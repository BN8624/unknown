# CURRENT TASK

- Task: TASK 015 — 용병·늑대·변경 교역로 첫 아트 샘플 (SD 전신 스프라이트)
- GitHub Issue: #3 (정본) — https://github.com/BN8624/unknown/issues/3
- 상태: 아트 방식 컷아웃→**SD 전신 스프라이트로 변경**(Issue #3). 배경 2개 확보, 캐릭터 2개는 투명 PNG 대기(불투명 반려). 코드 적용 보류.
- 정본: GitHub Issue #3 / 화풍·제작 방식은 ART_STYLE_GUIDE.md

---

## 방식 변경 (Issue #3)

컷아웃 파츠 방식 폐기(AI 생성 파츠 비율·관절 불안정). 캐릭터는 SD 전신 투명 PNG 1장 → Godot Sprite2D → 코드 트윈 연출(대기·공격·피격·죽음). 배경은 하늘·지면 2레이어 가로 스크롤. 전투·밸런스·UI·저장·등장 순서 변경 없음.

## 최종 에셋 4개

```
assets/characters/ mercenary.png  wolf.png
assets/bg/         bg_sky.png     bg_ground.png
```

## 현재 진행

- (완료) ART_STYLE_GUIDE.md를 SD 전신 방식 정본으로 재작성, VERTICAL_SLICE 연결 갱신.
- (완료) 기존 `assets/ref/` 컷아웃 기준 이미지 삭제, 새 4개 배치.
- (대기) **캐릭터 2개가 불투명 흰 배경(알파 없음)** — 사용자 결정대로 알파 포함 투명 PNG로 다시 받기. 같은 경로·파일명으로 덮어쓰면 적용 진행.
- 배경 2개는 사용 가능. 단 크기가 계약과 다름(sky 1110×1417, ground 1774×887) → 적용 시 코드에서 화면에 맞춰 스케일·타일링.

## 다음 (투명 캐릭터 수령 후)

1. mercenary·wolf를 Sprite2D로 적용(기존 도형 폴백 유지, 누락 시 도형).
2. 변경 교역로 배경 2레이어 적용(하늘 느리게·지면 빠르게).
3. 자동 검증(TASK_001~014 유지)·Web 빌드·아이폰 확인 → Issue #3 보고.

최종 미술 승인·수정은 TASK 016.
