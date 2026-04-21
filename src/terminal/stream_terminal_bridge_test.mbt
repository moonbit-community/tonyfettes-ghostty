///|
test "stream terminal bridge/default state and handled bell" {
  let state = StreamTerminalBridgeState::new()
  guard !state.palette_dirty() else {
    fail("expected palette dirty to start false")
  }
  guard state.mode_enabled(Mode::Wraparound) &&
    state.mode_enabled(Mode::CursorVisible) else {
    fail("expected default mode set")
  }
  guard state.display_state().status_display() == StatusDisplay::Main else {
    fail("expected default status display")
  }
  guard state.display_state().mouse_shape() == MouseShape::Text else {
    fail("expected default mouse shape")
  }
  guard state.protected_state().mode() == ProtectedMode::Off &&
    !state.protected_state().cursor_protected() else {
    fail("expected default protected state")
  }
  guard state.cursor_x() == 0 &&
    state.cursor_y() == 0 &&
    state.cursor_visual_style() == CursorVisualStyle::Block &&
    !state.cursor_pending_wrap() &&
    state.cursor_top_margin() == 0 &&
    state.cursor_bottom_margin() == 23 &&
    state.cursor_left_margin() == 0 &&
    state.cursor_right_margin() == 79 else {
    fail("expected default cursor state")
  }
  guard state.mouse_event() == MouseEvent::None &&
    state.mouse_format() == MouseFormat::X10 else {
    fail("expected default mouse reporting state")
  }
  guard !state.modify_other_keys_2() &&
    state.mouse_shift_capture() == None &&
    state.kitty_keyboard_flags() == KittyKeyboardFlags(0) else {
    fail("expected default input state")
  }
  guard state.charset(Slots::G0) == Charset::Utf8 &&
    state.charset_gl() == Slots::G0 &&
    state.charset_gr() == Slots::G2 &&
    state.charset_single_shift() == None &&
    !state.has_saved_cursor() else {
    fail("expected default charset/save state")
  }
  guard state.tabstop(8) && !state.tabstop(0) else {
    fail("expected default tabstop layout")
  }

  guard state.apply(StreamRestoreCursor) else {
    fail("expected restore cursor to be handled")
  }
  guard state.cursor_x() == 0 &&
    state.cursor_y() == 0 &&
    state.charset_gl() == Slots::G0 else {
    fail("expected restore without save to keep defaults")
  }

  guard state.apply(StreamBell) else {
    fail("expected bell action to be handled")
  }
}

///|
struct BridgeStreamRecorder {
  actions : Array[StreamAction]
}

///|
impl StreamHandler for BridgeStreamRecorder with vt(self, action) {
  self.actions.push(action)
}

///|
impl StreamHandler for BridgeStreamRecorder with deinit(_self) {
  ()
}

///|
struct BridgeEffectsRecorder {
  writes : Array[Bytes]
  mut bell_count : Int
  mut title_changed_count : Int
}

///|
fn BridgeEffectsRecorder::new() -> BridgeEffectsRecorder {
  { writes: [], bell_count: 0, title_changed_count: 0 }
}

///|
fn BridgeEffectsRecorder::write_pty(
  self : BridgeEffectsRecorder,
  data : Bytes,
) -> Unit {
  self.writes.push(data)
}

///|
fn BridgeEffectsRecorder::bell(self : BridgeEffectsRecorder) -> Unit {
  self.bell_count += 1
}

///|
fn BridgeEffectsRecorder::title_changed(self : BridgeEffectsRecorder) -> Unit {
  self.title_changed_count += 1
}

///|
fn expect_effect_write(
  recorder : BridgeEffectsRecorder,
  index : Int,
  expected : Bytes,
) -> Unit raise {
  guard recorder.writes[index] == expected else {
    fail("expected captured PTY write")
  }
}

///|
fn ascii_string(byte : Byte, count : Int) -> String {
  let buffer = @buffer.new(size_hint=count)
  for _ in 0..<count {
    buffer.write_byte(byte)
  }
  buffer.to_string()
}

///|
fn apply_stream_bytes(state : StreamTerminalBridgeState, bytes : Bytes) -> Bool {
  let actions : Array[StreamAction] = []
  let recorder : BridgeStreamRecorder = { actions, }
  let stream = Stream::new(recorder)
  stream.next_slice(bytes)
  stream.deinit()
  for action in actions {
    if !state.apply(action) {
      return false
    }
  }
  true
}

///|
fn expect_bridge_row(
  state : StreamTerminalBridgeState,
  row : CellCountInt,
) -> PageRowState {
  state.screen_row_snapshot(row).unwrap()
}

///|
fn expect_bridge_cell(
  state : StreamTerminalBridgeState,
  row : CellCountInt,
  col : CellCountInt,
) -> PageCellState {
  state.screen_cell_snapshot(row, col).unwrap()
}

///|
test "stream terminal bridge/applies printable semantic hyperlink actions" {
  let state = StreamTerminalBridgeState::new()

  guard apply_stream_bytes(state, b"\x1B]133;A;click_events=1\x07") &&
    apply_stream_bytes(state, b"\x1B[1;46m") &&
    apply_stream_bytes(state, b"\x1B]8;;https://example.com\x07") &&
    apply_stream_bytes(state, b"A\x1B[2b") &&
    apply_stream_bytes(state, b"\x1B]8;;\x07B") else {
    fail("expected printable stream bytes to be handled")
  }

  let style = state.current_style_snapshot()
  guard style.bold() &&
    style.bg_color().palette_index() == Some(Name::Cyan.code()) else {
    fail("expected current style to preserve bold and background color")
  }
  guard state.semantic_click_mode() == SemanticClickMode::ClickEvents &&
    state.semantic_cursor_content() == SemanticContent::Prompt &&
    state.semantic_row_prompt() == RowSemanticPrompt::Prompt &&
    !state.hyperlink_active() else {
    fail("expected semantic prompt and hyperlink state")
  }

  let row = expect_bridge_row(state, 0)
  guard row.semantic_prompt() == RowSemanticPrompt::Prompt &&
    row.styled() &&
    row.hyperlink() &&
    row.dirty() else {
    fail("expected printed row metadata")
  }

  let first = expect_bridge_cell(state, 0, 0)
  guard first.codepoint() == b'A'.to_uint() &&
    first.semantic_content() == SemanticContent::Prompt &&
    first.style().bold() &&
    first.style().bg_color().palette_index() == Some(Name::Cyan.code()) else {
    fail("expected first cell style and semantic metadata")
  }
  let first_link_ok = match first.hyperlink() {
    Some(link) =>
      link.uri() == "https://example.com" &&
      link.explicit_id() == None &&
      link.implicit_id() == Some(0)
    None => false
  }
  guard first_link_ok else { fail("expected implicit hyperlink metadata") }

  guard expect_bridge_cell(state, 0, 1).codepoint() == b'A'.to_uint() &&
    expect_bridge_cell(state, 0, 2).codepoint() == b'A'.to_uint() &&
    expect_bridge_cell(state, 0, 3).codepoint() == b'B'.to_uint() &&
    expect_bridge_cell(state, 0, 3).hyperlink() == None else {
    fail("expected repeat-print and hyperlink end behavior")
  }
}

///|
test "stream terminal bridge/applies semantic newline transitions" {
  let state = StreamTerminalBridgeState::new()

  guard apply_stream_bytes(state, b"Hello\x1B]133;N\x07") else {
    fail("expected semantic new-command bytes to be handled")
  }
  guard state.cursor_x() == 0 &&
    state.cursor_y() == 1 &&
    state.semantic_cursor_content() == SemanticContent::Prompt &&
    state.semantic_row_prompt() == RowSemanticPrompt::Prompt else {
    fail("expected new-command semantic prompt to fresh-line")
  }
  guard expect_bridge_row(state, 1).semantic_prompt() ==
    RowSemanticPrompt::Prompt else {
    fail("expected prompt row metadata after new-command")
  }

  guard apply_stream_bytes(state, b"\x1B]133;I\x07\n") else {
    fail("expected semantic linefeed bytes to be handled")
  }
  guard state.cursor_x() == 0 &&
    state.cursor_y() == 2 &&
    state.semantic_cursor_content() == SemanticContent::Output &&
    !state.semantic_cursor_content_clear_eol() &&
    expect_bridge_row(state, 2).semantic_prompt() == RowSemanticPrompt::None else {
    fail("expected terminate-eol input to clear on linefeed")
  }
}

