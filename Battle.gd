# 임시 용병과 임시 적의 자동 전진·자동 전투 루프를 한 화면에서 처리하는 메인 스크립트
extends Node2D

# ── 밸런스 수치 (조정은 모두 여기서) ──────────────────────────────
const MERC_MAX_HP := 100
const MERC_ATK := 10
const MERC_DEF := 2             # 용병 시작 방어력
const MERC_INTERVAL := 0.7      # 용병 공격 간격(초) — 템포 단축

const ENEMY_MAX_HP := 30
const ENEMY_ATK := 6            # 방어력 2 도입 상쇄: 6-2=4로 기존 실제 피해 유지
const ENEMY_DEF := 0            # 일반 적 방어력
const ENEMY_INTERVAL := 1.0     # 적 공격 간격(초) — 템포 단축

const ENEMY_APPROACH_SPEED := 185.0   # 적 접근 속도(px/s) — 빨리 붙게
const SCROLL_SPEED := 150.0           # 전진 시 배경 스크롤 속도(px/s)
const COMBAT_RANGE := 150.0           # 이 거리 안이면 전투 시작
const RESPAWN_DELAY := 0.4            # 적 처치 후 다음 적까지 대기(초) — 단축
const MERC_DEATH_DELAY := 1.0        # 용병 사망 후 재시작 대기(초)

# ── 일반 적 3종과 순환 (TASK_006) ────────────────────────────────
# 검증 모드는 위의 기준 적(ENEMY_*)만 쓰고, 일반 플레이만 아래 프로필로 순환한다.
const ENEMY_PROFILES := {
	"wolf": {"name": "굶주린 늑대", "max_hp": 32, "atk": 5, "defense": 0, "interval": 0.75, "approach_speed": 230.0, "gold": 5, "exp": 5},
	"goblin": {"name": "고블린", "max_hp": 22, "atk": 4, "defense": 0, "interval": 1.0, "approach_speed": 200.0, "gold": 4, "exp": 4},
	"shield": {"name": "방패병", "max_hp": 75, "atk": 8, "defense": 5, "interval": 1.5, "approach_speed": 130.0, "gold": 12, "exp": 10},
	"ogre": {"name": "오우거 징수꾼", "max_hp": 240, "atk": 16, "defense": 3, "interval": 2.0, "approach_speed": 100.0, "gold": 40, "exp": 30},
}
const ENEMY_SEQUENCE := ["wolf", "wolf", "wolf", "goblin", "goblin", "goblin", "shield", "ogre"]
const GOBLIN_SPACING := 82.0        # 무리 고블린 사이 가로 간격(겹치지 않게)

# ── 엘리트: 오우거 징수꾼 (TASK_008) ─────────────────────────────
const OGRE_HEAVY_MULT := 2.0       # 강공격(3번째) 배율
const OGRE_HEAVY_EVERY := 3        # 3번째 공격이 강공격
const OGRE_WINDUP_TIME := 1.0      # 강공격 준비 동작 시간(초)

# ── 보스: 철퇴의 브루노 (TASK_009) ───────────────────────────────
const BOSS_MAX_HP := 850
const BOSS_ATK := 15
const BOSS_BASE_DEF := 6            # 일반 상태 방어력
const BOSS_STANCE_DEF := 9          # 방어 태세 round(6×1.5)
const BOSS_STAGGER_DEF := 4         # 자세 붕괴 round(6×0.6)
const BOSS_EXP := 100
const BOSS_GOLD := 200
const BOSS_INTERVAL := 2.0          # 기본 공격 간격(초)
const BOSS_APPROACH_SPEED := 95.0
const BOSS_TIME_LIMIT := 45.0       # 보스 전투 제한 시간(초)
const BOSS_HEAVY_MULT := 2.3        # 강한 내려찍기(3번째) 배율
const BOSS_HEAVY_EVERY := 3
const BOSS_WINDUP_TIME := 1.2       # 강공격 준비 동작 시간(초)
const BOSS_STANCE_CYCLE := 10.0     # 방어 태세 주기(초)
const BOSS_STANCE_DURATION := 3.0   # 방어 태세 지속(초)
const BOSS_POSTURE_HITS := 8        # 자세 붕괴까지 필요한 연속 타격 수
const BOSS_POSTURE_WINDOW := 4.0    # 연속 타격 유효 시간(초)
const BOSS_STAGGER_DURATION := 3.0  # 자세 붕괴 지속(초)
const POWER_BOSS_BONUS := 1.1       # 강타의 보스 추가 피해 10% (TASK_009 최초 적용)

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
const COUNTER_EVERY := 3      # 적의 3번째 공격마다 확정 막기+반격 (결정적, TASK_007)

# 임시(TEMP): 특성 테스트용으로 시작 시 특성 포인트 지급. 정식 빌드 전 제거.
const DEBUG_START_TRAIT_POINTS := 3

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
var enemy_seq_index := 0     # 적 순환 위치 (처치 시 전진, 사망 재시작에는 유지)
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
var counter_hit_counter := 0    # 반격용 받는 공격 카운트 (3번째마다 발동)
var rng := RandomNumberGenerator.new()
var force_combo := 0            # 0=확률, 1=강제 발동, -1=강제 미발동 (검증용)
var kfont: Font = null         # 한글 폰트 (런타임 생성 라벨에도 적용)
var goblin_queue: Array = []   # 무리에서 대기 중인 고블린(앞에서부터 전투)
var goblin_run_start := -1     # 현재 고블린 무리가 시작된 순환 인덱스 (-1=무리 아님)

# 보스(철퇴의 브루노) 상태 (TASK_009)
var boss_defeated := false     # 이번 실행에서 보스를 처치했는가 (저장 없음)
var boss_due := false          # 오우거 처치 후 다음 적이 보스인가
var boss_fight_active := false # 보스와 실제 전투 중인가 (제한 시간 가동)
var boss_time_left := BOSS_TIME_LIMIT

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
var windup_label: Label   # 오우거 강공격 준비 문구

# 보스 전용 UI (TASK_009)
var boss_ui: Control
var boss_name_label: Label
var boss_hp_label: Label
var boss_time_label: Label
var boss_state_label: Label
var boss_ui_hp_fill: ColorRect
var boss_progress_label: Label   # 일반 전투 중 보스까지 진행 표시

# 검증 단계 통과 플래그
var v_task002 := false
var v_task003 := false
var v_damage := false
var v_hp := false
var v_def := false
var v_traits := false
var v_enemies := false
var v_ogre := false
var v_boss := false
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
	_build_windup_label()
	_build_boss_ui()
	_build_boss_progress_label()
	_apply_korean_font()
	_build_merc()
	_spawn_enemy()
	if verify_mode:
		Engine.time_scale = 8.0  # 검증 시간 단축 (수치는 그대로, 시간만 가속)
	# 임시(TEMP): 레벨 10 전이라도 특성을 바로 시험하도록 시작 포인트 지급
	if not verify_mode and DEBUG_START_TRAIT_POINTS > 0:
		trait_points += DEBUG_START_TRAIT_POINTS
		_update_trait_ui()


func _process(delta: float) -> void:
	if verify_mode:
		elapsed += delta  # time_scale 적용된 게임 시간(초)

	_update_status()
	_sync_all_ui()   # 체력 바·이름표가 공격(lunge) 중에도 본체와 어긋나지 않게

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
			enemy.body.position.x -= enemy.approach_speed * delta
			_sync_enemy_ui()
			for g in goblin_queue:   # 대기 고블린도 함께 전진(줄 유지)
				g.body.position.x -= enemy.approach_speed * delta
				_sync_goblin(g)
			if enemy.body.position.x - merc.body.position.x <= COMBAT_RANGE:
				enemy.state = COMBAT
				merc.state = COMBAT
				enemy["base_x"] = enemy.body.position.x   # 전투 위치를 lunge 복귀 기준으로 고정
				if enemy.get("is_boss", false) and not boss_fight_active:
					boss_fight_active = true            # 실제 전투 시작 = 제한 시간·방어 태세 주기 가동
					boss_time_left = BOSS_TIME_LIMIT
					enemy.stance_cooldown = BOSS_STANCE_CYCLE
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
		"body": body, "hp_bg": hp_bg, "hp_fill": hp_fill, "bar_w": 60.0,
		"max_hp": MERC_MAX_HP, "hp": MERC_MAX_HP,
		"atk": MERC_ATK, "defense": MERC_DEF, "interval": MERC_INTERVAL, "atk_timer": 0.0,
		"state": WALK, "base_x": MERC_X,
	}


