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

# ── 전투 특성 (TASK_005) ─────────────────────────────────────────
const POWER_MULT := 2.2       # 강타 피해 배율
const POWER_EVERY := 4        # 4번째 기본 공격마다 강타
const COMBO_MULT := 0.6       # 연격 추가 베기 배율
const COMBO_CHANCE := 0.30
const COUNTER_MULT := 1.2     # 반격 피해 배율
const COUNTER_REDUCE := 0.6   # 반격 발동 시 받는 피해 (×0.6 = 40% 감소)
const COUNTER_CHANCE := 0.25

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

# 전투 특성 상태 (TASK_005)
var trait_points := 0
var power_trait_level := 0      # 강타
var combo_trait_level := 0      # 연격
var counter_trait_level := 0    # 반격
var total_trait_points_earned := 0
var power_attack_counter := 0   # 강타용 기본 공격 카운트
var rng := RandomNumberGenerator.new()
var force_combo := 0            # 0=확률, 1=강제 발동, -1=강제 미발동 (검증용)
var force_counter := 0
var kfont: Font = null         # 한글 폰트 (런타임 생성 라벨에도 적용)

# 특성 UI
var trait_button: Button
var trait_status_label: Label
var trait_panel: Control
var trait_title_label: Label
var power_btn: Button
var combo_btn: Button
var counter_btn: Button
var reset_btn: Button
var notify_label: Label

# 검증 단계 통과 플래그
var v_task002 := false
var v_task003 := false
var v_damage := false
var v_hp := false
var v_def := false
var v_traits := false
var v_phase := 0   # 검증 강화 순서: 0=체력, 1=방어력, 2=공격력


func _ready() -> void:
	verify_mode = "--verify" in OS.get_cmdline_user_args()
	rng.randomize()
	_build_background()
	_build_status_label()
	_build_exp_bar()
	_build_upgrade_ui()
	_build_levelup_label()
	_build_trait_ui()
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
		_merc_basic_attack()
		if enemy.is_empty() or enemy.hp <= 0:
			_kill_enemy()
			return

	enemy.atk_timer += delta
	if enemy.atk_timer >= enemy.interval:
		enemy.atk_timer = 0.0
		_enemy_attack_merc()
		if merc.hp <= 0:
			_kill_merc()
			return
		if not enemy.is_empty() and enemy.hp <= 0:
			_kill_enemy()   # 반격으로 적이 죽은 경우


# ── 피해 공식 (모두 최소 1) ──────────────────────────────────────
func _damage(atk: int, target_def: int) -> int:
	return maxi(1, atk - target_def)

func _power_damage(atk: int, target_def: int) -> int:
	return maxi(1, int(round(atk * POWER_MULT)) - target_def)

func _combo_damage(atk: int, target_def: int) -> int:
	return maxi(1, int(round(atk * COMBO_MULT)) - target_def)

func _counter_damage(atk: int, target_def: int) -> int:
	return maxi(1, int(round(atk * COUNTER_MULT)) - target_def)

func _counter_reduced(base: int) -> int:
	return maxi(1, int(round(base * COUNTER_REDUCE)))


# 강타 카운트: 4번째 기본 공격이면 true (반격·연격은 호출하지 않음)
func _consume_power_attack() -> bool:
	power_attack_counter += 1
	if power_attack_counter >= POWER_EVERY:
		power_attack_counter = 0
		return true
	return false


func _roll_combo() -> bool:
	if force_combo != 0:
		return force_combo == 1
	return rng.randf() < COMBO_CHANCE

func _roll_counter() -> bool:
	if force_counter != 0:
		return force_counter == 1
	return rng.randf() < COUNTER_CHANCE

# 연격 추가 베기가 발동하는 조건 (적이 살아 있어야 함)
func _combo_would_trigger(enemy_alive: bool) -> bool:
	return combo_trait_level > 0 and enemy_alive and _roll_combo()


