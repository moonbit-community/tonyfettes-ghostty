// Shared StreamTerminal benchmark workloads. Each `Workload` bundles a fixed
// byte payload (a chunk of program output) with a default iteration count. It
// is consumed two ways:
//   - `moon bench` measures `process(payload)` once per iteration via the
//     `@bench.T` blocks in the white-box test file (mean ± σ statistics).
//   - each `bench/<name>` main package calls `run_main`, which loops
//     `process(payload)` `default_iters` times so `moon run bench/<name>
//     --profile` has a long-enough run for the Time Profiler / perf to sample.
// Both paths share the exact same payload builders below, so the profiled code
// is the code the statistics measure.

///|
/// A named benchmark payload plus the iteration count its main package loops.
struct Workload {
  name : String
  payload : Bytes
  default_iters : Int
}

///|
/// Feed the workload's payload into a fresh 80x24 terminal — the measured unit
/// shared by the statistical benchmark (`@bench.T`) and the profiling main
/// packages (`run_main`).
pub fn Workload::process(self : Workload) -> @terminal.StreamTerminal {
  let t = @terminal.StreamTerminal::new()
  ignore(t.resize(80, 24, 8U, 16U))
  t.next_slice(self.payload)
  t
}

///|
/// A cheap scalar derived from the terminal's final state. Accumulating and
/// printing it in `run_main` keeps the optimizer from eliding the whole
/// `process` call as dead work in a release build (the profiling equivalent of
/// `@bench.T::keep`).
fn checksum(t : @terminal.StreamTerminal) -> UInt64 {
  t.cursor_x().to_uint64() +
  t.cursor_y().to_uint64() +
  t.scrollback_rows().to_uint64()
}

///|
/// Entry point for a `bench/<name>` main package: loop the workload enough times
/// to give a profiler a meaningful sample, then print a checksum so the run
/// cannot be optimized away.
pub fn Workload::run_main(self : Workload) -> Unit {
  let mut acc = 0UL
  for _ in 0..<self.default_iters {
    acc = acc + checksum(self.process())
  }
  println(
    "\{self.name}: iters=\{self.default_iters} payload_bytes=\{self.payload.length()} checksum=\{acc}",
  )
}

///|
/// Append a decimal integer as ASCII (for CSI/OSC numeric params).
fn put_uint(buf : Buffer, value : Int) -> Unit {
  if value >= 10 {
    put_uint(buf, value / 10)
  }
  buf.write_byte((b'0'.to_int() + value % 10).to_byte())
}

///|
/// Normal program output: `lines` rows of 72 printable chars + newline.
pub fn plain_lines() -> Workload {
  let line = Buffer(size_hint=256)
  for i in 0..<72 {
    line.write_byte((b'A'.to_int() + i % 26).to_byte())
  }
  line.write_byte(b'\n')
  let lb = line.contents()
  let buf = Buffer(size_hint=256)
  for _ in 0..<200 {
    buf.write_bytes(lb)
  }
  { name: "plain_lines", payload: buf.contents(), default_iters: 1500 }
}

///|
/// One very long line with no newline: stresses auto-wrap.
pub fn wrapped_blob() -> Workload {
  let chunk = b"abcdefghijklmnopqrstuvwxyz"
  let buf = Buffer(size_hint=256)
  for _ in 0..<(16000 / 26) {
    buf.write_bytes(chunk)
  }
  { name: "wrapped_blob", payload: buf.contents(), default_iters: 2000 }
}

///|
/// `lines` rows of `x\n`: stresses scrolling / scrollback.
fn scroll(lines : Int) -> Bytes {
  let buf = Buffer(size_hint=256)
  for _ in 0..<lines {
    buf.write_bytes(b"x\n")
  }
  buf.contents()
}

///|
/// Mostly newlines, staying within the scrollback limit.
pub fn scroll_storm() -> Workload {
  { name: "scroll_storm", payload: scroll(4000), default_iters: 300 }
}

///|
/// 20_000 newlines overflow the scrollback limit (DefaultMaxScrollback =
/// 10_000), so every line past the limit forces a history eviction — the path
/// `scroll_storm` (4_000 lines) never reaches.
pub fn scroll_full() -> Workload {
  { name: "scroll_full", payload: scroll(20000), default_iters: 80 }
}

///|
/// Colored log lines (build output / `ls --color`): heavy SGR churn.
pub fn colored_log() -> Workload {
  let buf = Buffer(size_hint=256)
  for i in 0..<200 {
    buf.write_bytes(b"\x1b[1;32m[ OK ]\x1b[0m \x1b[36mservice-")
    put_uint(buf, i % 100)
    buf.write_bytes(b"\x1b[0m started on \x1b[33mport 8080\x1b[0m\n")
  }
  { name: "colored_log", payload: buf.contents(), default_iters: 1500 }
}