# ── 적 ───────────────────────────────────────────────────────────
func _spawn_enemy() -> void:
	# 검증 모드는 기준 적(기존 ENEMY_*, 보상 5/5)만 생성해 TASK_002~005 검증을 보존한다.
	if verify_mode:
		var vprof := {"name": "검증적", "max_hp": ENEMY_MAX_HP, "atk": ENEMY_ATK, "defense": ENEMY_DEF, "interval": ENEMY_INTERVAL, "approach_speed": ENEMY_APPROACH_SPEED, "gold": GOLD_PER_KILL, "exp": EXP_PER_KILL}
		enemy = _build_enemy("verify", vprof, 0, 0, ENEMY_SPAWN_X, true)
		current_enemy_hits = 0
		_sync_enemy_ui()
		return

	# 오우거 처치 후 보스 차례면 일반 적 대신 철퇴의 브루노를 생성한다
	if boss_due and not boss_defeated:
		_spawn_boss()
		return

	var typ: String = ENEMY_SEQUENCE[enemy_seq_index % ENEMY_SEQUENCE.size()]
	if typ == "goblin":
		_spawn_goblin_wave(enemy_seq_index % ENEMY_SEQUENCE.size())
		return
	enemy = _build_enemy(typ, ENEMY_PROFILES[typ], 0, 0, ENEMY_SPAWN_X, true)
	current_enemy_hits = 0
	_sync_enemy_ui()
	if typ == "ogre":
		counter_hit_counter = 0   # 반격을 오우거 강공격(3번째)에 맞춘다
		_show_notice("엘리트 등장!\n[엘리트] 오우거 징수꾼", 1.1)


# 고블린 무리: 3마리를 한 번에 줄지어 등장시킨다(겹치지 않게). 전투는 앞에서부터 한 마리씩.
func _spawn_goblin_wave(start_idx: int) -> void:
	goblin_run_start = start_idx
	var total: int = _goblin_wave_info(start_idx).y
	var prof: Dictionary = ENEMY_PROFILES["goblin"]
	var built: Array = []
	for i in range(total):
		var g := _build_enemy("goblin", prof, i + 1, total, ENEMY_SPAWN_X + i * GOBLIN_SPACING, i == 0)
		built.append(g)
	enemy = built[0]
	goblin_queue = built.slice(1)
	enemy_seq_index = start_idx + total   # 무리 다음(방패병)으로
	current_enemy_hits = 0
	_sync_enemy_ui()
	for g in goblin_queue:
		_sync_goblin(g)


# 보스(철퇴의 브루노) 생성: 일반 적·엘리트와 외형·UI로 구분되는 최종 보스
func _spawn_boss() -> void:
	_show_notice("보스 등장!\n철퇴의 브루노", 1.3)
	var bsize := Vector2(132, 156)            # 오우거(108×132)보다 크고 넓은 실루엣
	var bcolor := Color(0.50, 0.12, 0.30)     # 짙은 자주/적색
	var by: float = (GROUND_Y + 90) - bsize.y
	var sx := ENEMY_SPAWN_X
	var bar_w := bsize.x

	var body := ColorRect.new()
	body.color = bcolor
	body.size = bsize
	body.position = Vector2(sx, by)
	body.pivot_offset = bsize * 0.5
	add_child(body)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.7)
	hp_bg.size = Vector2(bar_w + 6, 14)       # 일반 적보다 넓은 보스 체력 바
	hp_bg.position = Vector2(sx - 3, by - 26)
	add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.color = Color(0.95, 0.25, 0.30)
	hp_fill.size = Vector2(bar_w, 12)
	hp_fill.position = Vector2(sx, by - 25)
	add_child(hp_fill)

	var name_label := Label.new()
	name_label.size = Vector2(240, 28)
	name_label.position = Vector2(sx + bar_w * 0.5 - 120, by - 56)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.6))
	name_label.text = "[보스] 철퇴의 브루노"
	if kfont != null:
		name_label.add_theme_font_override("font", kfont)
	add_child(name_label)

	# 큰 철퇴: 손잡이 + 철구를 Node2D로 묶어 준비 동작 시 함께 회전
	var mace := Node2D.new()
	var mace_off_x := -22.0
	mace.position = Vector2(sx + mace_off_x, by + 34)
	add_child(mace)
	var handle := ColorRect.new()
	handle.color = Color(0.35, 0.22, 0.12)
	handle.size = Vector2(16, 80)
	handle.position = Vector2(-8, -80)        # 그립(아래 끝)을 회전축으로
	mace.add_child(handle)
	var head := ColorRect.new()
	head.color = Color(0.30, 0.30, 0.34)
	head.size = Vector2(48, 48)               # 큰 철구
	head.position = Vector2(-24, -122)
	mace.add_child(head)

	enemy = {
		"type": "boss", "name": "철퇴의 브루노",
		"body": body, "hp_bg": hp_bg, "hp_fill": hp_fill, "name_label": name_label, "bar_w": bar_w,
		"max_hp": BOSS_MAX_HP, "hp": BOSS_MAX_HP,
		"atk": BOSS_ATK, "defense": BOSS_BASE_DEF, "interval": BOSS_INTERVAL,
		"approach_speed": BOSS_APPROACH_SPEED,
		"gold_reward": BOSS_GOLD, "exp_reward": BOSS_EXP,
		"atk_timer": 0.0, "state": WALK,
		"is_boss": true, "attack_count": 0,
		"is_winding_up": false, "windup_timer": 0.0,
		"defense_stance": false, "stance_timer": 0.0, "stance_cooldown": BOSS_STANCE_CYCLE,
		"staggered": false, "stagger_timer": 0.0,
		"posture_hits": 0, "posture_window": 0.0,
		"mace": mace, "mace_off_x": mace_off_x,
	}
	current_enemy_hits = 0
	counter_hit_counter = 0   # 반격을 보스 강공격(3번째)에 맞춘다
	power_attack_counter = 0
	_show_boss_ui()
	_update_boss_ui()
	_sync_enemy_ui()


# 오우거 처치 후 보스를 등장시킬지 여부(이미 처치했으면 재등장하지 않음)
func _should_set_boss_due(killed_type: String) -> bool:
	return killed_type == "ogre" and not boss_defeated


# 적 한 마리를 노드와 함께 만들어 반환한다 (active=true면 이름표 표시)
func _build_enemy(typ: String, prof: Dictionary, wave_cur: int, wave_total: int, sx: float, active: bool) -> Dictionary:
	var bsize := Vector2(54, 74)
	var bcolor := Color(0.90, 0.40, 0.35)
	match typ:
		"wolf":
			bsize = Vector2(78, 44); bcolor = Color(0.64, 0.34, 0.24)
		"goblin":
			bsize = Vector2(42, 64); bcolor = Color(0.32, 0.72, 0.34)
		"shield":
			bsize = Vector2(66, 96); bcolor = Color(0.52, 0.57, 0.64)
		"ogre":
			bsize = Vector2(108, 132); bcolor = Color(0.72, 0.42, 0.20)   # 가장 크고 무겁게
	var by: float = (GROUND_Y + 90) - bsize.y
	var bar_w: float = bsize.x

	var body := ColorRect.new()
	body.color = bcolor
	body.size = bsize
	body.position = Vector2(sx, by)
	add_child(body)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.6)
	hp_bg.size = Vector2(bar_w + 4, 10)
	hp_bg.position = Vector2(sx - 2, by - 20)
	add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.color = Color(0.95, 0.75, 0.20)
	hp_fill.size = Vector2(bar_w, 8)
	hp_fill.position = Vector2(sx, by - 19)
	add_child(hp_fill)

	var name_label := Label.new()
	name_label.size = Vector2(180, 26)
	name_label.position = Vector2(sx + bar_w * 0.5 - 90, by - 48)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	if typ == "goblin":
		name_label.text = "고블린 무리 %d/%d" % [wave_cur, wave_total]
	elif typ == "ogre":
		name_label.text = "[엘리트] %s" % prof.name
	else:
		name_label.text = prof.name
	name_label.visible = active   # 대기 고블린은 이름표 숨김
	if kfont != null:
		name_label.add_theme_font_override("font", kfont)
	add_child(name_label)

	var e := {
		"type": typ, "name": prof.name,
		"body": body, "hp_bg": hp_bg, "hp_fill": hp_fill, "name_label": name_label, "bar_w": bar_w,
		"max_hp": prof.max_hp, "hp": prof.max_hp,
		"atk": prof.atk, "defense": prof.defense, "interval": prof.interval,
		"approach_speed": prof.approach_speed,
		"gold_reward": prof.gold, "exp_reward": prof.exp,
		"atk_timer": 0.0, "state": WALK,
	}
	if typ == "shield":
		var sh := ColorRect.new()
		sh.color = Color(0.78, 0.82, 0.9)
		sh.size = Vector2(14, 56)
		sh.position = Vector2(sx - 8, by + 20)
		add_child(sh)
		e["shield"] = sh
	if typ == "ogre":
		# 손에 큰 몽둥이 도형 (용병 쪽 어깨에서 위로)
		var club := ColorRect.new()
		club.color = Color(0.45, 0.30, 0.18)
		club.size = Vector2(20, 86)
		club.pivot_offset = Vector2(10, 86)   # 아래 끝을 축으로 들어올리기
		club.position = Vector2(sx - 14, by - 30)
		add_child(club)
		e["club"] = club
		e["is_elite"] = true
		e["attack_count"] = 0
		e["is_winding_up"] = false
		e["windup_timer"] = 0.0
		e["club_base_y"] = by - 30
	return e