func _merc_basic_attack() -> void:
	# 우선순위: 강타 발동 확인 → 아니면 일반 공격 → 일반일 때만 연격 판정
	var is_power: bool = power_trait_level > 0 and _consume_power_attack()
	if is_power:
		_lunge(merc, 46.0)
		_enemy_pushback()
		_deal_to_enemy(_power_damage(merc.atk, enemy.defense), "강타", true)
		return
	_lunge(merc)
	_deal_to_enemy(_damage(merc.atk, enemy.defense), "", false)
	if _combo_would_trigger(not enemy.is_empty() and enemy.hp > 0):
		_lunge(merc, 30.0)
		_deal_to_enemy(_combo_damage(merc.atk, enemy.defense), "추가 베기", false)


func _enemy_attack_merc() -> void:
	var base := _damage(enemy.atk, merc.defense)
	var did_counter: bool = counter_trait_level > 0 and _roll_counter()
	var taken := _counter_reduced(base) if did_counter else base
	merc.hp = max(0, merc.hp - taken)
	_update_hp_bar(merc)
	_lunge(enemy)
	_flash(merc)
	_show_damage_at(merc, taken, "방어" if did_counter else "", false)
	# 감소된 피해로도 살아 있으면 즉시 반격
	if did_counter and merc.hp > 0 and not enemy.is_empty():
		enemy.hp = max(0, enemy.hp - _counter_damage(merc.atk, enemy.defense))
		_update_hp_bar(enemy)
		_lunge(merc)
		_flash(enemy)
		_show_damage_at(enemy, _counter_damage(merc.atk, enemy.defense), "반격", false)


func _deal_to_enemy(dmg: int, label: String, big: bool) -> void:
	if enemy.is_empty():
		return
	enemy.hp = max(0, enemy.hp - dmg)
	current_enemy_hits += 1
	_update_hp_bar(enemy)
	_flash(enemy)
	_show_damage_at(enemy, dmg, label, big)


func _enemy_pushback() -> void:
	# 강타 시 적이 짧게 밀렸다 돌아온다
	if enemy.is_empty():
		return
	var b: ColorRect = enemy.body
	var x0: float = b.position.x
	var tw := create_tween()
	tw.tween_property(b, "position:x", x0 + 24.0, 0.08)
	tw.tween_property(b, "position:x", x0, 0.14)


func _show_damage_at(target: Dictionary, dmg: int, label: String, big: bool) -> void:
	# 실제 피해 숫자(+선택적 특성 문구)를 대상 근처에 잠깐 띄운다 (공격마다 한 번)
	var b: ColorRect = target.body
	var lbl := Label.new()
	lbl.text = ("%s -%d" % [label, dmg]) if label != "" else "-%d" % dmg
	lbl.add_theme_font_size_override("font_size", 42 if big else 28)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4) if big else Color(1, 1, 1))
	if kfont != null:
		lbl.add_theme_font_override("font", kfont)
	lbl.position = Vector2(b.position.x - 6, b.position.y - 30)
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 36, 0.55)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
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
	_update_trait_points()          # 10레벨 단위 도달 시 특성 포인트 지급


# ── 전투 특성 포인트 (TASK_005) ──────────────────────────────────
func _update_trait_points() -> void:
	# 지급 총합 = 현재 레벨 ÷ 10 (정수). 누락·중복 없이 차이만 지급.
	var should := level / 10
	if should > total_trait_points_earned:
		trait_points += should - total_trait_points_earned
		total_trait_points_earned = should
		_update_trait_ui()
		if not verify_mode:
			_show_trait_notify()
			_open_trait_panel()


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

	# 기존 검증 통과 후 TASK_005 특성 검증을 1회 실행한다.
	if v_damage and v_hp and v_def and v_task002 and v_task003 and not v_traits:
		_verify_traits()
	# 특성 검증까지 모두 통과 시 종료 코드 0
	if v_damage and v_hp and v_def and v_task002 and v_task003 and v_traits:
		print("[VERIFY] ALL PASS kills=%d lv=%d atk=%d def=%d maxhp=%d (특성 포함)" % [kill_count, level, merc.atk, merc.defense, merc.max_hp])
		get_tree().quit(0)
	if kill_count >= 120:
		_vfail("incomplete dmg=%s hp=%s def=%s t002=%s t003=%s traits=%s kills=%d" % [str(v_damage), str(v_hp), str(v_def), str(v_task002), str(v_task003), str(v_traits), kill_count])


