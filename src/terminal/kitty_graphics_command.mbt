///|
priv enum KittyGraphicsQuiet {
  No
  Ok
  Failures
} derive(Eq, Debug)

///|
priv enum KittyImageFormat {
  Rgb
  Rgba
  Png
} derive(Eq, Debug)

///|
fn KittyImageFormat::bytes_per_pixel(self : KittyImageFormat) -> UInt {
  match self {
    Rgb => 3U
    Rgba => 4U
    Png => 0U
  }
}

///|
priv enum KittyImageMedium {
  Direct
  File
  TemporaryFile
  SharedMemory
} derive(Eq, Debug)

///|
priv enum KittyImageCompression {
  None
  ZlibDeflate
} derive(Eq, Debug)

///|
priv struct KittyImageTransmission {
  mut format : KittyImageFormat
  mut medium : KittyImageMedium
  mut width : UInt
  mut height : UInt
  mut size : UInt
  mut offset : UInt
  mut image_id : UInt
  mut image_number : UInt
  mut placement_id : UInt
  mut compression : KittyImageCompression
  mut more_chunks : Bool
} derive(Eq, Debug)

///|
fn KittyImageTransmission::new() -> KittyImageTransmission {
  {
    format: Rgba,
    medium: Direct,
    width: 0U,
    height: 0U,
    size: 0U,
    offset: 0U,
    image_id: 0U,
    image_number: 0U,
    placement_id: 0U,
    compression: KittyImageCompression::None,
    more_chunks: false,
  }
}

///|
priv enum KittyImageCursorMovement {
  After
  None
} derive(Eq, Debug)

///|
priv struct KittyImageDisplay {
  mut image_id : UInt
  mut image_number : UInt
  mut placement_id : UInt
  mut x : UInt
  mut y : UInt
  mut width : UInt
  mut height : UInt
  mut x_offset : UInt
  mut y_offset : UInt
  mut columns : UInt
  mut rows : UInt
  mut cursor_movement : KittyImageCursorMovement
  mut virtual_placement : Bool
  mut parent_id : UInt
  mut parent_placement_id : UInt
  mut horizontal_offset : Int
  mut vertical_offset : Int
  mut z : Int
} derive(Eq, Debug)

///|
fn KittyImageDisplay::new() -> KittyImageDisplay {
  {
    image_id: 0U,
    image_number: 0U,
    placement_id: 0U,
    x: 0U,
    y: 0U,
    width: 0U,
    height: 0U,
    x_offset: 0U,
    y_offset: 0U,
    columns: 0U,
    rows: 0U,
    cursor_movement: After,
    virtual_placement: false,
    parent_id: 0U,
    parent_placement_id: 0U,
    horizontal_offset: 0,
    vertical_offset: 0,
    z: 0,
  }
}

///|
priv struct KittyGraphicsDeleteById {
  delete : Bool
  image_id : UInt
  placement_id : UInt
} derive(Eq, Debug)

///|
priv struct KittyGraphicsDeleteByNumber {
  delete : Bool
  image_number : UInt
  placement_id : UInt
} derive(Eq, Debug)

///|
priv struct KittyGraphicsDeleteIntersectCell {
  delete : Bool
  x : UInt
  y : UInt
} derive(Eq, Debug)

///|
priv struct KittyGraphicsDeleteIntersectCellZ {
  delete : Bool
  x : UInt
  y : UInt
  z : Int
} derive(Eq, Debug)

///|
priv struct KittyGraphicsDeleteRange {
  delete : Bool
  first : UInt
  last : UInt
} derive(Eq, Debug)

///|
priv struct KittyGraphicsDeleteColumn {
  delete : Bool
  x : UInt
} derive(Eq, Debug)

///|
priv struct KittyGraphicsDeleteRow {
  delete : Bool
  y : UInt
} derive(Eq, Debug)

///|
priv struct KittyGraphicsDeleteZ {
  delete : Bool
  z : Int
} derive(Eq, Debug)

