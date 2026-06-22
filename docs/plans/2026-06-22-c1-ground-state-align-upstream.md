# Align lone C1 (0x80–0x9F) ground-state handling with upstream

Date: 2026-06-22
Branch: `perf/simd-ground-run`

## What changed

`Stream::next_utf8` (`terminal/stream.mbt`) had a MoonBit-only special case that
intercepted a standalone 8-bit C1 control byte (0x80–0x9F) while the UTF-8
decoder was in its accept state and routed it to `execute(byte)` (so e.g. a lone
`0x8E` was executed as SS2 → invoke-charset G2). This case is **removed**: every
ground-state byte now flows through the UTF-8 decoder, exactly as upstream.

## Why (this is removing a deviation, not adding one)

Upstream Ghostty does **not** execute lone C1 bytes in ground state:

- `nextUtf8` (`src/terminal/stream.zig:596`) feeds every ground byte to the
  scalar UTF-8 decoder; `handleCodepoint` (`:624`) executes only `c <= 0xF` (C0)
  and `0x1B` (ESC), everything else prints.
- The SIMD ground loop (`:522-530`) likewise executes only `cp <= 0xF`, else
  prints.
- `execute()`'s C1 branch (`:751-762`, "C1 → ESC c-0x40") is reachable **only**
  via the parser's `.execute` action — i.e. the non-ground `nextNonUtf8` path.
  Ground state bypasses the parser, so a lone C1 never reaches it.

A standalone 0x80–0x9F is a UTF-8 continuation byte with no lead → ill-formed
UTF-8 → the decoder yields **U+FFFD**, which `handle_codepoint` prints. This is
the correct UTF-8-mode behavior (8-bit C1 controls are incompatible with UTF-8;
the 7-bit `ESC <final>` form is how a UTF-8 stream invokes them, and that path —
`\x1BN` etc. — is unchanged because it goes through the parser). Confirmed not an
upstream bug: it is a deliberate design choice in the code structure and the
`execute` doc-comment.

Our `Utf8Decoder::next` already yields `{value: Some(0xFFFD), consumed: true}`
for a lone continuation byte in accept state (`utf8_decoder.mbt:82-85`,
RejectState arm), identical to the 0xA0–0xBF case that already took this path —
so removing the special case needed no decoder change.

## Behavioral delta

- Before: lone `0x8E` in ground → `StreamInvokeCharset({Gl, G2, locking})`.
- After:  lone `0x8E` in ground → `StreamPrint(0xFFFD)`.

7-bit `ESC N`/`ESC O`/`ESC ~` … (invoke-charset) are unaffected (parser path).

## Why now

This was the blocker for wiring `decode_utf8_until_control_seq` (the upstream
`utf8DecodeUntilControlSeq` port) into `next_slice_capped`: that SIMD-shaped
decoder emits U+FFFD for lone C1 (maximal-subpart rule), so it and the scalar
`next_utf8` fallback must agree. They now do.

## Touched

- `terminal/stream.mbt` — removed the C1 special case in `next_utf8`; updated the
  `print_ground_run` doc-comment (the "C1 → execute" claim is gone).
- `terminal/stream_test.mbt` — `stream/c1 execute delegates through esc dispatch`
  renamed to `stream/lone c1 byte decodes to U+FFFD in ground state`, now asserts
  `[StreamPrint(0xFFFD)]`.
- No `.mbti` change (`next_utf8` is private).

## Verification

- `moon test -p terminal --target {wasm,wasm-gc,js,native}` → 558/558 each.
- `moon test -p terminal/utf8_decoder --target all` → 14/14 each.
- `moon check`, `moon fmt`, `moon info` clean.
