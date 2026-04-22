# P9.B Stateless Helper Surface

## Goal

Close the remaining stateless `src/terminal/c` helper contracts in a MoonBit
shape by adding the missing bytes-oriented focus and paste surfaces, and by
auditing the existing style, color, modes, and size-report owner APIs against
the upstream stateless helper contracts.

## Upstream files

- `upstream/ghostty/src/terminal/c/color.zig`
- `upstream/ghostty/src/terminal/c/style.zig`
- `upstream/ghostty/src/terminal/c/modes.zig`
- `upstream/ghostty/src/terminal/c/focus.zig`
- `upstream/ghostty/src/terminal/c/size_report.zig`
- `upstream/ghostty/src/terminal/c/paste.zig`
- `upstream/ghostty/src/terminal/focus.zig`
- `upstream/ghostty/src/input/paste.zig`

## MoonBit target files

- `src/terminal/focus.mbt`
- `src/terminal/focus_test.mbt`
- `src/terminal/paste.mbt`
- `src/terminal/paste_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-22-p9-b-stateless-helper-surface.md`

## Dependency notes

- `color.zig`, `modes.zig`, and `size_report.zig` were already semantically
  covered by the existing owner APIs:
  - `RGB::r/g/b`
  - `ReportState::code()` and `Report::encode()`
  - `size_report.encode(...)`
- `focus.zig` and `paste.zig` were the real missing surfaces. They need to stay
  bytes-oriented, not string-oriented, because the upstream contracts operate
  on terminal byte streams.
- `style.zig` does not need a literal C-shaped mirror. The pre-existing MoonBit
  style surface already exposes the same semantics through
  `StyleColor::is_default()`, `StyleColor::palette_index()`,
  `StyleColor::rgb_value()`, and `CellStyle::underline()`.
- `paste.zig` does two distinct things that must stay separate:
  - `paste_is_safe(...)` flags suspicious payloads (`\n`, `ESC[201~`)
  - encoding always sanitizes unsafe control bytes to spaces and rewrites
    newline to carriage return in unbracketed mode

## Acceptance criteria

- Focus events encode to the same CSI byte sequences as upstream.
- Paste helpers expose a MoonBit-owned options surface and preserve upstream
  sanitization, bracketed fenceposts, and unbracketed newline rewriting.
- Style inspection remains satisfied by the existing typed MoonBit observation
  helpers without adding new ABI-shaped projection API.
- The existing `color`, `modes`, and `size_report` owner APIs are explicitly
  audited as satisfying their upstream stateless helper contracts.
- Blackbox tests cover all newly added public behavior.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/focus.mbt` is fully covered by `src/terminal/focus_test.mbt`.
- `src/terminal/paste.mbt` is fully covered by `src/terminal/paste_test.mbt`,
  including:
  - bracketed vs unbracketed encode paths
  - suspicious-payload detection
  - control-byte sanitization
  - newline rewrite behavior
- Pre-existing uncovered lines outside this slice remain in:
  - `src/terminal/stream.mbt:222`
  - documented invariant-only branches in `src/terminal/stream_terminal_bridge.mbt`
  - `tools/stream_terminal_perf/main.mbt`

## Commit scope

- `feat(c-surface-foundation): add stateless helper surface`

## Review findings

- `FocusEvent` is justified public surface because external callers need to
  construct the semantic event and encode it.
- `PasteOptions` stays opaque and only exposes `new` and `encode`; callers
  cannot mutate fields directly.
- `paste_is_safe` is intentionally a named free function instead of a generic
  package-level `is_safe` to avoid a vague public API entry.
- The review pass explicitly rejected test-driven additions such as
  `StyleColorTag`, `SgrUnderline::code()`, and `PasteOptions::bracketed()`;
  those APIs were removed before closeout.
- No public mutable fields were introduced. `pkg.generated.mbti` growth is
  limited to deliberate host-facing semantic values.

## Audit/result notes after implementation

- Added `FocusEvent::encode()` returning the upstream focus-report byte
  sequences.
- Added opaque `PasteOptions` plus `PasteOptions::encode()` and
  `paste_is_safe(...)`.
- Kept paste encoding faithful to upstream behavior:
  - strip xterm-style unsafe control bytes to spaces in every mode
  - wrap bracketed paste with `ESC[200~` and `ESC[201~`
  - rewrite `\n` to `\r` only in unbracketed mode
- Audited the pre-existing owner APIs and confirmed no additional code changes
  were needed for `color.zig`, `style.zig`, `modes.zig`, or
  `size_report.zig`.
