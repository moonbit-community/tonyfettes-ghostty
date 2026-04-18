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

- Do not structure tasks so they require a red intermediate commit. Every
  implementation task should be able to finish in a green state with its tests
  and validation in the same commit batch.

- Keep the translation faithful to upstream structure: preserve module
  boundaries, state machines, action ordering, and data contracts whenever
  MoonBit can express them directly.

- Prefer line-by-line translation over stylistic rewrites. Refactor only when
  needed to express the same semantics safely in MoonBit.

## Delegation First

- Before deep reading or editing, decide whether the task should be split into
  explorer and worker subagents.

- Default to delegation for non-trivial planning, file mapping, translation,
  and test-porting work when subagents are available and authorized.

- Treat the main agent as planner, boundary owner, reviewer, and integrator.
  Do not pull large implementation tasks back into the main context unless
  delegation is blocked or the user wants the work kept local.

- If a task crosses parser layers, first use an explorer subagent to produce
  the dependency map and must-preserve invariants before any worker starts
  porting.

## Delegation rules

- Use a separate worktree per worker when available.

- In every worker prompt, include the exact upstream file set, the MoonBit
  target module(s), the write ownership boundary, acceptance criteria, and the
  validation commands.

- Prefer explorers for mapping upstream behavior, hidden dependencies, and test
  surfaces. Prefer workers for isolated code or doc changes in distinct write
  sets.

- For non-trivial delegated work, require a task-specific subplan under
  `docs/plans/` that records goal, upstream files, MoonBit targets,
  dependencies, acceptance criteria, validation commands, and audit notes.

- After a worker finishes, review the boundary and acceptance criteria yourself
  or spawn a dedicated review task. If you find bugs or missed requirements,
  resume the worker and keep the task open.

- Do not redo the entire implementation in the main context unless the boundary
  review fails so badly that resuming the worker is no longer efficient.

## Git workflow

- Use Conventional Commits.

- Keep commits clean and atomic. Each commit should represent one logical step
  and should not mix unrelated edits.

- When work is split into multiple steps, make one commit per completed step
  before moving to the next step.

## Validation

- For MoonBit source changes, the expected quality gate is:
  - `moon check`
  - `moon test`
  - `moon fmt`
  - `moon info`

- Review any `.mbti` or formatting churn and confirm it is intentional before
  handoff or commit.
