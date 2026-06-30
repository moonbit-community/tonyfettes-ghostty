///|
/// Maximum subdivision recursion depth — a backstop against pathological inputs.
const MAX_DEPTH : Int = 24

///|
fn mid(a : Point, b : Point) -> Point {
  point((a.x + b.x) * 0.5, (a.y + b.y) * 0.5)
}

///|
/// Squared distance from `c` to the infinite line through `a` and `b`.
/// (If `a == b`, returns the squared distance to that point.)
fn dist2_to_line(a : Point, b : Point, c : Point) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  let len2 = dx * dx + dy * dy
  if len2 == 0.0 {
    let ex = c.x - a.x
    let ey = c.y - a.y
    return ex * ex + ey * ey
  }
  let cross = (c.x - a.x) * dy - (c.y - a.y) * dx
  cross * cross / len2
}

///|
/// Recursively flatten a quadratic Bézier, appending segment endpoints (never
/// the start point `p0`, which the caller already holds) to `out`.
fn flatten_quadratic(
  out : Array[Point],
  p0 : Point,
  c : Point,
  p1 : Point,
  tol2 : Double,
  depth : Int,
) -> Unit {
  if depth >= MAX_DEPTH || dist2_to_line(p0, p1, c) <= tol2 {
    out.push(p1)
    return
  }
  let p01 = mid(p0, c)
  let c1 = mid(c, p1)
  let m = mid(p01, c1)
  flatten_quadratic(out, p0, p01, m, tol2, depth + 1)
  flatten_quadratic(out, m, c1, p1, tol2, depth + 1)
}

///|
/// Recursively flatten a cubic Bézier, appending segment endpoints to `out`.
fn flatten_cubic(
  out : Array[Point],
  p0 : Point,
  c1 : Point,
  c2 : Point,
  p1 : Point,
  tol2 : Double,
  depth : Int,
) -> Unit {
  let flat = dist2_to_line(p0, p1, c1) <= tol2 &&
    dist2_to_line(p0, p1, c2) <= tol2
  if depth >= MAX_DEPTH || flat {
    out.push(p1)
    return
  }
  // de Casteljau split at t = 0.5
  let p01 = mid(p0, c1)
  let p12 = mid(c1, c2)
  let p23 = mid(c2, p1)
  let p012 = mid(p01, p12)
  let p123 = mid(p12, p23)
  let m = mid(p012, p123)
  flatten_cubic(out, p0, p01, p012, m, tol2, depth + 1)
  flatten_cubic(out, m, p123, p23, p1, tol2, depth + 1)
}

///|
/// Accumulates draw-style path commands — matching HarfBuzz's `draw` callbacks
/// (`move_to` / `line_to` / `quadratic_to` / `cubic_to` / `close`) — and
/// flattens any Bézier curves into line-segment contours. `build()` yields a
/// `Path` ready for `render`.
///
/// `tolerance` is the maximum allowed deviation (in input units) of a curve from
/// its flattened chord; smaller is smoother.
struct PathBuilder {
  contours : Array[Array[Point]]
  mut current : Array[Point]
  mut pen : Point
  mut open : Bool
  tol2 : Double
}

///|
pub fn PathBuilder::new(tolerance? : Double = 0.2) -> PathBuilder {
  {
    contours: [],
    current: [],
    pen: point(0.0, 0.0),
    open: false,
    tol2: tolerance * tolerance,
  }
}

///|
fn PathBuilder::finish_contour(self : PathBuilder) -> Unit {
  if self.current.length() >= 2 {
    self.contours.push(self.current)
  }
  self.current = []
  self.open = false
}

///|
pub fn PathBuilder::move_to(self : PathBuilder, x : Double, y : Double) -> Unit {
  if self.open {
    self.finish_contour()
  }
  let p = point(x, y)
  self.pen = p
  self.current = [p]
  self.open = true
}

///|
pub fn PathBuilder::line_to(self : PathBuilder, x : Double, y : Double) -> Unit {
  let p = point(x, y)
  self.current.push(p)
  self.pen = p
}

///|
pub fn PathBuilder::quadratic_to(
  self : PathBuilder,
  cx : Double,
  cy : Double,
  x : Double,
  y : Double,
) -> Unit {
  let p1 = point(x, y)
  flatten_quadratic(self.current, self.pen, point(cx, cy), p1, self.tol2, 0)
  self.pen = p1
}

///|
pub fn PathBuilder::cubic_to(
  self : PathBuilder,
  c1x : Double,
  c1y : Double,
  c2x : Double,
  c2y : Double,
  x : Double,
  y : Double,
) -> Unit {
  let p1 = point(x, y)
  flatten_cubic(
    self.current,
    self.pen,
    point(c1x, c1y),
    point(c2x, c2y),
    p1,
    self.tol2,
    0,
  )
  self.pen = p1
}

///|
pub fn PathBuilder::close(self : PathBuilder) -> Unit {
  self.finish_contour()
}

///|
pub fn PathBuilder::build(self : PathBuilder) -> Path {
  if self.open {
    self.finish_contour()
  }
  Path::new(self.contours)
}
