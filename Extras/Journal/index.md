# Development journal

## 2026-11-26

- [Full Review of Application](2026-11-26-full-review-application.md) reviews the lifecycle and monitoring APIs and records the reproduced ownership defects.
- [Proposed Maintenance Lifecycle](2026-11-26-maintenance-lifecycle.md) records the lifecycle investigation, the per-run runtime API, and the standalone counter demo.
- [Full Review Fixes and Stack Adoption](2026-11-26-review-fixes.md) fixes the review's findings, including an Observation re-entry crash, and lists the library gaps that stop Stack adopting the lifecycle.
- [Stack Adoption Support](2026-11-26-stack-adoption-support.md) closes those gaps with an async runtime accessor, watchOS support and a preparing-phase view, and removes the package's user-facing text.

## 2026-10-27

- [Planned: alternative startup and in-process restart](2026-10-27-startup-modes-and-restart.md):
  what Bookish's repair startup needs from `AppEngine`, and the questions an
  investigation should settle first.

## 2026-10-15

- [PR #1 review](2026-10-15-pr-1-review.md): original correctness, standards, and
  design review before fixes, including reproduced startup and observation defects.
- [PR #1 fixes and cleanup](2026-10-15-pr-1-fixes.md): ownership fixes,
  deterministic tests, compatible API cleanup, and validation results.
