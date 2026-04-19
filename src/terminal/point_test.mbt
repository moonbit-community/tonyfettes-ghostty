///|
test "point/coord returns payload" {
  let coord : Coordinate = Coordinate::new(42, 80)
  let point = Point::Viewport(coord)
  guard point.coord() == coord else { fail("expected coord payload") }
}

///|
test "point/coordinate equality checks both axes" {
  let a : Coordinate = Coordinate::new(12, 34)
  let b : Coordinate = Coordinate::new(12, 34)
  let c : Coordinate = Coordinate::new(12, 35)
  guard a == b else { fail("expected equal coordinates") }
  guard a != c else { fail("expected differing y coordinate") }
}

///|
test "point/constructors cover all point tags" {
  let coord : Coordinate = Coordinate::new(1, 2)
  ignore(Tag::Active)
  ignore(Tag::Viewport)
  ignore(Tag::Screen)
  ignore(Tag::History)
  ignore(Point::Active(coord))
  ignore(Point::Viewport(coord))
  ignore(Point::Screen(coord))
  ignore(Point::History(coord))
}

///|
test "point/coord handles every point variant" {
  let coords : Array[Coordinate] = [
    Coordinate::new(3, 4),
    Coordinate::new(5, 6),
    Coordinate::new(7, 8),
    Coordinate::new(9, 10),
  ]
  let points : Array[Point] = [
    Point::Active(coords[0]),
    Point::Viewport(coords[1]),
    Point::Screen(coords[2]),
    Point::History(coords[3]),
  ]

  for i in 0..<points.length() {
    guard points[i].coord() == coords[i] else {
      fail("expected point variant to preserve coordinate payload")
    }
  }
}

///|
test "point/coordinate constructor and accessors" {
  let coord = Coordinate::new(7, 9)
  assert_eq(coord.x(), 7)
  assert_eq(coord.y(), 9)
}
