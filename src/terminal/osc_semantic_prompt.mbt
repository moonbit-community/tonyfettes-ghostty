///|
pub(all) enum SemanticPromptAction {
  FreshLine
  FreshLineNewPrompt
  NewCommand
  PromptStart
  EndPromptStartInput
  EndPromptStartInputTerminateEol
  EndInputStartOutput
  EndCommand
} derive(Eq, Debug)

///|
pub(all) enum SemanticPromptClick {
  Line
  Multiple
  ConservativeVertical
  SmartVertical
} derive(Eq, Debug)

///|
pub(all) enum SemanticPromptKind {
  Initial
  Right
  Continuation
  Secondary
} derive(Eq, Debug)

///|
pub(all) enum SemanticPromptRedraw {
  Enabled
  Disabled
  Last
} derive(Eq, Debug)

///|
pub(all) suberror SemanticPromptDecodeError {
  DecodeError
} derive(Eq, Debug)

///|
struct SemanticPrompt {
  action : SemanticPromptAction
  options_unvalidated : Array[Byte]
} derive(Eq, Debug)

///|
fn SemanticPrompt::new(
  action : SemanticPromptAction,
  options_unvalidated : Array[Byte],
) -> SemanticPrompt {
  { action, options_unvalidated }
}

///|
pub fn SemanticPrompt::action(self : SemanticPrompt) -> SemanticPromptAction {
  self.action
}

///|
pub fn SemanticPrompt::aid(self : SemanticPrompt) -> String? {
  semantic_prompt_option_string(self.options_unvalidated, "aid")
}

///|
pub fn SemanticPrompt::cl(self : SemanticPrompt) -> SemanticPromptClick? {
  match semantic_prompt_option_value(self.options_unvalidated, "cl") {
    Some(value) => semantic_prompt_click_from_bytes(value)
    None => None
  }
}

///|
pub fn SemanticPrompt::prompt_kind(
  self : SemanticPrompt,
) -> SemanticPromptKind? {
  match semantic_prompt_option_value(self.options_unvalidated, "k") {
    Some(value) => semantic_prompt_kind_from_bytes(value)
    None => None
  }
}

///|
pub fn SemanticPrompt::err(self : SemanticPrompt) -> String? {
  semantic_prompt_option_string(self.options_unvalidated, "err")
}

///|
pub fn SemanticPrompt::redraw(self : SemanticPrompt) -> SemanticPromptRedraw? {
  match semantic_prompt_option_value(self.options_unvalidated, "redraw") {
    Some(value) => semantic_prompt_redraw_from_bytes(value)
    None => None
  }
}

///|
pub fn SemanticPrompt::special_key(self : SemanticPrompt) -> Bool? {
  match semantic_prompt_option_value(self.options_unvalidated, "special_key") {
    Some(value) => semantic_prompt_bool_from_bytes(value)
    None => None
  }
}

///|
pub fn SemanticPrompt::click_events(self : SemanticPrompt) -> Bool? {
  match semantic_prompt_option_value(self.options_unvalidated, "click_events") {
    Some(value) => semantic_prompt_bool_from_bytes(value)
    None => None
  }
}

///|
pub fn SemanticPrompt::cmdline(self : SemanticPrompt) -> String? {
  semantic_prompt_option_string(self.options_unvalidated, "cmdline")
}

///|
pub fn SemanticPrompt::cmdline_url(self : SemanticPrompt) -> String? {
  semantic_prompt_option_string(self.options_unvalidated, "cmdline_url")
}

///|
pub fn SemanticPrompt::exit_code(self : SemanticPrompt) -> Int? {
  if self.options_unvalidated.length() == 0 {
    return None
  }

  let first_end = match
    find_byte(
      self.options_unvalidated,
      0,
      self.options_unvalidated.length(),
      b';',
    ) {
    Some(index) => index
    None => self.options_unvalidated.length()
  }
  parse_i32_ascii(self.options_unvalidated, 0, first_end)
}

///|
pub fn SemanticPrompt::decoded_command_line(
  self : SemanticPrompt,
) -> String? raise SemanticPromptDecodeError {
  if semantic_prompt_option_value(self.options_unvalidated, "cmdline")
    is Some(value) {
    return Some(semantic_prompt_printf_q_decode(value))
  }
  if semantic_prompt_option_value(self.options_unvalidated, "cmdline_url")
    is Some(value) {
    return Some(semantic_prompt_url_percent_decode(value))
  }
  None
}

///|
fn parse_semantic_prompt_command(buffer : Array[Byte]) -> Command? {
  if buffer.length() == 0 {
    return None
  }

  match buffer[0] {
    b'A' =>
      semantic_prompt_command_with_optional_options(buffer, FreshLineNewPrompt)
    b'B' =>
      semantic_prompt_command_with_optional_options(buffer, EndPromptStartInput)
    b'C' =>
      semantic_prompt_command_with_optional_options(buffer, EndInputStartOutput)
    b'D' => semantic_prompt_command_with_optional_options(buffer, EndCommand)
    b'I' =>
      semantic_prompt_command_with_optional_options(
        buffer,
        EndPromptStartInputTerminateEol,
      )
    b'L' =>
      if buffer.length() == 1 {
        Some(SemanticPrompt(SemanticPrompt::new(FreshLine, [])))
      } else {
        None
      }
    b'N' => semantic_prompt_command_with_optional_options(buffer, NewCommand)
    b'P' => semantic_prompt_command_with_optional_options(buffer, PromptStart)
    _ => None
  }
}

