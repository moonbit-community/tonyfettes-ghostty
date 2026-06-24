///|
priv struct StreamTerminalHandler {
  bridge : StreamTerminalBridgeState
}

///|
impl @stream.StreamHandler for StreamTerminalHandler with fn vt(self, action) {
  ignore(self.bridge.apply(action))
}

///|
// Print fast lane: `apply(StreamPrint(cp))` just calls `bridge.print(cp)` and
// returns `true` (which `vt` ignores), so go straight to it and skip building
// then matching a `StreamPrint` box on the per-character hot path.
impl @stream.StreamHandler for StreamTerminalHandler with fn print(
  self,
  codepoint,
) {
  self.bridge.print(codepoint)
}

///|
impl @stream.StreamHandler for StreamTerminalHandler with fn deinit(_self) {
  ()
}

///|
struct StreamTerminal {
  stream : @stream.Stream[StreamTerminalHandler]
}

///|
pub fn StreamTerminal::new(
  write_pty? : (Bytes) -> Unit = fn(_data) { () },
  bell? : () -> Unit = fn() { () },
  color_scheme? : () -> @device.ColorScheme? = fn() { None },
  device_attributes? : () -> @device.DeviceAttributes? = fn() { None },
  enquiry? : () -> Bytes = fn() { b"" },
  size? : () -> Size? = fn() { None },
  title_changed? : () -> Unit = fn() { () },
  xtversion? : () -> String = fn() { "" },
) -> StreamTerminal {
  let bridge = StreamTerminalBridgeState::with_effects(
    StreamTerminalBridgeEffects::new(
      write_pty~,
      bell~,
      color_scheme~,
      device_attributes~,
      enquiry~,
      size~,
      title_changed~,
      xtversion~,
    ),
  )
  { stream: @stream.Stream::new({ bridge, }) }
}

///|
pub fn StreamTerminal::deinit(self : StreamTerminal) -> Unit {
  self.stream.deinit()
}

///|
pub fn StreamTerminal::next(self : StreamTerminal, byte : Byte) -> Unit {
  self.stream.next(byte)
}

///|
pub fn StreamTerminal::next_slice(self : StreamTerminal, input : Bytes) -> Unit {
  self.stream.next_slice(input)
}

///|
pub fn StreamTerminal::reset(self : StreamTerminal) -> Unit {
  self.bridge().reset()
}

///|
pub fn StreamTerminal::title(self : StreamTerminal) -> String? {
  self.bridge().title()
}

///|
pub fn StreamTerminal::set_title(self : StreamTerminal, title : String) -> Unit {
  self.bridge().set_title(title)
}

///|
pub fn StreamTerminal::pwd(self : StreamTerminal) -> String? {
  self.bridge().pwd()
}

///|
pub fn StreamTerminal::set_pwd(self : StreamTerminal, pwd : String) -> Unit {
  self.bridge().set_pwd(pwd)
}

///|
pub fn StreamTerminal::cursor_x(self : StreamTerminal) -> CellCountInt {
  self.bridge().cursor_x()
}

///|
pub fn StreamTerminal::cursor_y(self : StreamTerminal) -> CellCountInt {
  self.bridge().cursor_y()
}

///|
pub fn StreamTerminal::cursor_visual_style(
  self : StreamTerminal,
) -> CursorVisualStyle {
  self.bridge().cursor_visual_style()
}

///|
pub fn StreamTerminal::cursor_visible(self : StreamTerminal) -> Bool {
  self.bridge().cursor_visible()
}

///|
pub fn StreamTerminal::cursor_pending_wrap(self : StreamTerminal) -> Bool {
  self.bridge().cursor_pending_wrap()
}

///|
pub fn StreamTerminal::cursor_top_margin(self : StreamTerminal) -> CellCountInt {
  self.bridge().cursor_top_margin()
}

///|
pub fn StreamTerminal::cursor_bottom_margin(
  self : StreamTerminal,
) -> CellCountInt {
  self.bridge().cursor_bottom_margin()
}

///|
pub fn StreamTerminal::cursor_left_margin(
  self : StreamTerminal,
) -> CellCountInt {
  self.bridge().cursor_left_margin()
}

///|
pub fn StreamTerminal::cursor_right_margin(
  self : StreamTerminal,
) -> CellCountInt {
  self.bridge().cursor_right_margin()
}

