# Project Agents.md Guide

## Project goal

- The current goal of this repository is a faithful MoonBit translation of the
  upstream Ghostty terminal parser stack under `upstream/ghostty`.

- Unless the user explicitly changes scope, keep the work focused on the parser
  stack. Do not expand into unrelated Ghostty UI, renderer, or platform
  frontend code.

## Source of truth

- Read `docs/architecture.md` for the upstream parser architecture and module
  boundaries.

- Follow `docs/plan.md` as the ordered execution plan for the translation.

## Plan discipline

- Follow `docs/plan.md` in order unless the user explicitly reprioritizes the
  work.

- When a planned task is completed, update `docs/plan.md` in the same commit as
  the work for that task.

- Keep the translation faithful to upstream structure: preserve module
  boundaries, state machines, action ordering, and data contracts whenever
  MoonBit can express them directly.

- Prefer line-by-line translation over stylistic rewrites. Refactor only when
  needed to express the same semantics safely in MoonBit.

## Git workflow

- Use Conventional Commits.

- Keep commits clean and atomic. Each commit should represent one logical step
  and should not mix unrelated edits.

- When work is split into multiple steps, make one commit per completed step
  before moving to the next step.

## Validation

- For MoonBit source changes, run `moon info && moon fmt` before handoff.
