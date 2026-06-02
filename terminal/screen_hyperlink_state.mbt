///|
const FirstImplicitHyperlinkId : Int = 0

///|
struct ScreenHyperlinkState {
  mut uri : String?
  mut explicit_id : String?
  mut implicit_id : Int?
  mut next_implicit_id : Int
} derive(Eq, Debug)

///|
pub fn ScreenHyperlinkState::new() -> ScreenHyperlinkState {
  {
    uri: None,
    explicit_id: None,
    implicit_id: None,
    next_implicit_id: FirstImplicitHyperlinkId,
  }
}

///|
pub fn ScreenHyperlinkState::active(self : ScreenHyperlinkState) -> Bool {
  self.uri != None
}

///|
pub fn ScreenHyperlinkState::uri(self : ScreenHyperlinkState) -> String? {
  self.uri
}

///|
pub fn ScreenHyperlinkState::explicit_id(
  self : ScreenHyperlinkState,
) -> String? {
  self.explicit_id
}

///|
pub fn ScreenHyperlinkState::implicit_id(self : ScreenHyperlinkState) -> Int? {
  self.implicit_id
}

///|
pub fn ScreenHyperlinkState::next_implicit_id(
  self : ScreenHyperlinkState,
) -> Int {
  self.next_implicit_id
}

///|
pub fn ScreenHyperlinkState::start(
  self : ScreenHyperlinkState,
  uri : String,
  id : String?,
) -> Unit {
  self.uri = Some(uri)
  match id {
    Some(value) => {
      self.explicit_id = Some(value)
      self.implicit_id = None
    }
    None => {
      self.explicit_id = None
      self.implicit_id = Some(self.next_implicit_id)
      self.next_implicit_id += 1
    }
  }
}

///|
pub fn ScreenHyperlinkState::end(self : ScreenHyperlinkState) -> Unit {
  self.uri = None
  self.explicit_id = None
  self.implicit_id = None
}

///|
pub fn ScreenHyperlinkState::full_reset(self : ScreenHyperlinkState) -> Unit {
  self.end()
  self.next_implicit_id = FirstImplicitHyperlinkId
}
