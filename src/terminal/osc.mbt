///|
const OscMaxBuf : Int = 2048

///|
pub(all) enum Terminator {
  St
  Bel
} derive(Eq, Debug)

///|
pub fn terminator_init(ch : Byte?) -> Terminator {
  match ch {
    Some(0x07) => Bel
    _ => St
  }
}

///|
pub(all) enum ColorOperation {
  Osc4
  Osc5
  Osc10
  Osc11
  Osc12
  Osc13
  Osc14
  Osc15
  Osc16
  Osc17
  Osc18
  Osc19
  Osc104
  Osc110
  Osc111
  Osc112
  Osc113
  Osc114
  Osc115
  Osc116
  Osc117
  Osc118
  Osc119
} derive(Eq, Debug)

///|
pub(all) enum ColorTarget {
  Palette(Byte)
  Special(Special)
  Dynamic(Dynamic)
} derive(Eq, Debug)

///|
struct ColoredTarget {
  target : ColorTarget
  color : RGB
} derive(Eq, Debug)

///|
pub fn ColoredTarget::new(target : ColorTarget, color : RGB) -> ColoredTarget {
  { target, color }
}

///|
pub fn ColoredTarget::target(self : ColoredTarget) -> ColorTarget {
  self.target
}

///|
pub fn ColoredTarget::color(self : ColoredTarget) -> RGB {
  self.color
}

///|
pub(all) enum ColorRequest {
  Set(ColoredTarget)
  Query(ColorTarget)
  Reset(ColorTarget)
  ResetPalette
} derive(Eq, Debug)

///|
struct ColorCommand {
  op : ColorOperation
  requests : Array[ColorRequest]
  terminator : Terminator
} derive(Eq, Debug)

///|
pub fn ColorCommand::new(
  op : ColorOperation,
  requests : Array[ColorRequest],
  terminator : Terminator,
) -> ColorCommand {
  { op, requests, terminator }
}

///|
pub fn ColorCommand::op(self : ColorCommand) -> ColorOperation {
  self.op
}

///|
pub fn ColorCommand::requests(self : ColorCommand) -> Array[ColorRequest] {
  self.requests
}

///|
pub fn ColorCommand::terminator(self : ColorCommand) -> Terminator {
  self.terminator
}

///|
struct HyperlinkStart {
  uri : String
  id : String?
} derive(Eq, Debug)

///|
pub fn HyperlinkStart::uri(self : HyperlinkStart) -> String {
  self.uri
}

///|
pub fn HyperlinkStart::id(self : HyperlinkStart) -> String? {
  self.id
}

///|
struct ClipboardContents {
  kind : Byte
  data : String
} derive(Eq, Debug)

///|
pub fn ClipboardContents::kind(self : ClipboardContents) -> Byte {
  self.kind
}

///|
pub fn ClipboardContents::data(self : ClipboardContents) -> String {
  self.data
}

///|
pub(all) enum Command {
  Invalid
  ChangeWindowTitle(String)
  ChangeWindowIcon(String)
  ClipboardContents(ClipboardContents)
  HyperlinkStart(HyperlinkStart)
  HyperlinkEnd
  SemanticPrompt(SemanticPrompt)
  ReportPwd(String)
  MouseShape(String)
  ColorOperation(ColorCommand)
} derive(Eq, Debug)

///|
enum OscParserState {
  Start
  Invalid
  Prefix0
  Prefix1
  Prefix2
  Prefix4
  Prefix5
  Prefix52
  Prefix7
  Prefix8
  Prefix10
  Prefix11
  Prefix12
  Prefix13
  Prefix133
  Prefix14
  Prefix15
  Prefix16
  Prefix17
  Prefix18
  Prefix19
  Prefix22
  Prefix104
  Prefix110
  Prefix111
  Prefix112
  Prefix113
  Prefix114
  Prefix115
  Prefix116
  Prefix117
  Prefix118
  Prefix119
} derive(Eq, Debug)

///|
priv struct OscParser {
  mut state : OscParserState
  mut capturing : Bool
  mut buffer : Array[Byte]
  mut command : Command
} derive(Debug)

///|
fn OscParser::new() -> OscParser {
  { state: Start, capturing: false, buffer: [], command: Invalid }
}

