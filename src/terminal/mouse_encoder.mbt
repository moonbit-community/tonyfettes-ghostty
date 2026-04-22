///|
struct MouseEncoderSize {
  screen_width : UInt
  screen_height : UInt
  cell_width : UInt
  cell_height : UInt
  padding_top : UInt
  padding_bottom : UInt
  padding_right : UInt
  padding_left : UInt
} derive(Eq, Debug)

///|
pub fn MouseEncoderSize::new(
  screen_width : UInt,
  screen_height : UInt,
  cell_width : UInt,
  cell_height : UInt,
  padding_top? : UInt = 0U,
  padding_bottom? : UInt = 0U,
  padding_right? : UInt = 0U,
  padding_left? : UInt = 0U,
) -> MouseEncoderSize? {
  if cell_width == 0U || cell_height == 0U {
    return None
  }

  Some({
    screen_width,
    screen_height,
    cell_width,
    cell_height,
    padding_top,
    padding_bottom,
    padding_right,
    padding_left,
  })
}

///|
pub fn MouseEncoderSize::screen_width(self : MouseEncoderSize) -> UInt {
  self.screen_width
}

///|
pub fn MouseEncoderSize::screen_height(self : MouseEncoderSize) -> UInt {
  self.screen_height
}

///|
pub fn MouseEncoderSize::cell_width(self : MouseEncoderSize) -> UInt {
  self.cell_width
}

///|
pub fn MouseEncoderSize::cell_height(self : MouseEncoderSize) -> UInt {
  self.cell_height
}

///|
pub fn MouseEncoderSize::padding_top(self : MouseEncoderSize) -> UInt {
  self.padding_top
}

///|
pub fn MouseEncoderSize::padding_bottom(self : MouseEncoderSize) -> UInt {
  self.padding_bottom
}

///|
pub fn MouseEncoderSize::padding_right(self : MouseEncoderSize) -> UInt {
  self.padding_right
}

///|
pub fn MouseEncoderSize::padding_left(self : MouseEncoderSize) -> UInt {
  self.padding_left
}

///|
struct MouseEncoder {
  mut event : MouseEvent
  mut format : MouseFormat
  mut size : MouseEncoderSize
  mut any_button_pressed : Bool
  mut track_last_cell : Bool
  mut last_cell : Coordinate?
} derive(Eq, Debug)

///|
pub fn MouseEncoder::new() -> MouseEncoder {
  {
    event: MouseEvent::None,
    format: MouseFormat::X10,
    size: default_mouse_encoder_size(),
    any_button_pressed: false,
    track_last_cell: false,
    last_cell: None,
  }
}

///|
pub fn MouseEncoder::event(self : MouseEncoder) -> MouseEvent {
  self.event
}

///|
pub fn MouseEncoder::set_event(self : MouseEncoder, value : MouseEvent) -> Unit {
  if self.event != value {
    self.last_cell = None
  }
  self.event = value
}

///|
pub fn MouseEncoder::format(self : MouseEncoder) -> MouseFormat {
  self.format
}

///|
pub fn MouseEncoder::set_format(
  self : MouseEncoder,
  value : MouseFormat,
) -> Unit {
  if self.format != value {
    self.last_cell = None
  }
  self.format = value
}

///|
pub fn MouseEncoder::size(self : MouseEncoder) -> MouseEncoderSize {
  self.size
}

///|
pub fn MouseEncoder::set_size(
  self : MouseEncoder,
  value : MouseEncoderSize,
) -> Unit {
  self.size = value
  self.last_cell = None
}

///|
pub fn MouseEncoder::any_button_pressed(self : MouseEncoder) -> Bool {
  self.any_button_pressed
}

///|
pub fn MouseEncoder::set_any_button_pressed(
  self : MouseEncoder,
  value : Bool,
) -> Unit {
  self.any_button_pressed = value
}

///|
pub fn MouseEncoder::track_last_cell(self : MouseEncoder) -> Bool {
  self.track_last_cell
}

///|
pub fn MouseEncoder::set_track_last_cell(
  self : MouseEncoder,
  value : Bool,
) -> Unit {
  self.track_last_cell = value
  if !value {
    self.last_cell = None
  }
}

///|
pub fn MouseEncoder::sync_from_terminal(
  self : MouseEncoder,
  terminal : StreamTerminal,
) -> Unit {
  self.event = terminal.bridge().mouse_event()
  self.format = terminal.bridge().mouse_format()
  self.last_cell = None
}

///|
pub fn MouseEncoder::reset(self : MouseEncoder) -> Unit {
  self.last_cell = None
}

