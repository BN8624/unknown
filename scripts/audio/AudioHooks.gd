# 사운드 이벤트 경계(이벤트 이름 → 실제 SFX 매핑·계측). 실제 재생은 등록된 sink가 담당한다(TASK 019)
extends RefCounted

# 전투·성장·보스 흐름에서 소리가 나야 할 순간을 이름으로만 요청한다.
# 실제 재생은 sink(Battle)가 맡고, 여기서는 이벤트→SFX 매핑과 호출 횟수 계측만 한다.
const EVENTS := [
	"ui_button",
	"merc_basic_attack", "merc_hit", "merc_death", "merc_revive",
	"enemy_basic_attack", "enemy_hit", "enemy_death",
	"trait_heavy_strike", "trait_flurry", "trait_counter_block", "trait_counter_attack",
	"level_up", "elite_appear", "boss_appear",
	"boss_heavy_windup", "boss_defense_stance", "boss_posture_break", "boss_victory",
]

# 이벤트 → 실제 SFX 파일 기본명(assets/sfx/<name>.wav). ""이면 소리 없음(중복·과잉 방지).
# 19개 이벤트를 11종 효과음으로 매핑한다.
const SFX_MAP := {
	"ui_button": "button",
	"merc_basic_attack": "attack_basic",
	"merc_hit": "hit",
	"merc_death": "hit",
	"merc_revive": "",
	"enemy_basic_attack": "attack_basic",
	"enemy_hit": "hit",
	"enemy_death": "",                      # 치명타 hit로 이미 피드백 → 중복 방지
	"trait_heavy_strike": "heavy",
	"trait_flurry": "flurry",
	"trait_counter_block": "",              # 반격은 counter_attack에서 한 번만
	"trait_counter_attack": "counter",
	"level_up": "level_up",
	"elite_appear": "elite_appear",
	"boss_appear": "boss_appear",
	"boss_heavy_windup": "boss_charge",
	"boss_defense_stance": "",              # 청색 강조(시각)로 충분
	"boss_posture_break": "heavy",          # 자세 붕괴 = 큰 충격 재사용
	"boss_victory": "boss_victory",
}

# 이벤트별 누적 호출 횟수(검증·디버그용 계측, 게임 상태 아님).
static var counts := {}

# 실제 재생을 맡는 sink(Battle 노드). play_sfx(name) 메서드를 가진 노드를 기대한다.
# 미등록(헤드리스 --verify 등)이면 계측만 하고 소리는 내지 않는다.
static var _sink = null

# Battle이 오디오 풀을 준비한 뒤 자신을 등록한다.
static func set_sink(sink) -> void:
	_sink = sink

# sink를 해제한다(씬 재시작 등).
static func clear_sink() -> void:
	_sink = null

# 사운드 이벤트 1회 요청. 먼저 호출을 계측하고(검증 의존), 그 다음 등록된 sink로 실제 재생을 라우팅한다.
# 알 수 없는 이벤트 이름은 경고만 남기고 무시한다(게임 흐름에 영향 없음).
static func play(event: String) -> void:
	if not EVENTS.has(event):
		push_warning("AudioHooks: unknown event '%s'" % event)
		return
	counts[event] = int(counts.get(event, 0)) + 1
	if _sink != null and is_instance_valid(_sink):
		var sfx: String = SFX_MAP.get(event, "")
		if sfx != "" and _sink.has_method("play_sfx"):
			_sink.play_sfx(sfx)

# 계측 카운터 초기화(검증 시 특정 행동 전후 호출 횟수를 재기 위해 사용).
static func reset_counts() -> void:
	counts = {}

# 특정 이벤트가 지금까지 몇 번 호출됐는지 반환.
static func get_count(event: String) -> int:
	return int(counts.get(event, 0))
