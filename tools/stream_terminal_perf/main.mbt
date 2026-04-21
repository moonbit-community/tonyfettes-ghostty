///|
priv struct PerfStats {
  name : String
  bytes : Int
  runs : Int
  min_ms : UInt64
  total_ms : UInt64
}

///|
fn PerfStats::average_ms(self : PerfStats) -> UInt64 {
  self.total_ms / self.runs.to_uint64()
}

///|
fn PerfStats::bytes_per_ms(self : PerfStats) -> UInt64 {
  let average = self.average_ms()
  if average == 0 {
    self.bytes.to_uint64()
  } else {
    self.bytes.to_uint64() / average
  }
}

///|
fn repeated_bytes(chunk : Bytes, repeats : Int) -> Bytes {
  let buffer = @buffer.new(size_hint=chunk.length() * repeats)
  for _ in 0..<repeats {
    buffer.write_bytes(chunk)
  }
  buffer.contents()
}

///|
fn benchmark(
  name : String,
  runs : Int,
  bytes : Int,
  action : () -> Unit,
) -> PerfStats {
  let mut min_ms = 0xFFFF_FFFF_FFFF_FFFFUL
  let mut total_ms = 0UL
  for _ in 0..<runs {
    let started = @env.now()
    action()
    let elapsed = @env.now() - started
    if elapsed < min_ms {
      min_ms = elapsed
    }
    total_ms += elapsed
  }
  { name, bytes, runs, min_ms, total_ms }
}

///|
fn run_printable_bulk(payload : Bytes) -> Unit {
  let terminal = @terminal.StreamTerminal::new()
  terminal.next_slice(payload)
  terminal.deinit()
}

///|
fn run_split_escape(iterations : Int) -> Unit {
  let terminal = @terminal.StreamTerminal::new()
  for _ in 0..<iterations {
    terminal.next_slice(b"\x1B")
    terminal.next_slice(b"[1mA\x1B[0m")
  }
  terminal.deinit()
}

///|
fn run_query_callbacks(iterations : Int) -> Unit {
  let terminal = @terminal.StreamTerminal::new(
    write_pty=fn(_data) { () },
    enquiry=fn() { b"OK" },
    size=fn() { Some(@terminal.Size::new(24, 80, 8, 16)) },
    xtversion=fn() { "libghostty" },
  )
  for _ in 0..<iterations {
    terminal.next_slice(b"\x1B[?7$p\x1B[c\x1B[>q\x05\x1B[18t")
  }
  terminal.deinit()
}

///|
fn print_stats(stats : PerfStats) -> Unit {
  println(
    "\{stats.name}: bytes=\{stats.bytes.to_string()} runs=\{stats.runs.to_string()} min_ms=\{stats.min_ms.to_string()} avg_ms=\{stats.average_ms().to_string()} bytes_per_ms=\{stats.bytes_per_ms().to_string()}",
  )
}

///|
fn main {
  let runs = 5

  let printable_payload = repeated_bytes(
    b"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", 8192,
  )
  let printable_stats = benchmark(
    "printable_bulk",
    runs,
    printable_payload.length(),
    fn() { run_printable_bulk(printable_payload) },
  )

  let split_iterations = 50000
  let split_stats = benchmark("split_escape", runs, split_iterations * 9, fn() {
    run_split_escape(split_iterations)
  })

  let query_iterations = 20000
  let query_stats = benchmark("query_callbacks", runs, query_iterations * 19, fn() {
    run_query_callbacks(query_iterations)
  })

  print_stats(printable_stats)
  print_stats(split_stats)
  print_stats(query_stats)
}
