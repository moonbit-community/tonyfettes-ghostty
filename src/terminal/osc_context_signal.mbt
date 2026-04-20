///|
const ContextSignalMaxIdLength : Int = 64

///|
pub(all) enum ContextSignalAction {
  ContextSignalStart
  ContextSignalEnd
} derive(Eq, Debug)

///|
pub(all) enum ContextSignalType {
  ContextSignalBoot
  ContextSignalContainer
  ContextSignalVm
  ContextSignalElevate
  ContextSignalChpriv
  ContextSignalSubcontext
  ContextSignalRemote
  ContextSignalShell
  ContextSignalCommand
  ContextSignalApp
  ContextSignalService
  ContextSignalSession
} derive(Eq, Debug)

///|
pub(all) enum ContextSignalExitStatus {
  ContextSignalExitSuccess
  ContextSignalExitFailure
  ContextSignalExitCrash
  ContextSignalExitInterrupt
} derive(Eq, Debug)

///|
struct ContextSignalOsc {
  action : ContextSignalAction
  id_unvalidated : Array[Byte]
  metadata_unvalidated : Array[Byte]
} derive(Eq, Debug)

///|
fn ContextSignalOsc::new(
  action : ContextSignalAction,
  id_unvalidated : Array[Byte],
  metadata_unvalidated : Array[Byte],
) -> ContextSignalOsc {
  { action, id_unvalidated, metadata_unvalidated }
}

///|
pub fn ContextSignalOsc::action(self : ContextSignalOsc) -> ContextSignalAction {
  self.action
}

///|
pub fn ContextSignalOsc::id(self : ContextSignalOsc) -> String {
  captured_string(self.id_unvalidated)
}

///|
pub fn ContextSignalOsc::metadata(self : ContextSignalOsc) -> String {
  captured_string(self.metadata_unvalidated)
}

///|
pub fn ContextSignalOsc::context_type(
  self : ContextSignalOsc,
) -> ContextSignalType? {
  match context_signal_option_value(self.metadata_unvalidated, "type") {
    Some(value) => context_signal_type_from_bytes(value)
    None => None
  }
}

///|
pub fn ContextSignalOsc::user(self : ContextSignalOsc) -> String? {
  context_signal_option_string(self.metadata_unvalidated, "user")
}

///|
pub fn ContextSignalOsc::hostname(self : ContextSignalOsc) -> String? {
  context_signal_option_string(self.metadata_unvalidated, "hostname")
}

///|
pub fn ContextSignalOsc::machineid(self : ContextSignalOsc) -> String? {
  context_signal_option_string(self.metadata_unvalidated, "machineid")
}

///|
pub fn ContextSignalOsc::bootid(self : ContextSignalOsc) -> String? {
  context_signal_option_string(self.metadata_unvalidated, "bootid")
}

///|
pub fn ContextSignalOsc::pid(self : ContextSignalOsc) -> UInt64? {
  context_signal_option_uint64(self.metadata_unvalidated, "pid")
}

///|
pub fn ContextSignalOsc::pidfdid(self : ContextSignalOsc) -> UInt64? {
  context_signal_option_uint64(self.metadata_unvalidated, "pidfdid")
}

///|
pub fn ContextSignalOsc::comm(self : ContextSignalOsc) -> String? {
  context_signal_option_string(self.metadata_unvalidated, "comm")
}

///|
pub fn ContextSignalOsc::cwd(self : ContextSignalOsc) -> String? {
  context_signal_option_string(self.metadata_unvalidated, "cwd")
}

///|
pub fn ContextSignalOsc::cmdline(self : ContextSignalOsc) -> String? {
  context_signal_option_string(self.metadata_unvalidated, "cmdline")
}

///|
pub fn ContextSignalOsc::vm(self : ContextSignalOsc) -> String? {
  context_signal_option_string(self.metadata_unvalidated, "vm")
}

///|
pub fn ContextSignalOsc::container(self : ContextSignalOsc) -> String? {
  context_signal_option_string(self.metadata_unvalidated, "container")
}

///|
pub fn ContextSignalOsc::targetuser(self : ContextSignalOsc) -> String? {
  context_signal_option_string(self.metadata_unvalidated, "targetuser")
}

///|
pub fn ContextSignalOsc::targethost(self : ContextSignalOsc) -> String? {
  context_signal_option_string(self.metadata_unvalidated, "targethost")
}

///|
pub fn ContextSignalOsc::sessionid(self : ContextSignalOsc) -> String? {
  context_signal_option_string(self.metadata_unvalidated, "sessionid")
}

///|
pub fn ContextSignalOsc::exit_status(
  self : ContextSignalOsc,
) -> ContextSignalExitStatus? {
  match context_signal_option_value(self.metadata_unvalidated, "exit") {
    Some(value) => context_signal_exit_status_from_bytes(value)
    None => None
  }
}

///|
pub fn ContextSignalOsc::status(self : ContextSignalOsc) -> UInt64? {
  context_signal_option_uint64(self.metadata_unvalidated, "status")
}

///|
pub fn ContextSignalOsc::signal(self : ContextSignalOsc) -> String? {
  context_signal_option_string(self.metadata_unvalidated, "signal")
}

