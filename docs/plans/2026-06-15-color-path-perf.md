# Color-path performance: BytesView parsing + case-insensitive lookup

Post-translation performance work on the OSC color path. No behavior change;
all edits map to existing upstream symbols or to the approved compatibility
adapter recorded below.

## Goal

Remove per-command `String` allocations on the OSC color path and replace the
linear X11 named-color scan with a hash lookup, matching upstream Ghostty's
zero-copy byte parsing and comptime string map.

## Upstream files

- `upstream/ghostty/src/terminal/color.zig`
  - `RGB.parse` (byte-slice color spec parser, `#rgb` / `rgb:` / `rgbi:`)
- `upstream/ghostty/src/terminal/x11_color.zig`
  - `ColorMap = std.StaticStringMapWithEql(RGB, eqlAsciiIgnoreCase)`
  - `map` / `map.get(trim(value))`
- `upstream/ghostty/src/terminal/osc/parsers/color.zig`
  - `parseColor`, `parseGetSetAnsiColor`, `parseResetAnsiColor`,
    `parseGetSetDynamicColor`, `parseResetDynamicColor` (all operate on
    `[]const u8` slices via `tokenizeScalar`)

## Approved compatibility adapter

- `CiStrMap` (`terminal/cimap`) is the approved adapter translating upstream's
  `std.StaticStringMapWithEql(RGB, eqlAsciiIgnoreCase)`. MoonBit's core has no
  comptime perfect-hash string map with a case-insensitive equality, so this is
  a build-once, read-only open-addressing map whose hash and equality ASCII
  case-fold, mirroring `eqlAsciiIgnoreCase`. `get_view(BytesView)` reproduces
  `map.get` over a byte slice without allocating a normalized key — the MoonBit
  analogue of looking up by a `[]const u8`.

## MoonBit target files

- `terminal/cimap/cimap.mbt` (adapter), `terminal/cimap/moon.pkg`
- `terminal/color/color.mbt` (`RGB::parse` over `BytesView`)
- `terminal/color/x11_color.mbt` (`x11_color_lookup` via `CiStrMap`)
- `terminal/osc/osc.mbt` (color sub-parsers over `BytesView`)

## Dependencies and invariants

- The generated `terminal/color/x11_color_tables.mbt` data is unchanged; only
  the lookup structure built from it changes.
- `CiStrMap` hash uses unsigned (`UInt`) FNV-1a so the wrap is defined across
  backends (no signed-overflow UB on native/sanitized builds).
- X11 names are ASCII, so the `String`-key and `BytesView`-key hash/eq paths are
  required to agree byte-for-byte.
- The OSC color sub-parsers split the body the way upstream's `tokenizeScalar`
  does — empty `;`-tokens are skipped, not treated as terminators — so inputs
  like `4;;1;red` and `10;;red` still yield the valid request.

## Acceptance criteria

- OSC color parsing allocates no per-command `String`; named lookup is O(1).
- Behavior identical to the linear scan (case-insensitive, space-trimmed).

## Validation commands

- `moon check && moon test && moon fmt && moon info`
- `moon bench --package tonyfettes/ghostty/terminal/cimap --target native --release`

## Coverage findings

- `terminal/cimap` covered by black-box unit tests (case folding, hits/misses,
  empty map). Lookup is also exercised through `terminal/color` named-color
  tests via the public `RGB::parse`.

## Commit scope

- `feat(cimap)`, `perf(color)`, `test(bench)`

## Public API visibility findings

- `.mbti` reviewed. New public surface: `terminal/cimap` exports `CiStrMap`
  (opaque) with `from_entries` / `get` / `get_view`.
- `terminal/color`: **intentional breaking change** — `RGB::parse` changes from
  `String` to `BytesView` (matching upstream's `[]const u8`). Color specs reach
  it as bytes (OSC capture, config bytes), so the byte-view signature avoids a
  decode at every call; the only in-tree callers are the OSC parsers. Downstream
  `String` holders must view their bytes (`s.to_bytes()[:]`).
- `x11_color_lookup` is now internal (implementation detail of `RGB::parse`),
  removed from the public `.mbti`.

## Audit/result notes

- Benchmarked over ~700 entries: `get_view` ~16x faster than the linear scan and
  ~1.8x faster than `Map[Bytes,_]` with a per-call lowercased key.
