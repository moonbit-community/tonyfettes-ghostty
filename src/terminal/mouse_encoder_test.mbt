///|
fn test_mouse_encoder_size() -> MouseEncoderSize {
  MouseEncoderSize::new(1000U, 1000U, 1U, 1U).unwrap()
}

///|
fn make_mouse_event(
  action : MouseAction,
  button : MouseButton?,
  x : Float,
  y : Float,
  mods? : KeyMods = KeyMods::new(),
) -> MouseInputEvent {
  let event = MouseInputEvent::new()
  event.set_action(action)
  match button {
    Some(value) => event.set_button(value)
    None => event.clear_button()
  }
  event.set_mods(mods)
  event.set_position(MousePosition::new(x, y))
  event
}

///|
test "mouse encoder size/new validates and exposes fields" {
  guard MouseEncoderSize::new(10U, 10U, 0U, 1U) == None else {
    fail("expected zero cell width to be rejected")
  }
  guard MouseEncoderSize::new(10U, 10U, 1U, 0U) == None else {
    fail("expected zero cell height to be rejected")
  }

  let size = MouseEncoderSize::new(
    80U,
    24U,
    8U,
    16U,
    padding_top=1U,
    padding_bottom=2U,
    padding_right=3U,
    padding_left=4U,
  ).unwrap()
  guard size.screen_width() == 80U &&
    size.screen_height() == 24U &&
    size.cell_width() == 8U &&
    size.cell_height() == 16U &&
    size.padding_top() == 1U &&
    size.padding_bottom() == 2U &&
    size.padding_right() == 3U &&
    size.padding_left() == 4U else {
    fail("expected mouse encoder size accessors")
  }
}

///|
test "mouse encoder/new and setters expose typed owner surface" {
  let encoder = MouseEncoder::new()
  guard encoder.event() == MouseEvent::None &&
    encoder.format() == MouseFormat::X10 &&
    encoder.size() == MouseEncoderSize::new(1U, 1U, 1U, 1U).unwrap() &&
    !encoder.any_button_pressed() &&
    !encoder.track_last_cell() else {
    fail("expected default mouse encoder state")
  }

  let size = MouseEncoderSize::new(80U, 24U, 8U, 16U).unwrap()
  encoder.set_event(MouseEvent::Any)
  encoder.set_format(MouseFormat::Sgr)
  encoder.set_size(size)
  encoder.set_any_button_pressed(true)
  encoder.set_track_last_cell(true)

  guard encoder.event() == MouseEvent::Any &&
    encoder.format() == MouseFormat::Sgr &&
    encoder.size() == size &&
    encoder.any_button_pressed() &&
    encoder.track_last_cell() else {
    fail("expected setter updates on mouse encoder")
  }

  encoder.set_track_last_cell(false)
  guard !encoder.track_last_cell() else {
    fail("expected track-last-cell disable")
  }
}

///|
test "mouse encoder/sync from terminal keeps size caller owned" {
  let terminal = StreamTerminal::new()
  let encoder = MouseEncoder::new()
  let size = MouseEncoderSize::new(800U, 600U, 10U, 20U).unwrap()
  encoder.set_size(size)
  encoder.set_event(MouseEvent::Any)
  encoder.set_format(MouseFormat::Sgr)

  terminal.mode_set(Mode::MouseEventButton, true)
  terminal.mode_set(Mode::MouseFormatUrxvt, true)
  encoder.sync_from_terminal(terminal)

  guard encoder.event() == MouseEvent::Button &&
    encoder.format() == MouseFormat::Urxvt &&
    encoder.size() == size else {
    fail("expected terminal sync to update mode and format only")
  }

  terminal.deinit()
}

///|
test "mouse encoder/none x10 and normal mode reporting follow upstream rules" {
  let left_press = make_mouse_event(
    MouseAction::Press,
    Some(MouseButton::Left),
    0.0F,
    0.0F,
  )
  let left_release = make_mouse_event(
    MouseAction::Release,
    Some(MouseButton::Left),
    0.0F,
    0.0F,
  )
  let left_motion = make_mouse_event(
    MouseAction::Motion,
    Some(MouseButton::Left),
    0.0F,
    0.0F,
  )

  let none_encoder = MouseEncoder::new()
  none_encoder.set_size(test_mouse_encoder_size())
  guard none_encoder.encode(left_press) == b"" else {
    fail("expected none mode to stay silent")
  }

  let x10 = MouseEncoder::new()
  x10.set_event(MouseEvent::X10)
  x10.set_format(MouseFormat::X10)
  x10.set_size(test_mouse_encoder_size())
  guard x10.encode(left_press) == b"\x1B[M !!" else {
    fail("expected x10 press encoding")
  }
  guard x10.encode(left_release) == b"" &&
    x10.encode(
      make_mouse_event(MouseAction::Press, Some(MouseButton::Four), 0.0F, 0.0F),
    ) ==
    b"" else {
    fail("expected x10 filtering rules")
  }

  let normal = MouseEncoder::new()
  normal.set_event(MouseEvent::Normal)
  normal.set_format(MouseFormat::Sgr)
  normal.set_size(test_mouse_encoder_size())
  guard normal.encode(left_motion) == b"" else {
    fail("expected normal mode to ignore motion")
  }
  guard normal.encode(left_release) == b"\x1B[<0;1;1m" else {
    fail("expected normal mode release reporting")
  }
}

