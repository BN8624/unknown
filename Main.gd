# 균열기사 v0.1 — 화면·전투 루프·성장·스테이지·보상·저장을 묶는 메인 (데이터는 reset/GameData.gd)
extends Control

const GameData := preload("res://reset/GameData.gd")
const SaveSystem := preload("res://reset/SaveSystem.gd")

# ── 팔레트(다크 판타지: 차콜 스틸 + 금색 강조, 보라 최소화) ──────
const COL_PANEL := Color(0.09, 0.10, 0.13, 0.97)
const COL_PANEL_HI := Color(0.14, 0.16, 0.20, 0.98)
const COL_BTN := Color(0.17, 0.19, 0.24)
const COL_BTN_HI := Color(0.25, 0.28, 0.34)
const COL_BORDER := Color(0.44, 0.40, 0.30)        # 은은한 청동/금테
const COL_BEVEL := Color(0.72, 0.68, 0.52, 0.5)    # 윗변 하이라이트(금빛)
const COL_SHADOW := Color(0.0, 0.0, 0.0, 0.5)
const COL_GOLD := Color(1.0, 0.81, 0.36)
const COL_TEXT := Color(0.94, 0.94, 0.96)
const COL_DIM := Color(0.58, 0.60, 0.64)
const COL_HP := Color(0.40, 0.85, 0.46)
const COL_HP_BOSS := Color(0.90, 0.30, 0.34)
const COL_EXP := Color(0.40, 0.74, 0.95)           # 청록(보라 대신)
const COL_CRYSTAL := Color(0.62, 0.80, 0.92)       # 균열석/환생 강조(차분한 청)

const GROUND_Y := 600.0
const HERO_X := 158.0
const ENEMY_X := 392.0

# ── 진행 상태(저장 대상) ─────────────────────────────────────────
var level := 1
var exp := 0
var gold := 0
var upgrades := {"atk": 0, "hp": 0, "def": 0, "crit": 0, "gold": 0}
var stage := 1
var kills := 0
var max_stage_cleared := 0
var region_cleared := false
var souls := 0                # 환생 재화(균열석)
var prestige_count := 0
var last_save_unix := 0
var soul_upgrades := {"s_atk": 0, "s_gold": 0, "s_hp": 0, "s_off": 0}
var p_global_mult := 1.0      # 균열석 영구 배수(전투력)
var p_gold_mult := 1.0        # 균열석 + 상점 골드 배수
var p_off_eff := 0.6          # 오프라인 효율
var p_crit_mult := 2.0        # 치명타 피해 배수(처형 반영)
var p_cd_scale := 1.0         # 스킬 쿨다운 배수(각성 반영)
var p_power := 0              # 전투력(표시용)
var ach_mult := 1.0           # 업적 영구 배수(전투력·골드)
var achieved: Array = []      # 달성한 업적 id
# 자동화(저장)
var auto_upgrade := false
var auto_skill := false
var auto_prestige := false
var last_progress_t := 0.0    # 마지막 진행(스테이지 클리어) 이후 경과 — 자동 환생 판단
var _overpower := false        # 현재 적을 한 방에 처치 가능

# ── 파생 능력치 ──────────────────────────────────────────────────
var p_atk := 10
var p_max_hp := 100
var p_hp := 100
var p_def := 0
var p_crit := 0.03
var p_interval := 0.85

# ── 런타임 ───────────────────────────────────────────────────────
var enemy := {}
var p_atk_timer := 0.0
var e_atk_timer := 0.0
var boss_atk_count := 0
var boss_winding := false    # 보스 강공격 예열 중
var boss_active := false     # 실제 보스전 진행 중(게이트에서 도전 시작)
var auto_boss := false       # 보스 자동 도전(저장)
var challenge_btn: Button
var auto_btn: Button
var busy := false            # 보상 표시 중엔 전투 정지
# 액티브 스킬
const SMASH_CD := 9.0
const HASTE_CD := 18.0
const HASTE_DUR := 6.0
var smash_cd := 0.0
var haste_cd := 0.0
var haste_timer := 0.0
var smash_btn: Button
var haste_btn: Button
var kfont: FontFile

# UI 참조
var lbl_stage: Label
var lbl_gold: Label
var lbl_level: Label
var exp_fill: ColorRect
var lbl_progress: Label
var hero: Node2D
var hero_sprite: Sprite2D
var hero_vis: CanvasItem
var hero_anim: AnimatedSprite2D
var hero_hp_fill: ColorRect
var enemy_node: Node2D
var enemy_hp_fill: ColorRect
var enemy_hp_bg: ColorRect
var lbl_enemy_name: Label
var notice: Label
var up_rows := {}            # id → {panel,name,value,cost,button}
var reward_overlay: Control
var reward_title: Label
var reward_body: Label
var settings_overlay: Control
var prestige_overlay: Control
var prestige_body: Label
var prestige_do_btn: Button
var lbl_souls: Label
var mission_btn: Button
var mission_overlay: Control
var mission_rows := []
var save_timer := 0.0
var sfx_streams := {}
var sfx_players: Array = []
var sfx_next := 0
var sound_on := true
var seen_intro := false
var counters := {"kill": 0, "stage": 0, "upgrade": 0, "boss": 0, "gold": 0}
var missions: Array = []        # 활성 임무 3개: {pool, base}
var daily_day := 0
var daily_streak := 0


var ui_layer: CanvasLayer

func _ready() -> void:
	_shot_mode = "--shot" in OS.get_cmdline_user_args()
	ui_layer = CanvasLayer.new()       # 모든 오버레이는 이 레이어에 → 전투 표시물 위에 항상 그려짐
	ui_layer.layer = 10
	add_child(ui_layer)
	_build_background()
	_build_battle_area()
	_build_vignette()
	_build_hud()
	_build_growth_panel()
	_build_skills()
	_build_notice()
	_build_reward_overlay()
	_build_settings_overlay()
	_build_prestige_overlay()
	_build_mission_overlay()
	_build_achievements_overlay()
	_setup_audio()
	var s := SaveSystem.load_state()
	if not s.is_empty():
		_apply_save(s)
	_recompute_ach_mult()
	_recompute_stats()
	p_hp = p_max_hp
	_apply_hero_skin()
	_ensure_missions()
	_spawn_enemy()
	_update_hud()
	_update_growth_buttons()
	_refresh_mission_badge()
	_refresh_auto_btn()
	_apply_font()
	if not _shot_mode and not s.is_empty():
		_grant_offline(s)
	if not _shot_mode:
		_check_daily()
	if not _shot_mode and not seen_intro:
		_show_onboarding()
	if _shot_mode:
		_run_shot_sequence()


# --shot: GUI에서 몇 장면을 캡처해 레이아웃을 확인하고 종료(개발용)
var _shot_mode := false
const SHOT_DIR := "C:/Users/USER/AppData/Local/Temp/claude/C--Users-USER-unknown/ba7c179b-0677-4fb1-ad24-6193890d8154/scratchpad"

func _run_shot_sequence() -> void:
	await get_tree().create_timer(0.6).timeout
	_show_onboarding()
	await get_tree().create_timer(0.3).timeout
	_save_shot("r00_intro")
	if is_instance_valid(_onboard_ov):
		_onboard_ov.queue_free()
	await get_tree().create_timer(0.1).timeout
	_save_shot("r01_start")
	gold = 99999; _update_hud(); _update_growth_buttons()
	await get_tree().create_timer(0.3).timeout
	_save_shot("r02_rich")
	stage = 5; kills = 0; boss_active = true; _spawn_enemy()   # 보스 외형
	await get_tree().create_timer(0.5).timeout
	_save_shot("r03_boss")
	_show_reward("보스 격파!", "거대 거미 아라크 처치\n골드 +1,200\n전투력이 단단해졌습니다.\n\n6층으로 전진!")
	await get_tree().create_timer(0.4).timeout
	_save_shot("r04_reward")
	reward_overlay.visible = false
	max_stage_cleared = 12; souls = 8; _recompute_stats(); _update_hud()
	_open_prestige()
	await get_tree().create_timer(0.4).timeout
	_save_shot("r05_prestige")
	prestige_overlay.visible = false
	_show_reward("돌아오셨군요!", "자리를 비운 3시간 12분 동안\n부하들이 사냥했습니다.\n\n골드 +18,400")
	await get_tree().create_timer(0.4).timeout
	_save_shot("r06_offline")
	reward_overlay.visible = false
	stage = 23; kills = 2; _spawn_enemy()   # 2지역(잿빛 협곡) 일반 적
	await get_tree().create_timer(0.5).timeout
	_save_shot("r07_region2")
	stage = 40; kills = 0; boss_active = true; _spawn_enemy()    # 2지역 최종 보스
	await get_tree().create_timer(0.4).timeout
	_boss_heavy()                            # 강공격 예열(확대·붉은 경고)
	await get_tree().create_timer(0.45).timeout
	_save_shot("r08_bosswindup")
	# 임무 오버레이(진행도 보이게 카운터 세팅)
	boss_winding = false
	counters = {"kill": 137, "stage": 23, "upgrade": 14, "boss": 4, "gold": 88000}
	missions = []; _ensure_missions(); _refresh_mission_badge()
	_open_missions()
	await get_tree().create_timer(0.4).timeout
	_save_shot("r09_missions")
	mission_overlay.visible = false
	stage = 43; kills = 3; boss_active = false; prestige_count = 2; _apply_hero_skin(); _spawn_enemy()  # 3지역 + 승급 영웅
	await get_tree().create_timer(0.5).timeout
	_save_shot("r10_region3")
	stage = 10; kills = 0; boss_active = false; _spawn_enemy()  # 보스 관문(도전 버튼)
	await get_tree().create_timer(0.5).timeout
	_save_shot("r11_gate")
	stage = 20  # 뿔 보스(균열의 수호자) → 전용 초상화 표시
	_boss_intro()  # 보스 도전 컷(초상화)
	await get_tree().create_timer(0.6).timeout
	_save_shot("r11b_bossintro")
	stage = 5; _boss_intro()  # 거미 보스 → 초상화 없이 이름 배너(불일치 방지)
	await get_tree().create_timer(0.6).timeout
	_save_shot("r11c_bossname")
	# 업적 오버레이(일부 달성 상태로)
	max_stage_cleared = 45; counters = {"kill": 5200, "stage": 50, "upgrade": 230, "boss": 12, "gold": 2500000}
	achieved = ["f10","f25","f40","k100","k1k","b10","u50","u200","p1"]; _recompute_ach_mult(); _recompute_stats()
	_open_achievements()
	await get_tree().create_timer(0.4).timeout
	_save_shot("r12_achievements")
	ach_overlay.visible = false
	auto_upgrade = true; auto_skill = true
	_open_settings(); _apply_font_to(settings_overlay)
	await get_tree().create_timer(0.3).timeout
	_save_shot("r13_automation")
	get_tree().quit(0)

var _onboard_ov: Control

# 첫 실행 안내(코치마크). 카드를 탭하며 3장 넘기고, 끝나면 다시 안 보이게 저장한다.
func _show_onboarding() -> void:
	var pages := [
		"균열기사가 자동으로 싸웁니다.\n적을 처치하면 골드와 경험치가 쌓여요.",
		"아래 [성장] 버튼으로 강해지세요.\n누를수록 강해지고 비용이 오릅니다.",
		"5층마다 보스가 등장합니다.\n처치하면 다음 지역으로 전진!",
		"◆ 환생으로 진행을 초기화하면\n영구 강화 [균열석]을 얻어 더 빨라집니다.\n\n행운을 빕니다, 기사여!",
	]
	var ov := Control.new()
	ov.size = GameData.SCREEN
	ui_layer.add_child(ov)
	_onboard_ov = ov
	# 타이틀 배경 아트(균열 앞의 기사)
	var scene := _ui_icon("scene_rift", Vector2.ZERO, 0)
	if scene != null:
		scene.size = GameData.SCREEN
		scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		ov.add_child(scene)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.45)
	dim.size = GameData.SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.add_child(dim)
	var titlebar := _new_label("균열기사", 44, COL_GOLD)
	titlebar.position = Vector2(0, 70); titlebar.size = Vector2(GameData.SCREEN.x, 60)
	titlebar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(titlebar)
	var box := _new_panel(Rect2(50, 560, 440, 250), COL_PANEL_HI)
	ov.add_child(box)
	var head := _new_label("환영합니다", 28, COL_GOLD)
	head.position = Vector2(50, 584)
	head.size = Vector2(440, 36)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(head)
	var body := _new_label("", 21, COL_TEXT)
	body.position = Vector2(78, 632)
	body.size = Vector2(384, 120)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov.add_child(body)
	var btn := Button.new()
	btn.position = Vector2(150, 752)
	btn.size = Vector2(240, 46)
	btn.add_theme_font_size_override("font_size", 20)
	_style_button(btn)
	ov.add_child(btn)
	var idx := {"i": 0}
	var refresh := func() -> void:
		body.text = pages[idx["i"]]
		btn.text = "다음 ▶" if idx["i"] < pages.size() - 1 else "시작하기"
		if kfont != null:
			_apply_font_to(ov)
	refresh.call()
	btn.pressed.connect(func() -> void:
		_play("button")
		idx["i"] += 1
		if idx["i"] >= pages.size():
			seen_intro = true
			_save()
			ov.queue_free()
		else:
			refresh.call())


