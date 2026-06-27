# 균열기사 v0.1 — 화면·전투 루프·성장·스테이지·보상·저장을 묶는 메인 (데이터는 reset/GameData.gd)
extends Control

const GameData := preload("res://reset/GameData.gd")
const SaveSystem := preload("res://reset/SaveSystem.gd")

# ── 팔레트 ───────────────────────────────────────────────────────
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
var boss_atk_count := 0
var boss_winding := false    # 보스 강공격 예열 중
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
var sound_on := true
var seen_intro := false


func _ready() -> void:
	_shot_mode = "--shot" in OS.get_cmdline_user_args()
	_build_background()
	_build_battle_area()
	_build_vignette()
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
	reward_overlay.visible = false
	stage = 23; kills = 2; _spawn_enemy()   # 2지역(잿빛 협곡) 일반 적
	await get_tree().create_timer(0.5).timeout
	_save_shot("r07_region2")
	stage = 40; kills = 0; _spawn_enemy()    # 2지역 최종 보스
	await get_tree().create_timer(0.4).timeout
	_boss_heavy()                            # 강공격 예열(확대·붉은 경고)
	await get_tree().create_timer(0.45).timeout
	_save_shot("r08_bosswindup")
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
	add_child(ov)
	_onboard_ov = ov
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.size = GameData.SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.add_child(dim)
	var box := _new_panel(Rect2(50, 360, 440, 250), COL_PANEL_HI)
	ov.add_child(box)
	var head := _new_label("환영합니다", 28, COL_GOLD)
	head.position = Vector2(50, 384)
	head.size = Vector2(440, 36)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(head)
	var body := _new_label("", 21, COL_TEXT)
	body.position = Vector2(78, 432)
	body.size = Vector2(384, 120)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov.add_child(body)
	var btn := Button.new()
	btn.position = Vector2(150, 552)
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
	var name := "bg_dungeon" if stage <= GameData.REGIONS[0]["end"] else "bg_dungeon2"
	var tex := _load_gen(name)
	if tex != null:
		bg_layer.texture = tex


func _load_gen(name: String) -> Texture2D:
	var path := "res://assets/gen/%s.png" % name
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _gen_sprite(name: String, pos: Vector2, modulate := Color.WHITE) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _load_gen(name)
	s.position = pos
	s.modulate = modulate
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
	bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_layer)

	# 벽 횃불 위치(합성 이미지 기준)에 흔들리는 불빛 글로우
	for tx in [120.0, 424.0]:
		var glow := _gen_sprite("glow", Vector2(tx, 322), Color(1.0, 0.55, 0.2, 0.5))
		if glow.texture != null:
			glow.scale = Vector2(0.7, 0.7)
			add_child(glow)
			var tw := create_tween().set_loops()
			tw.tween_property(glow, "modulate:a", 0.32, 0.9).set_trans(Tween.TRANS_SINE)
			tw.tween_property(glow, "modulate:a", 0.55, 1.1).set_trans(Tween.TRANS_SINE)

	# 떠오르는 잔불(앰비언트 파티클)
	_build_ambient_embers()


