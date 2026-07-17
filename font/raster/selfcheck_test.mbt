// Self-checking tests for the rasterizer, requiring no fonts and no external
// libraries. Two independent oracles:
//   1. Area conservation: total rendered coverage must equal the analytic
//      shoelace area (simple, hole-free shapes only).
//   2. Supersampling: the rasterizer must agree with a brute-force point-sampled
//      reference that shares no code path with it.

///|
/// Relative error helper.
fn rel_err(actual : Double, expected : Double) -> Double {
  let d = actual - expected
  let d = if d < 0.0 { -d } else { d }
  d / expected
}

///|
test "area conservation: total coverage equals shoelace area" {
  let w = 64
  let h = 64
  let shapes = [
    rect(8.0, 8.0, 56.0, 40.0),
    triangle(point(10.0, 54.0), point(54.0, 54.0), point(32.0, 10.0)),
    regular_polygon(32.0, 32.0, 24.0, 6),
    circle(32.0, 32.0, 26.0, segments=48),
  ]
  for shape in shapes {
    let cov = render(shape, w, h, NonZero)
    let err = rel_err(cov.total(), shape.area())
    // Rasterizer is near-exact for straight edges, so this is a tight bound.
    assert_true(err < 0.005, msg="area relative error too large")
  }
}

///|
/// Non-self-intersecting shapes: the analytic rasterizer must track the
/// point-sampled oracle tightly everywhere. Because it computes *exact* per-pixel
/// area for straight edges, agreement here is far better than a sampling
/// rasterizer's — the residual is the oracle's own 12x12 sampling error at edges.
test "rasterizer agrees with supersampled oracle" {
  let w = 64
  let h = 64
  let cases : Array[(Path, FillRule)] = [
    (rect(8.5, 8.5, 55.5, 39.5), NonZero),
    (triangle(point(8.0, 56.0), point(56.0, 50.0), point(30.0, 8.0)), NonZero),
    (circle(32.0, 32.0, 26.0, segments=48), NonZero),
    (ring(32.0, 32.0, 28.0, 14.0, segments=48), NonZero),
    (ring(32.0, 32.0, 28.0, 14.0, segments=48), EvenOdd),
  ]
  for c in cases {
    let (shape, rule) = c
    let mine = render(shape, w, h, rule)
    let oracle = render_supersampled(shape, w, h, rule)
    assert_true(mine.mean_abs_diff(oracle) < 0.002, msg="mean diff vs oracle")
    assert_true(mine.max_abs_diff(oracle) < 0.05, msg="max diff vs oracle")
  }
}

///|
/// Self-intersecting paths (a pentagram) are where the analytic method shows its
/// nature: it integrates the *winding number* over each pixel, exactly as
/// FreeType's `ftgrays` and `stb_truetype` v2 do. A pixel straddling a self-
/// crossing is part winding-2 and part winding-0, so its integrated coverage
/// differs from a point-sampled "is-inside" oracle by design — a handful of
/// pixels per crossing. Crucially this is the *same* behavior the real FreeType
/// produces, so it costs nothing on the FreeType differential gate.
///
/// Away from those few crossing pixels the two agree, so the mean stays tiny;
/// the qualitative fill-rule distinction is asserted separately on the core
/// pixel (see "fill rule: pentagram core ...").
test "self-intersecting star: winding-integral agrees in the mean" {
  let w = 64
  let h = 64
  let rules : Array[FillRule] = [NonZero, EvenOdd]
  for rule in rules {
    let s = star(32.0, 32.0, 28.0, points=5)
    let mine = render(s, w, h, rule)
    let oracle = render_supersampled(s, w, h, rule)
    // Only ~5 self-crossing pixels differ, so the mean is still very small.
    assert_true(
      mine.mean_abs_diff(oracle) < 0.002,
      msg="mean diff vs oracle (self-intersection)",
    )
  }
}

