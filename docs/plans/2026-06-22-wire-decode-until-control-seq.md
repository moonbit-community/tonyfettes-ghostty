# Wire `decode_utf8_until_control_seq` into the ground-state fast path

Date: 2026-06-22
Branch: `perf/simd-ground-run`

## What changed

`Stream::next_slice_capped`'s ground loop now calls the upstream-aligned fused
decoder `@utf8_decoder.decode_utf8_until_control_seq` instead of decoding
byte-at-a-time. This mirrors upstream's `nextSliceCapped` (`src/terminal/
stream.zig:494`) exactly:

- `Stream` gains a reused `cp_buf : FixedArray[UInt]` of `CP_BUF_LEN = 4096`,
  allocated once in `new` (upstream's stack `cp_buf: [4096]u32`).
- `next_slice` chunks input into ≤`CP_BUF_LEN` slices (so each ground run fits
  `cp_buf`, one codepoint per input byte max) and calls `next_slice_capped` per
  chunk. Partial UTF-8 / escape state straddling a chunk boundary is carried in
  the decoder/parser and resolved by the next chunk's prologue.
- The ground loop: `decode_utf8_until_control_seq(input[offset:], cp_buf)` scans
  to the next ESC and bulk-decodes the run in one pass; dispatch is
  `cp <= 0x0F` execute else print (matches upstream `cp <= 0xF`); `offset +=
  res.consumed`; if the stop byte isn't ESC it's a partial UTF-8 tail handed to
  the scalar `next_utf8` (which buffers it); else drain escapes.
- `next_slice_capped` / `consume_all_escapes` / `consume_until_ground` params
  flip `Bytes` → `BytesView` (no copies; the chunk slice is a view).
- Removed the interim Stage-0 `print_ground_run` (bulk `@utf8.decode` into a
  per-run `String`) — it was never committed and is superseded.

Depends on `2026-06-22-c1-ground-state-align-upstream.md`: scalar `next_utf8` and
the fused decoder now agree on lone C1 (both → U+FFFD), so either path can own a
run boundary.

## Why

The byte-at-a-time ground loop paid per-byte decoder-state and dispatch overhead
on plain text (the dominant terminal case). The fused decoder reads runs with
array-pattern matching (8-wide ASCII arm, direct multibyte destructure, no
bounds checks) into a reused buffer — no per-run allocation, unlike the rejected
Stage-0 bulk `@utf8.decode` which allocated a `String` per run and regressed
escape-dense workloads.

## Benchmark (bench/workloads, release native)

baseline = committed HEAD (byte-at-a-time scalar); new = this change.

| workload        | baseline | new      | Δ       |
|-----------------|---------:|---------:|--------:|
| cjk_text        | 721.0 µs | 638.2 µs | −11.5%  |
| wrapped_blob    | 434.9 µs | 385.8 µs | −11.3%  |
| plain_lines     | 456.1 µs | 413.3 µs |  −9.4%  |
| osc_titles      | 473.8 µs | 441.1 µs |  −6.9%  |
| scroll_full     | 7.70 ms  | 7.29 ms  |  −5.3%  |
| mixed_realistic | 750.3 µs | 713.6 µs |  −4.9%  |
| scroll_storm    | 1.20 ms  | 1.15 ms  |  −4.2%  |
| colored_log     | 416.6 µs | 403.2 µs |  −3.2%  |
| color_storm     | 21.36 ms | 21.06 ms |  −1.4%  |
| tui_redraw      | 1.30 ms  | 1.29 ms  |  −0.8%  |
| query_storm     | 8.24 ms  | 8.22 ms  |  −0.2%  |
| sgr_storm       | 7.14 ms  | 7.20 ms  |  +0.8%  |

All plain-text workloads improve 9–11.5%; escape-dense workloads are flat
(within ~1% noise, σ≈50–120 µs on 7–8 ms). Crucially, no regression on
colored_log / query_storm / sgr_storm — the failure mode of the Stage-0 bulk
approach (which had regressed colored_log +4%, query_storm +6.9% from per-run
String allocation) is avoided because runs decode into the reused `cp_buf`.

## Touched

- `terminal/stream.mbt` — `cp_buf` field + `CP_BUF_LEN`; `next_slice` chunking;
  fused `next_slice_capped`; `BytesView` params; removed `print_ground_run`.
- `terminal/stream_test.mbt` — added `stream/c1 byte executes via parser when
  non-ground` (covers `execute`'s C1 branch, now only reachable via the parser).
- No `terminal` `.mbti` change (`next_slice` keeps `Bytes`; the rest private).

## Verification

- `moon test -p terminal --target {wasm,wasm-gc,js,native}` → 559/559 each.
- `moon coverage analyze` → `terminal/stream.mbt` fully covered.
- `moon check`, `moon fmt`, `moon info` clean.
