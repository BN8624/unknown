# 사운드 이벤트 요청만 받는 경계(아직 실제 음원·AudioStreamPlayer 없음, 게임 상태 변경 없음)
extends RefCounted

# 전투·성장·보스 흐름에서 소리가 나야 할 순간을 이름으로만 요청한다.
# 실제 재생은 이후 TASK에서 이 경계 뒤에 붙인다. 지금은 호출 횟수만 계측한다.
const EVENTS := [
	"ui_button",
	"merc_basic_attack", "merc_hit", "merc_death", "merc_revive",
	"enemy_basic_attack", "enemy_hit", "enemy_death",
	"trait_heavy_strike", "trait_flurry", "trait_counter_block", "trait_counter_attack",
	"level_up", "elite_appear", "boss_appear",
	"boss_heavy_windup", "boss_defense_stance", "boss_posture_break", "boss_victory",
]

# 이벤트별 누적 호출 횟수(검증·디버그용 계측, 게임 상태 아님).
static var counts := {}

# 사운드 이벤트 1회 요청. 실제 소리는 내지 않고 호출만 기록한다.
# 알 수 없는 이벤트 이름은 경고만 남기고 무시한다(게임 흐름에 영향 없음).
static func play(event: String) -> void:
	if not EVENTS.has(event):
		push_warning("AudioHooks: unknown event '%s'" % event)
		return
	counts[event] = int(counts.get(event, 0)) + 1

# 계측 카운터 초기화(검증 시 특정 행동 전후 호출 횟수를 재기 위해 사용).
static func reset_counts() -> void:
	counts = {}

# 특정 이벤트가 지금까지 몇 번 호출됐는지 반환.
static func get_count(event: String) -> int:
	return int(counts.get(event, 0))