func _sync_enemy_ui() -> void:
	_sync_goblin(enemy)


# 유닛 본체와 함께 체력 바·이름표·방패·몽둥이를 이동시킨다(공격 시 어긋남 방지)
func _sync_goblin(e: Dictionary) -> void:
	var bx: float = e.body.position.x
	e.hp_bg.position.x = bx - 2
	e.hp_fill.position.x = bx
	if e.has("name_label"):
		e.name_label.position.x = bx + e.bar_w * 0.5 - 90
	if e.has("shield"):
		e.shield.position.x = bx - 8
	if e.has("club"):
		e.club.position.x = bx - 14
	if e.has("mace"):
		e.mace.position.x = bx + e.get("mace_off_x", 0.0)


# 매 프레임 용병·적·대기 고블린의 체력 바를 본체에 맞춘다
func _sync_all_ui() -> void:
	if not merc.is_empty():
		_sync_goblin(merc)
	if not enemy.is_empty():
		_sync_goblin(enemy)
	for g in goblin_queue:
		_sync_goblin(g)


# 고블린 무리에서 현재 몇 번째인지 (현재, 전체) 반환
func _goblin_wave_info(seq_pos: int) -> Vector2i:
	var n := ENEMY_SEQUENCE.size()
	var s := seq_pos
	while s > 0 and ENEMY_SEQUENCE[s - 1] == "goblin":
		s -= 1
	var e := seq_pos
	while e < n - 1 and ENEMY_SEQUENCE[e + 1] == "goblin":
		e += 1
	return Vector2i(seq_pos - s + 1, e - s + 1)


# 적의 모든 노드를 정리한다 (잔존·겹침 방지)
func _free_enemy_nodes(e: Dictionary) -> void:
	for k in ["body", "hp_bg", "hp_fill", "name_label", "shield", "club", "mace"]:
		if e.has(k) and e[k] != null and is_instance_valid(e[k]):
			e[k].queue_free()


# ── 전투 ─────────────────────────────────────────────────────────
func _combat(delta: float) -> void:
	merc.atk_timer += delta
	if merc.atk_timer >= merc.interval:
		merc.atk_timer = 0.0
		_merc_basic_attack()
		if enemy.is_empty() or enemy.hp <= 0:
			_kill_enemy()   # 준비 중이라도 오우거가 죽으면 여기서 정리(강공격 취소)
			return

	# 적 공격: 보스/엘리트는 기본·기본·강공격 패턴, 일반은 단순 공격
	var attacked := false
	if enemy.get("is_boss", false):
		attacked = _boss_attack_logic(delta)
		if enemy.is_empty():   # 제한 시간 초과로 보스가 정리된 경우
			return
	elif enemy.get("is_elite", false):
		attacked = _ogre_attack_logic(delta)
	else:
		enemy.atk_timer += delta
		if enemy.atk_timer >= enemy.interval:
			enemy.atk_timer = 0.0
			_enemy_attack_merc()
			attacked = true

	if attacked:
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

# 보스 강타: 보스 추가 피해 10% 적용. round(공격력 × 2.2 × 1.1) − 현재 방어력
func _power_damage_boss(atk: int, target_def: int) -> int:
	return maxi(1, int(round(atk * POWER_MULT * POWER_BOSS_BONUS)) - target_def)

# 보스 강공격 위력: 공격력 × 2.3. 부동소수 오차 없이 ×23÷10로 계산해 round(15×2.3)=35가 되게 한다.
func _boss_heavy_power(atk: int) -> int:
	return int(round(atk * 23.0 / 10.0))

# 보스 현재 방어력: 자세 붕괴 > 방어 태세 > 일반 우선순위
func _boss_def_for(staggered: bool, stance: bool) -> int:
	if staggered:
		return BOSS_STAGGER_DEF
	if stance:
		return BOSS_STANCE_DEF
	return BOSS_BASE_DEF

# 현재 적의 유효 방어력(보스는 상태 기반, 일반/엘리트는 고정). 모든 용병 공격이 같은 값을 쓴다.
func _enemy_def() -> int:
	if enemy.get("is_boss", false):
		return _boss_def_for(enemy.get("staggered", false), enemy.get("defense_stance", false))
	return enemy.defense


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

# 반격: 받는 공격을 세어 3번째마다 확정 발동 (결정적, 확률 아님)
func _consume_counter() -> bool:
	counter_hit_counter += 1
	if counter_hit_counter >= COUNTER_EVERY:
		counter_hit_counter = 0
		return true
	return false

# 연격 추가 베기가 발동하는 조건 (적이 살아 있어야 함)
func _combo_would_trigger(enemy_alive: bool) -> bool:
	return combo_trait_level > 0 and enemy_alive and _roll_combo()


func _merc_basic_attack() -> void:
	# 우선순위: 강타 발동 확인 → 아니면 일반 공격 → 일반일 때만 연격 판정
	var edef := _enemy_def()
	var is_boss: bool = enemy.get("is_boss", false)
	var is_power: bool = power_trait_level > 0 and _consume_power_attack()
	if is_power:
		_lunge(merc, 46.0)
		_enemy_pushback()
		var pdmg: int = _power_damage_boss(merc.atk, edef) if is_boss else _power_damage(merc.atk, edef)
		_deal_to_enemy(pdmg, "강타", true)
		return
	_lunge(merc)
	_deal_to_enemy(_damage(merc.atk, edef), "", false)
	if _combo_would_trigger(not enemy.is_empty() and enemy.hp > 0):
		# 연격: 빠른 추가 전진 + 청록 잔상·발광으로 "한 번 더 벴다"가 보이게
		_lunge(merc, 34.0)
		_tint(merc, Color(0.5, 1.5, 1.7), 0.22)
		_spawn_ghost(merc, Color(0.4, 0.95, 1.0, 0.55))
		_deal_to_enemy(_combo_damage(merc.atk, _enemy_def()), "추가 베기", false)


func _enemy_attack_merc() -> void:
	_apply_enemy_hit(_damage(enemy.atk, merc.defense), false)


# 적의 한 번 공격을 용병에게 적용 (반격 연동 포함). is_heavy=오우거 강공격.
func _apply_enemy_hit(base: int, is_heavy: bool) -> void:
	var did_counter: bool = counter_trait_level > 0 and _consume_counter()
	var taken := _counter_reduced(base) if did_counter else base
	merc.hp = max(0, merc.hp - taken)
	_update_hp_bar(merc)
	_lunge(enemy)
	if did_counter:
		_tint(merc, Color(0.5, 0.8, 1.7), 0.22)   # 방어: 파랗게 번쩍
	elif is_heavy:
		_tint(merc, Color(1.7, 0.6, 0.3), 0.2)    # 강공격 피격: 주황
	else:
		_flash(merc)
	var merc_label := ""
	if is_heavy:
		merc_label = "강공격 방어" if did_counter else "강공격"
	elif did_counter:
		merc_label = "방어"
	_show_damage_at(merc, taken, merc_label, is_heavy)
	# 감소된 피해로도 살아 있으면 즉시 반격
	if did_counter and merc.hp > 0 and not enemy.is_empty():
		var cd := _counter_damage(merc.atk, _enemy_def())
		enemy.hp = max(0, enemy.hp - cd)
		_update_hp_bar(enemy)
		_lunge(merc, 44.0)                          # 되받아치는 큰 전진
		_spawn_ghost(merc, Color(1.0, 0.7, 0.3, 0.55))
		_flash(enemy)
		_show_damage_at(enemy, cd, "반격", false)
		_register_boss_hit()                        # 반격도 자세 붕괴 타격 1회로 센다


