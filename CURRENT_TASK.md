# CURRENT TASK

- Task: TASK 018 — 모바일 UI 재배치
- GitHub Issue: #5 (정본) — https://github.com/BN8624/unknown/issues/5
- 상태: **완료·커밋·푸시·Issue #5 닫음.** 다음 작업은 TASK 019(사운드).
- 정본: GitHub Issue #5(닫힘) / 화풍은 ART_STYLE_GUIDE.md
- ⚠ 다음 세션: TASK 019 새 Issue 작성 후 이 파일을 덮어쓸 것.

> GPT에게 Issue 줄 때 평문 URL은 CLAUDE.md 참조(본문/댓글/특정댓글/raw).

---

## 완료한 것 (미커밋, working tree에 있음)

상단 UI를 게임 화면처럼 정리. `Battle.gd`만 수정(전투·수치·저장·아트·등장순서 불변).
- 줄1 (y10): `status_label` "Lv N   골드 G" (fs26) + `trait_button`(우, 388,8 / 136×46)
- 줄2 (y46): EXP 바 풀폭(508×16)
- 줄3 (y70): `boss_progress_label` "빚 … 명성 … · 보스진행"(fs19)
- 줄4 (y96): `trait_status_label` 특성 포인트(fs18)
- **제거**: 용병HP·공격·방어·적HP 상단 텍스트 → HP 바·강화 버튼·적 이름표에 이미 표시(정보 손실 없음).
- 보스 UI(168~272)는 보스전만, 상단(0~120)과 비겹침 — 변경 안 함.
- 함수: `_build_status_label`·`_build_exp_bar`·`_build_boss_progress_label`·`_build_trait_ui`(위치), `_update_status`("Lv N 골드 G", exp_fill 504폭), `_update_boss_progress`(원래 형식 유지 — TASK_010 검증 통과 위해 골드 안 넣음).

## 검증 (완료분)
- `--verify` **ALL PASS TASK_001~014**(종료 0). (주의: `_verify_debt_fame`가 `boss_progress_label.text`를 고정 비교 → 그 형식 바꾸면 FAIL. 골드는 `status_label`에 넣어 회피함.)
- `--shot` 9장(기본·레벨업·고블린·방패병·오우거·브루노·방어태세·자세붕괴·강화불가) 확인. 07=상태 방어태세(청색), 08=자세붕괴(무방비), 09=골드0 강화버튼 비활성화. Web 빌드 종료 0, 서버 8443 200.

## 결과 (완료)
1. 상단 배치 + 겹침 수정 → 아이폰 확인 완료.
2. 보스 상태 shot 3장 추가(07 방어태세·08 자세붕괴·09 강화불가).
3. 별도 `[상세]` 패널은 최소변경 원칙상 미생성(강화 버튼이 공격/체력/방어 현재값 표시로 대체).
4. 커밋 `10d14ec`·`560f0d2` 푸시, Issue #5 결과 댓글·닫음.

## 다음 TASK
019 사운드 — `AudioHooks`(19개 이벤트 경계, 음원 없음) 뒤에 실제 음원 연결. 새 Issue 작성 후 이 파일 덮어쓰기.

## 아이폰
`https://node.tail3e9e21.ts.net:8443/?v=18`

## 이후 TASK
019 사운드(필수 9종, AudioHooks 뒤 실제 음원) → 020 외형 승급(브루노 처치 후 철검+가죽, boss_defeated 연동) → 021 슬라이스 전체 아이폰 검증.
