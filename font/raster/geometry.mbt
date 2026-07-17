///|
/// A 2D point in pixel coordinate space.
///
/// Convention: pixel `(px, py)` covers the half-open square
/// `[px, px+1) x [py, py+1)`. Sample positions use `+0.5` for cell centers.
pub struct Point {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
pub fn point(x : Double, y : Double) -> Point {
  { x, y }
}

///|
/// Fill rule for resolving which regions of a (possibly self-intersecting or
/// holed) path are "inside".
pub(all) enum FillRule {
  NonZero
  EvenOdd
} derive(Eq, Debug)

///|
/// A path is a set of closed contours. Each contour is an array of points; the
/// closing edge from the last point back to the first is implicit.
struct Path {
  contours : Array[Array[Point]]
}

///|
pub fn Path::new(contours : Array[Array[Point]]) -> Path {
  { contours, }
}

///|
fn absd(x : Double) -> Double {
  if x < 0.0 {
    -x
  } else {
    x
  }
}

///|
/// Signed area of the path via the shoelace formula, summed over all contours.
///
/// For shapes whose contours do not overlap and are consistently oriented,
/// `area()` (the absolute value) equals the geometric filled area. This is the
/// analytic ground truth used by the area-conservation tests, which therefore
/// deliberately use only simple shapes (no holes / no self-intersection).
pub fn Path::signed_area(self : Path) -> Double {
  let mut total = 0.0
  for contour in self.contours {
    let n = contour.length()
    for i in 0..<n {
      let a = contour[i]
      let b = contour[(i + 1) % n]
      total += a.x * b.y - b.x * a.y
    }
  }
  total / 2.0
}

///|
pub fn Path::area(self : Path) -> Double {
  absd(self.signed_area())
}

///|
/// `> 0` if `(px, py)` is left of the directed edge `a -> b`, `< 0` if right.
fn is_left(a : Point, b : Point, px : Double, py : Double) -> Double {
  (b.x - a.x) * (py - a.y) - (px - a.x) * (b.y - a.y)
}

///|
/// Winding number of the path around `(x, y)` (for the non-zero rule).
fn Path::winding_number(self : Path, x : Double, y : Double) -> Int {
  let mut wn = 0
  for contour in self.contours {
    let n = contour.length()
    for i in 0..<n {
      let a = contour[i]
      let b = contour[(i + 1) % n]
      if a.y <= y {
        if b.y > y && is_left(a, b, x, y) > 0.0 {
          wn += 1
        }
      } else if b.y <= y && is_left(a, b, x, y) < 0.0 {
        wn -= 1
      }
    }
  }
  wn
}

///|
/// Number of times a ray to `+x` from `(x, y)` crosses path edges (for the
/// even-odd rule).
fn Path::crossing_count(self : Path, x : Double, y : Double) -> Int {
  let mut c = 0
  for contour in self.contours {
    let n = contour.length()
    for i in 0..<n {
      let a = contour[i]
      let b = contour[(i + 1) % n]
      if (a.y > y) != (b.y > y) {
        let xint = a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x)
        if x < xint {
          c += 1
        }
      }
    }
  }
  c
}

///|
/// Exact point-in-path test. This is the trusted primitive behind the
/// brute-force oracle: it is simple enough to be obviously correct.
pub fn Path::point_inside(
  self : Path,
  x : Double,
  y : Double,
  rule : FillRule,
) -> Bool {
  match rule {
    NonZero => self.winding_number(x, y) != 0
    EvenOdd => self.crossing_count(x, y) % 2 == 1
  }
}