///|
priv enum KittyGraphicsDelete {
  All(Bool)
  Id(KittyGraphicsDeleteById)
  Newest(KittyGraphicsDeleteByNumber)
  IntersectCursor(Bool)
  AnimationFrames(Bool)
  IntersectCell(KittyGraphicsDeleteIntersectCell)
  IntersectCellZ(KittyGraphicsDeleteIntersectCellZ)
  Range(KittyGraphicsDeleteRange)
  Column(KittyGraphicsDeleteColumn)
  Row(KittyGraphicsDeleteRow)
  Z(KittyGraphicsDeleteZ)
} derive(Eq, Debug)

///|
priv struct KittyGraphicsTransmitAndDisplay {
  transmission : KittyImageTransmission
  display : KittyImageDisplay
} derive(Eq, Debug)

///|
priv enum KittyGraphicsControl {
  Query(KittyImageTransmission)
  Transmit(KittyImageTransmission)
  TransmitAndDisplay(KittyGraphicsTransmitAndDisplay)
  Display(KittyImageDisplay)
  Delete(KittyGraphicsDelete)
  Unsupported(Byte)
} derive(Eq, Debug)

///|
priv struct KittyGraphicsCommand {
  control : KittyGraphicsControl
  quiet : KittyGraphicsQuiet
  data : Bytes
} derive(Eq, Debug)

///|
fn KittyGraphicsCommand::transmission(
  self : KittyGraphicsCommand,
) -> KittyImageTransmission? {
  match self.control {
    Query(value) => Some(value)
    Transmit(value) => Some(value)
    TransmitAndDisplay(value) => Some(value.transmission)
    Display(_) | Delete(_) | Unsupported(_) => None
  }
}

///|
fn KittyGraphicsCommand::display(
  self : KittyGraphicsCommand,
) -> KittyImageDisplay? {
  match self.control {
    Display(value) => Some(value)
    TransmitAndDisplay(value) => Some(value.display)
    Query(_) | Transmit(_) | Delete(_) | Unsupported(_) => None
  }
}

///|
priv struct KittyGraphicsResponse {
  mut id : UInt
  image_number : UInt
  placement_id : UInt
  mut message : Bytes
} derive(Eq, Debug)

///|
fn KittyGraphicsResponse::new(
  id? : UInt = 0U,
  image_number? : UInt = 0U,
  placement_id? : UInt = 0U,
  message? : Bytes = b"OK",
) -> KittyGraphicsResponse {
  { id, image_number, placement_id, message }
}

///|
fn KittyGraphicsResponse::ok(self : KittyGraphicsResponse) -> Bool {
  self.message == b"OK"
}

///|
fn KittyGraphicsResponse::empty(self : KittyGraphicsResponse) -> Bool {
  self.id == 0U && self.image_number == 0U
}

///|
fn KittyGraphicsResponse::encode(self : KittyGraphicsResponse) -> Bytes {
  if self.empty() {
    return b""
  }

  let buffer = @buffer.new()
  let mut prior = false
  buffer.write_bytes(b"\x1B_G")
  if self.id > 0U {
    prior = true
    buffer.write_byte(b'i')
    buffer.write_byte(b'=')
    write_uint_ascii(buffer, self.id.to_uint64())
  }
  if self.image_number > 0U {
    if prior {
      buffer.write_byte(b',')
    } else {
      prior = true
    }
    buffer.write_byte(b'I')
    buffer.write_byte(b'=')
    write_uint_ascii(buffer, self.image_number.to_uint64())
  }
  if self.placement_id > 0U {
    if prior {
      buffer.write_byte(b',')
    }
    buffer.write_byte(b'p')
    buffer.write_byte(b'=')
    write_uint_ascii(buffer, self.placement_id.to_uint64())
  }
  buffer.write_byte(b';')
  buffer.write_bytes(self.message)
  buffer.write_bytes(b"\x1B\\")
  buffer.contents()
}