///|
pub fn StreamTerminal::kitty_keyboard_flags(
  self : StreamTerminal,
) -> @stream.KittyKeyboardFlags {
  self.bridge().kitty_keyboard_flags()
}

///|
pub fn StreamTerminal::mouse_tracking(self : StreamTerminal) -> Bool {
  self.bridge().mouse_tracking()
}

///|
pub fn StreamTerminal::palette_dirty(self : StreamTerminal) -> Bool {
  self.bridge().palette_dirty()
}

///|
pub fn StreamTerminal::clear_palette_dirty(self : StreamTerminal) -> Unit {
  self.bridge().clear_palette_dirty()
}

///|
pub fn StreamTerminal::take_scrollback_cleared(self : StreamTerminal) -> Bool {
  self.bridge().take_scrollback_cleared()
}

///|
pub fn StreamTerminal::mode_get(
  self : StreamTerminal,
  mode : @mode.Mode,
) -> Bool {
  self.bridge().mode_get(mode)
}

///|
pub fn StreamTerminal::mode_set(
  self : StreamTerminal,
  mode : @mode.Mode,
  enabled : Bool,
) -> Unit {
  self.bridge().mode_set(mode, enabled)
}

///|
pub fn StreamTerminal::resize(
  self : StreamTerminal,
  columns : CellCountInt,
  rows : CellCountInt,
  cell_width_px : UInt,
  cell_height_px : UInt,
) -> @result_code.TerminalResultCode {
  self.bridge().resize(columns, rows, cell_width_px, cell_height_px)
}

///|
pub fn StreamTerminal::scroll_viewport_top(self : StreamTerminal) -> Unit {
  self.bridge().scroll_viewport_top()
}

///|
pub fn StreamTerminal::scroll_viewport_bottom(self : StreamTerminal) -> Unit {
  self.bridge().scroll_viewport_bottom()
}

///|
pub fn StreamTerminal::scroll_viewport_delta(
  self : StreamTerminal,
  delta : Int,
) -> Unit {
  self.bridge().scroll_viewport_delta(delta)
}

///|
pub fn StreamTerminal::rows(self : StreamTerminal) -> CellCountInt {
  self.bridge().rows()
}

///|
pub fn StreamTerminal::columns(self : StreamTerminal) -> CellCountInt {
  self.bridge().columns()
}

///|
pub fn StreamTerminal::active_screen(self : StreamTerminal) -> TerminalScreen {
  self.bridge().active_screen()
}

///|
pub fn StreamTerminal::total_rows(self : StreamTerminal) -> UInt {
  self.bridge().total_rows()
}

///|
pub fn StreamTerminal::scrollback_rows(self : StreamTerminal) -> UInt {
  self.bridge().scrollback_rows()
}

///|
pub fn StreamTerminal::scrollbar(self : StreamTerminal) -> TerminalScrollbar {
  self.bridge().scrollbar()
}

///|
pub fn StreamTerminal::width_px(self : StreamTerminal) -> UInt {
  self.bridge().width_px()
}

///|
pub fn StreamTerminal::height_px(self : StreamTerminal) -> UInt {
  self.bridge().height_px()
}

///|
pub fn StreamTerminal::foreground_color(self : StreamTerminal) -> @color.RGB? {
  self.bridge().foreground_color()
}

///|
pub fn StreamTerminal::background_color(self : StreamTerminal) -> @color.RGB? {
  self.bridge().background_color()
}

///|
pub fn StreamTerminal::cursor_color(self : StreamTerminal) -> @color.RGB? {
  self.bridge().cursor_color()
}

///|
pub fn StreamTerminal::default_foreground_color(
  self : StreamTerminal,
) -> @color.RGB? {
  self.bridge().default_foreground_color()
}

///|
pub fn StreamTerminal::default_background_color(
  self : StreamTerminal,
) -> @color.RGB? {
  self.bridge().default_background_color()
}

///|
pub fn StreamTerminal::default_cursor_color(
  self : StreamTerminal,
) -> @color.RGB? {
  self.bridge().default_cursor_color()
}

///|
pub fn StreamTerminal::palette(self : StreamTerminal) -> Array[@color.RGB] {
  self.bridge().palette()
}

///|
pub fn StreamTerminal::default_palette(
  self : StreamTerminal,
) -> Array[@color.RGB] {
  self.bridge().default_palette()
}

