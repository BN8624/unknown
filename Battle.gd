# 임시 용병과 임시 적의 자동 전진·자동 전투 루프를 한 화면에서 처리하는 메인 스크립트
extends Node2D

# ── 밸런스 수치 (조정은 모두 여기서) ──────────────────────────────
const MERC_MAX_HP := 100
const MERC_ATK := 10
const MERC_INTERVAL := 1.0      # 용병 공격 간격(초)

const ENEMY_MAX_HP := 30
const ENEMY_ATK := 4
const ENEMY_INTERVAL := 1.5     # 적 공격 간격(초)

const ENEMY_APPROACH_SPEED := 130.0   # 적 접근 속도(px/s)
const SCROLL_SPEED := 130.0           # 전진 시 배경 스크롤 속도(px/s)
const COMBAT_RANGE := 150.0           # 이 거리 안이면 전투 시작
const RESPAWN_DELAY := 0.7            # 적 처치 후 다음 적까지 대기(초)
const MERC_DEATH_DELAY := 1.0        # 용병 사망 후 재시작 대기(초)

# ── 성장: 골드와 공격력 강화 (TASK_002) ──────────────────────────
const GOLD_PER_KILL := 5
const ATK_UPGRADE_AMOUNT := 2        # 강화 1회당 공격력 증가
const ATK_UPGRADE_BASE_COST := 20    # 첫 강화 비용
const ATK_COST_MULTIPLIER := 1.4     # 다음 비용 = 직전 비용 × 1.4

# ── 성장: 경험치와 레벨업 (TASK_003) ─────────────────────────────
const EXP_PER_KILL := 5
const START_LEVEL := 1
const LEVEL_ATK_GAIN := 1            # 레벨업 1회당 공격력 증가
const LEVEL_HP_GAIN := 5             # 레벨업 1회당 최대 체력 증가

# ── 화면/배치 기준 ────────────────────────────────────────────────
const SCREEN := Vector2(540, 960)
const MERC_X := 162.0            # 화면 왼쪽 약 30% 지점
const GROUND_Y := 600.0
const ENEMY_SPAWN_X := 560.0     # 화면 오른쪽 바깥

# ── 상태 머신 (필요한 최소 상태만) ───────────────────────────────
enum { WALK, COMBAT, DEAD }

var merc := {}
var enemy := {}              # 비어 있으면 현재 적 없음
var respawn_timer := 0.0     # 적 처치 후 카운트다운
var merc_revive_timer := 0.0 # 용병 사망 후 카운트다운
var bg_stripes: Array = []

# ── 검증용 (헤드리스 --verify 실행 시에만 동작) ──────────────────
var verify_mode := false
var kill_count := 0
var elapsed := 0.0

var status_label: Label

# 성장 상태
var gold := 0
var atk_upgrade_cost := ATK_UPGRADE_BASE_COST
var upgrade_button: Button
var current_enemy_hits := 0   # 현재 적에게 용병이 가한 타격 수
var first_hits := 0           # 검증용: 첫 적 처치에 든 타격 수
var attack_upgrade_count := 0 # 골드 강화 횟수 (레벨업 공격력과 구분)

# 레벨/경험치 상태
var level := START_LEVEL
var exp := 0
var exp_bg: ColorRect
var exp_fill: ColorRect
var levelup_label: Label

# 검증 단계 통과 플래그
var v_task002 := false
var v_task003 := false


func _ready() -> void:
	verify_mode = "--verify" in OS.get_cmdline_user_args()
	_build_background()
	_build_status_label()
	_build_exp_bar()
	_build_upgrade_ui()
	_build_levelup_label()
	_apply_korean_font()
	_build_merc()
	_spawn_enemy()
	if verify_mode:
		Engine.time_scale = 8.0  # 검증 시간 단축 (수치는 그대로, 시간만 가속)