# ── 임무(리텐션) ─────────────────────────────────────────────────
func _ensure_missions() -> void:
	while missions.size() < 3:
		var active_types := []
		for m in missions:
			active_types.append(GameData.MISSION_POOL[int(m["pool"])]["type"])
		# 가능하면 현재 활성 임무에 없는 타입을 우선 선택(다양성)
		var fresh := []
		for i in range(GameData.MISSION_POOL.size()):
			if not active_types.has(GameData.MISSION_POOL[i]["type"]):
				fresh.append(i)
		var pool := fresh if not fresh.is_empty() else range(GameData.MISSION_POOL.size())
		var pi: int = pool[randi() % pool.size()]
		var typ: String = GameData.MISSION_POOL[pi]["type"]
		missions.append({"pool": pi, "base": int(counters.get(typ, 0))})


func _mission_state(m: Dictionary) -> Dictionary:
	var pdef: Dictionary = GameData.MISSION_POOL[int(m["pool"])]
	var cur: int = int(counters.get(pdef["type"], 0)) - int(m["base"])
	var amt: int = int(pdef["amount"])
	return {"cur": clampi(cur, 0, amt), "amt": amt, "done": cur >= amt, "def": pdef}


func _claimable_count() -> int:
	var n := 0
	for m in missions:
		if _mission_state(m)["done"]:
			n += 1
	return n


func _refresh_mission_badge() -> void:
	if mission_btn == null:
		return
	var n := _claimable_count()
	mission_btn.text = "임무 ●%d" % n if n > 0 else "임무"
	if mission_overlay != null and mission_overlay.visible:
		_refresh_mission_rows()


func _build_mission_overlay() -> void:
	mission_overlay = Control.new()
	mission_overlay.size = GameData.SCREEN
	mission_overlay.visible = false
	ui_layer.add_child(mission_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.68)
	dim.size = GameData.SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	mission_overlay.add_child(dim)
	var box := _new_panel(Rect2(40, 280, 460, 400), COL_PANEL_HI)
	mission_overlay.add_child(box)
	var t := _new_label("임무", 30, COL_GOLD)
	t.position = Vector2(40, 302)
	t.size = Vector2(460, 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_overlay.add_child(t)
	var y := 360.0
	for i in range(3):
		var panel := _new_panel(Rect2(56, y, 428, 78), COL_PANEL)
		mission_overlay.add_child(panel)
		var desc := _new_label("", 18, COL_TEXT)
		desc.position = Vector2(72, y + 8)
		mission_overlay.add_child(desc)
		var barbg := ColorRect.new()
		barbg.color = Color(0, 0, 0, 0.5); barbg.size = Vector2(240, 12); barbg.position = Vector2(72, y + 40)
		barbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mission_overlay.add_child(barbg)
		var barfill := ColorRect.new()
		barfill.color = COL_EXP; barfill.size = Vector2(0, 12); barfill.position = Vector2(72, y + 40)
		barfill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mission_overlay.add_child(barfill)
		var prog := _new_label("", 14, COL_DIM)
		prog.position = Vector2(320, y + 38); prog.size = Vector2(80, 20)
		mission_overlay.add_child(prog)
		var claim := Button.new()
		claim.position = Vector2(360, y + 18); claim.size = Vector2(112, 42)
		claim.add_theme_font_size_override("font_size", 17)
		_style_button(claim)
		claim.pressed.connect(_claim_mission.bind(i))
		mission_overlay.add_child(claim)
		mission_rows.append({"desc": desc, "fill": barfill, "prog": prog, "claim": claim})
		y += 88.0
	var close_btn := Button.new()
	close_btn.text = "닫기"; close_btn.position = Vector2(150, 632); close_btn.size = Vector2(240, 40)
	close_btn.add_theme_font_size_override("font_size", 19)
	_style_button(close_btn)
	close_btn.pressed.connect(func() -> void: mission_overlay.visible = false)
	mission_overlay.add_child(close_btn)


func _open_missions() -> void:
	_ensure_missions()
	_refresh_mission_rows()
	mission_overlay.visible = true
	if kfont != null:
		_apply_font_to(mission_overlay)


func _refresh_mission_rows() -> void:
	for i in range(3):
		if i >= missions.size():
			continue
		var st := _mission_state(missions[i])
		var pdef: Dictionary = st["def"]
		var amt: int = st["amt"]
		var label: String = pdef["text"] % (_fmt(amt) if pdef["type"] == "gold" else amt)
		var row: Dictionary = mission_rows[i]
		row["desc"].text = label
		row["fill"].size.x = 240.0 * (float(st["cur"]) / float(amt))
		row["prog"].text = "%d/%d" % [st["cur"], amt] if pdef["type"] != "gold" else ""
		var reward := GameData.mission_reward(pdef, stage)
		row["claim"].text = ("받기 +%s" % _fmt(reward)) if st["done"] else "진행중"
		row["claim"].disabled = not st["done"]


func _claim_mission(i: int) -> void:
	if i >= missions.size():
		return
	var st := _mission_state(missions[i])
	if not st["done"]:
		return
	_play("level_up")
	gold += GameData.mission_reward(st["def"], stage)
	missions.remove_at(i)
	_ensure_missions()
	_update_hud()
	_update_growth_buttons()
	_refresh_mission_badge()
	_refresh_mission_rows()
	_save()


# ── 일일 보상 ────────────────────────────────────────────────────
func _check_daily() -> void:
	var today := int(Time.get_unix_time_from_system()) / 86400
	if today <= daily_day:
		return
	daily_streak = (daily_streak + 1) if today == daily_day + 1 else 1
	daily_day = today
	var reward := GameData.daily_reward(stage, daily_streak)
	gold += reward
	_update_hud()
	_update_growth_buttons()
	_save()
	_show_reward("일일 보상", "%d일 연속 접속!\n\n골드 +%s" % [daily_streak, _fmt(reward)])
	busy = true
	await get_tree().create_timer(2.2).timeout
	reward_overlay.visible = false
	busy = false


# ── 업적(영구 보상) ──────────────────────────────────────────────
func _ach_value(stat: String) -> int:
	match stat:
		"max_stage": return max_stage_cleared
		"prestige": return prestige_count
		_: return int(counters.get(stat, 0))


func _recompute_ach_mult() -> void:
	var m := 1.0
	for a in GameData.ACHIEVEMENTS:
		if achieved.has(a["id"]):
			m += float(a["bonus"])
	ach_mult = m


func _check_achievements() -> void:
	var changed := false
	for a in GameData.ACHIEVEMENTS:
		if achieved.has(a["id"]):
			continue
		if _ach_value(a["stat"]) >= int(a["target"]):
			achieved.append(a["id"])
			changed = true
			_flash_notice("업적 달성!  %s\n전투력·골드 +%d%%" % [a["name"], int(round(float(a["bonus"]) * 100))])
	if changed:
		_recompute_ach_mult()
		_recompute_stats()
		_update_hud()
		_update_growth_buttons()


func _save_shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/shot_%s.png" % [SHOT_DIR, tag])
	print("[SHOT] ", tag)


# ── 배경 ─────────────────────────────────────────────────────────
var bg_layer: TextureRect

# 지역에 맞는 던전 배경 이미지로 교체한다.
func _update_sky() -> void:
	if bg_layer == null:
		return
	var ri := 0
	for i in range(GameData.REGIONS.size()):
		if stage <= int(GameData.REGIONS[i]["end"]):
			ri = i; break
		ri = i
	var name := "bg_dungeon" if ri == 0 else "bg_dungeon%d" % (ri + 1)
	var tex := _load_gen(name)
	if tex != null:
		bg_layer.texture = tex


func _load_gen(name: String) -> Texture2D:
	var path := "res://assets/gen/%s.png" % name
	if ResourceLoader.exists(path):
		return load(path)
	return null

var _add_mat: CanvasItemMaterial
func _get_add_mat() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat

func _gen_sprite(name: String, pos: Vector2, modulate := Color.WHITE) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _load_gen(name)
	s.position = pos
	s.modulate = modulate
	return s

# 빛 글로우(가산 혼합 → 진짜 광원처럼 빛난다).
func _light(pos: Vector2, scale: float, color: Color) -> Sprite2D:
	var s := _gen_sprite("glow", pos, color)
	if s.texture != null:
		s.material = _get_add_mat()
		s.scale = Vector2(scale, scale)
	return s

func _build_background() -> void:
	# 던전 배경(Kenney 타일로 합성한 벽·바닥·횃불)
	var base := ColorRect.new()
	base.color = Color(0.07, 0.06, 0.10)
	base.size = GameData.SCREEN
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	bg_layer = TextureRect.new()
	bg_layer.texture = _load_gen("bg_dungeon")
	bg_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg_layer.size = GameData.SCREEN
	bg_layer.modulate = Color(0.96, 0.96, 0.97)   # 밝은 SD 배경 → 거의 풀 밝기
	bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_layer)

	# 배경 위 아주 옅은 스크림(캐릭터 발치 대비만)
	var scrim := ColorRect.new()
	scrim.color = Color(0.0, 0.0, 0.05, 0.06)
	scrim.size = GameData.SCREEN
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	# 벽 횃불 광원(따뜻한 주황, 흔들림)
	for tx in [120.0, 424.0]:
		var glow := _light(Vector2(tx, 318), 1.1, Color(1.0, 0.58, 0.25, 0.45))
		if glow.texture != null:
			add_child(glow)
			var tw := create_tween().set_loops()
			tw.tween_property(glow, "modulate:a", 0.30, 0.9).set_trans(Tween.TRANS_SINE)
			tw.tween_property(glow, "modulate:a", 0.52, 1.1).set_trans(Tween.TRANS_SINE)
	# 바닥 전투 영역 따뜻한 광원(보라 제거 → 횃불빛 톤, 캐릭터 접지·가독)
	var floor_light := _light(Vector2(GameData.SCREEN.x * 0.5, GROUND_Y - 30), 2.2, Color(0.95, 0.62, 0.34, 0.15))
	if floor_light.texture != null:
		add_child(floor_light)



# 화면 가장자리를 어둡게(분위기). 비전투 표시라 입력 통과, UI 패널보다 아래.
func _build_vignette() -> void:
	var tex := _load_gen("vignette")
	if tex == null:
		return
	var v := TextureRect.new()
	v.texture = tex
	v.position = Vector2.ZERO
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)


# 타격·처치 순간 잔불이 튀는 버스트(한 번 터지고 사라짐).
func _spawn_hit_burst(pos: Vector2, color: Color, amount: int) -> void:
	var tex := _load_gen("ember")
	if tex == null:
		return
	var p := CPUParticles2D.new()
	p.texture = tex
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.5
	p.direction = Vector2(-1, -0.3)
	p.spread = 70.0
	p.gravity = Vector2(0, 240)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 200.0
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.6
	p.color = color
	add_child(p)
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)


