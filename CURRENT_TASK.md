# CURRENT TASK

- Task: TASK 015 — 용병·늑대·변경 교역로 첫 아트 샘플 (SD 전신 스프라이트)
- GitHub Issue: #3 (정본) — https://github.com/BN8624/unknown/issues/3
- 상태: 기술 적용·레이아웃 확정값·렌더 스크린샷 검증 완료. 색감·미세조정·최종 미감은 TASK 016.
- 정본: GitHub Issue #3 / 화풍·제작 방식은 ART_STYLE_GUIDE.md

---

## 적용 완료 (SD 전신, 동작 변화 0)

- 용병·늑대 `Sprite2D`(Node2D 래퍼+자식, 표시 축소비는 자식이 흡수해 연출 scale이 표시 크기를 안 덮음). 늑대만 적용, 나머지 적은 도형.
- 배경 하늘·지면 2레이어 가로 스크롤. 지면을 위로(GROUND_TOP_Y) 끌어올려 캐릭터 발이 지면 안쪽에.
- 텍스처 누락 시 도형 폴백, 비상호작용 입력 통과.

## GPT 확정 레이아웃 값 (Issue #3)
```
MERC_DISP_H 144 · WOLF_DISP_H 92
CHAR_FOOT_Y 660 (캐릭터 발) · CHAR_FOOT_DROP 제거
GROUND_TOP_Y 615 (지면 상단) · PANEL_TOP_Y 700 · MIN_PANEL_GAP 24
레벨업 강조 scale 1.18
```

## 검증
- `--shot` 모드 추가: GUI에서 540×960 렌더 직접 캡처(기본·레벨업). 4조건 확인 — 패널 비겹침·발 접촉·체력바·정상 배치, 레벨업 확대 침범 없음.
- 헤드리스 `--verify`: ALL PASS TASK_001~014(종료 0), SCRIPT ERROR 0. Web 빌드 정상.

## 다음 — TASK 016 (아이폰 아트 승인·수정)
- 색감, 캐릭터 2~5px 미세조정, 좌우 간격, 배경 미세 위치, 최종 미감.
- 검증은 `--shot` 렌더 스크린샷을 1차로, 그 다음 아이폰.

## 아이폰
`https://node.tail3e9e21.ts.net:8443/?v=16`