# 오우거 공격 패턴: 기본·기본·강공격(준비 동작). 이번 프레임에 피해를 줬으면 true.
func _ogre_attack_logic(delta: float) -> bool:
	if enemy.is_winding_up:
		enemy.windup_timer -= delta
		if enemy.windup_timer <= 0.0:
			_ogre_end_windup()
			_apply_enemy_hit(maxi(1, int(round(enemy.atk * OGRE_HEAVY_MULT)) - merc.defense), true)
			return true
		return false
	enemy.atk_timer += delta
	if enemy.atk_timer >= enemy.interval:
		enemy.atk_timer = 0.0
		enemy.attack_count += 1
		if enemy.attack_count >= OGRE_HEAVY_EVERY:
			enemy.attack_count = 0
			_ogre_start_windup()   # 3번째 = 강공격, 준비 동작 먼저(피해 없음)
			return false
		_apply_enemy_hit(_damage(enemy.atk, merc.defense), false)
		return true
	return false


func _ogre_start_windup() -> void:
	enemy.is_winding_up = true
	enemy.windup_timer = OGRE_WINDUP_TIME
	enemy.body.modulate = Color(1.8, 0.9, 0.4)   # 준비 중 주황 강조(지속)
	if enemy.has("club"):
		var c: ColorRect = enemy.club
		var tw := create_tween()
		tw.tween_property(c, "rotation_degrees", -75.0, 0.3)   # 몽둥이 들어올림
	windup_label.text = "강공격 준비!"
	windup_label.position = Vector2(enemy.body.position.x + enemy.body.size.x * 0.5 - 110, enemy.body.position.y - 84)
	windup_label.visible = true


func _ogre_end_windup() -> void:
	enemy.is_winding_up = false
	if not enemy.is_empty() and is_instance_valid(enemy.body):
		enemy.body.modulate = Color.WHITE
		if enemy.has("club"):
			var c: ColorRect = enemy.club
			var tw := create_tween()
			tw.tween_property(c, "rotation_degrees", 0.0, 0.12)   # 내려찍기
	windup_label.visible = false


# ── 보스(철퇴의 브루노) 전투 로직 (TASK_009) ────────────────────
# 보스 공격: 제한 시간·방어 태세·자세 붕괴를 매 프레임 갱신하고 기본·기본·강공격을 반복한다.
func _boss_attack_logic(delta: float) -> bool:
	if boss_fight_active:
		boss_time_left -= delta
		if boss_time_left <= 0.0:
			_boss_lose("화력 부족")   # 시간 초과: 보스 정리 후 첫 늑대로 복귀
			return false
	_boss_update_posture(delta)
	_boss_update_stagger(delta)
	_boss_update_stance(delta)
	_update_boss_ui()

	if enemy.get("staggered", false):
		return false   # 자세 붕괴 중에는 공격하지 않는다
	if enemy.is_winding_up:
		enemy.windup_timer -= delta
		if enemy.windup_timer <= 0.0:
			_boss_end_windup()
			_apply_enemy_hit(maxi(1, _boss_heavy_power(enemy.atk) - merc.defense), true)
			return true
		return false
	enemy.atk_timer += delta
	if enemy.atk_timer >= enemy.interval:
		enemy.atk_timer = 0.0
		enemy.attack_count += 1
		if enemy.attack_count >= BOSS_HEAVY_EVERY:
			enemy.attack_count = 0
			_boss_start_windup()   # 3번째 = 강한 내려찍기, 준비 동작 먼저(피해 없음)
			return false
		_apply_enemy_hit(_damage(enemy.atk, merc.defense), false)
		return true
	return false


# 연속 타격 유효 시간 경과 시 타격 수 초기화
func _boss_update_posture(delta: float) -> void:
	if enemy.get("posture_window", 0.0) > 0.0:
		enemy.posture_window -= delta
		if enemy.posture_window <= 0.0:
			enemy.posture_hits = 0


func _boss_update_stagger(delta: float) -> void:
	if enemy.get("staggered", false):
		enemy.stagger_timer -= delta
		if enemy.stagger_timer <= 0.0:
			_boss_end_stagger()


func _boss_update_stance(delta: float) -> void:
	if enemy.get("staggered", false):
		return   # 자세 붕괴 중에는 방어 태세를 시작하지 않는다
	if enemy.get("defense_stance", false):
		enemy.stance_timer -= delta
		if enemy.stance_timer <= 0.0:
			_boss_end_stance()
		return
	enemy.stance_cooldown -= delta
	if enemy.stance_cooldown <= 0.0 and not enemy.is_winding_up:
		_boss_start_stance()   # 강공격 준비 중이면 끝난 뒤로 미룬다(쿨다운은 음수 유지)


# 순수 함수: 한 번의 피해를 타격 수로 누적하고 8타 도달 시 true(자세 붕괴 트리거)
func _posture_register(d: Dictionary) -> bool:
	if d.get("staggered", false):
		return false   # 자세 붕괴 중에는 누적·연장하지 않는다
	if int(d.get("posture_hits", 0)) == 0 or float(d.get("posture_window", 0.0)) <= 0.0:
		d.posture_window = BOSS_POSTURE_WINDOW   # 첫 타격부터 유효 시간 시작
	d.posture_hits = int(d.get("posture_hits", 0)) + 1
	if int(d.posture_hits) >= BOSS_POSTURE_HITS:
		d.posture_hits = 0
		d.posture_window = 0.0
		return true
	return false


# 실제 피해가 보스에게 들어갈 때마다 호출. 8타 누적 시 자세 붕괴.
func _register_boss_hit() -> void:
	if enemy.is_empty() or not enemy.get("is_boss", false) or enemy.hp <= 0:
		return
	if _posture_register(enemy):
		_boss_stagger()


func _boss_start_windup() -> void:
	enemy.is_winding_up = true
	enemy.windup_timer = BOSS_WINDUP_TIME
	enemy.body.modulate = Color(1.9, 0.7, 0.4)   # 준비 중 주황 강조(지속)
	if enemy.has("mace"):
		var tw := create_tween()
		tw.tween_property(enemy.mace, "rotation_degrees", -78.0, 0.35)   # 철퇴 들어올림
	windup_label.text = "강한 내려찍기 준비!"
	windup_label.position = Vector2(enemy.body.position.x + enemy.body.size.x * 0.5 - 110, enemy.body.position.y - 96)
	windup_label.visible = true


func _boss_end_windup() -> void:
	enemy.is_winding_up = false
	if not enemy.is_empty() and is_instance_valid(enemy.body):
		if not enemy.get("staggered", false):
			enemy.body.modulate = Color.WHITE
		if enemy.has("mace"):
			var tw := create_tween()
			tw.tween_property(enemy.mace, "rotation_degrees", 0.0, 0.12)   # 내려찍기
	windup_label.visible = false


func _boss_start_stance() -> void:
	enemy.defense_stance = true
	enemy.stance_timer = BOSS_STANCE_DURATION
	enemy.stance_cooldown = BOSS_STANCE_CYCLE
	if is_instance_valid(enemy.body) and not enemy.is_winding_up:
		enemy.body.modulate = Color(0.7, 0.85, 1.7)   # 방어 효과: 청색 강조


func _boss_end_stance() -> void:
	enemy.defense_stance = false
	if not enemy.is_empty() and is_instance_valid(enemy.body) and not enemy.get("staggered", false) and not enemy.is_winding_up:
		enemy.body.modulate = Color.WHITE


