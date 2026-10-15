# Project Guide

## Scope and references

- This repository translates Ghostty's terminal parser and terminal model into
  MoonBit. Upstream source lives in `upstream/ghostty`.
- The repository also includes pure MoonBit font work and a headless renderer
  extension scope. Keep changes within the requested area; platform
  frontends, GPU backends, and native C ABI parity remain outside current scope.
- Read the documentation relevant to the task:
  - `docs/architecture.md`: upstream parser architecture and invariants.
  - `docs/terminal-package.md`: current MoonBit package navigation.

## Working style

- Work directly from the user's request and make reasonable implementation
  decisions. Do not create or maintain task plans, roadmaps, phase boards, or
  subplans unless the user explicitly asks for one.
- Routine refactors, helper functions, and MoonBit compatibility adaptations
  do not need a separate approval or deviation report. Explain significant
  tradeoffs; ask when the intended behavior or scope is genuinely unclear.
- Investigate and fix failures within the task. Report blockers and unresolved
  failures with enough detail to reproduce them.
- Use subagents and worktrees when they help. Keep concurrent write boundaries
  clear and review the combined result; no fixed explorer/worker/reviewer
  sequence or task subplan is required.
- Update technical and usage documentation when the change calls for it.

## Implementation principles

- Preserve upstream behavior, parser state transitions, action ordering,
  UTF-8 retry semantics, and the separation of parsing, terminal state, and
  host effects. Follow upstream structure where it remains useful in MoonBit.
- Prefer clear MoonBit code over mechanical copies of Zig allocation or C ABI
  plumbing. Record non-obvious compatibility choices where they help future
  maintenance.
- Keep implementation details private by default. Public APIs and mutable
  fields should serve callers; white-box tests can use `_wbtest.mbt` files.
- Keep changes focused. When committing, use Conventional Commits and group
  related code, tests, and documentation together; no commit per plan step is
  required.

## Validation

- For MoonBit changes, normally run `moon check --target wasm`,
  `moon test --target wasm`, and `moon fmt`. These match the current CI target.
- Run relevant additional backends or example checks when the change affects
  them. See `README.md` for commands.
- Run `moon info` when source changes may affect generated interfaces, and
  review the `.mbti` diff for intentional API changes.
- Add or update tests for changed behavior. Use coverage to investigate test
  gaps in substantial logic changes and benchmarks to assess performance work;
  neither needs a separate signoff or per-line audit for every edit.
- For documentation-only changes, check accuracy, links, and `git diff --check`.
  MoonBit tests are unnecessary unless code or executable examples also change.
- In the handoff, summarize the change, relevant checks, and any known limits.
