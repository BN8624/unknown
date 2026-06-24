# 임시 용병과 임시 적의 자동 전진·자동 전투 루프를 한 화면에서 처리하는 메인 스크립트
extends Node2D

# ── 밸런스 수치 (조정은 모두 여기서) ──────────────────────────────
const MERC_MAX_HP := 100
const MERC_ATK := 10
const MERC_DEF := 2             # 용병 시작 방어력
const MERC_INTERVAL := 1.0      # 용병 공격 간격(초)

const ENEMY_MAX_HP := 30
const ENEMY_ATK := 6            # 방어력 2 도입 상쇄: 6-2=4로 기존 실제 피해 유지
const ENEMY_DEF := 0            # 일반 적 방어력
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

# ── 성장: 체력·방어력 강화 (TASK_004) ────────────────────────────
const HP_UPGRADE_AMOUNT := 20
const HP_UPGRADE_BASE_COST := 20
const HP_COST_MULTIPLIER := 1.4
const DEF_UPGRADE_AMOUNT := 1
const DEF_UPGRADE_BASE_COST := 25
const DEF_COST_MULTIPLIER := 1.4

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
var hp_upgrade_cost := HP_UPGRADE_BASE_COST
var def_upgrade_cost := DEF_UPGRADE_BASE_COST
var atk_button: Button
var hp_button: Button
var def_button: Button
var current_enemy_hits := 0   # 현재 적에게 용병이 가한 타격 수
var first_hits := 0           # 검증용: 첫 적 처치에 든 타격 수
var attack_upgrade_count := 0 # 공격력 강화 횟수 (레벨업 공격력과 구분)
var hp_upgrade_count := 0     # 체력 강화 횟수
var def_upgrade_count := 0    # 방어력 강화 횟수

# 레벨/경험치 상태
var level := START_LEVEL
var exp := 0
var exp_bg: ColorRect
var exp_fill: ColorRect
var levelup_label: Label

# 검증 단계 통과 플래그
var v_task002 := false
var v_task003 := false
var v_damage := false
var v_hp := false
var v_def := false
var v_phase := 0   # 검증 강화 순서: 0=체력, 1=방어력, 2=공격력


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
		"atk": MERC_ATK, "defense": MERC_DEF, "interval": MERC_INTERVAL, "atk_timer": 0.0,
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
		"atk": ENEMY_ATK, "defense": ENEMY_DEF, "interval": ENEMY_INTERVAL, "atk_timer": 0.0,
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


func _damage(atk: int, target_def: int) -> int:
	# 최종 피해 = 공격력 - 대상 방어력, 최소 1
	return maxi(1, atk - target_def)


func _attack(attacker: Dictionary, target: Dictionary) -> void:
	var dmg := _damage(attacker.atk, target.defense)
	target.hp = max(0, target.hp - dmg)
	if attacker == merc:
		current_enemy_hits += 1
	_update_hp_bar(target)
	_lunge(attacker)
	_flash(target)
	_show_damage(target, dmg)


func _show_damage(target: Dictionary, dmg: int) -> void:
	# 실제 피해 숫자를 대상 근처에 잠깐 띄운다 (공격마다 한 번)
	var b: ColorRect = target.body
	var lbl := Label.new()
	lbl.text = "-%d" % dmg
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.position = Vector2(b.position.x + 14, b.position.y - 26)
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 34, 0.5)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)


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


# ── 검증: TASK_002·003·004 를 모두 확인 ──────────────────────────
func _vfail(msg: String) -> void:
	print("[VERIFY] FAIL ", msg)
	get_tree().quit(1)


