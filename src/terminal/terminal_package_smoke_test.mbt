///|
struct PackageSurfaceLogRecorder {
  mut call_count : Int
  levels : Array[SystemLogLevel]
  messages : Array[Bytes]
} derive(Eq, Debug)

///|
fn PackageSurfaceLogRecorder::new() -> PackageSurfaceLogRecorder {
  { call_count: 0, levels: [], messages: [] }
}

///|
fn PackageSurfaceLogRecorder::record(
  self : PackageSurfaceLogRecorder,
  level : SystemLogLevel,
  message : Bytes,
) -> Unit {
  self.call_count += 1
  self.levels.push(level)
  self.messages.push(message)
}

///|
fn package_smoke_key_event(
  key : Key,
  mods? : KeyMods = KeyMods::new(),
  utf8? : Bytes = b"",
) -> KeyEvent {
  let event = KeyEvent::new()
  event.set_key(key)
  event.set_mods(mods)
  event.set_utf8(utf8)
  event
}

///|
fn package_smoke_mouse_event(
  action : MouseAction,
  button : MouseButton?,
  x : Float,
  y : Float,
) -> MouseInputEvent {
  let event = MouseInputEvent::new()
  event.set_action(action)
  match button {
    Some(value) => event.set_button(value)
    None => event.clear_button()
  }
  event.set_position(MousePosition::new(x, y))
  event
}

///|
test "terminal package smoke/metadata registry and system hooks" {
  let info = build_info()
  guard info.version_string().length() > 0 else {
    fail("expected build info version string")
  }

  let entries = terminal_surface_types()
  guard entries.length() == 22 else {
    fail("expected the translated types.zig registry to stay complete")
  }

  let string_info = terminal_surface_type("GhosttyString").unwrap()
  guard string_info.mapping() == TerminalSurfaceTypeMapping::Native &&
    string_info.moonbit_surface() == "String / Bytes" &&
    string_info.note() != None else {
    fail("expected GhosttyString native replacement metadata")
  }

  let recorder = PackageSurfaceLogRecorder::new()
  terminal_system_clear_log()
  terminal_system_set_log(fn(level, _scope, message) {
    recorder.record(level, message)
  })
  terminal_system_emit_log(SystemLogLevel::Info, b"pkg", b"surface smoke")
  terminal_system_clear_log()

  guard recorder.call_count == 1 &&
    recorder.levels == [SystemLogLevel::Info] &&
    recorder.messages == [b"surface smoke"] else {
    fail("expected package log hook smoke path")
  }
}

///|
test "terminal package smoke/terminal render formatter and graphics surface" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(4, 2, 8U, 16U) == TerminalResultCode::Success else {
    fail("expected resize before package smoke terminal snapshot")
  }

  terminal.next_slice(b"AB\r\nCD")

  let selection = terminal
    .selection(
      Point::Active(Coordinate::new(1, 0U)),
      Point::Active(Coordinate::new(1, 1U)),
      true,
    )
    .unwrap()

  guard terminal.screen_cell_snapshot(0, 1).unwrap().codepoint() ==
    b'B'.to_uint() &&
    terminal.screen_cell_snapshot(0, 1).unwrap().style().is_default() else {
    fail("expected terminal cell query surface")
  }

  let formatter = Formatter::new_terminal(
    terminal,
    FormatterOptions::new(
      Format::Plain,
      selection=Some(selection),
      extra=FormatterTerminalExtra::none(),
    ),
  )
  guard formatter.format() == b"B\nD" else {
    fail("expected formatter package smoke path")
  }

  let render = RenderState::new()
  render.update(terminal)
  let rows = render.row_iterator()
  guard render.rows() == 2 &&
    render.columns() == 4 &&
    rows.next() &&
    rows.y() == Some(0) &&
    rows.row() != None else {
    fail("expected render state package smoke path")
  }

  let cells = rows.cells().unwrap()
  guard cells.next() &&
    cells.x() == Some(0) &&
    cells.cell().unwrap().codepoint() == b'A'.to_uint() else {
    fail("expected render row iterator package smoke path")
  }

  let graphics = terminal.kitty_graphics()
  let placements = graphics.placement_iterator()
  let empty_placements = match placements.next() {
    None => true
    Some(_) => false
  }
  guard graphics.image(1U) == None else {
    fail("expected kitty graphics image lookup to stay empty")
  }
  guard empty_placements else {
    fail("expected kitty graphics package smoke defaults")
  }

  terminal.deinit()
}

///|
test "terminal package smoke/input helpers and encoders" {
  guard FocusEvent::Gained.encode() == b"\x1B[I" &&
    paste_is_safe(b"abc") &&
    PasteOptions::new(true).encode(b"abc") == b"\x1B[200~abc\x1B[201~" else {
    fail("expected focus and paste helper smoke path")
  }

  let terminal = StreamTerminal::new()
  terminal.mode_set(Mode::CursorKeys, true)
  terminal.mode_set(Mode::MouseEventAny, true)
  terminal.mode_set(Mode::MouseFormatSgr, true)

  let key_encoder = KeyEncoder::new()
  key_encoder.sync_from_terminal(terminal)
  guard key_encoder.cursor_key_application() &&
    key_encoder.encode(package_smoke_key_event(Key::KeyC, utf8=b"c")) == b"c" else {
    fail("expected key encoder package smoke path")
  }

  let mouse_encoder = MouseEncoder::new()
  mouse_encoder.sync_from_terminal(terminal)
  mouse_encoder.set_size(MouseEncoderSize::new(80U, 24U, 8U, 16U).unwrap())
  let mouse_bytes = mouse_encoder.encode(
    package_smoke_mouse_event(
      MouseAction::Press,
      Some(MouseButton::Left),
      0.0F,
      0.0F,
    ),
  )
  guard mouse_encoder.event() == MouseEvent::Any &&
    mouse_encoder.format() == MouseFormat::Sgr &&
    mouse_bytes == b"\x1B[<0;1;1M" else {
    fail("expected mouse encoder package smoke path")
  }

  terminal.deinit()
}
