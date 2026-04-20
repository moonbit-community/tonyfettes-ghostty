///|
struct WhiteboxRecorder {
  actions : Array[StreamAction]
}

///|
impl StreamHandler for WhiteboxRecorder with vt(self, action) {
  self.actions.push(action)
}

///|
impl StreamHandler for WhiteboxRecorder with deinit(_self) {
  ()
}

///|
fn new_whitebox_stream() -> (Stream[WhiteboxRecorder], Array[StreamAction]) {
  let actions : Array[StreamAction] = []
  (Stream::new({ actions, }), actions)
}

///|
test "stream/private non-utf8 print branch emits stream print" {
  let (stream, actions) = new_whitebox_stream()
  stream.parser.state = Ground
  stream.next_non_utf8(b'x')
  guard actions == [StreamPrint(b'x'.to_uint())] else {
    fail("expected next_non_utf8 print branch to emit stream print")
  }
}
