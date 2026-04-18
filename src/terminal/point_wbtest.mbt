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