# ── 전투 영역(캐릭터·진행) ───────────────────────────────────────
func _build_battle_area() -> void:
	lbl_progress = _new_label("", 22, COL_TEXT)
	lbl_progress.position = Vector2(0, 150)
	lbl_progress.size = Vector2(GameData.SCREEN.x, 30)
	lbl_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl_progress)

	hero = _make_hero()
	hero.position = Vector2(HERO_X, GROUND_Y)
	add_child(hero)
	# 영웅 체력 바
	var hbg := ColorRect.new()
	hbg.color = Color(0, 0, 0, 0.6)
	hbg.size = Vector2(86, 11)
	hbg.position = Vector2(HERO_X - 43, GROUND_Y - 150)
	hbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbg)
	hero_hp_fill = ColorRect.new()
	hero_hp_fill.color = COL_HP
	hero_hp_fill.size = Vector2(82, 7)
	hero_hp_fill.position = Vector2(HERO_X - 41, GROUND_Y - 148)
	hero_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hero_hp_fill)
	var hname := _new_label("균열기사", 16, COL_DIM)
	hname.position = Vector2(HERO_X - 60, GROUND_Y - 172)
	hname.size = Vector2(120, 20)
	hname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hname)

	# 영웅 가벼운 호흡(상하 흔들림)
	var tw := create_tween().set_loops()
	tw.tween_property(hero, "position:y", GROUND_Y - 4.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(hero, "position:y", GROUND_Y, 1.0).set_trans(Tween.TRANS_SINE)


# ── 상단 HUD ─────────────────────────────────────────────────────
func _build_hud() -> void:
	var panel := _new_panel(Rect2(8, 8, 524, 128), COL_PANEL)
	add_child(panel)

	var title := _new_label(GameData.GAME_TITLE, 26, COL_GOLD)
	title.position = Vector2(22, 14)
	add_child(title)

	lbl_stage = _new_label("", 18, COL_TEXT)
	lbl_stage.position = Vector2(180, 20)
	lbl_stage.size = Vector2(280, 24)
	lbl_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(lbl_stage)

	# 설정(톱니) 버튼
	var gear := Button.new()
	gear.text = "⚙"
	gear.position = Vector2(478, 12)
	gear.size = Vector2(46, 38)
	gear.add_theme_font_size_override("font_size", 22)
	_style_button(gear)
	gear.pressed.connect(func() -> void:
		_play("button")
		_open_settings())
	add_child(gear)

	var coin := _icon_sprite("icon_gold", Vector2(32, 66), 28)
	if coin != null:
		add_child(coin)
	lbl_gold = _new_label("", 22, COL_GOLD)
	lbl_gold.position = Vector2(52, 54)
	add_child(lbl_gold)

	lbl_level = _new_label("", 22, COL_TEXT)
	lbl_level.position = Vector2(300, 54)
	lbl_level.size = Vector2(160, 26)
	lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(lbl_level)

	lbl_souls = _new_label("", 15, COL_CRYSTAL)
	lbl_souls.position = Vector2(180, 82)
	lbl_souls.size = Vector2(330, 18)
	lbl_souls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(lbl_souls)

	var exp_bg := ColorRect.new()
	exp_bg.color = Color(0, 0, 0, 0.45)
	exp_bg.size = Vector2(500, 13)
	exp_bg.position = Vector2(20, 108)
	exp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(exp_bg)
	exp_fill = ColorRect.new()
	exp_fill.color = COL_EXP
	exp_fill.size = Vector2(0, 9)
	exp_fill.position = Vector2(22, 110)
	exp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(exp_fill)


# ── 하단 성장 패널 ───────────────────────────────────────────────
func _build_growth_panel() -> void:
	var panel := _new_panel(Rect2(8, 648, 524, 304), COL_PANEL)
	add_child(panel)
	var head := _new_label("성장", 20, COL_GOLD)
	head.position = Vector2(22, 656)
	add_child(head)

	mission_btn = Button.new()
	mission_btn.text = "임무"
	mission_btn.position = Vector2(228, 652)
	mission_btn.size = Vector2(132, 34)
	mission_btn.add_theme_font_size_override("font_size", 18)
	_style_button(mission_btn)
	mission_btn.pressed.connect(func() -> void:
		_play("button")
		_open_missions())
	add_child(mission_btn)

	var prestige_btn := Button.new()
	prestige_btn.text = "◆ 환생"
	prestige_btn.position = Vector2(372, 652)
	prestige_btn.size = Vector2(144, 34)
	prestige_btn.add_theme_font_size_override("font_size", 18)
	_style_button(prestige_btn)
	prestige_btn.pressed.connect(func() -> void:
		_play("button")
		_open_prestige())
	add_child(prestige_btn)

	var y := 692.0
	for udef in GameData.UPGRADES:
		_make_upgrade_row(udef, y)
		y += 50.0


func _make_upgrade_row(udef: Dictionary, y: float) -> void:
	var id: String = udef["id"]
	var panel := _new_panel(Rect2(16, y, 508, 44), COL_PANEL_HI)
	add_child(panel)
	var ic := _icon_sprite("icon_" + id, Vector2(38, y + 22), 30)
	if ic != null:
		add_child(ic)
	var name_lbl := _new_label("", 18, COL_TEXT)
	name_lbl.position = Vector2(62, y + 9)
	add_child(name_lbl)
	var value_lbl := _new_label("", 17, COL_DIM)
	value_lbl.position = Vector2(180, y + 10)
	value_lbl.size = Vector2(180, 24)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(value_lbl)
	var cost_lbl := _new_label("", 18, COL_GOLD)
	cost_lbl.position = Vector2(366, y + 9)
	cost_lbl.size = Vector2(140, 26)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(cost_lbl)
	var btn := Button.new()
	btn.flat = true
	btn.position = Vector2(16, y)
	btn.size = Vector2(508, 44)
	btn.pressed.connect(_on_upgrade_pressed.bind(id))
	add_child(btn)
	up_rows[id] = {"panel": panel, "name": name_lbl, "value": value_lbl, "cost": cost_lbl, "button": btn}


# ── 액티브 스킬 ──────────────────────────────────────────────────
func _build_skills() -> void:
	# 좌측 세로 스택(영웅 왼편 빈 공간 — 우측 적·중앙 영웅과 안 겹침)
	smash_btn = _make_skill_btn("강타", Vector2(14, 452), _use_smash)
	haste_btn = _make_skill_btn("가속", Vector2(14, 522), _use_haste)
	_build_challenge_ui()


# 보스 게이트 도전 UI: 큰 '보스 도전' 버튼 + 자동 도전 토글.
func _build_challenge_ui() -> void:
	challenge_btn = Button.new()
	challenge_btn.text = "⚔  보스 도전"
	challenge_btn.position = Vector2(110, 250)
	challenge_btn.size = Vector2(320, 64)
	challenge_btn.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.16, 0.20, 0.96); sb.set_corner_radius_all(16)
	sb.border_color = COL_GOLD; sb.set_border_width_all(3)
	var pr := sb.duplicate(); pr.bg_color = Color(0.70, 0.22, 0.26)
	challenge_btn.add_theme_stylebox_override("normal", sb)
	challenge_btn.add_theme_stylebox_override("hover", sb)
	challenge_btn.add_theme_stylebox_override("pressed", pr)
	challenge_btn.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	challenge_btn.pressed.connect(func() -> void:
		_play("button"); _btn_pop(challenge_btn); _start_boss_challenge())
	challenge_btn.visible = false
	add_child(challenge_btn)

	auto_btn = Button.new()
	auto_btn.position = Vector2(150, 322); auto_btn.size = Vector2(240, 40)
	auto_btn.add_theme_font_size_override("font_size", 18)
	_style_button(auto_btn)
	auto_btn.pressed.connect(func() -> void:
		auto_boss = not auto_boss
		_refresh_auto_btn()
		_save()
		if auto_boss and challenge_btn.visible and not boss_active:
			_start_boss_challenge())
	auto_btn.visible = false
	add_child(auto_btn)
	_refresh_auto_btn()


func _refresh_auto_btn() -> void:
	if auto_btn != null:
		auto_btn.text = "자동 도전: 켜짐" if auto_boss else "자동 도전: 꺼짐"


func _show_challenge(on: bool) -> void:
	if challenge_btn == null:
		return
	challenge_btn.visible = on
	auto_btn.visible = on


func _start_boss_challenge() -> void:
	if boss_active or not GameData.is_boss_stage(stage) or busy:
		return
	boss_active = true
	_show_challenge(false)
	_boss_intro()
	_spawn_enemy()


