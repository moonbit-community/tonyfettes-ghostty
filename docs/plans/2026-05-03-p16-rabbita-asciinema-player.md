# P16 Rabbita Asciinema Player

## Goal

Build a browser asciinema player that uses Rabbita for the UI shell and the
translated Ghostty terminal surface for terminal parsing and screen state.

The player should be similar in workflow to `rabbita_xterm/examples/web`, but
it must not delegate terminal parsing or screen mutation to xterm.js. Output
bytes from asciicast events should flow into `StreamTerminal::next_slice`, and
the rendered viewport should be derived from the translated terminal model.

## Local survey

- `~/Workspace/moonbit/rabbita` is the local Rabbita repository. Its core
  packages provide the `cell`/`update`/`view` model, commands, subscriptions,
  typed HTML builders, file-input compatible DOM events, and raw `inner_html`
  support behind an explicit XSS warning.
- `~/Workspace/moonbit/feihaoxiang/rabbita_xterm` is the closest reference.
  Its `examples/web` demo already has:
  - asciicast v2/v3 NDJSON parsing
  - sample cast data
  - file loading through a JS `File` input helper
  - play/pause/scrub/speed/theme controls
  - resize, marker, and exit-event handling
  - Rabbita command scheduling via delayed `Step` messages
- This repository already exposes the terminal pieces needed for a Rabbita
  player:
  - `StreamTerminal::new`, `next_slice`, `reset`, `resize`, title and side
    effect callbacks
  - `RenderState::update` and row/cell iterators for viewport rendering
  - `Formatter::new_terminal(..., Format::Html)` for generated escaped HTML
    snapshots
  - `StreamTerminal::screen_row_snapshot`,
    `StreamTerminal::screen_cell_snapshot`, and `grid_ref_*` helpers for a
    cell renderer
- `moon check --target js` passes for this repository as of 2026-05-03, with
  only existing deprecation warnings. The translated terminal package is not
  native-only.
- `docs/plans/2026-04-23-p15-terminal-playground.md` and
  `tools/terminal_playground_core/` are useful references for session
  lifecycle, resize defaults, side-effect capture, and formatter-based browser
  rendering, but P16 should use a Rabbita JS target rather than the P15
  TypeScript + `wasm-gc` shell.

## Upstream and reference files

