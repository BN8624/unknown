# AUDIO CREDITS

이 프로젝트에 사용된 사운드의 출처·라이선스 기록이다. (정본 기준은 Issue #6 댓글의 음원 우선순위.)

## 효과음 (assets/sfx/)

11종 전부 **직접 생성(자체 합성) CC0**다. 외부 에셋을 받지 않고 `scripts/audio/gen_sfx.py`(numpy 합성)로 만든다. 재실행 시 동일 결과(결정적, seed 1019).

| 파일명 | 사용 이벤트(AudioHooks) | 출처 | 라이선스 | 수정 여부 |
| --- | --- | --- | --- | --- |
| attack_basic.wav | merc_basic_attack, enemy_basic_attack | 자체 합성(gen_sfx.py) | CC0 | 생성 |
| hit.wav | merc_hit, enemy_hit, merc_death | 자체 합성(gen_sfx.py) | CC0 | 생성 |
| heavy.wav | trait_heavy_strike, boss_posture_break | 자체 합성(gen_sfx.py) | CC0 | 생성 |
| flurry.wav | trait_flurry | 자체 합성(gen_sfx.py) | CC0 | 생성 |
| counter.wav | trait_counter_attack | 자체 합성(gen_sfx.py) | CC0 | 생성 |
| level_up.wav | level_up | 자체 합성(gen_sfx.py) | CC0 | 생성 |
| elite_appear.wav | elite_appear | 자체 합성(gen_sfx.py) | CC0 | 생성 |
| boss_appear.wav | boss_appear | 자체 합성(gen_sfx.py) | CC0 | 생성 |
| boss_charge.wav | boss_heavy_windup | 자체 합성(gen_sfx.py) | CC0 | 생성 |
| boss_victory.wav | boss_victory | 자체 합성(gen_sfx.py) | CC0 | 생성 |
| button.wav | ui_button | 자체 합성(gen_sfx.py) | CC0 | 생성 |

소리 없음(매핑 ""): merc_revive, enemy_death(치명 hit로 충분), trait_counter_block(반격은 counter에서 1회), boss_defense_stance(청색 강조로 충분).

## 비고

- 임시 식별용 합성음이다. 나중에 더 풍부한 음을 원하면 Kenney CC0 / OpenGameArt CC0 음원으로 파일 단위 교체 가능(매핑은 `AudioHooks.SFX_MAP`, 파일은 같은 이름으로 덮으면 됨). 교체 시 이 표의 출처·라이선스·수정여부를 갱신할 것.
- 사용 금지: CC-BY, CC-BY-NC, 라이선스 불명, 영상/게임 추출 음원.
- BGM 없음(TASK 019 범위 밖).