///|
test "mouse encoder/button and any modes handle null buttons and sgr release" {
  let encoder = MouseEncoder::new()
  encoder.set_event(MouseEvent::Button)
  encoder.set_format(MouseFormat::Sgr)
  encoder.set_size(test_mouse_encoder_size())

  guard encoder.encode(make_mouse_event(MouseAction::Motion, None, 1.0F, 2.0F)) ==
    b"" else {
    fail("expected button mode to require a button")
  }

  encoder.set_event(MouseEvent::Any)
  guard encoder.encode(make_mouse_event(MouseAction::Motion, None, 1.0F, 2.0F)) ==
    b"\x1B[<35;2;3M" else {
    fail("expected any mode motion without button")
  }
  guard encoder.encode(
      make_mouse_event(
        MouseAction::Press,
        Some(MouseButton::Middle),
        4.0F,
        5.0F,
      ),
    ) ==
    b"\x1B[<1;5;6M" else {
    fail("expected middle-button sgr press encoding")
  }
  guard encoder.encode(
      make_mouse_event(
        MouseAction::Release,
        Some(MouseButton::Right),
        4.0F,
        5.0F,
      ),
    ) ==
    b"\x1B[<2;5;6m" else {
    fail("expected sgr release to keep button identity")
  }
}

///|
test "mouse encoder/utf8 urxvt and sgr pixels formats encode correctly" {
  let utf8_encoder = MouseEncoder::new()
  utf8_encoder.set_event(MouseEvent::Any)
  utf8_encoder.set_format(MouseFormat::Utf8)
  utf8_encoder.set_size(test_mouse_encoder_size())
  let utf8_bytes = utf8_encoder.encode(
    make_mouse_event(
      MouseAction::Press,
      Some(MouseButton::Left),
      300.0F,
      400.0F,
    ),
  )
  guard utf8_bytes[:4] == b"\x1B[M " else {
    fail("expected utf8 prefix and button byte")
  }
  let decoded = @utf8.decode(utf8_bytes[4:])
  guard decoded == "\u{14D}\u{1B1}" else {
    fail("expected utf8 coordinate encoding")
  }
  utf8_encoder.set_size(MouseEncoderSize::new(10U, 0x110100U, 1U, 1U).unwrap())
  let clamped_utf8 = utf8_encoder.encode(
    make_mouse_event(
      MouseAction::Press,
      Some(MouseButton::Left),
      0.0F,
      1114176.0F,
    ),
  )
  let clamped_decoded = @utf8.decode(clamped_utf8[4:])
  guard clamped_decoded == "\u{21}\u{FFFD}" else {
    fail("expected oversized utf8 coordinate to use replacement character")
  }

  let urxvt = MouseEncoder::new()
  urxvt.set_event(MouseEvent::Any)
  urxvt.set_format(MouseFormat::Urxvt)
  urxvt.set_size(test_mouse_encoder_size())
  let mods = KeyMods::new().with_shift(true).with_alt(true).with_ctrl(true)
  guard urxvt.encode(
      make_mouse_event(
        MouseAction::Press,
        Some(MouseButton::Left),
        2.0F,
        3.0F,
        mods~,
      ),
    ) ==
    b"\x1B[60;3;4M" else {
    fail("expected urxvt encoding with modifiers")
  }
  guard urxvt.encode(
      make_mouse_event(
        MouseAction::Release,
        Some(MouseButton::Right),
        2.0F,
        3.0F,
      ),
    ) ==
    b"\x1B[35;3;4M" else {
    fail("expected urxvt release legacy button encoding")
  }

  let pixels = MouseEncoder::new()
  pixels.set_event(MouseEvent::Any)
  pixels.set_format(MouseFormat::SgrPixels)
  pixels.set_any_button_pressed(true)
  pixels.set_size(
    MouseEncoderSize::new(100U, 100U, 10U, 10U, padding_top=2U, padding_left=1U).unwrap(),
  )
  guard pixels.encode(
      make_mouse_event(
        MouseAction::Press,
        Some(MouseButton::Left),
        10.0F,
        20.0F,
      ),
    ) ==
    b"\x1B[<0;9;18M" else {
    fail("expected sgr pixels terminal-space coordinates")
  }
  guard pixels.encode(
      make_mouse_event(
        MouseAction::Release,
        Some(MouseButton::Right),
        10.0F,
        20.0F,
      ),
    ) ==
    b"\x1B[<2;9;18m" else {
    fail("expected sgr pixels release encoding")
  }
  guard pixels.encode(
      make_mouse_event(
        MouseAction::Press,
        Some(MouseButton::Left),
        -1.0F,
        -2.0F,
      ),
    ) ==
    b"\x1B[<0;-2;-4M" else {
    fail("expected sgr pixels negative terminal-space coordinates")
  }
}

