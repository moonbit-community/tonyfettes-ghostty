# M1: align promoted Eq/Debug methods with current core policy

## Goal and authorization

The user explicitly requested that `not_equal` and `to_repr` follow the core
library's policy. This is a public API annotation correction to M1 maintenance;
it introduces no runtime implementation, storage change, helper, or parser
behavior. Existing translated upstream owner symbols and derived trait
implementations remain unchanged.

## Source and exact declaration mapping

Policy source: installed `moonbitlang/core/hashset/extends.mbt`, lines 15-52,
and `hashset/pkg.generated.mbti` under the current MoonBit library. Core keeps
`Eq::equal` as a regular promoted method, while deprecated `Eq::not_equal` and
`Debug::to_repr` promotions remain callable but hidden from generated docs/API.

Apply that exact policy to existing promotions in `terminal/**` and `font/**`:

- 183 `Eq::{not_equal, equal}` declarations become a visible `Eq::{equal}`
  declaration and a separate `Eq::{not_equal}` declaration annotated with
  ``#deprecated("Use `!=` instead", skip_current_package=true)`` and
  `#doc(hidden)`.
- 184 `@debug.Debug::{to_repr}` declarations gain
  ``#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)`` and
  `#doc(hidden)`.
- Keep all derives, trait impls, `equal`, `hash` and `hash_combine` promotions.

## Targets, ownership and dependencies

Worker owns only affected `.mbt` and generated `.mbti` under `terminal/**` and
`font/**`, plus this subplan. Main owns the aggregate M1 plan/audit. Worktree:
`/tmp/ghostty-pr61-core-extensions`, baseline `6e9d05e7`. No dependency change.
Existing upstream terminal/font symbol mapping is retained from the M1 audit;
the newly requested compatibility policy follows core, not a new runtime
adapter. Deprecated compatibility calls must remain resolvable by consumers.

## Acceptance and validation

- `moon check --target all --deny-warn`
- `moon test --target all`
- `moon coverage analyze` with inherited annotation-only gaps documented
- `moon fmt`, `moon fmt --check`, `moon info`, `git diff --check`
- Generated API diff removes exactly 367 hidden method listings: 183
  `not_equal`, 184 `to_repr`; no other signature changes.
- A temporary downstream package checks old dot calls still compile with the
  exact deprecation messages and canonical `!=` / `Debug::to_repr` calls pass
  warning-free. No permanent redundant tests or new helpers.

## Results and API/coverage audit

- `moon check --target all --deny-warn` passes with zero compiler warnings.
- `moon test --target all`: 666/666 on wasm, wasm-gc and native; 688/688 on JS.
- `moon fmt`, `moon fmt --check`, `moon info`, `git diff --check` pass.
- Machine audit of every affected source file reverses only the requested
  split/attributes and reproduces the baseline bytes exactly. No executable
  line, derive, trait impl, state transition or method body changed.
- Machine audit of all generated interfaces confirms exactly 367 removals
  (183 `not_equal`, 184 `to_repr`) and zero additions or other removals. These
  entries are hidden rather than deleted; all `equal` and Hash signatures remain.
- Temporary downstream module `/tmp/ghostty-extension-policy-smoke` imports
  this local worktree. Legacy `RGB.not_equal` / `RGB.to_repr` compile on all
  targets with exactly ``Use `!=` instead`` and ``Use `Debug::to_repr` instead``
  warnings, no errors. Switching to `!=` and `@debug.Debug::to_repr` passes
  `moon check --target all --deny-warn` and a native run (prints `false`).
  This verifies source compatibility and canonical warning-free replacements
  without committing redundant runtime tests.
- `moon coverage analyze -- -f summary`: 13341/13944 points, unchanged from
  the preceding main-sync audit. No changed executable lines exist. Existing
  gaps in touched owner files remain accepted for this annotation-only task:
  they are the inherited parser, formatting, grid/pagelist, defensive-bound and
  font branch gaps documented in the M1/core and main-sync audits. The hidden
  extensions add no executable branches and no coverage suppression attribute.
- Existing native dependency `libtool` empty-archive diagnostic remains outside
  this annotation-only patch; no project compiler warning remains.

Main reviewer signoff: the exact annotation and generated-interface changes
were independently verified. The inherited coverage gaps are acceptable for
this change because no executable source or coverage instrumentation changed.