///|
test "stream terminal bridge/applies reverse index at the top margin" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(StreamTopAndBottomMargin({ top_left: 2, bottom_right: 3 })) else {
    fail("expected top/bottom margin setup")
  }
  guard state.apply(StreamCursorPos({ row: 2, col: 1 })) else {
    fail("expected cursor move to top margin")
  }
  guard apply_stream_bytes(state, b"A") else {
    fail("expected first reverse-index row write")
  }
  guard state.apply(StreamCursorPos({ row: 3, col: 1 })) else {
    fail("expected cursor move inside scroll region")
  }
  guard apply_stream_bytes(state, b"B") else {
    fail("expected second reverse-index row write")
  }
  guard state.apply(StreamCursorPos({ row: 2, col: 1 })) else {
    fail("expected cursor reset to top margin")
  }

  guard apply_stream_bytes(state, b"\x1BM") else {
    fail("expected reverse index bytes to be handled")
  }
  guard state.cursor_x() == 0 && state.cursor_y() == 1 else {
    fail("expected reverse index cursor position")
  }
  guard expect_bridge_cell(state, 1, 0).is_empty() &&
    expect_bridge_cell(state, 2, 0).codepoint() == b'A'.to_uint() else {
    fail("expected reverse index to scroll region downward")
  }
}

///|
test "stream terminal bridge/applies edit and scroll mutations" {
  let state = StreamTerminalBridgeState::new()

  guard apply_stream_bytes(state, b"ABCDE") &&
    apply_stream_bytes(state, b"\r\x1B[2C\x1B[2P") else {
    fail("expected delete-char bytes to be handled")
  }
  guard expect_bridge_cell(state, 0, 0).codepoint() == b'A'.to_uint() &&
    expect_bridge_cell(state, 0, 1).codepoint() == b'B'.to_uint() &&
    expect_bridge_cell(state, 0, 2).codepoint() == b'E'.to_uint() &&
    expect_bridge_cell(state, 0, 3).is_empty() else {
    fail("expected delete chars bridge behavior")
  }

  guard apply_stream_bytes(state, b"\r\x1B[3C") else {
    fail("expected erase-char cursor bytes to be handled")
  }
  guard state.apply(StreamSetAttribute(Color256Bg(5))) else {
    fail("expected background style setup")
  }
  guard apply_stream_bytes(state, b"\x1B[X") else {
    fail("expected erase-char bytes to be handled")
  }
  guard expect_bridge_cell(state, 0, 3).palette_index() == Some(5) else {
    fail("expected erase chars to preserve current background style")
  }

  let pending_wrap = StreamTerminalBridgeState::new()
  guard pending_wrap.apply(StreamCursorPos({ row: 1, col: 80 })) else {
    fail("expected pending-wrap cursor setup")
  }
  guard apply_stream_bytes(pending_wrap, b"Z") else {
    fail("expected pending-wrap print bytes to be handled")
  }
  guard pending_wrap.cursor_pending_wrap() else {
    fail("expected print at right edge to enter pending wrap")
  }
  guard pending_wrap.apply(StreamEraseLineRightUnlessPendingWrap(false)) else {
    fail("expected right-unless-pending-wrap action to be handled")
  }
  guard expect_bridge_cell(pending_wrap, 0, 79).codepoint() == b'Z'.to_uint() else {
    fail("expected pending-wrap erase-right guard to no-op")
  }

  let scroll = StreamTerminalBridgeState::new()
  guard apply_stream_bytes(scroll, b"A\x1BEB\x1BEC") else {
    fail("expected scroll population bytes to be handled")
  }
  guard scroll.apply(StreamCursorPos({ row: 1, col: 1 })) else {
    fail("expected scroll cursor reset")
  }
  guard scroll.apply(StreamScrollUp(1)) else {
    fail("expected scroll up to be handled")
  }
  guard expect_bridge_cell(scroll, 0, 0).codepoint() == b'B'.to_uint() &&
    expect_bridge_cell(scroll, 1, 0).codepoint() == b'C'.to_uint() else {
    fail("expected scroll up to move rows")
  }
  guard scroll.apply(StreamScrollDown(1)) else {
    fail("expected scroll down to be handled")
  }
  guard expect_bridge_cell(scroll, 0, 0).is_empty() &&
    expect_bridge_cell(scroll, 1, 0).codepoint() == b'B'.to_uint() else {
    fail("expected scroll down to insert a blank row")
  }
}

///|
test "stream terminal bridge/applies decaln full reset and kitty color protocol" {
  let state = StreamTerminalBridgeState::new()

  guard apply_stream_bytes(
    state, b"\x1B]21;5=rgb:01/02/03;foreground=rgb:04/05/06\x07",
  ) else {
    fail("expected kitty color bytes to be handled")
  }
  guard state.palette_dirty() &&
    state.colors().palette_color(5) == RGB::new(1, 2, 3) &&
    state.colors().foreground() == Some(RGB::new(4, 5, 6)) else {
    fail("expected kitty color protocol mutation")
  }

  guard apply_stream_bytes(state, b"\x1B[1;31;42m") &&
    apply_stream_bytes(state, b"\x1B]8;;https://example.com\x07") &&
    apply_stream_bytes(state, b"\x1B]133;A\x07") &&
    apply_stream_bytes(state, b"X") &&
    apply_stream_bytes(state, b"\x1B#8") else {
    fail("expected decaln setup bytes to be handled")
  }

  let decaln_style = state.current_style_snapshot()
  guard !decaln_style.bold() &&
    decaln_style.fg_color().palette_index() == Some(Name::Red.code()) &&
    decaln_style.bg_color().palette_index() == Some(Name::Green.code()) &&
    expect_bridge_cell(state, 0, 0).codepoint() == b'E'.to_uint() &&
    state.cursor_x() == 0 &&
    state.cursor_y() == 0 else {
    fail("expected decaln bridge behavior")
  }

  guard apply_stream_bytes(state, b"\x1Bc") else {
    fail("expected full-reset bytes to be handled")
  }
  guard !state.palette_dirty() &&
    expect_bridge_cell(state, 0, 0).is_empty() &&
    state.cursor_x() == 0 &&
    state.cursor_y() == 0 &&
    state.current_style_snapshot().is_default() &&
    !state.hyperlink_active() &&
    state.semantic_cursor_content() == SemanticContent::Output &&
    state.colors().palette_color(5) == RGB::new(1, 2, 3) &&
    state.colors().foreground() == Some(RGB::new(4, 5, 6)) else {
    fail("expected full reset bridge behavior")
  }
}

///|
test "stream terminal bridge/covers accessors and print guard branches" {
  let state = StreamTerminalBridgeState::new()

  guard state.title() == None &&
    state.shell_redraws_prompt() == SemanticPromptRedraw::Enabled &&
    state.hyperlink_uri() == None &&
    state.hyperlink_explicit_id() == None &&
    state.hyperlink_implicit_id() == None &&
    state.screen_row_snapshot(24) == None &&
    state.screen_cell_snapshot(0, 80) == None else {
    fail("expected default metadata and out-of-bounds accessors")
  }

  guard state.apply(StreamSetMode(Mode::EnableLeftAndRightMargin)) &&
    state.apply(StreamLeftAndRightMargin({ top_left: 11, bottom_right: 20 })) &&
    state.apply(StreamSetMode(Mode::Origin)) &&
    state.apply(StreamCursorPos({ row: 1, col: 15 })) &&
    state.apply(StreamCarriageReturn) else {
    fail("expected carriage-return origin setup")
  }
  guard state.cursor_x() == 10 else {
    fail("expected carriage return to honor origin left margin")
  }

  guard state.apply(StreamResetMode(Mode::Origin)) &&
    state.apply(StreamCursorPos({ row: 1, col: 1 })) &&
    state.apply(StreamCarriageReturn) else {
    fail("expected carriage-return non-origin setup")
  }
  guard state.cursor_x() == 0 else {
    fail("expected carriage return to fall back to column zero")
  }

  guard state.apply(StreamActiveStatusDisplay(StatusDisplay::StatusLine)) &&
    state.apply(StreamPrint(b'X'.to_uint())) else {
    fail("expected status-line print to be handled")
  }
  guard expect_bridge_cell(state, 0, 0).is_empty() else {
    fail("expected print to no-op outside the main display")
  }

  guard state.apply(StreamActiveStatusDisplay(StatusDisplay::Main)) &&
    state.apply(StreamPrint(0U)) &&
    state.apply(StreamPrintRepeat(2)) &&
    state.apply(StreamPrint(0x4E2DU)) else {
    fail("expected zero-width, repeat-none, and wide print paths")
  }
  guard expect_bridge_cell(state, 0, 0).wide() == PageCellWide::Wide &&
    expect_bridge_cell(state, 0, 1).wide() == PageCellWide::SpacerTail else {
    fail("expected wide print layout")
  }
}