///|
priv enum KittyGraphicsParseState {
  ControlKey
  ControlKeyIgnore
  ControlValue
  ControlValueIgnore
  Data
} derive(Eq, Debug)

///|
priv struct KittyGraphicsPair {
  key : Byte
  value : Array[Byte]
} derive(Eq, Debug)

///|
fn parse_kitty_graphics_command_bytes(
  buffer : Array[Byte],
) -> KittyGraphicsCommand? {
  let mut state = KittyGraphicsParseState::ControlKey
  let mut current_key : Byte = 0
  let mut temp : Array[Byte] = []
  let pairs : Array[KittyGraphicsPair] = []
  let data : Array[Byte] = []

  for byte in buffer {
    match state {
      ControlKey =>
        if byte == b'=' {
          if temp.length() != 1 {
            state = ControlValueIgnore
            temp = []
          } else {
            current_key = temp[0]
            temp = []
            state = ControlValue
          }
        } else if byte == b';' {
          state = Data
          temp = []
        } else {
          temp.push(byte)
          if temp.length() > 11 {
            temp = []
            state = ControlKeyIgnore
          }
        }
      ControlKeyIgnore => if byte == b'=' { state = ControlValueIgnore }
      ControlValue =>
        if byte == b',' {
          guard finish_kitty_graphics_pair(pairs, current_key, temp) else {
            return None
          }
          temp = []
          state = ControlKey
        } else if byte == b';' {
          guard finish_kitty_graphics_pair(pairs, current_key, temp) else {
            return None
          }
          temp = []
          state = Data
        } else {
          temp.push(byte)
          if temp.length() > 11 {
            temp = []
            state = ControlValueIgnore
          }
        }
      ControlValueIgnore =>
        if byte == b',' {
          temp = []
          state = ControlKey
        } else if byte == b';' {
          temp = []
          state = Data
        }
      Data => data.push(byte)
    }
  }

  if state == ControlKey || state == ControlKeyIgnore {
    return None
  }
  if state == ControlValue &&
    !finish_kitty_graphics_pair(pairs, current_key, temp) {
    return None
  }

  let control = match build_kitty_graphics_control(pairs) {
    Some(value) => value
    None => return None
  }
  let quiet = match build_kitty_graphics_quiet(pairs) {
    Some(value) => value
    None => return None
  }
  let payload = match decode_kitty_graphics_base64(data) {
    Some(value) => value
    None => return None
  }
  Some({ control, quiet, data: payload })
}

///|
fn finish_kitty_graphics_pair(
  pairs : Array[KittyGraphicsPair],
  key : Byte,
  value : Array[Byte],
) -> Bool {
  if value.length() == 0 {
    return false
  }
  if !kitty_graphics_value_is_valid(value) {
    return false
  }
  set_kitty_graphics_pair(pairs, key, clone_kitty_graphics_bytes(value))
  true
}

///|
fn kitty_graphics_value_is_valid(value : Array[Byte]) -> Bool {
  if value.length() == 1 && (value[0] < b'0' || value[0] > b'9') {
    return true
  }
  if parse_kitty_graphics_u32(value) is Some(_) {
    return true
  }
  parse_kitty_graphics_i32(value) is Some(_)
}

///|
fn set_kitty_graphics_pair(
  pairs : Array[KittyGraphicsPair],
  key : Byte,
  value : Array[Byte],
) -> Unit {
  let mut index = 0
  while index < pairs.length() {
    if pairs[index].key == key {
      pairs[index] = { key, value }
      return
    }
    index += 1
  }
  pairs.push({ key, value })
}

