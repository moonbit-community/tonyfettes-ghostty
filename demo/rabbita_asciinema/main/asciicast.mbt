///|
priv enum CastKind {
  Output
  Input
  Marker
  Resize
  Exit
  Unknown(String)
}

///|
priv struct CastEvent {
  delay_ms : Int
  kind : CastKind
  data : String
}

///|
priv struct Cast {
  version : Int
  title : String?
  cols : Int
  rows : Int
  duration_ms : Int
  events : Array[CastEvent]
}

///|
priv struct CastHeader {
  version : Int
  title : String?
  cols : Int
  rows : Int
}

///|
priv enum HeaderResult {
  HeaderOk(CastHeader)
  HeaderErr(String)
}

///|
priv enum ParseResult {
  ParseOk(Cast)
  ParseErr(String)
}

///|
fn sample_cast() -> String {
  "{\"version\":3,\"term\":{\"cols\":92,\"rows\":26,\"type\":\"xterm-256color\"},\"title\":\"ghostty replay\",\"env\":{\"SHELL\":\"/bin/zsh\"}}\n" +
  "[0.15,\"o\",\"\\u001b[38;5;42m$ moon check --target js\\u001b[0m\\r\\n\"]\n" +
  "[0.28,\"o\",\"Checking tonyfettes/ghostty ...\\r\\n\"]\n" +
  "[0.18,\"o\",\"Checked terminal parser.\\r\\n\\r\\n\"]\n" +
  "[0.25,\"m\",\"build\"]\n" +
  "[0.15,\"o\",\"\\u001b[38;5;81m$ moon build --target js --release demo/rabbita_asciinema/main\\u001b[0m\\r\\n\"]\n" +
  "[0.32,\"o\",\"Rendering with the translated Ghostty terminal model.\\r\\n\"]\n" +
  "[0.22,\"o\",\"No xterm.js parser is used in this demo.\\r\\n\\r\\n\"]\n" +
  "[0.30,\"r\",\"100x28\"]\n" +
  "[0.15,\"m\",\"replay\"]\n" +
  "[0.16,\"o\",\"\\u001b[38;5;214m$ asciinema play ghostty.cast\\u001b[0m\\r\\n\"]\n" +
  "[0.25,\"o\",\"Output events feed StreamTerminal::next_slice.\\r\\n\"]\n" +
  "[0.24,\"o\",\"Resize events call StreamTerminal::resize.\\r\\n\"]\n" +
  "[0.30,\"o\",\"\\r\\n\\u001b]0;Ghostty Rabbita replay\\u0007\\u001b[38;5;118mready\\u001b[0m\\r\\n\"]\n" +
  "[0.40,\"x\",\"0\"]\n"
}

///|
fn seconds_to_ms(seconds : Double) -> Int {
  let ms = (seconds * 1000.0).to_int()
  if ms < 0 {
    0
  } else {
    ms
  }
}

///|
fn title_from_json(value : Json?) -> String? {
  match value {
    Some(String(title)) => if title.is_empty() { None } else { Some(title) }
    _ => None
  }
}

///|
fn parse_header(header : Json) -> HeaderResult {
  if header
    is {
      "version": Number(version, ..),
      "width": Number(width, ..),
      "height": Number(height, ..),
      "title"? : title,
      ..
    } {
    HeaderOk({
      version: version.to_int(),
      title: title_from_json(title),
      cols: width.to_int(),
      rows: height.to_int(),
    })
  } else if header
    is {
      "version": Number(version, ..),
      "term": { "cols": Number(cols, ..), "rows": Number(rows, ..), .. },
      "title"? : title,
      ..
    } {
    HeaderOk({
      version: version.to_int(),
      title: title_from_json(title),
      cols: cols.to_int(),
      rows: rows.to_int(),
    })
  } else {
    HeaderErr("missing asciicast header fields")
  }
}

///|
fn kind_from_code(code : String) -> CastKind {
  match code {
    "o" => Output
    "i" => Input
    "m" => Marker
    "r" => Resize
    "x" => Exit
    other => Unknown(other)
  }
}

///|
fn event_from_json(
  version : Int,
  previous_time : Double,
  json : Json,
) -> (CastEvent, Double) raise {
  let (time, code, data) : (Double, String, String) = @json.from_json(json)
  let delay = if version == 2 {
    seconds_to_ms(time - previous_time)
  } else {
    seconds_to_ms(time)
  }
  let next_time = if version == 2 { time } else { previous_time + time }
  ({ delay_ms: delay, kind: kind_from_code(code), data }, next_time)
}

///|
fn parse_cast(source : String) -> ParseResult {
  let mut header : Json? = None
  let raw_events : Array[(Int, Json)] = []
  let mut line_no = 0
  for piece in source.split("\n") {
    line_no += 1
    let line = piece.trim().to_owned()
    if line.is_empty() {
      continue
    }
    if header is Some(_) && line.strip_prefix("#") is Some(_) {
      continue
    }
    let json = @json.parse(line) catch {
      err => return ParseErr("line \{line_no}: \{err}")
    }
    match header {
      None => header = Some(json)
      Some(_) => raw_events.push((line_no, json))
    }
  }
  guard header is Some(header_json) else { return ParseErr("empty asciicast") }
  let cast_header = match parse_header(header_json) {
    HeaderOk(header) => header
    HeaderErr(message) => return ParseErr(message)
  }
  if cast_header.version != 2 && cast_header.version != 3 {
    return ParseErr("unsupported asciicast version \{cast_header.version}")
  }
  let events : Array[CastEvent] = []
  let mut previous_time = 0.0
  let mut duration_ms = 0
  for raw_event in raw_events {
    let (event_line, json) = raw_event
    let (event, next_time) = event_from_json(
      cast_header.version,
      previous_time,
      json,
    ) catch {
      err => return ParseErr("line \{event_line}: \{err}")
    }
    previous_time = next_time
    duration_ms += event.delay_ms
    events.push(event)
  }
  ParseOk({
    version: cast_header.version,
    title: cast_header.title,
    cols: cast_header.cols,
    rows: cast_header.rows,
    duration_ms,
    events,
  })
}