Ghostty source-of-truth semantics:

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/stream_terminal.zig`
- `upstream/ghostty/src/terminal/c/formatter.zig`
- `upstream/ghostty/src/terminal/c/render.zig`

Translated MoonBit terminal surface:

- `src/terminal/stream_terminal.mbt`
- `src/terminal/stream_terminal_bridge.mbt`
- `src/terminal/render_state.mbt`
- `src/terminal/render_row_iterator.mbt`
- `src/terminal/page_state.mbt`
- `src/terminal/formatter.mbt`

Rabbita references:

- `~/Workspace/moonbit/rabbita/rabbita/pkg.generated.mbti`
- `~/Workspace/moonbit/rabbita/rabbita/cmd/pkg.generated.mbti`
- `~/Workspace/moonbit/rabbita/rabbita/sub/pkg.generated.mbti`
- `~/Workspace/moonbit/rabbita/rabbita/html/attrs.mbt`
- `~/Workspace/moonbit/rabbita/templates/rabbita-template/`

Asciicast player reference:

- `~/Workspace/moonbit/feihaoxiang/rabbita_xterm/examples/web/main.mbt`
- `~/Workspace/moonbit/feihaoxiang/rabbita_xterm/examples/web/asciicast.mbt`
- `~/Workspace/moonbit/feihaoxiang/rabbita_xterm/examples/web/file_loader.mbt`
- `~/Workspace/moonbit/feihaoxiang/rabbita_xterm/examples/web/style.css`

## MoonBit target files

Keep the core terminal module dependency-free. Add Rabbita as a dependency only
in a nested demo module:

- `moon.work`
- `demo/rabbita_asciinema/moon.mod.json`
- `demo/rabbita_asciinema/index.html`
- `demo/rabbita_asciinema/styles.css`
- `.github/workflows/pages.yml`
- `demo/rabbita_asciinema/main/moon.pkg`
- `demo/rabbita_asciinema/main/asciicast.mbt`
- `demo/rabbita_asciinema/main/asciicast_wbtest.mbt`
- `demo/rabbita_asciinema/main/file_loader.mbt`
- `demo/rabbita_asciinema/main/ghostty_terminal.mbt`
- `demo/rabbita_asciinema/main/ghostty_terminal_wbtest.mbt`
- `demo/rabbita_asciinema/main/main.mbt`
- `demo/rabbita_asciinema/main/main_wbtest.mbt`
- `demo/rabbita_asciinema/main/pkg.generated.mbti`
- `demo/rabbita_asciinema/README.md`

Only add or change files under `src/terminal/` if the demo exposes a real
missing public surface. Any such API change must be minimal and audited in
`src/terminal/pkg.generated.mbti`.

## Dependency notes and invariants

- `demo/rabbita_asciinema/moon.mod.json` should depend on:
  - `tonyfettes/ghostty` through a local path dependency to `../..`
  - `moonbit-community/rabbita` at the same compatible version used by the
    local `rabbita_xterm` reference, currently `0.12.1`
- The demo module should set `preferred-target` to `js` and `main/moon.pkg`
  should set `supported_targets = "js"`.
- Do not add `moonbit-community/rabbita` to the root `tonyfettes/ghostty`
  module. The parser stack should remain usable without browser UI deps.
- The terminal flow is:
  `CastEvent(Output) -> Bytes -> StreamTerminal::next_slice -> RenderState::update -> Rabbita Html`.
- Resize events must call `StreamTerminal::resize` with cast columns/rows and
  fixed cell pixel defaults before re-rendering.
- OSC title changes must use the existing `title_changed` callback plus
  `StreamTerminal::title` to update player metadata.
- Host side effects should be captured, not dropped:
  - bell count
  - PTY replies from device-status or enquiry sequences
  - title-change count or last title
- Asciicast `Input` events remain ignored for the initial player, matching the
  xterm reference demo. They can be shown in metadata later.
- Rendering must preserve fixed terminal geometry. A first prototype may use
  `Formatter::Html` because it escapes codepoints and hyperlink attributes, but
  the accepted player should prefer a viewport renderer over `RenderState` rows
  so it does not accidentally display full scrollback as the active screen.
- Avoid passing user cast bytes directly to Rabbita `Attrs::inner_html`. If
  generated formatter HTML is used, add explicit escaping tests and document
  that only formatter-generated output reaches `inner_html`.
- Wide cells, spacer cells, hyperlinks, invisible text, inverse color, and
  grapheme clusters need renderer-specific audit. If grapheme clusters require
  `grid_ref_graphemes`, use the public `Point::Viewport` and `grid_ref_*`
  helpers before adding new core API.

## Implementation tasks

### P16.0: Plan and boundary check

Status: done for this document.

Acceptance:

- local Rabbita, `rabbita_xterm`, and terminal surfaces are mapped
- feasibility of JS target is checked
- implementation boundary keeps Rabbita outside the core parser package

Validation:

- `moon check --target js`

### P16.1: Demo module skeleton

Status: done.

Create the nested JS module and static app shell.

Acceptance:

- `demo/rabbita_asciinema` builds as a Rabbita app with a placeholder view
- `moon.work` includes the root module and the demo module
- the root module does not gain a Rabbita dependency
- the browser entry references the MoonBit release JS artifact directly, so
  deployment does not require a Node/Vite build step

Validation:

- `moon -C demo/rabbita_asciinema check --target js`
- `moon -C demo/rabbita_asciinema build --target js --release main`

Commit scope:

- `feat(rabbita-player)`

### P16.2: Asciicast parser

Status: done.

Port the parser from `rabbita_xterm/examples/web/asciicast.mbt` into the demo
module, keeping it private to the player unless a reusable package is later
needed.

Acceptance:

- supports asciicast v2 and v3 headers
- supports `o`, `i`, `m`, `r`, `x`, and unknown event codes
- converts v2 absolute event times and v3 relative event times to millisecond
  delays
- handles comments after the header and reports line-numbered JSON errors
- tests cover v2, v3, resize, marker, exit, unknown, empty input, bad JSON, and
  unsupported version

Validation:

- `moon -C demo/rabbita_asciinema test`
- `moon -C demo/rabbita_asciinema coverage analyze`

Commit scope:

- `feat(rabbita-player)`

### P16.3: Ghostty terminal Rabbita adapter

Status: done.

Create a small managed adapter inside the demo module. It should be shaped like
`rabbita_xterm` but own `@terminal.StreamTerminal` and `@terminal.RenderState`
instead of JS xterm handles.

Suggested responsibilities:

- create/reset/deinit terminal sessions
- apply output bytes and resize events
- capture bell, PTY writes, and title updates
- update `RenderState` after mutations
- expose a `view` helper that renders the viewport
- expose enough state for player metadata: title, size, cursor, screen, side
  effect counters, and last PTY reply

Acceptance:

- output bytes mutate `StreamTerminal`
- resize updates terminal dimensions and render dimensions
- title, bell, and PTY callbacks are observable in adapter state
- renderer preserves rows/columns and stable cell sizing
- renderer covers SGR foreground/background, bold, italic, underline,
  strikethrough, inverse, invisible, hyperlinks, wide/spacer cells, and cursor
  position at an acceptable MVP level
- no core public API is widened unless renderer coverage proves it is necessary

Validation:

- `moon -C demo/rabbita_asciinema test`
- `moon -C demo/rabbita_asciinema coverage analyze`
- `moon -C demo/rabbita_asciinema info`
- `moon check`, `moon test`, `moon coverage analyze`, and `moon info` if any
  core `src/terminal` files changed
- review `demo/rabbita_asciinema/main/pkg.generated.mbti`
- review `src/terminal/pkg.generated.mbti` if any core API changed

Commit scope:

- `feat(rabbita-player)`

### P16.4: Player UI

Status: done.

Adapt the Rabbita update/view structure from `rabbita_xterm/examples/web`.

Acceptance:

- starts with an embedded sample cast
- starts replay after initial render without requiring xterm.js
- supports play, pause, scrub, step by scheduled event, speed cycle, theme
  toggle, and local file load
- resize events resize the Ghostty terminal model
- marker and exit events update visible metadata
- terminal title prefers OSC title, then cast title, then file name
- layout keeps the terminal as the first-class surface and avoids explanatory
  landing-page composition

Validation:

- `moon -C demo/rabbita_asciinema check --target js`
- `moon -C demo/rabbita_asciinema build --target js --release main`
- serve the demo locally and smoke-test sample playback plus a loaded `.cast`
  file

Commit scope:

- `feat(rabbita-player)`

### P16.5: Closeout and documentation

Status: done.

Document how to build and serve the demo.

Acceptance:

- `demo/rabbita_asciinema/README.md` explains local build and serve commands
- `docs/plan.md` gains a concise P16 entry if the implementation is accepted as
  part of the main project plan
- any validation or coverage residue is recorded in this plan

Validation:

- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`
- `moon -C demo/rabbita_asciinema check --target js`
- `moon -C demo/rabbita_asciinema test`
- `moon -C demo/rabbita_asciinema coverage analyze`
- `moon -C demo/rabbita_asciinema fmt`
- `moon -C demo/rabbita_asciinema info`
- `moon -C demo/rabbita_asciinema build --target js --release main`