///|
fn build_kitty_graphics_control(
  pairs : Array[KittyGraphicsPair],
) -> KittyGraphicsControl? {
  let action = kitty_graphics_option_byte(
    kitty_graphics_pair_u8(pairs, b'a'),
    b't',
  )
  match action {
    b'q' =>
      match parse_kitty_graphics_transmission(pairs) {
        Some(value) => Some(Query(value))
        None => None
      }
    b't' =>
      match parse_kitty_graphics_transmission(pairs) {
        Some(value) => Some(Transmit(value))
        None => None
      }
    b'T' =>
      match parse_kitty_graphics_transmission(pairs) {
        Some(transmission) =>
          match parse_kitty_graphics_display(pairs) {
            Some(display) => Some(TransmitAndDisplay({ transmission, display }))
            None => None
          }
        None => None
      }
    b'p' =>
      match parse_kitty_graphics_display(pairs) {
        Some(value) => Some(Display(value))
        None => None
      }
    b'd' =>
      match parse_kitty_graphics_delete(pairs) {
        Some(value) => Some(Delete(value))
        None => None
      }
    b'f' | b'a' | b'c' => Some(Unsupported(action))
    _ => None
  }
}

///|
fn build_kitty_graphics_quiet(
  pairs : Array[KittyGraphicsPair],
) -> KittyGraphicsQuiet? {
  match kitty_graphics_pair_u32(pairs, b'q') {
    None => Some(KittyGraphicsQuiet::No)
    Some(0U) => Some(KittyGraphicsQuiet::No)
    Some(1U) => Some(KittyGraphicsQuiet::Ok)
    Some(2U) => Some(KittyGraphicsQuiet::Failures)
    Some(_) => None
  }
}

///|
fn parse_kitty_graphics_transmission(
  pairs : Array[KittyGraphicsPair],
) -> KittyImageTransmission? {
  let result = KittyImageTransmission::new()

  match kitty_graphics_pair_u32(pairs, b'f') {
    Some(24U) => result.format = Rgb
    Some(32U) => result.format = Rgba
    Some(100U) => result.format = Png
    Some(_) => return None
    None => ()
  }

  match kitty_graphics_pair_u8(pairs, b't') {
    Some(b'd') => result.medium = Direct
    Some(b'f') => result.medium = File
    Some(b't') => result.medium = TemporaryFile
    Some(b's') => result.medium = SharedMemory
    Some(_) => return None
    None => ()
  }

  match kitty_graphics_pair_u32(pairs, b's') {
    Some(value) => result.width = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'v') {
    Some(value) => result.height = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'S') {
    Some(value) => result.size = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'O') {
    Some(value) => result.offset = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'i') {
    Some(value) => result.image_id = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'I') {
    Some(value) => result.image_number = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'p') {
    Some(value) => result.placement_id = value
    None => ()
  }

  match kitty_graphics_pair_u8(pairs, b'o') {
    Some(b'z') => result.compression = ZlibDeflate
    Some(_) => return None
    None => ()
  }

  if result.medium == Direct {
    match kitty_graphics_pair_u32(pairs, b'm') {
      Some(value) => result.more_chunks = value > 0U
      None => ()
    }
  }

  Some(result)
}

///|
fn parse_kitty_graphics_display(
  pairs : Array[KittyGraphicsPair],
) -> KittyImageDisplay? {
  let result = KittyImageDisplay::new()

  match kitty_graphics_pair_u32(pairs, b'i') {
    Some(value) => result.image_id = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'I') {
    Some(value) => result.image_number = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'p') {
    Some(value) => result.placement_id = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'x') {
    Some(value) => result.x = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'y') {
    Some(value) => result.y = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'w') {
    Some(value) => result.width = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'h') {
    Some(value) => result.height = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'X') {
    Some(value) => result.x_offset = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'Y') {
    Some(value) => result.y_offset = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'c') {
    Some(value) => result.columns = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'r') {
    Some(value) => result.rows = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'C') {
    Some(0U) => result.cursor_movement = After
    Some(1U) => result.cursor_movement = KittyImageCursorMovement::None
    Some(_) => return None
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'U') {
    Some(0U) => result.virtual_placement = false
    Some(1U) => result.virtual_placement = true
    Some(_) => return None
    None => ()
  }
  match kitty_graphics_pair_i32(pairs, b'z') {
    Some(value) => result.z = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'P') {
    Some(value) => result.parent_id = value
    None => ()
  }
  match kitty_graphics_pair_u32(pairs, b'Q') {
    Some(value) => result.parent_placement_id = value
    None => ()
  }
  match kitty_graphics_pair_i32(pairs, b'H') {
    Some(value) => result.horizontal_offset = value
    None => ()
  }
  match kitty_graphics_pair_i32(pairs, b'V') {
    Some(value) => result.vertical_offset = value
    None => ()
  }

  Some(result)
}