///|
test "stream terminal bridge/covers semantic prompt variants and explicit hyperlinks" {
  let state = StreamTerminalBridgeState::new()

  guard apply_stream_bytes(state, b"Hi\x1B]133;L\x07") &&
    apply_stream_bytes(state, b"\x1B]133;A;redraw=0\x07") else {
    fail("expected fresh-line semantic prompt bytes")
  }
  guard state.cursor_x() == 0 &&
    state.cursor_y() == 1 &&
    state.shell_redraws_prompt() == SemanticPromptRedraw::Disabled &&
    state.semantic_cursor_content() == SemanticContent::Prompt else {
    fail("expected fresh-line and redraw semantic prompt behavior")
  }

  guard apply_stream_bytes(state, b"\x1B]8;id=foo;http://example.com\x07X") else {
    fail("expected explicit hyperlink bytes")
  }
  guard state.hyperlink_uri() == Some("http://example.com") &&
    state.hyperlink_explicit_id() == Some("foo") &&
    state.hyperlink_implicit_id() == None else {
    fail("expected explicit hyperlink accessors")
  }
  let explicit_link_ok = match expect_bridge_cell(state, 1, 0).hyperlink() {
    Some(link) =>
      link.uri() == "http://example.com" && link.explicit_id() == Some("foo")
    None => false
  }
  guard explicit_link_ok else {
    fail("expected explicit hyperlink to be written to the grid")
  }

  guard apply_stream_bytes(state, b"\x1B]133;P;k=c\x07") &&
    apply_stream_bytes(state, b"\x1B]133;B\x07") else {
    fail("expected prompt-start and input-start bytes")
  }
  guard state.semantic_row_prompt() == RowSemanticPrompt::PromptContinuation &&
    state.semantic_cursor_content() == SemanticContent::Input &&
    !state.semantic_cursor_content_clear_eol() else {
    fail("expected prompt-start continuation and input state")
  }

  let reset_row = StreamTerminalBridgeState::new()
  guard apply_stream_bytes(reset_row, b"\x1B]133;P;k=i\x07") &&
    apply_stream_bytes(reset_row, b"\x1B]133;C\x07") &&
    apply_stream_bytes(reset_row, b"\x1B]133;D\x07") else {
    fail("expected output and end-command semantic bytes")
  }
  guard reset_row.semantic_cursor_content() == SemanticContent::Output &&
    expect_bridge_row(reset_row, 0).semantic_prompt() == RowSemanticPrompt::None else {
    fail("expected output transition to clear row prompt at column zero")
  }
}

///|
test "stream terminal bridge/covers movement helper branches" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(StreamBackspace) else {
    fail("expected backspace to be handled")
  }

  guard state.apply(StreamSetMode(Mode::Linefeed)) &&
    apply_stream_bytes(state, b"AB") &&
    state.apply(StreamLinefeed) else {
    fail("expected linefeed-mode setup")
  }
  guard state.cursor_x() == 0 && state.cursor_y() == 1 else {
    fail("expected linefeed mode to add carriage return")
  }

  guard state.apply(StreamSetMode(Mode::EnableLeftAndRightMargin)) &&
    state.apply(StreamLeftAndRightMargin({ top_left: 11, bottom_right: 20 })) &&
    state.apply(StreamCursorPos({ row: 5, col: 1 })) &&
    state.apply(StreamIndex) else {
    fail("expected index setup outside scroll region")
  }
  guard state.cursor_y() == 5 else {
    fail("expected index outside the scroll region to move down one row")
  }

  guard state.apply(StreamReverseIndex) else {
    fail("expected reverse index outside top margin to be handled")
  }
  guard state.cursor_y() == 4 else {
    fail("expected reverse index outside top margin to move the cursor up")
  }
}

///|
test "stream terminal bridge/covers erase and insertion bridge arms" {
  let state = StreamTerminalBridgeState::new()
  guard apply_stream_bytes(state, b"ABC\x1BEDEF") &&
    state.apply(StreamSetAttribute(Color256Bg(4))) else {
    fail("expected erase bridge setup")
  }

  guard state.apply(StreamEraseDisplayBelow(false)) &&
    state.apply(StreamEraseDisplayAbove(false)) &&
    state.apply(StreamEraseDisplayComplete(false)) &&
    state.apply(StreamEraseDisplayScrollback(false)) &&
    state.apply(StreamEraseDisplayScrollComplete(false)) else {
    fail("expected erase-display actions to be handled")
  }

  guard apply_stream_bytes(state, b"ABCDE") &&
    state.apply(StreamCursorPos({ row: 1, col: 3 })) &&
    state.apply(StreamEraseLineRight(false)) &&
    state.apply(StreamEraseLineLeft(false)) &&
    state.apply(StreamEraseLineComplete(false)) else {
    fail("expected erase-line actions to be handled")
  }

  guard apply_stream_bytes(state, b"ABCDE") &&
    state.apply(StreamCursorPos({ row: 1, col: 3 })) &&
    state.apply(StreamEraseLineRightUnlessPendingWrap(false)) else {
    fail("expected erase-line-right-unless-pending-wrap action")
  }
  guard expect_bridge_cell(state, 0, 2).palette_index() == Some(4) else {
    fail(
      "expected erase-line-right-unless-pending-wrap to erase when not pending wrap",
    )
  }

  guard state.apply(StreamInsertLines(1)) &&
    state.apply(StreamInsertBlanks(1)) &&
    state.apply(StreamDeleteLines(1)) else {
    fail("expected line insertion and deletion actions to be handled")
  }
}

///|
test "stream terminal bridge/covers kitty color query and reset branches" {
  let state = StreamTerminalBridgeState::new()

  guard apply_stream_bytes(
    state, b"\x1B]21;foreground=rgb:01/02/03;foreground=?;background=rgb:07/08/09;cursor=rgb:0A/0B/0C;selection_background=rgb:0D/0E/0F\x07",
  ) else {
    fail("expected kitty color set/query bytes")
  }
  guard state.colors().foreground() == Some(RGB::new(1, 2, 3)) &&
    state.colors().background() == Some(RGB::new(7, 8, 9)) &&
    state.colors().cursor() == Some(RGB::new(10, 11, 12)) else {
    fail("expected kitty color set branches")
  }

  guard apply_stream_bytes(
    state, b"\x1B]21;5=rgb:11/12/13;5=;foreground=;background=;cursor=;selection_background=\x07",
  ) else {
    fail("expected kitty color reset bytes")
  }
  guard state.colors().palette_color(5) == Name::Magenta.default_rgb() &&
    state.colors().foreground() == None &&
    state.colors().background() == None &&
    state.colors().cursor() == None else {
    fail("expected kitty color reset branches")
  }
}

///|
test "stream terminal bridge/covers repeat print and remaining semantic branches" {
  let repeat_state = StreamTerminalBridgeState::new()
  guard apply_stream_bytes(repeat_state, b"A") &&
    repeat_state.apply(StreamActiveStatusDisplay(StatusDisplay::StatusLine)) &&
    repeat_state.apply(StreamPrintRepeat(3)) else {
    fail("expected repeat-print status-display setup")
  }
  guard expect_bridge_cell(repeat_state, 0, 0).codepoint() == b'A'.to_uint() &&
    expect_bridge_cell(repeat_state, 0, 1).is_empty() else {
    fail("expected repeat print to no-op outside the main display")
  }

  let semantic_state = StreamTerminalBridgeState::new()
  guard apply_stream_bytes(semantic_state, b"Q\x1B]133;N;redraw=last\x07") else {
    fail("expected new-command redraw bytes")
  }
  guard semantic_state.shell_redraws_prompt() == SemanticPromptRedraw::Last else {
    fail("expected new-command redraw metadata")
  }

  let fresh_line_state = StreamTerminalBridgeState::new()
  guard fresh_line_state.apply(StreamSetMode(Mode::EnableLeftAndRightMargin)) &&
    fresh_line_state.apply(
      StreamLeftAndRightMargin({ top_left: 11, bottom_right: 20 }),
    ) &&
    apply_stream_bytes(fresh_line_state, b"\x1B]133;L\x07") else {
    fail("expected fresh-line left-margin bytes")
  }
  guard fresh_line_state.cursor_x() == 0 && fresh_line_state.cursor_y() == 0 else {
    fail("expected fresh line at x<left-margin to no-op")
  }
}

