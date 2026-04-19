# P2.C OSC Coverage Follow-up

## Goal

- Improve behavior coverage for the Phase 2 OSC core in `src/terminal/osc.mbt`.
- Target real parser-state and color-operation branches reported by
  `moon coverage analyze`.
- Keep the change scoped to tests unless a coverage-driven test exposes a real
  parser bug.

## Upstream Files

- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/osc/parsers/color.zig`

## MoonBit Target Files

- `src/terminal/osc.mbt`
- `src/terminal/osc_wbtest.mbt`
- `docs/plans/2026-04-19-p2-c-coverage-osc.md`

## Dependency Notes

- Phase ordering follows `docs/plan.md`; this is a follow-up within completed
  Phase 2 task `P2.C`.
- Keep module boundaries faithful to upstream: parser state handling stays in
  `osc.mbt`, while tests exercise it through `OscParser`.
- Prefer parser-level inputs that naturally drive the color helper branches
  instead of direct unit tests of private helpers, unless a branch is otherwise
  unreachable.

## Acceptance Criteria

- Add white-box parser tests covering real OSC behavior for:
  - parser reset/deinit and start-state termination
  - invalid-prefix transitions and invalid-state short-circuiting
  - OSC 5 special-color query/set behavior
  - OSC 10-19 query/set behavior, including truncation after the last dynamic
    color
  - OSC 104 reset behavior for palette and special targets with invalid entries
    skipped
  - OSC 110-119 reset behavior, including rejected non-empty bodies
- Leave `src/terminal/osc.mbt` unchanged unless a real bug is found.
- Record post-change coverage findings for owned files, including any remaining
  uncovered branches and why they remain uncovered.

## Validation Commands

- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Coverage Findings For Touched Files

### Baseline before edits

- `src/terminal/osc.mbt` reported 95 uncovered lines.
- The meaningful gaps cluster in:
  - `OscParser::deinit`
  - `OscParser::next` prefix transitions for OSC 5, 10-19, 104, 110-119, and
    invalid-prefix exits
  - `OscParser::end` dispatch arms for OSC 5, 10-19, 110-119
  - color helper branches for OSC 5, OSC 10-19, OSC 104, OSC 110-119, invalid
    numeric/color bodies, and special-color targets
- Likely unreachable or low-value synthetic branches from the baseline:
  - `OscParser::next` match arm `Invalid => ()`, because the function returns
    early when `self.state == Invalid`
  - `parse_color_command` fallback `None => return Invalid`, because parser
    states reaching `parse_color_command` are already restricted to color
    prefixes
  - `ansi_target_from_index` negative-value fallback, because parser-fed values
    come only from decimal parsing

### Post-change audit

- Measured after the added OSC coverage tests:
  - total uncovered lines across the repo dropped from `158` to `61`
  - `src/terminal/osc.mbt` dropped from `95` uncovered lines to `8`
- Covered behavior added in `src/terminal/osc.mbt`:
  - `OscParser::deinit` and start-state `end()` behavior
  - invalid-state short-circuiting after bad prefix transitions
  - valid and invalid prefix flows for OSC 5, OSC 10-19, OSC 104, and
    OSC 110-119
  - `end()` dispatch arms for those color operations
  - color parsing branches for:
    - OSC 5 special-color set/query
    - OSC 4 special target query and partial accumulation on invalid bodies
    - OSC 104 palette/special resets with invalid entries skipped
    - OSC 10-19 query/set parsing, empty-body rejection, invalid-color
      rejection, and truncation after the last dynamic color
    - OSC 110-119 empty-body resets and rejected non-empty bodies
- Remaining uncovered branches in `src/terminal/osc.mbt`:
  - `OscParser::next` arm `Invalid => ()` at line 182:
    unreachable in normal execution because the function returns early when
    `self.state == Invalid`
  - `Prefix1` invalid continuation fallback at line 202:
    still reachable; worth a small follow-up parser test such as bad `OSC 1x`
  - `Prefix11` invalid continuation fallback at line 247:
    still reachable; worth a small follow-up parser test such as bad `OSC 11x`
  - `parse_color_command` fallback `None => return Invalid` at line 469:
    unreachable through public parser states because only color-prefix states
    call this helper
  - `color_operation_from_state` fallback `_ => None` at line 504:
    same unreachable helper guard as above
  - `ansi_target_from_index` negative-value fallback at line 672:
    unreachable from parser-fed decimal input because parsed values are
    non-negative
  - `special_from_int` cases `0 => Bold` and `2 => Blink` at lines 680 and 682:
    reachable; worth a follow-up OSC 5/104 test if further branch cleanup is
    needed

## Commit Scope

- Test-only coverage improvement for the OSC parser core and its task audit
  record.

## Review Findings

- No parser bug was exposed by the new coverage-driven cases, so `src/terminal/osc.mbt`
  stayed unchanged.
- The added tests remain behavior-driven rather than helper-driven, except for
  using white-box access to keep assertions in the owned test file.

## Audit / Result Notes

- Files changed:
  - `src/terminal/osc_wbtest.mbt`
  - `docs/plans/2026-04-19-p2-c-coverage-osc.md`
- Validation completed successfully for this change set:
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon fmt`
  - `moon info`
- A later targeted rerun encountered a concurrent edit outside this write set
  in `src/terminal/point_wbtest.mbt`; I left this patch at the last fully
  measured and validated OSC coverage state instead of chasing that unrelated
  failure.