# ── TASK_005 특성 검증 (확률 비의존, 강제 발동 경로) ─────────────
func _verify_traits() -> void:
	var save_level := level

	# 1) 레벨 10 포인트 지급 + 중복 방지
	level = 9
	total_trait_points_earned = 0
	trait_points = 0
	_update_trait_points()
	if total_trait_points_earned != 0 or trait_points != 0:
		_vfail("lv9 earned=%d pts=%d" % [total_trait_points_earned, trait_points]); return
	level = 10
	_update_trait_points()
	if total_trait_points_earned != 1 or trait_points != 1:
		_vfail("lv10 grant earned=%d pts=%d" % [total_trait_points_earned, trait_points]); return
	_update_trait_points()  # 같은 레벨 재호출 → 중복 지급 없어야 함
	if total_trait_points_earned != 1 or trait_points != 1:
		_vfail("dup grant earned=%d pts=%d" % [total_trait_points_earned, trait_points]); return
	print("[VERIFY] trait grant PASS lv10 earned=1 pts=1")

	# 2) 투자 / 무료 초기화
	var gold_b := gold
	var exp_b := exp
	var atk_b: int = merc.atk
	_invest_power()
	if power_trait_level != 1 or trait_points != 0:
		_vfail("invest power lvl=%d pts=%d" % [power_trait_level, trait_points]); return
	_invest_combo()  # 포인트 0이라 변화 없어야 함
	if combo_trait_level != 0:
		_vfail("invest combo with 0pts lvl=%d" % combo_trait_level); return
	_reset_traits()
	if power_trait_level != 0 or combo_trait_level != 0 or counter_trait_level != 0 or trait_points != 1 or power_attack_counter != 0:
		_vfail("reset pwr=%d cmb=%d ctr=%d pts=%d cnt=%d" % [power_trait_level, combo_trait_level, counter_trait_level, trait_points, power_attack_counter]); return
	if gold != gold_b or exp != exp_b or merc.atk != atk_b:
		_vfail("reset changed base gold=%d exp=%d atk=%d" % [gold, exp, merc.atk]); return
	print("[VERIFY] trait invest/reset PASS")

	# 3) 강타: 4번째 기본 공격
	power_trait_level = 1
	combo_trait_level = 0
	counter_trait_level = 0
	power_attack_counter = 0
	var seq: Array = []
	for i in range(5):
		seq.append(_consume_power_attack())
	if seq != [false, false, false, true, false]:
		_vfail("강타 seq=%s" % str(seq)); return
	var pd := _power_damage(merc.atk, 3)
	if pd != maxi(1, int(round(merc.atk * POWER_MULT)) - 3):
		_vfail("강타 dmg=%d" % pd); return
	print("[VERIFY] 강타 PASS 4타째 발동 dmg(atk%d,def3)=%d" % [merc.atk, pd])

	# 4) 연격: 공식 + 강제 발동/미발동 + 죽은 적 가드
	var cdv := _combo_damage(merc.atk, 0)
	if cdv != maxi(1, int(round(merc.atk * COMBO_MULT))):
		_vfail("연격 dmg=%d" % cdv); return
	combo_trait_level = 1
	force_combo = 1
	if not _combo_would_trigger(true):
		_vfail("연격 강제발동 실패"); return
	if _combo_would_trigger(false):  # 첫 공격으로 적이 죽으면 추가 없음
		_vfail("연격 죽은적 발동"); return
	force_combo = -1
	if _combo_would_trigger(true):
		_vfail("연격 강제미발동 실패"); return
	force_combo = 0
	print("[VERIFY] 연격 PASS dmg=%d 강제발동/미발동/죽은적가드" % cdv)

	# 5) 반격: 받는 피해 감소 + 반격 피해 + 강제 발동/미발동
	var base := _damage(ENEMY_ATK, MERC_DEF)   # 6-2=4
	var reduced := _counter_reduced(base)       # round(4*0.6)=2
	if reduced != 2:
		_vfail("반격 감소피해=%d" % reduced); return
	var ctd := _counter_damage(merc.atk, 0)
	if ctd != maxi(1, int(round(merc.atk * COUNTER_MULT))):
		_vfail("반격 dmg=%d" % ctd); return
	counter_trait_level = 1
	force_counter = 1
	if not _roll_counter():
		_vfail("반격 강제발동 실패"); return
	force_counter = -1
	if _roll_counter():
		_vfail("반격 강제미발동 실패"); return
	force_counter = 0
	print("[VERIFY] 반격 PASS 받는피해 %d→%d 반격피해=%d" % [base, reduced, ctd])

	# 6) 충돌: 강타+연격 동시 → 4번째는 강타만, 연격 미발동
	power_trait_level = 1
	combo_trait_level = 1
	power_attack_counter = 0
	force_combo = 1
	var power_on_4th := false
	var combo_on_4th := false
	for i in range(4):
		var is_p := _consume_power_attack() if power_trait_level > 0 else false
		var combo_this: bool = (not is_p) and _combo_would_trigger(true)
		if i == 3:
			power_on_4th = is_p
			combo_on_4th = combo_this
	if not power_on_4th or combo_on_4th:
		_vfail("충돌 4타 강타=%s 연격=%s" % [str(power_on_4th), str(combo_on_4th)]); return
	print("[VERIFY] 충돌규칙 PASS 4타=강타만(연격 미발동)")

	# 검증으로 바꾼 상태 복원
	force_combo = 0
	force_counter = 0
	power_trait_level = 0
	combo_trait_level = 0
	counter_trait_level = 0
	power_attack_counter = 0
	level = save_level
	_update_trait_ui()
	v_traits = true
	print("[VERIFY] task005 특성 ALL PASS")


