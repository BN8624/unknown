# 균열기사 (Riftblade Knight)

세로형(540×960) 모바일 **방치형 RPG**. Godot 4.7로 만든 작은 출시 후보 v0.1.
갈라진 변경의 균열에서 끝없이 밀려오는 마물을 홀로 베어내는 기사를 자동 전투로 성장시킨다.

> 정본 기획: [`PRODUCT_RESET_SPEC.md`](PRODUCT_RESET_SPEC.md)

---

## 현재 상태

**출시 후보 v0.1 — 핵심 루프와 메타·콘텐츠가 닫힌 상태.** 아트·사운드는 전부 코드로 생성한 절차적 자체제작(CC0).

구현됨:

- 자동 전투(공격·치명타·피해 숫자·파티클), 패배 시 자동 재정비
- 성장 5종: 공격력 · 체력 · 방어력 · 치명타 · 골드 획득(비용 증가·부족 시 비활성)
- 레벨·경험치, 전투력 표시, 큰 수 축약 표기(K/M/B/…)
- 스테이지 진행, 5층마다 보스(외형·HP바·강공격 예열 패턴으로 구분)
- 2개 지역: 갈라진 변경(1~20층) · 잿빛 협곡(21~40층), 이후 무한 스케일
- 보상 표시, 지역 클리어 → 다음 지역 개방
- **환생(프레스티지)** + **균열석 상점**(환생해도 유지되는 영구 강화 4종)
- **오프라인 보상**(최대 8시간)
- 사운드: 합성 효과음 8종 + BGM 루프, 설정에서 on/off
- 저장/불러오기(JSON, 재접속 진행 유지), 설정·진행 초기화
- 첫 실행 온보딩 안내

아직 없는 것(후속 후보): 정식 일러스트/애니메이션 아트, 더 긴 BGM, 3지역 이상, 적 스킬 다양화, 랭킹/업적.

---

## 실행

에디터로 실행(화면 확인):

```
"<godot>" --path . Main.tscn
```

Web 빌드:

```
"<godot>" --headless --path . --export-release "Web" "build/index.html"
```

> Web 페이지 `<title>`은 export 시 프로젝트명("unknown")으로 리셋되므로, 내보낸 뒤 `build/index.html`의 title을 "균열기사"로 바꾼다.

개발용 스크린샷 모드: `"<godot>" --path . -- --shot` → `scratchpad/shot_*.png` 저장 후 종료.

---

## 구조

데이터(수치·콘텐츠)와 화면(루프·UI)을 분리해 나중에 쉽게 바꾸도록 했다.

| 파일 | 역할 |
| --- | --- |
| `Main.gd` / `Main.tscn` | 화면·전투 루프·성장·스테이지·보스·보상·저장·오프라인·환생·사운드 |
| `reset/GameData.gd` | 밸런스·콘텐츠 데이터(적·스테이지·지역·성장·환생 수치) |
| `reset/SaveSystem.gd` | JSON 저장/불러오기(버전 필드) |
| `reset/gen_art.py` | 절차적 아트 텍스처 생성 → `assets/gen/` |
| `reset/gen_audio.py` | 효과음·BGM 합성 → `assets/gen_sfx/`, `assets/gen_bgm/` |

저장 위치: `user://riftblade_save_v1.json` (레벨·경험치·골드·강화·스테이지·균열석·상점·설정).

아트/사운드를 다시 만들려면: `python reset/gen_art.py`, `python reset/gen_audio.py` (numpy·Pillow 필요).

---

## 크레딧 / 라이선스

- **캐릭터·몬스터 스프라이트**: [Kenney](https://kenney.nl) — *Tiny Dungeon* 팩, **CC0**. `assets/sprites/`.
- **배경·파티클·효과음·BGM**: `reset/gen_art.py`·`reset/gen_audio.py`로 생성한 **절차적 자체제작(CC0)**. `assets/gen*`.
- AI 이미지 생성 미사용. 모두 CC0라 상업 배포 가능(저작자 표시 의무 없음, 위는 감사 표기).
- 한글 폰트(`malgun.ttf`)는 저장소에 포함하지 않으며(상용), 없으면 기본 폰트로 동작한다.
