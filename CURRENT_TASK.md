# CURRENT TASK

- Task: TASK 019 — 전투 효과·사운드 적용
- GitHub Issue: #6 (정본, 본문) — https://github.com/BN8624/unknown/issues/6
  - ⚠ 이슈 제목은 "TASK 020 외형 승급"으로 잘못 붙음. **본문이 TASK 019 사운드**이며 그게 정본. (제목 정정은 사용자 확인 대기.)
- 상태: **진행 중.** 음원 합성·AudioHooks 재생 연결 단계.
- 정본: GitHub Issue #6 본문 / 음원 기준은 #6 댓글(id 4815309071)

> 음원 우선순위(이슈 댓글): ①직접 생성 wav/ogg ②Kenney CC0 ③OpenGameArt CC0 ④Freesound CC0. CC-BY·불명·추출 금지. 출처는 `AUDIO_CREDITS.md`에 기록.

---

## 목표 (Issue #6 본문)

전투 이벤트 11종이 눈·귀로 구분되게 한다(화려함 아님, 최소 식별).
기본공격·피격·강타·연격·반격·레벨업·엘리트등장·보스등장·보스강공격준비·보스승리·버튼.

**불변**: 전투 수치, 적 등장 순서, 저장 형식, UI 배치, 캐릭터 아트.

## 결정

- 음원 11종 전부 **직접 합성 CC0**(우선순위 1순위). 합성 스크립트 `scripts/audio/gen_sfx.py`, 출력 `assets/sfx/*.wav`.
- 기존 `AudioHooks`(이벤트 19종 카운트, 음원 없음)는 **카운트 동작 유지**(--verify 의존). 그 뒤에 실제 재생 연결 — 헤드리스/verify에선 플레이어 미등록이라 카운트만, 라이브/웹에서만 실제 소리.
- 19개 이벤트 → 11개 SFX 매핑(예: merc_basic_attack·enemy_basic_attack→attack_basic).

## 체크리스트

- [x] `scripts/audio/gen_sfx.py`로 11종 wav 생성 → `assets/sfx/`(총 ~340KB)
- [x] `AUDIO_CREDITS.md` 작성(11종 전부 자체 합성 CC0)
- [x] `AudioHooks.gd`에 SFX_MAP(19→11) + 재생 sink 등록 경로 추가(카운트 동작 보존)
- [x] `Battle.gd`에서 AudioStreamPlayer 풀 8개 생성·등록(verify 제외), `play_sfx` 진입점
- [x] 이벤트별 시각 효과는 기존 활용(플래시·피해숫자·러지·레벨업 확대·보스 강조·자세붕괴 흔들림) — 신규 추가 없음(최소 변경)
- [x] `--verify` ALL PASS TASK_001~014, SCRIPT ERROR 0
- [x] `--shot` 9장 캡처(오디오 로드가 캡처 안 깸 확인)
- [x] Web 빌드 재내보내기(음원 포함)
- [ ] 아이폰 첫 터치 후 재생 확인(사용자)
- [ ] Issue #6 보고

## 다음 TASK
020 외형 승급(브루노 처치 후 철검+가죽).
