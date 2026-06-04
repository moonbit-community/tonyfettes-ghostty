///|
struct StreamTerminalEffectsRecorder {
  writes : Array[Bytes]
  mut bell_count : Int
  mut title_changed_count : Int
}

///|
fn StreamTerminalEffectsRecorder::new() -> StreamTerminalEffectsRecorder {
  { writes: [], bell_count: 0, title_changed_count: 0 }
}

///|
fn StreamTerminalEffectsRecorder::write_pty(
  self : StreamTerminalEffectsRecorder,
  data : Bytes,
) -> Unit {
  self.writes.push(data)
}

///|
fn StreamTerminalEffectsRecorder::bell(
  self : StreamTerminalEffectsRecorder,
) -> Unit {
  self.bell_count += 1
}

///|
fn StreamTerminalEffectsRecorder::title_changed(
  self : StreamTerminalEffectsRecorder,
) -> Unit {
  self.title_changed_count += 1
}

///|
fn expect_stream_write(
  recorder : StreamTerminalEffectsRecorder,
  index : Int,
  expected : Bytes,
) -> Unit raise {
  guard recorder.writes[index] == expected else {
    fail("expected captured PTY write")
  }
}

///|
fn expect_terminal_cell(
  terminal : StreamTerminal,
  row : CellCountInt,
  col : CellCountInt,
) -> PageCellState {
  terminal.screen_cell_snapshot(row, col).unwrap()
}

///|
fn expect_row_text(
  terminal : StreamTerminal,
  row : CellCountInt,
  expected : Bytes,
) -> Unit raise {
  for index in 0..<expected.length() {
    guard expect_terminal_cell(terminal, row, index.to_uint16()).codepoint() ==
      expected[index].to_uint() else {
      fail("expected row text")
    }
  }
}

///|
test "stream terminal/applies bytes across split escape writes" {
  let terminal = StreamTerminal::new()

  guard terminal.title() == None &&
    terminal.cursor_x() == 0 &&
    terminal.cursor_y() == 0 &&
    terminal.cursor_visual_style() == Block &&
    !terminal.palette_dirty() &&
    terminal.screen_row_snapshot(24) == None &&
    terminal.screen_cell_snapshot(0, 80) == None else {
    fail("expected default public state")
  }

  terminal.next_slice(b"Hello \x1B")
  terminal.next_slice(b"[1mBold\x1B[0m")

  let row = terminal.screen_row_snapshot(0).unwrap()
  guard row.styled() && row.dirty() else {
    fail("expected row snapshot after split escape writes")
  }
  guard expect_terminal_cell(terminal, 0, 0).codepoint() == b'H'.to_uint() &&
    expect_terminal_cell(terminal, 0, 6).codepoint() == b'B'.to_uint() &&
    expect_terminal_cell(terminal, 0, 6).style().bold() &&
    expect_terminal_cell(terminal, 0, 9).codepoint() == b'd'.to_uint() else {
    fail("expected split escape sequence to preserve parser state")
  }

  terminal.deinit()
}

///|
test "stream terminal/routes query replies and callbacks" {
  let recorder = StreamTerminalEffectsRecorder::new()
  let attributes = DeviceAttributes::new(
    PrimaryDeviceAttributes::new(Vt420, [AnsiColor, Clipboard]),
    SecondaryDeviceAttributes::new(Vt420, 100, 7),
    TertiaryDeviceAttributes::new(9U),
  )
  let terminal = StreamTerminal::new(
    write_pty=fn(data) { recorder.write_pty(data) },
    bell=fn() { recorder.bell() },
    color_scheme=fn() { Some(Light) },
    device_attributes=fn() { Some(attributes) },
    enquiry=fn() { b"ghostty" },
    size=fn() { Some(Size::new(24, 80, 9, 18)) },
    title_changed=fn() { recorder.title_changed() },
    xtversion=fn() { "ghostty 1.2.3" },
  )

  terminal.next(0x07)
  terminal.next_slice(
    b"\x1B]2;Hello World\x1B\\\x1B[?7$p\x1B[c\x1B[>c\x1B[=c\x1B[18t\x1B[>q\x1B[?996n\x05",
  )

  guard recorder.bell_count == 1 &&
    recorder.title_changed_count == 1 &&
    terminal.title() == Some("Hello World") else {
    fail("expected bell and title callbacks")
  }
  guard recorder.writes.length() == 8 else {
    fail("expected query replies to be captured")
  }
  expect_stream_write(recorder, 0, b"\x1B[?7;1$y")
  expect_stream_write(recorder, 1, b"\x1B[?64;22;52c")
  expect_stream_write(recorder, 2, b"\x1B[>41;100;7c")
  expect_stream_write(recorder, 3, b"\x1BP!|00000009\x1B\\")
  expect_stream_write(recorder, 4, b"\x1B[8;24;80t")
  expect_stream_write(recorder, 5, b"\x1BP>|ghostty 1.2.3\x1B\\")
  expect_stream_write(recorder, 6, b"\x1B[?997;2n")
  expect_stream_write(recorder, 7, b"ghostty")

  terminal.deinit()
}

