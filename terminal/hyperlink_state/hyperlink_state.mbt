///|
const FirstImplicitHyperlinkId : Int32 = 0

///|
struct ScreenHyperlinkState {
  mut uri : String?
  mut explicit_id : String?
  mut implicit_id : Int32?
  mut next_implicit_id : Int32
  mut cell : @hyperlink.CellHyperlink?
} derive(Eq, Debug)

///|
pub fn ScreenHyperlinkState::new() -> ScreenHyperlinkState {
  {
    uri: None,
    explicit_id: None,
    implicit_id: None,
    next_implicit_id: FirstImplicitHyperlinkId,
    cell: None,
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
pub fn ScreenHyperlinkState::implicit_id(self : ScreenHyperlinkState) -> Int32? {
  self.implicit_id
}

///|
pub fn ScreenHyperlinkState::next_implicit_id(
  self : ScreenHyperlinkState,
) -> Int32 {
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
      self.cell = Some(@hyperlink.CellHyperlink::explicit(uri, value))
    }
    None => {
      self.explicit_id = None
      self.implicit_id = Some(self.next_implicit_id)
      self.cell = Some(
        @hyperlink.CellHyperlink::implicit(uri, self.next_implicit_id),
      )
      self.next_implicit_id += 1
    }
  }
}

///|
pub fn ScreenHyperlinkState::end(self : ScreenHyperlinkState) -> Unit {
  self.uri = None
  self.explicit_id = None
  self.implicit_id = None
  self.cell = None
}

///|
pub fn ScreenHyperlinkState::cell_hyperlink(
  self : ScreenHyperlinkState,
) -> @hyperlink.CellHyperlink? {
  self.cell
}

///|
pub fn ScreenHyperlinkState::full_reset(self : ScreenHyperlinkState) -> Unit {
  self.end()
  self.next_implicit_id = FirstImplicitHyperlinkId
}

///|
pub extend ScreenHyperlinkState with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend ScreenHyperlinkState with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend ScreenHyperlinkState with @debug.Debug::{to_repr}
