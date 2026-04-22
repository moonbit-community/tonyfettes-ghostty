///|
test "selection/preserves endpoints and rectangle flag" {
  let start = Point::Screen(Coordinate::new(3, 4))
  let end_ = Point::History(Coordinate::new(7, 9))
  let selection = Selection::new(start, end_, true)

  guard selection.start() == start else {
    fail("expected selection start to be preserved")
  }
  guard selection.end() == end_ else {
    fail("expected selection end to be preserved")
  }
  guard selection.rectangle() else {
    fail("expected selection rectangle flag to be preserved")
  }
}

///|
test "selection/supports non-rectangular selections" {
  let selection = Selection::new(
    Point::Active(Coordinate::new(0, 0)),
    Point::Viewport(Coordinate::new(10, 20)),
    false,
  )
  guard !selection.rectangle() else {
    fail("expected line selection to remain non-rectangular")
  }
}