///|
fn parse_kitty_graphics_delete(
  pairs : Array[KittyGraphicsPair],
) -> KittyGraphicsDelete? {
  let selector = kitty_graphics_option_byte(
    kitty_graphics_pair_u8(pairs, b'd'),
    b'a',
  )
  match selector {
    b'a' => Some(All(false))
    b'A' => Some(All(true))
    b'i' =>
      Some(
        Id({
          delete: false,
          image_id: kitty_graphics_option_u32(
            kitty_graphics_pair_u32(pairs, b'i'),
            0U,
          ),
          placement_id: kitty_graphics_option_u32(
            kitty_graphics_pair_u32(pairs, b'p'),
            0U,
          ),
        }),
      )
    b'I' =>
      Some(
        Id({
          delete: true,
          image_id: kitty_graphics_option_u32(
            kitty_graphics_pair_u32(pairs, b'i'),
            0U,
          ),
          placement_id: kitty_graphics_option_u32(
            kitty_graphics_pair_u32(pairs, b'p'),
            0U,
          ),
        }),
      )
    b'n' =>
      Some(
        Newest({
          delete: false,
          image_number: kitty_graphics_option_u32(
            kitty_graphics_pair_u32(pairs, b'I'),
            0U,
          ),
          placement_id: kitty_graphics_option_u32(
            kitty_graphics_pair_u32(pairs, b'p'),
            0U,
          ),
        }),
      )
    b'N' =>
      Some(
        Newest({
          delete: true,
          image_number: kitty_graphics_option_u32(
            kitty_graphics_pair_u32(pairs, b'I'),
            0U,
          ),
          placement_id: kitty_graphics_option_u32(
            kitty_graphics_pair_u32(pairs, b'p'),
            0U,
          ),
        }),
      )
    b'c' => Some(IntersectCursor(false))
    b'C' => Some(IntersectCursor(true))
    b'f' => Some(AnimationFrames(false))
    b'F' => Some(AnimationFrames(true))
    b'p' =>
      Some(
        IntersectCell({
          delete: false,
          x: kitty_graphics_option_u32(kitty_graphics_pair_u32(pairs, b'x'), 0U),
          y: kitty_graphics_option_u32(kitty_graphics_pair_u32(pairs, b'y'), 0U),
        }),
      )
    b'P' =>
      Some(
        IntersectCell({
          delete: true,
          x: kitty_graphics_option_u32(kitty_graphics_pair_u32(pairs, b'x'), 0U),
          y: kitty_graphics_option_u32(kitty_graphics_pair_u32(pairs, b'y'), 0U),
        }),
      )
    b'q' =>
      Some(
        IntersectCellZ({
          delete: false,
          x: kitty_graphics_option_u32(kitty_graphics_pair_u32(pairs, b'x'), 0U),
          y: kitty_graphics_option_u32(kitty_graphics_pair_u32(pairs, b'y'), 0U),
          z: kitty_graphics_option_int(kitty_graphics_pair_i32(pairs, b'z'), 0),
        }),
      )
    b'Q' =>
      Some(
        IntersectCellZ({
          delete: true,
          x: kitty_graphics_option_u32(kitty_graphics_pair_u32(pairs, b'x'), 0U),
          y: kitty_graphics_option_u32(kitty_graphics_pair_u32(pairs, b'y'), 0U),
          z: kitty_graphics_option_int(kitty_graphics_pair_i32(pairs, b'z'), 0),
        }),
      )
    b'r' | b'R' => {
      let first = match kitty_graphics_pair_u32(pairs, b'x') {
        Some(value) => value
        None => return None
      }
      let last = match kitty_graphics_pair_u32(pairs, b'y') {
        Some(value) => value
        None => return None
      }
      if first > last {
        return None
      }
      Some(Range({ delete: selector == b'R', first, last }))
    }
    b'x' =>
      Some(
        Column({
          delete: false,
          x: kitty_graphics_option_u32(kitty_graphics_pair_u32(pairs, b'x'), 0U),
        }),
      )
    b'X' =>
      Some(
        Column({
          delete: true,
          x: kitty_graphics_option_u32(kitty_graphics_pair_u32(pairs, b'x'), 0U),
        }),
      )
    b'y' =>
      Some(
        Row({
          delete: false,
          y: kitty_graphics_option_u32(kitty_graphics_pair_u32(pairs, b'y'), 0U),
        }),
      )
    b'Y' =>
      Some(
        Row({
          delete: true,
          y: kitty_graphics_option_u32(kitty_graphics_pair_u32(pairs, b'y'), 0U),
        }),
      )
    b'z' =>
      Some(
        Z({
          delete: false,
          z: kitty_graphics_option_int(kitty_graphics_pair_i32(pairs, b'z'), 0),
        }),
      )
    b'Z' =>
      Some(
        Z({
          delete: true,
          z: kitty_graphics_option_int(kitty_graphics_pair_i32(pairs, b'z'), 0),
        }),
      )
    _ => None
  }
}