///|
pub fn StreamTerminal::set_default_foreground_color(
  self : StreamTerminal,
  color : @color.RGB?,
) -> Unit {
  self.bridge().set_default_foreground_color(color)
}

///|
pub fn StreamTerminal::set_default_background_color(
  self : StreamTerminal,
  color : @color.RGB?,
) -> Unit {
  self.bridge().set_default_background_color(color)
}

///|
pub fn StreamTerminal::set_default_cursor_color(
  self : StreamTerminal,
  color : @color.RGB?,
) -> Unit {
  self.bridge().set_default_cursor_color(color)
}

///|
pub fn StreamTerminal::set_default_palette(
  self : StreamTerminal,
  palette : Array[@color.RGB]?,
) -> @result_code.TerminalResultCode {
  self.bridge().set_default_palette(palette)
}

///|
pub fn StreamTerminal::screen_row_snapshot(
  self : StreamTerminal,
  row : CellCountInt,
) -> @page.PageRowState? {
  self.bridge().screen_row_snapshot(row)
}

///|
pub fn StreamTerminal::semantic_prompt_row_range(
  self : StreamTerminal,
  row : CellCountInt,
) -> (CellCountInt, CellCountInt)? {
  self.bridge().semantic_prompt_row_range(row)
}

///|
pub fn StreamTerminal::pin(self : StreamTerminal, point : Point) -> Pin? {
  self.bridge().pin(point)
}

///|
pub fn StreamTerminal::untrack_pin(self : StreamTerminal, pin : Pin) -> Unit {
  self.bridge().untrack_pin(pin)
}

///|
pub fn StreamTerminal::point_from_pin(
  self : StreamTerminal,
  pin : Pin,
  tag : Tag,
) -> Coordinate? {
  self.bridge().point_from_pin(pin, tag)
}

///|
pub fn StreamTerminal::selection(
  self : StreamTerminal,
  start : Point,
  end_ : Point,
  rectangle : Bool,
) -> Selection? {
  match self.pin(start) {
    None => None
    Some(start_pin) =>
      match self.pin(end_) {
        Some(end_pin) => Some(Selection::new(start_pin, end_pin, rectangle))
        None => {
          self.untrack_pin(start_pin)
          None
        }
      }
  }
}

///|
pub fn StreamTerminal::untrack_selection(
  self : StreamTerminal,
  selection : Selection,
) -> Unit {
  self.untrack_pin(selection.start())
  self.untrack_pin(selection.end())
}

///|
pub fn StreamTerminal::set_write_pty(
  self : StreamTerminal,
  callback : (Bytes) -> Unit,
) -> Unit {
  self.bridge().set_write_pty(callback)
}

///|
pub fn StreamTerminal::clear_write_pty(self : StreamTerminal) -> Unit {
  self.bridge().clear_write_pty()
}

///|
pub fn StreamTerminal::set_bell(
  self : StreamTerminal,
  callback : () -> Unit,
) -> Unit {
  self.bridge().set_bell(callback)
}

///|
pub fn StreamTerminal::clear_bell(self : StreamTerminal) -> Unit {
  self.bridge().clear_bell()
}

///|
pub fn StreamTerminal::set_color_scheme(
  self : StreamTerminal,
  callback : () -> @device.ColorScheme?,
) -> Unit {
  self.bridge().set_color_scheme(callback)
}

///|
pub fn StreamTerminal::clear_color_scheme(self : StreamTerminal) -> Unit {
  self.bridge().clear_color_scheme()
}

///|
pub fn StreamTerminal::set_device_attributes(
  self : StreamTerminal,
  callback : () -> @device.DeviceAttributes?,
) -> Unit {
  self.bridge().set_device_attributes(callback)
}

///|
pub fn StreamTerminal::clear_device_attributes(self : StreamTerminal) -> Unit {
  self.bridge().clear_device_attributes()
}

///|
pub fn StreamTerminal::set_enquiry(
  self : StreamTerminal,
  callback : () -> Bytes,
) -> Unit {
  self.bridge().set_enquiry(callback)
}

///|
pub fn StreamTerminal::clear_enquiry(self : StreamTerminal) -> Unit {
  self.bridge().clear_enquiry()
}

///|
pub fn StreamTerminal::set_size(
  self : StreamTerminal,
  callback : () -> Size?,
) -> Unit {
  self.bridge().set_size(callback)
}

///|
pub fn StreamTerminal::clear_size(self : StreamTerminal) -> Unit {
  self.bridge().clear_size()
}

