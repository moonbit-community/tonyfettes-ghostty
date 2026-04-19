///|
test "point/coord returns payload" {
  let coord : Coordinate = { x: 42, y: 80 }
  let point = Point::Viewport(coord)
  guard point.coord() == coord else { fail("expected coord payload") }
}

///|
test "point/coordinate equality checks both axes" {
  let a : Coordinate = { x: 12, y: 34 }
  let b : Coordinate = { x: 12, y: 34 }
  let c : Coordinate = { x: 12, y: 35 }
  guard a == b else { fail("expected equal coordinates") }
  guard a != c else { fail("expected differing y coordinate") }
}

///|
test "point/constructors cover all point tags" {
  let coord : Coordinate = { x: 1, y: 2 }
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
    { x: 3, y: 4 },
    { x: 5, y: 6 },
    { x: 7, y: 8 },
    { x: 9, y: 10 },
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
