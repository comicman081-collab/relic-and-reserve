# RELIC & RESERVE R3 — Human MVP Playtest Matrix

자동화된 기술 PASS와 실제 완성 판정을 분리하기 위한 기록지다. 이 문서는 audit-only이며 production source/data, save, export artifact를 변경하지 않는다.

## 세션 기록 규칙

- 처음 플레이하는 사람 3~5명을 권장한다. 진행 전에 시스템 설명을 하지 말고 Stage 1 tutorial만 사용하게 한다.
- 관찰자는 hidden truth, bidder private threshold, RNG를 알려주지 않는다. 기록에는 화면에 보인 public state와 플레이어의 말만 남긴다.
- 각 세션은 `qa/R3_HUMAN_PLAYTEST_SESSION_TEMPLATE.md`를 복사해 별도 기록한다. `미기록`은 PASS가 아니다.

## 실행 범위

- fresh profile에서 실제 UI 입력만 사용해 Stage 1 → 10 → Grand Reserve 3 lot → Ending → Epilogue → Postgame까지 진행
- 종료 후 재실행/Continue와 NEW GAME → Stage Select에서 Stage 1~10 해금 유지 확인
- Godot는 headless 캡처/검증만 사용하고 Windows `.exe/.pck`, `.zip/.7z/.rar`는 만들지 않음
- 자동 기준선: `qa/R3_FRESH_PROFILE_E2E.json` 15/15, 순차 회귀·무결성 감사 통과

## P0: 진행 가능성 관찰

각 행에서 `막힘`이 한 번이라도 나오면 Freeze하지 않고 재현 화면·현재 CTA·authoritative state를 함께 기록한다.

| 구간 | 다음 행동을 스스로 찾았나 | CTA/상태 불일치 | softlock | 메모 |
|---|---|---|---|---|
| NEW GAME → Stage 1 tutorial | 미기록 | 미기록 | 미기록 | |
| 조사 → 증거 → 보고서 | 미기록 | 미기록 | 미기록 | |
| 수리 → listing → auction | 미기록 | 미기록 | 미기록 | |
| SOLD / NO_SALE 각각 | 미기록 | 미기록 | 미기록 | |
| upgrade / event / shop | 미기록 | 미기록 | 미기록 | |
| Stage Clear → 다음 Stage | 미기록 | 미기록 | 미기록 | |
| Stage 8~10 신규 유물 | 미기록 | 미기록 | 미기록 | |
| Grand Reserve LOT1→3 | 미기록 | 미기록 | 미기록 | |
| Stage10 Clear → Ending → Postgame | 미기록 | 미기록 | 미기록 | |
| Continue / NEW GAME / Stage Select | 미기록 | 미기록 | 미기록 | |

## P0: 경매 causal comprehension

Stage 1, 5, 8, 10에서 대표 경매 직후 아래 네 질문을 하고 frozen public `reasonTags`와 대조한다. 대표 경매 70% 이상에서 primary reason category와 바꿀 행동이 모두 맞으면 통과로 기록한다.

| Stage | SOLD/NO_SALE | frozen primary reason | 플레이어 답: 왜 참여/탈락? | 플레이어 답: 핵심 결과 원인 | 플레이어 답: 다음에 바꿀 행동 | 플레이어 답: 이전보다 어려운 이유 | category/행동 일치 |
|---:|---|---|---|---|---|---|
| 1 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 |
| 5 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 |
| 8 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 |
| 10 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 |

판정 원칙: 실제 태그와 답이 어긋나면 bidder 수치나 RNG를 먼저 바꾸지 말고 listing summary·최대 1~2개 reason chip·terminal 원인 어휘를 먼저 검토한다.

### 관찰자가 보존할 public checkpoint

각 checkpoint에서 아래만 저장한다: Stage/case/artifact, 조사 action 수와 LOW/HIGH risk 선택 여부, repair tool과 repair 여부, FAST/BALANCED/HIGH, disclosure, terminal reason code/category, SOLD/NO_SALE, Stage 3축 점수, 재도전 여부, 같은 Stage 재도전에서 달라진 선택. hidden truth·bidder maximum·RNG는 기록하지 않는다.

이전 정적 vocabulary probe가 발견한 `RESERVE_TOO_HIGH` chip `예약가 높음`과 Stage sale 힌트의 표현 차이는 `예약가와 공개 주장을 조정해 보세요`로 통일했다. 이후 human comprehension에서 같은 의미가 연결되는지 확인한다.

## P1: 7% 체감·재도전

민감도 감사의 현재 신호는 deterministic 7,776 trials PASS, 정상 가용성 decision-change 2.55%, material adverse coverage 46.3%다. 이 수치만으로 즉시 튜닝하지 않는다.

| 비교 | 위험 조사 선택 | 도구 선택 다양성 | listing/disclosure 변화 | 돈 부족 외 압력 인식 | 피로/반복감 |
|---|---|---|---|---|---|
| Stage 1 → 5 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 |
| Stage 5 → 8 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 |
| Stage 8 → 10 | 미기록 | 미기록 | 미기록 | 미기록 | 미기록 |

다음 중 2개 이상이 실제 플레이에서 반복될 때만 P1 수치/콘텐츠 튜닝을 재개한다: Stage1과 Stage10 listing 판단이 거의 같음, 후반을 돈 부족으로만 인식, 위험 조사·공개·가격 선택이 고정됨, 재도전에서 바꿀 경매 전략이 없음.

## P1: Stage Clear 재도전 동기

| Stage | 결과 카드에서 Investigation/Preservation/Sale 3축을 읽었나 | 다음 시도에서 바꿀 행동을 말했나 | BEST/권장 목표를 혼동했나 | 메모 |
|---:|---|---|---|---|
| 1 | 미기록 | 미기록 | 미기록 | |
| 5 | 미기록 | 미기록 | 미기록 | |
| 8 | 미기록 | 미기록 | 미기록 | |
| 10 | 미기록 | 미기록 | 미기록 | |

## 현재 동결 항목

- `pow(1.07, stage - 1)` 난이도 계수
- bidder AI / auction coefficient / listing preset 숫자
- 3축 점수식·evidence weight·repair cash·relist friction
- 신규 Stage / Artifact / bidder / NPC
- Windows export/package 및 압축파일

Human 결과가 채워질 때까지 본 문서의 `미기록`을 PASS로 간주하지 않는다.