func _kill_merc() -> void:
	merc.state = DEAD
	merc.body.modulate = Color(0.5, 0.5, 0.5)
	merc_revive_timer = MERC_DEATH_DELAY
	power_attack_counter = 0   # 사망 시 강타 카운트 초기화
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
func _lunge(unit: Dictionary, dist: float = 22.0) -> void:
	# 공격 순간 앞으로 짧게 움직였다 복귀 (강타는 더 크게)
	var body: ColorRect = unit.body
	var dir := 1.0 if unit == merc else -1.0
	var start_x: float = body.position.x
	var tw := create_tween()
	tw.tween_property(body, "position:x", start_x + dir * dist, 0.07)
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
	kfont = load(path)
	_apply_font_recursive(self)


func _apply_font_recursive(node: Node) -> void:
	for c in node.get_children():
		if c is Label or c is Button:
			c.add_theme_font_override("font", kfont)
		_apply_font_recursive(c)


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


# ── 특성 UI (TASK_005) ───────────────────────────────────────────
func _build_trait_ui() -> void:
	trait_status_label = Label.new()
	trait_status_label.position = Vector2(20, 120)
	trait_status_label.add_theme_font_size_override("font_size", 22)
	add_child(trait_status_label)

	trait_button = Button.new()
	trait_button.position = Vector2(372, 114)
	trait_button.size = Vector2(148, 50)
	trait_button.add_theme_font_size_override("font_size", 22)
	trait_button.pressed.connect(_toggle_trait_panel)
	add_child(trait_button)

	notify_label = Label.new()
	notify_label.position = Vector2(0, 430)
	notify_label.size = Vector2(SCREEN.x, 120)
	notify_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notify_label.add_theme_font_size_override("font_size", 27)
	notify_label.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0))
	notify_label.visible = false
	add_child(notify_label)

	_build_trait_panel()
	_update_trait_ui()