///|
fn OscParser::deinit(self : OscParser) -> Unit {
  self.reset()
}

///|
fn OscParser::reset(self : OscParser) -> Unit {
  self.state = Start
  self.capturing = false
  self.buffer = []
  self.command = Invalid
}

///|
fn OscParser::start_capture(self : OscParser) -> Unit {
  self.capturing = true
  self.buffer = []
}

///|
fn OscParser::push_capture(self : OscParser, byte : Byte) -> Unit {
  if self.buffer.length() >= OscMaxBuf - 1 {
    self.state = Invalid
    self.capturing = false
    self.buffer = []
  } else {
    self.buffer.push(byte)
  }
}

///|
fn OscParser::next(self : OscParser, byte : Byte) -> Unit {
  if self.capturing {
    self.push_capture(byte)
    return
  }

  match self.state {
    Invalid => ()
    Start =>
      match byte {
        b'0' => self.state = Prefix0
        b'1' => self.state = Prefix1
        b'2' => self.state = Prefix2
        b'4' => self.state = Prefix4
        b'5' => self.state = Prefix5
        b'7' => self.state = Prefix7
        b'8' => self.state = Prefix8
        _ => self.state = Invalid
      }
    Prefix0 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix1 =>
      match byte {
        b';' => self.start_capture()
        b'0' => self.state = Prefix10
        b'1' => self.state = Prefix11
        b'2' => self.state = Prefix12
        b'3' => self.state = Prefix13
        b'4' => self.state = Prefix14
        b'5' => self.state = Prefix15
        b'6' => self.state = Prefix16
        b'7' => self.state = Prefix17
        b'8' => self.state = Prefix18
        b'9' => self.state = Prefix19
        _ => self.state = Invalid
      }
    Prefix2 =>
      match byte {
        b';' => self.start_capture()
        b'2' => self.state = Prefix22
        _ => self.state = Invalid
      }
    Prefix4 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix5 =>
      match byte {
        b';' => self.start_capture()
        b'2' => self.state = Prefix52
        _ => self.state = Invalid
      }
    Prefix52 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix7 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix8 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix10 =>
      match byte {
        b';' => self.start_capture()
        b'4' => self.state = Prefix104
        _ => self.state = Invalid
      }
    Prefix11 =>
      match byte {
        b';' => self.start_capture()
        b'0' => self.state = Prefix110
        b'1' => self.state = Prefix111
        b'2' => self.state = Prefix112
        b'3' => self.state = Prefix113
        b'4' => self.state = Prefix114
        b'5' => self.state = Prefix115
        b'6' => self.state = Prefix116
        b'7' => self.state = Prefix117
        b'8' => self.state = Prefix118
        b'9' => self.state = Prefix119
        _ => self.state = Invalid
      }
    Prefix12 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix13 =>
      if byte == b';' {
        self.start_capture()
      } else if byte == b'3' {
        self.state = Prefix133
      } else {
        self.state = Invalid
      }
    Prefix133 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix14 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix15 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix16 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix17 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix18 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix19 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix22 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix104 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix110 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix111 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix112 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix113 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix114 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix115 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix116 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix117 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix118 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
    Prefix119 =>
      if byte == b';' {
        self.start_capture()
      } else {
        self.state = Invalid
      }
  }
}

