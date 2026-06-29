///|
/// The production rasterizer: analytic signed-area coverage.
///
/// This is the cell-accumulation method used by FreeType's `ftgrays` and
/// `stb_truetype`'s v2 rasterizer. Every edge is walked once through the pixel
/// grid; in each cell it touches it deposits two signed quantities:
///
///   * `cover` — the edge's vertical extent within the cell (its `dy`). This is
///     the winding contribution: anything strictly to the right of the edge sees
///     the full `dy`.
///   * `area`  — `dy` times the average horizontal distance from the edge to the
///     cell's right border, i.e. the signed area the edge encloses *inside* the
///     cell (toward +x), by Green's theorem.
///
/// A final left-to-right prefix sweep per row turns these into per-pixel signed
/// coverage: `coverage(x) = acc + area(x)`, then `acc += cover(x)`, where `acc`
/// is the full winding accumulated from every cell to the left. The fill rule
/// maps signed coverage to an alpha in `[0, 1]`.
///
/// Unlike a sampling rasterizer this computes the *exact* area each edge covers
/// in each pixel — for straight edges the result is analytically exact (no
/// supersampling residual), which is why it tracks both the shoelace area and an
/// independent point-sampled oracle to within floating-point noise.
pub fn render(
  path : Path,
  width : Int,
  height : Int,
  rule : FillRule,
) -> Coverage {
  let cov = Coverage::new(width, height)
  if width <= 0 || height <= 0 {
    return cov
  }
  // Per-cell accumulators (row-major) plus a per-row seed for edges that fall
  // entirely left of the canvas (their full cover must enter the prefix sum
  // before column 0).
  let area : Array[Double] = Array::make(width * height, 0.0)
  let cover : Array[Double] = Array::make(width * height, 0.0)
  let seed : Array[Double] = Array::make(height, 0.0)
  for contour in path.contours {
    let n = contour.length()
    for i in 0..<n {
      let a = contour[i]
      let b = contour[(i + 1) % n]
      render_edge(area, cover, seed, width, height, a.x, a.y, b.x, b.y)
    }
  }
  // Resolve per-pixel signed coverage and apply the fill rule.
  for ey in 0..<height {
    let base = ey * width
    let mut acc = seed[ey]
    for ex in 0..<width {
      let signed = acc + area[base + ex]
      cov.data[base + ex] = apply_rule(signed, rule)
      acc += cover[base + ex]
    }
  }
  cov
}

///|
/// Map a signed coverage value to an alpha in `[0, 1]` under the fill rule.
fn apply_rule(c : Double, rule : FillRule) -> Double {
  match rule {
    NonZero => {
      let a = absd(c)
      if a > 1.0 {
        1.0
      } else {
        a
      }
    }
    // Fold the winding into [0, 1] with even-odd parity: ...,-1,0,1 -> 0 and the
    // half-open interval reflects so both 0.3 and 1.7 give alpha 0.3.
    EvenOdd => {
      let m = c - 2.0 * floord(c * 0.5)
      if m > 1.0 {
        2.0 - m
      } else {
        m
      }
    }
  }
}

///|
/// Largest integer `<= x`, as an `Int`. (`Double::to_int` truncates toward zero.)
fn ifloor(x : Double) -> Int {
  let t = x.to_int()
  if x < 0.0 && t.to_double() != x {
    t - 1
  } else {
    t
  }
}

///|
fn floord(x : Double) -> Double {
  ifloor(x).to_double()
}

