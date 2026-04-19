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
  - `moon coverage analyze`
  - `moon fmt`
  - `moon info`

- Treat coverage as a completion gate, not a nice-to-have. After
  `moon coverage analyze`, review uncovered lines in the files touched by the
  task.

- Do not close a MoonBit implementation task while touched executable lines are
  left uncovered without an explicit note in the task subplan or audit trail
  explaining why the uncovered lines are acceptable for now.

- The main agent is responsible for enforcing this coverage gate on both local
  work and delegated work. Worker validation is not complete until coverage
  findings for the touched files have been reviewed.

- Review any `.mbti` or formatting churn and confirm it is intentional before
  handoff or commit.

## Public API audit

- Treat public API shape as a quality gate, not a cleanup task for later.

- During review of MoonBit source changes, inspect the `.mbti` diff and ask
  whether each public item has an external consumer story.

- Public mutable fields are banned unless caller mutation is an intentional and
  documented part of the API contract.

- Parser state machines, transition tables, accumulators, parse buffers,
  embedded helper parsers, and other implementation-detail structs or enums are
  internal by default. Do not expose them publicly just because tests or the
  current translation scaffolding can see them.

- White-box tests are not justification for public visibility. Prefer keeping
  internals package-private and testing them from `_wbtest.mbt` files.

- If a task must temporarily expose internals to unblock translation, record
  that exposure as temporary debt in the task subplan and add a follow-up task
  to remove it.

- Reviewer prompts for delegated review should explicitly ask for public API
  quality findings, including pre-existing unjustified public surface in the
  touched area.
