///|
fn feed_apc_bytes(handler : ApcHandler, bytes : Bytes) -> Unit {
  for byte in bytes {
    handler.feed(byte)
  }
}

///|
test "apc/unknown command is ignored" {
  let handler = ApcHandler::new()
  handler.start()
  feed_apc_bytes(handler, b"Xabcdef1234")
  guard handler.end() == None else {
    fail("expected unknown APC to be ignored")
  }
}

///|
test "apc/malformed kitty command returns none" {
  let handler = ApcHandler::new()
  handler.start()
  feed_apc_bytes(handler, b"Gabcdef1234")
  guard handler.end() == None else {
    fail("expected malformed kitty APC to return no command")
  }
}

///|
test "apc/kitty u32 overflow returns none" {
  let handler = ApcHandler::new()
  handler.start()
  feed_apc_bytes(handler, b"Ga=p,i=10000000000")
  guard handler.end() == None else {
    fail("expected kitty APC u32 overflow to return no command")
  }
}

///|
test "apc/kitty i32 overflow returns none" {
  let handler = ApcHandler::new()
  handler.start()
  feed_apc_bytes(handler, b"Ga=p,i=1,z=-9999999999")
  guard handler.end() == None else {
    fail("expected kitty APC i32 overflow to return no command")
  }
}

///|
test "apc/valid kitty command yields typed output" {
  let handler = ApcHandler::new()
  handler.start()
  feed_apc_bytes(handler, b"Gf=24,s=10,v=20,hello=world")
  guard handler.end() is Some(Kitty(command)) else {
    fail("expected typed kitty APC command")
  }
  assert_eq(command.payload, "f=24,s=10,v=20,hello=world")
}

///|
test "apc/identify state without bytes returns none" {
  let handler = ApcHandler::new()
  handler.start()
  guard handler.end() == None else {
    fail("expected identify state with no bytes to return no command")
  }
}

///|
test "apc/kitty minimum signed boundary is accepted" {
  let handler = ApcHandler::new()
  handler.start()
  feed_apc_bytes(handler, b"Gz=-2147483648")
  guard handler.end() is Some(Kitty(command)) else {
    fail("expected kitty APC command at i32 minimum")
  }
  assert_eq(command.payload, "z=-2147483648")
}

///|
test "apc/private helper branches and parser states" {
  let handler = ApcHandler::new()
  handler.deinit()
  guard handler.state is Inactive else {
    fail("expected deinit to reset state")
  }

  handler.feed(b'X')
  guard handler.state is Inactive else {
    fail("expected feed while inactive to be ignored")
  }
  guard handler.end() == None else {
    fail("expected inactive end to return none")
  }

  guard !validate_kitty_graphics_payload([]) else {
    fail("expected empty kitty payload to be rejected")
  }
  guard !validate_kitty_graphics_payload([b',']) else {
    fail("expected empty kitty segment to be rejected")
  }

  guard parse_u32_ascii([b'1'], 1, 1) == None else {
    fail("expected empty u32 slice to fail")
  }
  guard parse_u32_ascii([b'a'], 0, 1) == None else {
    fail("expected invalid u32 digit to fail")
  }
  guard parse_u32_ascii([b'4', b'2'], 0, 2) == Some(42U) else {
    fail("expected valid u32 parse")
  }

  guard parse_i32_ascii([b'-'], 0, 1) == None else {
    fail("expected bare minus to fail")
  }
  guard parse_i32_ascii([b'0'], 1, 1) == None else {
    fail("expected empty i32 slice to fail")
  }
  guard parse_i32_ascii([b'a'], 0, 1) == None else {
    fail("expected invalid i32 digit to fail")
  }
  guard parse_i32_ascii([b'-', b'1'], 0, 2) == Some(-1) else {
    fail("expected negative i32 parse")
  }
  guard parse_i32_ascii([b'7'], 0, 1) == Some(7) else {
    fail("expected positive i32 parse")
  }
}
