///|
struct Pin {
  screen : TerminalScreen
  pin : PageListPin
}

///|
struct Selection {
  start : Pin
  end : Pin
  rectangle : Bool
}

///|
pub fn Selection::new(start : Pin, end_ : Pin, rectangle : Bool) -> Selection {
  { start, end: end_, rectangle }
}

///|
pub fn Selection::start(self : Selection) -> Pin {
  self.start
}

///|
pub fn Selection::end(self : Selection) -> Pin {
  self.end
}

///|
pub fn Selection::rectangle(self : Selection) -> Bool {
  self.rectangle
}
