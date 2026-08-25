# R3 human-session harness (audit-only)

한국어 실제 세션 운영 절차는 [`HUMAN_PLAYTEST_RUNBOOK_KO.md`](HUMAN_PLAYTEST_RUNBOOK_KO.md)를 먼저 따른다.

This folder is the only destination for human playtest observations. The
harness does not run Godot, load a save, consume RNG, or write to production
source/data.

## Record a session

1. Copy `session_template.jsonl` to a new file.
2. Use one `session_meta` line and one `checkpoint` line for each of Stages
   1, 5, 8, and 10. Keep `checkpoint_role` as `causal_representative`.
3. Record only what the player saw, chose, or said. Use the categorical fields
   for the four post-auction questions; do not paste hidden implementation
   details into the JSONL.
4. Validate it with:

```powershell
python tools/audit/human_session_harness.py `
  --input qa/human_sessions/my_session.jsonl `
  --output qa/human_sessions/my_session.report.json
```

`FIXTURE_PASS_NOT_HUMAN_EVIDENCE` is only a schema/validator result. A real
session must use `fixture: false` and complete the fresh Stage 1 → 10 → Grand
Reserve → Ending → Postgame path.

## Public-safe fields

The checkpoint records capture: stage/case, investigation action count,
LOW/HIGH risk choices, repair tool, FAST/BALANCED/HIGH listing preset,
limited/verified/full disclosure, the frozen public terminal reason, SOLD or
NO_SALE, the three public score axes, retry and changed public choices, the
player's primary reason/action/difficulty categories, and native portrait
legibility.

Never add canonical truth, hidden value, undiscovered evidence, bidder private
threshold/weight, RNG/seed, hidden tuning, or internal state keys. Unknown
fields and forbidden internal key fragments fail closed.

## Human acceptance

- Exactly one representative checkpoint for each of Stages 1, 5, 8, and 10.
- Player primary-cause and next-action categories each match the frozen public
  result in at least 70% of those checkpoints.
- No repeated portrait misread at native Auction/Shop/Event/Dossier size.
- No progress block, softlock, or duplicate checkpoint on retry/restart.

The harness report always states `productionMutations`, `saveSchemaMutations`,
`gameStateMutations`, `rngConsumption`, and `uiMutations` as zero because it is
read-only by design.