///|
test "stream terminal/uses readonly fallbacks and palette dirtiness" {
  let recorder = StreamTerminalEffectsRecorder::new()
  let terminal = StreamTerminal::new(write_pty=fn(data) {
    recorder.write_pty(data)
  })

  terminal.next_slice(
    b"\x1B[c\x1B[18t\x1B[?996n\x1B[>q\x05\x1B]21;5=rgb:01/02/03\x07A",
  )

  guard recorder.writes.length() == 2 else {
    fail("expected only default DA and XTVERSION replies")
  }
  expect_stream_write(recorder, 0, b"\x1B[?62;22c")
  expect_stream_write(recorder, 1, b"\x1BP>|libghostty\x1B\\")

  guard terminal.palette_dirty() &&
    expect_terminal_cell(terminal, 0, 0).codepoint() == b'A'.to_uint() else {
    fail("expected palette dirtiness and printable text")
  }
  terminal.clear_palette_dirty()
  guard !terminal.palette_dirty() else {
    fail("expected public palette dirty clear")
  }

  terminal.deinit()
}

///|
test "stream terminal/resize updates dimensions and reports size" {
  let recorder = StreamTerminalEffectsRecorder::new()
  let terminal = StreamTerminal::new(write_pty=fn(data) {
    recorder.write_pty(data)
  })

  terminal.mode_set(SynchronizedOutput, true)
  terminal.mode_set(InBandSizeReports, true)

  guard terminal.resize(100, 40, 9U, 18U) == Success else {
    fail("expected resize success")
  }
  guard terminal.columns() == 100 &&
    terminal.rows() == 40 &&
    terminal.width_px() == 900U &&
    terminal.height_px() == 720U else {
    fail("expected resize dimensions")
  }
  guard !terminal.mode_get(SynchronizedOutput) else {
    fail("expected resize to disable synchronized output")
  }
  guard recorder.writes.length() == 1 else {
    fail("expected in-band resize report")
  }
  expect_stream_write(recorder, 0, b"\x1B[48;40;100;720;900t")

  terminal.deinit()
}

///|
test "stream terminal/resize rejects zero dimensions and saturates pixels" {
  let terminal = StreamTerminal::new()

  guard terminal.resize(0, 24, 9U, 18U) == InvalidValue &&
    terminal.resize(80, 0, 9U, 18U) == InvalidValue else {
    fail("expected resize invalid-value guards")
  }
  guard terminal.resize(100, 40, 0xFFFFFFFF, 0xFFFFFFFF) == Success else {
    fail("expected resize saturation success")
  }
  guard terminal.width_px() == 0xFFFFFFFF && terminal.height_px() == 0xFFFFFFFF else {
    fail("expected saturated pixel dimensions")
  }

  terminal.deinit()
}

///|
test "stream terminal/scrollback viewport tracks active screen rows" {
  let terminal = StreamTerminal::new()

  guard terminal.resize(5, 2, 0U, 0U) == Success else {
    fail("expected resize before scrollback viewport test")
  }
  terminal.next_slice(b"hello\x1BD\x1BD\x1BD")

  guard terminal.active_screen() == Primary else {
    fail("expected primary screen by default")
  }
  guard terminal.total_rows() == 4U && terminal.scrollback_rows() == 2U else {
    fail("expected scrollback accounting")
  }
  guard expect_terminal_cell(terminal, 0, 0).codepoint() == 0U &&
    expect_terminal_cell(terminal, 1, 0).codepoint() == 0U else {
    fail("expected scrolled viewport bottom to be blank")
  }

  terminal.scroll_viewport_top()
  expect_row_text(terminal, 0, b"hello")

  terminal.scroll_viewport_bottom()
  guard expect_terminal_cell(terminal, 0, 0).codepoint() == 0U else {
    fail("expected viewport bottom after scroll reset")
  }

  terminal.scroll_viewport_delta(-2)
  expect_row_text(terminal, 0, b"hello")

  terminal.deinit()
}

///|
test "stream terminal/semantic_prompt_row_range returns None without OSC 133" {
  let terminal = StreamTerminal::new()

  // No semantic sequences sent — range should be None for any row.
  guard terminal.semantic_prompt_row_range(0) == None &&
    terminal.semantic_prompt_row_range(1) == None else {
    fail("expected None when no OSC 133 seen")
  }

  terminal.deinit()
}