func _build_ambient_embers() -> void:
	var tex := _load_gen("ember")
	if tex == null:
		return
	var p := CPUParticles2D.new()
	p.texture = tex
	p.position = Vector2(GameData.SCREEN.x * 0.5, GROUND_Y + 20)
	p.amount = 26
	p.lifetime = 6.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(GameData.SCREEN.x * 0.5, 10)
	p.direction = Vector2(0, -1)
	p.spread = 18.0
	p.gravity = Vector2(0, -8)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 26.0
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.5
	p.color = Color(1.0, 0.8, 0.5, 0.5)
	add_child(p)


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
	var box := _new_panel(Rect2(70, 330, 400, 330), COL_PANEL_HI)
	settings_overlay.add_child(box)
	var t := _new_label("설정", 30, COL_GOLD)
	t.position = Vector2(70, 352)
	t.size = Vector2(400, 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_overlay.add_child(t)

	var sound_btn := Button.new()
	sound_btn.text = "사운드: 켜짐" if sound_on else "사운드: 꺼짐"
	sound_btn.position = Vector2(120, 408)
	sound_btn.size = Vector2(300, 52)
	sound_btn.add_theme_font_size_override("font_size", 21)
	_style_button(sound_btn)
	sound_btn.pressed.connect(func() -> void:
		_set_sound(not sound_on)
		sound_btn.text = "사운드: 켜짐" if sound_on else "사운드: 꺼짐"
		_play("button")
		_save())
	settings_overlay.add_child(sound_btn)

	var reset_btn := Button.new()
	reset_btn.text = "진행 초기화"
	reset_btn.position = Vector2(120, 476)
	reset_btn.size = Vector2(300, 54)
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
	close_btn.position = Vector2(120, 548)
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
			_play("prestige")
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
func _pixel_sprite(name: String, disp_h: float, tint := Color.WHITE) -> Sprite2D:
	var path := "res://assets/sprites/%s.png" % name
	if not ResourceLoader.exists(path):
		return null
	var s := Sprite2D.new()
	s.texture = load(path)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.modulate = tint
	var th: float = maxf(1.0, s.texture.get_height())
	var sc := disp_h / th
	s.scale = Vector2(sc, sc)
	s.centered = false
	s.position = Vector2(-s.texture.get_width() * sc * 0.5, -s.texture.get_height() * sc)
	return s


func _make_hero() -> Node2D:
	var root := Node2D.new()
	root.add_child(_shadow(120))
	var aura0 := _gen_sprite("glow", Vector2(0, -50), Color(0.45, 0.6, 1.0, 0.14))
	if aura0.texture != null:
		aura0.scale = Vector2(0.7, 0.9)
		root.add_child(aura0)
	var spr := _pixel_sprite("hero", 84.0)
	if spr != null:
		root.add_child(spr)
		return root
	# 폴백: 절차적 도형 영웅
	return _make_hero_shapes(root)


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
	root.add_child(_shadow(r * 2.6))
	if e["boss"]:
		var ba := _gen_sprite("glow", Vector2(0, -r), Color(col.r, col.g * 0.5, col.b * 0.5, 0.26))
		if ba.texture != null:
			ba.scale = Vector2(r / 95.0, r / 95.0)
			root.add_child(ba)
	# Kenney CC0 픽셀 스프라이트 우선, 없으면 절차적 도형
	var spr := _pixel_sprite(String(e.get("sprite", "")), r * 2.3, e.get("tint", Color.WHITE))
	if spr != null:
		root.add_child(spr)
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
	boss_atk_count = 0
	boss_winding = false
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
	if not boss_winding:
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
	_play("crit" if crit else "slash")
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
	var tw := create_tween()
	tw.tween_property(enemy_node, "position:x", ENEMY_X - 24, 0.09)
	tw.tween_property(enemy_node, "position:x", ENEMY_X, 0.12)
	var dmg: int = maxi(1, int(enemy["atk"]) - p_def)
	p_hp -= dmg
	_play("hit")
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
	_screen_flash(Color(0.9, 0.15, 0.15, 0.32))
	_hit_flash(hero)
	_spawn_hit_burst(Vector2(HERO_X, GROUND_Y - 60), Color(1.0, 0.4, 0.4, 0.9), 16)
	_float_text(Vector2(HERO_X, GROUND_Y - 150), str(dmg), Color(1.0, 0.35, 0.35), true)
	_update_hero_hp()
	e_atk_timer = 0.0
	boss_winding = false
	if p_hp <= 0:
		_player_down()


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
	_flash_notice("재정비!")


func _enemy_die() -> void:
	enemy["dying"] = true
	gold += _gold_gain(int(enemy["gold"]))
	_gain_exp(int(enemy["exp"]))
	var was_boss: bool = enemy["boss"]
	_play("boss_victory" if was_boss else "")
	_spawn_hit_burst(Vector2(ENEMY_X, GROUND_Y - enemy["r"]), Color(enemy["color"]).lightened(0.2), 22 if was_boss else 12)
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
		"sound_on": sound_on, "seen_intro": seen_intro,
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
