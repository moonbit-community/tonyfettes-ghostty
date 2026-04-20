///|
fn parse_rxvt_extension_command(buffer : Array[Byte]) -> Command? {
  let extension_end = match find_byte(buffer, 0, buffer.length(), b';') {
    Some(index) => index
    None => return None
  }
  if !slice_equals_bytes(buffer, 0, extension_end, b"notify") {
    return None
  }

  let title_end = match
    find_byte(buffer, extension_end + 1, buffer.length(), b';') {
    Some(index) => index
    None => return None
  }

  Some(
    ShowDesktopNotification(
      DesktopNotification::new(
        captured_string(copy_bytes_range(buffer, extension_end + 1, title_end)),
        captured_string(
          copy_bytes_range(buffer, title_end + 1, buffer.length()),
        ),
      ),
    ),
  )
}

///|
fn parse_iterm2_command(buffer : Array[Byte]) -> Command? {
  let separator = find_byte(buffer, 0, buffer.length(), b'=')
  let key_end = match separator {
    Some(index) => index
    None => buffer.length()
  }

  if slice_equals_ascii_ignore_case_bytes(buffer, 0, key_end, b"copy") {
    return parse_iterm2_copy(buffer, separator)
  }
  if slice_equals_ascii_ignore_case_bytes(buffer, 0, key_end, b"currentdir") {
    return parse_iterm2_current_dir(buffer, separator)
  }

  None
}

///|
fn parse_iterm2_copy(buffer : Array[Byte], separator : Int?) -> Command? {
  let value_start = match separator {
    Some(index) => index + 1
    None => return None
  }
  if value_start >= buffer.length() || buffer[value_start] != b':' {
    return None
  }

  let payload_start = value_start + 1
  if payload_start >= buffer.length() {
    return None
  }
  if payload_start + 1 == buffer.length() && buffer[payload_start] == b'?' {
    return None
  }

  Some(
    ClipboardContents({
      kind: b'c',
      data: captured_string(
        copy_bytes_range(buffer, payload_start, buffer.length()),
      ),
    }),
  )
}

///|
fn parse_iterm2_current_dir(buffer : Array[Byte], separator : Int?) -> Command? {
  let value_start = match separator {
    Some(index) => index + 1
    None => return None
  }
  if value_start >= buffer.length() {
    return None
  }

  Some(
    ReportPwd(
      captured_string(copy_bytes_range(buffer, value_start, buffer.length())),
    ),
  )
}

///|
fn slice_equals_bytes(
  bytes : Array[Byte],
  start : Int,
  end_ : Int,
  expected : Bytes,
) -> Bool {
  if end_ - start != expected.length() {
    return false
  }

  let mut index = 0
  while start + index < end_ {
    if bytes[start + index] != expected[index] {
      return false
    }
    index += 1
  }

  true
}

///|
fn slice_equals_ascii_ignore_case_bytes(
  bytes : Array[Byte],
  start : Int,
  end_ : Int,
  expected : Bytes,
) -> Bool {
  if end_ - start != expected.length() {
    return false
  }

  let mut index = 0
  while start + index < end_ {
    if ascii_lower_byte(bytes[start + index]) != expected[index] {
      return false
    }
    index += 1
  }

  true
}

///|
fn ascii_lower_byte(value : Byte) -> Byte {
  if value >= b'A' && value <= b'Z' {
    value + (b'a' - b'A')
  } else {
    value
  }
}