func _process(delta: float) -> void:
	if verify_mode:
		elapsed += delta  # time_scale 적용된 게임 시간(초)

	_update_status()

	if merc.state == DEAD:
		_update_merc_revive(delta)
		_update_background(delta)
		return

	# 적 등장 대기
	if enemy.is_empty():
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_spawn_enemy()
		_advance(delta)
		return

	match enemy.state:
		WALK:
			_advance(delta)
			enemy.body.position.x -= ENEMY_APPROACH_SPEED * delta
			_sync_enemy_ui()
			if enemy.body.position.x - merc.body.position.x <= COMBAT_RANGE:
				enemy.state = COMBAT
				merc.state = COMBAT
		COMBAT:
			_combat(delta)
		DEAD:
			pass


# ── 전진/배경 ────────────────────────────────────────────────────
func _advance(delta: float) -> void:
	merc.state = WALK
	_update_background(delta)


func _build_background() -> void:
	# 세로 줄무늬가 왼쪽으로 흘러 전진하는 느낌을 준다.
	for i in range(9):
		var s := ColorRect.new()
		s.color = Color(0.18, 0.20, 0.26)
		s.size = Vector2(18, SCREEN.y)
		s.position = Vector2(i * 90.0, 0)
		s.z_index = -10
		add_child(s)
		bg_stripes.append(s)
	# 바닥선
	var ground := ColorRect.new()
	ground.color = Color(0.10, 0.12, 0.16)
	ground.size = Vector2(SCREEN.x, SCREEN.y - (GROUND_Y + 90))
	ground.position = Vector2(0, GROUND_Y + 90)
	ground.z_index = -9
	add_child(ground)


func _update_background(delta: float) -> void:
	if merc.state != WALK:
		return
	for s in bg_stripes:
		s.position.x -= SCROLL_SPEED * delta
		if s.position.x <= -18.0:
			s.position.x += 9 * 90.0


# ── 용병 ─────────────────────────────────────────────────────────
func _build_merc() -> void:
	var body := ColorRect.new()
	body.color = Color(0.30, 0.65, 0.95)
	body.size = Vector2(60, 90)
	body.position = Vector2(MERC_X, GROUND_Y)
	body.pivot_offset = Vector2(30, 45)   # 확대/강조가 중심에서 일어나게
	add_child(body)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.6)
	hp_bg.size = Vector2(64, 10)
	hp_bg.position = Vector2(MERC_X - 2, GROUND_Y - 18)
	add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.color = Color(0.30, 0.85, 0.40)
	hp_fill.size = Vector2(60, 8)
	hp_fill.position = Vector2(MERC_X, GROUND_Y - 17)
	add_child(hp_fill)

	merc = {
		"body": body, "hp_bg": hp_bg, "hp_fill": hp_fill,
		"max_hp": MERC_MAX_HP, "hp": MERC_MAX_HP,
		"atk": MERC_ATK, "interval": MERC_INTERVAL, "atk_timer": 0.0,
		"state": WALK, "base_x": MERC_X,
	}


# ── 적 ───────────────────────────────────────────────────────────
func _spawn_enemy() -> void:
	var body := ColorRect.new()
	body.color = Color(0.90, 0.40, 0.35)
	body.size = Vector2(54, 74)
	body.position = Vector2(ENEMY_SPAWN_X, GROUND_Y + 16)
	add_child(body)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.6)
	hp_bg.size = Vector2(58, 10)
	hp_bg.position = Vector2(ENEMY_SPAWN_X - 2, GROUND_Y - 2)
	add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.color = Color(0.95, 0.75, 0.20)
	hp_fill.size = Vector2(54, 8)
	hp_fill.position = Vector2(ENEMY_SPAWN_X, GROUND_Y - 1)
	add_child(hp_fill)

	enemy = {
		"body": body, "hp_bg": hp_bg, "hp_fill": hp_fill,
		"max_hp": ENEMY_MAX_HP, "hp": ENEMY_MAX_HP,
		"atk": ENEMY_ATK, "interval": ENEMY_INTERVAL, "atk_timer": 0.0,
		"state": WALK,
	}
	current_enemy_hits = 0
	_sync_enemy_ui()


func _sync_enemy_ui() -> void:
	var bx: float = enemy.body.position.x
	enemy.hp_bg.position.x = bx - 2
	enemy.hp_fill.position.x = bx


