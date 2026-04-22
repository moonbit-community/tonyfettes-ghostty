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
test "apc/kitty overflow returns none" {
  let handler = ApcHandler::new()
  handler.start()
  feed_apc_bytes(handler, b"Ga=p,i=10000000000")
  guard handler.end() == None else {
    fail("expected kitty APC u32 overflow to return no command")
  }

  handler.start()
  feed_apc_bytes(handler, b"Ga=p,i=1,z=-9999999999")
  guard handler.end() == None else {
    fail("expected kitty APC i32 overflow to return no command")
  }
}

///|
test "apc/valid transmit and display yields typed output" {
  let handler = ApcHandler::new()
  handler.start()
  feed_apc_bytes(handler, b"Ga=T,t=d,f=24,i=1,p=2,s=1,v=2,c=10,r=1;////////")
  guard handler.end() is Some(Kitty(command)) else {
    fail("expected typed kitty APC command")
  }

  guard command.quiet == KittyGraphicsQuiet::No else {
    fail("expected default quiet mode")
  }
  guard command.control is TransmitAndDisplay(value) else {
    fail("expected transmit-and-display control")
  }
  guard value.transmission.format == Rgb &&
    value.transmission.medium == Direct &&
    value.transmission.image_id == 1U &&
    value.transmission.placement_id == 2U &&
    value.transmission.width == 1U &&
    value.transmission.height == 2U else {
    fail("expected parsed transmission fields")
  }
  guard value.display.image_id == 1U &&
    value.display.placement_id == 2U &&
    value.display.columns == 10U &&
    value.display.rows == 1U else {
    fail("expected parsed display fields")
  }
  guard command.data.length() == 6 else {
    fail("expected decoded kitty payload bytes")
  }
}

///|
test "apc/unsupported action is preserved as typed command" {
  let handler = ApcHandler::new()
  handler.start()
  feed_apc_bytes(handler, b"Ga=f,i=3;AAAA")
  guard handler.end() is Some(Kitty(command)) else {
    fail("expected unsupported kitty action to remain typed")
  }
  guard command.control == Unsupported(b'f') else {
    fail("expected unsupported action tag")
  }
}

///|
test "apc/parser helpers preserve upstream defaults" {
  guard parse_kitty_graphics_command_bytes([
      b';', b'Q', b'U', b'F', b'B', b'Q', b'Q',
    ])
    is Some(command) else {
    fail("expected payload-only kitty command")
  }
  guard command.control is Transmit(transmission) &&
    transmission.format == Rgba &&
    transmission.medium == Direct else {
    fail("expected default payload-only transmit command")
  }
  guard command.data == b"AAAA" else {
    fail("expected payload-only base64 decode")
  }

  guard parse_kitty_graphics_command_bytes([
      b'a', b'=', b'p', b',', b'i', b'=', b'1', b',', b'z', b'=', b'-', b'1', b',',
      b'H', b'=', b'-', b'2', b',', b'V', b'=', b'-', b'3',
    ])
    is Some(display_command) else {
    fail("expected signed kitty display parse")
  }
  guard display_command.control is Display(display) &&
    display.z == -1 &&
    display.horizontal_offset == -2 &&
    display.vertical_offset == -3 else {
    fail("expected signed display fields")
  }

  guard parse_kitty_graphics_command_bytes([
      b'h', b'e', b'l', b'l', b'o', b'=', b'w', b'o', b'r', b'l', b'd', b',', b'f',
      b'=', b'2', b'4', b',', b's', b'=', b'1', b',', b'v', b'=', b'2',
    ])
    is Some(ignored_long_key) else {
    fail("expected long unknown key to be ignored")
  }
  guard ignored_long_key.control is Transmit(transmit) &&
    transmit.format == Rgb &&
    transmit.width == 1U &&
    transmit.height == 2U else {
    fail("expected long-key ignore behavior")
  }
}

///|
test "apc/private helper branches and parser states" {
  let handler = ApcHandler::new()
  handler.deinit()
  guard handler.state is Inactive else {
    fail("expected deinit to reset state")
  }

  handler.start()
  guard handler.end() == None else {
    fail("expected identify-without-bytes end to return none")
  }

  guard parse_i32_ascii([], 0, 0) == None else {
    fail("expected empty i32 slice to return none")
  }

  handler.feed(b'X')
  guard handler.state is Inactive else {
    fail("expected feed while inactive to be ignored")
  }
  guard handler.end() == None else {
    fail("expected inactive end to return none")
  }

  guard parse_kitty_graphics_u32([b'4', b'2']) == Some(42U) else {
    fail("expected valid u32 parse")
  }
  guard parse_kitty_graphics_u32([b'a']) == None else {
    fail("expected invalid u32 digit to fail")
  }
  guard parse_kitty_graphics_i32([b'-', b'1']) == Some(-1) else {
    fail("expected negative i32 parse")
  }
  guard parse_kitty_graphics_i32([b'a']) == None else {
    fail("expected invalid i32 digit to fail")
  }
  guard decode_kitty_graphics_base64([b'Q', b'U', b'F', b'B']) == Some(b"AAA") else {
    fail("expected valid base64 decode")
  }
  guard decode_kitty_graphics_base64([b'%']) == None else {
    fail("expected invalid base64 decode to fail")
  }
  guard parse_kitty_graphics_command_bytes([
      b'a', b'=', b'd', b',', b'd', b'=', b'r',
    ]) ==
    None else {
    fail("expected invalid delete selector to fail")
  }
}