///|
pub fn StreamTerminal::set_title_changed(
  self : StreamTerminal,
  callback : () -> Unit,
) -> Unit {
  self.bridge().set_title_changed(callback)
}

///|
pub fn StreamTerminal::clear_title_changed(self : StreamTerminal) -> Unit {
  self.bridge().clear_title_changed()
}

///|
pub fn StreamTerminal::set_xtversion(
  self : StreamTerminal,
  callback : () -> String,
) -> Unit {
  self.bridge().set_xtversion(callback)
}

///|
pub fn StreamTerminal::clear_xtversion(self : StreamTerminal) -> Unit {
  self.bridge().clear_xtversion()
}

///|
pub fn StreamTerminal::screen_cell_snapshot(
  self : StreamTerminal,
  row : CellCountInt,
  col : CellCountInt,
) -> @page.PageCellState? {
  self.bridge().screen_cell_snapshot(row, col)
}

///|
// The raw `@hyperlink.HyperlinkId` of the snapshot cell at (row, col) — package-private, for
// `RenderState`'s damage diff (a hyperlink-only change leaves the packed cell
// equal, so the id is compared alongside it). The full link still resolves via
// `screen_cell_hyperlink_snapshot`.
fn StreamTerminal::screen_cell_hyperlink_id_snapshot(
  self : StreamTerminal,
  row : CellCountInt,
  col : CellCountInt,
) -> @hyperlink.HyperlinkId {
  self.bridge().screen_cell_hyperlink_id_snapshot(row, col)
}

///|
// Resolve the style of the snapshot cell at (row, col) through the active screen's
// table. Cells store only a `StyleId`, so callers that want the full `CellStyle`
// (color, attributes) go through here rather than the cell directly.
pub fn StreamTerminal::screen_cell_style_snapshot(
  self : StreamTerminal,
  row : CellCountInt,
  col : CellCountInt,
) -> @style.CellStyle? {
  match self.bridge().screen_cell_snapshot(row, col) {
    Some(cell) => Some(self.active_style_table().get(cell.style_id()))
    None => None
  }
}

///|
// Resolve the hyperlink of the snapshot cell at (row, col), or `None` if the cell
// is absent or carries no link. The id is stored out-of-cell in the row's
// `link_ids` side array, so this resolves by position, not from the cell value.
pub fn StreamTerminal::screen_cell_hyperlink_snapshot(
  self : StreamTerminal,
  row : CellCountInt,
  col : CellCountInt,
) -> @hyperlink.CellHyperlink? {
  self.bridge().screen_cell_hyperlink_snapshot(row, col)
}

///|
// Resolve the combining codepoints of the snapshot cell at (row, col), empty if
// the cell is absent or not a grapheme cluster. Cells store only a `@page.GraphemeId`.
pub fn StreamTerminal::screen_cell_grapheme_codepoints_snapshot(
  self : StreamTerminal,
  row : CellCountInt,
  col : CellCountInt,
) -> ReadOnlyArray[UInt] {
  match self.bridge().screen_cell_snapshot(row, col) {
    Some(cell) => self.active_grapheme_table().get(cell.grapheme_id())
    None => []
  }
}

///|
fn StreamTerminal::bridge(self : StreamTerminal) -> StreamTerminalBridgeState {
  self.stream.handler().bridge
}

///|
// The active screen's style intern table. Snapshotted cells carry `StyleId`s
// minted from it, so renderers/formatters resolve their styles through it. The
// active grid shares its `PageList`'s table, which also covers scrollback rows.
fn StreamTerminal::active_style_table(
  self : StreamTerminal,
) -> @style.StyleTable {
  self.bridge().grid.style_table
}

///|
// The active screen's grapheme intern table (see `active_style_table`).
fn StreamTerminal::active_grapheme_table(
  self : StreamTerminal,
) -> @page.GraphemeTable {
  self.bridge().grid.grapheme_table
}

///|
// The active screen's hyperlink intern table (see `active_style_table`). Captured
// by `RenderState` so a render-snapshot-driven renderer can resolve a cell's OSC 8
// uri from the snapshot alone, the same way it resolves styles and graphemes.
fn StreamTerminal::active_hyperlink_table(
  self : StreamTerminal,
) -> @hyperlink.HyperlinkTable {
  self.bridge().grid.hyperlink_table
}
