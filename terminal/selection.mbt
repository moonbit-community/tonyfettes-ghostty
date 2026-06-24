///|
struct Selection {
  start : @pagelist.Pin
  end : @pagelist.Pin
  rectangle : Bool
}

///|
pub fn Selection::new(
  start : @pagelist.Pin,
  end_ : @pagelist.Pin,
  rectangle : Bool,
) -> Selection {
  { start, end: end_, rectangle }
}

///|
pub fn Selection::start(self : Selection) -> @pagelist.Pin {
  self.start
}

///|
pub fn Selection::end(self : Selection) -> @pagelist.Pin {
  self.end
}

///|
pub fn Selection::rectangle(self : Selection) -> Bool {
  self.rectangle
}
