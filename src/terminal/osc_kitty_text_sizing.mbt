///|
const KittyTextSizingPayloadLimit : Int = 4096

///|
pub(all) enum KittyTextSizingVerticalAlign {
  KittyTextSizingVTop
  KittyTextSizingVBottom
  KittyTextSizingVCenter
} derive(Eq, Debug)

///|
pub(all) enum KittyTextSizingHorizontalAlign {
  KittyTextSizingHLeft
  KittyTextSizingHRight
  KittyTextSizingHCenter
} derive(Eq, Debug)

///|
struct KittyTextSizingOsc {
  scale : Byte
  width : Byte
  numerator : Byte
  denominator : Byte
  valign : KittyTextSizingVerticalAlign
  halign : KittyTextSizingHorizontalAlign
  text : String
  terminator : Terminator
} derive(Eq, Debug)

///|
fn KittyTextSizingOsc::new(
  scale : Byte,
  width : Byte,
  numerator : Byte,
  denominator : Byte,
  valign : KittyTextSizingVerticalAlign,
  halign : KittyTextSizingHorizontalAlign,
  text : String,
  terminator : Terminator,
) -> KittyTextSizingOsc {
  { scale, width, numerator, denominator, valign, halign, text, terminator }
}

///|
pub fn KittyTextSizingOsc::scale(self : KittyTextSizingOsc) -> Byte {
  self.scale
}

///|
pub fn KittyTextSizingOsc::width(self : KittyTextSizingOsc) -> Byte {
  self.width
}

///|
pub fn KittyTextSizingOsc::numerator(self : KittyTextSizingOsc) -> Byte {
  self.numerator
}

///|
pub fn KittyTextSizingOsc::denominator(self : KittyTextSizingOsc) -> Byte {
  self.denominator
}

///|
pub fn KittyTextSizingOsc::valign(
  self : KittyTextSizingOsc,
) -> KittyTextSizingVerticalAlign {
  self.valign
}

///|
pub fn KittyTextSizingOsc::halign(
  self : KittyTextSizingOsc,
) -> KittyTextSizingHorizontalAlign {
  self.halign
}

///|
pub fn KittyTextSizingOsc::text(self : KittyTextSizingOsc) -> String {
  self.text
}

///|
pub fn KittyTextSizingOsc::terminator(self : KittyTextSizingOsc) -> Terminator {
  self.terminator
}

///|
fn parse_kitty_text_sizing_command(
  buffer : Array[Byte],
  terminator_ch : Byte?,
) -> Command? {
  let payload_start = match find_byte(buffer, 0, buffer.length(), b';') {
    Some(index) => index
    None => return None
  }
  let payload = copy_bytes_range(buffer, payload_start + 1, buffer.length())
  if payload.length() > KittyTextSizingPayloadLimit {
    return None
  }
  let text = match decode_safe_utf8(payload) {
    Some(text) => text
    None => return None
  }

  let mut scale : Byte = 1
  let mut width : Byte = 0
  let mut numerator : Byte = 0
  let mut denominator : Byte = 0
  let mut valign = KittyTextSizingVTop
  let mut halign = KittyTextSizingHLeft

  let mut start = 0
  while start < payload_start {
    let segment_end = match find_byte(buffer, start, payload_start, b':') {
      Some(index) => index
      None => payload_start
    }
    match find_byte(buffer, start, segment_end, b'=') {
      Some(eq_index) =>
        if eq_index == start + 1 && eq_index + 1 < segment_end {
          let key = buffer[start]
          let value = copy_bytes_range(buffer, eq_index + 1, segment_end)
          let parsed = parse_u32_ascii(value, 0, value.length())
          match key {
            b's' =>
              match parsed {
                Some(raw) if raw >= 1U && raw <= 7U => scale = raw.to_byte()
                _ => ()
              }
            b'w' =>
              match parsed {
                Some(raw) if raw <= 7U => width = raw.to_byte()
                _ => ()
              }
            b'n' =>
              match parsed {
                Some(raw) if raw <= 15U => numerator = raw.to_byte()
                _ => ()
              }
            b'd' =>
              match parsed {
                Some(raw) if raw <= 15U => denominator = raw.to_byte()
                _ => ()
              }
            b'v' =>
              match parsed {
                Some(0U) => valign = KittyTextSizingVTop
                Some(1U) => valign = KittyTextSizingVBottom
                Some(2U) => valign = KittyTextSizingVCenter
                _ => ()
              }
            b'h' =>
              match parsed {
                Some(0U) => halign = KittyTextSizingHLeft
                Some(1U) => halign = KittyTextSizingHRight
                Some(2U) => halign = KittyTextSizingHCenter
                _ => ()
              }
            _ => ()
          }
        }
      None => ()
    }

    if segment_end == payload_start {
      break
    }
    start = segment_end + 1
  }

  Some(
    KittyTextSizing(
      KittyTextSizingOsc::new(
        scale,
        width,
        numerator,
        denominator,
        valign,
        halign,
        text,
        terminator_init(terminator_ch),
      ),
    ),
  )
}

///|
fn decode_safe_utf8(payload : Array[Byte]) -> String? {
  let bytes = @buffer.from_array(payload[:]).to_bytes()
  let decoded : Result[String, @utf8.Malformed] = try? @utf8.decode(bytes[:])
  match decoded {
    Err(_) => None
    Ok(text) =>
      if kitty_text_contains_escape_control(text) {
        None
      } else {
        Some(text)
      }
  }
}

///|
fn kitty_text_contains_escape_control(text : String) -> Bool {
  for char in text {
    let value = char.to_int()
    if value <= 0x1F || value == 0x7F || (value >= 0x80 && value <= 0x9F) {
      return true
    }
  }
  false
}
