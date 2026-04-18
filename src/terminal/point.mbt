///|
pub enum Tag {
  Active
  Viewport
  Screen
  History
} derive(Eq, Debug)

///|
pub struct Coordinate {
  x : CellCountInt
  y : UInt
} derive(Eq, Debug)

///|
pub enum Point {
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
