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


func _ready() -> void:
	verify_mode = "--verify" in OS.get_cmdline_user_args()
	_build_background()
	_build_status_label()
	_build_merc()
	_spawn_enemy()
	if verify_mode:
		Engine.time_scale = 8.0  # 검증 시간 단축 (수치는 그대로, 시간만 가속)


func _process(delta: float) -> void:
	if verify_mode:
		elapsed += delta  # time_scale 적용된 게임 시간(초)

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

	_update_status()


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
	_update_hp_bar(target)
	_lunge(attacker)
	_flash(target)


func _kill_enemy() -> void:
	kill_count += 1
	if verify_mode:
		print("[VERIFY] kill=", kill_count, " t=%.1f" % elapsed)
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

	if verify_mode and kill_count >= 6:
		print("[VERIFY] PASS kills=", kill_count, " elapsed=%.1f merc_hp=" % elapsed, merc.hp)
		get_tree().quit(0)


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
func _build_status_label() -> void:
	status_label = Label.new()
	status_label.position = Vector2(16, 24)
	status_label.add_theme_font_size_override("font_size", 22)
	add_child(status_label)


func _update_status() -> void:
	if status_label == null:
		return
	var enemy_hp := 0
	if not enemy.is_empty():
		enemy_hp = enemy.hp
	status_label.text = "처치 %d   용병 HP %d/%d   적 HP %d" % [kill_count, merc.hp, merc.max_hp, enemy_hp]