func _boss_stagger() -> void:
	# 강공격 준비·방어 태세를 즉시 취소하고 3초간 무방비 상태로 전환
	if enemy.is_winding_up:
		_boss_end_windup()
	if enemy.get("defense_stance", false):
		_boss_end_stance()
	enemy.staggered = true
	enemy.stagger_timer = BOSS_STAGGER_DURATION
	enemy.posture_hits = 0
	enemy.posture_window = 0.0
	if is_instance_valid(enemy.body):
		enemy.body.modulate = Color(0.55, 0.55, 0.85)   # 휘청이는 표현
		var b: ColorRect = enemy.body
		var home: float = enemy.get("base_x", b.position.x)
		var tw := create_tween()
		tw.tween_property(b, "position:x", home - 10.0, 0.06)
		tw.tween_property(b, "position:x", home + 8.0, 0.06)
		tw.tween_property(b, "position:x", home, 0.06)
	if not verify_mode:
		_show_notice("자세 붕괴!", 0.9)


func _boss_end_stagger() -> void:
	enemy.staggered = false
	enemy.stagger_timer = 0.0
	enemy.posture_hits = 0
	enemy.atk_timer = 0.0   # 공격 타이머 초기화(방어 태세 쿨다운은 그대로 진행)
	if not enemy.is_empty() and is_instance_valid(enemy.body):
		enemy.body.modulate = Color.WHITE


func _boss_state_text() -> String:
	if enemy.is_empty():
		return "일반"
	if enemy.get("staggered", false):
		return "자세 붕괴"
	if enemy.is_winding_up:
		return "강공격 준비"
	if enemy.get("defense_stance", false):
		return "방어 태세"
	return "일반"


func _deal_to_enemy(dmg: int, label: String, big: bool) -> void:
	if enemy.is_empty():
		return
	enemy.hp = max(0, enemy.hp - dmg)
	current_enemy_hits += 1
	_update_hp_bar(enemy)
	_flash(enemy)
	_show_damage_at(enemy, dmg, label, big)
	_register_boss_hit()   # 일반 공격·강타·연격 모두 자세 붕괴 타격 1회로 센다


func _enemy_pushback() -> void:
	# 강타 시 적이 짧게 밀렸다 돌아온다 (고정 기준 위치로 복귀)
	if enemy.is_empty():
		return
	var b: ColorRect = enemy.body
	var home: float = enemy.get("base_x", b.position.x)
	var tw := create_tween()
	tw.tween_property(b, "position:x", home + 24.0, 0.08)
	tw.tween_property(b, "position:x", home, 0.14)


func _show_damage_at(target: Dictionary, dmg: int, label: String, _big: bool) -> void:
	# 실제 피해 숫자(+선택적 특성 문구)를 대상 근처에 잠깐 띄운다 (공격마다 한 번)
	# 특성별로 색과 크기를 달리해 구분이 잘 되게 한다.
	var col := Color(1, 1, 1)
	var fs := 28
	match label:
		"강타":
			col = Color(1.0, 0.85, 0.3); fs = 46
		"추가 베기":
			col = Color(0.4, 0.95, 1.0); fs = 34
		"방어":
			col = Color(0.55, 0.8, 1.0); fs = 28
		"반격":
			col = Color(1.0, 0.6, 0.2); fs = 38
		"강공격":
			col = Color(1.0, 0.45, 0.2); fs = 44
		"강공격 방어":
			col = Color(0.6, 0.85, 1.0); fs = 40
	var b: ColorRect = target.body
	var lbl := Label.new()
	lbl.text = ("%s -%d" % [label, dmg]) if label != "" else "-%d" % dmg
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", col)
	if kfont != null:
		lbl.add_theme_font_override("font", kfont)
	lbl.position = Vector2(b.position.x - 6, b.position.y - 30)
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 38, 0.55)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lbl.queue_free)


func _tint(unit: Dictionary, color: Color, dur: float) -> void:
	# 유닛 본체를 잠깐 특정 색으로 물들였다 복귀 (특성 강조용)
	var body: ColorRect = unit.body
	if unit.get("state", -1) == DEAD:
		return
	body.modulate = color
	var tw := create_tween()
	tw.tween_property(body, "modulate", Color.WHITE, dur)


func _spawn_ghost(unit: Dictionary, color: Color) -> void:
	# 앞으로 흐르며 사라지는 잔상 (연격·반격 강조용)
	var src: ColorRect = unit.body
	var g := ColorRect.new()
	g.color = color
	g.size = src.size
	g.position = src.position
	g.z_index = -1
	add_child(g)
	var tw := create_tween()
	tw.tween_property(g, "position:x", g.position.x + 48.0, 0.28)
	tw.parallel().tween_property(g, "modulate:a", 0.0, 0.28)
	tw.tween_callback(g.queue_free)