func _verify_step(hits: int) -> void:
	if first_hits == 0:
		first_hits = hits
	# 불변식: 공격력·최대 체력·방어력이 누적 공식과 정확히 일치하는가
	var levelups := level - START_LEVEL
	var expect_atk := MERC_ATK + attack_upgrade_count * ATK_UPGRADE_AMOUNT + levelups * LEVEL_ATK_GAIN
	var expect_maxhp := MERC_MAX_HP + hp_upgrade_count * HP_UPGRADE_AMOUNT + levelups * LEVEL_HP_GAIN
	var expect_def := MERC_DEF + def_upgrade_count * DEF_UPGRADE_AMOUNT
	if merc.atk != expect_atk:
		_vfail("atk=%d expected=%d (강화=%d 레벨업=%d)" % [merc.atk, expect_atk, attack_upgrade_count, levelups]); return
	if merc.max_hp != expect_maxhp:
		_vfail("maxhp=%d expected=%d (체력강화=%d 레벨업=%d)" % [merc.max_hp, expect_maxhp, hp_upgrade_count, levelups]); return
	if merc.defense != expect_def:
		_vfail("def=%d expected=%d (방어강화=%d)" % [merc.defense, expect_def, def_upgrade_count]); return

	# 피해 계산 함수 검증 (한 번)
	if not v_damage:
		if _damage(ENEMY_ATK, MERC_DEF) == 4 and _damage(ENEMY_ATK, MERC_DEF + 1) == 3 and _damage(4, 10) == 1:
			v_damage = true
			print("[VERIFY] damage PASS 6-2=4, 6-3=3, min=1")
		else:
			_vfail("damage calc 6-2=%d 6-3=%d 4-10=%d" % [_damage(ENEMY_ATK, MERC_DEF), _damage(ENEMY_ATK, MERC_DEF + 1), _damage(4, 10)]); return

	print("[VERIFY] kill=%d lv=%d exp=%d/%d atk=%d def=%d maxhp=%d hp=%d gold=%d" % [kill_count, level, exp, _exp_to_next(level), merc.atk, merc.defense, merc.max_hp, merc.hp, gold])

	# TASK_003: 첫 레벨업 상태 확인
	if not v_task003 and level >= START_LEVEL + 1:
		var ok: bool = level == 2 and exp == 0 and _exp_to_next(level) == 30 and merc.hp == merc.max_hp
		if not ok:
			_vfail("levelup level=%d exp=%d next=%d hp=%d/%d" % [level, exp, _exp_to_next(level), merc.hp, merc.max_hp]); return
		v_task003 = true
		print("[VERIFY] task003 PASS level=2 exp=0/30 완전회복 hp=%d" % merc.hp)

	# TASK_002: 공격력 강화 2회 이상 한 상태에서 더 적은 타격으로 처치
	if not v_task002 and attack_upgrade_count >= 2 and hits < first_hits:
		v_task002 = true
		print("[VERIFY] task002 PASS 공격강화=%d hits=%d(<%d) atk=%d" % [attack_upgrade_count, hits, first_hits, merc.atk])

	# 강화 순서: 0=체력 1회 → 1=방어력 1회 → 2=공격력 여러 번
	if v_phase == 0:
		if gold >= hp_upgrade_cost:
			var g0 := gold
			var mh0: int = merc.max_hp
			var hp0: int = merc.hp
			var c0 := hp_upgrade_cost
			_do_hp_upgrade()
			if gold != g0 - c0 or merc.max_hp != mh0 + HP_UPGRADE_AMOUNT or merc.hp != mini(hp0 + HP_UPGRADE_AMOUNT, merc.max_hp) or hp_upgrade_cost != int(round(c0 * HP_COST_MULTIPLIER)) or hp_upgrade_count != 1:
				_vfail("hp upgrade gold=%d maxhp=%d hp=%d(was %d/%d) cost=%d" % [gold, merc.max_hp, merc.hp, hp0, mh0, hp_upgrade_cost]); return
			v_hp = true
			v_phase = 1
			print("[VERIFY] task004 hp PASS maxhp %d→%d hp %d→%d cost→%d" % [mh0, merc.max_hp, hp0, merc.hp, hp_upgrade_cost])
	elif v_phase == 1:
		if gold >= def_upgrade_cost:
			var g0 := gold
			var d0: int = merc.defense
			var c0 := def_upgrade_cost
			_do_def_upgrade()
			if gold != g0 - c0 or merc.defense != d0 + DEF_UPGRADE_AMOUNT or def_upgrade_cost != int(round(c0 * DEF_COST_MULTIPLIER)) or def_upgrade_count != 1 or _damage(ENEMY_ATK, merc.defense) != 3:
				_vfail("def upgrade def=%d 적피해=%d cost=%d" % [merc.defense, _damage(ENEMY_ATK, merc.defense), def_upgrade_cost]); return
			v_def = true
			v_phase = 2
			print("[VERIFY] task004 def PASS def %d→%d 적피해 4→%d cost→%d" % [d0, merc.defense, _damage(ENEMY_ATK, merc.defense), def_upgrade_cost])
	else:
		while gold >= atk_upgrade_cost:
			var g0 := gold
			var a0: int = merc.atk
			var c0 := atk_upgrade_cost
			_do_atk_upgrade()
			if gold != g0 - c0 or merc.atk != a0 + ATK_UPGRADE_AMOUNT or atk_upgrade_cost != int(round(c0 * ATK_COST_MULTIPLIER)):
				_vfail("atk upgrade gold=%d atk=%d cost=%d" % [gold, merc.atk, atk_upgrade_cost]); return
			print("[VERIFY] atk upgrade -> atk=%d cost=%d gold=%d 강화횟수=%d" % [merc.atk, atk_upgrade_cost, gold, attack_upgrade_count])

	# 모든 검증 통과 시 종료 코드 0
	if v_damage and v_hp and v_def and v_task002 and v_task003:
		print("[VERIFY] ALL PASS kills=%d lv=%d atk=%d def=%d maxhp=%d" % [kill_count, level, merc.atk, merc.defense, merc.max_hp])
		get_tree().quit(0)
	if kill_count >= 120:
		_vfail("incomplete dmg=%s hp=%s def=%s t002=%s t003=%s kills=%d" % [str(v_damage), str(v_hp), str(v_def), str(v_task002), str(v_task003), kill_count])


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
	atk_button.add_theme_font_override("font", f)
	hp_button.add_theme_font_override("font", f)
	def_button.add_theme_font_override("font", f)
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
	status_label.text = "레벨 %d   EXP %d/%d   골드 %d   처치 %d\n용병 HP %d/%d   공격 %d   방어 %d   적 HP %d" % [level, exp, need, gold, kill_count, merc.hp, merc.max_hp, merc.atk, merc.defense, enemy_hp]
	if exp_fill != null:
		exp_fill.size.x = 504.0 * clampf(float(exp) / float(need), 0.0, 1.0)


