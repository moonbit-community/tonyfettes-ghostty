///|
fn expect_cast(source : String) -> Cast raise {
  guard parse_cast(source) is ParseOk(cast) else {
    fail("expected successful cast parse")
  }
  cast
}

///|
fn expect_parse_error(source : String) -> String raise {
  guard parse_cast(source) is ParseErr(message) else {
    fail("expected cast parse error")
  }
  message
}

///|
test "asciicast/parser parses v3 relative timing and event kinds" {
  let cast = expect_cast(
    "{\"version\":3,\"term\":{\"cols\":80,\"rows\":24},\"title\":\"demo\"}\n" +
    "[0.1,\"o\",\"hello\"]\n" +
    "[0.2,\"i\",\"ls\"]\n" +
    "[0.3,\"m\",\"mark\"]\n" +
    "[0.4,\"r\",\"100x30\"]\n" +
    "[0.5,\"x\",\"0\"]\n" +
    "[0.6,\"z\",\"payload\"]\n",
  )
  assert_eq(cast.version, 3)
  guard cast.title == Some("demo") else { fail("expected title") }
  assert_eq(cast.cols, 80)
  assert_eq(cast.rows, 24)
  assert_eq(cast.duration_ms, 2100)
  assert_eq(cast.events.length(), 6)
  guard cast.events[0] == { delay_ms: 100, kind: Output, data: "hello" } else {
    fail("expected output event")
  }
  guard cast.events[1] == { delay_ms: 200, kind: Input, data: "ls" } else {
    fail("expected input event")
  }
  guard cast.events[2] == { delay_ms: 300, kind: Marker, data: "mark" } else {
    fail("expected marker event")
  }
  guard cast.events[3] == { delay_ms: 400, kind: Resize, data: "100x30" } else {
    fail("expected resize event")
  }
  guard cast.events[4] == { delay_ms: 500, kind: Exit, data: "0" } else {
    fail("expected exit event")
  }
  guard cast.events[5] == { delay_ms: 600, kind: Unknown("z"), data: "payload" } else {
    fail("expected unknown event")
  }
}

///|
test "asciicast/parser parses v2 absolute timing and comments" {
  let cast = expect_cast(
    "{\"version\":2,\"width\":90,\"height\":20,\"title\":\"v2\"}\n" +
    "# comment after header\n" +
    "[1.0,\"o\",\"first\"]\n" +
    "[1.25,\"o\",\"second\"]\n" +
    "[2.0,\"o\",\"third\"]\n",
  )
  assert_eq(cast.version, 2)
  guard cast.title == Some("v2") else { fail("expected v2 title") }
  assert_eq(cast.cols, 90)
  assert_eq(cast.rows, 20)
  assert_eq(cast.duration_ms, 2000)
  assert_eq(cast.events[0].delay_ms, 1000)
  assert_eq(cast.events[1].delay_ms, 250)
  assert_eq(cast.events[2].delay_ms, 750)
}

///|
test "asciicast/parser accepts empty title as none" {
  let cast = expect_cast(
    "{\"version\":3,\"term\":{\"cols\":10,\"rows\":5},\"title\":\"\"}\n",
  )
  guard cast.title == None else { fail("expected no title") }
  assert_eq(cast.events.length(), 0)
}

///|
test "asciicast/parser clamps negative seconds to zero" {
  assert_eq(seconds_to_ms(-0.25), 0)
}

///|
test "asciicast/parser rejects empty input" {
  assert_eq(expect_parse_error(""), "empty asciicast")
}

///|
test "asciicast/parser rejects missing header fields" {
  assert_eq(
    expect_parse_error("{\"version\":3,\"term\":{\"cols\":80}}\n"),
    "missing asciicast header fields",
  )
}

///|
test "asciicast/parser rejects unsupported version" {
  assert_eq(
    expect_parse_error("{\"version\":1,\"width\":80,\"height\":24}\n"),
    "unsupported asciicast version 1",
  )
}

///|
test "asciicast/parser reports bad json line" {
  let message = expect_parse_error(
    "{\"version\":3,\"term\":{\"cols\":80,\"rows\":24}}\n" +
    "[0.1,\"o\",\"ok\"]\n" +
    "not-json\n",
  )
  guard message.has_prefix("line 3:") else {
    fail("expected line-numbered json diagnostic")
  }
}

///|
test "asciicast/parser reports bad event shape line" {
  let message = expect_parse_error(
    "{\"version\":3,\"term\":{\"cols\":80,\"rows\":24}}\n" + "[0.1,\"o\"]\n",
  )
  guard message.has_prefix("line 2:") else {
    fail("expected line-numbered event diagnostic")
  }
}

///|
test "asciicast/parser sample parses" {
  let cast = expect_cast(sample_cast())
  assert_eq(cast.version, 3)
  assert_eq(cast.cols, 92)
  assert_eq(cast.rows, 26)
  guard cast.events.length() > 0 else { fail("expected sample events") }
}