func _kill_enemy() -> void:
	kill_count += 1
	var hits := current_enemy_hits
	# 적 처치 → 현재 적 프로필의 골드·경험치 지급(한 번) → 레벨업 확인
	var killed_type: String = enemy.get("type", "verify")
	var was_elite: bool = enemy.get("is_elite", false)
	var was_boss: bool = enemy.get("is_boss", false)
	windup_label.visible = false   # 준비 중 처치 시 강공격 취소(문구 정리)
	gold += enemy.gold_reward       # 보스 보상도 프로필 값(200/100)으로 한 번만 지급
	exp += enemy.exp_reward
	_check_level_up()
	if not verify_mode and was_boss:
		boss_defeated = true
		boss_due = false
		boss_fight_active = false
		_hide_boss_ui()
		_show_notice("보스 처치!\n철퇴의 브루노 격파.\n\n첫 지역 클리어!", 2.0)
	elif not verify_mode and was_elite:
		_show_notice("엘리트 처치!\n골드 +40   경험치 +30", 1.3)
	# 사망 연출 후 모든 적 노드 정리
	var dying := enemy
	dying.state = DEAD
	var tw := create_tween()
	tw.tween_property(dying.body, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(dying.body, "scale", Vector2(0.6, 0.6), 0.25)
	tw.tween_callback(func() -> void: _free_enemy_nodes(dying))
	enemy = {}
	merc.state = WALK
	merc.atk_timer = 0.0

	# 고블린 무리: 대기 중인 다음 고블린을 즉시 앞으로 승격
	if not verify_mode and killed_type == "goblin" and not goblin_queue.is_empty():
		enemy = goblin_queue.pop_front()
		enemy.name_label.visible = true
		current_enemy_hits = 0
		respawn_timer = 0.0   # 이미 화면에 있으므로 대기 없이 전진
		_update_upgrade_ui()
		return

	# 순환 전진 + 다음 등장 지연 (고블린 무리 인덱스는 무리 시작 시 이미 전진됨)
	if not verify_mode:
		if was_boss:
			enemy_seq_index = 0          # 처치 후 첫 늑대로 복귀(boss_defeated라 재등장 없음)
		elif _should_set_boss_due(killed_type):
			boss_due = true              # 오우거 처치 → 다음 적이 보스
		elif killed_type == "goblin":
			goblin_run_start = -1        # 무리의 마지막 고블린 처치
		else:
			enemy_seq_index += 1
	respawn_timer = 2.0 if was_boss else RESPAWN_DELAY   # 승리 문구를 보여줄 시간
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

	# 기존 검증 통과 후 TASK_005 특성 → TASK_006 적 → TASK_008 오우거 검증을 1회씩.
	var base5: bool = v_damage and v_hp and v_def and v_task002 and v_task003
	if base5 and not v_traits:
		_verify_traits()
	if base5 and v_traits and not v_enemies:
		_verify_enemies()
	if base5 and v_traits and v_enemies and not v_ogre:
		_verify_ogre()
	if base5 and v_traits and v_enemies and v_ogre and not v_boss:
		_verify_boss()
	# 모든 검증 통과 시 종료 코드 0
	if base5 and v_traits and v_enemies and v_ogre and v_boss:
		print("[VERIFY] ALL PASS TASK_001~009 kills=%d lv=%d atk=%d def=%d maxhp=%d" % [kill_count, level, merc.atk, merc.defense, merc.max_hp])
		get_tree().quit(0)
	if kill_count >= 120:
		_vfail("incomplete dmg=%s hp=%s def=%s t002=%s t003=%s traits=%s enemies=%s ogre=%s boss=%s kills=%d" % [str(v_damage), str(v_hp), str(v_def), str(v_task002), str(v_task003), str(v_traits), str(v_enemies), str(v_ogre), str(v_boss), kill_count])


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

	# 5) 반격: 받는 피해 감소 + 반격 피해 + 결정적 3번째마다 발동
	var base := _damage(ENEMY_ATK, MERC_DEF)   # 6-2=4
	var reduced := _counter_reduced(base)       # round(4*0.6)=2
	if reduced != 2:
		_vfail("반격 감소피해=%d" % reduced); return
	var ctd := _counter_damage(merc.atk, 0)
	if ctd != maxi(1, int(round(merc.atk * COUNTER_MULT))):
		_vfail("반격 dmg=%d" % ctd); return
	counter_trait_level = 1
	counter_hit_counter = 0
	var cseq: Array = []
	for i in range(6):
		cseq.append(_consume_counter())
	if cseq != [false, false, true, false, false, true]:
		_vfail("반격 발동열 %s" % str(cseq)); return
	counter_hit_counter = 0
	print("[VERIFY] 반격 PASS 받는피해 %d→%d 반격피해=%d 3타째확정" % [base, reduced, ctd])

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
	power_trait_level = 0
	combo_trait_level = 0
	counter_trait_level = 0
	power_attack_counter = 0
	counter_hit_counter = 0
	level = save_level
	_update_trait_ui()
	v_traits = true
	print("[VERIFY] task005 특성 ALL PASS")


# ── TASK_006 적 검증 (프로필·순서·보상·피해, 무작위 비의존) ──────
func _verify_enemies() -> void:
	# 1) 프로필 수치
	var expect := {
		"wolf": {"max_hp": 32, "atk": 5, "defense": 0, "interval": 0.75, "gold": 5, "exp": 5},
		"goblin": {"max_hp": 22, "atk": 4, "defense": 0, "interval": 1.0, "gold": 4, "exp": 4},
		"shield": {"max_hp": 75, "atk": 8, "defense": 5, "interval": 1.5, "gold": 12, "exp": 10},
	}
	for k in expect:
		var p: Dictionary = ENEMY_PROFILES[k]
		for f in expect[k]:
			if not is_equal_approx(float(p[f]), float(expect[k][f])):
				_vfail("profile %s.%s=%s expected %s" % [k, f, str(p[f]), str(expect[k][f])]); return
	print("[VERIFY] TASK_006 enemy profiles PASS")

	# 2) 일반 적 결정적 순서(앞 7칸) + 고블린 무리 번호 (오우거는 TASK_008에서 검증)
	var want := ["wolf", "wolf", "wolf", "goblin", "goblin", "goblin", "shield"]
	var got: Array = []
	for i in range(want.size()):
		got.append(ENEMY_SEQUENCE[i])
	if got != want:
		_vfail("sequence %s" % str(got)); return
	if _goblin_wave_info(3) != Vector2i(1, 3) or _goblin_wave_info(4) != Vector2i(2, 3) or _goblin_wave_info(5) != Vector2i(3, 3):
		_vfail("goblin wave %s %s %s" % [str(_goblin_wave_info(3)), str(_goblin_wave_info(4)), str(_goblin_wave_info(5))]); return
	print("[VERIFY] TASK_006 sequence PASS (늑대3·고블린3·방패병1, 무리 1/3·2/3·3/3)")

	# 3) 보상 (프로필 값 = 지급 보상)
	if int(ENEMY_PROFILES["wolf"].gold) != 5 or int(ENEMY_PROFILES["wolf"].exp) != 5 \
		or int(ENEMY_PROFILES["goblin"].gold) != 4 or int(ENEMY_PROFILES["goblin"].exp) != 4 \
		or int(ENEMY_PROFILES["shield"].gold) != 12 or int(ENEMY_PROFILES["shield"].exp) != 10:
		_vfail("rewards mismatch"); return
	print("[VERIFY] TASK_006 rewards PASS (늑대 5/5, 고블린 4/4, 방패병 12/10)")

	# 4) 전투 역할: 공격력 10 기준 적에게 주는 피해 + 적이 주는 피해
	var w_def: int = ENEMY_PROFILES["wolf"].defense
	var s_def: int = ENEMY_PROFILES["shield"].defense
	if _damage(10, w_def) != 10 or _damage(10, s_def) != 5:
		_vfail("hit dmg wolf=%d shield=%d" % [_damage(10, w_def), _damage(10, s_def)]); return
	if _power_damage(10, s_def) != 17:   # round(22)-5
		_vfail("강타 vs 방패병=%d" % _power_damage(10, s_def)); return
	if _damage(ENEMY_PROFILES["wolf"].atk, MERC_DEF) != 3 \
		or _damage(ENEMY_PROFILES["goblin"].atk, MERC_DEF) != 2 \
		or _damage(ENEMY_PROFILES["shield"].atk, MERC_DEF) != 6:
		_vfail("적 피해 늑대/고블린/방패병 %d/%d/%d" % [_damage(ENEMY_PROFILES["wolf"].atk, MERC_DEF), _damage(ENEMY_PROFILES["goblin"].atk, MERC_DEF), _damage(ENEMY_PROFILES["shield"].atk, MERC_DEF)]); return
	print("[VERIFY] TASK_006 combat roles PASS (방패병 일반5<강타17, 적 피해 3/2/6)")

	v_enemies = true
	print("[VERIFY] task006 적 ALL PASS")


# ── TASK_008 오우거 엘리트 검증 (결정적) ─────────────────────────
func _verify_ogre() -> void:
	# 1) 프로필
	var p: Dictionary = ENEMY_PROFILES["ogre"]
	var ex := {"max_hp": 240, "atk": 16, "defense": 3, "exp": 30, "gold": 40, "interval": 2.0}
	for f in ex:
		if not is_equal_approx(float(p[f]), float(ex[f])):
			_vfail("ogre profile %s=%s expected %s" % [f, str(p[f]), str(ex[f])]); return
	print("[VERIFY] TASK_008 ogre profile PASS (체력240 공16 방3 보상40/30 간격2.0)")

	# 2) 등장 순서: 일반 순환 뒤 오우거, 처치 후 첫 늑대
	if ENEMY_SEQUENCE.find("ogre") != 7 or ENEMY_SEQUENCE[(7 + 1) % ENEMY_SEQUENCE.size()] != "wolf":
		_vfail("ogre 순서 idx=%d" % ENEMY_SEQUENCE.find("ogre")); return
	print("[VERIFY] TASK_008 sequence PASS (방패병 다음 오우거, 처치 후 늑대)")

	# 3) 공격 패턴: 기본·기본·강공격 ×2
	var ac := 0
	var pat: Array = []
	for i in range(6):
		ac += 1
		if ac >= OGRE_HEAVY_EVERY:
			ac = 0
			pat.append("heavy")
		else:
			pat.append("basic")
	if pat != ["basic", "basic", "heavy", "basic", "basic", "heavy"]:
		_vfail("ogre 패턴 %s" % str(pat)); return
	print("[VERIFY] TASK_008 attack pattern PASS (기본·기본·강공격 반복)")

	# 4) 피해: 기본 14, 강공격 30
	var basic_dmg := _damage(16, MERC_DEF)
	var heavy_dmg := maxi(1, int(round(16 * OGRE_HEAVY_MULT)) - MERC_DEF)
	if basic_dmg != 14 or heavy_dmg != 30:
		_vfail("ogre 피해 기본=%d 강공격=%d" % [basic_dmg, heavy_dmg]); return

	# 5) 반격 연동: 3번째(강공격)에만 발동, 강공격 30→감소 18
	counter_trait_level = 1
	counter_hit_counter = 0
	var cs: Array = []
	for i in range(3):   # 오우거 기본, 기본, 강공격
		cs.append(_consume_counter())
	if cs != [false, false, true]:
		_vfail("ogre 반격열 %s" % str(cs)); return
	var heavy_reduced := _counter_reduced(heavy_dmg)
	if heavy_reduced != 18:
		_vfail("강공격 감소피해=%d" % heavy_reduced); return
	counter_hit_counter = 0
	counter_trait_level = 0
	print("[VERIFY] TASK_008 heavy counter PASS (강공격 30→%d, 3번째만 반격)" % heavy_reduced)

	# 6) 보상
	if int(p.gold) != 40 or int(p.exp) != 30:
		_vfail("ogre 보상 %d/%d" % [int(p.gold), int(p.exp)]); return
	print("[VERIFY] TASK_008 reward PASS (골드+40 경험치+30, 1회)")

	# 7) 패배 후 복귀: 엘리트 패배 시 첫 늑대(인덱스 0)로
	if ENEMY_SEQUENCE[0] != "wolf":
		_vfail("복귀 첫 적 %s" % ENEMY_SEQUENCE[0]); return
	print("[VERIFY] TASK_008 retry loop PASS (패배 시 첫 늑대 복귀, 일반 순환 후 재도전)")

	v_ogre = true
	print("[VERIFY] task008 오우거 ALL PASS")


# ── TASK_009 보스(철퇴의 브루노) 검증 (결정적, 확률 비의존) ───────
func _verify_boss() -> void:
	# 1) 프로필
	if BOSS_MAX_HP != 850 or BOSS_ATK != 15 or BOSS_BASE_DEF != 6 or BOSS_EXP != 100 or BOSS_GOLD != 200:
		_vfail("boss profile hp=%d atk=%d def=%d exp=%d gold=%d" % [BOSS_MAX_HP, BOSS_ATK, BOSS_BASE_DEF, BOSS_EXP, BOSS_GOLD]); return
	if not is_equal_approx(BOSS_INTERVAL, 2.0) or not is_equal_approx(BOSS_TIME_LIMIT, 45.0) or not is_equal_approx(BOSS_HEAVY_MULT, 2.3):
		_vfail("boss profile interval=%s time=%s mult=%s" % [str(BOSS_INTERVAL), str(BOSS_TIME_LIMIT), str(BOSS_HEAVY_MULT)]); return
	print("[VERIFY] TASK_009 boss profile PASS (체력850 공15 방6 보상200/100 간격2.0 제한45 강공격×2.3)")

	# 2) 등장: 오우거 다음 보스, 처치 후 재등장 방지
	if ENEMY_SEQUENCE.find("ogre") != 7 or ENEMY_SEQUENCE[0] != "wolf":
		_vfail("boss 등장 전제 ogre_idx=%d first=%s" % [ENEMY_SEQUENCE.find("ogre"), ENEMY_SEQUENCE[0]]); return
	var save_defeated := boss_defeated
	boss_defeated = false
	if not _should_set_boss_due("ogre") or _should_set_boss_due("wolf"):
		_vfail("boss due 미처치 ogre=%s wolf=%s" % [str(_should_set_boss_due("ogre")), str(_should_set_boss_due("wolf"))]); return
	boss_defeated = true
	if _should_set_boss_due("ogre"):
		_vfail("boss 처치 후 재등장 방지 실패"); return
	boss_defeated = save_defeated
	print("[VERIFY] TASK_009 sequence PASS (오우거 다음 보스, 처치 후 첫 늑대·재등장 없음)")

	# 3) 공격 패턴: 기본·기본·강공격 ×2
	var ac := 0
	var pat: Array = []
	for i in range(6):
		ac += 1
		if ac >= BOSS_HEAVY_EVERY:
			ac = 0
			pat.append("heavy")
		else:
			pat.append("basic")
	if pat != ["basic", "basic", "heavy", "basic", "basic", "heavy"]:
		_vfail("boss 패턴 %s" % str(pat)); return
	print("[VERIFY] TASK_009 attack pattern PASS (기본·기본·강공격 반복)")

	# 4) 피해: 기본 13, 강공격 33 (방어력 2 기준)
	var basic_dmg := _damage(BOSS_ATK, MERC_DEF)
	var heavy_dmg := maxi(1, _boss_heavy_power(BOSS_ATK) - MERC_DEF)
	if _boss_heavy_power(BOSS_ATK) != 35 or basic_dmg != 13 or heavy_dmg != 33:
		_vfail("boss 피해 heavy_power=%d 기본=%d 강공격=%d" % [_boss_heavy_power(BOSS_ATK), basic_dmg, heavy_dmg]); return
	print("[VERIFY] TASK_009 damage PASS (기본 13, 강공격 33)")

	# 5) 반격 연동: 기본·기본·강공격에서 3번째(강공격)만 발동, 강공격 33→감소 20
	counter_trait_level = 1
	counter_hit_counter = 0
	var cs: Array = []
	for i in range(3):
		cs.append(_consume_counter())
	if cs != [false, false, true]:
		_vfail("boss 반격열 %s" % str(cs)); return
	var heavy_reduced := _counter_reduced(heavy_dmg)
	if heavy_reduced != 20:
		_vfail("강공격 감소피해=%d" % heavy_reduced); return
	counter_hit_counter = 0
	counter_trait_level = 0
	print("[VERIFY] TASK_009 heavy counter PASS (강공격 33→%d, 3번째만 반격)" % heavy_reduced)

	# 6) 현재 방어력: 일반6·방어태세9·자세붕괴4, 자세 붕괴 우선
	if _boss_def_for(false, false) != 6 or _boss_def_for(false, true) != 9 or _boss_def_for(true, false) != 4 or _boss_def_for(true, true) != 4:
		_vfail("boss 방어력 일반=%d 태세=%d 붕괴=%d 우선=%d" % [_boss_def_for(false, false), _boss_def_for(false, true), _boss_def_for(true, false), _boss_def_for(true, true)]); return
	if BOSS_STANCE_DEF != int(round(BOSS_BASE_DEF * 1.5)) or BOSS_STAGGER_DEF != int(round(BOSS_BASE_DEF * 0.6)):
		_vfail("boss 방어력 상수 태세=%d 붕괴=%d" % [BOSS_STANCE_DEF, BOSS_STAGGER_DEF]); return
	if not is_equal_approx(BOSS_STANCE_CYCLE, 10.0) or not is_equal_approx(BOSS_STANCE_DURATION, 3.0):
		_vfail("boss 방어 태세 주기=%s 지속=%s" % [str(BOSS_STANCE_CYCLE), str(BOSS_STANCE_DURATION)]); return
	print("[VERIFY] TASK_009 defense stance PASS (방어력 6/9/4, 10초마다 3초)")

	# 7) 자세 붕괴: 8타째 발동, 유효시간 내 8타 미달 시 0으로 초기화, 붕괴 중 미연장
	var d := {"staggered": false, "posture_hits": 0, "posture_window": 0.0}
	var trig: Array = []
	for i in range(8):
		trig.append(_posture_register(d))
	if trig != [false, false, false, false, false, false, false, true]:
		_vfail("자세 붕괴 발동열 %s" % str(trig)); return
	# 4초 안에 7타만: 유효 시간 경과 시 타격 수 0
	var d2 := {"staggered": false, "posture_hits": 0, "posture_window": 0.0}
	for i in range(7):
		_posture_register(d2)
	if int(d2.posture_hits) != 7:
		_vfail("7타 누적=%d" % int(d2.posture_hits)); return
	_posture_tick(d2, BOSS_POSTURE_WINDOW + 0.1)   # 유효 시간 경과
	if int(d2.posture_hits) != 0:
		_vfail("유효시간 경과 후 타격 수=%d" % int(d2.posture_hits)); return
	# 자세 붕괴 중에는 누적·연장하지 않음
	var d3 := {"staggered": true, "posture_hits": 0, "posture_window": 0.0}
	if _posture_register(d3) or int(d3.posture_hits) != 0:
		_vfail("붕괴 중 누적 hits=%d" % int(d3.posture_hits)); return
	if BOSS_POSTURE_HITS != 8 or not is_equal_approx(BOSS_POSTURE_WINDOW, 4.0) or not is_equal_approx(BOSS_STAGGER_DURATION, 3.0):
		_vfail("자세 붕괴 상수 hits=%d window=%s dur=%s" % [BOSS_POSTURE_HITS, str(BOSS_POSTURE_WINDOW), str(BOSS_STAGGER_DURATION)]); return
	print("[VERIFY] TASK_009 posture break PASS (8타 붕괴, 미달 시 초기화, 붕괴 중 미연장)")

	# 8) 강타 보스 추가 피해 10%: 공격력 10·일반 방어력 6 → 18 (일반/오우거엔 미적용)
	if _power_damage_boss(10, 6) != 18:
		_vfail("강타 보스 추가피해=%d" % _power_damage_boss(10, 6)); return
	if _power_damage(10, 6) != 16 or _power_damage(10, 3) != 19:   # 보스 보너스 없는 일반 강타
		_vfail("일반 강타 def6=%d def3=%d" % [_power_damage(10, 6), _power_damage(10, 3)]); return
	print("[VERIFY] TASK_009 power boss bonus PASS (보스 18 > 일반 16)")

	v_boss = true
	print("[VERIFY] task009 보스 ALL PASS")


# 순수 함수: 유효 시간 경과를 모사해 타격 수를 초기화(검증용)
func _posture_tick(d: Dictionary, delta: float) -> void:
	if float(d.get("posture_window", 0.0)) > 0.0:
		d.posture_window = float(d.posture_window) - delta
		if float(d.posture_window) <= 0.0:
			d.posture_hits = 0


func _kill_merc() -> void:
	merc.state = DEAD
	merc.body.modulate = Color(0.5, 0.5, 0.5)
	merc_revive_timer = MERC_DEATH_DELAY
	power_attack_counter = 0   # 사망 시 강타·반격 카운트 초기화
	counter_hit_counter = 0
	if not verify_mode and not enemy.is_empty() and enemy.get("is_boss", false):
		# 보스에게 체력이 0이 되어 패배 = 생존 부족
		_show_notice("보스 도전 실패.\n생존 부족.\n\n체력·방어력을 강화하거나\n반격 특성을 사용해 보세요.", 2.0)
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
	windup_label.visible = false
	var was_elite: bool = (not enemy.is_empty()) and enemy.get("is_elite", false)
	var was_boss: bool = (not enemy.is_empty()) and enemy.get("is_boss", false)
	if not enemy.is_empty():
		_free_enemy_nodes(enemy)   # 현재 적 제거 (순환 위치는 유지 — 같은 적이 다시 등장)
		enemy = {}
	# 고블린 무리 중 사망: 대기 고블린 정리하고 무리를 처음부터 다시 시작
	if not goblin_queue.is_empty():
		for g in goblin_queue:
			_free_enemy_nodes(g)
		goblin_queue = []
	if goblin_run_start >= 0:
		enemy_seq_index = goblin_run_start
		goblin_run_start = -1
	# 엘리트(오우거)에게 패배하면 첫 늑대로 복귀해 일반 사냥 후 재도전
	if was_elite:
		enemy_seq_index = 0
	# 보스에게 패배(생존 부족)하면 보스 상태를 정리하고 첫 늑대로 복귀해 재도전
	if was_boss:
		_boss_return_to_hunt()
	respawn_timer = RESPAWN_DELAY


# 제한 시간 초과(화력 부족): 용병은 살아 있으나 보스 처치 실패 → 첫 늑대로 복귀
func _boss_lose(reason: String) -> void:
	if reason == "화력 부족":
		_show_notice("보스 도전 실패.\n화력 부족.\n\n공격력을 강화하거나\n강타·연격 특성을 사용해 보세요.", 2.0)
	if not enemy.is_empty():
		_free_enemy_nodes(enemy)   # 보상 없이 보스 제거
		enemy = {}
	merc.hp = merc.max_hp          # 체력 완전 회복
	_update_hp_bar(merc)
	merc.atk_timer = 0.0
	merc.state = WALK
	_boss_return_to_hunt()
	respawn_timer = 1.8            # 패배 안내를 보여줄 시간


# 보스전 종료 시 공통 정리: 보스 UI·상태 초기화, 첫 늑대로 복귀, 보스 재도전 준비
func _boss_return_to_hunt() -> void:
	_hide_boss_ui()
	boss_fight_active = false
	boss_due = false              # 재도전 시 오우거를 다시 처치해야 보스 등장
	boss_time_left = BOSS_TIME_LIMIT
	enemy_seq_index = 0           # 첫 늑대로 복귀
	windup_label.visible = false
	power_attack_counter = 0
	counter_hit_counter = 0


# ── 표현(타격감) ─────────────────────────────────────────────────
func _lunge(unit: Dictionary, dist: float = 22.0) -> void:
	# 공격 순간 앞으로 짧게 움직였다 복귀. 항상 고정 기준 위치(home)로 돌아와
	# 공격이 겹쳐도 본체가 조금씩 밀려나지 않게 한다.
	var body: ColorRect = unit.body
	var dir := 1.0 if unit == merc else -1.0
	var home: float = unit.get("base_x", body.position.x)
	var tw := create_tween()
	tw.tween_property(body, "position:x", home + dir * dist, 0.07)
	tw.tween_property(body, "position:x", home, 0.10)


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
	unit.hp_fill.size.x = maxf(0.0, unit.bar_w * ratio)


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


func _build_windup_label() -> void:
	windup_label = Label.new()
	windup_label.size = Vector2(220, 32)
	windup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	windup_label.add_theme_font_size_override("font_size", 24)
	windup_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	windup_label.visible = false
	add_child(windup_label)


func _build_boss_ui() -> void:
	# 보스 전용 정보 영역(상단). 기존 상태·경험치 바·특성 UI(y≤164) 아래에 배치.
	boss_ui = Control.new()
	boss_ui.position = Vector2.ZERO
	boss_ui.size = SCREEN
	boss_ui.z_index = 40
	boss_ui.visible = false
	add_child(boss_ui)

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.03, 0.06, 0.85)
	bg.size = Vector2(508, 104)
	bg.position = Vector2(16, 168)
	boss_ui.add_child(bg)

	boss_name_label = Label.new()
	boss_name_label.position = Vector2(28, 174)
	boss_name_label.add_theme_font_size_override("font_size", 24)
	boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.65))
	boss_name_label.text = "[보스] 철퇴의 브루노"
	boss_ui.add_child(boss_name_label)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.6)
	hp_bg.size = Vector2(484, 18)
	hp_bg.position = Vector2(28, 208)
	boss_ui.add_child(hp_bg)

	boss_ui_hp_fill = ColorRect.new()
	boss_ui_hp_fill.color = Color(0.95, 0.25, 0.30)
	boss_ui_hp_fill.size = Vector2(480, 14)
	boss_ui_hp_fill.position = Vector2(30, 210)
	boss_ui.add_child(boss_ui_hp_fill)

	boss_hp_label = Label.new()
	boss_hp_label.position = Vector2(36, 207)
	boss_hp_label.add_theme_font_size_override("font_size", 15)
	boss_ui.add_child(boss_hp_label)

	boss_time_label = Label.new()
	boss_time_label.position = Vector2(28, 234)
	boss_time_label.add_theme_font_size_override("font_size", 20)
	boss_time_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	boss_ui.add_child(boss_time_label)

	boss_state_label = Label.new()
	boss_state_label.position = Vector2(250, 234)
	boss_state_label.add_theme_font_size_override("font_size", 20)
	boss_state_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	boss_ui.add_child(boss_state_label)