///|
fn kitty_graphics_option_byte(value : Byte?, fallback : Byte) -> Byte {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn kitty_graphics_option_u32(value : UInt?, fallback : UInt) -> UInt {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn kitty_graphics_option_int(value : Int?, fallback : Int) -> Int {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn kitty_graphics_pair_value(
  pairs : Array[KittyGraphicsPair],
  key : Byte,
) -> Array[Byte]? {
  let mut index = 0
  while index < pairs.length() {
    if pairs[index].key == key {
      return Some(pairs[index].value)
    }
    index += 1
  }
  None
}

///|
fn kitty_graphics_pair_u32(
  pairs : Array[KittyGraphicsPair],
  key : Byte,
) -> UInt? {
  match kitty_graphics_pair_value(pairs, key) {
    Some(value) => parse_kitty_graphics_u32(value)
    None => None
  }
}

///|
fn kitty_graphics_pair_i32(
  pairs : Array[KittyGraphicsPair],
  key : Byte,
) -> Int? {
  match kitty_graphics_pair_value(pairs, key) {
    Some(value) => parse_kitty_graphics_i32(value)
    None => None
  }
}

///|
fn kitty_graphics_pair_u8(
  pairs : Array[KittyGraphicsPair],
  key : Byte,
) -> Byte? {
  match kitty_graphics_pair_value(pairs, key) {
    Some(value) =>
      if value.length() == 1 && (value[0] < b'0' || value[0] > b'9') {
        Some(value[0])
      } else {
        match parse_kitty_graphics_u32(value) {
          Some(parsed) =>
            if parsed <= 255U {
              Some(parsed.to_byte())
            } else {
              None
            }
          None => None
        }
      }
    None => None
  }
}

///|
fn parse_kitty_graphics_u32(bytes : Array[Byte]) -> UInt? {
  if bytes.length() == 0 {
    return None
  }

  let mut value : UInt = 0U
  let limit = 4294967295U
  let mut index = 0
  while index < bytes.length() {
    let byte = bytes[index]
    if byte < b'0' || byte > b'9' {
      return None
    }

    let digit = (byte.to_int() - b'0'.to_int()).reinterpret_as_uint()
    if value > limit / 10U || (value == limit / 10U && digit > limit % 10U) {
      return None
    }

    value = value * 10U + digit
    index += 1
  }
  Some(value)
}

///|
fn parse_kitty_graphics_i32(bytes : Array[Byte]) -> Int? {
  if bytes.length() == 0 {
    return None
  }

  let negative = bytes[0] == b'-'
  let start = if negative { 1 } else { 0 }
  if start >= bytes.length() {
    return None
  }

  let mut value : UInt = 0U
  let limit = if negative { 2147483648U } else { 2147483647U }
  let mut index = start
  while index < bytes.length() {
    let byte = bytes[index]
    if byte < b'0' || byte > b'9' {
      return None
    }

    let digit = (byte.to_int() - b'0'.to_int()).reinterpret_as_uint()
    if value > limit / 10U || (value == limit / 10U && digit > limit % 10U) {
      return None
    }

    value = value * 10U + digit
    index += 1
  }

  if negative {
    if value == 2147483648U {
      Some(-2147483648)
    } else {
      Some(-value.reinterpret_as_int())
    }
  } else {
    Some(value.reinterpret_as_int())
  }
}

///|
fn decode_kitty_graphics_base64(data : Array[Byte]) -> Bytes? {
  if data.length() == 0 {
    return Some(b"")
  }

  let decoded : Array[Byte] = []
  let mut quartet : Array[Int] = []
  let mut saw_padding = false

  for byte in data {
    if saw_padding {
      return None
    }

    let value = if byte == b'=' {
      -1
    } else {
      match kitty_graphics_base64_value(byte) {
        Some(v) => v
        None => return None
      }
    }

    quartet.push(value)
    if quartet.length() == 4 {
      let written = match
        decode_kitty_graphics_base64_quartet(decoded, quartet) {
        Some(value) => value
        None => return None
      }
      if written < 3 {
        saw_padding = true
      }
      quartet = []
    }
  }

  match quartet.length() {
    0 => Some(Bytes::from_array(decoded))
    2 => {
      if quartet[0] < 0 || quartet[1] < 0 {
        return None
      }
      decoded.push(((quartet[0] << 2) | (quartet[1] >> 4)).to_byte())
      Some(Bytes::from_array(decoded))
    }
    3 => {
      if quartet[0] < 0 || quartet[1] < 0 || quartet[2] < 0 {
        return None
      }
      decoded.push(((quartet[0] << 2) | (quartet[1] >> 4)).to_byte())
      decoded.push((((quartet[1] & 0x0F) << 4) | (quartet[2] >> 2)).to_byte())
      Some(Bytes::from_array(decoded))
    }
    _ => None
  }
}

///|
fn decode_kitty_graphics_base64_quartet(
  decoded : Array[Byte],
  quartet : Array[Int],
) -> Int? {
  let a = quartet[0]
  let b = quartet[1]
  let c = quartet[2]
  let d = quartet[3]
  if a < 0 || b < 0 {
    return None
  }

  decoded.push(((a << 2) | (b >> 4)).to_byte())
  if c == -1 {
    if d != -1 {
      return None
    }
    return Some(1)
  }
  if c < 0 {
    return None
  }

  decoded.push((((b & 0x0F) << 4) | (c >> 2)).to_byte())
  if d == -1 {
    return Some(2)
  }
  if d < 0 {
    return None
  }

  decoded.push((((c & 0x03) << 6) | d).to_byte())
  Some(3)
}

///|
fn kitty_graphics_base64_value(byte : Byte) -> Int? {
  if byte >= b'A' && byte <= b'Z' {
    return Some(byte.to_int() - b'A'.to_int())
  }
  if byte >= b'a' && byte <= b'z' {
    return Some(26 + byte.to_int() - b'a'.to_int())
  }
  if byte >= b'0' && byte <= b'9' {
    return Some(52 + byte.to_int() - b'0'.to_int())
  }
  if byte == b'+' {
    return Some(62)
  }
  if byte == b'/' {
    return Some(63)
  }
  None
}

///|
fn clone_kitty_graphics_bytes(source : Array[Byte]) -> Array[Byte] {
  let result : Array[Byte] = []
  for value in source {
    result.push(value)
  }
  result
}
