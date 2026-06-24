///|
pub(all) enum Tag {
  Active
  Viewport
  Screen
  History
} derive(Eq, Debug)

///|
struct Coordinate {
  x : @size.CellCountInt
  y : UInt
} derive(Eq, Debug)

///|
pub fn Coordinate::new(x : @size.CellCountInt, y : UInt) -> Coordinate {
  { x, y }
}

///|
pub fn Coordinate::x(self : Coordinate) -> @size.CellCountInt {
  self.x
}

///|
pub fn Coordinate::y(self : Coordinate) -> UInt {
  self.y
}

///|
pub(all) enum Point {
  Active(Coordinate)
  Viewport(Coordinate)
  Screen(Coordinate)
  History(Coordinate)
} derive(Eq, Debug)

///|
pub fn Point::coord(self : Point) -> Coordinate {
  match self {
    Active(coord) => coord
    Viewport(coord) => coord
    Screen(coord) => coord
    History(coord) => coord
  }
}