///|
/// Full-screen TUI redraws (vim/htop): cursor addressing + clears.
pub fn tui_redraw() -> Workload {
  let buf = Buffer(size_hint=256)
  for _ in 0..<60 {
    buf.write_bytes(b"\x1b[H\x1b[2J")
    for row in 1..<24 {
      buf.write_bytes(b"\x1b[")
      put_uint(buf, row)
      buf.write_bytes(b";1H\x1b[7m row ")
      put_uint(buf, row)
      buf.write_bytes(b" content here \x1b[0m")
    }
  }
  { name: "tui_redraw", payload: buf.contents(), default_iters: 800 }
}

///|
/// CJK wide-character text (UTF-8 multibyte + wide-cell handling).
pub fn cjk_text() -> Workload {
  // "中文终端测试" + newline
  let chunk = b"\xE4\xB8\xAD\xE6\x96\x87\xE7\xBB\x88\xE7\xAB\xAF\xE6\xB5\x8B\xE8\xAF\x95\n"
  let buf = Buffer(size_hint=256)
  for _ in 0..<200 {
    for _ in 0..<4 {
      buf.write_bytes(chunk)
    }
  }
  { name: "cjk_text", payload: buf.contents(), default_iters: 900 }
}

///|
/// OSC title churn interleaved with text.
pub fn osc_titles() -> Workload {
  let buf = Buffer(size_hint=256)
  for i in 0..<300 {
    buf.write_bytes(b"\x1b]0;build step ")
    put_uint(buf, i % 1000)
    buf.write_bytes(b" running\x07compiling module output line\n")
  }
  { name: "osc_titles", payload: buf.contents(), default_iters: 1500 }
}

///|
/// Pure OSC color churn (OSC 4 palette + OSC 10/11 dynamic) with no printable
/// payload: every byte drives the OSC parser and the color command apply, with
/// nothing reaching the glyph print path. Isolates the OSC color parse cost
/// (UTF-8 decode of the body, `;`-split, `RGB::parse`), which the micro-bench
/// flags as ~5x the OSC title cost.
pub fn color_storm() -> Workload {
  let buf = Buffer(size_hint=256)
  for i in 0..<20000 {
    buf.write_bytes(b"\x1b]4;")
    put_uint(buf, i % 256)
    buf.write_bytes(b";rgb:0102/0304/0506\x07")
    buf.write_bytes(b"\x1b]10;rgb:ffff/0000/0000\x07")
    buf.write_bytes(b"\x1b]11;#1e1e2e\x07")
  }
  { name: "color_storm", payload: buf.contents(), default_iters: 60 }
}

///|
/// Pure SGR churn with no printable payload to dilute it: every byte is part of
/// an escape sequence, so the whole stream drives `Parser::next` and nothing
/// reaches the glyph print / wrap / scroll path. This isolates the parser's
/// escape-handling cost.
pub fn sgr_storm() -> Workload {
  let buf = Buffer(size_hint=256)
  for _ in 0..<50000 {
    buf.write_bytes(b"\x1b[1m\x1b[0m")
  }
  { name: "sgr_storm", payload: buf.contents(), default_iters: 120 }
}

///|
/// Back-to-back device-status / attribute queries: another parser-bound stream
/// (CSI with intermediates and params) with no text between sequences.
pub fn query_storm() -> Workload {
  let buf = Buffer(size_hint=256)
  for _ in 0..<20000 {
    buf.write_bytes(b"\x1b[?7$p\x1b[c\x1b[>q\x05\x1b[18t")
  }
  { name: "query_storm", payload: buf.contents(), default_iters: 80 }
}

///|
/// A realistic blend of the above.
pub fn mixed_realistic() -> Workload {
  let buf = Buffer(size_hint=256)
  for i in 0..<150 {
    buf.write_bytes(b"\x1b]0;make: target ")
    put_uint(buf, i % 50)
    buf.write_bytes(b"\x07")
    buf.write_bytes(b"\x1b[1;34m==>\x1b[0m building \x1b[32msrc/mod.c\x1b[0m\n")
    buf.write_bytes(b"plain compiler output describing what happened here\n")
    buf.write_bytes(
      b"\x1b[31merror:\x1b[0m something went \x1b[1mwrong\x1b[0m at line ",
    )
    put_uint(buf, i)
    buf.write_bytes(b"\n")
  }
  { name: "mixed_realistic", payload: buf.contents(), default_iters: 900 }
}
