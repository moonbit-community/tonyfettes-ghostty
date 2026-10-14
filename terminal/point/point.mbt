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
  y : UInt32
} derive(Eq, Debug)

///|
pub fn Coordinate::new(x : @size.CellCountInt, y : UInt32) -> Coordinate {
  { x, y, }
}

///|
pub fn Coordinate::x(self : Coordinate) -> @size.CellCountInt {
  self.x
}

///|
pub fn Coordinate::y(self : Coordinate) -> UInt32 {
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

///|
pub extend Tag with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Tag with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Tag with @debug.Debug::{to_repr}

///|
pub extend Coordinate with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Coordinate with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Coordinate with @debug.Debug::{to_repr}

///|
pub extend Point with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Point with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Point with @debug.Debug::{to_repr}
