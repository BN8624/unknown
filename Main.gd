# 균열기사 v0.1 — 화면·전투 루프·성장·스테이지·보상·저장을 묶는 메인 (데이터는 reset/GameData.gd)
extends Control

const GameData := preload("res://reset/GameData.gd")
const SaveSystem := preload("res://reset/SaveSystem.gd")

# ── 팔레트 ───────────────────────────────────────────────────────
const COL_BG_TOP := Color(0.10, 0.08, 0.18)
const COL_BG_BOT := Color(0.18, 0.14, 0.30)
const COL_GROUND := Color(0.22, 0.17, 0.12)
const COL_PANEL := Color(0.14, 0.11, 0.22, 0.96)
const COL_PANEL_HI := Color(0.20, 0.16, 0.30, 0.98)
const COL_BORDER := Color(0.40, 0.33, 0.58)
const COL_GOLD := Color(0.96, 0.78, 0.32)
const COL_TEXT := Color(0.93, 0.91, 0.99)
const COL_DIM := Color(0.62, 0.58, 0.72)
const COL_HP := Color(0.35, 0.82, 0.42)
const COL_HP_BOSS := Color(0.86, 0.32, 0.34)
const COL_EXP := Color(0.55, 0.45, 0.95)

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
var p_power := 0              # 전투력(표시용)

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
var busy := false            # 보상 표시 중엔 전투 정지
var kfont: FontFile

# UI 참조
var lbl_stage: Label
var lbl_gold: Label
var lbl_level: Label
var exp_fill: ColorRect
var lbl_progress: Label
var hero: Node2D
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
var save_timer := 0.0
var sfx_streams := {}
var sfx_players: Array = []
var sfx_next := 0


func _ready() -> void:
	_shot_mode = "--shot" in OS.get_cmdline_user_args()
	_build_background()
	_build_battle_area()
	_build_hud()
	_build_growth_panel()
	_build_notice()
	_build_reward_overlay()
	_build_settings_overlay()
	_build_prestige_overlay()
	_setup_audio()
	var s := SaveSystem.load_state()
	if not s.is_empty():
		_apply_save(s)
	_recompute_stats()
	p_hp = p_max_hp
	_spawn_enemy()
	_update_hud()
	_update_growth_buttons()
	_apply_font()
	if not _shot_mode and not s.is_empty():
		_grant_offline(s)
	if _shot_mode:
		_run_shot_sequence()


# --shot: GUI에서 몇 장면을 캡처해 레이아웃을 확인하고 종료(개발용)
var _shot_mode := false
const SHOT_DIR := "C:/Users/USER/AppData/Local/Temp/claude/C--Users-USER-unknown/ba7c179b-0677-4fb1-ad24-6193890d8154/scratchpad"

func _run_shot_sequence() -> void:
	await get_tree().create_timer(0.6).timeout
	_save_shot("r01_start")
	gold = 99999; _update_hud(); _update_growth_buttons()
	await get_tree().create_timer(0.3).timeout
	_save_shot("r02_rich")
	stage = 5; kills = 0; _spawn_enemy()   # 보스 외형
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
	get_tree().quit(0)

func _save_shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/shot_%s.png" % [SHOT_DIR, tag])
	print("[SHOT] ", tag)


# ── 배경 ─────────────────────────────────────────────────────────
var sky_grad: Gradient

# 5층 구간마다 하늘 색을 살짝 바꿔 전진하는 느낌을 준다.
const SKY_TONES := [
	Color(0.18, 0.14, 0.30), Color(0.12, 0.18, 0.30), Color(0.20, 0.13, 0.22),
	Color(0.10, 0.20, 0.22), Color(0.22, 0.16, 0.14), Color(0.16, 0.12, 0.26),
]

func _update_sky() -> void:
	if sky_grad == null:
		return
	var tier := int((stage - 1) / GameData.BOSS_EVERY)
	sky_grad.set_color(1, SKY_TONES[tier % SKY_TONES.size()])