///|
test "stream terminal bridge/covers cursor-left wrap modes" {
  let plain = StreamTerminalBridgeState::new()
  guard plain.apply(StreamResetMode(Mode::Wraparound)) &&
    plain.apply(StreamCursorPos({ row: 2, col: 4 })) &&
    plain.apply(StreamCursorLeft(CursorMovement(1))) else {
    fail("expected plain cursor-left setup")
  }
  guard plain.cursor_x() == 2 && plain.cursor_y() == 1 else {
    fail("expected cursor-left without wraparound")
  }

  let reverse = StreamTerminalBridgeState::new()
  guard reverse.apply(StreamSetMode(Mode::ReverseWrap)) &&
    reverse.apply(StreamCursorLeft(CursorMovement(1))) else {
    fail("expected reverse-wrap cursor-left setup")
  }
  guard reverse.cursor_x() == 0 && reverse.cursor_y() == 0 else {
    fail("expected reverse-wrap top-left clamp")
  }

  let pending = StreamTerminalBridgeState::new()
  guard pending.apply(StreamSetMode(Mode::ReverseWrap)) &&
    pending.apply(StreamCursorPos({ row: 1, col: 80 })) &&
    apply_stream_bytes(pending, b"Z") &&
    pending.apply(StreamCursorLeft(CursorMovement(1))) else {
    fail("expected pending-wrap cursor-left setup")
  }
  guard !pending.cursor_pending_wrap() &&
    pending.cursor_x() == 79 &&
    pending.cursor_y() == 0 else {
    fail("expected pending-wrap cursor-left to consume the wrap flag")
  }

  let extended = StreamTerminalBridgeState::new()
  guard extended.apply(
      StreamTopAndBottomMargin({ top_left: 2, bottom_right: 3 }),
    ) &&
    extended.apply(StreamSetMode(Mode::ReverseWrapExtended)) &&
    extended.apply(StreamCursorPos({ row: 2, col: 1 })) &&
    extended.apply(StreamCursorLeft(CursorMovement(1))) else {
    fail("expected reverse-wrap-extended cursor-left setup")
  }
  guard extended.cursor_x() == 79 && extended.cursor_y() == 2 else {
    fail("expected reverse-wrap-extended top wrap")
  }

  let left_margin_branch = StreamTerminalBridgeState::new()
  guard left_margin_branch.apply(StreamSetMode(Mode::EnableLeftAndRightMargin)) &&
    left_margin_branch.apply(
      StreamLeftAndRightMargin({ top_left: 11, bottom_right: 20 }),
    ) &&
    left_margin_branch.apply(StreamSetMode(Mode::ReverseWrapExtended)) &&
    left_margin_branch.apply(StreamCursorPos({ row: 2, col: 1 })) &&
    left_margin_branch.apply(StreamCursorLeft(CursorMovement(1))) else {
    fail("expected reverse-wrap-extended left-margin setup")
  }
  guard left_margin_branch.cursor_x() == 19 &&
    left_margin_branch.cursor_y() == 0 else {
    fail("expected x<left-margin reverse wrap behavior")
  }

  let top_return = StreamTerminalBridgeState::new()
  guard top_return.apply(StreamSetMode(Mode::ReverseWrap)) &&
    top_return.apply(StreamCursorPos({ row: 1, col: 2 })) &&
    top_return.apply(StreamCursorLeft(CursorMovement(2))) else {
    fail("expected reverse-wrap top-row setup")
  }
  guard top_return.cursor_x() == 0 && top_return.cursor_y() == 0 else {
    fail("expected reverse-wrap to stop at the top row")
  }

  let y_zero_return = StreamTerminalBridgeState::new()
  guard y_zero_return.apply(
      StreamTopAndBottomMargin({ top_left: 2, bottom_right: 3 }),
    ) &&
    y_zero_return.apply(StreamSetMode(Mode::ReverseWrap)) &&
    y_zero_return.apply(StreamCursorPos({ row: 1, col: 2 })) &&
    y_zero_return.apply(StreamCursorLeft(CursorMovement(2))) else {
    fail("expected reverse-wrap y-zero setup")
  }
  guard y_zero_return.cursor_x() == 0 && y_zero_return.cursor_y() == 0 else {
    fail("expected reverse-wrap to stop at row zero outside the top margin")
  }

  let no_prev_wrap = StreamTerminalBridgeState::new()
  guard no_prev_wrap.apply(StreamSetMode(Mode::ReverseWrap)) &&
    no_prev_wrap.apply(StreamCursorPos({ row: 2, col: 1 })) &&
    no_prev_wrap.apply(StreamCursorLeft(CursorMovement(1))) else {
    fail("expected reverse-wrap no-prev-wrap setup")
  }
  guard no_prev_wrap.cursor_x() == 0 && no_prev_wrap.cursor_y() == 1 else {
    fail("expected reverse-wrap to stop when the previous row did not wrap")
  }

  let prev_wrap = StreamTerminalBridgeState::new()
  guard prev_wrap.apply(StreamSetMode(Mode::ReverseWrap)) else {
    fail("expected reverse-wrap previous-row-wrap setup")
  }
  for _ in 0..<81 {
    guard prev_wrap.apply(StreamPrint(b'A'.to_uint())) else {
      fail("expected wrap-generating print")
    }
  }
  guard prev_wrap.apply(StreamCursorPos({ row: 2, col: 1 })) &&
    prev_wrap.apply(StreamCursorLeft(CursorMovement(1))) else {
    fail("expected reverse-wrap previous-row-wrap action")
  }
  guard prev_wrap.cursor_x() == 79 && prev_wrap.cursor_y() == 0 else {
    fail("expected reverse-wrap to jump to the previous wrapped row")
  }
}

///|
test "stream terminal bridge/applies protected and display actions" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(StreamProtectedModeIso) else {
    fail("expected protected mode iso to be handled")
  }
  guard state.protected_state().mode() == ProtectedMode::Iso &&
    state.protected_state().cursor_protected() else {
    fail("expected protected mode iso semantics")
  }

  guard state.apply(StreamProtectedModeOff) else {
    fail("expected protected mode off to be handled")
  }
  guard state.protected_state().mode() == ProtectedMode::Iso &&
    !state.protected_state().cursor_protected() else {
    fail("expected off to preserve last non-off mode")
  }

  guard state.apply(StreamProtectedModeDec) else {
    fail("expected protected mode dec to be handled")
  }
  guard state.protected_state().mode() == ProtectedMode::Dec &&
    state.protected_state().cursor_protected() else {
    fail("expected protected mode dec semantics")
  }

  guard state.apply(StreamActiveStatusDisplay(StatusDisplay::StatusLine)) else {
    fail("expected active status display to be handled")
  }
  guard state.apply(StreamMouseShape(MouseShape::Pointer)) else {
    fail("expected mouse shape to be handled")
  }
  guard state.display_state().status_display() == StatusDisplay::StatusLine &&
    state.display_state().mouse_shape() == MouseShape::Pointer else {
    fail("expected display actions to update state")
  }
}