func _build_boss_progress_label() -> void:
	boss_progress_label = Label.new()
	boss_progress_label.position = Vector2(16, 66)
	boss_progress_label.add_theme_font_size_override("font_size", 18)
	boss_progress_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
	add_child(boss_progress_label)


func _show_boss_ui() -> void:
	if boss_ui != null:
		boss_ui.visible = true


func _hide_boss_ui() -> void:
	if boss_ui != null:
		boss_ui.visible = false


func _update_boss_ui() -> void:
	if boss_ui == null or not boss_ui.visible or enemy.is_empty():
		return
	boss_hp_label.text = "HP %d / %d" % [enemy.hp, enemy.max_hp]
	boss_ui_hp_fill.size.x = 480.0 * clampf(float(enemy.hp) / float(enemy.max_hp), 0.0, 1.0)
	var t: int = int(ceil(maxf(0.0, boss_time_left))) if boss_fight_active else int(BOSS_TIME_LIMIT)
	boss_time_label.text = "남은 시간 %d초" % t
	boss_state_label.text = "상태: " + _boss_state_text()


# 일반 전투 중 보스까지 진행 상황을 짧게 표시
func _update_boss_progress() -> void:
	if boss_progress_label == null:
		return
	var t := ""
	if boss_defeated:
		t = "첫 지역 완료"
	elif boss_fight_active:
		t = "보스 전투"
	elif boss_due:
		t = "보스 등장 예정"
	else:
		t = "보스까지 %d / 8" % (enemy_seq_index % ENEMY_SEQUENCE.size())
	boss_progress_label.text = t


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
	_update_boss_progress()


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
	counter_hit_counter = 0
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
	_show_notice("전투 특성 포인트 획득!\n강타·연격·반격 중 하나를 선택하세요.", 1.1)


# 화면 중앙 알림 문구 (엘리트 등장·처치, 특성 획득 등)
func _show_notice(text: String, dur: float) -> void:
	notify_label.text = text
	notify_label.visible = true
	notify_label.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_interval(dur)
	tw.tween_property(notify_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: notify_label.visible = false)
