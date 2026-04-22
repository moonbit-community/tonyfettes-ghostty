///|
struct SystemLogRecorder {
  mut call_count : Int
  mut total_bytes : Int
  levels : Array[SystemLogLevel]
  scopes : Array[Bytes]
  messages : Array[Bytes]
}

///|
fn SystemLogRecorder::new() -> SystemLogRecorder {
  { call_count: 0, total_bytes: 0, levels: [], scopes: [], messages: [] }
}

///|
fn SystemLogRecorder::record(
  self : SystemLogRecorder,
  level : SystemLogLevel,
  scope : Bytes,
  message : Bytes,
) -> Unit {
  self.call_count += 1
  self.total_bytes += message.length()
  self.levels.push(level)
  self.scopes.push(scope)
  self.messages.push(message)
}

///|
fn repeated_bytes(byte : Byte, count : Int) -> Bytes {
  let buffer = @buffer.new(size_hint=count)
  for _ in 0..<count {
    buffer.write_byte(byte)
  }
  buffer.contents()
}

///|
test "terminal system/log callback install clear and small emit" {
  let recorder = SystemLogRecorder::new()
  terminal_system_clear_log()
  terminal_system_set_log(fn(level, scope, message) {
    recorder.record(level, scope, message)
  })

  terminal_system_emit_log(SystemLogLevel::Info, b"test", b"hello")

  guard recorder.call_count == 1 &&
    recorder.total_bytes == 5 &&
    recorder.levels == [SystemLogLevel::Info] &&
    recorder.scopes == [b"test"] &&
    recorder.messages == [b"hello"] else {
    fail("expected small log message to be emitted as one chunk")
  }

  terminal_system_clear_log()
  terminal_system_emit_log(SystemLogLevel::Error, b"test", b"ignored")
  guard recorder.call_count == 1 else {
    fail("expected cleared log callback to ignore messages")
  }
}

///|
test "terminal system/log emit splits messages larger than one chunk" {
  let recorder = SystemLogRecorder::new()
  terminal_system_clear_log()
  terminal_system_set_log(fn(level, scope, message) {
    recorder.record(level, scope, message)
  })

  let payload = repeated_bytes(b'A', 3000)
  terminal_system_emit_log(SystemLogLevel::Warning, b"gfx", payload)
  terminal_system_clear_log()

  guard recorder.call_count == 2 &&
    recorder.total_bytes == 3000 &&
    recorder.levels == [SystemLogLevel::Warning, SystemLogLevel::Warning] &&
    recorder.scopes == [b"gfx", b"gfx"] &&
    recorder.messages[0].length() == 2048 &&
    recorder.messages[1].length() == 952 else {
    fail("expected long log message to be split into bounded chunks")
  }
}

///|
test "terminal system/log emit preserves exact chunk boundaries" {
  let exact = SystemLogRecorder::new()
  terminal_system_clear_log()
  terminal_system_set_log(fn(level, scope, message) {
    exact.record(level, scope, message)
  })
  terminal_system_emit_log(
    SystemLogLevel::Debug,
    b"",
    repeated_bytes(b'B', 2048),
  )

  guard exact.call_count == 1 &&
    exact.total_bytes == 2048 &&
    exact.messages[0].length() == 2048 else {
    fail("expected exact one-chunk log message")
  }

  let double = SystemLogRecorder::new()
  terminal_system_set_log(fn(level, scope, message) {
    double.record(level, scope, message)
  })
  terminal_system_emit_log(
    SystemLogLevel::Debug,
    b"",
    repeated_bytes(b'C', 4096),
  )
  terminal_system_clear_log()

  guard double.call_count == 2 &&
    double.total_bytes == 4096 &&
    double.messages[0].length() == 2048 &&
    double.messages[1].length() == 2048 else {
    fail("expected exact double-chunk log message")
  }
}