///|
fn semantic_prompt_command_with_optional_options(
  buffer : Array[Byte],
  action : SemanticPromptAction,
) -> Command? {
  if buffer.length() == 1 {
    return Some(SemanticPrompt(SemanticPrompt::new(action, [])))
  }
  if buffer[1] != b';' {
    return None
  }
  Some(
    SemanticPrompt(
      SemanticPrompt::new(action, copy_bytes_range(buffer, 2, buffer.length())),
    ),
  )
}

///|
fn semantic_prompt_option_string(
  options_unvalidated : Array[Byte],
  key : String,
) -> String? {
  match semantic_prompt_option_value(options_unvalidated, key) {
    Some(value) => Some(captured_string(value))
    None => None
  }
}

///|
fn semantic_prompt_option_value(
  options_unvalidated : Array[Byte],
  key : String,
) -> Array[Byte]? {
  let mut start = 0
  while start <= options_unvalidated.length() {
    let segment_end = match
      find_byte(options_unvalidated, start, options_unvalidated.length(), b';') {
      Some(index) => index
      None => options_unvalidated.length()
    }

    match find_byte(options_unvalidated, start, segment_end, b'=') {
      Some(eq_index) =>
        if slice_equals_ascii(options_unvalidated, start, eq_index, key) {
          return Some(
            copy_bytes_range(options_unvalidated, eq_index + 1, segment_end),
          )
        }
      None => ()
    }

    if segment_end == options_unvalidated.length() {
      return None
    }
    start = segment_end + 1
  }
  None
}

///|
fn semantic_prompt_click_from_bytes(
  value : Array[Byte],
) -> SemanticPromptClick? {
  if value.length() == 1 {
    match value[0] {
      b'm' => Some(Multiple)
      b'v' => Some(ConservativeVertical)
      b'w' => Some(SmartVertical)
      _ => None
    }
  } else if slice_equals_ascii(value, 0, value.length(), "line") {
    Some(Line)
  } else {
    None
  }
}

///|
fn semantic_prompt_kind_from_bytes(value : Array[Byte]) -> SemanticPromptKind? {
  if value.length() != 1 {
    return None
  }
  match value[0] {
    b'i' => Some(Initial)
    b'r' => Some(Right)
    b'c' => Some(Continuation)
    b's' => Some(Secondary)
    _ => None
  }
}

///|
fn semantic_prompt_redraw_from_bytes(
  value : Array[Byte],
) -> SemanticPromptRedraw? {
  if value.length() == 1 {
    match value[0] {
      b'0' => Some(Disabled)
      b'1' => Some(Enabled)
      _ => None
    }
  } else if slice_equals_ascii(value, 0, value.length(), "last") {
    Some(Last)
  } else {
    None
  }
}

///|
fn semantic_prompt_bool_from_bytes(value : Array[Byte]) -> Bool? {
  if value.length() != 1 {
    return None
  }
  match value[0] {
    b'0' => Some(false)
    b'1' => Some(true)
    _ => None
  }
}

///|
fn semantic_prompt_printf_q_decode(
  value : Array[Byte],
) -> String raise SemanticPromptDecodeError {
  let (start, end_) = semantic_prompt_printf_q_range(value)
  let result : Array[Byte] = []
  let mut index = start
  while index < end_ {
    let byte = value[index]
    if byte != b'\\' {
      result.push(byte)
      index += 1
    } else {
      if index + 1 >= end_ {
        raise DecodeError
      }
      match value[index + 1] {
        b' ' | b'\\' | b'"' | b'\'' | b'$' => result.push(value[index + 1])
        b'e' => result.push(0x1B)
        b'n' => result.push(0x0A)
        b'r' => result.push(0x0D)
        b't' => result.push(0x09)
        b'v' => result.push(0x0B)
        _ => raise DecodeError
      }
      index += 2
    }
  }
  let bytes = @buffer.from_array(result[:]).to_bytes()
  @utf8.decode_lossy(bytes[:])
}

///|
fn semantic_prompt_printf_q_range(
  value : Array[Byte],
) -> (Int, Int) raise SemanticPromptDecodeError {
  if value.length() >= 2 && value[0] == b'$' && value[1] == b'\'' {
    if value.length() < 3 || value[value.length() - 1] != b'\'' {
      raise DecodeError
    }
    (2, value.length() - 1)
  } else if value.length() >= 1 && value[0] == b'\'' {
    if value.length() < 2 || value[value.length() - 1] != b'\'' {
      raise DecodeError
    }
    (1, value.length() - 1)
  } else {
    (0, value.length())
  }
}

///|
fn semantic_prompt_url_percent_decode(
  value : Array[Byte],
) -> String raise SemanticPromptDecodeError {
  let result : Array[Byte] = []
  let mut index = 0
  while index < value.length() {
    if value[index] != b'%' {
      result.push(value[index])
      index += 1
    } else {
      if index + 2 >= value.length() {
        raise DecodeError
      }
      let high = match semantic_prompt_hex(value[index + 1]) {
        Some(digit) => digit
        None => raise DecodeError
      }
      let low = match semantic_prompt_hex(value[index + 2]) {
        Some(digit) => digit
        None => raise DecodeError
      }
      result.push((high * 16 + low).to_byte())
      index += 3
    }
  }
  let bytes = @buffer.from_array(result[:]).to_bytes()
  @utf8.decode_lossy(bytes[:])
}

///|
fn semantic_prompt_hex(byte : Byte) -> Int? {
  if byte >= b'0' && byte <= b'9' {
    Some(byte.to_int() - b'0'.to_int())
  } else if byte >= b'a' && byte <= b'f' {
    Some(byte.to_int() - b'a'.to_int() + 10)
  } else if byte >= b'A' && byte <= b'F' {
    Some(byte.to_int() - b'A'.to_int() + 10)
  } else {
    None
  }
}
