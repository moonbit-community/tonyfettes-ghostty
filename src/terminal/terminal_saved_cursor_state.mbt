///|
struct ScreenCharsetState {
  mut g0 : Charset
  mut g1 : Charset
  mut g2 : Charset
  mut g3 : Charset
  mut gl : Slots
  mut gr : Slots
  mut single_shift : Slots?
} derive(Eq, Debug)

///|
pub fn ScreenCharsetState::new() -> ScreenCharsetState {
  {
    g0: Charset::Utf8,
    g1: Charset::Utf8,
    g2: Charset::Utf8,
    g3: Charset::Utf8,
    gl: Slots::G0,
    gr: Slots::G2,
    single_shift: None,
  }
}

///|
pub fn ScreenCharsetState::charset(
  self : ScreenCharsetState,
  slot : Slots,
) -> Charset {
  match slot {
    G0 => self.g0
    G1 => self.g1
    G2 => self.g2
    G3 => self.g3
  }
}

///|
pub fn ScreenCharsetState::gl(self : ScreenCharsetState) -> Slots {
  self.gl
}

///|
pub fn ScreenCharsetState::gr(self : ScreenCharsetState) -> Slots {
  self.gr
}

///|
pub fn ScreenCharsetState::single_shift(self : ScreenCharsetState) -> Slots? {
  self.single_shift
}

///|
pub fn ScreenCharsetState::configure(
  self : ScreenCharsetState,
  slot : Slots,
  charset : Charset,
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
  active : ActiveSlot,
  slot : Slots,
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
) -> Slots? {
  let shift = self.single_shift
  self.single_shift = None
  shift
}

///|
pub fn ScreenCharsetState::reset(self : ScreenCharsetState) -> Unit {
  self.g0 = Charset::Utf8
  self.g1 = Charset::Utf8
  self.g2 = Charset::Utf8
  self.g3 = Charset::Utf8
  self.gl = Slots::G0
  self.gr = Slots::G2
  self.single_shift = None
}

///|
struct ScreenSavedCursor {
  x : CellCountInt
  y : CellCountInt
  style : CellStyle
  cursor_protected : Bool
  pending_wrap : Bool
  origin : Bool
  charset : ScreenCharsetState
} derive(Eq, Debug)

///|
pub fn ScreenSavedCursor::x(self : ScreenSavedCursor) -> CellCountInt {
  self.x
}

///|
pub fn ScreenSavedCursor::y(self : ScreenSavedCursor) -> CellCountInt {
  self.y
}

///|
pub fn ScreenSavedCursor::style(self : ScreenSavedCursor) -> CellStyle {
  copy_cell_style(self.style)
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
  mut owner : TerminalScreen?
} derive(Eq, Debug)

///|
pub fn ScreenSavedCursorState::new() -> ScreenSavedCursorState {
  { saved: None, owner: None }
}

///|
pub fn ScreenSavedCursorState::has_saved(self : ScreenSavedCursorState) -> Bool {
  self.saved != None
}

///|
pub fn ScreenSavedCursorState::save(
  self : ScreenSavedCursorState,
  cursor : TerminalCursorState,
  style : CellStyle,
  cursor_protected : Bool,
  origin : Bool,
  charset : ScreenCharsetState,
) -> Unit {
  self.saved = Some({
    x: cursor.x(),
    y: cursor.y(),
    style: copy_cell_style(style),
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
  self.owner = None
}

///|
fn default_saved_cursor() -> ScreenSavedCursor {
  {
    x: 0,
    y: 0,
    style: CellStyle::new(),
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
    style: copy_cell_style(saved.style),
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

///|
fn copy_cell_style(style : CellStyle) -> CellStyle {
  {
    fg_color: style.fg_color,
    bg_color: style.bg_color,
    underline_color: style.underline_color,
    bold: style.bold,
    italic: style.italic,
    faint: style.faint,
    blink: style.blink,
    inverse: style.inverse,
    invisible: style.invisible,
    strikethrough: style.strikethrough,
    overline: style.overline,
    underline: style.underline,
  }
}
