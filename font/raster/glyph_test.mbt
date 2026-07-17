// End-to-end test of the real pipeline: a glyph outline captured from
// harfbuzz.mbt's `draw` API -> Bézier flattening -> scanline rasterization.
//
// The command stream below is the *verbatim* output HarfBuzz produced for a
// curved TrueType glyph (a standard 4-quadratic "circle"), captured by the test
// `capture draw stream for curved glyph` in the harfbuzz.mbt repo:
//
//   M 100 50 / Q 100 100 50 100 / Q 0 100 0 50 / Q 0 0 50 0 / Q 100 0 100 50 / Z
//
// Treating it as a checked-in fixture keeps the two modules decoupled — exactly
// how a FreeType reference bitmap would later be captured offline.

///|
/// `move_to` start point of the captured glyph (font units).
let glyph_start : (Double, Double) = (100.0, 50.0)

///|
/// The captured `quadratic_to` commands: each is `(ctrl_x, ctrl_y, end_x, end_y)`.
let glyph_quads : Array[(Double, Double, Double, Double)] = [
  (100.0, 100.0, 50.0, 100.0),
  (0.0, 100.0, 0.0, 50.0),
  (0.0, 0.0, 50.0, 0.0),
  (100.0, 0.0, 100.0, 50.0),
]

///|
/// Replay the captured harfbuzz `draw` stream into a `PathBuilder` at scale `s`
/// with margin `m`, flattening curves at the given `tolerance`.
fn build_glyph_path(s : Double, m : Double, tolerance : Double) -> Path {
  let pb = PathBuilder::new(tolerance~)
  pb.move_to(glyph_start.0 * s + m, glyph_start.1 * s + m)
  for q in glyph_quads {
    pb.quadratic_to(q.0 * s + m, q.1 * s + m, q.2 * s + m, q.3 * s + m)
  }
  pb.close()
  pb.build()
}

///|
/// Exact signed-area contribution of one quadratic Bézier via the line integral
/// `½∫(x·y' − y·x') dt`, evaluated with Simpson's rule (exact for the cubic
/// integrand of a quadratic). This is an independent oracle for the true area
/// enclosed by the *curve*, against which flattening must converge.
fn quad_area(p0 : Point, c : Point, p1 : Point) -> Double {
  let n = 64
  let h = 1.0 / n.to_double()
  fn integrand(t : Double) -> Double {
    let mt = 1.0 - t
    let x = mt * mt * p0.x + 2.0 * mt * t * c.x + t * t * p1.x
    let y = mt * mt * p0.y + 2.0 * mt * t * c.y + t * t * p1.y
    let dx = 2.0 * mt * (c.x - p0.x) + 2.0 * t * (p1.x - c.x)
    let dy = 2.0 * mt * (c.y - p0.y) + 2.0 * t * (p1.y - c.y)
    x * dy - y * dx
  }

  let mut acc = integrand(0.0) + integrand(1.0)
  for i in 1..<n {
    let w = if i % 2 == 1 { 4.0 } else { 2.0 }
    acc += w * integrand(i.to_double() * h)
  }
  0.5 * (h / 3.0) * acc
}

///|
/// True area enclosed by the captured curved glyph, at scale `s`.
fn glyph_exact_area(s : Double) -> Double {
  let mut p0 = point(glyph_start.0, glyph_start.1)
  let mut total = 0.0
  for q in glyph_quads {
    let c = point(q.0, q.1)
    let p1 = point(q.2, q.3)
    total += quad_area(p0, c, p1)
    p0 = p1
  }
  let a = if total < 0.0 { -total } else { total }
  a * s * s
}

///|
fn rel(actual : Double, expected : Double) -> Double {
  let d = actual - expected
  let d = if d < 0.0 { -d } else { d }
  d / expected
}

///|
test "flattening converges to the exact curved area" {
  let exact = glyph_exact_area(1.0)
  let coarse = build_glyph_path(1.0, 0.0, 5.0).area()
  let fine = build_glyph_path(1.0, 0.0, 0.05).area()
  // Finer tolerance must be at least as accurate as coarser.
  assert_true(
    rel(fine, exact) <= rel(coarse, exact),
    msg="finer should improve",
  )
  // And fine flattening should track the true curve area tightly.
  assert_true(rel(fine, exact) < 0.002, msg="fine flatten area off")
}

///|
test "rasterized glyph conserves the curved area" {
  let s = 0.4
  let m = 2.0
  let path = build_glyph_path(s, m, 0.05)
  let cov = render(path, 44, 44, NonZero)
  assert_true(
    rel(cov.total(), glyph_exact_area(s)) < 0.01,
    msg="glyph area off",
  )
}

///|
test "rasterized glyph agrees with supersampled oracle" {
  let path = build_glyph_path(0.4, 2.0, 0.05)
  let mine = render(path, 44, 44, NonZero)
  let oracle = render_supersampled(path, 44, 44, NonZero)
  assert_true(mine.mean_abs_diff(oracle) < 0.02, msg="mean diff vs oracle")
  assert_true(mine.max_abs_diff(oracle) < 0.25, msg="max diff vs oracle")
}

///|
test "ascii snapshot: rasterized harfbuzz glyph" {
  let path = build_glyph_path(0.4, 2.0, 0.05)
  let cov = render(path, 44, 44, NonZero)
  inspect(
    cov.to_ascii(),
    content=(
      #|                                            
      #|                                            
      #|               -=*#%%%%%%#*=-               
      #|            =#%@@@@@@@@@@@@@@%#=            
      #|          +%@@@@@@@@@@@@@@@@@@@@%+          
      #|        :%@@@@@@@@@@@@@@@@@@@@@@@@%:        
      #|       =%@@@@@@@@@@@@@@@@@@@@@@@@@@%=       
      #|      =@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@=      
      #|     :%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%:     
      #|     %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%     
      #|    +@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@+    
      #|    %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%    
      #|   =@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@=   
      #|   #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#   
      #|   %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%   
      #|  -@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@-  
      #|  =@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@=  
      #|  *@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*  
      #|  #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#  
      #|  %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%  
      #|  %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%  
      #|  %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%  
      #|  %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%  
      #|  %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%  
      #|  %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%  
      #|  #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#  
      #|  *@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*  
      #|  =@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@=  
      #|  -@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@-  
      #|   %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%   
      #|   #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#   
      #|   =@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@=   
      #|    %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%    
      #|    +@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@+    
      #|     %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%     
      #|     :%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%:     
      #|      =@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@=      
      #|       =%@@@@@@@@@@@@@@@@@@@@@@@@@@%=       
      #|        :%@@@@@@@@@@@@@@@@@@@@@@@@%:        
      #|          +%@@@@@@@@@@@@@@@@@@@@%+          
      #|            =#%@@@@@@@@@@@@@@%#=            
      #|               -=*#%%%%%%#*=-               
      #|                                            
      #|                                            
      #|
    ),
  )
}