func _build_trait_panel() -> void:
	trait_panel = Control.new()
	trait_panel.position = Vector2.ZERO
	trait_panel.size = SCREEN
	trait_panel.z_index = 50
	trait_panel.visible = false
	add_child(trait_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09, 0.96)
	bg.size = SCREEN
	trait_panel.add_child(bg)

	trait_title_label = Label.new()
	trait_title_label.position = Vector2(40, 50)
	trait_title_label.add_theme_font_size_override("font_size", 26)
	trait_panel.add_child(trait_title_label)

	_add_trait_desc("강타 — 4번째 기본 공격마다 220% 내려찍기", 130)
	power_btn = _make_trait_button(175, _invest_power)
	_add_trait_desc("연격 — 기본 공격 시 30% 확률로 60% 추가 베기", 265)
	combo_btn = _make_trait_button(310, _invest_combo)
	_add_trait_desc("반격 — 피격 시 25% 확률로 피해 40% 감소 + 120% 반격", 400)
	counter_btn = _make_trait_button(445, _invest_counter)

	reset_btn = Button.new()
	reset_btn.position = Vector2(40, 560)
	reset_btn.size = Vector2(220, 64)
	reset_btn.add_theme_font_size_override("font_size", 24)
	reset_btn.text = "무료 초기화"
	reset_btn.pressed.connect(_reset_traits)
	trait_panel.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.position = Vector2(280, 560)
	close_btn.size = Vector2(220, 64)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.text = "닫기"
	close_btn.pressed.connect(_close_trait_panel)
	trait_panel.add_child(close_btn)


func _add_trait_desc(text: String, y: float) -> void:
	var l := Label.new()
	l.position = Vector2(40, y)
	l.size = Vector2(460, 40)
	l.add_theme_font_size_override("font_size", 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = text
	trait_panel.add_child(l)


func _make_trait_button(y: float, cb: Callable) -> Button:
	var b := Button.new()
	b.position = Vector2(40, y)
	b.size = Vector2(460, 60)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	trait_panel.add_child(b)
	return b


func _update_trait_ui() -> void:
	if trait_button == null:
		return
	trait_button.text = ("특성 ●%d" % trait_points) if trait_points > 0 else "특성"
	var names: Array = []
	if power_trait_level > 0:
		names.append("강타")
	if combo_trait_level > 0:
		names.append("연격")
	if counter_trait_level > 0:
		names.append("반격")
	trait_status_label.text = "특성: " + ("없음" if names.is_empty() else "·".join(names))
	if trait_title_label == null:
		return
	trait_title_label.text = "전투 특성    보유 포인트 %d" % trait_points
	power_btn.text = "강타  %d/1   [투자]" % power_trait_level
	power_btn.disabled = trait_points <= 0 or power_trait_level >= 1
	combo_btn.text = "연격  %d/1   [투자]" % combo_trait_level
	combo_btn.disabled = trait_points <= 0 or combo_trait_level >= 1
	counter_btn.text = "반격  %d/1   [투자]" % counter_trait_level
	counter_btn.disabled = trait_points <= 0 or counter_trait_level >= 1
	reset_btn.disabled = (power_trait_level + combo_trait_level + counter_trait_level) == 0


func _invest_power() -> void:
	if trait_points > 0 and power_trait_level < 1:
		power_trait_level = 1
		trait_points -= 1
		_update_trait_ui()


func _invest_combo() -> void:
	if trait_points > 0 and combo_trait_level < 1:
		combo_trait_level = 1
		trait_points -= 1
		_update_trait_ui()


func _invest_counter() -> void:
	if trait_points > 0 and counter_trait_level < 1:
		counter_trait_level = 1
		trait_points -= 1
		_update_trait_ui()


func _reset_traits() -> void:
	# 투자 포인트를 모두 보유로 반환하고 전투 카운터 초기화 (무료)
	trait_points += power_trait_level + combo_trait_level + counter_trait_level
	power_trait_level = 0
	combo_trait_level = 0
	counter_trait_level = 0
	power_attack_counter = 0
	_update_trait_ui()


func _toggle_trait_panel() -> void:
	trait_panel.visible = not trait_panel.visible
	if trait_panel.visible:
		_update_trait_ui()


func _open_trait_panel() -> void:
	trait_panel.visible = true
	_update_trait_ui()


func _close_trait_panel() -> void:
	trait_panel.visible = false


func _show_trait_notify() -> void:
	notify_label.text = "전투 특성 포인트 획득!\n강타·연격·반격 중 하나를 선택하세요."
	notify_label.visible = true
	notify_label.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(notify_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: notify_label.visible = false)
