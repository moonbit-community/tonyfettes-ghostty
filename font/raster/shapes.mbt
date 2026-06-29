///|
/// Axis-aligned rectangle `[x0, x1] x [y0, y1]`, wound counter-clockwise.
pub fn rect(x0 : Double, y0 : Double, x1 : Double, y1 : Double) -> Path {
  Path::new([[point(x0, y0), point(x1, y0), point(x1, y1), point(x0, y1)]])
}

///|
pub fn triangle(a : Point, b : Point, c : Point) -> Path {
  Path::new([[a, b, c]])
}

///|
/// Vertices of a regular `sides`-gon, in order, centered at `(cx, cy)`.
fn polygon_points(
  cx : Double,
  cy : Double,
  r : Double,
  sides : Int,
  rotation : Double,
) -> Array[Point] {
  let pts : Array[Point] = []
  for i in 0..<sides {
    let ang = rotation + 2.0 * @math.PI * i.to_double() / sides.to_double()
    pts.push(point(cx + r * @math.cos(ang), cy + r * @math.sin(ang)))
  }
  pts
}

///|
pub fn regular_polygon(
  cx : Double,
  cy : Double,
  r : Double,
  sides : Int,
  rotation? : Double = 0.0,
) -> Path {
  Path::new([polygon_points(cx, cy, r, sides, rotation)])
}

///|
/// Many-sided polygon approximating a circle.
pub fn circle(
  cx : Double,
  cy : Double,
  r : Double,
  segments? : Int = 64,
) -> Path {
  regular_polygon(cx, cy, r, segments)
}

///|
/// Annulus: outer ring CCW, inner ring CW (reversed) so the hole resolves under
/// both the non-zero and even-odd rules.
pub fn ring(
  cx : Double,
  cy : Double,
  r_outer : Double,
  r_inner : Double,
  segments? : Int = 64,
) -> Path {
  let outer = polygon_points(cx, cy, r_outer, segments, 0.0)
  let inner = polygon_points(cx, cy, r_inner, segments, 0.0).rev()
  Path::new([outer, inner])
}

///|
/// A self-intersecting `{n/2}` star polygon (e.g. a pentagram for `points = 5`),
/// built as one contour visiting every other outer vertex. The central region
/// is filled under non-zero (winding 2) but empty under even-odd — which makes
/// this the discriminating case for fill-rule handling.
pub fn star(cx : Double, cy : Double, r : Double, points? : Int = 5) -> Path {
  let outer = polygon_points(cx, cy, r, points, -@math.PI / 2.0)
  let contour : Array[Point] = []
  let mut idx = 0
  for _ in 0..<points {
    contour.push(outer[idx])
    idx = (idx + 2) % points
  }
  Path::new([contour])
}