///|
test "stream terminal/combining codepoints accumulate as grapheme extras" {
  let terminal = StreamTerminal::new()

  // 'e' (U+0065) followed by combining acute accent (U+0301) → é
  // The accent (U+0301) is zero-width and should be combined onto 'e'.
  terminal.next_slice(@utf8.encode("e\u{0301}"))
  let cell = expect_terminal_cell(terminal, 0, 0)
  guard cell.codepoint() == 0x65U &&
    cell.has_grapheme() &&
    cell.grapheme_codepoints() == [0x301U] else {
    fail(
      "expected combining accent to be stored as grapheme extra on the base cell",
    )
  }

  // Second combining codepoint appended to same base cell
  terminal.next_slice(@utf8.encode("\u{0300}"))
  let cell2 = expect_terminal_cell(terminal, 0, 0)
  guard cell2.codepoint() == 0x65U &&
    cell2.grapheme_codepoints() == [0x301U, 0x300U] else {
    fail("expected second combining codepoint to accumulate")
  }

  // A new printable character at the next column has no grapheme extras
  terminal.next_slice(b"a")
  let cell3 = expect_terminal_cell(terminal, 0, 1)
  guard !cell3.has_grapheme() && cell3.grapheme_codepoints() == [] else {
    fail("expected adjacent plain cell to have no grapheme extras")
  }

  terminal.deinit()
}

///|
test "stream terminal/semantic_prompt_row_range covers prompt and output zones" {
  let terminal = StreamTerminal::new()

  guard terminal.resize(80, 5, 0U, 0U) == Success else {
    fail("expected resize success")
  }

  // Row 0: prompt start.
  terminal.next_slice(b"\x1B]133;A\x07prompt>")
  // Switch to output mode (cursor.x != 0 so no row override), then \r\n
  // advances to row 1 with cursor_content=Output — apply_semantic_after_newline
  // returns early and row 1 keeps its initial None state.
  terminal.next_slice(b"\x1B]133;C\x07\r\n")
  // Rows 1 and 2: output, each \r\n keeps cursor_content=Output → rows stay None.
  terminal.next_slice(b"output line 1\r\n")
  terminal.next_slice(b"output line 2\r\n")
  // Row 3: second prompt.
  terminal.next_slice(b"\x1B]133;A\x07$ ")

  guard terminal.semantic_prompt_row_range(0) == Some((0, 0)) else {
    fail("expected prompt row to map to its own zone")
  }
  // Rows 1 and 2 are both None — one output zone.
  guard terminal.semantic_prompt_row_range(1) == Some((1, 2)) &&
    terminal.semantic_prompt_row_range(2) == Some((1, 2)) else {
    fail("expected output rows to share the same zone")
  }
  guard terminal.semantic_prompt_row_range(3) == Some((3, 3)) else {
    fail("expected second prompt row to map to its own zone")
  }

  terminal.deinit()
}

///|
test "stream terminal/mode 2027 suppresses combining codepoint append" {
  let terminal = StreamTerminal::new()

  // Enable grapheme cluster mode (2027): zero-width codepoints must be dropped.
  terminal.mode_set(GraphemeCluster, true)
  terminal.next_slice(@utf8.encode("e\u{0301}"))
  let cell = expect_terminal_cell(terminal, 0, 0)
  guard cell.codepoint() == b'e'.to_uint() &&
    !cell.has_grapheme() &&
    cell.grapheme_codepoints() == [] else {
    fail("expected combining codepoint dropped when mode 2027 is on")
  }

  // Disable mode 2027: combining codepoints should be appended again.
  terminal.mode_set(GraphemeCluster, false)
  terminal.next_slice(@utf8.encode("e\u{0301}"))
  let cell2 = expect_terminal_cell(terminal, 0, 1)
  guard cell2.has_grapheme() && cell2.grapheme_codepoints() == [0x301U] else {
    fail("expected combining codepoint appended when mode 2027 is off")
  }

  terminal.deinit()
}

///|
test "stream terminal/semantic_prompt_row_range spans prompt continuation rows" {
  let terminal = StreamTerminal::new()

  // 3 rows: row 0 = Prompt, row 1 = PromptContinuation, row 2 = output (None).
  guard terminal.resize(80, 3, 0U, 0U) == Success else {
    fail("expected resize success")
  }

  // Row 0: prompt start; \r\n with cursor_content=Prompt triggers
  // apply_semantic_after_newline → row 1 = PromptContinuation.
  terminal.next_slice(b"\x1B]133;A\x07line1\r\n")
  // Row 1: explicit continuation marker.
  terminal.next_slice(b"\x1B]133;A;k=c\x07line2\r\n")
  // Row 2: output at column 0 — EndInputStartOutput with x=0 overrides row 2
  // back to None.
  terminal.next_slice(b"\x1B]133;C\x07output")

  // Rows 0 and 1 share one prompt zone.
  guard terminal.semantic_prompt_row_range(0) == Some((0, 1)) &&
    terminal.semantic_prompt_row_range(1) == Some((0, 1)) else {
    fail("expected prompt and continuation to share zone")
  }
  guard terminal.semantic_prompt_row_range(2) == Some((2, 2)) else {
    fail("expected output row to be its own zone")
  }

  terminal.deinit()
}