///|
/// Walk one edge from `(x0, y0)` to `(x1, y1)`, splitting it at integer-`y`
/// (row) boundaries and handing each row-confined piece to `render_row_piece`.
/// Travel follows the edge's natural direction so each piece's `dy` carries the
/// correct winding sign; the cell of each piece is found from its midpoint,
/// which is robust at boundaries regardless of direction.
fn render_edge(
  area : Array[Double],
  cover : Array[Double],
  seed : Array[Double],
  w : Int,
  h : Int,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  let dy = y1 - y0
  if dy == 0.0 {
    return // horizontal edges contribute no coverage
  }
  let dx = x1 - x0
  let mut t = 0.0
  // Cap iterations as a backstop against pathological coordinates.
  let max_iter = h + (if dy > 0.0 { y1 - y0 } else { y0 - y1 }).to_int() + 4
  let mut steps = 0
  while t < 1.0 - 1.0e-12 && steps <= max_iter {
    steps += 1
    let cy = y0 + t * dy
    // t-distance to the next row boundary in the direction of travel.
    let bound = if dy > 0.0 { floord(cy) + 1.0 } else { ceild(cy) - 1.0 }
    let mut t_next = t + (bound - cy) / dy
    if t_next > 1.0 || t_next <= t {
      t_next = 1.0
    }
    // Identify the row from the piece midpoint (strictly interior to one row).
    let tm = (t + t_next) * 0.5
    let ey = ifloor(y0 + tm * dy)
    if ey >= 0 && ey < h {
      let xa = x0 + t * dx
      let ya = y0 + t * dy
      let xb = x0 + t_next * dx
      let yb = y0 + t_next * dy
      let eyf = ey.to_double()
      render_row_piece(area, cover, seed, w, ey, xa, ya - eyf, xb, yb - eyf)
    }
    t = t_next
  }
}

///|
/// Walk a row-confined edge piece (with `y0`, `y1` already made fractional
/// within the row) across integer-`x` (column) boundaries, depositing `cover`
/// and `area` into each cell it crosses.
fn render_row_piece(
  area : Array[Double],
  cover : Array[Double],
  seed : Array[Double],
  w : Int,
  ey : Int,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  let base = ey * w
  let dx = x1 - x0
  let dyv = y1 - y0
  if dx == 0.0 {
    // Vertical within the row: a single column.
    add_cell(area, cover, seed, w, base, ey, ifloor(x0), x0, x1, dyv)
    return
  }
  let mut t = 0.0
  let mut steps = 0
  let max_iter = w + (if dx > 0.0 { x1 - x0 } else { x0 - x1 }).to_int() + 4
  while t < 1.0 - 1.0e-12 && steps <= max_iter {
    steps += 1
    let cx = x0 + t * dx
    let bound = if dx > 0.0 { floord(cx) + 1.0 } else { ceild(cx) - 1.0 }
    let mut t_next = t + (bound - cx) / dx
    if t_next > 1.0 || t_next <= t {
      t_next = 1.0
    }
    let tm = (t + t_next) * 0.5
    let ex = ifloor(x0 + tm * dx)
    let xa = x0 + t * dx
    let xb = x0 + t_next * dx
    let dy_sub = (t_next - t) * dyv
    add_cell(area, cover, seed, w, base, ey, ex, xa, xb, dy_sub)
    t = t_next
  }
}

///|
/// `x = -ifloor(-x)`: the smallest integer `>= x`, as a `Double`.
fn ceild(x : Double) -> Double {
  -ifloor(-x).to_double()
}

///|
/// Deposit one cell-confined edge piece into `(ex, ey)`'s accumulators.
/// `dy` is the (signed) vertical extent; `xa`/`xb` are its x-endpoints inside
/// the cell. Pieces left of the canvas feed the row seed; pieces right of it (no
/// visible cell lies to their right) are dropped.
fn add_cell(
  area : Array[Double],
  cover : Array[Double],
  seed : Array[Double],
  w : Int,
  base : Int,
  ey : Int,
  ex : Int,
  xa : Double,
  xb : Double,
  dy : Double,
) -> Unit {
  if dy == 0.0 {
    return
  }
  if ex < 0 {
    seed[ey] += dy
    return
  }
  if ex >= w {
    return
  }
  let exf = ex.to_double()
  let mut fx = (xa - exf + (xb - exf)) * 0.5
  if fx < 0.0 {
    fx = 0.0
  } else if fx > 1.0 {
    fx = 1.0
  }
  cover[base + ex] += dy
  area[base + ex] += dy * (1.0 - fx)
}
