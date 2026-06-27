# HANDOFF

> 이 문서는 현재 상태와 다음 한 단계만 담는다. 과거 TASK 전체 내역은 반복하지 않는다(이력은 git, `docs/archive/`, `context-notes.md`에 있음).

## ⚡ RESET 001 (2026-06-27 이후 정본)

**프로젝트를 백지에서 새 게임으로 리셋함.** 정본 = `PRODUCT_RESET_SPEC.md`. 새 게임 **「균열기사」**(세로형 방치 RPG v0.1): `Main.tscn`/`Main.gd`(화면·전투·성장·스테이지·보스·보상·저장) + `reset/GameData.gd`(밸런스·콘텐츠) + `reset/SaveSystem.gd`(저장). 메인 씬을 `Main.tscn`으로 교체. 도형 아트(AI/PNG 없음). 골드·레벨·강화 5종·20스테이지·5층마다 보스·저장/불러오기·설정 초기화·Web 빌드 동작 확인. **오프라인 보상(최대 8h)·환생(균열석)·사운드·균열석 상점(영구 강화 4종)·큰수 표기(K/M/B)·전투력 표시·층별 배경 톤 추가.** 출시 후보 상태.
⚠ Web 페이지 `<title>`는 export 시 프로젝트명("unknown", user:// 경로라 변경 불가)로 리셋됨 → **export 후 `build/index.html` title을 "균열기사"로 패치**해야 함(현재 패치됨). 정식 출시 시 export 프리셋에 custom HTML shell 권장. 기존 `Battle.gd`·`assets/`·옛 TASK 문서는 **비활성 이력**(삭제 안 함, 현재 지시 아님). 아래 옛 TASK 내용은 리셋 이전 기록.

---

## 현재 목표

프로토타입 v0.1 승인 완료. 지금은 **버티컬 슬라이스** 단계 — 검증된 첫 지역 흐름을 그대로 두고 "실제 게임처럼 보이고 들리는 작은 완성품"으로 만든다. 정본 계획은 `VERTICAL_SLICE.md`.

**TASK 020(Issue #7) 외형 승급 — 코드 완료, 실제 아트 에셋 사용자 제공 대기.** 브루노 처치(`boss_defeated`) 시 용병 텍스처 `mercenary.png`→`mercenary_upgraded.png` 교체. 순수 함수 `_choose_merc_tex(defeated, upgraded_exists)`(검증 결정적) + `_merc_tex_path`, `_apply_merc_appearance(flash)`(Sprite2D 텍스처만 교체·재정렬)를 ①`_load_game` 후 ②브루노 승리(`_bruno_settlement`)에서 호출. 짧은 승급 연출(`_play_upgrade_flash`: 확대·반짝임·"장비가 좋아졌다"). 에셋 누락 시 기본 용병 폴백. 전용 검증 `_verify_task020` 추가 → `--verify` **ALL PASS TASK_001~014(+020)**. 임시 플레이스홀더로 스왑 스모크 확인 후 삭제(현재 기본 폴백). 새 저장 키 없음·전투 수치 불변. ⚠ **다음: 사용자가 `assets/characters/mercenary_upgraded.png`(RGBA SD 전신) 제공 → import·`--shot`·Web 빌드·아이폰 확인 → Issue #7 보고.**
(이전)**TASK 019(Issue #6) 사운드 — 완료·커밋·푸시·Issue 닫음.** 효과음 11종 자체 합성(CC0, `scripts/audio/gen_sfx.py` → `assets/sfx/*.wav`). `AudioHooks`에 SFX_MAP(19이벤트→11SFX) + sink 등록 경로 추가(카운트 동작 보존 → --verify 영향 없음). `Battle.gd`가 AudioStreamPlayer 풀 8개로 실제 재생(`_setup_audio`/`play_sfx`, verify 모드 제외). `AUDIO_CREDITS.md` 출처 기록. 시각 효과는 기존 활용(신규 0). `--verify` ALL PASS, `--shot` 9장, Web 빌드 완료. **다음: 아이폰 첫 터치 후 재생 확인 → Issue #6 보고.**
(이전)**TASK 018(Issue #5) UI 재배치 — 완료·커밋·푸시·Issue 닫음.** 상단 재배치(줄1 레벨·골드+특성버튼 / 줄2 EXP바 / 줄3 빚·명성·보스진행, 용병HP·공격·방어·적HP 텍스트는 HP바·강화버튼·이름표에 있어 제거). 특성 버튼이 EXP 바를 침범하던 겹침 수정(버튼 (388,6)·크기 (136,34)·폰트 20). 보스 상태 shot 3장 추가(07 방어태세·08 자세붕괴·09 강화불가). `--verify` ALL PASS TASK_001~014, `--shot` 9장 정상, Web 빌드 재내보내기 후 **아이폰에서 겹침 해결 확인 완료.** 커밋 `10d14ec`·`560f0d2`.
⚠ **다음 세션 먼저 할 일**: TASK 019(사운드) 새 Issue 작성·`CURRENT_TASK.md` 덮어쓰기부터.
(이전: TASK 015~017 용병·늑대·배경·적4종 SD 적용·아이폰 확인 완료. TASK 016은 015에 통합.)

확정 방향: **SD 전신 스프라이트**(AI 생성 투명 RGBA PNG 1장 — 2D 컷아웃 파츠 방식은 Issue #3에서 폐기) / 첫 지역 = 황량한 변경 교역로 / 외형 성장 포함(브루노 처치 후 철검+가죽) / 오프라인 보상 제외(슬라이스 후 별도 Issue) / 대규모 리팩터링 금지.

## 작업 방식 (TASK 013부터)

- 작업지시서 **정본은 GitHub Issue**(Issue 하나=주제 하나). 본문=지시, 댓글=결과·판단·수정. 완료 시 Issue 닫기.
- 로컬은 `CURRENT_TASK.md` **하나만** 두고 새 작업마다 덮어쓴다. 맨 위에 Issue 번호·상태·정본 표시.
- Issue 충돌 시 GitHub Issue 우선. 완료된 `docs/archive/prototype-v0.1/tasks/`의 TASK 001~012는 현재 지시 아님.
- GPT가 Issue HTML을 못 읽으면 평문 JSON/raw URL을 준다(상세는 CLAUDE.md): 본문 `.../issues/<N>`, 댓글 전체 `.../issues/<N>/comments`, **특정 댓글 `https://api.github.com/repos/BN8624/unknown/issues/comments/<CID>`**, raw 파일 `https://raw.githubusercontent.com/BN8624/unknown/main/<경로>`. GPT가 "댓글 N개뿐"이라면 이슈 번호부터 확인.
- 규칙 정본은 `CLAUDE.md` "작업 흐름". 문서 역할: `UNKNOWN.md`=기획 정본 / `HANDOFF.md`=현재 상태 / `CURRENT_TASK.md`=실행할 작업 하나 / `VERTICAL_SLICE.md`=슬라이스 단계 정본 / `checklist.md`=큰 단계만 / `context-notes.md`=결정 이유·버그 원인.

## 지금까지 완료 (요약)

- 프로토타입 v0.1: 자동 전투 → 골드·경험치 성장 → 공·체·방 강화 → 레벨 10 특성(강타·연격·반격) → 일반 적 3종 → 오우거 엘리트 → 철퇴의 브루노 보스(방어 태세·자세 붕괴·45초) → 패배·재도전 → 빚 상환·명성 상승 → 저장·복원. **아이폰 전체 흐름 검증·승인 완료.**
- TASK 013: 버티컬 슬라이스 범위 확정(`VERTICAL_SLICE.md`), Issue #1 닫음.
- 세부 구현·수치·결정 이유는 `context-notes.md`와 `docs/archive/prototype-v0.1/tasks/`(TASK 001~012), git 히스토리에 있음.

## 다음 액션

> **TASK 020 외형 승급 — 코드 완료, 에셋 대기(Issue #7).**
> 1) 사용자가 `assets/characters/mercenary_upgraded.png`(RGBA 투명 SD 전신, 용병과 같은 키 계열·오른쪽 바라봄, 철검+가죽) 제공.
> 2) 도착 후: `--headless --import` → `--shot`(10_upgraded 등) 확인 → Web 빌드 → 아이폰 확인 → Issue #7 보고·닫기.
> 주의: 표시 높이 `MERC_DISP_H=144` 고정. 새 에셋이 크거나 작게 보이면 에셋 여백/정렬 2~5px만 조정(`_apply_merc_appearance`는 기존 정렬식 동일). 음원 교체는 `AudioHooks.SFX_MAP`.
> 이후: 슬라이스 전체 아이폰 검증 021.

## 렌더 스크린샷 (TASK 015~)

```
"C:\Users\USER\godot-engine\Godot_v4.7-stable_win64_console.exe" --path "C:\Users\USER\unknown" -- --shot
```
GUI에서 9장(기본·레벨업·고블린무리·방패병·오우거·브루노·방어태세·자세붕괴·강화불가)을 `scratchpad/shot_0*.png`로 저장 후 자동 종료(`_shot_force`가 각 적을 화면 안 고정 위치에 강제 스폰, 보스 상태는 `_boss_start_stance`·`_boss_stagger` 강제 호출, 강화불가는 골드 0). 저장 경로는 `SHOT_DIR` 상수(환경 특정 — 다른 머신은 수정 필요). 캐릭터 구조: `Sprite2D`는 Node2D 래퍼의 자식, 표시 크기는 `get_used_rect`로 실제 그림 기준 정렬. 적 텍스처·높이는 `ENEMY_TEX`/`ENEMY_DISP_H` 매핑(보스는 `BRUNO_*`).

## 코드 현황 (TASK 014~ 참고)

- 대부분 `Battle.gd`(전투·UI·보스·저장·검증). TASK_014에서 데이터·사운드 경계만 분리: `scripts/data/EnemyProfiles.gd`(적 5종 고정 프로필 + `get_profile()` 복사본), `scripts/audio/AudioHooks.gd`(19개 사운드 이벤트 호출 경계, 실제 음원 없음). 둘 다 `Battle.gd` 상단에서 `preload`. 씬 `Battle.tscn`은 스크립트만 단 빈 `Node2D`. 모든 표시물은 `ColorRect`/`Label`을 코드로 생성.
- 보스 스탯은 `EnemyProfiles.PROFILES["bruno"]`가 단일 출처(`BOSS_*` const가 거기서 파생). `ENEMY_PROFILES`는 읽기용 별칭, 전투 생성만 `get_profile()` 복사본 사용.
- 입력 원칙(UI/표시 건드릴 때 주의): 비상호작용 표시물은 `MOUSE_FILTER_IGNORE`, 버튼·특성 패널만 STOP. Godot Control 입력은 z_index가 아니라 트리 순서를 따르므로 전투 중 생성되는 표시물이 버튼을 가리지 않게 IGNORE 유지(`_ignore_mouse`/`_ignore_enemy_mouse`/`_ignore_decorative_mouse`).
- 저장: `user://save_v1.json`(검증은 `user://save_test_v1.json`만). 헤드리스 `--verify`는 실제 저장 비접근.

## 실행 방법

방법 A — 에디터로 실행(화면 확인).
```
"C:\Users\USER\godot-engine\Godot_v4.7-stable_win64.exe" --path "C:\Users\USER\unknown" Battle.tscn
```
보스까지: 늑대3→고블린3→방패병→오우거 처치 후 브루노 등장. 신규 게임은 특성 포인트 0, 레벨 10에 첫 1포인트.

방법 B — 자동 검증(로그만).
```
"C:\Users\USER\godot-engine\Godot_v4.7-stable_win64_console.exe" --headless --path "C:\Users\USER\unknown" -- --verify
```

방법 C — 아이폰(웹). Tailscale 켠 Safari로 `https://node.tail3e9e21.ts.net:8443` (캐시 회피 `/?v=숫자`). 같은 망 아이폰 `iphone182`. 노출: `tailscale serve :8443 → 127.0.0.1:8060`, 8060은 `python -m http.server 8060 --bind 127.0.0.1 --directory build/`가 `build/` 제공.

코드 변경 후 아이폰 반영:
```
"C:\Users\USER\godot-engine\Godot_v4.7-stable_win64_console.exe" --headless --path "C:\Users\USER\unknown" --export-release "Web" "C:\Users\USER\unknown\build\index.html"
```
(서버는 디스크에서 바로 제공 — 이미 떠 있으면 재시작 불필요.)

## 검증 상태

- 헤드리스 `--verify`: **TASK_001~014 ALL PASS**, 종료 0. 무작위 비의존(연격만 force 경로, 나머지 결정적). 검증 저장이 실제 저장 비접근·테스트 파일 미잔존. (TASK_014 검증이 잘못된 id/이벤트 안전장치를 일부러 호출해 의도된 `push_warning` 2건 — 라이브엔 없음.)
- 아이폰 플레이: **TASK_001~012(v0.1) + TASK_014 확인됨**. TASK_014는 분리 후 기존 저장 복원·전투 동일 작동 확인("잘 되네").
- 항목별 검증 상세는 git 히스토리/`context-notes.md` 참고.

## 남은 위험

- iOS Safari IndexedDB 지속성(용량·기간 제한, 캐시 정리, 비공개 모드 영구 저장 불가) — 드물게 저장이 사라질 수 있음. 장기 플레이 시 재확인.
- 보스 난이도·45초 제한이 장기 플레이에서 적당한지는 슬라이스 검증 때 재확인.
- 상용 폰트 `malgun.ttf`는 비공개(gitignore)·빌드 pck에만 포함. 배포 시 라이선스 확인 필요.
