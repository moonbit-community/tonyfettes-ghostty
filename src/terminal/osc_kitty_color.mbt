///|
pub(all) enum KittyColorSpecial {
  KittyForeground
  KittyBackground
  KittySelectionForeground
  KittySelectionBackground
  KittyCursor
  KittyCursorText
  KittyVisualBell
  KittySecondTransparentBackground
} derive(Eq, Debug)

///|
pub(all) enum KittyColorKind {
  KittyPalette(Byte)
  KittySpecial(KittyColorSpecial)
} derive(Eq, Debug)

///|
struct KittyColorSet {
  key : KittyColorKind
  color : RGB
} derive(Eq, Debug)

///|
fn KittyColorSet::new(key : KittyColorKind, color : RGB) -> KittyColorSet {
  { key, color }
}

///|
pub fn KittyColorSet::key(self : KittyColorSet) -> KittyColorKind {
  self.key
}

///|
pub fn KittyColorSet::color(self : KittyColorSet) -> RGB {
  self.color
}

///|
pub(all) enum KittyColorRequest {
  KittyQuery(KittyColorKind)
  KittySet(KittyColorSet)
  KittyReset(KittyColorKind)
} derive(Eq, Debug)

///|
struct KittyColorOsc {
  requests : Array[KittyColorRequest]
  terminator : Terminator
} derive(Eq, Debug)

///|
pub fn KittyColorOsc::requests(
  self : KittyColorOsc,
) -> Array[KittyColorRequest] {
  self.requests
}

///|
pub fn KittyColorOsc::terminator(self : KittyColorOsc) -> Terminator {
  self.terminator
}

///|
const KittyColorRequestLimit : Int = 528

///|
fn parse_kitty_color_command(
  buffer : Array[Byte],
  terminator_ch : Byte?,
) -> Command? {
  let requests : Array[KittyColorRequest] = []
  let mut start = 0
  let mut done = false
  while !done {
    if requests.length() >= KittyColorRequestLimit {
      return None
    }

    let segment_end = match find_byte(buffer, start, buffer.length(), b';') {
      Some(index) => index
      None => buffer.length()
    }
    kitty_color_append_request(buffer, start, segment_end, requests)

    done = segment_end == buffer.length()
    if !done {
      start = segment_end + 1
    }
  }

  Some(
    KittyColorProtocol({ requests, terminator: terminator_init(terminator_ch) }),
  )
}

///|
fn kitty_color_append_request(
  buffer : Array[Byte],
  start : Int,
  end_ : Int,
  requests : Array[KittyColorRequest],
) -> Unit {
  let key_end = match find_byte(buffer, start, end_, b'=') {
    Some(index) => index
    None => end_
  }
  if key_end == start {
    return
  }

  let kind = match kitty_color_kind_from_bytes(buffer, start, key_end) {
    Some(kind) => kind
    None => return
  }

  let value_start = if key_end < end_ && buffer[key_end] == b'=' {
    key_end + 1
  } else {
    end_
  }
  let (trimmed_start, trimmed_end) = trim_ascii_spaces(
    buffer, value_start, end_,
  )
  if trimmed_start == trimmed_end {
    requests.push(KittyReset(kind))
    return
  }

  if trimmed_end - trimmed_start == 1 && buffer[trimmed_start] == b'?' {
    requests.push(KittyQuery(kind))
    return
  }

  let spec = captured_string(
    copy_bytes_range(buffer, trimmed_start, trimmed_end),
  )
  let parsed : Result[RGB, ColorParseError] = try? RGB::parse(spec)
  match parsed {
    Ok(color) => requests.push(KittySet(KittyColorSet::new(kind, color)))
    Err(_) => ()
  }
}

///|
fn kitty_color_kind_from_bytes(
  buffer : Array[Byte],
  start : Int,
  end_ : Int,
) -> KittyColorKind? {
  if slice_equals_ascii(buffer, start, end_, "foreground") {
    return Some(KittySpecial(KittyForeground))
  }
  if slice_equals_ascii(buffer, start, end_, "background") {
    return Some(KittySpecial(KittyBackground))
  }
  if slice_equals_ascii(buffer, start, end_, "selection_foreground") {
    return Some(KittySpecial(KittySelectionForeground))
  }
  if slice_equals_ascii(buffer, start, end_, "selection_background") {
    return Some(KittySpecial(KittySelectionBackground))
  }
  if slice_equals_ascii(buffer, start, end_, "cursor") {
    return Some(KittySpecial(KittyCursor))
  }
  if slice_equals_ascii(buffer, start, end_, "cursor_text") {
    return Some(KittySpecial(KittyCursorText))
  }
  if slice_equals_ascii(buffer, start, end_, "visual_bell") {
    return Some(KittySpecial(KittyVisualBell))
  }
  if slice_equals_ascii(buffer, start, end_, "second_transparent_background") {
    return Some(KittySpecial(KittySecondTransparentBackground))
  }

  match
    parse_u32_ascii(copy_bytes_range(buffer, start, end_), 0, end_ - start) {
    Some(value) =>
      if value <= 255U {
        Some(KittyPalette(value.to_byte()))
      } else {
        None
      }
    None => None
  }
}

///|
fn trim_ascii_spaces(
  buffer : Array[Byte],
  start : Int,
  end_ : Int,
) -> (Int, Int) {
  let mut trimmed_start = start
  let mut trimmed_end = end_
  while trimmed_start < trimmed_end && buffer[trimmed_start] == b' ' {
    trimmed_start += 1
  }
  while trimmed_start < trimmed_end && buffer[trimmed_end - 1] == b' ' {
    trimmed_end -= 1
  }
  (trimmed_start, trimmed_end)
}
