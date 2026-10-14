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
pub struct KittyColorSet {
  key : KittyColorKind
  color : @color.RGB
} derive(Eq, Debug)

///|
pub fn KittyColorSet::new(
  key : KittyColorKind,
  color : @color.RGB,
) -> KittyColorSet {
  { key, color, }
}

///|
pub fn KittyColorSet::key(self : KittyColorSet) -> KittyColorKind {
  self.key
}

///|
pub fn KittyColorSet::color(self : KittyColorSet) -> @color.RGB {
  self.color
}

///|
pub(all) enum KittyColorRequest {
  KittyQuery(KittyColorKind)
  KittySet(KittyColorSet)
  KittyReset(KittyColorKind)
} derive(Eq, Debug)

///|
pub struct KittyColorOsc {
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
const KittyColorRequestLimit : Int32 = 528

///|
fn parse_kitty_color_command(
  buffer : BytesView,
  terminator_ch : Byte?,
) -> Command? {
  let requests : Array[KittyColorRequest] = []
  let mut start = 0
  let mut done = false
  while !done {
    if requests.length() >= KittyColorRequestLimit {
      return None
    }

    let segment_end = match
      @ascii.find_byte(buffer, start, buffer.length(), b';') {
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
    KittyColorProtocol({ requests, terminator: terminator_init(terminator_ch), }),
  )
}

///|
fn kitty_color_append_request(
  buffer : BytesView,
  start : Int32,
  end_ : Int32,
  requests : Array[KittyColorRequest],
) -> Unit {
  let key_end = match @ascii.find_byte(buffer, start, end_, b'=') {
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

  let color = try @color.RGB::parse(buffer[trimmed_start:trimmed_end]) catch {
    _ => return
  } noraise {
    color => color
  }
  requests.push(KittySet(KittyColorSet::new(kind, color)))
}

///|
fn kitty_color_kind_from_bytes(
  buffer : BytesView,
  start : Int32,
  end_ : Int32,
) -> KittyColorKind? {
  if @ascii.slice_equals_ascii(buffer, start, end_, "foreground") {
    return Some(KittySpecial(KittyForeground))
  }
  if @ascii.slice_equals_ascii(buffer, start, end_, "background") {
    return Some(KittySpecial(KittyBackground))
  }
  if @ascii.slice_equals_ascii(buffer, start, end_, "selection_foreground") {
    return Some(KittySpecial(KittySelectionForeground))
  }
  if @ascii.slice_equals_ascii(buffer, start, end_, "selection_background") {
    return Some(KittySpecial(KittySelectionBackground))
  }
  if @ascii.slice_equals_ascii(buffer, start, end_, "cursor") {
    return Some(KittySpecial(KittyCursor))
  }
  if @ascii.slice_equals_ascii(buffer, start, end_, "cursor_text") {
    return Some(KittySpecial(KittyCursorText))
  }
  if @ascii.slice_equals_ascii(buffer, start, end_, "visual_bell") {
    return Some(KittySpecial(KittyVisualBell))
  }
  if @ascii.slice_equals_ascii(
      buffer, start, end_, "second_transparent_background",
    ) {
    return Some(KittySpecial(KittySecondTransparentBackground))
  }

  match @ascii.parse_u32_ascii(buffer, start, end_) {
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
  buffer : BytesView,
  start : Int32,
  end_ : Int32,
) -> (Int32, Int32) {
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

///|
pub extend KittyColorSpecial with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend KittyColorSpecial with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend KittyColorSpecial with @debug.Debug::{to_repr}

///|
pub extend KittyColorKind with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend KittyColorKind with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend KittyColorKind with @debug.Debug::{to_repr}

///|
pub extend KittyColorSet with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend KittyColorSet with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend KittyColorSet with @debug.Debug::{to_repr}

///|
pub extend KittyColorRequest with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend KittyColorRequest with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend KittyColorRequest with @debug.Debug::{to_repr}

///|
pub extend KittyColorOsc with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend KittyColorOsc with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend KittyColorOsc with @debug.Debug::{to_repr}