///|
fn OscParser::end(self : OscParser, terminator_ch : Byte?) -> Command? {
  let result : Command? = match self.state {
    Start => None
    Invalid => None
    Prefix0 =>
      captured_command(
        self.capturing,
        ChangeWindowTitle(captured_string(self.buffer)),
      )
    Prefix1 =>
      captured_command(
        self.capturing,
        ChangeWindowIcon(captured_string(self.buffer)),
      )
    Prefix2 =>
      captured_command(
        self.capturing,
        ChangeWindowTitle(captured_string(self.buffer)),
      )
    Prefix4 => Some(parse_color_command(Prefix4, self.buffer, terminator_ch))
    Prefix5 => Some(parse_color_command(Prefix5, self.buffer, terminator_ch))
    Prefix52 =>
      if self.capturing {
        parse_clipboard_command(self.buffer)
      } else {
        None
      }
    Prefix7 =>
      captured_command(self.capturing, ReportPwd(captured_string(self.buffer)))
    Prefix8 =>
      if self.capturing {
        parse_hyperlink_command(self.buffer)
      } else {
        None
      }
    Prefix10 => Some(parse_color_command(Prefix10, self.buffer, terminator_ch))
    Prefix11 => Some(parse_color_command(Prefix11, self.buffer, terminator_ch))
    Prefix12 => Some(parse_color_command(Prefix12, self.buffer, terminator_ch))
    Prefix13 => Some(parse_color_command(Prefix13, self.buffer, terminator_ch))
    Prefix133 =>
      if self.capturing {
        parse_semantic_prompt_command(self.buffer)
      } else {
        None
      }
    Prefix14 => Some(parse_color_command(Prefix14, self.buffer, terminator_ch))
    Prefix15 => Some(parse_color_command(Prefix15, self.buffer, terminator_ch))
    Prefix16 => Some(parse_color_command(Prefix16, self.buffer, terminator_ch))
    Prefix17 => Some(parse_color_command(Prefix17, self.buffer, terminator_ch))
    Prefix18 => Some(parse_color_command(Prefix18, self.buffer, terminator_ch))
    Prefix19 => Some(parse_color_command(Prefix19, self.buffer, terminator_ch))
    Prefix22 =>
      captured_command(self.capturing, MouseShape(captured_string(self.buffer)))
    Prefix104 =>
      Some(parse_color_command(Prefix104, self.buffer, terminator_ch))
    Prefix110 =>
      Some(parse_color_command(Prefix110, self.buffer, terminator_ch))
    Prefix111 =>
      Some(parse_color_command(Prefix111, self.buffer, terminator_ch))
    Prefix112 =>
      Some(parse_color_command(Prefix112, self.buffer, terminator_ch))
    Prefix113 =>
      Some(parse_color_command(Prefix113, self.buffer, terminator_ch))
    Prefix114 =>
      Some(parse_color_command(Prefix114, self.buffer, terminator_ch))
    Prefix115 =>
      Some(parse_color_command(Prefix115, self.buffer, terminator_ch))
    Prefix116 =>
      Some(parse_color_command(Prefix116, self.buffer, terminator_ch))
    Prefix117 =>
      Some(parse_color_command(Prefix117, self.buffer, terminator_ch))
    Prefix118 =>
      Some(parse_color_command(Prefix118, self.buffer, terminator_ch))
    Prefix119 =>
      Some(parse_color_command(Prefix119, self.buffer, terminator_ch))
  }
  self.reset()
  result
}

///|
fn captured_command(capturing : Bool, command : Command) -> Command? {
  if capturing {
    Some(command)
  } else {
    None
  }
}

///|
fn parse_hyperlink_command(buffer : Array[Byte]) -> Command? {
  let params_end = match find_byte(buffer, 0, buffer.length(), b';') {
    Some(index) => index
    None => return None
  }

  let id = parse_hyperlink_id(buffer, params_end)
  let uri = captured_string(
    copy_bytes_range(buffer, params_end + 1, buffer.length()),
  )
  if uri == "" {
    match id {
      Some(_) => None
      None => Some(HyperlinkEnd)
    }
  } else {
    Some(HyperlinkStart({ uri, id }))
  }
}

///|
fn parse_hyperlink_id(buffer : Array[Byte], end_ : Int) -> String? {
  let mut result : String? = None
  let mut start = 0
  while start <= end_ {
    let segment_end = match find_byte(buffer, start, end_, b':') {
      Some(index) => index
      None => end_
    }

    match find_byte(buffer, start, segment_end, b'=') {
      Some(eq_index) =>
        if slice_equals_ascii(buffer, start, eq_index, "id") &&
          eq_index + 1 < segment_end {
          result = Some(
            captured_string(copy_bytes_range(buffer, eq_index + 1, segment_end)),
          )
        }
      None => ()
    }

    if segment_end == end_ {
      return result
    }
    start = segment_end + 1
  }
  result
}