///|
test "stream terminal bridge/applies cursor movement and mode metadata" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(StreamCursorPos({ row: 4, col: 5 })) else {
    fail("expected cursor position to be handled")
  }
  guard state.cursor_x() == 4 && state.cursor_y() == 3 else {
    fail("expected cursor position update")
  }

  guard state.apply(StreamCursorCol(CursorMovement(2))) else {
    fail("expected cursor column to be handled")
  }
  guard state.cursor_x() == 1 && state.cursor_y() == 3 else {
    fail("expected cursor column update")
  }

  guard state.apply(StreamCursorRow(CursorMovement(6))) else {
    fail("expected cursor row to be handled")
  }
  guard state.cursor_x() == 1 && state.cursor_y() == 5 else {
    fail("expected cursor row update")
  }

  guard state.apply(StreamCursorColRelative(CursorMovement(3))) else {
    fail("expected cursor relative column to be handled")
  }
  guard state.cursor_x() == 4 && state.cursor_y() == 5 else {
    fail("expected cursor relative column update")
  }

  guard state.apply(StreamCursorRowRelative(CursorMovement(2))) else {
    fail("expected cursor relative row to be handled")
  }
  guard state.cursor_x() == 4 && state.cursor_y() == 7 else {
    fail("expected cursor relative row update")
  }

  guard state.apply(StreamCursorUp(CursorMovement(2))) else {
    fail("expected cursor up to be handled")
  }
  guard state.cursor_y() == 5 else { fail("expected cursor up clamp") }

  guard state.apply(StreamCursorDown(CursorMovement(0))) else {
    fail("expected cursor down to be handled")
  }
  guard state.cursor_y() == 6 else {
    fail("expected cursor down default count")
  }

  guard state.apply(StreamCursorLeft(CursorMovement(10))) else {
    fail("expected cursor left to be handled")
  }
  guard state.cursor_x() == 0 && !state.cursor_pending_wrap() else {
    fail("expected cursor left clamp")
  }

  guard state.apply(StreamCursorRight(CursorMovement(100))) else {
    fail("expected cursor right to be handled")
  }
  guard state.cursor_x() == 79 && !state.cursor_pending_wrap() else {
    fail("expected cursor right clamp")
  }

  guard state.apply(StreamCursorColRelative(CursorMovement(65535))) else {
    fail("expected large relative column to be handled")
  }
  guard state.cursor_x() == 79 else {
    fail("expected large relative column saturation")
  }

  guard state.apply(StreamCursorStyle(CursorStyle::BlinkingUnderline)) else {
    fail("expected cursor style to be handled")
  }
  guard state.cursor_visual_style() == CursorVisualStyle::Underline &&
    state.mode_enabled(Mode::CursorBlinking) else {
    fail("expected cursor style metadata update")
  }

  guard state.apply(StreamModifyKeyFormat(ModifyKeyFormat::OtherKeysNumeric)) else {
    fail("expected modify-key format to be handled")
  }
  guard state.modify_other_keys_2() else {
    fail("expected modify-other-keys state")
  }

  guard state.apply(StreamModifyKeyFormat(ModifyKeyFormat::Legacy)) else {
    fail("expected legacy modify-key format to be handled")
  }
  guard !state.modify_other_keys_2() else {
    fail("expected legacy modify-key format reset")
  }

  guard state.apply(StreamMouseShiftCapture(true)) else {
    fail("expected mouse shift capture to be handled")
  }
  guard state.mouse_shift_capture() == Some(true) else {
    fail("expected mouse shift capture state")
  }

  guard state.apply(StreamSetMode(Mode::MouseEventButton)) else {
    fail("expected mouse event mode to be handled")
  }
  guard state.mode_enabled(Mode::MouseEventButton) &&
    state.mouse_event() == MouseEvent::Button else {
    fail("expected mouse event mode state")
  }

  guard state.apply(StreamResetMode(Mode::MouseEventButton)) else {
    fail("expected mouse event reset to be handled")
  }
  guard !state.mode_enabled(Mode::MouseEventButton) &&
    state.mouse_event() == MouseEvent::None else {
    fail("expected mouse event reset state")
  }

  guard state.apply(StreamSetMode(Mode::MouseEventX10)) else {
    fail("expected x10 mouse event mode to be handled")
  }
  guard state.mouse_event() == MouseEvent::X10 else {
    fail("expected x10 mouse event mode state")
  }
  guard state.apply(StreamResetMode(Mode::MouseEventX10)) else {
    fail("expected x10 mouse event reset to be handled")
  }

  guard state.apply(StreamSetMode(Mode::MouseEventNormal)) else {
    fail("expected normal mouse event mode to be handled")
  }
  guard state.mouse_event() == MouseEvent::Normal else {
    fail("expected normal mouse event mode state")
  }
  guard state.apply(StreamResetMode(Mode::MouseEventNormal)) else {
    fail("expected normal mouse event reset to be handled")
  }

  guard state.apply(StreamSetMode(Mode::MouseEventAny)) else {
    fail("expected any mouse event mode to be handled")
  }
  guard state.mouse_event() == MouseEvent::Any else {
    fail("expected any mouse event mode state")
  }
  guard state.apply(StreamResetMode(Mode::MouseEventAny)) else {
    fail("expected any mouse event reset to be handled")
  }

  guard state.apply(StreamSetMode(Mode::MouseFormatSgr)) else {
    fail("expected mouse format mode to be handled")
  }
  guard state.mode_enabled(Mode::MouseFormatSgr) &&
    state.mouse_format() == MouseFormat::Sgr else {
    fail("expected mouse format mode state")
  }

  guard state.apply(StreamResetMode(Mode::MouseFormatSgr)) else {
    fail("expected mouse format reset to be handled")
  }
  guard !state.mode_enabled(Mode::MouseFormatSgr) &&
    state.mouse_format() == MouseFormat::X10 else {
    fail("expected mouse format reset state")
  }

  guard state.apply(StreamSetMode(Mode::MouseFormatUtf8)) else {
    fail("expected utf8 mouse format mode to be handled")
  }
  guard state.mouse_format() == MouseFormat::Utf8 else {
    fail("expected utf8 mouse format mode state")
  }
  guard state.apply(StreamResetMode(Mode::MouseFormatUtf8)) else {
    fail("expected utf8 mouse format reset to be handled")
  }

  guard state.apply(StreamSetMode(Mode::MouseFormatUrxvt)) else {
    fail("expected urxvt mouse format mode to be handled")
  }
  guard state.mouse_format() == MouseFormat::Urxvt else {
    fail("expected urxvt mouse format mode state")
  }
  guard state.apply(StreamResetMode(Mode::MouseFormatUrxvt)) else {
    fail("expected urxvt mouse format reset to be handled")
  }

  guard state.apply(StreamSetMode(Mode::MouseFormatSgrPixels)) else {
    fail("expected sgr-pixels mouse format mode to be handled")
  }
  guard state.mouse_format() == MouseFormat::SgrPixels else {
    fail("expected sgr-pixels mouse format mode state")
  }
  guard state.apply(StreamResetMode(Mode::MouseFormatSgrPixels)) else {
    fail("expected sgr-pixels mouse format reset to be handled")
  }

  guard state.apply(StreamResetMode(Mode::CursorVisible)) else {
    fail("expected cursor-visible reset to be handled")
  }
  guard !state.mode_enabled(Mode::CursorVisible) else {
    fail("expected cursor-visible mode reset")
  }

  guard state.apply(StreamSaveMode(Mode::CursorVisible)) else {
    fail("expected save mode to be handled")
  }
  guard state.apply(StreamSetMode(Mode::CursorVisible)) else {
    fail("expected cursor-visible set to be handled")
  }
  guard state.mode_enabled(Mode::CursorVisible) else {
    fail("expected cursor-visible mode set")
  }

  guard state.apply(StreamRestoreMode(Mode::CursorVisible)) else {
    fail("expected restore mode to be handled")
  }
  guard !state.mode_enabled(Mode::CursorVisible) else {
    fail("expected restore mode to reapply saved value")
  }
}