func _build_background() -> void:
	var grad := Gradient.new()
	grad.set_color(0, COL_BG_TOP)
	grad.set_color(1, COL_BG_BOT)
	sky_grad = grad
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = int(GameData.SCREEN.x)
	gt.height = int(GameData.SCREEN.y)
	var sky := TextureRect.new()
	sky.texture = gt
	sky.size = GameData.SCREEN
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	# 멀리 보이는 균열(장식): 가운데 위로 뻗는 옅은 보라 빛기둥
	for i in range(3):
		var rift := ColorRect.new()
		rift.color = Color(0.45, 0.35, 0.75, 0.06 + i * 0.03)
		rift.size = Vector2(60 - i * 16, GROUND_Y - 120)
		rift.position = Vector2(GameData.SCREEN.x * 0.5 - rift.size.x * 0.5, 120)
		rift.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rift)

	var ground := ColorRect.new()
	ground.color = COL_GROUND
	ground.size = Vector2(GameData.SCREEN.x, 760 - GROUND_Y)
	ground.position = Vector2(0, GROUND_Y)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	var edge := ColorRect.new()       # 지면 윗선 강조
	edge.color = Color(0.30, 0.24, 0.17)
	edge.size = Vector2(GameData.SCREEN.x, 4)
	edge.position = Vector2(0, GROUND_Y)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)


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
		settings_overlay.visible = true)
	add_child(gear)

	lbl_gold = _new_label("", 22, COL_GOLD)
	lbl_gold.position = Vector2(22, 54)
	add_child(lbl_gold)

	lbl_level = _new_label("", 22, COL_TEXT)
	lbl_level.position = Vector2(300, 54)
	lbl_level.size = Vector2(160, 26)
	lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(lbl_level)

	lbl_souls = _new_label("", 15, Color(0.80, 0.72, 1.0))
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
	var name_lbl := _new_label("", 18, COL_TEXT)
	name_lbl.position = Vector2(30, y + 9)
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
	add_child(reward_overlay)
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
	add_child(settings_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = GameData.SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_overlay.add_child(dim)
	var box := _new_panel(Rect2(70, 360, 400, 260), COL_PANEL_HI)
	settings_overlay.add_child(box)
	var t := _new_label("설정", 30, COL_GOLD)
	t.position = Vector2(70, 384)
	t.size = Vector2(400, 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_overlay.add_child(t)

	var reset_btn := Button.new()
	reset_btn.text = "진행 초기화"
	reset_btn.position = Vector2(120, 450)
	reset_btn.size = Vector2(300, 56)
	reset_btn.add_theme_font_size_override("font_size", 22)
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
	close_btn.position = Vector2(120, 524)
	close_btn.size = Vector2(300, 50)
	close_btn.add_theme_font_size_override("font_size", 20)
	_style_button(close_btn)
	close_btn.pressed.connect(func() -> void:
		confirming["v"] = false
		reset_btn.text = "진행 초기화"
		settings_overlay.visible = false)
	settings_overlay.add_child(close_btn)


# ── 환생(프레스티지) + 균열석 상점 오버레이 ──────────────────────
var soul_rows := {}
var prestige_confirming := false

func _build_prestige_overlay() -> void:
	prestige_overlay = Control.new()
	prestige_overlay.size = GameData.SCREEN
	prestige_overlay.visible = false
	add_child(prestige_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = GameData.SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	prestige_overlay.add_child(dim)
	var box := _new_panel(Rect2(34, 120, 472, 720), COL_PANEL_HI)
	prestige_overlay.add_child(box)
	var t := _new_label("환생 · 균열석 상점", 30, Color(0.82, 0.74, 1.0))
	t.position = Vector2(34, 142)
	t.size = Vector2(472, 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prestige_overlay.add_child(t)
	prestige_body = _new_label("", 19, COL_TEXT)
	prestige_body.position = Vector2(50, 190)
	prestige_body.size = Vector2(440, 60)
	prestige_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prestige_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prestige_overlay.add_child(prestige_body)

	# 균열석 상점(영구 강화, 환생해도 유지)
	var y := 264.0
	for udef in GameData.SOUL_UPGRADES:
		_make_soul_row(udef, y)
		y += 62.0

	var div := _new_label("— 환생하면 균열석을 얻고 진행은 초기화됩니다 —", 15, COL_DIM)
	div.position = Vector2(34, 540)
	div.size = Vector2(472, 22)
	div.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prestige_overlay.add_child(div)

	prestige_do_btn = Button.new()
	prestige_do_btn.position = Vector2(70, 576)
	prestige_do_btn.size = Vector2(400, 60)
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
			_play("boss_victory")
			_do_prestige(gain)
			prestige_overlay.visible = false)
	prestige_overlay.add_child(prestige_do_btn)

	var pclose_btn := Button.new()
	pclose_btn.text = "닫기"
	pclose_btn.position = Vector2(70, 648)
	pclose_btn.size = Vector2(400, 48)
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
	var cost_lbl := _new_label("", 18, Color(0.82, 0.74, 1.0))
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
	level = 1; exp = 0; gold = 0
	upgrades = {"atk": 0, "hp": 0, "def": 0, "crit": 0, "gold": 0}
	stage = 1; kills = 0; max_stage_cleared = 0; region_cleared = false
	_recompute_stats()
	p_hp = p_max_hp
	busy = false
	_save()
	_update_hud()
	_update_growth_buttons()
	_spawn_enemy()
	_flash_notice("환생!  전투력 x%.2f" % p_global_mult)


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
func _setup_audio() -> void:
	for name in ["attack_basic", "hit", "heavy", "level_up", "boss_appear", "boss_victory", "button"]:
		var path := "res://assets/sfx/%s.wav" % name
		if ResourceLoader.exists(path):
			sfx_streams[name] = load(path)
	for i in range(6):
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)

const SFX_VOL := {
	"attack_basic": -12.0, "hit": -10.0, "heavy": -6.0, "level_up": -5.0,
	"boss_appear": -4.0, "boss_victory": -3.0, "button": -11.0,
}

func _play(name: String) -> void:
	if name == "" or sfx_players.is_empty():
		return
	var stream = sfx_streams.get(name, null)
	if stream == null:
		return
	var pl: AudioStreamPlayer = sfx_players[sfx_next]
	sfx_next = (sfx_next + 1) % sfx_players.size()
	pl.stream = stream
	pl.volume_db = float(SFX_VOL.get(name, -8.0))
	pl.play()


# ── 캐릭터 생성(도형 조합) ───────────────────────────────────────
func _make_hero() -> Node2D:
	var root := Node2D.new()
	# 다리
	root.add_child(_rect_poly(Vector2(-14, -28), Vector2(11, 28), Color(0.18, 0.16, 0.24)))
	root.add_child(_rect_poly(Vector2(3, -28), Vector2(11, 28), Color(0.18, 0.16, 0.24)))
	# 몸통(갑옷)
	root.add_child(_rect_poly(Vector2(-20, -78), Vector2(40, 52), Color(0.28, 0.40, 0.72)))
	root.add_child(_rect_poly(Vector2(-20, -78), Vector2(40, 8), Color(0.40, 0.55, 0.92)))   # 가슴 강조
	# 머리
	root.add_child(_circle_poly(Vector2(0, -94), 16, Color(0.92, 0.80, 0.66)))
	# 투구 챙
	root.add_child(_rect_poly(Vector2(-16, -104), Vector2(32, 8), Color(0.50, 0.55, 0.62)))
	# 방패(왼쪽)
	root.add_child(_circle_poly(Vector2(-26, -52), 14, Color(0.55, 0.45, 0.30)))
	# 검(오른쪽, 위로)
	var blade := _rect_poly(Vector2(26, -110), Vector2(7, 70), Color(0.78, 0.82, 0.90))
	root.add_child(blade)
	root.add_child(_rect_poly(Vector2(22, -44), Vector2(16, 7), Color(0.45, 0.35, 0.25)))   # 검 손잡이 가드
	return root


func _make_enemy(e: Dictionary) -> Node2D:
	var root := Node2D.new()
	var r: float = e["r"]
	var col: Color = e["color"]
	# 그림자
	root.add_child(_circle_poly(Vector2(0, -6), r * 0.8, Color(0, 0, 0, 0.18)))
	# 몸체
	root.add_child(_circle_poly(Vector2(0, -r), r, col))
	# 보스 뿔
	if e["boss"]:
		root.add_child(_tri_poly(Vector2(-r * 0.5, -r * 1.7), Vector2(-r * 0.15, -r * 1.2), Vector2(-r * 0.7, -r * 1.2), col.darkened(0.2)))
		root.add_child(_tri_poly(Vector2(r * 0.5, -r * 1.7), Vector2(r * 0.15, -r * 1.2), Vector2(r * 0.7, -r * 1.2), col.darkened(0.2)))
	# 눈(왼쪽을 본다)
	root.add_child(_circle_poly(Vector2(-r * 0.35, -r * 1.1), r * 0.13, Color(0.05, 0.05, 0.08)))
	root.add_child(_circle_poly(Vector2(-r * 0.0, -r * 1.1), r * 0.13, Color(0.05, 0.05, 0.08)))
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

	enemy = GameData.make_enemy(stage)
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
	_update_progress()


# ── 전투 루프 ────────────────────────────────────────────────────
func _process(delta: float) -> void:
	save_timer += delta
	if save_timer >= 5.0:
		save_timer = 0.0
		_save()
	if busy or enemy.is_empty():
		return
	if enemy.get("dying", false):
		return
	p_atk_timer += delta
	if p_atk_timer >= p_interval:
		p_atk_timer = 0.0
		_player_attack()
	e_atk_timer += delta
	if e_atk_timer >= float(enemy["interval"]):
		e_atk_timer = 0.0
		_enemy_attack()


func _player_attack() -> void:
	if enemy.is_empty() or enemy.get("dying", false):
		return
	# 살짝 전진 후 복귀(타격감)
	var tw := create_tween()
	tw.tween_property(hero, "position:x", HERO_X + 26, 0.08).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(hero, "position:x", HERO_X, 0.12)
	var crit: bool = randf() < p_crit
	var dmg: int = p_atk
	if crit:
		dmg = int(round(dmg * GameData.PLAYER_BASE["crit_mult"]))
	enemy["hp"] = int(enemy["hp"]) - dmg
	_play("heavy" if crit else "attack_basic")
	_hit_flash(enemy_node)
	_float_text(Vector2(ENEMY_X, GROUND_Y - enemy["r"] * 2.0 - 6), str(dmg), COL_GOLD if crit else COL_TEXT, crit)
	_update_enemy_hp()
	if int(enemy["hp"]) <= 0:
		_enemy_die()


func _enemy_attack() -> void:
	if enemy.is_empty() or enemy.get("dying", false):
		return
	var tw := create_tween()
	tw.tween_property(enemy_node, "position:x", ENEMY_X - 24, 0.09)
	tw.tween_property(enemy_node, "position:x", ENEMY_X, 0.12)
	var dmg: int = maxi(1, int(enemy["atk"]) - p_def)
	p_hp -= dmg
	_hit_flash(hero)
	_float_text(Vector2(HERO_X, GROUND_Y - 150), str(dmg), Color(1.0, 0.5, 0.5), false)
	_update_hero_hp()
	if p_hp <= 0:
		_player_down()


func _player_down() -> void:
	p_hp = p_max_hp
	_update_hero_hp()
	_flash_notice("재정비!")


func _enemy_die() -> void:
	enemy["dying"] = true
	gold += _gold_gain(int(enemy["gold"]))
	_gain_exp(int(enemy["exp"]))
	var was_boss: bool = enemy["boss"]
	_play("boss_victory" if was_boss else "")
	if is_instance_valid(enemy_node):
		var tw := create_tween()
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
		_stage_clear(true)
		return
	kills += 1
	if kills >= GameData.KILLS_PER_STAGE:
		_stage_clear(false)
	else:
		_update_progress()
		await get_tree().create_timer(0.35).timeout
		_spawn_enemy()


func _stage_clear(was_boss: bool) -> void:
	if stage > max_stage_cleared:
		max_stage_cleared = stage
	kills = 0
	var cleared_stage := stage
	stage += 1
	_save()
	if was_boss:
		busy = true
		var final := cleared_stage >= GameData.STAGE_COUNT and not region_cleared
		if final:
			region_cleared = true
		var lines := "골드 +%s\n전투력이 단단해졌습니다." % _fmt(int(enemy["gold"]))
		if final:
			_show_reward("지역 클리어!", "%s 돌파!\n%s\n\n새 균열이 계속 열립니다." % [GameData.REGION_NAME, lines])
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
	gold -= cost
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
	var atk_mult := passive * (1.0 + _soul_lv("s_atk") * float(GameData.soul_upgrade_def("s_atk")["per"]))
	p_gold_mult = passive * (1.0 + _soul_lv("s_gold") * float(GameData.soul_upgrade_def("s_gold")["per"]))
	var hp_mult := 1.0 + _soul_lv("s_hp") * float(GameData.soul_upgrade_def("s_hp")["per"])
	p_off_eff = clampf(GameData.OFFLINE_EFFICIENCY + _soul_lv("s_off") * float(GameData.soul_upgrade_def("s_off")["per"]), 0.0, 0.95)
	p_global_mult = atk_mult
	var raw_atk: int = int(b["atk"]) + (level - 1) * GameData.LVL_ATK + upgrades["atk"] * GameData.upgrade_def("atk")["per"]
	p_atk = int(round(raw_atk * atk_mult))
	p_max_hp = int(round((int(b["hp"]) + (level - 1) * GameData.LVL_HP + upgrades["hp"] * GameData.upgrade_def("hp")["per"]) * hp_mult))
	p_def = int(b["def"]) + upgrades["def"] * GameData.upgrade_def("def")["per"]
	p_crit = float(b["crit"]) + upgrades["crit"] * GameData.upgrade_def("crit")["per"]
	p_interval = float(b["atk_interval"])
	p_hp = mini(p_hp, p_max_hp)
	p_power = int(round(p_atk / p_interval * (1.0 + p_crit) + p_max_hp * 0.4 + p_def * 6.0))


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
	lbl_gold.text = "골드  %s" % _fmt(gold)
	lbl_level.text = "Lv %d" % level
	var depth := "%s · %d층" % [GameData.REGION_NAME, stage]
	lbl_stage.text = depth
	var need := GameData.exp_to_next(level)
	exp_fill.size.x = 500.0 * clampf(float(exp) / float(need), 0.0, 1.0)
	var line := "전투력 %s" % _fmt(p_power)
	if souls > 0 or prestige_count > 0:
		line += "   ·   %s ◆ %d" % [GameData.SOUL_NAME, souls]
	lbl_souls.text = line
	_update_hero_hp()


func _update_progress() -> void:
	if enemy.get("boss", false):
		lbl_progress.text = "◆ 보스 ◆"
		lbl_progress.add_theme_color_override("font_color", COL_HP_BOSS)
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


func _new_panel(rect: Rect2, col: Color) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(14)
	sb.border_color = COL_BORDER
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _style_button(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COL_PANEL_HI
	normal.set_corner_radius_all(12)
	normal.border_color = COL_BORDER
	normal.set_border_width_all(2)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.28, 0.22, 0.40)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", COL_TEXT)


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
