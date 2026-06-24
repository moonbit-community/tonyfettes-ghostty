///|
struct ScreenCharsetState {
  mut g0 : @charsets.Charset
  mut g1 : @charsets.Charset
  mut g2 : @charsets.Charset
  mut g3 : @charsets.Charset
  mut gl : @charsets.Slots
  mut gr : @charsets.Slots
  mut single_shift : @charsets.Slots?
} derive(Eq, Debug)

///|
pub fn ScreenCharsetState::new() -> ScreenCharsetState {
  { g0: Utf8, g1: Utf8, g2: Utf8, g3: Utf8, gl: G0, gr: G2, single_shift: None }
}

///|
pub fn ScreenCharsetState::charset(
  self : ScreenCharsetState,
  slot : @charsets.Slots,
) -> @charsets.Charset {
  match slot {
    G0 => self.g0
    G1 => self.g1
    G2 => self.g2
    G3 => self.g3
  }
}

///|
pub fn ScreenCharsetState::gl(self : ScreenCharsetState) -> @charsets.Slots {
  self.gl
}

///|
pub fn ScreenCharsetState::gr(self : ScreenCharsetState) -> @charsets.Slots {
  self.gr
}

///|
pub fn ScreenCharsetState::single_shift(
  self : ScreenCharsetState,
) -> @charsets.Slots? {
  self.single_shift
}

///|
pub fn ScreenCharsetState::configure(
  self : ScreenCharsetState,
  slot : @charsets.Slots,
  charset : @charsets.Charset,
) -> Unit {
  match slot {
    G0 => self.g0 = charset
    G1 => self.g1 = charset
    G2 => self.g2 = charset
    G3 => self.g3 = charset
  }
}

///|
pub fn ScreenCharsetState::invoke(
  self : ScreenCharsetState,
  active : @charsets.ActiveSlot,
  slot : @charsets.Slots,
  single : Bool,
) -> Unit {
  if single {
    self.single_shift = Some(slot)
    return
  }

  match active {
    Gl => self.gl = slot
    Gr => self.gr = slot
  }
}

///|
pub fn ScreenCharsetState::consume_single_shift(
  self : ScreenCharsetState,
) -> @charsets.Slots? {
  let shift = self.single_shift
  self.single_shift = None
  shift
}

///|
pub fn ScreenCharsetState::reset(self : ScreenCharsetState) -> Unit {
  self.g0 = Utf8
  self.g1 = Utf8
  self.g2 = Utf8
  self.g3 = Utf8
  self.gl = G0
  self.gr = G2
  self.single_shift = None
}

///|
struct ScreenSavedCursor {
  x : @size.CellCountInt
  y : @size.CellCountInt
  style : @style.CellStyle
  cursor_protected : Bool
  pending_wrap : Bool
  origin : Bool
  charset : ScreenCharsetState
} derive(Eq, Debug)

///|
pub fn ScreenSavedCursor::x(self : ScreenSavedCursor) -> @size.CellCountInt {
  self.x
}

///|
pub fn ScreenSavedCursor::y(self : ScreenSavedCursor) -> @size.CellCountInt {
  self.y
}

///|
pub fn ScreenSavedCursor::style(self : ScreenSavedCursor) -> @style.CellStyle {
  self.style
}

///|
pub fn ScreenSavedCursor::cursor_protected(self : ScreenSavedCursor) -> Bool {
  self.cursor_protected
}

///|
pub fn ScreenSavedCursor::pending_wrap(self : ScreenSavedCursor) -> Bool {
  self.pending_wrap
}

///|
pub fn ScreenSavedCursor::origin(self : ScreenSavedCursor) -> Bool {
  self.origin
}

///|
pub fn ScreenSavedCursor::charset(
  self : ScreenSavedCursor,
) -> ScreenCharsetState {
  copy_charset_state(self.charset)
}

///|
struct ScreenSavedCursorState {
  mut saved : ScreenSavedCursor?
} derive(Eq, Debug)

///|
pub fn ScreenSavedCursorState::new() -> ScreenSavedCursorState {
  { saved: None }
}

///|
pub fn ScreenSavedCursorState::has_saved(self : ScreenSavedCursorState) -> Bool {
  self.saved != None
}

///|
pub fn ScreenSavedCursorState::save(
  self : ScreenSavedCursorState,
  cursor : TerminalCursorState,
  style : @style.CellStyle,
  cursor_protected : Bool,
  origin : Bool,
  charset : ScreenCharsetState,
) -> Unit {
  self.saved = Some({
    x: cursor.x(),
    y: cursor.y(),
    style,
    cursor_protected,
    pending_wrap: cursor.pending_wrap(),
    origin,
    charset: copy_charset_state(charset),
  })
}

///|
pub fn ScreenSavedCursorState::restore(
  self : ScreenSavedCursorState,
) -> ScreenSavedCursor {
  match self.saved {
    Some(saved) => copy_saved_cursor(saved)
    None => default_saved_cursor()
  }
}

///|
pub fn ScreenSavedCursorState::reset(self : ScreenSavedCursorState) -> Unit {
  self.saved = None
}

///|
fn default_saved_cursor() -> ScreenSavedCursor {
  {
    x: 0,
    y: 0,
    style: @style.CellStyle::new(),
    cursor_protected: false,
    pending_wrap: false,
    origin: false,
    charset: ScreenCharsetState::new(),
  }
}

///|
fn copy_saved_cursor(saved : ScreenSavedCursor) -> ScreenSavedCursor {
  {
    x: saved.x,
    y: saved.y,
    style: saved.style,
    cursor_protected: saved.cursor_protected,
    pending_wrap: saved.pending_wrap,
    origin: saved.origin,
    charset: copy_charset_state(saved.charset),
  }
}

///|
fn copy_charset_state(state : ScreenCharsetState) -> ScreenCharsetState {
  {
    g0: state.g0,
    g1: state.g1,
    g2: state.g2,
    g3: state.g3,
    gl: state.gl,
    gr: state.gr,
    single_shift: state.single_shift,
  }
}