///|
test "stream terminal bridge/applies margin actions and cursor save branches" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(StreamTopAndBottomMargin({ top_left: 3, bottom_right: 5 })) else {
    fail("expected top/bottom margins to be handled")
  }
  guard state.cursor_top_margin() == 2 &&
    state.cursor_bottom_margin() == 4 &&
    state.cursor_x() == 0 &&
    state.cursor_y() == 0 else {
    fail("expected top/bottom margin state")
  }

  guard state.apply(StreamSetMode(Mode::Origin)) else {
    fail("expected origin mode to be handled")
  }
  guard state.mode_enabled(Mode::Origin) &&
    state.cursor_x() == 0 &&
    state.cursor_y() == 2 else {
    fail("expected origin mode home position")
  }

  guard state.apply(StreamSetMode(Mode::EnableLeftAndRightMargin)) else {
    fail("expected left/right margin mode to be handled")
  }
  guard state.mode_enabled(Mode::EnableLeftAndRightMargin) else {
    fail("expected left/right margin mode state")
  }

  guard state.apply(
    StreamLeftAndRightMargin({ top_left: 11, bottom_right: 20 }),
  ) else {
    fail("expected left/right margins to be handled")
  }
  guard state.cursor_left_margin() == 10 &&
    state.cursor_right_margin() == 19 &&
    state.cursor_x() == 10 &&
    state.cursor_y() == 2 else {
    fail("expected left/right margin state")
  }

  guard state.apply(StreamCursorRight(CursorMovement(100))) else {
    fail("expected cursor right in margins to be handled")
  }
  guard state.cursor_x() == 19 else {
    fail("expected cursor right margin clamp")
  }

  guard state.apply(StreamCursorPos({ row: 1, col: 3 })) else {
    fail("expected cursor position inside left/right margins")
  }
  guard state.apply(StreamCursorLeft(CursorMovement(5))) else {
    fail("expected cursor left inside origin margins")
  }
  guard state.cursor_x() == 10 else {
    fail("expected origin left-margin clamp")
  }

  guard state.apply(StreamHorizontalTabBack(1)) else {
    fail("expected horizontal tab back at left limit to be handled")
  }
  guard state.cursor_x() == 10 else {
    fail("expected horizontal tab back to stop at origin left limit")
  }

  guard state.apply(StreamLeftAndRightMarginAmbiguous) else {
    fail("expected ambiguous left/right margin action to be handled")
  }
  guard state.cursor_left_margin() == 0 &&
    state.cursor_right_margin() == 79 &&
    state.cursor_x() == 0 &&
    state.cursor_y() == 2 else {
    fail("expected enabled ambiguous margin branch")
  }

  guard state.apply(StreamResetMode(Mode::EnableLeftAndRightMargin)) else {
    fail("expected left/right margin mode reset to be handled")
  }
  guard !state.mode_enabled(Mode::EnableLeftAndRightMargin) &&
    state.cursor_left_margin() == 0 &&
    state.cursor_right_margin() == 79 &&
    state.cursor_x() == 0 &&
    state.cursor_y() == 2 else {
    fail("expected left/right margin reset branch")
  }

  guard state.apply(StreamCursorPos({ row: 4, col: 5 })) else {
    fail("expected cursor position after margin reset")
  }
  guard state.apply(StreamLeftAndRightMarginAmbiguous) else {
    fail("expected ambiguous action disabled branch")
  }
  guard state.has_saved_cursor() else {
    fail("expected ambiguous action to save cursor when margins disabled")
  }

  guard state.apply(StreamCursorPos({ row: 1, col: 1 })) else {
    fail("expected cursor mutation before restore")
  }
  guard state.apply(StreamRestoreCursor) else {
    fail("expected restore cursor after ambiguous save")
  }
  guard state.cursor_x() == 4 &&
    state.cursor_y() == 4 &&
    state.mode_enabled(Mode::Origin) else {
    fail("expected restore cursor after ambiguous save")
  }
}

///|
test "stream terminal bridge/applies charset save restore and keyboard state" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(
    StreamConfigureCharset({ slot: Slots::G1, charset: Charset::British }),
  ) else {
    fail("expected charset configure to be handled")
  }
  guard state.apply(
    StreamInvokeCharset({
      bank: ActiveSlot::Gl,
      charset: Slots::G1,
      locking: false,
    }),
  ) else {
    fail("expected locking charset invoke to be handled")
  }
  guard state.apply(
    StreamInvokeCharset({
      bank: ActiveSlot::Gl,
      charset: Slots::G2,
      locking: true,
    }),
  ) else {
    fail("expected single-shift charset invoke to be handled")
  }
  guard state.apply(StreamProtectedModeDec) else {
    fail("expected protected mode dec before save")
  }
  guard state.apply(StreamSetMode(Mode::Origin)) else {
    fail("expected origin mode before save")
  }
  guard state.apply(StreamCursorPos({ row: 2, col: 3 })) else {
    fail("expected cursor position before save")
  }
  guard state.apply(StreamSaveCursor) else {
    fail("expected direct save cursor to be handled")
  }

  guard state.apply(
    StreamConfigureCharset({ slot: Slots::G1, charset: Charset::Ascii }),
  ) else {
    fail("expected charset reconfigure to be handled")
  }
  guard state.apply(
    StreamInvokeCharset({
      bank: ActiveSlot::Gl,
      charset: Slots::G0,
      locking: false,
    }),
  ) else {
    fail("expected charset invoke mutation")
  }
  guard state.apply(StreamProtectedModeOff) else {
    fail("expected protected mode off mutation")
  }
  guard state.apply(StreamResetMode(Mode::Origin)) else {
    fail("expected origin reset mutation")
  }
  guard state.apply(StreamCursorPos({ row: 10, col: 10 })) else {
    fail("expected cursor mutation before restore")
  }

  guard state.apply(StreamRestoreCursor) else {
    fail("expected direct restore cursor to be handled")
  }
  guard state.cursor_x() == 2 &&
    state.cursor_y() == 1 &&
    state.mode_enabled(Mode::Origin) else {
    fail("expected restored cursor position and origin mode")
  }
  guard state.charset(Slots::G1) == Charset::British &&
    state.charset_gl() == Slots::G1 &&
    state.charset_single_shift() == Some(Slots::G2) else {
    fail("expected restored charset state")
  }
  guard state.protected_state().mode() == ProtectedMode::Dec &&
    state.protected_state().cursor_protected() else {
    fail("expected restored cursor protection")
  }

  guard state.apply(StreamCursorPos({ row: 5, col: 6 })) else {
    fail("expected cursor mutation before mode save")
  }
  guard state.apply(StreamSetMode(Mode::SaveCursor)) else {
    fail("expected save-cursor mode set to be handled")
  }
  guard state.apply(StreamCursorPos({ row: 1, col: 1 })) else {
    fail("expected cursor mutation before mode restore")
  }
  guard state.apply(StreamResetMode(Mode::SaveCursor)) else {
    fail("expected save-cursor mode reset to restore cursor")
  }
  guard state.cursor_x() == 5 && state.cursor_y() == 4 else {
    fail("expected save-cursor mode restore")
  }

  guard state.apply(StreamKittyKeyboardPush(KittyKeyboardFlags(3))) else {
    fail("expected kitty keyboard push to be handled")
  }
  guard state.apply(StreamKittyKeyboardSetOr(KittyKeyboardFlags(4))) else {
    fail("expected kitty keyboard set-or to be handled")
  }
  guard state.kitty_keyboard_flags() == KittyKeyboardFlags(7) else {
    fail("expected kitty keyboard or state")
  }

  guard state.apply(StreamKittyKeyboardSetNot(KittyKeyboardFlags(1))) else {
    fail("expected kitty keyboard set-not to be handled")
  }
  guard state.kitty_keyboard_flags() == KittyKeyboardFlags(6) else {
    fail("expected kitty keyboard not state")
  }

  guard state.apply(StreamKittyKeyboardSet(KittyKeyboardFlags(5))) else {
    fail("expected kitty keyboard set to be handled")
  }
  guard state.kitty_keyboard_flags() == KittyKeyboardFlags(5) else {
    fail("expected kitty keyboard set state")
  }

  guard state.apply(StreamKittyKeyboardPop(9)) else {
    fail("expected kitty keyboard pop to be handled")
  }
  guard state.kitty_keyboard_flags() == KittyKeyboardFlags(0) else {
    fail("expected kitty keyboard pop reset")
  }
}

