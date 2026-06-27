# CURRENT TASK

- Task: TASK 020 — 브루노 처치 후 용병 외형 승급
- GitHub Issue: #7 (정본) — https://github.com/BN8624/unknown/issues/7
- 상태: **진행 중.** 코드 구현 단계. 실제 아트 에셋(`mercenary_upgraded.png`)은 사용자 제공 대기.
- 정본: GitHub Issue #7 / 화풍은 ART_STYLE_GUIDE.md

---

## 목표 (Issue #7)

브루노 처치(`boss_defeated == true`) 시 용병 외형을 `mercenary.png` → `mercenary_upgraded.png`(철검+가죽 갑옷, 한 단계 성장)로 교체. 저장 복원 시에도 유지. 새 저장 키 없음(기존 `boss_defeated` 재사용). 짧은 승급 연출(<1초) 허용.

**불변**: 전투 수치·강화 비용·보스 보상·저장 형식·UI 배치·표시 높이(`MERC_DISP_H=144`)·`CHAR_FOOT_Y`·`PANEL_TOP_Y`·체력바 위치. 장비/인벤토리/드랍/외형선택 UI 없음.

## 핵심 의존성

- **새 아트 `assets/characters/mercenary_upgraded.png`** — RGBA 투명 PNG, 용병과 같은 SD 전신·같은 키 계열·오른쪽 바라봄, 브루노 장비 탈취 느낌 금지. **AI 생성 필요 → 사용자 제공 대기.** 없으면 코드가 기본 용병으로 안전 폴백.

## 결정

- 텍스처 선택은 순수 함수 `_choose_merc_tex(defeated, upgraded_exists)`로 분리(검증 결정적). `_build_merc`와 로드 후·승리 시 교체가 이를 사용.
- 적용 시점: ①`_load_game()` 후(저장된 boss_defeated 반영) ②브루노 승리 처리 시(짧은 연출과 함께). Sprite2D 텍스처만 교체·재정렬(노드·판정·체력바 보존).
- 에셋 누락 시 기본 용병(또는 도형) 폴백.

## 체크리스트

- [ ] 문서 동기화(CURRENT/HANDOFF/VERTICAL_SLICE/ART_STYLE_GUIDE 오래된 표현 정리)
- [ ] `MERC_UPGRADED_TEX_PATH` + `_choose_merc_tex` 순수 함수
- [ ] `_apply_merc_appearance(flash)` — Sprite2D 텍스처 교체·재정렬, 로드 후·승리 시 호출
- [ ] 승급 연출(짧은 확대·반짝임·"장비가 좋아졌다" 문구, <1초)
- [ ] 전용 검증 `_verify_task020`(false→기본, true→업그레이드, 누락→폴백)
- [ ] `--verify` ALL PASS, SCRIPT ERROR 0
- [ ] (에셋 도착 후) import → `--shot` 7장 → Web 빌드 → 아이폰 확인
- [ ] Issue #7 보고

## 다음 TASK
021 슬라이스 전체 아이폰 검증.