///|
test "stream terminal/semantic_prompt_row_range is screen-local" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(80, 5, 0U, 0U) == Success else {
    fail("expected resize success")
  }

  // Primary screen sees an OSC 133 prompt → it has a semantic zone.
  terminal.next_slice(b"\x1B]133;A\x07prompt>")
  guard terminal.semantic_prompt_row_range(0) == Some((0, 0)) else {
    fail("expected primary prompt zone")
  }

  // Enter the alternate screen (fullscreen app). It received no OSC 133, so it
  // must not inherit the primary screen's terminal-wide semantic state: every
  // row query is None rather than a leaked full-screen output zone.
  terminal.next_slice(b"\x1B[?1049h")
  guard terminal.active_screen() == Alternate else {
    fail("expected alternate screen after 1049h")
  }
  guard terminal.semantic_prompt_row_range(0) == None &&
    terminal.semantic_prompt_row_range(4) == None else {
    fail("expected no semantic zone leaked onto the alternate screen")
  }

  // Returning to the primary screen restores its semantic state intact.
  terminal.next_slice(b"\x1B[?1049l")
  guard terminal.active_screen() == Primary else {
    fail("expected primary screen after 1049l")
  }
  guard terminal.semantic_prompt_row_range(0) == Some((0, 0)) else {
    fail("expected primary semantic zone to survive the alt-screen round trip")
  }

  terminal.deinit()
}

///|
test "stream terminal/clearing alternate screen resets its semantic state" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(80, 5, 0U, 0U) == Success else {
    fail("expected resize success")
  }

  // Enter the alternate screen and let it emit its own OSC 133 prompt: the
  // alternate screen legitimately has a semantic zone of its own.
  terminal.next_slice(b"\x1B[?1049h")
  terminal.next_slice(b"\x1B]133;A\x07prompt>")
  guard terminal.semantic_prompt_row_range(0) == Some((0, 0)) else {
    fail("expected alternate screen to track its own prompt zone")
  }

  // Leave and re-enter: ?1049h clears the alternate screen, which wipes its
  // per-row markers. The reused, now-blank alternate session must not keep the
  // previous session's seen()=true and report a phantom output zone.
  terminal.next_slice(b"\x1B[?1049l")
  terminal.next_slice(b"\x1B[?1049h")
  guard terminal.active_screen() == Alternate else {
    fail("expected alternate screen after re-entry")
  }
  guard terminal.semantic_prompt_row_range(0) == None &&
    terminal.semantic_prompt_row_range(4) == None else {
    fail("expected cleared alternate screen to carry no semantic zone")
  }

  terminal.deinit()
}

///|
test "stream terminal/copied default cell is not reported as styled" {
  let terminal = StreamTerminal::new()

  // Plain default text followed by a bold cell.
  terminal.next_slice(b"A\x1B[1mB\x1B[0m")

  // screen_cell_snapshot reads through the scrollback copy path
  // (copy_scrollback_cell), which rebuilds the style as a fresh CellStyle rather
  // than the shared default singleton. has_styling() must still be false for the
  // unstyled cell (regression: an identity-only check reported every copied
  // default cell as styled) and true for the bold one.
  let plain = expect_terminal_cell(terminal, 0, 0)
  let bold = expect_terminal_cell(terminal, 0, 1)
  guard !plain.has_styling() && bold.has_styling() else {
    fail("expected copied default cell unstyled and bold cell styled")
  }

  terminal.deinit()
}

///|
test "stream terminal/grapheme_codepoints visible through row iterator" {
  let terminal = StreamTerminal::new()
  let render = RenderState::new()

  // Write 'n' + combining tilde (U+0303) → ñ
  terminal.next_slice(@utf8.encode("n\u{0303}"))
  render.update(terminal)

  let iter = render.row_iterator()
  guard iter.next() else { fail("expected at least one row") }
  let cells = iter.cells().unwrap()
  guard cells.next() else { fail("expected at least one cell") }
  let cell = cells.cell().unwrap()
  guard cell.codepoint() == b'n'.to_uint() &&
    cell.has_grapheme() &&
    cell.grapheme_codepoints() == [0x303U] else {
    fail("expected grapheme codepoints accessible through render row iterator")
  }

  terminal.deinit()
}