# 보스 도전 컷: 초상화가 확 떠오르며 보스 이름 표시(1.3초, 비차단).
func _boss_intro() -> void:
	var bdef := GameData.make_enemy(stage)
	var bname: String = bdef.get("name", "보스")
	var bsprite: String = bdef.get("sprite", "")
	# 그 보스에 맞는 전용 초상화가 있을 때만 사용(이름과 안 맞는 그림 금지)
	var port_path := "res://assets/ui/portrait_%s.png" % bsprite
	var has_portrait := ResourceLoader.exists(port_path)
	var ov := Control.new(); ov.size = GameData.SCREEN
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ov)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0); dim.size = GameData.SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(dim)
	var name_y := 520.0
	if has_portrait:
		var port := TextureRect.new()
		port.texture = load(port_path)
		port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		port.size = Vector2(340, 340)
		port.position = Vector2(GameData.SCREEN.x * 0.5 - 170, 168)
		port.pivot_offset = Vector2(170, 170)
		port.scale = Vector2(0.6, 0.6)
		port.modulate = Color(1, 1, 1, 0)
		port.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ov.add_child(port)
		var ptw := create_tween()
		ptw.tween_property(port, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ptw.parallel().tween_property(port, "modulate", Color(1, 1, 1, 1), 0.25)
	else:
		name_y = 360.0   # 초상화 없으면 이름 배너를 가운데로
	var head := _new_label("⚔  보스 등장", 24, COL_GOLD)
	head.position = Vector2(0, name_y - 46); head.size = Vector2(GameData.SCREEN.x, 30)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.modulate = Color(1, 1, 1, 0)
	ov.add_child(head)
	var nm := _new_label("[보스]  " + bname, 32, COL_HP_BOSS)
	nm.position = Vector2(0, name_y); nm.size = Vector2(GameData.SCREEN.x, 44)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.modulate = Color(1, 1, 1, 0)
	ov.add_child(nm)
	if kfont != null:
		_apply_font_to(ov)
	_play("boss_appear")
	var tw := create_tween()
	tw.tween_property(dim, "color", Color(0.12, 0.0, 0.02, 0.6), 0.2)
	tw.parallel().tween_property(nm, "modulate", Color(1, 1, 1, 1), 0.3)
	tw.parallel().tween_property(head, "modulate", Color(1, 1, 1, 1), 0.3)
	tw.tween_interval(0.55)
	tw.tween_property(ov, "modulate", Color(1, 1, 1, 0), 0.35)
	tw.parallel().tween_property(dim, "color", Color(0, 0, 0, 0), 0.35)
	tw.tween_callback(ov.queue_free)


func _make_skill_btn(label: String, pos: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = Vector2(60, 60)
	b.text = label
	b.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.20, 0.26, 0.96)
	sb.set_corner_radius_all(30)
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	var pressed := sb.duplicate(); pressed.bg_color = Color(0.28, 0.31, 0.38)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", sb)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.48, 0.58))
	b.pressed.connect(cb)
	add_child(b)
	return b


func _use_smash() -> void:
	if smash_cd > 0 or enemy.is_empty() or enemy.get("dying", false):
		return
	_btn_pop(smash_btn)
	smash_cd = SMASH_CD * p_cd_scale
	var dmg := int(round(p_atk * 8.0))
	enemy["hp"] = int(enemy["hp"]) - dmg
	_play("crit")
	_hitstop(0.08)
	_screen_flash(Color(1.0, 0.85, 0.3, 0.25))
	var hp := Vector2(ENEMY_X - enemy["r"] * 0.4, GROUND_Y - enemy["r"])
	_slash_fx(hp, true); _slash_fx(hp + Vector2(0, -10), true)
	_spawn_hit_burst(hp, Color(1.0, 0.8, 0.3, 0.95), 20)
	_float_text(Vector2(ENEMY_X, GROUND_Y - enemy["r"] * 2.0 - 6), str(dmg), Color(1.0, 0.7, 0.2), true)
	_update_enemy_hp()
	if int(enemy["hp"]) <= 0:
		_enemy_die()


func _use_haste() -> void:
	if haste_cd > 0:
		return
	_btn_pop(haste_btn)
	haste_cd = HASTE_CD * p_cd_scale
	haste_timer = HASTE_DUR
	_play("level_up")
	_flash_notice("가속!")
	if is_instance_valid(hero):
		hero.modulate = Color(1.4, 1.4, 1.8)


func _update_skill_buttons() -> void:
	if smash_btn == null:
		return
	smash_btn.text = "강타" if smash_cd <= 0 else "%d" % ceil(smash_cd)
	smash_btn.disabled = smash_cd > 0
	if haste_timer > 0:
		haste_btn.text = "%d" % ceil(haste_timer); haste_btn.disabled = true
	elif haste_cd > 0:
		haste_btn.text = "%d" % ceil(haste_cd); haste_btn.disabled = true
	else:
		haste_btn.text = "가속"; haste_btn.disabled = false


func _build_notice() -> void:
	notice = _new_label("", 30, COL_GOLD)
	notice.position = Vector2(0, 300)
	notice.size = Vector2(GameData.SCREEN.x, 50)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.visible = false
	add_child(notice)


# ── 보상 오버레이 ────────────────────────────────────────────────
func _build_reward_overlay() -> void:
	reward_overlay = Control.new()
	reward_overlay.size = GameData.SCREEN
	reward_overlay.visible = false
	ui_layer.add_child(reward_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = GameData.SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_overlay.add_child(dim)
	var box := _new_panel(Rect2(50, 330, 440, 300), COL_PANEL_HI)
	reward_overlay.add_child(box)
	reward_title = _new_label("", 34, COL_GOLD)
	reward_title.position = Vector2(50, 360)
	reward_title.size = Vector2(440, 44)
	reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_overlay.add_child(reward_title)
	reward_body = _new_label("", 22, COL_TEXT)
	reward_body.position = Vector2(74, 420)
	reward_body.size = Vector2(392, 190)
	reward_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_overlay.add_child(reward_body)


func _build_settings_overlay() -> void:
	settings_overlay = Control.new()
	settings_overlay.size = GameData.SCREEN
	settings_overlay.visible = false
	ui_layer.add_child(settings_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = GameData.SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_overlay.add_child(dim)
	var box := _new_panel(Rect2(60, 170, 420, 620), COL_PANEL_HI)
	settings_overlay.add_child(box)
	var t := _new_label("설정 · 자동화", 28, COL_GOLD)
	t.position = Vector2(60, 190)
	t.size = Vector2(420, 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_overlay.add_child(t)

	_settings_toggle(244, "사운드",
		func() -> bool: return sound_on,
		func(v: bool) -> void: _set_sound(v))
	_settings_toggle(304, "자동 강화",
		func() -> bool: return auto_upgrade,
		func(v: bool) -> void: auto_upgrade = v)
	_settings_toggle(364, "자동 스킬",
		func() -> bool: return auto_skill,
		func(v: bool) -> void: auto_skill = v)
	_settings_toggle(424, "자동 환생",
		func() -> bool: return auto_prestige,
		func(v: bool) -> void: auto_prestige = v)

	var ach_btn := Button.new()
	ach_btn.text = "업적"
	ach_btn.position = Vector2(110, 492); ach_btn.size = Vector2(320, 52)
	ach_btn.add_theme_font_size_override("font_size", 21)
	_style_button(ach_btn)
	ach_btn.pressed.connect(func() -> void: _play("button"); _open_achievements())
	settings_overlay.add_child(ach_btn)

	var reset_btn := Button.new()
	reset_btn.text = "진행 초기화"
	reset_btn.position = Vector2(110, 560)
	reset_btn.size = Vector2(320, 50)
	reset_btn.add_theme_font_size_override("font_size", 20)
	_style_button(reset_btn)
	var confirming := {"v": false}
	reset_btn.pressed.connect(func() -> void:
		if not confirming["v"]:
			confirming["v"] = true
			reset_btn.text = "정말 초기화? 한 번 더"
		else:
			_reset_progress()
			confirming["v"] = false
			reset_btn.text = "진행 초기화"
			settings_overlay.visible = false)
	settings_overlay.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.position = Vector2(110, 624)
	close_btn.size = Vector2(320, 48)
	close_btn.add_theme_font_size_override("font_size", 20)
	_style_button(close_btn)
	close_btn.pressed.connect(func() -> void:
		confirming["v"] = false
		reset_btn.text = "진행 초기화"
		settings_overlay.visible = false)
	settings_overlay.add_child(close_btn)


var ach_overlay: Control
var ach_vbox: VBoxContainer
var ach_summary: Label

func _build_achievements_overlay() -> void:
	ach_overlay = Control.new()
	ach_overlay.size = GameData.SCREEN
	ach_overlay.visible = false
	ui_layer.add_child(ach_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72); dim.size = GameData.SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ach_overlay.add_child(dim)
	var box := _new_panel(Rect2(34, 110, 472, 740), COL_PANEL_HI)
	ach_overlay.add_child(box)
	var t := _new_label("업적", 30, COL_GOLD)
	t.position = Vector2(34, 130); t.size = Vector2(472, 38)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ach_overlay.add_child(t)
	ach_summary = _new_label("", 17, COL_DIM)
	ach_summary.position = Vector2(34, 170); ach_summary.size = Vector2(472, 24)
	ach_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ach_overlay.add_child(ach_summary)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(52, 204); scroll.size = Vector2(436, 568)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ach_overlay.add_child(scroll)
	ach_vbox = VBoxContainer.new()
	ach_vbox.custom_minimum_size = Vector2(432, 0)
	ach_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(ach_vbox)
	var close_btn := Button.new()
	close_btn.text = "닫기"; close_btn.position = Vector2(116, 788); close_btn.size = Vector2(308, 46)
	close_btn.add_theme_font_size_override("font_size", 19)
	_style_button(close_btn)
	close_btn.pressed.connect(func() -> void: ach_overlay.visible = false)
	ach_overlay.add_child(close_btn)


func _open_achievements() -> void:
	for c in ach_vbox.get_children():
		c.queue_free()
	for a in GameData.ACHIEVEMENTS:
		var done: bool = achieved.has(a["id"])
		var cur: int = _ach_value(a["stat"])
		var tgt: int = int(a["target"])
		var row := Panel.new()
		row.custom_minimum_size = Vector2(424, 58)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.20, 0.17, 0.30, 0.96) if done else Color(0.12, 0.11, 0.18, 0.96)
		sb.set_corner_radius_all(10)
		sb.border_color = COL_GOLD if done else COL_BORDER
		sb.set_border_width_all(2)
		row.add_theme_stylebox_override("panel", sb)
		var nm := _new_label(("✓ " if done else "") + a["name"], 18, COL_GOLD if done else COL_TEXT)
		nm.position = Vector2(14, 7); row.add_child(nm)
		var sub := _new_label("", 14, COL_DIM)
		if done:
			sub.text = "달성 · 전투력·골드 +%d%%" % int(round(float(a["bonus"]) * 100))
		else:
			sub.text = "%s / %s   (+%d%%)" % [_fmt(mini(cur, tgt)), _fmt(tgt), int(round(float(a["bonus"]) * 100))]
		sub.position = Vector2(14, 32); row.add_child(sub)
		ach_vbox.add_child(row)
	ach_summary.text = "달성 %d / %d   ·   현재 보너스 +%d%%" % [achieved.size(), GameData.ACHIEVEMENTS.size(), int(round((ach_mult - 1.0) * 100))]
	ach_overlay.visible = true
	if kfont != null:
		_apply_font_to(ach_overlay)


var settings_toggles := []

func _settings_toggle(y: float, label: String, getter: Callable, setter: Callable) -> void:
	var b := Button.new()
	b.position = Vector2(110, y); b.size = Vector2(320, 52)
	b.add_theme_font_size_override("font_size", 21)
	_style_button(b)
	b.text = "%s: %s" % [label, "켜짐" if getter.call() else "꺼짐"]
	b.pressed.connect(func() -> void:
		setter.call(not getter.call())
		b.text = "%s: %s" % [label, "켜짐" if getter.call() else "꺼짐"]
		_play("button")
		_save())
	settings_toggles.append({"b": b, "label": label, "get": getter})
	settings_overlay.add_child(b)


func _open_settings() -> void:
	for tg in settings_toggles:
		tg["b"].text = "%s: %s" % [tg["label"], "켜짐" if tg["get"].call() else "꺼짐"]
	settings_overlay.visible = true


# ── 환생(프레스티지) + 균열석 상점 오버레이 ──────────────────────
var soul_rows := {}
var prestige_confirming := false

func _build_prestige_overlay() -> void:
	prestige_overlay = Control.new()
	prestige_overlay.size = GameData.SCREEN
	prestige_overlay.visible = false
	ui_layer.add_child(prestige_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = GameData.SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	prestige_overlay.add_child(dim)
	var box := _new_panel(Rect2(28, 92, 484, 770), COL_PANEL_HI)
	prestige_overlay.add_child(box)
	var t := _new_label("환생 · 균열석 상점", 28, COL_CRYSTAL)
	t.position = Vector2(28, 108)
	t.size = Vector2(484, 38)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prestige_overlay.add_child(t)
	prestige_body = _new_label("", 18, COL_TEXT)
	prestige_body.position = Vector2(44, 150)
	prestige_body.size = Vector2(452, 28)
	prestige_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prestige_overlay.add_child(prestige_body)

	# 균열석 상점(영구 강화, 환생해도 유지) — 6행
	var y := 192.0
	for udef in GameData.SOUL_UPGRADES:
		_make_soul_row(udef, y)
		y += 58.0

	var div := _new_label("— 환생하면 균열석을 얻고 진행은 초기화됩니다 —", 15, COL_DIM)
	div.position = Vector2(28, 546)
	div.size = Vector2(484, 22)
	div.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prestige_overlay.add_child(div)

	prestige_do_btn = Button.new()
	prestige_do_btn.position = Vector2(64, 578)
	prestige_do_btn.size = Vector2(412, 58)
	prestige_do_btn.add_theme_font_size_override("font_size", 22)
	_style_button(prestige_do_btn)
	prestige_do_btn.pressed.connect(func() -> void:
		var gain := GameData.souls_for(max_stage_cleared)
		if gain <= 0:
			return
		if not prestige_confirming:
			prestige_confirming = true
			prestige_do_btn.text = "정말 환생? 한 번 더 누르기"
		else:
			prestige_confirming = false
			_play("prestige")
			_do_prestige(gain)
			prestige_overlay.visible = false)
	prestige_overlay.add_child(prestige_do_btn)

	var pclose_btn := Button.new()
	pclose_btn.text = "닫기"
	pclose_btn.position = Vector2(64, 648)
	pclose_btn.size = Vector2(412, 46)
	pclose_btn.add_theme_font_size_override("font_size", 19)
	_style_button(pclose_btn)
	pclose_btn.pressed.connect(func() -> void:
		prestige_confirming = false
		prestige_overlay.visible = false)
	prestige_overlay.add_child(pclose_btn)


func _make_soul_row(udef: Dictionary, y: float) -> void:
	var id: String = udef["id"]
	var panel := _new_panel(Rect2(50, y, 440, 54), COL_PANEL)
	prestige_overlay.add_child(panel)
	var name_lbl := _new_label("", 18, COL_TEXT)
	name_lbl.position = Vector2(66, y + 7)
	prestige_overlay.add_child(name_lbl)
	var eff_lbl := _new_label("", 14, COL_DIM)
	eff_lbl.position = Vector2(66, y + 30)
	prestige_overlay.add_child(eff_lbl)
	var cost_lbl := _new_label("", 18, COL_CRYSTAL)
	cost_lbl.position = Vector2(300, y + 16)
	cost_lbl.size = Vector2(174, 24)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prestige_overlay.add_child(cost_lbl)
	var btn := Button.new()
	btn.flat = true
	btn.position = Vector2(50, y)
	btn.size = Vector2(440, 54)
	btn.pressed.connect(_on_soul_pressed.bind(id))
	prestige_overlay.add_child(btn)
	soul_rows[id] = {"panel": panel, "name": name_lbl, "eff": eff_lbl, "cost": cost_lbl, "button": btn}


func _on_soul_pressed(id: String) -> void:
	var udef := GameData.soul_upgrade_def(id)
	var cost := GameData.soul_upgrade_cost(udef, _soul_lv(id))
	if souls < cost:
		return
	_play("button")
	souls -= cost
	soul_upgrades[id] = _soul_lv(id) + 1
	_recompute_stats()
	p_hp = mini(p_hp + 0, p_max_hp)
	_save()
	_update_hud()
	_update_growth_buttons()
	_open_prestige()   # 상점 표시 갱신


func _open_prestige() -> void:
	var gain := GameData.souls_for(max_stage_cleared)
	prestige_confirming = false
	var head := "보유 균열석 ◆ %d   전투력 x%.2f · 골드 x%.2f" % [souls, p_global_mult, p_gold_mult]
	prestige_body.text = head
	for udef in GameData.SOUL_UPGRADES:
		var id: String = udef["id"]
		var lv := _soul_lv(id)
		var cost := GameData.soul_upgrade_cost(udef, lv)
		var row: Dictionary = soul_rows[id]
		row["name"].text = "%s  Lv %d" % [udef["name"], lv]
		var pct := int(round(float(udef["per"]) * 100))
		row["eff"].text = "%s +%d%% / 레벨" % [udef["desc"], pct]
		row["cost"].text = "◆ %d" % cost
		var afford := souls >= cost
		row["button"].disabled = not afford
		row["panel"].modulate = Color(1, 1, 1, 1) if afford else Color(0.6, 0.6, 0.66, 1)
	if gain > 0:
		prestige_do_btn.disabled = false
		prestige_do_btn.text = "환생하고 ◆%d 받기" % gain
	else:
		prestige_do_btn.disabled = true
		prestige_do_btn.text = "%d층 넘으면 환생 가능" % GameData.SOUL_MIN_STAGE
	prestige_overlay.visible = true
	if kfont != null:
		_apply_font_to(prestige_overlay)


func _do_prestige(gain: int) -> void:
	souls += gain
	prestige_count += 1
	last_progress_t = 0.0
	_check_achievements()
	level = 1; exp = 0; gold = 0
	upgrades = {"atk": 0, "hp": 0, "def": 0, "crit": 0, "gold": 0}
	stage = 1; kills = 0; max_stage_cleared = 0; region_cleared = false
	_recompute_stats()
	p_hp = p_max_hp
	busy = false
	_apply_hero_skin()
	_save()
	_update_hud()
	_update_growth_buttons()
	_spawn_enemy()
	var skin_note := "  외형 승급!" if prestige_count <= 2 else ""
	_flash_notice("환생!  전투력 x%.2f%s" % [p_global_mult, skin_note])


# ── 오프라인 보상 ────────────────────────────────────────────────
func _grant_offline(s: Dictionary) -> void:
	var last := int(s.get("last_save_unix", 0))
	if last <= 0:
		return
	var elapsed: int = int(Time.get_unix_time_from_system()) - last
	if elapsed < GameData.OFFLINE_MIN_SEC:
		return
	elapsed = mini(elapsed, GameData.OFFLINE_CAP_SEC)
	var dps := float(p_atk) / p_interval * (1.0 + p_crit * (float(GameData.PLAYER_BASE["crit_mult"]) - 1.0))
	var ehp := float(GameData.enemy_hp(stage))
	var kills_per_sec: float = clampf(dps / maxf(1.0, ehp), 0.0, 3.0)
	var gold_per_sec := kills_per_sec * float(_gold_gain(GameData.enemy_gold(stage)))
	var reward := int(round(gold_per_sec * elapsed * p_off_eff))
	if reward <= 0:
		return
	gold += reward
	_update_hud()
	_update_growth_buttons()
	_save()
	var hrs := elapsed / 3600
	var mins := (elapsed % 3600) / 60
	var dur := ("%d시간 %d분" % [hrs, mins]) if hrs > 0 else ("%d분" % mins)
	_show_reward("돌아오셨군요!", "자리를 비운 %s 동안\n부하들이 사냥했습니다.\n\n골드 +%s" % [dur, _fmt(reward)])
	busy = true
	await get_tree().create_timer(2.4).timeout
	reward_overlay.visible = false
	busy = false


# ── 사운드 ───────────────────────────────────────────────────────
var bgm_player: AudioStreamPlayer

func _setup_audio() -> void:
	for name in ["slash", "hit", "crit", "level_up", "boss_appear", "boss_victory", "button", "prestige"]:
		var path := "res://assets/gen_sfx/%s.wav" % name
		if ResourceLoader.exists(path):
			sfx_streams[name] = load(path)
	for i in range(6):
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
	# 배경음(루프). 첫 사용자 입력 후 재생되도록 _ready 끝에서 시작.
	var bgm_path := "res://assets/gen_bgm/theme.wav"
	if ResourceLoader.exists(bgm_path):
		var s = load(bgm_path)
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = s.data.size() / 2   # 16-bit 모노 샘플 수
		bgm_player = AudioStreamPlayer.new()
		bgm_player.stream = s
		bgm_player.volume_db = -16.0
		add_child(bgm_player)
		# 재생은 첫 입력(_unlock_audio)에서 시작 — iOS/브라우저 자동재생 차단 대응

const SFX_VOL := {
	"slash": -13.0, "hit": -11.0, "crit": -7.0, "level_up": -6.0,
	"boss_appear": -5.0, "boss_victory": -4.0, "button": -12.0, "prestige": -6.0,
}

func _play(name: String) -> void:
	if name == "" or not sound_on or sfx_players.is_empty():
		return
	var stream = sfx_streams.get(name, null)
	if stream == null:
		return
	var pl: AudioStreamPlayer = sfx_players[sfx_next]
	sfx_next = (sfx_next + 1) % sfx_players.size()
	pl.stream = stream
	pl.volume_db = float(SFX_VOL.get(name, -8.0))
	pl.play()


var _audio_unlocked := false

# 브라우저/iOS는 사용자 입력 전 오디오를 막는다. 첫 탭에서 오디오를 깨우고 BGM을 시작한다.
func _input(event: InputEvent) -> void:
	if _audio_unlocked:
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_audio_unlocked = true
		if sound_on and bgm_player != null and not bgm_player.playing:
			bgm_player.play()


func _set_sound(on: bool) -> void:
	sound_on = on
	if bgm_player != null:
		if on and _audio_unlocked:
			bgm_player.play()
		elif not on:
			bgm_player.stop()


# ── 캐릭터 생성(도형 조합) ───────────────────────────────────────
# 바닥 그림자 스프라이트(글로우 텍스처를 눌러 타원 그림자로 사용).
func _shadow(width: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _load_gen("glow")
	s.position = Vector2(0, -4)
	s.modulate = Color(0, 0, 0, 0.33)
	if s.texture != null:
		s.scale = Vector2(width / 256.0, width / 256.0 * 0.32)
	return s


# 16px 픽셀 스프라이트를 또렷하게(nearest) 표시. 발 바닥이 y=0에 오도록 정렬.
var _outline_mat: ShaderMaterial

# 픽셀 스프라이트용 1px 외곽선 셰이더(배경에서 캐릭터를 분리).
func _get_outline_mat() -> ShaderMaterial:
	if _outline_mat != null:
		return _outline_mat
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(0.04, 0.03, 0.06, 1.0);
uniform float width = 1.2;
void fragment() {
	vec2 px = width / vec2(textureSize(TEXTURE, 0));
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.3) {
		COLOR = c * COLOR;
	} else {
		float a = 0.0;
		a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV + px).a);
		a = max(a, texture(TEXTURE, UV - px).a);
		COLOR = vec4(outline_color.rgb, outline_color.a * step(0.3, a) * COLOR.a);
	}
}
"""
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = sh
	return _outline_mat


const ANIM_STATES := ["idle", "attack", "hit", "death"]

# 캐릭터 비주얼 노드: 애니 시트가 있으면 AnimatedSprite2D, 없으면 정적 Sprite2D(SD 또는 픽셀).
func _make_char(name: String, disp_h: float, tint := Color.WHITE) -> CanvasItem:
	var anim := _build_anim(name, disp_h, tint)
	if anim != null:
		return anim
	return _char_sprite(name, disp_h, tint)


# 가로 스프라이트 시트(정사각 셀)들로 AnimatedSprite2D 구성. 발 바닥 접지·스케일·idle 재생.
func _build_anim(name: String, disp_h: float, tint := Color.WHITE) -> AnimatedSprite2D:
	var any := false
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var ref_used := Rect2()
	for st in ANIM_STATES:
		var path := "res://assets/sd/anim/%s_%s.png" % [name, st]
		if not ResourceLoader.exists(path):
			continue
		var sheet: Texture2D = load(path)
		var ch: int = sheet.get_height()
		var n: int = maxi(1, int(sheet.get_width() / float(ch)))
		sf.add_animation(st)
		sf.set_animation_loop(st, st == "idle")
		sf.set_animation_speed(st, 10.0)
		for i in range(n):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * ch, 0, ch, ch)
			sf.add_frame(st, at)
		if not any:   # 첫 시트의 첫 셀로 접지 기준 산출
			ref_used = sheet.get_image().get_region(Rect2(0, 0, ch, ch)).get_used_rect()
		any = true
	if not any:
		return null
	var asp := AnimatedSprite2D.new()
	asp.sprite_frames = sf
	asp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	asp.modulate = tint
	asp.centered = false
	var ch2: float = maxf(1.0, ref_used.size.y)
	var sc := disp_h / ch2
	asp.scale = Vector2(sc, sc)
	asp.offset = Vector2(-(ref_used.position.x + ref_used.size.x * 0.5), -(ref_used.position.y + ref_used.size.y))
	var first := "idle"
	if not sf.has_animation("idle"):
		for s in ANIM_STATES:
			if sf.has_animation(s):
				first = s
				break
	asp.play(first)
	asp.animation_finished.connect(_on_char_anim_done.bind(asp))
	return asp


# 원샷(attack/hit) 끝나면 idle 복귀. death는 마지막 프레임 유지.
func _on_char_anim_done(asp: AnimatedSprite2D) -> void:
	if not is_instance_valid(asp):
		return
	var a := asp.animation
	if (a == "attack" or a == "hit") and asp.sprite_frames.has_animation("idle"):
		asp.play("idle")


# 비주얼 노드에 상태 애니 재생(없으면 무시).
func _play_char_anim(node: Node, state: String) -> void:
	if node is AnimatedSprite2D and is_instance_valid(node):
		if node.sprite_frames != null and node.sprite_frames.has_animation(state):
			node.play(state)


# 캐릭터 스프라이트 통합 로더(정적): SD 일러스트 우선, 없으면 픽셀.
func _char_sprite(name: String, disp_h: float, tint := Color.WHITE) -> Sprite2D:
	var sd := "res://assets/sd/%s.png" % name
	if ResourceLoader.exists(sd):
		return _illus_sprite(sd, disp_h, tint)
	return _pixel_sprite(name, disp_h, tint)


# SD 일러스트 스프라이트(부드러운 고해상). 투명 여백 제외한 '실제 그림 바닥'을 지면(y0)에 정렬 → 떠보임 방지.
func _illus_sprite(path: String, disp_h: float, tint := Color.WHITE) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.modulate = tint
	var used := s.texture.get_image().get_used_rect()   # 불투명 영역
	var ch: float = maxf(1.0, used.size.y)
	var sc := disp_h / ch                                # disp_h = 실제 캐릭터 높이
	s.scale = Vector2(sc, sc)
	s.centered = false
	# 실제 그림의 가로 중심을 x0, 바닥을 y0에 맞춘다.
	s.position = Vector2(
		-(used.position.x + used.size.x * 0.5) * sc,
		-(used.position.y + used.size.y) * sc
	)
	return s


func _pixel_sprite(name: String, disp_h: float, tint := Color.WHITE) -> Sprite2D:
	var path := "res://assets/sprites/%s.png" % name
	if not ResourceLoader.exists(path):
		return null
	var s := Sprite2D.new()
	s.texture = load(path)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.material = _get_outline_mat()
	s.modulate = tint
	var th: float = maxf(1.0, s.texture.get_height())
	var sc := disp_h / th
	s.scale = Vector2(sc, sc)
	s.centered = false
	s.position = Vector2(-s.texture.get_width() * sc * 0.5, -s.texture.get_height() * sc)
	return s


func _make_hero() -> Node2D:
	var root := Node2D.new()
	root.add_child(_shadow(140))
	# 영웅 뒤 림라이트(어두운 갑옷이 어두운 배경에 묻히지 않게 밝게 분리)
	var back := _light(Vector2(0, -56), 1.5, Color(0.85, 0.88, 1.0, 0.34))
	if back.texture != null:
		root.add_child(back)
	var hkey := _hero_skin_name()
	var hdisp := 150.0 if ResourceLoader.exists("res://assets/sd/%s.png" % hkey) else 104.0
	var vis := _make_char(hkey, hdisp)
	if vis != null:
		hero_vis = vis
		hero_anim = vis if vis is AnimatedSprite2D else null
		hero_sprite = vis if vis is Sprite2D else null
		root.add_child(vis)
		return root
	# 폴백: 절차적 도형 영웅
	return _make_hero_shapes(root)


# 환생 횟수에 따라 영웅 외형이 승급(장비 강화 느낌).
func _hero_skin_name() -> String:
	return ["hero", "hero1", "hero2"][mini(prestige_count, 2)]


func _apply_hero_skin() -> void:
	if not is_instance_valid(hero) or hero_vis == null or not is_instance_valid(hero_vis):
		return
	var hkey := _hero_skin_name()
	var hdisp := 150.0 if ResourceLoader.exists("res://assets/sd/%s.png" % hkey) else 104.0
	var ns := _make_char(hkey, hdisp)
	if ns == null:
		return
	hero_vis.queue_free()   # 외형 노드 교체(애니/정적·필터 다를 수 있어 재생성)
	hero_vis = ns
	hero_anim = ns if ns is AnimatedSprite2D else null
	hero_sprite = ns if ns is Sprite2D else null
	hero.add_child(ns)


func _make_hero_shapes(root: Node2D) -> Node2D:
	# 은은한 아우라
	var aura := _gen_sprite("glow", Vector2(0, -62), Color(0.45, 0.6, 1.0, 0.16))
	if aura.texture != null:
		aura.scale = Vector2(0.7, 0.9)
		root.add_child(aura)
	# 외곽선(살짝 큰 어두운 실루엣)
	root.add_child(_rect_poly(Vector2(-23, -81), Vector2(46, 58), Color(0.06, 0.05, 0.10)))
	# 다리
	root.add_child(_rect_poly(Vector2(-14, -28), Vector2(11, 28), Color(0.16, 0.14, 0.22)))
	root.add_child(_rect_poly(Vector2(3, -28), Vector2(11, 28), Color(0.20, 0.17, 0.26)))
	# 망토(뒤)
	root.add_child(_tri_poly(Vector2(-18, -74), Vector2(-30, -16), Vector2(-6, -22), Color(0.45, 0.18, 0.22)))
	# 몸통(갑옷) — 음영 3톤
	root.add_child(_rect_poly(Vector2(-20, -78), Vector2(40, 54), Color(0.22, 0.32, 0.60)))      # 바닥 그늘
	root.add_child(_rect_poly(Vector2(-20, -78), Vector2(40, 34), Color(0.30, 0.44, 0.78)))      # 본체
	root.add_child(_rect_poly(Vector2(-20, -78), Vector2(40, 8), Color(0.46, 0.62, 0.98)))       # 가슴 하이라이트
	root.add_child(_rect_poly(Vector2(-20, -54), Vector2(40, 5), Color(0.85, 0.72, 0.35)))       # 허리띠(금)
	# 머리 + 턱 그늘
	root.add_child(_circle_poly(Vector2(0, -92), 16, Color(0.80, 0.66, 0.52)))
	root.add_child(_circle_poly(Vector2(0, -94), 15, Color(0.93, 0.81, 0.67)))
	# 투구
	root.add_child(_rect_poly(Vector2(-16, -106), Vector2(32, 9), Color(0.58, 0.62, 0.70)))
	root.add_child(_rect_poly(Vector2(-16, -106), Vector2(32, 3), Color(0.78, 0.82, 0.90)))
	# 방패(왼쪽) — 테두리 + 면 + 문양
	root.add_child(_circle_poly(Vector2(-27, -52), 16, Color(0.30, 0.24, 0.16)))
	root.add_child(_circle_poly(Vector2(-27, -52), 13, Color(0.62, 0.50, 0.32)))
	root.add_child(_circle_poly(Vector2(-27, -52), 5, Color(0.85, 0.72, 0.40)))
	# 검(오른쪽) — 날 + 빛 모서리 + 글로우 + 가드
	root.add_child(_rect_poly(Vector2(25, -114), Vector2(8, 74), Color(0.70, 0.76, 0.86)))
	root.add_child(_rect_poly(Vector2(25, -114), Vector2(3, 74), Color(0.92, 0.96, 1.0)))
	var sw_glow := _gen_sprite("glow", Vector2(29, -118), Color(0.7, 0.85, 1.0, 0.5))
	if sw_glow.texture != null:
		sw_glow.scale = Vector2(0.18, 0.18)
		root.add_child(sw_glow)
	root.add_child(_rect_poly(Vector2(20, -44), Vector2(18, 7), Color(0.50, 0.38, 0.24)))
	return root


func _make_enemy(e: Dictionary) -> Node2D:
	var root := Node2D.new()
	var r: float = e["r"]
	var col: Color = e["color"]
	root.add_child(_shadow(r * 3.0))
	if e["boss"]:
		var ba := _light(Vector2(0, -r), r / 80.0, Color(col.r, col.g * 0.5, col.b * 0.5, 0.34))
		if ba.texture != null:
			root.add_child(ba)
	# SD 애니/일러스트(있으면) → 픽셀 → 도형. SD는 더 크게 표시.
	var ekey := String(e.get("sprite", ""))
	var has_sd := ResourceLoader.exists("res://assets/sd/%s.png" % ekey)
	var edisp := (r * 3.8) if has_sd else (r * 2.7)
	var etint: Color = Color.WHITE if has_sd else e.get("tint", Color.WHITE)
	var vis := _make_char(ekey, edisp, etint)
	if vis != null:
		enemy["anim"] = vis if vis is AnimatedSprite2D else null
		root.add_child(vis)
		return root
	# 외곽선
	root.add_child(_circle_poly(Vector2(0, -r), r + 2.5, Color(0.05, 0.04, 0.07)))
	# 몸체(아래 그늘 → 본체 → 위 하이라이트)
	root.add_child(_circle_poly(Vector2(0, -r), r, col.darkened(0.28)))
	root.add_child(_circle_poly(Vector2(0, -r * 1.04), r * 0.92, col))
	root.add_child(_circle_poly(Vector2(-r * 0.22, -r * 1.28), r * 0.42, col.lightened(0.28)))
	# 보스 뿔·가시
	if e["boss"]:
		root.add_child(_tri_poly(Vector2(-r * 0.5, -r * 1.8), Vector2(-r * 0.12, -r * 1.25), Vector2(-r * 0.72, -r * 1.22), col.darkened(0.4)))
		root.add_child(_tri_poly(Vector2(r * 0.5, -r * 1.8), Vector2(r * 0.12, -r * 1.25), Vector2(r * 0.72, -r * 1.22), col.darkened(0.4)))
	# 눈(흰자 + 동공, 왼쪽을 본다)
	var er: float = r * 0.17
	for ex in [-r * 0.34, r * 0.02]:
		root.add_child(_circle_poly(Vector2(ex, -r * 1.12), er, Color(0.95, 0.95, 0.98)))
		root.add_child(_circle_poly(Vector2(ex - er * 0.4, -r * 1.12), er * 0.55, Color(0.05, 0.04, 0.08)))
	return root


# ── 적 등장 ──────────────────────────────────────────────────────
func _spawn_enemy() -> void:
	if enemy_node != null and is_instance_valid(enemy_node):
		enemy_node.queue_free()
	if enemy_hp_bg != null and is_instance_valid(enemy_hp_bg):
		enemy_hp_bg.queue_free()
	if enemy_hp_fill != null and is_instance_valid(enemy_hp_fill):
		enemy_hp_fill.queue_free()
	if lbl_enemy_name != null and is_instance_valid(lbl_enemy_name):
		lbl_enemy_name.queue_free()

	# 보스 스테이지인데 아직 도전 전이면: 일반 몹을 파밍하며 '보스 도전' 게이트 표시
	var at_gate: bool = GameData.is_boss_stage(stage) and not boss_active
	enemy = GameData.make_enemy(stage, at_gate)
	_overpower = not enemy["boss"] and p_atk >= int(enemy["max_hp"])   # 한 방 처치 가능 → 빠른 진행
	enemy_node = _make_enemy(enemy)
	enemy_node.position = Vector2(ENEMY_X + 180, GROUND_Y)   # 오른쪽에서 슬라이드 인
	add_child(enemy_node)
	var slide := create_tween()
	slide.tween_property(enemy_node, "position:x", ENEMY_X, 0.35).set_trans(Tween.TRANS_QUAD)

	var bar_w: float = 96.0 if not enemy["boss"] else 220.0
	var top: float = GROUND_Y - (enemy["r"] * 2.0) - 30.0
	enemy_hp_bg = ColorRect.new()
	enemy_hp_bg.color = Color(0, 0, 0, 0.6)
	enemy_hp_bg.size = Vector2(bar_w + 4, 13)
	enemy_hp_bg.position = Vector2(ENEMY_X - bar_w * 0.5 - 2, top)
	enemy_hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(enemy_hp_bg)
	enemy_hp_fill = ColorRect.new()
	enemy_hp_fill.color = COL_HP_BOSS if enemy["boss"] else COL_HP
	enemy_hp_fill.size = Vector2(bar_w, 9)
	enemy_hp_fill.position = Vector2(ENEMY_X - bar_w * 0.5, top + 2)
	enemy_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(enemy_hp_fill)
	enemy["bar_w"] = bar_w

	var nm: String = ("[보스] " + enemy["name"]) if enemy["boss"] else enemy["name"]
	lbl_enemy_name = _new_label(nm, 18 if not enemy["boss"] else 22, COL_TEXT if not enemy["boss"] else COL_HP_BOSS)
	lbl_enemy_name.position = Vector2(ENEMY_X - 150, top - 28)
	lbl_enemy_name.size = Vector2(300, 26)
	lbl_enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl_enemy_name)
	if kfont != null:
		_apply_font_to(lbl_enemy_name)

	if enemy["boss"]:
		_play("boss_appear")
	_update_sky()
	e_atk_timer = 0.0
	boss_atk_count = 0
	boss_winding = false
	_show_challenge(at_gate)
	if at_gate and auto_boss:
		get_tree().create_timer(1.2).timeout.connect(_start_boss_challenge)
	_update_progress()


# ── 전투 루프 ────────────────────────────────────────────────────
func _process(delta: float) -> void:
	save_timer += delta
	if save_timer >= 5.0:
		save_timer = 0.0
		_save()
	# 스킬 쿨다운·가속 진행
	if smash_cd > 0: smash_cd = maxf(0.0, smash_cd - delta)
	if haste_cd > 0: haste_cd = maxf(0.0, haste_cd - delta)
	if haste_timer > 0:
		haste_timer = maxf(0.0, haste_timer - delta)
		if haste_timer == 0.0 and is_instance_valid(hero):
			hero.modulate = Color.WHITE
	_update_skill_buttons()
	_auto_tick(delta)
	if busy or enemy.is_empty():
		return
	if enemy.get("dying", false):
		return
	# 보스 분노: 체력 30% 이하에서 1회, 공격 속도 상승
	if enemy.get("boss", false) and not enemy.get("enraged", false) and int(enemy["hp"]) < int(enemy["max_hp"]) * 0.3:
		enemy["enraged"] = true
		enemy["interval"] = float(enemy["interval"]) * 0.6
		_flash_notice("보스 분노!")
		if is_instance_valid(enemy_node):
			enemy_node.modulate = Color(1.6, 0.7, 0.7)
	var atk_interval := p_interval * (0.5 if haste_timer > 0 else 1.0)
	p_atk_timer += delta
	if p_atk_timer >= atk_interval:
		p_atk_timer = 0.0
		_player_attack()
	if not boss_winding:
		e_atk_timer += delta
		if e_atk_timer >= float(enemy["interval"]):
			e_atk_timer = 0.0
			_enemy_attack()


# ── 자동화(방치) ─────────────────────────────────────────────────
var _auto_buy_t := 0.0
func _auto_tick(delta: float) -> void:
	last_progress_t += delta
	# 자동 강화: 0.25초마다 살 수 있는 가장 싼 강화 구매(골드 소진까지)
	if auto_upgrade:
		_auto_buy_t += delta
		if _auto_buy_t >= 0.25:
			_auto_buy_t = 0.0
			_auto_buy_upgrades()
	# 자동 스킬: 쿨 끝나면 자동 시전(전투 중)
	if auto_skill and not busy and not enemy.is_empty() and not enemy.get("dying", false):
		if smash_cd <= 0:
			_use_smash()
		if haste_cd <= 0 and haste_timer <= 0:
			_use_haste()
	# 자동 환생: 30초 이상 진행 정체 + 환생 이득이 충분하면 자동 환생
	if auto_prestige and not busy and last_progress_t > 30.0:
		var gain := GameData.souls_for(max_stage_cleared)
		if gain >= 5 and gain >= souls / 4:
			_play("prestige")
			_do_prestige(gain)
			prestige_overlay.visible = false


func _auto_buy_upgrades() -> void:
	var n := 0
	while n < 25:
		var best_id := ""
		var best_cost := -1
		for udef in GameData.UPGRADES:
			var c := GameData.upgrade_cost(udef, upgrades[udef["id"]])
			if best_cost < 0 or c < best_cost:
				best_cost = c; best_id = udef["id"]
		if best_id == "" or gold < best_cost:
			break
		gold -= best_cost
		upgrades[best_id] = int(upgrades[best_id]) + 1
		counters["upgrade"] += 1
		n += 1
	if n > 0:
		_recompute_stats()
		_update_hud()
		_update_growth_buttons()
		_refresh_mission_badge()
		_check_achievements()


func _player_attack() -> void:
	if enemy.is_empty() or enemy.get("dying", false):
		return
	# 살짝 전진 후 복귀(타격감) + 공격 애니
	_play_char_anim(hero_anim, "attack")
	var tw := create_tween()
	tw.tween_property(hero, "position:x", HERO_X + 22, 0.08).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(hero, "position:x", HERO_X, 0.12)
	var crit: bool = randf() < p_crit
	var dmg: int = p_atk
	if crit:
		dmg = int(round(dmg * p_crit_mult))
	enemy["hp"] = int(enemy["hp"]) - dmg
	_play("crit" if crit else "slash")
	_play_char_anim(enemy.get("anim"), "hit")
	if crit:
		_hitstop(0.05)
	_hit_flash(enemy_node)
	var hitpos := Vector2(ENEMY_X - enemy["r"] * 0.4, GROUND_Y - enemy["r"])
	_slash_fx(hitpos, crit)
	_spawn_hit_burst(hitpos, Color(1.0, 0.85, 0.55, 0.9) if crit else Color(0.9, 0.92, 1.0, 0.8), 12 if crit else 6)
	_float_text(Vector2(ENEMY_X, GROUND_Y - enemy["r"] * 2.0 - 6), str(dmg), COL_GOLD if crit else COL_TEXT, crit)
	_update_enemy_hp()
	if int(enemy["hp"]) <= 0:
		_enemy_die()


func _enemy_attack() -> void:
	if enemy.is_empty() or enemy.get("dying", false):
		return
	# 보스는 3번째 공격마다 예고된 강공격
	if enemy.get("boss", false):
		boss_atk_count += 1
		if boss_atk_count % 3 == 0:
			_boss_heavy()
			return
	_play_char_anim(enemy.get("anim"), "attack")
	var tw := create_tween()
	tw.tween_property(enemy_node, "position:x", ENEMY_X - 24, 0.09)
	tw.tween_property(enemy_node, "position:x", ENEMY_X, 0.12)
	var dmg: int = maxi(1, int(enemy["atk"]) - p_def)
	p_hp -= dmg
	_play("hit")
	_play_char_anim(hero_anim, "hit")
	_hit_flash(hero)
	_float_text(Vector2(HERO_X, GROUND_Y - 150), str(dmg), Color(1.0, 0.5, 0.5), false)
	_update_hero_hp()
	if p_hp <= 0:
		_player_down()


# 보스 강공격: 0.75초 예열(확대·붉은 경고) 후 큰 피해. 예열 동안 보스는 일반 공격을 멈춘다.
func _boss_heavy() -> void:
	boss_winding = true
	_play("boss_appear")
	_flash_notice("⚠ 강공격 예열")
	if is_instance_valid(enemy_node):
		var tw := create_tween()
		tw.tween_property(enemy_node, "scale", Vector2(1.28, 1.28), 0.7)
		tw.parallel().tween_property(enemy_node, "modulate", Color(1.9, 0.5, 0.5), 0.7)
	await get_tree().create_timer(0.78).timeout
	if enemy.is_empty() or enemy.get("dying", false) or not enemy.get("boss", false):
		boss_winding = false
		return
	if is_instance_valid(enemy_node):
		var tw2 := create_tween()
		tw2.tween_property(enemy_node, "position:x", ENEMY_X - 64, 0.1)
		tw2.tween_property(enemy_node, "position:x", ENEMY_X, 0.22)
		tw2.parallel().tween_property(enemy_node, "scale", Vector2(1, 1), 0.32)
		tw2.parallel().tween_property(enemy_node, "modulate", Color(1, 1, 1), 0.32)
	var dmg: int = maxi(1, int(round(int(enemy["atk"]) * 2.6)) - p_def)
	p_hp -= dmg
	_play("crit")
	_hitstop(0.07)
	_screen_flash(Color(0.9, 0.15, 0.15, 0.32))
	_hit_flash(hero)
	_spawn_hit_burst(Vector2(HERO_X, GROUND_Y - 60), Color(1.0, 0.4, 0.4, 0.9), 16)
	_float_text(Vector2(HERO_X, GROUND_Y - 150), str(dmg), Color(1.0, 0.35, 0.35), true)
	_update_hero_hp()
	e_atk_timer = 0.0
	boss_winding = false
	if p_hp <= 0:
		_player_down()


var _hitstop_busy := false

# 히트스톱: 찰나의 시간 정지로 강타의 무게감을 준다(치명타·보스 강공격). 실시간 타이머로 복구.
func _hitstop(dur: float) -> void:
	if _hitstop_busy or _shot_mode:
		return
	_hitstop_busy = true
	Engine.time_scale = 0.06
	await get_tree().create_timer(dur, true, false, true).timeout  # ignore_time_scale
	Engine.time_scale = 1.0
	_hitstop_busy = false


# 버튼 누름 피드백: 살짝 줄었다 복귀(촉각적 반응).
func _btn_pop(node: Control) -> void:
	if not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(0.93, 0.93), 0.05)
	tw.tween_property(node, "scale", Vector2(1, 1), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# 타격 순간 흰 베기 섬광(대각선 스트릭). 치명타는 더 크고 노랗게.
func _slash_fx(pos: Vector2, crit: bool) -> void:
	var s := Sprite2D.new()
	s.texture = _load_gen("glow")
	if s.texture == null:
		return
	s.position = pos
	s.rotation = deg_to_rad(-38)
	s.modulate = Color(1.0, 0.95, 0.6, 0.95) if crit else Color(1, 1, 1, 0.9)
	var w: float = 0.95 if crit else 0.7
	s.scale = Vector2(w * 0.45, 0.05)
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2(w, 0.015), 0.16).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.16)
	tw.tween_callback(s.queue_free)


# 화면 전체 짧은 색 플래시(보스 강공격 등 임팩트).
func _screen_flash(col: Color) -> void:
	var r := ColorRect.new()
	r.color = col
	r.size = GameData.SCREEN
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color", Color(col.r, col.g, col.b, 0), 0.4)
	tw.tween_callback(r.queue_free)


func _player_down() -> void:
	p_hp = p_max_hp
	_update_hero_hp()
	if boss_active:
		# 보스전 패배 → 보스 포기, 일반 몹 파밍으로 복귀(다시 도전 가능)
		boss_active = false
		boss_winding = false
		_flash_notice("보스 도전 실패!\n전열을 정비하세요")
		_spawn_enemy()
	else:
		# 일반 몹에게 패배 → 현재 층 처음부터(처치 수 초기화)
		kills = 0
		_flash_notice("재정비! 처음부터")
		_update_progress()


func _enemy_die() -> void:
	enemy["dying"] = true
	var g := _gold_gain(int(enemy["gold"]))
	gold += g
	_float_text(Vector2(HERO_X + 30, GROUND_Y - 96), "+%s" % _fmt(g), COL_GOLD, enemy["boss"])
	_gain_exp(int(enemy["exp"]))
	var was_boss: bool = enemy["boss"]
	counters["kill"] += 1
	counters["gold"] += g
	if was_boss:
		counters["boss"] += 1
	_refresh_mission_badge()
	_check_achievements()
	_play("boss_victory" if was_boss else "")
	_spawn_hit_burst(Vector2(ENEMY_X, GROUND_Y - enemy["r"]), Color(enemy["color"]).lightened(0.2), 22 if was_boss else 12)
	_play_char_anim(enemy.get("anim"), "death")
	if is_instance_valid(enemy_node):
		var tw := create_tween()
		tw.tween_interval(0.25)   # death 애니 잠깐 보여주고
		tw.tween_property(enemy_node, "scale", Vector2(0.1, 0.1), 0.22)
		tw.parallel().tween_property(enemy_node, "modulate", Color(1, 1, 1, 0), 0.22)
	if is_instance_valid(enemy_hp_bg): enemy_hp_bg.visible = false
	if is_instance_valid(enemy_hp_fill): enemy_hp_fill.visible = false
	if is_instance_valid(lbl_enemy_name): lbl_enemy_name.visible = false
	_update_hud()
	_update_growth_buttons()
	GameData.bump_salt()
	_after_kill(was_boss)


func _after_kill(was_boss: bool) -> void:
	if was_boss:
		boss_active = false
		_stage_clear(true)
		return
	# 압도 시(이전 적을 한 방에) 더 빠른 재등장 — 후반 대기 피로 감소
	var fast: float = 0.1 if _overpower else 0.35
	# 보스 게이트에서 파밍 중이면 처치해도 진행 없이 다음 몹(도전 대기)
	if GameData.is_boss_stage(stage) and not boss_active:
		await get_tree().create_timer(fast).timeout
		_spawn_enemy()
		return
	kills += 1
	if kills >= GameData.KILLS_PER_STAGE:
		_stage_clear(false)
	else:
		_update_progress()
		await get_tree().create_timer(fast).timeout
		_spawn_enemy()


func _stage_clear(was_boss: bool) -> void:
	if stage > max_stage_cleared:
		max_stage_cleared = stage
	kills = 0
	var cleared_stage := stage
	stage += 1
	counters["stage"] += 1
	last_progress_t = 0.0
	_refresh_mission_badge()
	_check_achievements()
	_save()
	if was_boss:
		busy = true
		var region_final := GameData.is_region_final(cleared_stage)
		if cleared_stage >= GameData.STAGE_COUNT:
			region_cleared = true
		var lines := "골드 +%s\n전투력이 단단해졌습니다." % _fmt(int(enemy["gold"]))
		if region_final:
			var nextreg := GameData.region_for(cleared_stage + 1)
			_show_reward("지역 클리어!", "%s 돌파!\n%s\n\n새 지역 [%s] 개방!" % [GameData.region_for(cleared_stage)["name"], lines, nextreg["name"]])
		else:
			_show_reward("보스 격파!", "%s 처치\n%s\n\n%d층으로 전진!" % [enemy["name"], lines, stage])
		await get_tree().create_timer(1.9).timeout
		reward_overlay.visible = false
		busy = false
		_update_hud()
		_spawn_enemy()
	else:
		_flash_notice("%d층 클리어!" % cleared_stage)
		_update_hud()
		await get_tree().create_timer(0.4).timeout
		_spawn_enemy()


# ── 성장 ─────────────────────────────────────────────────────────
func _on_upgrade_pressed(id: String) -> void:
	var udef := GameData.upgrade_def(id)
	var cost := GameData.upgrade_cost(udef, upgrades[id])
	if gold < cost:
		return
	_play("button")
	_btn_pop(up_rows[id]["panel"])
	gold -= cost
	counters["upgrade"] += 1
	_refresh_mission_badge()
	upgrades[id] = int(upgrades[id]) + 1
	_recompute_stats()
	if id == "hp":
		p_hp = mini(p_hp + udef["per"], p_max_hp)   # 체력 강화는 그만큼 회복
	_update_hud()
	_update_growth_buttons()
	_update_hero_hp()
	_save()


func _recompute_stats() -> void:
	var b: Dictionary = GameData.PLAYER_BASE
	var passive := GameData.global_mult(souls)
	var atk_mult := passive * (1.0 + _soul_lv("s_atk") * float(GameData.soul_upgrade_def("s_atk")["per"])) * ach_mult
	p_gold_mult = passive * (1.0 + _soul_lv("s_gold") * float(GameData.soul_upgrade_def("s_gold")["per"])) * ach_mult
	var hp_mult := 1.0 + _soul_lv("s_hp") * float(GameData.soul_upgrade_def("s_hp")["per"])
	p_off_eff = clampf(GameData.OFFLINE_EFFICIENCY + _soul_lv("s_off") * float(GameData.soul_upgrade_def("s_off")["per"]), 0.0, 0.95)
	p_crit_mult = float(b["crit_mult"]) + _soul_lv("s_crit") * float(GameData.soul_upgrade_def("s_crit")["per"])
	p_cd_scale = clampf(1.0 - _soul_lv("s_cd") * float(GameData.soul_upgrade_def("s_cd")["per"]), 0.4, 1.0)
	p_global_mult = atk_mult
	var raw_atk: int = int(b["atk"]) + (level - 1) * GameData.LVL_ATK + upgrades["atk"] * GameData.upgrade_def("atk")["per"]
	p_atk = int(round(raw_atk * atk_mult))
	p_max_hp = int(round((int(b["hp"]) + (level - 1) * GameData.LVL_HP + upgrades["hp"] * GameData.upgrade_def("hp")["per"]) * hp_mult))
	p_def = int(b["def"]) + upgrades["def"] * GameData.upgrade_def("def")["per"]
	p_crit = float(b["crit"]) + upgrades["crit"] * GameData.upgrade_def("crit")["per"]
	p_interval = float(b["atk_interval"])
	p_hp = mini(p_hp, p_max_hp)
	p_power = int(round(p_atk / p_interval * (1.0 + p_crit * (p_crit_mult - 1.0)) + p_max_hp * 0.4 + p_def * 6.0))


func _soul_lv(id: String) -> int:
	return int(soul_upgrades.get(id, 0))


func _gold_gain(base: int) -> int:
	var bonus: float = 1.0 + int(upgrades["gold"]) * float(GameData.upgrade_def("gold")["per"])
	return int(round(base * bonus * p_gold_mult))


func _gain_exp(amount: int) -> void:
	exp += amount
	while exp >= GameData.exp_to_next(level):
		exp -= GameData.exp_to_next(level)
		level += 1
		_recompute_stats()
		p_hp = p_max_hp
		_play("level_up")
		_flash_notice("레벨 업!  Lv %d" % level)


# ── 표시 갱신 ────────────────────────────────────────────────────
func _update_hud() -> void:
	lbl_gold.text = _fmt(gold)
	lbl_level.text = "Lv %d" % level
	lbl_stage.text = "%s · %d층" % [GameData.region_for(stage)["name"], stage]
	var need := GameData.exp_to_next(level)
	exp_fill.size.x = 500.0 * clampf(float(exp) / float(need), 0.0, 1.0)
	var line := "전투력 %s" % _fmt(p_power)
	if souls > 0 or prestige_count > 0:
		line += "   ·   %s ◆ %d" % [GameData.SOUL_NAME, souls]
	lbl_souls.text = line
	_update_hero_hp()


func _update_progress() -> void:
	if enemy.get("boss", false):
		lbl_progress.text = "◆ 보스전 ◆"
		lbl_progress.add_theme_color_override("font_color", COL_HP_BOSS)
	elif GameData.is_boss_stage(stage) and not boss_active:
		lbl_progress.text = "보스 관문 — 도전 대기"
		lbl_progress.add_theme_color_override("font_color", COL_GOLD)
	else:
		lbl_progress.text = "처치  %d / %d" % [kills, GameData.KILLS_PER_STAGE]
		lbl_progress.add_theme_color_override("font_color", COL_DIM)


func _update_hero_hp() -> void:
	hero_hp_fill.size.x = 82.0 * clampf(float(p_hp) / float(p_max_hp), 0.0, 1.0)


func _update_enemy_hp() -> void:
	if not is_instance_valid(enemy_hp_fill) or enemy.is_empty():
		return
	enemy_hp_fill.size.x = float(enemy["bar_w"]) * clampf(float(enemy["hp"]) / float(enemy["max_hp"]), 0.0, 1.0)


func _update_growth_buttons() -> void:
	for udef in GameData.UPGRADES:
		var id: String = udef["id"]
		var row: Dictionary = up_rows[id]
		var lv: int = upgrades[id]
		var cost := GameData.upgrade_cost(udef, lv)
		row["name"].text = "%s  Lv %d" % [udef["name"], lv]
		row["value"].text = _value_preview(udef)
		row["cost"].text = "%s G" % _fmt(cost)
		var afford := gold >= cost
		row["button"].disabled = not afford
		row["panel"].modulate = Color(1, 1, 1, 1) if afford else Color(0.62, 0.62, 0.68, 1)
		row["cost"].add_theme_color_override("font_color", COL_GOLD if afford else COL_DIM)


func _value_preview(udef: Dictionary) -> String:
	var id: String = udef["id"]
	match id:
		"atk": return "%d → %d" % [p_atk, p_atk + int(udef["per"])]
		"hp": return "%d → %d" % [p_max_hp, p_max_hp + int(udef["per"])]
		"def": return "%d → %d" % [p_def, p_def + int(udef["per"])]
		"crit": return "%d%% → %d%%" % [int(round(p_crit * 100)), int(round((p_crit + float(udef["per"])) * 100))]
		"gold":
			var g: int = upgrades["gold"]
			return "+%d%% → +%d%%" % [int(round(g * float(udef["per"]) * 100)), int(round((g + 1) * float(udef["per"]) * 100))]
	return ""


# ── 보상·알림 ────────────────────────────────────────────────────
func _show_reward(title: String, body: String) -> void:
	reward_title.text = title
	reward_body.text = body
	reward_overlay.visible = true
	if kfont != null:
		_apply_font_to(reward_title)
		_apply_font_to(reward_body)


func _flash_notice(text: String) -> void:
	notice.text = text
	notice.visible = true
	notice.modulate = Color(1, 1, 1, 1)
	notice.scale = Vector2(0.7, 0.7)
	notice.pivot_offset = Vector2(GameData.SCREEN.x * 0.5, 25)
	if kfont != null:
		_apply_font_to(notice)
	var tw := create_tween()
	tw.tween_property(notice, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(notice, "modulate", Color(1, 1, 1, 0), 0.4)
	tw.tween_callback(func() -> void: notice.visible = false)


func _float_text(pos: Vector2, text: String, color: Color, big: bool) -> void:
	var l := _new_label(text, 30 if big else 22, color)
	l.position = pos + Vector2(-30, -10)
	l.size = Vector2(60, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	if kfont != null:
		_apply_font_to(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 46, 0.5)
	tw.parallel().tween_property(l, "modulate", Color(color.r, color.g, color.b, 0), 0.5)
	tw.tween_callback(l.queue_free)


func _hit_flash(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	node.modulate = Color(2.2, 2.2, 2.2)
	var tw := create_tween()
	tw.tween_property(node, "modulate", Color(1, 1, 1), 0.18)


# ── 저장 ─────────────────────────────────────────────────────────
func _state_dict() -> Dictionary:
	return {
		"level": level, "exp": exp, "gold": gold, "upgrades": upgrades,
		"stage": stage, "kills": kills,
		"max_stage_cleared": max_stage_cleared, "region_cleared": region_cleared,
		"souls": souls, "prestige_count": prestige_count, "soul_upgrades": soul_upgrades,
		"sound_on": sound_on, "seen_intro": seen_intro,
		"counters": counters, "missions": missions,
		"daily_day": daily_day, "daily_streak": daily_streak,
		"auto_boss": auto_boss, "achieved": achieved,
		"auto_upgrade": auto_upgrade, "auto_skill": auto_skill, "auto_prestige": auto_prestige,
	}


func _save() -> void:
	SaveSystem.save(_state_dict())


func _apply_save(s: Dictionary) -> void:
	level = s["level"]
	exp = s["exp"]
	gold = s["gold"]
	for id in upgrades.keys():
		upgrades[id] = int(s["upgrades"].get(id, 0))
	stage = s["stage"]
	kills = s["kills"]
	max_stage_cleared = s["max_stage_cleared"]
	region_cleared = s["region_cleared"]
	souls = int(s.get("souls", 0))
	prestige_count = int(s.get("prestige_count", 0))
	last_save_unix = int(s.get("last_save_unix", 0))
	sound_on = bool(s.get("sound_on", true))
	seen_intro = bool(s.get("seen_intro", false))
	var c = s.get("counters", {})
	for k in counters.keys():
		counters[k] = int(c.get(k, 0)) if typeof(c) == TYPE_DICTIONARY else 0
	missions = s.get("missions", []) if typeof(s.get("missions")) == TYPE_ARRAY else []
	daily_day = int(s.get("daily_day", 0))
	daily_streak = int(s.get("daily_streak", 0))
	auto_boss = bool(s.get("auto_boss", false))
	achieved = s.get("achieved", []) if typeof(s.get("achieved")) == TYPE_ARRAY else []
	auto_upgrade = bool(s.get("auto_upgrade", false))
	auto_skill = bool(s.get("auto_skill", false))
	auto_prestige = bool(s.get("auto_prestige", false))
	var su = s.get("soul_upgrades", {})
	for id in soul_upgrades.keys():
		soul_upgrades[id] = int(su.get(id, 0)) if typeof(su) == TYPE_DICTIONARY else 0


func _reset_progress() -> void:
	SaveSystem.clear()
	level = 1; exp = 0; gold = 0
	upgrades = {"atk": 0, "hp": 0, "def": 0, "crit": 0, "gold": 0}
	stage = 1; kills = 0; max_stage_cleared = 0; region_cleared = false
	souls = 0; prestige_count = 0
	soul_upgrades = {"s_atk": 0, "s_gold": 0, "s_hp": 0, "s_off": 0}
	counters = {"kill": 0, "stage": 0, "upgrade": 0, "boss": 0, "gold": 0}
	missions = []; daily_day = 0; daily_streak = 0
	boss_active = false; auto_boss = false
	achieved = []; ach_mult = 1.0
	auto_upgrade = false; auto_skill = false; auto_prestige = false
	_refresh_auto_btn()
	_ensure_missions()
	_refresh_mission_badge()
	_recompute_stats()
	p_hp = p_max_hp
	busy = false
	_update_hud()
	_update_growth_buttons()
	_spawn_enemy()
	_flash_notice("새로 시작!")


# ── 작은 헬퍼 ────────────────────────────────────────────────────
const _SUFFIX := ["", "K", "M", "B", "T", "aa", "ab", "ac", "ad", "ae", "af", "ag"]

# 큰 수는 K·M·B·T·aa… 로 줄여 표시(방치형 누적에 대응). 10만 미만은 천 단위 콤마.
func _fmt(n: int) -> String:
	if n < 100000:
		var s := str(n)
		var out := ""
		var c := 0
		for i in range(s.length() - 1, -1, -1):
			out = s[i] + out
			c += 1
			if c % 3 == 0 and i > 0:
				out = "," + out
		return out
	var tier := 0
	var v := float(n)
	while v >= 1000.0 and tier < _SUFFIX.size() - 1:
		v /= 1000.0
		tier += 1
	if v >= 100.0:
		return "%.0f%s" % [v, _SUFFIX[tier]]
	return "%.2f%s" % [v, _SUFFIX[tier]]


func _new_label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# 인라인 작은 아이콘(Sprite2D, 크기 정확히 제어). center=중심좌표, disp=표시 한 변(px).
func _icon_sprite(name: String, center: Vector2, disp: float) -> Sprite2D:
	var path := "res://assets/ui/%s.png" % name
	if not ResourceLoader.exists(path):
		return null
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = true
	var th: float = maxf(1.0, s.texture.get_height())
	s.scale = Vector2(disp / th, disp / th)
	s.position = center
	return s


# UI 아이콘(assets/ui/<name>.png) TextureRect(전체화면 배경 등). 없으면 null.
func _ui_icon(name: String, pos: Vector2, size: float) -> TextureRect:
	var path := "res://assets/ui/%s.png" % name
	if not ResourceLoader.exists(path):
		return null
	var t := TextureRect.new()
	t.texture = load(path)
	t.position = pos
	t.size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _new_panel(rect: Rect2, col: Color) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(16)
	sb.border_color = COL_BORDER
	sb.set_border_width_all(2)
	sb.border_width_top = 1
	sb.border_width_bottom = 3            # 아래 두껍게 → 입체감
	sb.shadow_color = COL_SHADOW
	sb.shadow_size = 8                    # 소프트 드롭 섀도우 → 배경에서 떠 보임
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	return p


# 입체 베벨 버튼 스타일박스 한 장.
func _btn_box(bg: Color, top_bevel: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(12)
	s.border_color = COL_BORDER
	s.set_border_width_all(2)
	s.border_width_bottom = 4
	if top_bevel:
		s.border_width_top = 1
	s.expand_margin_top = 0.0
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = COL_SHADOW
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, 3)
	return s


func _style_button(b: Button) -> void:
	var normal := _btn_box(COL_BTN, true)
	var hover := _btn_box(COL_BTN_HI, true)
	var pressed := _btn_box(COL_BTN_HI.darkened(0.1), false)
	pressed.border_width_bottom = 2
	pressed.shadow_size = 2
	var disabled := _btn_box(Color(0.14, 0.12, 0.20), true)
	disabled.border_color = Color(0.30, 0.27, 0.40)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.47, 0.6))
	b.pressed.connect(_btn_pop.bind(b))


func _rect_poly(pos: Vector2, sz: Vector2, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([pos, pos + Vector2(sz.x, 0), pos + sz, pos + Vector2(0, sz.y)])
	p.color = col
	return p


func _tri_poly(a: Vector2, b: Vector2, c: Vector2, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([a, b, c])
	p.color = col
	return p


func _circle_poly(center: Vector2, radius: float, col: Color) -> Polygon2D:
	var pts := PackedVector2Array()
	var seg := 22
	for i in range(seg):
		var ang := TAU * i / seg
		pts.append(center + Vector2(cos(ang), sin(ang)) * radius)
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = col
	return p


# ── 폰트 ─────────────────────────────────────────────────────────
func _apply_font() -> void:
	var path := "res://malgun.ttf"
	if not ResourceLoader.exists(path):
		return
	kfont = load(path)
	_apply_font_to(self)


func _apply_font_to(node: Node) -> void:
	if node is Label or node is Button:
		node.add_theme_font_override("font", kfont)
	for c in node.get_children():
		_apply_font_to(c)
