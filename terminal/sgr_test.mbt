///|
test "sgr parser/new empty parser yields unset once" {
  let parser = SgrParser::new()
  guard parser.next() == Some(Unset) else {
    fail("expected empty public sgr parser to yield unset")
  }
  guard parser.next() == None else {
    fail("expected empty public sgr parser to finish after unset")
  }
}

///|
test "sgr parser/set params parses and reset rewinds iteration" {
  let parser = SgrParser::new()
  guard parser.set_params([1, 38, 2, 40, 44, 52], []) == Success else {
    fail("expected sgr params to be accepted")
  }

  guard parser.next() == Some(Bold) else {
    fail("expected first sgr attribute to be bold")
  }
  guard parser.next() == Some(DirectColorFg(RGB::new(40, 44, 52))) else {
    fail("expected second sgr attribute to be direct foreground color")
  }
  guard parser.next() == None else {
    fail("expected parser to finish after parsed attributes")
  }

  parser.reset()
  guard parser.next() == Some(Bold) else {
    fail("expected reset to rewind sgr parser iteration")
  }
}

///|
test "sgr parser/unknown payload stays visible through public attribute surface" {
  let parser = SgrParser::new()
  guard parser.set_params([0, 4, 1], [b':', b';', b';']) == Success else {
    fail("expected colon-marked sgr params to be accepted")
  }

  guard parser.next() is Some(Unknown(unknown)) &&
    unknown.full == [0, 4, 1] &&
    unknown.partial == [0, 4] else {
    fail("expected unknown sgr payload to stay observable")
  }
  guard parser.next() == Some(Bold) else {
    fail("expected parser to continue after unknown payload")
  }
}

///|
test "sgr parser/rejects invalid separator lengths" {
  let parser = SgrParser::new()
  guard parser.set_params([1], [b':', b':']) == InvalidValue else {
    fail("expected mismatched separator lengths to be rejected")
  }
}

///|
test "sgr parser/rejects oversized parameter payloads" {
  let parser = SgrParser::new()
  let oversized : Array[UInt16] = []
  for value in 0..<65 {
    oversized.push(value.to_uint16())
  }

  guard parser.set_params(oversized, []) == InvalidValue else {
    fail("expected oversized sgr parameter payload to be rejected")
  }
}