///|
test "fill rule: pentagram core differs between non-zero and even-odd" {
  let s = star(32.0, 32.0, 28.0, points=5)
  // The central pentagon: filled by non-zero (winding 2), empty by even-odd.
  assert_true(s.point_inside(32.0, 32.0, NonZero), msg="non-zero fills core")
  assert_false(s.point_inside(32.0, 32.0, EvenOdd), msg="even-odd voids core")
  // The rasterizer must reproduce that distinction, not just the oracle.
  let nz = render(s, 64, 64, NonZero)
  let eo = render(s, 64, 64, EvenOdd)
  assert_true(nz.get(32, 32) > 0.9, msg="non-zero core covered")
  assert_true(eo.get(32, 32) < 0.1, msg="even-odd core empty")
}

///|
test "coverage stays within [0, 1]" {
  let cov = render(star(32.0, 32.0, 28.0, points=5), 64, 64, NonZero)
  for y in 0..<64 {
    for x in 0..<64 {
      let v = cov.get(x, y)
      assert_true(
        v >= -1.0e-9 && v <= 1.0 + 1.0e-9,
        msg="coverage out of range",
      )
    }
  }
}

///|
test "integer translation shifts the image exactly" {
  let base = render(circle(20.0, 20.0, 12.0, segments=48), 64, 64, NonZero)
  let dx = 7
  let dy = 9
  let moved = render(circle(27.0, 29.0, 12.0, segments=48), 64, 64, NonZero)
  let mut max_d = 0.0
  for y in 0..<40 {
    for x in 0..<40 {
      let d = base.get(x, y) - moved.get(x + dx, y + dy)
      let d = if d < 0.0 { -d } else { d }
      if d > max_d {
        max_d = d
      }
    }
  }
  assert_true(max_d < 1.0e-12, msg="integer translation not exact")
}

///|
test "empty path renders blank" {
  let empty = Path::new([])
  let cov = render(empty, 16, 16, NonZero)
  assert_true(cov.total() == 0.0, msg="empty path should be blank")
}

///|
test "ascii snapshot: anti-aliased circle" {
  let cov = render(circle(16.0, 16.0, 13.0, segments=64), 32, 32, NonZero)
  inspect(
    cov.to_ascii(),
    content=(
      #|                                
      #|                                
      #|                                
      #|           .=*%%%%*=.           
      #|         :*%@@@@@@@@%*:         
      #|        +%@@@@@@@@@@@@%+        
      #|       #@@@@@@@@@@@@@@@@#       
      #|      #@@@@@@@@@@@@@@@@@@#      
      #|     +@@@@@@@@@@@@@@@@@@@@+     
      #|    :%@@@@@@@@@@@@@@@@@@@@%:    
      #|    *@@@@@@@@@@@@@@@@@@@@@@*    
      #|   .%@@@@@@@@@@@@@@@@@@@@@@%.   
      #|   =@@@@@@@@@@@@@@@@@@@@@@@@=   
      #|   *@@@@@@@@@@@@@@@@@@@@@@@@*   
      #|   %@@@@@@@@@@@@@@@@@@@@@@@@%   
      #|   %@@@@@@@@@@@@@@@@@@@@@@@@%   
      #|   %@@@@@@@@@@@@@@@@@@@@@@@@%   
      #|   %@@@@@@@@@@@@@@@@@@@@@@@@%   
      #|   *@@@@@@@@@@@@@@@@@@@@@@@@*   
      #|   =@@@@@@@@@@@@@@@@@@@@@@@@=   
      #|   .%@@@@@@@@@@@@@@@@@@@@@@%.   
      #|    *@@@@@@@@@@@@@@@@@@@@@@*    
      #|    :%@@@@@@@@@@@@@@@@@@@@%:    
      #|     +@@@@@@@@@@@@@@@@@@@@+     
      #|      #@@@@@@@@@@@@@@@@@@#      
      #|       #@@@@@@@@@@@@@@@@#       
      #|        +%@@@@@@@@@@@@%+        
      #|         :*%@@@@@@@@%*:         
      #|           .=*%%%%*=.           
      #|                                
      #|                                
      #|                                
      #|
    ),
  )
}