///|
test "stream terminal bridge/applies tab operations" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(StreamHorizontalTab(1)) else {
    fail("expected horizontal tab to be handled")
  }
  guard state.cursor_x() == 8 else {
    fail("expected default horizontal tab stop")
  }

  guard state.apply(StreamCursorPos({ row: 1, col: 6 })) else {
    fail("expected cursor position before tab set")
  }
  guard state.apply(StreamTabSet) else {
    fail("expected tab set to be handled")
  }
  guard state.apply(StreamCursorPos({ row: 1, col: 1 })) else {
    fail("expected cursor reset before tab jump")
  }
  guard state.apply(StreamHorizontalTab(1)) else {
    fail("expected horizontal tab after custom set")
  }
  guard state.cursor_x() == 5 else { fail("expected custom tab stop") }

  guard state.apply(StreamTabClearCurrent) else {
    fail("expected tab clear current to be handled")
  }
  guard !state.tabstop(5) else { fail("expected current tab stop clear") }

  guard state.apply(StreamCursorPos({ row: 1, col: 1 })) else {
    fail("expected cursor reset before default tab")
  }
  guard state.apply(StreamHorizontalTab(1)) else {
    fail("expected horizontal tab after clear current")
  }
  guard state.cursor_x() == 8 else {
    fail("expected fallback to default tab stop")
  }

  guard state.apply(StreamTabClearAll) else {
    fail("expected tab clear all to be handled")
  }
  guard state.apply(StreamCursorPos({ row: 1, col: 1 })) else {
    fail("expected cursor reset before clear-all tab")
  }
  guard state.apply(StreamHorizontalTab(1)) else {
    fail("expected horizontal tab without tab stops")
  }
  guard state.cursor_x() == 79 else {
    fail("expected tab without stops to run to the right edge")
  }

  guard state.apply(StreamHorizontalTab(2)) else {
    fail("expected horizontal tab at the right edge to be handled")
  }
  guard state.cursor_x() == 79 else {
    fail("expected horizontal tab at the right edge to stay put")
  }

  guard state.apply(StreamTabReset) else {
    fail("expected tab reset to be handled")
  }
  guard state.apply(StreamCursorPos({ row: 1, col: 21 })) else {
    fail("expected cursor position before horizontal tab back")
  }
  guard state.apply(StreamHorizontalTabBack(1)) else {
    fail("expected horizontal tab back to be handled")
  }
  guard state.cursor_x() == 16 else {
    fail("expected horizontal tab back to previous stop")
  }
}

///|
test "stream terminal bridge/covers cursor movement edge branches" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(StreamTopAndBottomMargin({ top_left: 3, bottom_right: 5 })) else {
    fail("expected top/bottom margin setup")
  }
  guard state.apply(StreamCursorPos({ row: 10, col: 1 })) else {
    fail("expected cursor move below bottom margin")
  }
  guard state.apply(StreamCursorDown(CursorMovement(1))) else {
    fail("expected cursor down below margin to be handled")
  }
  guard state.cursor_y() == 10 else {
    fail("expected cursor down outside-scroll-region branch")
  }

  guard state.apply(StreamSetMode(Mode::EnableLeftAndRightMargin)) else {
    fail("expected left/right margin mode setup")
  }
  guard state.apply(
    StreamLeftAndRightMargin({ top_left: 11, bottom_right: 20 }),
  ) else {
    fail("expected left/right margin setup")
  }
  guard state.apply(StreamCursorPos({ row: 1, col: 80 })) else {
    fail("expected cursor move outside right margin")
  }
  guard state.apply(StreamCursorRight(CursorMovement(1))) else {
    fail("expected cursor right outside margin to be handled")
  }
  guard state.cursor_x() == 79 else {
    fail("expected cursor right outside-scroll-region branch")
  }
}

///|
test "stream terminal bridge/applies color set operations and ignores non-terminal targets" {
  let state = StreamTerminalBridgeState::new()
  let command = ColorCommand::new(
    Osc4,
    [
      Set(ColoredTarget::new(Palette(1), RGB::new(9, 8, 7))),
      Set(ColoredTarget::new(Dynamic(Foreground), RGB::new(1, 2, 3))),
      Set(ColoredTarget::new(Dynamic(Background), RGB::new(4, 5, 6))),
      Set(ColoredTarget::new(Dynamic(Cursor), RGB::new(7, 8, 9))),
      Set(ColoredTarget::new(Dynamic(PointerForeground), RGB::new(9, 9, 9))),
      Set(ColoredTarget::new(Special(Bold), RGB::new(6, 6, 6))),
    ],
    Terminator::St,
  )

  guard state.apply(StreamColorOperation(command)) else {
    fail("expected color operation to be handled")
  }
  guard state.palette_dirty() else {
    fail("expected palette writes to mark palette dirty")
  }
  guard state.colors().palette_color(1) == RGB::new(9, 8, 7) else {
    fail("expected palette color write")
  }
  guard state.colors().foreground() == Some(RGB::new(1, 2, 3)) else {
    fail("expected foreground dynamic color write")
  }
  guard state.colors().background() == Some(RGB::new(4, 5, 6)) else {
    fail("expected background dynamic color write")
  }
  guard state.colors().cursor() == Some(RGB::new(7, 8, 9)) else {
    fail("expected cursor dynamic color write")
  }
}

///|
test "stream terminal bridge/applies color resets and reset palette" {
  let state = StreamTerminalBridgeState::new()
  guard state.apply(
    StreamColorOperation(
      ColorCommand::new(
        Osc4,
        [
          Set(ColoredTarget::new(Palette(1), RGB::new(10, 11, 12))),
          Set(ColoredTarget::new(Palette(2), RGB::new(20, 21, 22))),
          Set(ColoredTarget::new(Dynamic(Foreground), RGB::new(1, 2, 3))),
          Set(ColoredTarget::new(Dynamic(Background), RGB::new(4, 5, 6))),
          Set(ColoredTarget::new(Dynamic(Cursor), RGB::new(7, 8, 9))),
        ],
        Terminator::St,
      ),
    ),
  ) else {
    fail("expected setup color operation")
  }

  state.clear_palette_dirty()
  guard state.apply(
    StreamColorOperation(
      ColorCommand::new(
        Osc104,
        [
          Reset(Palette(1)),
          Reset(Dynamic(Foreground)),
          Reset(Dynamic(Background)),
          Reset(Dynamic(Cursor)),
          Reset(Dynamic(PointerBackground)),
        ],
        Terminator::Bel,
      ),
    ),
  ) else {
    fail("expected reset color operation")
  }

  guard state.palette_dirty() else {
    fail("expected palette reset to mark palette dirty")
  }
  guard state.colors().palette_color(1) == Name::Red.default_rgb() else {
    fail("expected palette reset to restore default entry")
  }
  guard state.colors().foreground() == None &&
    state.colors().background() == None &&
    state.colors().cursor() == None else {
    fail("expected dynamic color resets to restore unset state")
  }

  state.clear_palette_dirty()
  guard state.apply(
    StreamColorOperation(
      ColorCommand::new(Osc104, [ResetPalette], Terminator::St),
    ),
  ) else {
    fail("expected reset palette operation")
  }
  guard state.palette_dirty() else {
    fail("expected reset palette to mark palette dirty when changes exist")
  }
  guard state.colors().palette_color(2) == Name::Green.default_rgb() else {
    fail("expected reset palette to restore all palette entries")
  }
}

///|
test "stream terminal bridge/empty and query color operations are handled without mutation" {
  let state = StreamTerminalBridgeState::new()
  guard state.apply(
    StreamColorOperation(ColorCommand::new(Osc4, [], Terminator::St)),
  ) else {
    fail("expected empty color operation to be handled")
  }

  guard state.apply(
    StreamColorOperation(
      ColorCommand::new(
        Osc4,
        [Query(Palette(1)), Reset(Special(Bold))],
        Terminator::St,
      ),
    ),
  ) else {
    fail("expected query-only color operation to be handled")
  }
  guard !state.palette_dirty() else {
    fail("expected query-only color operation to leave state unchanged")
  }
}

