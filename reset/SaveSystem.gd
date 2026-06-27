# 저장·불러오기 (user:// JSON, 버전 필드 고정) — 균열기사 v0.1
extends RefCounted

const PATH := "user://riftblade_save_v1.json"
const VERSION := 1

# 진행 상태를 JSON으로 저장한다. 실패해도 게임은 멈추지 않는다.
static func save(state: Dictionary) -> void:
	var data := {
		"version": VERSION,
		"level": int(state.get("level", 1)),
		"exp": int(state.get("exp", 0)),
		"gold": int(state.get("gold", 0)),
		"upgrades": state.get("upgrades", {}),
		"stage": int(state.get("stage", 1)),
		"kills": int(state.get("kills", 0)),
		"max_stage_cleared": int(state.get("max_stage_cleared", 0)),
		"region_cleared": bool(state.get("region_cleared", false)),
		"souls": int(state.get("souls", 0)),
		"prestige_count": int(state.get("prestige_count", 0)),
		"soul_upgrades": state.get("soul_upgrades", {}),
		"sound_on": bool(state.get("sound_on", true)),
		"seen_intro": bool(state.get("seen_intro", false)),
		"counters": state.get("counters", {}),
		"missions": state.get("missions", []),
		"daily_day": int(state.get("daily_day", 0)),
		"daily_streak": int(state.get("daily_streak", 0)),
		"auto_boss": bool(state.get("auto_boss", false)),
		"last_save_unix": int(Time.get_unix_time_from_system()),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("저장 실패: 파일 열기 불가")
		return
	f.store_string(JSON.stringify(data))
	f.close()

# 저장이 있으면 정규화한 상태를 반환, 없으면 빈 딕셔너리.
static func load_state() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if int(parsed.get("version", 0)) != VERSION:
		return {}   # 버전 불일치는 새 게임으로(마이그레이션 없음)
	var up_in = parsed.get("upgrades", {})
	var upgrades := {}
	for id in ["atk", "hp", "def", "crit", "gold"]:
		upgrades[id] = int(up_in.get(id, 0)) if typeof(up_in) == TYPE_DICTIONARY else 0
	var su_in = parsed.get("soul_upgrades", {})
	var soul_upgrades := {}
	for id in ["s_atk", "s_gold", "s_hp", "s_off"]:
		soul_upgrades[id] = int(su_in.get(id, 0)) if typeof(su_in) == TYPE_DICTIONARY else 0
	return {
		"level": maxi(1, int(parsed.get("level", 1))),
		"exp": maxi(0, int(parsed.get("exp", 0))),
		"gold": maxi(0, int(parsed.get("gold", 0))),
		"upgrades": upgrades,
		"stage": maxi(1, int(parsed.get("stage", 1))),
		"kills": maxi(0, int(parsed.get("kills", 0))),
		"max_stage_cleared": maxi(0, int(parsed.get("max_stage_cleared", 0))),
		"region_cleared": bool(parsed.get("region_cleared", false)),
		"souls": maxi(0, int(parsed.get("souls", 0))),
		"prestige_count": maxi(0, int(parsed.get("prestige_count", 0))),
		"soul_upgrades": soul_upgrades,
		"sound_on": bool(parsed.get("sound_on", true)),
		"seen_intro": bool(parsed.get("seen_intro", false)),
		"counters": parsed.get("counters", {}) if typeof(parsed.get("counters")) == TYPE_DICTIONARY else {},
		"missions": parsed.get("missions", []) if typeof(parsed.get("missions")) == TYPE_ARRAY else [],
		"daily_day": int(parsed.get("daily_day", 0)),
		"daily_streak": int(parsed.get("daily_streak", 0)),
		"auto_boss": bool(parsed.get("auto_boss", false)),
		"last_save_unix": int(parsed.get("last_save_unix", 0)),
	}

static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		# user:// 경로 직접 제거 시도(웹 포함 안전하게)
		var d := DirAccess.open("user://")
		if d != null and d.file_exists(PATH.get_file()):
			d.remove(PATH.get_file())
