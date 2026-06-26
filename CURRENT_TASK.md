# CURRENT TASK

- Task: 없음 (TASK 014 종료, Issue #2 닫음)
- GitHub Issue: 다음 작업 TASK 015는 새 Issue로 시작 예정
- 상태: 대기 중 — 아이폰 확인 완료("잘 되네"), 다음은 TASK 015(첫 컷아웃 아트 샘플)
- 정본: 현재 열린 GitHub Issue (없으면 VERTICAL_SLICE.md + HANDOFF.md)

---

## 범위 (동작 변화 0의 구조 정리)

1. 적 5종(늑대·고블린·방패병·오우거·브루노) 고정 프로필을 `scripts/data/EnemyProfiles.gd`로 분리.
2. 사운드 이벤트 경계 `scripts/audio/AudioHooks.gd` 추가(실제 음원·AudioStreamPlayer 없음).

전투·밸런스·UI·저장·등장 순서는 바꾸지 않는다.

## 완료 분

- `EnemyProfiles.gd`: 5종 고정값(이름·체력·공격력·방어력·간격·접근속도·골드/경험치·엘리트/보스 여부·크기·색상) + `get_profile()` 깊은 복사본 반환.
- `Battle.gd`: `ENEMY_PROFILES`는 읽기용 별칭, 보스 상수(`BOSS_*`)는 `bruno` 프로필을 단일 출처로 참조(값 동일). 생성 경로는 복사본 사용. 표시 크기·색상 하드코딩 제거.
- `AudioHooks.gd`: 19개 이벤트 호출 경계. 전투·성장·보스 흐름의 19개 지점에 1회씩 훅 삽입(매 프레임 반복 없음, 게임 상태 무변경).
- 검증: 헤드리스 `--verify` **ALL PASS TASK_001~014**(종료 0). 신규 `_verify_task014`로 프로필 복사본 격리·잘못된 id 안전 처리·사운드 1회 호출 검증. Web 빌드 정상.

## 남은 것

- 사용자가 아이폰에서 기존 저장 복원·전투가 이전과 동일하게 작동하는지 확인 → 확인되면 Issue #2 닫고 TASK 015(첫 컷아웃 아트 샘플) 착수.
