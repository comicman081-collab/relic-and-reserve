# R3 인간 MVP 게이트 실행표

이 문서는 실제 인간 플레이테스트를 위한 QA 운영표다. 게임 로직, UI,
save schema, RNG, production telemetry를 추가하거나 변경하지 않는다.

## 세션 준비

- 서로 다른 3~5명의 새 플레이어를 준비한다.
- 각 플레이어는 fresh profile에서 시작한다.
- 내부 정답, hidden value, bidder threshold, RNG, 튜닝 수치는 알려주지 않는다.
- 플레이어에게는 게임 안의 Stage 1 안내만 설명한다.
- 세션 파일은 `session_template.jsonl`을 복사해 만들고, `fixture`는 반드시
  `false`로 둔다.

## 진행 경로

`NEW GAME → Stage 1 → Stage 2 → … → Stage 10 → Grand Reserve → Ending → Postgame`

진행을 막는 현상, 다음 행동을 찾지 못하는 중단, reload/restart 뒤 결과
변경, 중복 보상이나 판매가 보이면 즉시 운영 메모에 남긴다. 내부 필드는
JSONL에 기록하지 않는다.

## 네 checkpoint에서 동일하게 묻기

Stage 1, 5, 8, 10의 대표 경매가 끝난 직후 다음 네 질문을 그대로 묻는다.

1. 왜 이 경매 결과가 나왔다고 생각하나요?
2. 가장 영향을 준 선택은 무엇이었나요?
3. 다시 한다면 무엇을 바꾸겠나요?
4. 이전 Stage보다 어려웠다면 무엇이 더 어려웠나요?

운영자는 답을 `player_primary_category`, `player_next_action`,
`player_difficulty_category`의 public category로만 옮긴다. 실제 선택은
`investigation_action_count`, `risk_actions`, `repair_tool`,
`listing_preset`, `disclosure`, `stage_retry`, `retry_changed_choice`로만
기록한다.

## 캐릭터 판독

이름을 가린다고 가정하고 Auction, Shop, Event, Dossier의 실제 표시 크기에서
인물·역할·표정·NEUTRAL/POSITIVE/NEGATIVE 반응을 읽을 수 있는지 확인한다.
같은 인물을 여러 플레이어가 반복해서 오인하면 `portrait_repeated_misread`
를 `true`로 기록한다.

## 통과 기준

- 3~5명 모두 Stage 1→10→Grand Reserve→Ending→Postgame 완주.
- 진행 중단/softlock 0.
- Stage 1/5/8/10의 원인·다음 행동 category 일치율 각각 70% 이상.
- Stage 8/10에서 과반이 돈 외의 조사·수리·공개·예약가 판단 압력을 설명.
- 과반이 재도전 때 바꿀 public causal input을 하나 이상 제시.
- 반복 오인되는 캐릭터 0명.

## 검증

```powershell
python tools/audit/human_session_harness.py `
  --input qa/human_sessions/<session>.jsonl `
  --output qa/human_sessions/<session>.report.json
```

`FIXTURE_PASS_NOT_HUMAN_EVIDENCE`는 fixture 검증 결과일 뿐 인간 게이트
통과가 아니다. 실제 세션은 `fixture: false`이고 `humanObserved: true`가
되는 기록이어야 한다.