///|
pub fn MouseEncoder::encode(
  self : MouseEncoder,
  event : MouseInputEvent,
) -> Bytes {
  if !mouse_should_report(event, self.event) {
    return b""
  }

  if event.action() != MouseAction::Release &&
    mouse_position_out_of_viewport(event.position(), self.size) {
    if !mouse_event_sends_motion(self.event) || !self.any_button_pressed {
      return b""
    }
  }

  let cell = mouse_position_to_cell(event.position(), self.size)
  if event.action() == MouseAction::Motion &&
    self.format != MouseFormat::SgrPixels &&
    self.track_last_cell {
    if self.last_cell == Some(cell) {
      return b""
    }
  }

  if self.track_last_cell {
    self.last_cell = Some(cell)
  }

  let code = mouse_button_code(event, self.event, self.format)
  guard code is Some(button_code) else { return b"" }

  match self.format {
    X10 => encode_mouse_x10(button_code, cell)
    Utf8 => encode_mouse_utf8(button_code, cell)
    Sgr => encode_mouse_sgr(button_code, cell, event.action())
    Urxvt => encode_mouse_urxvt(button_code, cell)
    SgrPixels =>
      encode_mouse_sgr_pixels(
        button_code,
        mouse_position_to_pixels(event.position(), self.size),
        event.action(),
      )
  }
}

///|
fn default_mouse_encoder_size() -> MouseEncoderSize {
  {
    screen_width: 1U,
    screen_height: 1U,
    cell_width: 1U,
    cell_height: 1U,
    padding_top: 0U,
    padding_bottom: 0U,
    padding_right: 0U,
    padding_left: 0U,
  }
}

///|
fn mouse_should_report(event : MouseInputEvent, mode : MouseEvent) -> Bool {
  match mode {
    None => false
    X10 =>
      match (event.action(), event.button()) {
        (MouseAction::Press, Some(MouseButton::Left))
        | (MouseAction::Press, Some(MouseButton::Middle))
        | (MouseAction::Press, Some(MouseButton::Right)) => true
        _ => false
      }
    Normal => event.action() != MouseAction::Motion
    Button => event.button() != None
    Any => true
  }
}

///|
fn mouse_button_code(
  event : MouseInputEvent,
  mode : MouseEvent,
  format : MouseFormat,
) -> Int? {
  let mut code = match event.button() {
    None => 3
    Some(button) =>
      if event.action() == MouseAction::Release &&
        format != MouseFormat::Sgr &&
        format != MouseFormat::SgrPixels {
        3
      } else {
        match button {
          Left => 0
          Middle => 1
          Right => 2
          Four => 64
          Five => 65
          Six => 66
          Seven => 67
          Eight => 128
          Nine => 129
          _ => return None
        }
      }
  }

  if mode != MouseEvent::X10 {
    if event.mods().shift() {
      code += 4
    }
    if event.mods().alt() {
      code += 8
    }
    if event.mods().ctrl() {
      code += 16
    }
  }

  if event.action() == MouseAction::Motion {
    code += 32
  }

  Some(code)
}

///|
fn encode_mouse_x10(button_code : Int, cell : Coordinate) -> Bytes {
  if cell.x().to_int() > 222 || cell.y().reinterpret_as_int() > 222 {
    return b""
  }

  Bytes::from_array([
    b'\x1B',
    b'[',
    b'M',
    (32 + button_code).to_byte(),
    (33 + cell.x().to_int()).to_byte(),
    (33 + cell.y().reinterpret_as_int()).to_byte(),
  ])
}

///|
fn encode_mouse_utf8(button_code : Int, cell : Coordinate) -> Bytes {
  let buffer = @buffer.new()
  buffer.write_bytes(b"\x1B[M")
  buffer.write_byte((32 + button_code).to_byte())
  write_codepoint_utf8(buffer, 33 + cell.x().to_int())
  write_codepoint_utf8(buffer, 33 + cell.y().reinterpret_as_int())
  buffer.contents()
}

///|
fn encode_mouse_sgr(
  button_code : Int,
  cell : Coordinate,
  action : MouseAction,
) -> Bytes {
  let buffer = @buffer.new()
  buffer.write_bytes(b"\x1B[<")
  write_uint_ascii(buffer, button_code.to_uint64())
  buffer.write_byte(b';')
  write_uint_ascii(buffer, (cell.x().to_int() + 1).to_uint64())
  buffer.write_byte(b';')
  write_uint_ascii(buffer, (cell.y().reinterpret_as_int() + 1).to_uint64())
  buffer.write_byte(mouse_action_final_byte(action))
  buffer.contents()
}

