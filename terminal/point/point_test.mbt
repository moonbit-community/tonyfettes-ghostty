///|
test "point/coord returns payload" {
  let coord : @point.Coordinate = @point.Coordinate::new(42, 80)
  let point = @point.Point::Viewport(coord)
  guard point.coord() == coord else { fail("expected coord payload") }
}

///|
test "point/coordinate equality checks both axes" {
  let a : @point.Coordinate = @point.Coordinate::new(12, 34)
  let b : @point.Coordinate = @point.Coordinate::new(12, 34)
  let c : @point.Coordinate = @point.Coordinate::new(12, 35)
  guard a == b else { fail("expected equal coordinates") }
  guard a != c else { fail("expected differing y coordinate") }
}

///|
test "point/constructors cover all point tags" {
  let coord : @point.Coordinate = @point.Coordinate::new(1, 2)
  ignore(@point.Tag::Active)
  ignore(@point.Tag::Viewport)
  ignore(@point.Tag::Screen)
  ignore(@point.Tag::History)
  ignore(@point.Point::Active(coord))
  ignore(@point.Point::Viewport(coord))
  ignore(@point.Point::Screen(coord))
  ignore(@point.Point::History(coord))
}

///|
test "point/coord handles every point variant" {
  let coords : Array[@point.Coordinate] = [
    @point.Coordinate::new(3, 4),
    @point.Coordinate::new(5, 6),
    @point.Coordinate::new(7, 8),
    @point.Coordinate::new(9, 10),
  ]
  let points : Array[@point.Point] = [
    Active(coords[0]),
    Viewport(coords[1]),
    Screen(coords[2]),
    History(coords[3]),
  ]

  for i in 0..<points.length() {
    guard points[i].coord() == coords[i] else {
      fail("expected point variant to preserve coordinate payload")
    }
  }
}

///|
test "point/coordinate constructor and accessors" {
  let coord = @point.Coordinate::new(7, 9)
  assert_eq(coord.x(), 7)
  assert_eq(coord.y(), 9)
}
