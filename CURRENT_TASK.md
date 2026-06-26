# CURRENT TASK

- Task: 없음 (TASK 017 완료, Issue #4 닫음)
- GitHub Issue: 다음 작업 TASK 018은 새 Issue로 시작 예정
- 상태: 대기 중 — TASK 017 아이폰 확인 완료("잘 됨"). 다음은 TASK 018(UI 재배치).
- 정본: 현재 열린 GitHub Issue (없으면 VERTICAL_SLICE.md + HANDOFF.md)

> 아래는 방금 완료한 TASK 017 요약(참고). 다음 작업 시작 시 이 파일을 새 Issue 내용으로 덮어쓴다.

---

## 적용 완료 (SD 전신, 동작 변화 0)

- 적 4종을 `Sprite2D`로 교체. `ENEMY_TEX`/`ENEMY_DISP_H` 매핑으로 `_build_enemy` 일반화, 보스는 `_spawn_boss`에 `BRUNO_TEX`.
- 표시 높이: 고블린 82 · 방패병 120 · 오우거 154 · 브루노 170 (크기 순서 고블린<늑대·방패병<용병<오우거<브루노). 발은 `CHAR_FOOT_Y 660` 공통.
- 특수 무기 도형(방패·몽둥이·철퇴)은 텍스처 있으면 **숨김**(텍스처에 포함), 누락 시 도형 폴백.
- 모든 적 왼쪽(용병) 바라봄. 전투 판정·수치·등장 순서·저장 변경 없음.

## 검증
- `--shot` 6장 캡처(기본·레벨업·고블린무리·방패병·오우거·브루노) — SD 표시·크기 순서·발 접촉·체력바·패널 비겹침 확인.
- 헤드리스 `--verify`: ALL PASS TASK_001~014(종료 0), SCRIPT ERROR 0. Web 빌드 정상(14.3MB).

## 신규 에셋
```
assets/characters/ goblin.png  shield.png  ogre.png  bruno.png  (모두 RGBA 투명, 1254×1254)
```

## 남은 것 (아이폰 확인 → TASK 018)
- 고블린 무리·방패병·오우거·브루노 SD 표시, 오우거 강공격 준비·브루노 방어 태세·자세 붕괴 구분, 무기 끝·UI 충돌 여부.
- 다음: UI 재배치 018, 사운드 019, 외형 승급 020.

## 아이폰
`https://node.tail3e9e21.ts.net:8443/?v=17`