///|
fn encode_mouse_urxvt(button_code : Int, cell : Coordinate) -> Bytes {
  let buffer = @buffer.new()
  buffer.write_bytes(b"\x1B[")
  write_uint_ascii(buffer, (32 + button_code).to_uint64())
  buffer.write_byte(b';')
  write_uint_ascii(buffer, (cell.x().to_int() + 1).to_uint64())
  buffer.write_byte(b';')
  write_uint_ascii(buffer, (cell.y().reinterpret_as_int() + 1).to_uint64())
  buffer.write_byte(b'M')
  buffer.contents()
}

///|
fn encode_mouse_sgr_pixels(
  button_code : Int,
  pixels : MousePixelPoint,
  action : MouseAction,
) -> Bytes {
  let buffer = @buffer.new()
  buffer.write_bytes(b"\x1B[<")
  write_uint_ascii(buffer, button_code.to_uint64())
  buffer.write_byte(b';')
  write_signed_ascii(buffer, pixels.x)
  buffer.write_byte(b';')
  write_signed_ascii(buffer, pixels.y)
  buffer.write_byte(mouse_action_final_byte(action))
  buffer.contents()
}

///|
fn mouse_action_final_byte(action : MouseAction) -> Byte {
  match action {
    Release => b'm'
    _ => b'M'
  }
}

///|
fn write_codepoint_utf8(buffer : @buffer.Buffer, codepoint : Int) -> Unit {
  let scalar = if codepoint > 0x10FFFF {
    0xFFFDU.reinterpret_as_int()
  } else {
    codepoint
  }
  buffer.write_char_utf8(scalar.to_char().unwrap())
}

///|
fn write_signed_ascii(buffer : @buffer.Buffer, value : Int) -> Unit {
  if value < 0 {
    buffer.write_byte(b'-')
    write_uint_ascii(buffer, (0 - value).to_uint64())
    return
  }
  write_uint_ascii(buffer, value.to_uint64())
}

///|
priv struct MousePixelPoint {
  x : Int
  y : Int
}

///|
fn mouse_position_out_of_viewport(
  pos : MousePosition,
  size : MouseEncoderSize,
) -> Bool {
  pos.x().to_double() < 0.0 ||
  pos.y().to_double() < 0.0 ||
  pos.x().to_double() > size.screen_width.to_double() ||
  pos.y().to_double() > size.screen_height.to_double()
}

///|
fn mouse_position_to_cell(
  pos : MousePosition,
  size : MouseEncoderSize,
) -> Coordinate {
  let content_columns = mouse_encoder_columns(size)
  let content_rows = mouse_encoder_rows(size)
  let x = clamp_mouse_cell_index(
    pos.x().to_double() - size.padding_left.to_double(),
    size.cell_width,
    content_columns,
  )
  let y = clamp_mouse_cell_index(
    pos.y().to_double() - size.padding_top.to_double(),
    size.cell_height,
    content_rows,
  )
  Coordinate::new(x.to_uint16(), y.reinterpret_as_uint())
}

///|
fn mouse_position_to_pixels(
  pos : MousePosition,
  size : MouseEncoderSize,
) -> MousePixelPoint {
  {
    x: (pos.x().to_double() - size.padding_left.to_double()).round().to_int(),
    y: (pos.y().to_double() - size.padding_top.to_double()).round().to_int(),
  }
}

///|
fn clamp_mouse_cell_index(
  position : Double,
  cell_size : UInt,
  cells : UInt,
) -> Int {
  if cells <= 1U {
    return 0
  }
  if position <= 0.0 {
    return 0
  }

  let scaled = (position / cell_size.to_double()).floor().to_int()
  let max_index = cells.reinterpret_as_int() - 1
  if scaled > max_index {
    max_index
  } else {
    scaled
  }
}

///|
fn mouse_encoder_columns(size : MouseEncoderSize) -> UInt {
  let content_width = saturated_sub_uint(
    size.screen_width,
    size.padding_left + size.padding_right,
  )
  max_uint(content_width / size.cell_width, 1U)
}

///|
fn mouse_encoder_rows(size : MouseEncoderSize) -> UInt {
  let content_height = saturated_sub_uint(
    size.screen_height,
    size.padding_top + size.padding_bottom,
  )
  max_uint(content_height / size.cell_height, 1U)
}

///|
fn saturated_sub_uint(value : UInt, other : UInt) -> UInt {
  if value > other {
    value - other
  } else {
    0U
  }
}

///|
fn max_uint(a : UInt, b : UInt) -> UInt {
  if a > b {
    a
  } else {
    b
  }
}
