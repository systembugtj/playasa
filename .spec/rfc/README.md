# RFC Index — Playasa

All design decisions and code changes in this project must be covered by an RFC.

## Rules

1. **Everything needs an RFC.** No implementation without a prior RFC.
2. **One RFC, one thing.** If two things can be independently shipped and rolled back, they get two RFCs.
3. **Umbrella RFCs are allowed.** A parent RFC coordinates child RFCs but ships no code itself.
4. **ROADMAP.md and TASK_TRACKING.md track only RFC state.** Every row must reference a named RFC.
5. **Completed RFCs are archived here with code + test proof.** No RFC moves to `completed/` without a `## 完成证明` section.

## Directory Layout

```
.spec/rfc/
├── README.md                     # This file
├── rfc-template.md               # Blank RFC template
├── rfc-XXXX-<slug>.md            # Active (Proposed / In Progress)
└── completed/
    └── rfc-XXXX-<slug>.md        # Terminal state (Completed / Rejected / Deprecated)
```

## Status Values

| Status | Meaning |
|---|---|
| 提案 (Proposed) | Written, not yet started |
| 执行中 (In Progress) | Implementation underway |
| 已完成 (Completed) | Done, with code + test proof |
| 已拒绝 (Rejected) | Not proceeding; rationale recorded |
| 已废弃 (Deprecated) | Superseded; successor RFC named |

## Full Index

See **[ROADMAP.md](../../ROADMAP.md)** for the master RFC index table and umbrella/child relationships.
See **[TASK_TRACKING.md](../../TASK_TRACKING.md)** for per-RFC status and execution notes.

## Workflow Reference

The Claude Code skills `rfc-manage` and `rfc-workflow` encode the full procedure for creating RFCs, transitioning states, and archiving with proof. They activate automatically when working in this project.
