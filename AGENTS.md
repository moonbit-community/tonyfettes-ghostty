# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod.json` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Git workflow

- Use Conventional Commits for every commit. Prefer clear commit subjects such
  as `docs: add architecture overview` or `chore: add upstream ghostty
  submodule`.

- Keep commits clean and atomic. Each commit should represent one logical step
  in the work, and should not mix unrelated edits.

- When a task is split into multiple steps, make one commit per completed step
  before moving to the next step.

## Project goal

- The current goal of this repository is a faithful MoonBit translation of the
  upstream Ghostty terminal parser stack under `upstream/ghostty`.

- The authoritative setup documents are:
  - `docs/architecture.md` for the upstream parser architecture and boundaries.
  - `docs/plan.md` for the ordered execution plan.

- Unless the user explicitly changes scope, treat the parser stack as the
  target. Do not expand the work to unrelated Ghostty UI, renderer, or platform
  frontend code.

## Plan discipline

- Follow `docs/plan.md` in order. Do not skip ahead to later tasks unless an
  earlier task is fully complete or the user explicitly reprioritizes.

- When working on a task, update the plan file status in the same commit as the
  work that completed that task.

- Keep the translation faithful to upstream structure: preserve module
  boundaries, state machines, action ordering, and data contracts whenever
  MoonBit can express them directly.

- Prefer line-by-line translation over stylistic rewrites. Refactor only when
  needed to express the same semantics safely in MoonBit.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. Use snapshot tests to record current
  behavior. For solid, well-defined results (e.g. scientific computations),
  prefer assertion tests. You can use `moon coverage analyze > uncovered.log` to
  see which parts of your code are not covered by tests.