Commit scope:

- `docs(rabbita-player)` or included with the final feature commit when the
  implementation and docs are landed together

### P16.6: GitHub Pages deployment

Status: ready for first publish.

Deploy the finished demo to GitHub Pages from GitHub Actions. Use
`rabbita_xterm/.github/workflows/pages.yml` as the local reference pattern:
install MoonBit, update the registry, check/build the library and demo, prepare
a static `site/` directory containing the demo sources and generated JS build
artifacts, then publish with the official Pages artifact/deploy actions.

Acceptance:

- `.github/workflows/pages.yml` is added for the repository
- the workflow runs on pushes to `main` and via `workflow_dispatch`
- permissions are limited to `contents: read`, `pages: write`, and
  `id-token: write`
- the workflow runs root validation before publishing at least `moon check`
- the workflow checks and builds `demo/rabbita_asciinema` for the JS target
- the published site contains:
  - `demo/rabbita_asciinema/`
  - the generated `_build/js/...` output required by that demo
  - `.nojekyll`
  - a root `index.html` redirect or link to the player
- `demo/rabbita_asciinema/README.md` documents the expected Pages URL shape and
  notes that the repository's Pages source must be configured to GitHub Actions
- successful deployment URL is recorded in this plan's audit notes after the
  first publish

Validation:

