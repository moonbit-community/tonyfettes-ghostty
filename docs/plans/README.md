# Delegated Task Plans

Use this directory for non-trivial delegated work.

Required filename pattern:

- `YYYY-MM-DD-<task-id>-<slug>.md`

Required contents:

1. Goal
2. Upstream files
3. MoonBit target files
4. Dependencies and invariants
5. Acceptance criteria
6. Validation commands
7. Coverage findings for touched files
8. Commit scope
9. Review findings
10. Audit/result notes

Coverage findings should record:

- whether `moon coverage analyze` was run
- which touched files still had uncovered lines, if any
- whether those lines were covered in the task or intentionally deferred with
  reviewer signoff

These files are meant to support both:

- pre-implementation checking before a worker starts editing
- post-implementation auditing before the task is merged