///|
fn parse_clipboard_command(buffer : Array[Byte]) -> Command? {
  if buffer.length() == 0 {
    return None
  }

  if buffer[0] == b';' {
    return Some(
      ClipboardContents({
        kind: b'c',
        data: captured_string(copy_bytes_range(buffer, 1, buffer.length())),
      }),
    )
  }

  if buffer.length() < 2 || buffer[1] != b';' {
    return None
  }

  Some(
    ClipboardContents({
      kind: buffer[0],
      data: captured_string(copy_bytes_range(buffer, 2, buffer.length())),
    }),
  )
}

///|
fn copy_bytes_range(
  buffer : Array[Byte],
  start : Int,
  end_ : Int,
) -> Array[Byte] {
  let result : Array[Byte] = []
  let mut index = start
  while index < end_ {
    result.push(buffer[index])
    index += 1
  }
  result
}

///|
fn captured_string(buffer : Array[Byte]) -> String {
  let decoder = Utf8Decoder::new()
  let builder = StringBuilder::new(size_hint=buffer.length())
  for byte in buffer {
    let mut consumed = false
    while !consumed {
      let (value, did_consume) = decoder.next(byte)
      consumed = did_consume
      if value is Some(codepoint) {
        builder.write_char(codepoint.reinterpret_as_int().unsafe_to_char())
      }
    }
  }
  builder.to_string()
}

///|
fn parse_color_command(
  state : OscParserState,
  buffer : Array[Byte],
  terminator_ch : Byte?,
) -> Command {
  let op = match color_operation_from_state(state) {
    Some(op) => op
    None => return Invalid
  }
  ColorOperation({
    op,
    requests: parse_color_requests(op, captured_string(buffer)),
    terminator: terminator_init(terminator_ch),
  })
}

///|
fn color_operation_from_state(state : OscParserState) -> ColorOperation? {
  match state {
    Prefix4 => Some(Osc4)
    Prefix5 => Some(Osc5)
    Prefix10 => Some(Osc10)
    Prefix11 => Some(Osc11)
    Prefix12 => Some(Osc12)
    Prefix13 => Some(Osc13)
    Prefix14 => Some(Osc14)
    Prefix15 => Some(Osc15)
    Prefix16 => Some(Osc16)
    Prefix17 => Some(Osc17)
    Prefix18 => Some(Osc18)
    Prefix19 => Some(Osc19)
    Prefix104 => Some(Osc104)
    Prefix110 => Some(Osc110)
    Prefix111 => Some(Osc111)
    Prefix112 => Some(Osc112)
    Prefix113 => Some(Osc113)
    Prefix114 => Some(Osc114)
    Prefix115 => Some(Osc115)
    Prefix116 => Some(Osc116)
    Prefix117 => Some(Osc117)
    Prefix118 => Some(Osc118)
    Prefix119 => Some(Osc119)
    _ => None
  }
}

///|
fn parse_color_requests(
  op : ColorOperation,
  body : String,
) -> Array[ColorRequest] {
  match op {
    Osc4 => parse_get_set_ansi_color(op, body)
    Osc5 => parse_get_set_ansi_color(op, body)
    Osc104 => parse_reset_ansi_color(op, body)
    Osc10 => parse_get_set_dynamic_color(Foreground, body)
    Osc11 => parse_get_set_dynamic_color(Background, body)
    Osc12 => parse_get_set_dynamic_color(Cursor, body)
    Osc13 => parse_get_set_dynamic_color(PointerForeground, body)
    Osc14 => parse_get_set_dynamic_color(PointerBackground, body)
    Osc15 => parse_get_set_dynamic_color(TektronixForeground, body)
    Osc16 => parse_get_set_dynamic_color(TektronixBackground, body)
    Osc17 => parse_get_set_dynamic_color(HighlightBackground, body)
    Osc18 => parse_get_set_dynamic_color(TektronixCursor, body)
    Osc19 => parse_get_set_dynamic_color(HighlightForeground, body)
    Osc110 => parse_reset_dynamic_color(Foreground, body)
    Osc111 => parse_reset_dynamic_color(Background, body)
    Osc112 => parse_reset_dynamic_color(Cursor, body)
    Osc113 => parse_reset_dynamic_color(PointerForeground, body)
    Osc114 => parse_reset_dynamic_color(PointerBackground, body)
    Osc115 => parse_reset_dynamic_color(TektronixForeground, body)
    Osc116 => parse_reset_dynamic_color(TektronixBackground, body)
    Osc117 => parse_reset_dynamic_color(HighlightBackground, body)
    Osc118 => parse_reset_dynamic_color(TektronixCursor, body)
    Osc119 => parse_reset_dynamic_color(HighlightForeground, body)
  }
}