///|
test "mouse encoder/x10 limits wheel buttons and viewport boundary" {
  let x10 = MouseEncoder::new()
  x10.set_event(MouseEvent::X10)
  x10.set_format(MouseFormat::X10)
  x10.set_size(test_mouse_encoder_size())

  guard x10.encode(
      make_mouse_event(
        MouseAction::Press,
        Some(MouseButton::Left),
        223.0F,
        0.0F,
      ),
    ) ==
    b"" else {
    fail("expected x10 coordinate limit guard")
  }

  let sgr = MouseEncoder::new()
  sgr.set_event(MouseEvent::Any)
  sgr.set_format(MouseFormat::Sgr)
  sgr.set_size(MouseEncoderSize::new(10U, 10U, 2U, 2U).unwrap())
  guard sgr.encode(
      make_mouse_event(
        MouseAction::Press,
        Some(MouseButton::Left),
        10.0F,
        10.0F,
      ),
    ) ==
    b"\x1B[<0;5;5M" else {
    fail("expected viewport-boundary position to clamp into final cell")
  }

  guard sgr.encode(
      make_mouse_event(MouseAction::Press, Some(MouseButton::Four), 0.0F, 0.0F),
    ) ==
    b"\x1B[<64;1;1M" &&
    sgr.encode(
      make_mouse_event(MouseAction::Press, Some(MouseButton::Five), 0.0F, 0.0F),
    ) ==
    b"\x1B[<65;1;1M" &&
    sgr.encode(
      make_mouse_event(MouseAction::Press, Some(MouseButton::Six), 0.0F, 0.0F),
    ) ==
    b"\x1B[<66;1;1M" &&
    sgr.encode(
      make_mouse_event(MouseAction::Press, Some(MouseButton::Seven), 0.0F, 0.0F),
    ) ==
    b"\x1B[<67;1;1M" &&
    sgr.encode(
      make_mouse_event(MouseAction::Press, Some(MouseButton::Eight), 0.0F, 0.0F),
    ) ==
    b"\x1B[<128;1;1M" &&
    sgr.encode(
      make_mouse_event(MouseAction::Press, Some(MouseButton::Nine), 0.0F, 0.0F),
    ) ==
    b"\x1B[<129;1;1M" &&
    sgr.encode(
      make_mouse_event(MouseAction::Press, Some(MouseButton::Ten), 0.0F, 0.0F),
    ) ==
    b"" else {
    fail("expected wheel and unsupported button handling")
  }

  let padded = MouseEncoder::new()
  padded.set_event(MouseEvent::Any)
  padded.set_format(MouseFormat::Sgr)
  padded.set_size(
    MouseEncoderSize::new(2U, 2U, 4U, 4U, padding_top=4U, padding_left=4U).unwrap(),
  )
  guard padded.encode(
      make_mouse_event(MouseAction::Press, Some(MouseButton::Left), 0.0F, 0.0F),
    ) ==
    b"\x1B[<0;1;1M" else {
    fail("expected degenerate padded size to clamp into a single cell")
  }
}

///|
test "mouse encoder/out of viewport motion and dedupe follow state" {
  let encoder = MouseEncoder::new()
  encoder.set_event(MouseEvent::Any)
  encoder.set_format(MouseFormat::Sgr)
  encoder.set_size(test_mouse_encoder_size())
  encoder.set_track_last_cell(true)

  let motion = make_mouse_event(
    MouseAction::Motion,
    Some(MouseButton::Left),
    5.0F,
    6.0F,
  )
  guard encoder.encode(motion) == b"\x1B[<32;6;7M" else {
    fail("expected first motion write")
  }
  guard encoder.encode(motion) == b"" else {
    fail("expected same-cell motion dedupe")
  }

  encoder.reset()
  guard encoder.encode(motion) == b"\x1B[<32;6;7M" else {
    fail("expected reset to clear dedupe state")
  }

  encoder.set_any_button_pressed(false)
  guard encoder.encode(
      make_mouse_event(
        MouseAction::Motion,
        Some(MouseButton::Left),
        -1.0F,
        -1.0F,
      ),
    ) ==
    b"" else {
    fail("expected out-of-viewport motion without button state to stay silent")
  }

  encoder.set_any_button_pressed(true)
  encoder.reset()
  guard encoder.encode(
      make_mouse_event(
        MouseAction::Motion,
        Some(MouseButton::Left),
        -1.0F,
        -1.0F,
      ),
    ) ==
    b"\x1B[<32;1;1M" else {
    fail("expected out-of-viewport motion with button state to report")
  }
}