# ── 전투 ─────────────────────────────────────────────────────────
func _combat(delta: float) -> void:
	merc.atk_timer += delta
	if merc.atk_timer >= merc.interval:
		merc.atk_timer = 0.0
		_attack(merc, enemy)
		if enemy.hp <= 0:
			_kill_enemy()
			return

	enemy.atk_timer += delta
	if enemy.atk_timer >= enemy.interval:
		enemy.atk_timer = 0.0
		_attack(enemy, merc)
		if merc.hp <= 0:
			_kill_merc()


func _attack(attacker: Dictionary, target: Dictionary) -> void:
	# 피해량 = 공격력 (이번 작업은 단순 계산, 무작위 없음)
	target.hp = max(0, target.hp - attacker.atk)
	if attacker == merc:
		current_enemy_hits += 1
	_update_hp_bar(target)
	_lunge(attacker)
	_flash(target)


func _kill_enemy() -> void:
	kill_count += 1
	var hits := current_enemy_hits
	# 적 처치 → 골드 +5 → 경험치 +5 → 레벨업 확인
	gold += GOLD_PER_KILL
	exp += EXP_PER_KILL
	_check_level_up()
	# 사망 연출 후 제거
	var dying := enemy
	dying.state = DEAD
	var tw := create_tween()
	tw.tween_property(dying.body, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(dying.body, "scale", Vector2(0.6, 0.6), 0.25)
	tw.tween_callback(func() -> void:
		dying.body.queue_free()
		dying.hp_bg.queue_free()
		dying.hp_fill.queue_free())
	enemy = {}
	respawn_timer = RESPAWN_DELAY
	merc.state = WALK
	merc.atk_timer = 0.0
	_update_upgrade_ui()

	if verify_mode:
		_verify_step(hits)


# 현재 레벨에서 다음 레벨까지 필요한 경험치
func _exp_to_next(lv: int) -> int:
	return 20 + lv * 5


func _check_level_up() -> void:
	# 초과 경험치를 버리지 않고 가능한 만큼 레벨업한다.
	while exp >= _exp_to_next(level):
		exp -= _exp_to_next(level)
		_level_up()


func _level_up() -> void:
	level += 1
	merc.atk += LEVEL_ATK_GAIN
	merc.max_hp += LEVEL_HP_GAIN
	merc.hp = merc.max_hp            # 새 최대 체력까지 완전 회복
	_update_hp_bar(merc)
	_update_upgrade_ui()            # 강화 버튼에 현재 공격력 즉시 반영
	_show_level_up_effect()


func _show_level_up_effect() -> void:
	# 레벨업 문구 (전투/입력은 막지 않음)
	levelup_label.text = "레벨 업! %d" % level
	levelup_label.visible = true
	levelup_label.modulate = Color(1, 1, 1, 1)
	levelup_label.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.tween_property(levelup_label, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(levelup_label, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void: levelup_label.visible = false)
	# 용병 강조: 중심에서 크게 부풀었다 복귀 + 금색 번쩍
	if not merc.is_empty():
		var b: ColorRect = merc.body
		b.scale = Vector2.ONE
		b.modulate = Color(2.2, 1.8, 0.5)   # 금색 번쩍
		var t2 := create_tween()
		t2.tween_property(b, "scale", Vector2(1.7, 1.7), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t2.parallel().tween_property(b, "modulate", Color.WHITE, 0.45)
		t2.tween_property(b, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


# ── 검증: TASK_002(골드 강화)와 TASK_003(경험치·레벨업)을 모두 확인 ──
func _verify_step(hits: int) -> void:
	if first_hits == 0:
		first_hits = hits
	# 불변식: 공격력·최대 체력이 강화/레벨 누적과 정확히 일치하는가
	var levelups := level - START_LEVEL
	var expect_atk := MERC_ATK + attack_upgrade_count * ATK_UPGRADE_AMOUNT + levelups * LEVEL_ATK_GAIN
	var expect_maxhp := MERC_MAX_HP + levelups * LEVEL_HP_GAIN
	if merc.atk != expect_atk:
		print("[VERIFY] FAIL atk=%d expected=%d (강화=%d 레벨업=%d)" % [merc.atk, expect_atk, attack_upgrade_count, levelups])
		get_tree().quit(1)
		return
	if merc.max_hp != expect_maxhp:
		print("[VERIFY] FAIL maxhp=%d expected=%d (레벨업=%d)" % [merc.max_hp, expect_maxhp, levelups])
		get_tree().quit(1)
		return
	print("[VERIFY] xp kill=%d level=%d exp=%d/%d atk=%d gold=%d" % [kill_count, level, exp, _exp_to_next(level), merc.atk, gold])

	# TASK_003: 첫 레벨업 상태 확인
	if not v_task003 and level >= START_LEVEL + 1:
		var ok: bool = level == 2 and exp == 0 and _exp_to_next(level) == 30 \
			and merc.max_hp == MERC_MAX_HP + LEVEL_HP_GAIN and merc.hp == merc.max_hp
		if not ok:
			print("[VERIFY] FAIL levelup level=%d exp=%d next=%d maxhp=%d hp=%d" % [level, exp, _exp_to_next(level), merc.max_hp, merc.hp])
			get_tree().quit(1)
			return
		v_task003 = true
		print("[VERIFY] task003 PASS level=2 exp=0/30 maxhp=%d hp=%d atk=%d(직전+1)" % [merc.max_hp, merc.hp, merc.atk])

	# TASK_002: 골드 강화 (수식 검증) → 더 적은 타격으로 처치
	while gold >= atk_upgrade_cost:
		var g0 := gold
		var a0: int = merc.atk
		var c0 := atk_upgrade_cost
		_do_upgrade()
		if gold != g0 - c0 or merc.atk != a0 + ATK_UPGRADE_AMOUNT or atk_upgrade_cost != int(round(c0 * ATK_COST_MULTIPLIER)):
			print("[VERIFY] FAIL upgrade math gold=%d atk=%d cost=%d" % [gold, merc.atk, atk_upgrade_cost])
			get_tree().quit(1)
			return
		print("[VERIFY] upgrade -> atk=%d cost=%d gold=%d 강화횟수=%d" % [merc.atk, atk_upgrade_cost, gold, attack_upgrade_count])
	if not v_task002 and attack_upgrade_count >= 1 and hits < first_hits:
		v_task002 = true
		print("[VERIFY] task002 PASS 강화=%d hits=%d(<%d) atk=%d" % [attack_upgrade_count, hits, first_hits, merc.atk])

	# 두 검증 모두 통과해야 종료 코드 0
	if v_task002 and v_task003:
		print("[VERIFY] ALL PASS kills=%d level=%d atk=%d maxhp=%d" % [kill_count, level, merc.atk, merc.max_hp])
		get_tree().quit(0)
	if kill_count >= 80:
		print("[VERIFY] FAIL incomplete task002=%s task003=%s kills=%d" % [str(v_task002), str(v_task003), kill_count])
		get_tree().quit(1)


func _kill_merc() -> void:
	merc.state = DEAD
	merc.body.modulate = Color(0.5, 0.5, 0.5)
	merc_revive_timer = MERC_DEATH_DELAY
	if verify_mode:
		print("[VERIFY] merc died, reviving")


func _update_merc_revive(delta: float) -> void:
	merc_revive_timer -= delta
	if merc_revive_timer > 0.0:
		return
	# 체력 회복 후 전투 루프 재시작
	merc.hp = merc.max_hp
	merc.atk_timer = 0.0
	merc.body.modulate = Color.WHITE
	_update_hp_bar(merc)
	merc.state = WALK
	if not enemy.is_empty():
		enemy.body.queue_free()
		enemy.hp_bg.queue_free()
		enemy.hp_fill.queue_free()
		enemy = {}
	respawn_timer = RESPAWN_DELAY


# ── 표현(타격감) ─────────────────────────────────────────────────
func _lunge(unit: Dictionary) -> void:
	# 공격 순간 앞으로 짧게 움직였다 복귀
	var body: ColorRect = unit.body
	var dir := 1.0 if unit == merc else -1.0
	var start_x: float = body.position.x
	var tw := create_tween()
	tw.tween_property(body, "position:x", start_x + dir * 22.0, 0.07)
	tw.tween_property(body, "position:x", start_x, 0.10)


func _flash(unit: Dictionary) -> void:
	# 피격 대상이 잠깐 밝아진다
	var body: ColorRect = unit.body
	if unit.get("state", -1) == DEAD:
		return
	body.modulate = Color(2.0, 2.0, 2.0)
	var tw := create_tween()
	tw.tween_property(body, "modulate", Color.WHITE, 0.15)


func _update_hp_bar(unit: Dictionary) -> void:
	var ratio: float = float(unit.hp) / float(unit.max_hp)
	unit.hp_fill.size.x = max(0.0, 60.0 * ratio) if unit == merc else max(0.0, 54.0 * ratio)


# ── 상단 상태 표시 ───────────────────────────────────────────────
func _apply_korean_font() -> void:
	# 웹 기본 폰트에는 한글 글리프가 없어 깨진다. 한글 폰트가 있으면 적용한다.
	# (폰트 파일은 공개 저장소에 커밋하지 않으므로 없으면 그냥 넘어간다.)
	var path := "res://malgun.ttf"
	if not ResourceLoader.exists(path):
		return
	var f: Font = load(path)
	status_label.add_theme_font_override("font", f)
	upgrade_button.add_theme_font_override("font", f)
	levelup_label.add_theme_font_override("font", f)


func _build_status_label() -> void:
	status_label = Label.new()
	status_label.position = Vector2(16, 20)
	status_label.add_theme_font_size_override("font_size", 22)
	add_child(status_label)


func _build_exp_bar() -> void:
	exp_bg = ColorRect.new()
	exp_bg.color = Color(0, 0, 0, 0.5)
	exp_bg.size = Vector2(508, 16)
	exp_bg.position = Vector2(16, 92)
	add_child(exp_bg)

	exp_fill = ColorRect.new()
	exp_fill.color = Color(0.55, 0.45, 0.95)   # 체력 바(초록/노랑)와 구분되는 보라
	exp_fill.size = Vector2(0, 12)
	exp_fill.position = Vector2(18, 94)
	add_child(exp_fill)


func _build_levelup_label() -> void:
	levelup_label = Label.new()
	levelup_label.position = Vector2(0, 300)
	levelup_label.size = Vector2(SCREEN.x, 80)
	levelup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	levelup_label.add_theme_font_size_override("font_size", 52)
	levelup_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	levelup_label.pivot_offset = Vector2(SCREEN.x * 0.5, 40)   # 중심에서 커지게
	levelup_label.visible = false
	add_child(levelup_label)


func _update_status() -> void:
	if status_label == null:
		return
	var enemy_hp := 0
	if not enemy.is_empty():
		enemy_hp = enemy.hp
	var need := _exp_to_next(level)
	status_label.text = "레벨 %d   EXP %d/%d   골드 %d   처치 %d\n용병 HP %d/%d   적 HP %d" % [level, exp, need, gold, kill_count, merc.hp, merc.max_hp, enemy_hp]
	if exp_fill != null:
		exp_fill.size.x = 504.0 * clampf(float(exp) / float(need), 0.0, 1.0)


# ── 골드 강화 (TASK_002) ─────────────────────────────────────────
func _build_upgrade_ui() -> void:
	upgrade_button = Button.new()
	upgrade_button.position = Vector2(20, 812)
	upgrade_button.size = Vector2(500, 116)
	upgrade_button.add_theme_font_size_override("font_size", 26)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	add_child(upgrade_button)
	_update_upgrade_ui()


func _update_upgrade_ui() -> void:
	if upgrade_button == null:
		return
	var cur_atk: int = merc.atk if not merc.is_empty() else MERC_ATK
	upgrade_button.text = "공격력 강화   %d → %d\n비용 %d골드   (보유 %d)" % [cur_atk, cur_atk + ATK_UPGRADE_AMOUNT, atk_upgrade_cost, gold]
	upgrade_button.disabled = gold < atk_upgrade_cost


func _on_upgrade_pressed() -> void:
	if gold < atk_upgrade_cost:
		return
	_do_upgrade()


func _do_upgrade() -> void:
	gold -= atk_upgrade_cost
	merc.atk += ATK_UPGRADE_AMOUNT
	atk_upgrade_cost = int(round(atk_upgrade_cost * ATK_COST_MULTIPLIER))
	attack_upgrade_count += 1
	_update_upgrade_ui()
