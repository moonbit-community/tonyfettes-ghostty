///|
/// Drive a full OSC command (every byte through `next`, then `end`) so the bench
/// exercises the per-byte dispatch hot path plus the terminal parse/decode.
fn bench_run(parser : OscParser, bytes : Bytes, terminator : Byte?) -> Unit {
  for byte in bytes {
    parser.next(byte)
  }
  parser.end(terminator) |> ignore
}

///|
test (b : @bench.T) {
  let parser = OscParser::new()
  // Window title — the most frequent OSC in practice (shells emit it per prompt).
  let title = b"0;user@host:~/work/project — zsh"
  b.bench(name="title", fn() { b.keep(bench_run(parser, title, Some(0x07))) })

  // Set one ANSI palette color (OSC 4).
  let color4 = b"4;1;rgb:0102/0304/0506"
  b.bench(name="color4", fn() { b.keep(bench_run(parser, color4, Some(0x07))) })

  // Set a dynamic color (OSC 10 foreground).
  let color10 = b"10;rgb:ffff/0000/0000"
  b.bench(name="color10", fn() {
    b.keep(bench_run(parser, color10, Some(0x07)))
  })

  // Hyperlink start (OSC 8) with id + uri.
  let hyperlink = b"8;id=abc123;https://ghostty.org/docs/config/reference"
  b.bench(name="hyperlink", fn() {
    b.keep(bench_run(parser, hyperlink, Some(0x1B)))
  })

  // Semantic prompt (OSC 133) with options.
  let prompt = b"133;A;aid=42;cl=line"
  b.bench(name="semantic_prompt", fn() {
    b.keep(bench_run(parser, prompt, Some(0x07)))
  })

  // Large clipboard payload (OSC 52) — base64 body, the allocating capture path.
  let clip_body = Bytes::make(2000, b'A')
  let clip = b"52;c;".to_array()
  for byte in clip_body {
    clip.push(byte)
  }
  let clip = Bytes::from_array(clip)
  b.bench(name="clipboard_2k", fn() {
    b.keep(bench_run(parser, clip, Some(0x07)))
  })

  // Invalid prefix — fast rejection path (no capture).
  let invalid = b"999z"
  b.bench(name="invalid", fn() {
    b.keep(bench_run(parser, invalid, Some(0x07)))
  })
}