# ── 골드 강화: 공격력·체력·방어력 (TASK_002·004) ─────────────────
func _build_upgrade_ui() -> void:
	atk_button = _make_upgrade_button(700.0, _on_atk_pressed)
	hp_button = _make_upgrade_button(786.0, _on_hp_pressed)
	def_button = _make_upgrade_button(872.0, _on_def_pressed)
	_update_upgrade_ui()


func _make_upgrade_button(y: float, cb: Callable) -> Button:
	var b := Button.new()
	b.position = Vector2(20, y)
	b.size = Vector2(500, 78)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	add_child(b)
	return b


func _update_upgrade_ui() -> void:
	if atk_button == null:
		return
	var atk: int = merc.atk if not merc.is_empty() else MERC_ATK
	var mhp: int = merc.max_hp if not merc.is_empty() else MERC_MAX_HP
	var df: int = merc.defense if not merc.is_empty() else MERC_DEF
	atk_button.text = "공격력 강화   %d → %d\n비용 %d골드" % [atk, atk + ATK_UPGRADE_AMOUNT, atk_upgrade_cost]
	atk_button.disabled = gold < atk_upgrade_cost
	hp_button.text = "체력 강화   %d → %d\n비용 %d골드" % [mhp, mhp + HP_UPGRADE_AMOUNT, hp_upgrade_cost]
	hp_button.disabled = gold < hp_upgrade_cost
	def_button.text = "방어력 강화   %d → %d\n비용 %d골드" % [df, df + DEF_UPGRADE_AMOUNT, def_upgrade_cost]
	def_button.disabled = gold < def_upgrade_cost


func _on_atk_pressed() -> void:
	if gold >= atk_upgrade_cost:
		_do_atk_upgrade()


func _on_hp_pressed() -> void:
	if gold >= hp_upgrade_cost:
		_do_hp_upgrade()


func _on_def_pressed() -> void:
	if gold >= def_upgrade_cost:
		_do_def_upgrade()


func _do_atk_upgrade() -> void:
	gold -= atk_upgrade_cost
	merc.atk += ATK_UPGRADE_AMOUNT
	atk_upgrade_cost = int(round(atk_upgrade_cost * ATK_COST_MULTIPLIER))
	attack_upgrade_count += 1
	_update_upgrade_ui()


func _do_hp_upgrade() -> void:
	gold -= hp_upgrade_cost
	merc.max_hp += HP_UPGRADE_AMOUNT
	merc.hp = mini(merc.hp + HP_UPGRADE_AMOUNT, merc.max_hp)  # 잃은 체력 유지, 완전 회복 아님
	hp_upgrade_cost = int(round(hp_upgrade_cost * HP_COST_MULTIPLIER))
	hp_upgrade_count += 1
	_update_hp_bar(merc)
	_update_upgrade_ui()


func _do_def_upgrade() -> void:
	gold -= def_upgrade_cost
	merc.defense += DEF_UPGRADE_AMOUNT
	def_upgrade_cost = int(round(def_upgrade_cost * DEF_COST_MULTIPLIER))
	def_upgrade_count += 1
	_update_upgrade_ui()