///|
test "stream terminal bridge/applies query responses and callbacks" {
  let recorder = BridgeEffectsRecorder::new()
  let attributes = DeviceAttributes::new(
    PrimaryDeviceAttributes::new(ConformanceLevel::Vt420, [
      PrimaryDeviceAttributeFeature::AnsiColor,
      PrimaryDeviceAttributeFeature::Clipboard,
    ]),
    SecondaryDeviceAttributes::new(DeviceType::Vt420, 100, 7),
    TertiaryDeviceAttributes::new(9U),
  )
  let effects = StreamTerminalBridgeEffects::new(
    write_pty=fn(data) { recorder.write_pty(data) },
    bell=fn() { recorder.bell() },
    color_scheme=fn() { Some(ColorScheme::Light) },
    device_attributes=fn() { Some(attributes) },
    enquiry=fn() { b"ghostty" },
    size=fn() { Some(Size::new(24, 80, 9, 18)) },
    title_changed=fn() { recorder.title_changed() },
    xtversion=fn() { "ghostty 1.2.3" },
  )
  let state = StreamTerminalBridgeState::with_effects(effects)

  guard state.apply(StreamBell) else {
    fail("expected bell callback path to be handled")
  }
  guard recorder.bell_count == 1 else { fail("expected bell callback count") }

  guard state.apply(StreamWindowTitle("Hello World")) else {
    fail("expected window-title action to be handled")
  }
  guard state.title() == Some("Hello World") &&
    recorder.title_changed_count == 1 else {
    fail("expected title state and callback")
  }

  guard state.apply(StreamDeviceStatus(DeviceStatusRequest::OperatingStatus)) &&
    state.apply(StreamCursorPos({ row: 5, col: 10 })) &&
    state.apply(StreamDeviceStatus(DeviceStatusRequest::CursorPosition)) &&
    state.apply(StreamTopAndBottomMargin({ top_left: 5, bottom_right: 20 })) &&
    state.apply(StreamSetMode(Mode::Origin)) &&
    state.apply(StreamCursorPos({ row: 3, col: 5 })) &&
    state.apply(StreamDeviceStatus(DeviceStatusRequest::CursorPosition)) &&
    state.apply(StreamRequestMode(Mode::Wraparound)) &&
    state.apply(StreamResetMode(Mode::Wraparound)) &&
    state.apply(StreamRequestMode(Mode::Wraparound)) &&
    state.apply(StreamRequestModeUnknown(mode_tag(9999, false))) &&
    state.apply(StreamDeviceAttributes(DeviceAttributeRequest::Primary)) &&
    state.apply(StreamDeviceAttributes(DeviceAttributeRequest::Secondary)) &&
    state.apply(StreamDeviceAttributes(DeviceAttributeRequest::Tertiary)) &&
    state.apply(StreamSizeReport(Csi14t)) &&
    state.apply(StreamSizeReport(Csi16t)) &&
    state.apply(StreamSizeReport(Csi18t)) &&
    state.apply(StreamSizeReport(Csi21t)) &&
    state.apply(StreamXtversion) &&
    state.apply(StreamKittyKeyboardPush(KittyKeyboardFlags(1))) &&
    state.apply(StreamKittyKeyboardQuery) &&
    state.apply(StreamEnquiry) &&
    state.apply(StreamDeviceStatus(DeviceStatusRequest::ColorScheme)) else {
    fail("expected query/effect actions to be handled")
  }

  guard recorder.writes.length() == 17 else {
    fail("expected all query/effect writes to be captured")
  }
  expect_effect_write(recorder, 0, b"\x1B[0n")
  expect_effect_write(recorder, 1, b"\x1B[5;10R")
  expect_effect_write(recorder, 2, b"\x1B[3;5R")
  expect_effect_write(recorder, 3, b"\x1B[?7;1$y")
  expect_effect_write(recorder, 4, b"\x1B[?7;2$y")
  expect_effect_write(recorder, 5, b"\x1B[?9999;0$y")
  expect_effect_write(recorder, 6, b"\x1B[?64;22;52c")
  expect_effect_write(recorder, 7, b"\x1B[>41;100;7c")
  expect_effect_write(recorder, 8, b"\x1BP!|00000009\x1B\\")
  expect_effect_write(recorder, 9, b"\x1B[4;432;720t")
  expect_effect_write(recorder, 10, b"\x1B[6;18;9t")
  expect_effect_write(recorder, 11, b"\x1B[8;24;80t")
  expect_effect_write(recorder, 12, b"\x1B]lHello World\x1B\\")
  expect_effect_write(recorder, 13, b"\x1BP>|ghostty 1.2.3\x1B\\")
  expect_effect_write(recorder, 14, b"\x1B[?1u")
  expect_effect_write(recorder, 15, b"ghostty")
  expect_effect_write(recorder, 16, b"\x1B[?997;2n")
}

///|
test "stream terminal bridge/covers readonly query branches and truncation" {
  let recorder = BridgeEffectsRecorder::new()
  let state = StreamTerminalBridgeState::with_effects(
    StreamTerminalBridgeEffects::new(
      write_pty=fn(data) { recorder.write_pty(data) },
      title_changed=fn() { recorder.title_changed() },
    ),
  )

  let long_title = ascii_string(b'x', 1100)
  guard state.apply(StreamWindowTitle(long_title)) else {
    fail("expected long window title to be handled")
  }
  guard state.title() != Some(long_title) && recorder.title_changed_count == 1 else {
    fail("expected long title to be truncated to upstream limit")
  }

  guard state.apply(StreamDeviceAttributes(DeviceAttributeRequest::Primary)) &&
    state.apply(StreamDeviceStatus(DeviceStatusRequest::ColorScheme)) &&
    state.apply(StreamSizeReport(Csi14t)) &&
    state.apply(StreamEnquiry) &&
    state.apply(StreamXtversion) else {
    fail("expected readonly query branches to be handled")
  }
  guard recorder.writes.length() == 1 else {
    fail("expected only default xtversion to write")
  }
  expect_effect_write(recorder, 0, b"\x1BP>|libghostty\x1B\\")

  let untitled_recorder = BridgeEffectsRecorder::new()
  let untitled_state = StreamTerminalBridgeState::with_effects(
    StreamTerminalBridgeEffects::new(write_pty=fn(data) {
      untitled_recorder.write_pty(data)
    }),
  )
  guard untitled_state.apply(StreamSizeReport(Csi16t)) &&
    untitled_state.apply(StreamSizeReport(Csi18t)) &&
    untitled_state.apply(StreamSizeReport(Csi21t)) else {
    fail("expected untitled size-report branches to be handled")
  }
  guard untitled_recorder.writes.length() == 1 else {
    fail("expected only untitled csi-21-t to write")
  }
  expect_effect_write(untitled_recorder, 0, b"\x1B]l\x1B\\")

  let dark_recorder = BridgeEffectsRecorder::new()
  let dark_state = StreamTerminalBridgeState::with_effects(
    StreamTerminalBridgeEffects::new(
      write_pty=fn(data) { dark_recorder.write_pty(data) },
      color_scheme=fn() { Some(ColorScheme::Dark) },
    ),
  )
  guard dark_state.apply(StreamDeviceStatus(DeviceStatusRequest::ColorScheme)) else {
    fail("expected dark color-scheme branch to be handled")
  }
  expect_effect_write(dark_recorder, 0, b"\x1B[?997;1n")

  let overflow_recorder = BridgeEffectsRecorder::new()
  let overflow_state = StreamTerminalBridgeState::with_effects(
    StreamTerminalBridgeEffects::new(
      write_pty=fn(data) { overflow_recorder.write_pty(data) },
      enquiry=fn() { @utf8.encode(ascii_string(b'e', 256)) },
      xtversion=fn() { ascii_string(b'v', 257) },
    ),
  )
  guard overflow_state.apply(StreamEnquiry) &&
    overflow_state.apply(StreamXtversion) else {
    fail("expected overflow query branches to be handled")
  }
  guard overflow_recorder.writes.length() == 0 else {
    fail("expected oversized enquiry and xtversion to be ignored")
  }
}

///|
test "stream terminal bridge/handles passive effect and passthrough actions" {
  let state = StreamTerminalBridgeState::new()
  guard apply_stream_bytes(state, b"\x1B]52;c;?\x07") &&
    apply_stream_bytes(state, b"\x1B]9;hello world\x07") &&
    apply_stream_bytes(state, b"\x1B]9;4;3;40\x07") &&
    apply_stream_bytes(state, b"\x1B]9;9;file:///tmp\x07") &&
    apply_stream_bytes(state, b"\x1B[22;0t\x1B[22;0;5t\x1B[23;0t\x1B[23;0;5t") &&
    apply_stream_bytes(state, b"\x1BP1;2+qa\x1B\\z") &&
    apply_stream_bytes(state, b"\x1B_a\x1B\\z") else {
    fail("expected passive effect and passthrough actions to be handled")
  }

  guard expect_bridge_cell(state, 0, 0).codepoint() == b'z'.to_uint() &&
    expect_bridge_cell(state, 0, 1).codepoint() == b'z'.to_uint() else {
    fail("expected later printable text to remain functional")
  }
}
