///|
struct Selection[Ref] {
  start : Ref
  end : Ref
  rectangle : Bool
} derive(Eq, Debug)

///|
pub fn[Ref] Selection::new(
  start : Ref,
  end_ : Ref,
  rectangle : Bool,
) -> Selection[Ref] {
  { start, end: end_, rectangle }
}

///|
pub fn[Ref] Selection::start(self : Selection[Ref]) -> Ref {
  self.start
}

///|
pub fn[Ref] Selection::end(self : Selection[Ref]) -> Ref {
  self.end
}

///|
pub fn[Ref] Selection::rectangle(self : Selection[Ref]) -> Bool {
  self.rectangle
}
