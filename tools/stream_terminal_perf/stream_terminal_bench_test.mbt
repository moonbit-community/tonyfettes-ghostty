// Benchmarks for the StreamTerminal pipeline, using the @bench framework.
// Run with: moon bench -p tools/stream_terminal_perf --release --target native
//
// Each benchmark feeds a fixed payload into a fresh 80x24 terminal, so the
// measured unit is "process this chunk of program output from scratch".

///| Append a decimal integer as ASCII (for CSI/OSC numeric params).
fn put_uint(buf : Buffer, value : Int) -> Unit {
  if value >= 10 {
    put_uint(buf, value / 10)
  }
  buf.write_byte((b'0'.to_int() + value % 10).to_byte())
}

///| Feed a payload into a fresh 80x24 terminal (the measured unit).
fn process(payload : Bytes) -> @terminal.StreamTerminal {
  let t = @terminal.StreamTerminal::new()
  ignore(t.resize(80, 24, 8U, 16U))
  t.next_slice(payload)
  t
}

// ---- payload builders -------------------------------------------------------

///| Normal program output: `lines` rows of 72 printable chars + newline.
fn plain_lines(lines : Int) -> Bytes {
  let line = Buffer(size_hint=256)
  for i in 0..<72 {
    line.write_byte((b'A'.to_int() + i % 26).to_byte())
  }
  line.write_byte(b'\n')
  let lb = line.contents()
  let buf = Buffer(size_hint=256)
  for _ in 0..<lines {
    buf.write_bytes(lb)
  }
  buf.contents()
}

///| One very long line with no newline: stresses auto-wrap.
fn wrapped_blob(chars : Int) -> Bytes {
  let chunk = b"abcdefghijklmnopqrstuvwxyz"
  let buf = Buffer(size_hint=256)
  for _ in 0..<(chars / 26) {
    buf.write_bytes(chunk)
  }
  buf.contents()
}

///| Mostly newlines: stresses scrolling / scrollback.
fn scroll_storm(lines : Int) -> Bytes {
  let buf = Buffer(size_hint=256)
  for _ in 0..<lines {
    buf.write_bytes(b"x\n")
  }
  buf.contents()
}

///| Colored log lines (build output / `ls --color`): heavy SGR churn.
fn colored_log(lines : Int) -> Bytes {
  let buf = Buffer(size_hint=256)
  for i in 0..<lines {
    buf.write_bytes(b"\x1b[1;32m[ OK ]\x1b[0m \x1b[36mservice-")
    put_uint(buf, i % 100)
    buf.write_bytes(b"\x1b[0m started on \x1b[33mport 8080\x1b[0m\n")
  }
  buf.contents()
}

///| Full-screen TUI redraws (vim/htop): cursor addressing + clears.
fn tui_redraw(frames : Int) -> Bytes {
  let buf = Buffer(size_hint=256)
  for _ in 0..<frames {
    buf.write_bytes(b"\x1b[H\x1b[2J")
    for row in 1..<24 {
      buf.write_bytes(b"\x1b[")
      put_uint(buf, row)
      buf.write_bytes(b";1H\x1b[7m row ")
      put_uint(buf, row)
      buf.write_bytes(b" content here \x1b[0m")
    }
  }
  buf.contents()
}

///| CJK wide-character text (UTF-8 multibyte + wide-cell handling).
fn cjk_text(lines : Int) -> Bytes {
  // "中文终端测试" + newline
  let chunk = b"\xE4\xB8\xAD\xE6\x96\x87\xE7\xBB\x88\xE7\xAB\xAF\xE6\xB5\x8B\xE8\xAF\x95\n"
  let buf = Buffer(size_hint=256)
  for _ in 0..<lines {
    for _ in 0..<4 {
      buf.write_bytes(chunk)
    }
  }
  buf.contents()
}

///| OSC title churn interleaved with text.
fn osc_titles(count : Int) -> Bytes {
  let buf = Buffer(size_hint=256)
  for i in 0..<count {
    buf.write_bytes(b"\x1b]0;build step ")
    put_uint(buf, i % 1000)
    buf.write_bytes(b" running\x07compiling module output line\n")
  }
  buf.contents()
}

///| A realistic blend of the above.
fn mixed_realistic(blocks : Int) -> Bytes {
  let buf = Buffer(size_hint=256)
  for i in 0..<blocks {
    buf.write_bytes(b"\x1b]0;make: target ")
    put_uint(buf, i % 50)
    buf.write_bytes(b"\x07")
    buf.write_bytes(b"\x1b[1;34m==>\x1b[0m building \x1b[32msrc/mod.c\x1b[0m\n")
    buf.write_bytes(b"plain compiler output describing what happened here\n")
    buf.write_bytes(b"\x1b[31merror:\x1b[0m something went \x1b[1mwrong\x1b[0m at line ")
    put_uint(buf, i)
    buf.write_bytes(b"\n")
  }
  buf.contents()
}

// ---- benchmarks -------------------------------------------------------------

///|
test "bench plain_lines x200" (it : @bench.T) {
  let payload = plain_lines(200)
  it.bench(fn() { it.keep(process(payload)) })
}

///|
test "bench wrapped_blob 16k" (it : @bench.T) {
  let payload = wrapped_blob(16000)
  it.bench(fn() { it.keep(process(payload)) })
}

///|
test "bench scroll_storm x4000" (it : @bench.T) {
  let payload = scroll_storm(4000)
  it.bench(fn() { it.keep(process(payload)) })
}

///|
test "bench colored_log x200" (it : @bench.T) {
  let payload = colored_log(200)
  it.bench(fn() { it.keep(process(payload)) })
}

///|
test "bench tui_redraw x60" (it : @bench.T) {
  let payload = tui_redraw(60)
  it.bench(fn() { it.keep(process(payload)) })
}

///|
test "bench cjk_text x200" (it : @bench.T) {
  let payload = cjk_text(200)
  it.bench(fn() { it.keep(process(payload)) })
}

///|
test "bench osc_titles x300" (it : @bench.T) {
  let payload = osc_titles(300)
  it.bench(fn() { it.keep(process(payload)) })
}

///|
test "bench mixed_realistic x150" (it : @bench.T) {
  let payload = mixed_realistic(150)
  it.bench(fn() { it.keep(process(payload)) })
}