///|
fn parse_context_signal_command(buffer : Array[Byte]) -> Command? {
  if buffer.length() == 0 {
    return None
  }

  let (action, prefix_len) = if buffer.length() >= 6 &&
    slice_equals_ascii(buffer, 0, 5, "start") &&
    buffer[5] == b'=' {
    (ContextSignalStart, 6)
  } else if buffer.length() >= 4 &&
    slice_equals_ascii(buffer, 0, 3, "end") &&
    buffer[3] == b'=' {
    (ContextSignalEnd, 4)
  } else {
    return None
  }

  if prefix_len >= buffer.length() {
    return None
  }

  let id_end = match find_byte(buffer, prefix_len, buffer.length(), b';') {
    Some(index) => index
    None => buffer.length()
  }
  if !context_signal_id_is_valid(buffer, prefix_len, id_end) {
    return None
  }

  let metadata = if id_end < buffer.length() {
    copy_bytes_range(buffer, id_end + 1, buffer.length())
  } else {
    []
  }
  Some(
    ContextSignal(
      ContextSignalOsc::new(
        action,
        copy_bytes_range(buffer, prefix_len, id_end),
        metadata,
      ),
    ),
  )
}

///|
fn context_signal_option_string(
  metadata_unvalidated : Array[Byte],
  key : String,
) -> String? {
  match context_signal_option_value(metadata_unvalidated, key) {
    Some(value) =>
      if value.length() > 0 {
        Some(captured_string(value))
      } else {
        None
      }
    None => None
  }
}

///|
fn context_signal_option_uint64(
  metadata_unvalidated : Array[Byte],
  key : String,
) -> UInt64? {
  match context_signal_option_value(metadata_unvalidated, key) {
    Some(value) => parse_u64_ascii(value, 0, value.length())
    None => None
  }
}

///|
fn context_signal_option_value(
  metadata_unvalidated : Array[Byte],
  key : String,
) -> Array[Byte]? {
  let mut start = 0
  while start <= metadata_unvalidated.length() {
    let segment_end = match
      find_byte(
        metadata_unvalidated,
        start,
        metadata_unvalidated.length(),
        b';',
      ) {
      Some(index) => index
      None => metadata_unvalidated.length()
    }

    match find_byte(metadata_unvalidated, start, segment_end, b'=') {
      Some(eq_index) =>
        if slice_equals_ascii(metadata_unvalidated, start, eq_index, key) {
          return Some(
            copy_bytes_range(metadata_unvalidated, eq_index + 1, segment_end),
          )
        }
      None => ()
    }

    if segment_end == metadata_unvalidated.length() {
      return None
    }
    start = segment_end + 1
  }

  None
}

///|
fn context_signal_id_is_valid(
  buffer : Array[Byte],
  start : Int,
  end_ : Int,
) -> Bool {
  let length = end_ - start
  if length == 0 || length > ContextSignalMaxIdLength {
    return false
  }

  let mut index = start
  while index < end_ {
    let value = buffer[index]
    if value < 0x20 || value > 0x7E {
      return false
    }
    index += 1
  }

  true
}

///|
fn context_signal_type_from_bytes(value : Array[Byte]) -> ContextSignalType? {
  if slice_equals_ascii(value, 0, value.length(), "boot") {
    return Some(ContextSignalBoot)
  }
  if slice_equals_ascii(value, 0, value.length(), "container") {
    return Some(ContextSignalContainer)
  }
  if slice_equals_ascii(value, 0, value.length(), "vm") {
    return Some(ContextSignalVm)
  }
  if slice_equals_ascii(value, 0, value.length(), "elevate") {
    return Some(ContextSignalElevate)
  }
  if slice_equals_ascii(value, 0, value.length(), "chpriv") {
    return Some(ContextSignalChpriv)
  }
  if slice_equals_ascii(value, 0, value.length(), "subcontext") {
    return Some(ContextSignalSubcontext)
  }
  if slice_equals_ascii(value, 0, value.length(), "remote") {
    return Some(ContextSignalRemote)
  }
  if slice_equals_ascii(value, 0, value.length(), "shell") {
    return Some(ContextSignalShell)
  }
  if slice_equals_ascii(value, 0, value.length(), "command") {
    return Some(ContextSignalCommand)
  }
  if slice_equals_ascii(value, 0, value.length(), "app") {
    return Some(ContextSignalApp)
  }
  if slice_equals_ascii(value, 0, value.length(), "service") {
    return Some(ContextSignalService)
  }
  if slice_equals_ascii(value, 0, value.length(), "session") {
    return Some(ContextSignalSession)
  }
  None
}

///|
fn context_signal_exit_status_from_bytes(
  value : Array[Byte],
) -> ContextSignalExitStatus? {
  if slice_equals_ascii(value, 0, value.length(), "success") {
    return Some(ContextSignalExitSuccess)
  }
  if slice_equals_ascii(value, 0, value.length(), "failure") {
    return Some(ContextSignalExitFailure)
  }
  if slice_equals_ascii(value, 0, value.length(), "crash") {
    return Some(ContextSignalExitCrash)
  }
  if slice_equals_ascii(value, 0, value.length(), "interrupt") {
    return Some(ContextSignalExitInterrupt)
  }
  None
}

///|
fn parse_u64_ascii(bytes : Array[Byte], start : Int, end_ : Int) -> UInt64? {
  if start >= end_ {
    return None
  }

  let mut value : UInt64 = 0UL
  let limit = 18446744073709551615UL
  let mut index = start
  while index < end_ {
    let byte = bytes[index]
    if byte < b'0' || byte > b'9' {
      return None
    }

    let digit = (byte.to_int() - b'0'.to_int()).to_uint64()
    if value > limit / 10UL || (value == limit / 10UL && digit > limit % 10UL) {
      return None
    }

    value = value * 10UL + digit
    index += 1
  }

  Some(value)
}