///|
fn parse_get_set_ansi_color(
  op : ColorOperation,
  body : String,
) -> Array[ColorRequest] {
  let result : Array[ColorRequest] = []
  let parts = body.split(";").map(part => part.to_string()).collect()
  let mut index = 0
  while index + 1 < parts.length() {
    let color = match parse_decimal(parts[index]) {
      Some(value) => value
      None => return result
    }
    let target = match ansi_target_from_index(op, color) {
      Some(target) => target
      None => return result
    }
    let spec = parts[index + 1]
    if spec == "?" {
      result.push(Query(target))
    } else {
      let rgb = try RGB::parse(spec) catch {
        _ => return result
      } noraise {
        rgb => rgb
      }
      result.push(Set({ target, color: rgb }))
    }
    index += 2
  }
  result
}

///|
fn parse_reset_ansi_color(
  op : ColorOperation,
  body : String,
) -> Array[ColorRequest] {
  let result : Array[ColorRequest] = []
  let parts = body.split(";").map(part => part.to_string()).collect()
  let mut saw_value = false
  for part in parts {
    let text = part
    if text == "" {
      continue
    }
    saw_value = true
    let color = match parse_decimal(text) {
      Some(value) => value
      None => continue
    }
    let target = match ansi_target_from_index(op, color) {
      Some(target) => target
      None => continue
    }
    result.push(Reset(target))
  }
  if !saw_value {
    result.push(ResetPalette)
  }
  result
}

///|
fn parse_get_set_dynamic_color(
  start : Dynamic,
  body : String,
) -> Array[ColorRequest] {
  let result : Array[ColorRequest] = []
  let parts = body.split(";").map(part => part.to_string()).collect()
  let mut current = Some(start)
  for part in parts {
    let dynamic = match current {
      Some(dynamic) => dynamic
      None => return result
    }
    let spec = part
    if spec == "" {
      return result
    }
    if spec == "?" {
      result.push(Query(Dynamic(dynamic)))
    } else {
      let rgb = try RGB::parse(spec) catch {
        _ => return result
      } noraise {
        rgb => rgb
      }
      result.push(Set({ target: Dynamic(dynamic), color: rgb }))
    }
    current = dynamic.next()
  }
  result
}

///|
fn parse_reset_dynamic_color(
  dynamic : Dynamic,
  body : String,
) -> Array[ColorRequest] {
  let parts = body.split(";").map(part => part.to_string()).collect()
  let mut saw_non_empty = false
  for part in parts {
    if part != "" {
      saw_non_empty = true
      break
    }
  }
  if saw_non_empty {
    []
  } else {
    [Reset(Dynamic(dynamic))]
  }
}

///|
fn ansi_target_from_index(op : ColorOperation, value : Int) -> ColorTarget? {
  match op {
    Osc5 =>
      match special_from_int(value) {
        Some(special) => Some(Special(special))
        None => None
      }
    _ =>
      if value >= 0 && value <= 255 {
        Some(Palette(value.to_byte()))
      } else if value >= 256 {
        match special_from_int(value - 256) {
          Some(special) => Some(Special(special))
          None => None
        }
      } else {
        None
      }
  }
}

///|
fn special_from_int(value : Int) -> Special? {
  match value {
    0 => Some(Bold)
    1 => Some(Underline)
    2 => Some(Blink)
    3 => Some(Reverse)
    4 => Some(Italic)
    _ => None
  }
}

///|
fn parse_decimal(value : String) -> Int? {
  if value == "" {
    return None
  }
  let mut result = 0
  for char in value {
    if char < '0' || char > '9' {
      return None
    }
    result = result * 10 + (char.to_int() - '0'.to_int())
  }
  Some(result)
}
