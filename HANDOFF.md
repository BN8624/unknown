# HANDOFF

> 이 문서는 현재 상태와 다음 한 단계만 담는다. 과거 TASK 전체 내역은 반복하지 않는다(이력은 git, `docs/archive/`, `context-notes.md`에 있음).

## 현재 목표

프로토타입 v0.1 승인 완료. 지금은 **버티컬 슬라이스** 단계 — 검증된 첫 지역 흐름을 그대로 두고 "실제 게임처럼 보이고 들리는 작은 완성품"으로 만든다. 정본 계획은 `VERTICAL_SLICE.md`.

**TASK 014(Issue #2) 완료·종료.** 적 5종 프로필을 `scripts/data/EnemyProfiles.gd`로, 사운드 경계를 `scripts/audio/AudioHooks.gd`로 분리(동작 변화 0, 실제 음원 없음). 헤드리스 ALL PASS TASK_001~014, 아이폰 확인 완료("잘 되네"). 다음은 **TASK 015 — 첫 컷아웃 아트 샘플(용병·늑대·변경 교역로 배경)**, 새 Issue로 시작.

확정 방향(Issue #1 승인): 2D 컷아웃(AI 생성 투명 분리 파츠) / 첫 지역 = 황량한 변경 교역로 / 외형 성장 포함(브루노 처치 후 철검+가죽) / 오프라인 보상 제외(슬라이스 후 별도 Issue) / 코드는 데이터 분리+사운드 훅만(대규모 리팩터링 금지).

## 작업 방식 (TASK 013부터)

- 작업지시서 **정본은 GitHub Issue**(Issue 하나=주제 하나). 본문=지시, 댓글=결과·판단·수정. 완료 시 Issue 닫기.
- 로컬은 `CURRENT_TASK.md` **하나만** 두고 새 작업마다 덮어쓴다. 맨 위에 Issue 번호·상태·정본 표시.
- Issue 충돌 시 GitHub Issue 우선. 완료된 `docs/archive/prototype-v0.1/tasks/`의 TASK 001~012는 현재 지시 아님.
- GPT가 Issue HTML 댓글을 못 읽으면 평문 JSON API URL을 준다: `https://api.github.com/repos/BN8624/unknown/issues/<번호>/comments` (본문은 `.../issues/<번호>`).
- 규칙 정본은 `CLAUDE.md` "작업 흐름". 문서 역할: `UNKNOWN.md`=기획 정본 / `HANDOFF.md`=현재 상태 / `CURRENT_TASK.md`=실행할 작업 하나 / `VERTICAL_SLICE.md`=슬라이스 단계 정본 / `checklist.md`=큰 단계만 / `context-notes.md`=결정 이유·버그 원인.

## 지금까지 완료 (요약)

- 프로토타입 v0.1: 자동 전투 → 골드·경험치 성장 → 공·체·방 강화 → 레벨 10 특성(강타·연격·반격) → 일반 적 3종 → 오우거 엘리트 → 철퇴의 브루노 보스(방어 태세·자세 붕괴·45초) → 패배·재도전 → 빚 상환·명성 상승 → 저장·복원. **아이폰 전체 흐름 검증·승인 완료.**
- TASK 013: 버티컬 슬라이스 범위 확정(`VERTICAL_SLICE.md`), Issue #1 닫음.
- 세부 구현·수치·결정 이유는 `context-notes.md`와 `docs/archive/prototype-v0.1/tasks/`(TASK 001~012), git 히스토리에 있음.

## 다음 액션

> **TASK 015 — 용병·늑대·변경 교역로 배경의 첫 컷아웃 아트 샘플**을 새 GitHub Issue로 시작.
> 컷아웃 리깅용 투명 배경 분리 파츠로 용병·늑대·변경 교역로 배경 먼저 제작 → 아이폰 승인 → 나머지 적으로 확장(승인 흐름은 VERTICAL_SLICE.md). 외형 적용 시 기존 트랜스폼 트윈(대기·전진·공격·피격) 재사용.
> 참고: 실제 음원·`AudioStreamPlayer`는 아직 없음(`AudioHooks`는 호출 경계만). 소리는 TASK 019.

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
