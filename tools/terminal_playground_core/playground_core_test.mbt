///|
test "playground/new apply render and state json stay typed" {
  let handle = playground_new(12, 4)

  playground_apply_text(handle, "Hello\u{001B}]0;Demo\u{0007}\u{001B}[5 q")

  let plain = playground_render_plain(handle)
  guard plain.contains("Hello") else {
    fail("expected plain formatter output to include terminal text")
  }
  guard playground_render_html(handle).contains("<div") &&
    playground_render_vt(handle).contains("Hello") else {
    fail("expected html and vt formatter exports")
  }

  let state = @json.parse(playground_state_json(handle))
  guard state is Object(obj) else { fail("expected state json object") }

  guard obj["rows"] == 4 &&
    obj["columns"] == 12 &&
    obj["title"] == "Demo" &&
    obj["cursorStyle"] == "bar" &&
    obj["cursorVisible"] == true else {
    fail("expected typed state json")
  }

  playground_free(handle)
}

///|
test "playground/cell json reports styled text hyperlink and wide cells" {
  let handle = playground_new(8, 2)

  playground_apply_text(
    handle, "\u{001B}]8;;https://example.com\u{001B}\\\u{001B}[1;4;38;2;1;2;3;48;2;4;5;6mZ\u{001B}]8;;\u{001B}\\",
  )

  let cell = @json.parse(playground_cell_json(handle, 0, 0))
  guard cell is Object(obj) else { fail("expected cell json object") }
  guard obj["row"] == 0 &&
    obj["column"] == 0 &&
    obj["rowState"] is Object(_) &&
    obj["cell"] is Object(cell_obj) &&
    cell_obj["codepoint"] == 90 &&
    cell_obj["style"] is Object(style_obj) &&
    style_obj["bold"] == true &&
    style_obj["underline"] == "single" else {
    fail("expected styled hyperlink cell json")
  }

  playground_reset(handle)
  playground_apply_text(handle, "\u{001B}[44mA中")

  let palette_cell = @json.parse(playground_cell_json(handle, 0, 0))
  let wide_cell = @json.parse(playground_cell_json(handle, 0, 1))
  let spacer_tail = @json.parse(playground_cell_json(handle, 0, 2))

  guard palette_cell is Object(palette_obj) &&
    palette_obj["cell"] is Object(_) &&
    wide_cell is Object(wide_obj) &&
    wide_obj["cell"] is Object(_) &&
    spacer_tail is Object(tail_obj) &&
    tail_obj["cell"] is Object(_) else {
    fail("expected palette and wide-cell branches")
  }

  playground_free(handle)
}

///|
test "playground/pty output captures terminal replies reset and query callbacks" {
  let handle = playground_new(8, 2)

  playground_apply_text(
    handle, "\u{0007}\u{0005}\u{001B}[5n\u{001B}[18t\u{001B}[>q",
  )

  let state_before_reset = @json.parse(playground_state_json(handle))
  guard state_before_reset is Object(state_obj) && state_obj["bellCount"] == 1 else {
    fail("expected bell callback state to be captured")
  }

  let pty = playground_pty_output(handle)
  guard pty.contains("\u{001B}[0n") &&
    pty.contains("ghostty-playground") &&
    pty.contains("ghostty-moonbit-playground") else {
    fail("expected query callbacks to be captured")
  }

  playground_reset(handle)
  let state_after_reset = @json.parse(playground_state_json(handle))
  guard state_after_reset is Object(reset_obj) &&
    reset_obj["bellCount"] == 0 &&
    reset_obj["ptyLength"] == 0 else {
    fail("expected reset to clear side-effect logs")
  }

  playground_clear_pty_output(handle)
  guard playground_pty_output(handle) == "" else {
    fail("expected pty output buffer to clear")
  }

  playground_free(handle)
}

///|
test "playground/kitty json exports placement metadata and image payload" {
  let handle = playground_new(10, 4)

  let empty = @json.parse(playground_kitty_json(handle))
  guard empty is Object(empty_obj) && empty_obj["count"] == 0 else {
    fail("expected empty kitty surface before image transmit")
  }

  playground_apply_text(
    handle, "\u{001B}_Ga=T,t=d,f=24,i=1,p=1,s=1,v=2,c=4,r=1;////////\u{001B}\\",
  )

  let kitty = @json.parse(playground_kitty_json(handle))
  guard kitty is Object(obj) &&
    obj["count"] == 1 &&
    obj["placements"] is Array(placements) &&
    placements.length() == 1 &&
    placements[0] is Object(placement) &&
    placement["image"] is Object(image) &&
    image["format"] == "rgb" &&
    image["dataBase64"] == "////////" else {
    fail("expected kitty placement metadata and base64 image data")
  }

  playground_free(handle)
}

///|
test "playground/invalid handles clamp paths and missing cells stay safe" {
  let handle = playground_new(0, 999)

  let clamped = @json.parse(playground_state_json(handle))
  guard clamped is Object(obj) && obj["rows"] == 120 && obj["columns"] == 1 else {
    fail("expected constructor clamp behavior")
  }

  guard playground_resize(-1, 4, 4) ==
    @terminal.TerminalResultCode::InvalidValue.code() else {
    fail("expected invalid handle resize to return invalid-value code")
  }

  let invalid = @json.parse(playground_render_plain(-1))
  guard invalid is Object(invalid_obj) &&
    invalid_obj["error"] == "invalid handle" else {
    fail("expected invalid handle json response")
  }

  playground_apply_text(-1, "ignored")

  guard playground_resize(handle, 3, 5) == 0 else {
    fail("expected valid resize to succeed")
  }

  playground_scroll_delta(handle, 1)

  let missing = @json.parse(playground_cell_json(handle, 400, 400))
  guard missing is Object(_) else {
    fail("expected missing screen coordinates to stay typed")
  }

  guard @json.parse(playground_cell_json(handle, -1, 0)) == null else {
    fail("expected negative coordinates to short-circuit to null")
  }

  playground_scroll_delta(-1, 1)
  playground_reset(-1)
  playground_clear_pty_output(-1)
  playground_free(-1)
  playground_free(handle)
  playground_free(handle)

  let freed = @json.parse(playground_render_plain(handle))
  let out_of_range = @json.parse(playground_render_plain(handle + 99))
  guard freed is Object(_) && out_of_range is Object(_) else {
    fail("expected freed and out-of-range handles to stay safe")
  }
}

///|
test "playground/alternate screen state becomes visible in json" {
  let handle = playground_new(6, 2)

  playground_apply_text(handle, "\u{001B}[?1049h")

  let state = @json.parse(playground_state_json(handle))
  guard state is Object(obj) && obj["activeScreen"] == "alternate" else {
    fail("expected alternate-screen state to serialize")
  }

  playground_free(handle)
}
