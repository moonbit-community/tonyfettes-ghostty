///|
const SystemLogChunkBytes : Int = 2048

///|
pub(all) enum SystemLogLevel {
  Error
  Warning
  Info
  Debug
} derive(Eq, Debug)

///|
struct SystemImage {
  width : UInt
  height : UInt
  data : Bytes
} derive(Eq, Debug)

///|
priv struct TerminalSystemState {
  mut decode_png : (Bytes) -> SystemImage?
  mut decode_png_installed : Bool
  mut log : (SystemLogLevel, Bytes, Bytes) -> Unit
}

///|
let current_terminal_system : TerminalSystemState = TerminalSystemState::new()

///|
pub fn SystemImage::new(
  width : UInt,
  height : UInt,
  data : Bytes,
) -> SystemImage {
  { width, height, data }
}

///|
pub fn SystemImage::width(self : SystemImage) -> UInt {
  self.width
}

///|
pub fn SystemImage::height(self : SystemImage) -> UInt {
  self.height
}

///|
pub fn SystemImage::data(self : SystemImage) -> Bytes {
  self.data
}

///|
fn TerminalSystemState::new() -> TerminalSystemState {
  {
    decode_png: terminal_system_no_decode_png,
    decode_png_installed: false,
    log: terminal_system_no_log,
  }
}

///|
fn TerminalSystemState::set_decode_png(
  self : TerminalSystemState,
  callback : (Bytes) -> SystemImage?,
) -> Unit {
  self.decode_png = callback
  self.decode_png_installed = true
}

///|
fn TerminalSystemState::clear_decode_png(self : TerminalSystemState) -> Unit {
  self.decode_png = terminal_system_no_decode_png
  self.decode_png_installed = false
}

///|
fn TerminalSystemState::set_log(
  self : TerminalSystemState,
  callback : (SystemLogLevel, Bytes, Bytes) -> Unit,
) -> Unit {
  self.log = callback
}

///|
fn TerminalSystemState::clear_log(self : TerminalSystemState) -> Unit {
  self.log = terminal_system_no_log
}

///|
fn TerminalSystemState::emit_log(
  self : TerminalSystemState,
  level : SystemLogLevel,
  scope : Bytes,
  message : Bytes,
) -> Unit {
  (self.log)(level, scope, message)
}

///|
pub fn terminal_system_set_decode_png(
  callback : (Bytes) -> SystemImage?,
) -> Unit {
  current_terminal_system.set_decode_png(callback)
}

///|
pub fn terminal_system_clear_decode_png() -> Unit {
  current_terminal_system.clear_decode_png()
}

///|
pub fn terminal_system_set_log(
  callback : (SystemLogLevel, Bytes, Bytes) -> Unit,
) -> Unit {
  current_terminal_system.set_log(callback)
}

///|
pub fn terminal_system_clear_log() -> Unit {
  current_terminal_system.clear_log()
}

///|
pub fn terminal_system_emit_log(
  level : SystemLogLevel,
  scope : Bytes,
  message : Bytes,
) -> Unit {
  let buffer = @buffer.new(size_hint=SystemLogChunkBytes)
  for byte in message {
    if buffer.length() == SystemLogChunkBytes {
      current_terminal_system.emit_log(level, scope, buffer.contents())
      buffer.reset()
    }
    buffer.write_byte(byte)
  }
  if !buffer.is_empty() {
    current_terminal_system.emit_log(level, scope, buffer.contents())
  }
}

///|
fn terminal_system_decode_png_installed() -> Bool {
  current_terminal_system.decode_png_installed
}

///|
fn terminal_system_decode_png(data : Bytes) -> SystemImage? {
  (current_terminal_system.decode_png)(data)
}

///|
fn terminal_system_no_decode_png(_data : Bytes) -> SystemImage? {
  None
}

///|
fn terminal_system_no_log(
  _level : SystemLogLevel,
  _scope : Bytes,
  _message : Bytes,
) -> Unit {
  ()
}