- `moon check`
- `moon -C demo/rabbita_asciinema check --target js`
- `moon -C demo/rabbita_asciinema build --target js --release main`
- local static-site smoke check against the generated `site/` directory before
  enabling or merging the workflow
- GitHub Actions Pages run passes on `main` or from `workflow_dispatch`

Commit scope:

- `ci(rabbita-player)`

## Acceptance criteria

- The demo plays asciicast v2/v3 recordings in a Rabbita app.
- The terminal viewport is produced by the translated Ghostty terminal parser
  and screen model, not xterm.js.
- Output, resize, marker, exit, title, bell, and terminal query side effects
  have visible or testable behavior.
- The demo can load a local `.cast` file in the browser.
- The player has parity with the core `rabbita_xterm` demo controls:
  play/pause, scrub, speed, theme, and file open.
- The implementation is isolated from the core parser package except for
  intentional, audited public API additions.
- The finished demo is deployed to GitHub Pages through a repository workflow.

## Coverage findings for touched files

- `moon -C demo/rabbita_asciinema test --target js` passed with 515 tests.
- `moon -C demo/rabbita_asciinema coverage analyze -- -f summary` was run
  after tests.
- Fully covered demo files are omitted by the summary output. The asciicast
  parser and JS `LoadedFile` conversion are covered.
- `demo/rabbita_asciinema/main/ghostty_terminal.mbt` has 250/253 lines
  covered. Remaining lines are defensive fallbacks:
  - `plain_viewport` handling a missing in-range screen cell
  - `grid_ref_graphemes` returning `None` for a cell that reports a grapheme
- `demo/rabbita_asciinema/main/main.mbt` has 211/228 lines covered. Remaining
  lines are:
  - `initial_cast` fallback for a broken embedded sample cast
  - async browser file-picker execution inside the Rabbita command
  - an unreachable `jump_to` `events.get` fallback after target clamping
  - the browser `main` mount path, which is exercised by build/static smoke
    checks rather than unit tests
- No `src/terminal` files were changed for P16.1-P16.4.

## Public API visibility findings

- `demo/rabbita_asciinema/main/pkg.generated.mbti` exposes no demo internals;
  the player package keeps parser, adapter, and model types private.
- `src/terminal/pkg.generated.mbti` is intentionally unchanged for
  P16.1-P16.4. Renderer needs were satisfied by existing public terminal APIs:
  `screen_cell_snapshot`, `grid_ref`, `grid_ref_graphemes`, `palette`,
  cursor/size accessors, and title/side-effect callbacks.
- No public mutable fields were added.

## Audit notes

- Feasibility is positive: the translated terminal package already type-checks
  for the JS target.
- The highest-risk implementation area is renderer correctness, not parser
  ingestion. The terminal can already consume bytes; the player must render the
  active viewport faithfully enough for terminal output inspection.
- The implemented renderer is cell-based over the active viewport and does not
  use formatter full-scrollback HTML or Rabbita `inner_html` for cast output.
- Demo validation currently has only existing root-package deprecation warnings
  in `src/terminal/key_event_test.mbt` and `src/terminal/osc.mbt`.
- GitHub Pages workflow is added in `.github/workflows/pages.yml`. It installs
  MoonBit, runs root and demo validation, builds the demo, copies
  `demo/rabbita_asciinema` plus `_build/js` into the Pages artifact, and
  publishes through `actions/deploy-pages`.
- Local Pages artifact smoke was run from a temporary `site/` directory on
  `http://127.0.0.1:18080/`; root redirect, demo HTML, and compiled
  `main.js` all returned HTTP 200.
- First GitHub Actions Pages publish succeeded on run
  `25277265241` for commit `e69d0a59f09d775ced7868d724524b3afcf5db37`.
- Published demo URL:
  `https://moonbit-community.github.io/tonyfettes-ghostty/demo/rabbita_asciinema/`.
