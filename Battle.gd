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

# ── 적·보스 고정 프로필과 사운드 훅 분리 (TASK_014) ──────────────
# 적 5종(일반·엘리트·보스)의 고정값은 scripts/data/EnemyProfiles.gd로 분리.
# 사운드 이벤트 경계는 scripts/audio/AudioHooks.gd로 분리(아직 실제 음원 없음).
const EnemyProfiles := preload("res://scripts/data/EnemyProfiles.gd")
const AudioHooks := preload("res://scripts/audio/AudioHooks.gd")

# ── 일반 적 3종과 순환 (TASK_006) ────────────────────────────────
# 검증 모드는 위의 기준 적(ENEMY_*)만 쓰고, 일반 플레이만 아래 프로필로 순환한다.
# 읽기용 별칭(검증·조회). 전투 생성 경로는 EnemyProfiles.get_profile()로 복사본을 받는다.
const ENEMY_PROFILES := EnemyProfiles.PROFILES
const ENEMY_SEQUENCE := ["wolf", "wolf", "wolf", "goblin", "goblin", "goblin", "shield", "ogre"]
const GOBLIN_SPACING := 82.0        # 무리 고블린 사이 가로 간격(겹치지 않게)

# ── 엘리트: 오우거 징수꾼 (TASK_008) ─────────────────────────────
const OGRE_HEAVY_MULT := 2.0       # 강공격(3번째) 배율
const OGRE_HEAVY_EVERY := 3        # 3번째 공격이 강공격
const OGRE_WINDUP_TIME := 1.0      # 강공격 준비 동작 시간(초)

# ── 보스: 철퇴의 브루노 (TASK_009) ───────────────────────────────
# 보스 고정 스탯은 EnemyProfiles의 "bruno" 프로필이 단일 출처(값 동일, 중복 정의 제거).
const BOSS_MAX_HP := int(EnemyProfiles.PROFILES["bruno"]["max_hp"])
const BOSS_ATK := int(EnemyProfiles.PROFILES["bruno"]["atk"])
const BOSS_BASE_DEF := int(EnemyProfiles.PROFILES["bruno"]["defense"])   # 일반 상태 방어력
const BOSS_STANCE_DEF := 9          # 방어 태세 round(6×1.5)
const BOSS_STAGGER_DEF := 4         # 자세 붕괴 round(6×0.6)
const BOSS_EXP := int(EnemyProfiles.PROFILES["bruno"]["exp"])
const BOSS_GOLD := int(EnemyProfiles.PROFILES["bruno"]["gold"])
const BOSS_INTERVAL := float(EnemyProfiles.PROFILES["bruno"]["interval"])   # 기본 공격 간격(초)
const BOSS_APPROACH_SPEED := float(EnemyProfiles.PROFILES["bruno"]["approach_speed"])
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

# ── 빚과 명성 (TASK_010) ─────────────────────────────────────────
const STARTING_DEBT := 10_000       # 프로토타입 시작 빚
const BRUNO_DEBT_PAYMENT := 500     # 브루노 처치 시 자동 상환액(보유 골드와 별도)

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

# ── 저장·불러오기 (TASK_011) ─────────────────────────────────────
const SAVE_PATH := "user://save_v1.json"
const VERIFY_SAVE_PATH := "user://save_test_v1.json"   # 검증 전용(실제 저장과 분리)
const SAVE_VERSION := 1
const AUTOSAVE_DELAY := 2.0          # 마지막 변경 후 자동 저장까지 대기(초)
const FAME_NAMELESS := "무명 용병"
const FAME_ROOKIE := "풋내기 용병"

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

# 빚·명성 상태 (TASK_010). 저장 없음 — 재실행 시 초기값으로.
var debt_remaining := STARTING_DEBT
var debt_paid_total := 0
var fame_rank := FAME_NAMELESS
var fame_advanced := false
var bruno_settlement_done := false   # 브루노 처치 정산(골드·경험치·빚·명성) 중복 방지
var last_debt_before := 0            # 결과 화면용: 상환 직전 남은 빚
var last_payment := 0                # 결과 화면용: 이번 실제 상환액

# 저장·불러오기 상태 (TASK_011)
var save_dirty := false              # 변경 후 자동 저장 대기 중인가
var autosave_timer := 0.0
var load_error := false              # 저장 손상·미지원으로 새 게임 시작했는가
var reset_confirm_timer := 0.0       # 저장 초기화 2회 확인 창(초)
var save_reset_btn: Button

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
var boss_progress_label: Label   # 상단 한 줄: 빚·명성·보스 진행
var boss_result_panel: Control   # 보스 처치 결과 패널 (TASK_010)
var boss_result_label: Label

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
var v_debt := false
var v_save := false
var v_task014 := false   # 프로필 분리·사운드 훅 경계 검증(TASK_014)
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
	_build_boss_result_panel()
	_apply_korean_font()
	_ignore_decorative_mouse()   # 상태·경험치·알림 등 비상호작용 표시가 버튼 터치를 막지 않게
	_build_merc()
	# 저장 데이터 불러오기 → UI 갱신 후 첫 적 생성 (검증 모드는 실제 저장을 건드리지 않음)
	var loaded := false
	if not verify_mode:
		loaded = _load_game()
	_spawn_enemy()
	if verify_mode:
		Engine.time_scale = 8.0  # 검증 시간 단축 (수치는 그대로, 시간만 가속)
	if not verify_mode and loaded:
		_show_notice("저장 데이터 불러옴", 1.0)


func _process(delta: float) -> void:
	if verify_mode:
		elapsed += delta  # time_scale 적용된 게임 시간(초)

	_update_status()
	_sync_all_ui()   # 체력 바·이름표가 공격(lunge) 중에도 본체와 어긋나지 않게
	_update_autosave(delta)
	_update_reset_confirm(delta)

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
	_ignore_enemy_mouse(merc)   # 용병 도형·체력 바도 입력 통과


# ── 적 ───────────────────────────────────────────────────────────
func _spawn_enemy() -> void:
	# 검증 모드는 기준 적(기존 ENEMY_*, 보상 5/5)만 생성해 TASK_002~005 검증을 보존한다.
	if verify_mode:
		var vprof := {"name": "검증적", "max_hp": ENEMY_MAX_HP, "atk": ENEMY_ATK, "defense": ENEMY_DEF, "interval": ENEMY_INTERVAL, "approach_speed": ENEMY_APPROACH_SPEED, "gold": GOLD_PER_KILL, "exp": EXP_PER_KILL, "size": Vector2(54, 74), "color": Color(0.90, 0.40, 0.35)}
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
	enemy = _build_enemy(typ, EnemyProfiles.get_profile(typ), 0, 0, ENEMY_SPAWN_X, true)
	current_enemy_hits = 0
	_sync_enemy_ui()
	if typ == "ogre":
		AudioHooks.play("elite_appear")
		counter_hit_counter = 0   # 반격을 오우거 강공격(3번째)에 맞춘다
		_show_notice("엘리트 등장!\n[엘리트] 오우거 징수꾼", 1.1)


# 고블린 무리: 3마리를 한 번에 줄지어 등장시킨다(겹치지 않게). 전투는 앞에서부터 한 마리씩.
func _spawn_goblin_wave(start_idx: int) -> void:
	goblin_run_start = start_idx
	var total: int = _goblin_wave_info(start_idx).y
	var prof: Dictionary = EnemyProfiles.get_profile("goblin")
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
	AudioHooks.play("boss_appear")
	_show_notice("보스 등장!\n철퇴의 브루노", 1.3)
	var prof := EnemyProfiles.get_profile("bruno")
	var bsize: Vector2 = prof.size            # 오우거(108×132)보다 크고 넓은 실루엣
	var bcolor: Color = prof.color            # 짙은 자주/적색
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
		"is_boss": prof.is_boss, "attack_count": 0,
		"is_winding_up": false, "windup_timer": 0.0,
		"defense_stance": false, "stance_timer": 0.0, "stance_cooldown": BOSS_STANCE_CYCLE,
		"staggered": false, "stagger_timer": 0.0,
		"posture_hits": 0, "posture_window": 0.0,
		"mace": mace, "mace_off_x": mace_off_x,
	}
	current_enemy_hits = 0
	counter_hit_counter = 0   # 반격을 보스 강공격(3번째)에 맞춘다
	power_attack_counter = 0
	_ignore_enemy_mouse(enemy)   # 보스 도형·철퇴가 버튼 터치를 가로채지 않게
	_show_boss_ui()
	_update_boss_ui()
	_sync_enemy_ui()


# 오우거 처치 후 보스를 등장시킬지 여부(이미 처치했으면 재등장하지 않음)
func _should_set_boss_due(killed_type: String) -> bool:
	return killed_type == "ogre" and not boss_defeated


# 적 한 마리를 노드와 함께 만들어 반환한다 (active=true면 이름표 표시)
func _build_enemy(typ: String, prof: Dictionary, wave_cur: int, wave_total: int, sx: float, active: bool) -> Dictionary:
	# 표시 크기·색상은 프로필 고정값 사용(하드코딩 제거, 단일 출처).
	var bsize: Vector2 = prof.size
	var bcolor: Color = prof.color
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
		e["is_elite"] = prof.is_elite
		e["attack_count"] = 0
		e["is_winding_up"] = false
		e["windup_timer"] = 0.0
		e["club_base_y"] = by - 30
	_ignore_enemy_mouse(e)   # 적 도형·체력 바가 (특성 패널 등) 버튼 터치를 가로채지 않게
	return e


# 적 딕셔너리의 모든 시각 노드를 입력 통과로 설정 (전투 도형이 버튼을 막지 않게)
func _ignore_enemy_mouse(e: Dictionary) -> void:
	for k in ["body", "hp_bg", "hp_fill", "name_label", "shield", "club", "mace"]:
		if e.has(k):
			_ignore_mouse(e[k])


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
		AudioHooks.play("trait_heavy_strike")
		_lunge(merc, 46.0)
		_enemy_pushback()
		var pdmg: int = _power_damage_boss(merc.atk, edef) if is_boss else _power_damage(merc.atk, edef)
		_deal_to_enemy(pdmg, "강타", true)
		return
	AudioHooks.play("merc_basic_attack")
	_lunge(merc)
	_deal_to_enemy(_damage(merc.atk, edef), "", false)
	if _combo_would_trigger(not enemy.is_empty() and enemy.hp > 0):
		# 연격: 빠른 추가 전진 + 청록 잔상·발광으로 "한 번 더 벴다"가 보이게
		AudioHooks.play("trait_flurry")
		_lunge(merc, 34.0)
		_tint(merc, Color(0.5, 1.5, 1.7), 0.22)
		_spawn_ghost(merc, Color(0.4, 0.95, 1.0, 0.55))
		_deal_to_enemy(_combo_damage(merc.atk, _enemy_def()), "추가 베기", false)


func _enemy_attack_merc() -> void:
	_apply_enemy_hit(_damage(enemy.atk, merc.defense), false)


# 적의 한 번 공격을 용병에게 적용 (반격 연동 포함). is_heavy=오우거 강공격.
func _apply_enemy_hit(base: int, is_heavy: bool) -> void:
	AudioHooks.play("enemy_basic_attack")
	var did_counter: bool = counter_trait_level > 0 and _consume_counter()
	var taken := _counter_reduced(base) if did_counter else base
	merc.hp = max(0, merc.hp - taken)
	_update_hp_bar(merc)
	_lunge(enemy)
	AudioHooks.play("trait_counter_block" if did_counter else "merc_hit")
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
		AudioHooks.play("trait_counter_attack")
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
	AudioHooks.play("boss_heavy_windup")
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
	AudioHooks.play("boss_defense_stance")
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
	AudioHooks.play("boss_posture_break")
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
	AudioHooks.play("enemy_hit")
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
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 떠오르는 피해 숫자가 버튼 터치를 가로채지 않게
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
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 잔상이 터치를 가로채지 않게
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
	AudioHooks.play("boss_victory" if was_boss else "enemy_death")
	if was_boss:
		_bruno_settlement()         # 개인 보상(200/100) + 빚 500 상환 + 명성 상승을 한 번만
	else:
		gold += enemy.gold_reward
		exp += enemy.exp_reward
		_check_level_up()
		_mark_dirty()               # 적 처치 성장은 지연 자동 저장
	if not verify_mode and was_boss:
		boss_due = false
		boss_fight_active = false
		_hide_boss_ui()
		_show_boss_result()         # 개인 보상·빚 상환·명성 상승 결과 패널(약 3.5초)
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
	respawn_timer = 3.6 if was_boss else RESPAWN_DELAY   # 결과 패널을 읽을 시간(그동안 적 미생성)
	_update_upgrade_ui()

	if verify_mode:
		_verify_step(hits)


# 브루노 처치 정산: 개인 보상·빚 자동 상환·명성 상승을 정확히 한 번만 적용
func _bruno_settlement() -> void:
	if bruno_settlement_done:
		return
	bruno_settlement_done = true
	boss_defeated = true                # 같은 실행에서 재등장 방지(TASK_009 규칙과 통합)
	gold += BOSS_GOLD                   # 개인 보상 +200 (보유 골드)
	exp += BOSS_EXP                     # +100
	last_debt_before = debt_remaining
	last_payment = mini(BRUNO_DEBT_PAYMENT, debt_remaining)   # 남은 빚보다 많이 상환하지 않음
	debt_remaining -= last_payment      # 보유 골드에서는 차감하지 않는다(별도 진행 보상)
	debt_paid_total += last_payment
	if not fame_advanced:
		fame_advanced = true
		fame_rank = FAME_ROOKIE
	_check_level_up()                   # 경험치 +100으로 레벨업 조건을 넘으면 즉시 처리
	_save_now()                         # 결과 패널 표시 전에 정산 결과를 저장


# 현재 레벨에서 다음 레벨까지 필요한 경험치
func _exp_to_next(lv: int) -> int:
	return 20 + lv * 5


func _check_level_up() -> void:
	# 초과 경험치를 버리지 않고 가능한 만큼 레벨업한다.
	while exp >= _exp_to_next(level):
		exp -= _exp_to_next(level)
		_level_up()


func _level_up() -> void:
	AudioHooks.play("level_up")
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
	if base5 and v_traits and v_enemies and v_ogre and v_boss and not v_debt:
		_verify_debt_fame()
	if base5 and v_traits and v_enemies and v_ogre and v_boss and v_debt and not v_save:
		_verify_save()
	if base5 and v_traits and v_enemies and v_ogre and v_boss and v_debt and v_save and not v_task014:
		_verify_task014()
	# 모든 검증 통과 시 종료 코드 0
	if base5 and v_traits and v_enemies and v_ogre and v_boss and v_debt and v_save and v_task014:
		print("[VERIFY] ALL PASS TASK_001~014 kills=%d lv=%d atk=%d def=%d maxhp=%d (TASK_012·013은 플레이·문서로 별도 확인)" % [kill_count, level, merc.atk, merc.defense, merc.max_hp])
		get_tree().quit(0)
	if kill_count >= 120:
		_vfail("incomplete dmg=%s hp=%s def=%s t002=%s t003=%s traits=%s enemies=%s ogre=%s boss=%s debt=%s save=%s kills=%d" % [str(v_damage), str(v_hp), str(v_def), str(v_task002), str(v_task003), str(v_traits), str(v_enemies), str(v_ogre), str(v_boss), str(v_debt), str(v_save), kill_count])


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


# ── TASK_010 빚·명성 정산 검증 (결정적) ─────────────────────────
func _verify_debt_fame() -> void:
	# 1) 초기 상태 (보스 미처치 — 검증 중 보스는 스폰되지 않으므로 현재값이 초기값)
	if debt_remaining != STARTING_DEBT or debt_paid_total != 0 or fame_rank != "무명 용병" or fame_advanced or bruno_settlement_done:
		_vfail("초기 debt=%d paid=%d fame=%s adv=%s done=%s" % [debt_remaining, debt_paid_total, fame_rank, str(fame_advanced), str(bruno_settlement_done)]); return
	if STARTING_DEBT != 10000 or BRUNO_DEBT_PAYMENT != 500:
		_vfail("상수 debt=%d pay=%d" % [STARTING_DEBT, BRUNO_DEBT_PAYMENT]); return
	if _format_debt(10000) != "10,000" or _format_debt(9500) != "9,500" or _format_debt(0) != "0" or _format_debt(300) != "300":
		_vfail("천단위 %s/%s/%s/%s" % [_format_debt(10000), _format_debt(9500), _format_debt(0), _format_debt(300)]); return
	print("[VERIFY] TASK_010 initial debt fame PASS (빚 10,000, 무명 용병, 정산 미완료)")

	# 정산이 건드리는 모든 상태 스냅샷 후 복원
	var s_gold := gold; var s_exp := exp; var s_level := level
	var s_atk: int = merc.atk; var s_maxhp: int = merc.max_hp; var s_hp: int = merc.hp
	var s_pts := trait_points; var s_earned := total_trait_points_earned
	var s_debt := debt_remaining; var s_paid := debt_paid_total
	var s_fame := fame_rank; var s_fadv := fame_advanced; var s_done := bruno_settlement_done
	var s_bdef := boss_defeated

	# 2) 패배 복귀 경로는 빚·명성·정산을 건드리지 않는다
	_boss_return_to_hunt()
	if debt_remaining != STARTING_DEBT or debt_paid_total != 0 or fame_rank != "무명 용병" or bruno_settlement_done:
		_vfail("복귀 후 debt=%d fame=%s done=%s" % [debt_remaining, fame_rank, str(bruno_settlement_done)]); return
	print("[VERIFY] TASK_010 defeat no settlement PASS (복귀에 빚·명성·정산 불변)")

	# 3) 정상 정산 + 골드 비차감 (레벨업 간섭 없도록 level 높게)
	level = 20; exp = 0; gold = 100
	debt_remaining = STARTING_DEBT; debt_paid_total = 0
	fame_rank = "무명 용병"; fame_advanced = false; bruno_settlement_done = false; boss_defeated = false
	_bruno_settlement()
	if gold != 300:
		_vfail("골드 비차감 gold=%d (기대 300)" % gold); return
	if exp != 100:
		_vfail("경험치 exp=%d (기대 100)" % exp); return
	if debt_remaining != 9500 or debt_paid_total != 500:
		_vfail("상환 남은=%d 누적=%d" % [debt_remaining, debt_paid_total]); return
	if fame_rank != "풋내기 용병" or not fame_advanced or not bruno_settlement_done:
		_vfail("명성 fame=%s adv=%s done=%s" % [fame_rank, str(fame_advanced), str(bruno_settlement_done)]); return
	print("[VERIFY] TASK_010 boss settlement PASS (골드 100→300, 빚 10,000→9,500, 무명→풋내기)")
	print("[VERIFY] TASK_010 gold not deducted PASS (상환 후에도 골드 300)")

	# 4) 메인 UI 텍스트 갱신
	_update_boss_progress()
	if not boss_progress_label.text.begins_with("빚 9,500   명성 풋내기 용병"):
		_vfail("UI 텍스트 %s" % boss_progress_label.text); return
	print("[VERIFY] TASK_010 ui text PASS (%s)" % boss_progress_label.text)

	# 5) 중복 정산 방지
	_bruno_settlement()
	if gold != 300 or exp != 100 or debt_remaining != 9500 or debt_paid_total != 500 or fame_rank != "풋내기 용병":
		_vfail("중복 gold=%d exp=%d 남은=%d 누적=%d fame=%s" % [gold, exp, debt_remaining, debt_paid_total, fame_rank]); return
	print("[VERIFY] TASK_010 duplicate guard PASS (재호출에도 1회분 유지)")

	# 6) 빚 0 하한 (빚 300에 500 상환 → 실제 300, 남은 0)
	debt_remaining = 300; debt_paid_total = 0; bruno_settlement_done = false; exp = 0
	_bruno_settlement()
	if debt_remaining != 0 or debt_paid_total != 300:
		_vfail("하한 남은=%d 누적=%d (기대 0/300)" % [debt_remaining, debt_paid_total]); return
	print("[VERIFY] TASK_010 debt floor PASS (빚 300+500상환 → 실제 300, 남은 0)")

	# 상태 복원
	gold = s_gold; exp = s_exp; level = s_level
	merc.atk = s_atk; merc.max_hp = s_maxhp; merc.hp = s_hp
	trait_points = s_pts; total_trait_points_earned = s_earned
	debt_remaining = s_debt; debt_paid_total = s_paid
	fame_rank = s_fame; fame_advanced = s_fadv; bruno_settlement_done = s_done
	boss_defeated = s_bdef
	_update_boss_progress()
	v_debt = true
	print("[VERIFY] task010 빚·명성 ALL PASS")


# 검증용: 테스트 저장 경로에 원시 텍스트 기록
func _write_test_save_raw(text: String) -> void:
	var f := FileAccess.open(VERIFY_SAVE_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.flush()
	f.close()


# ── TASK_011 저장·불러오기 검증 (테스트 경로만 사용, 결정적) ─────
func _verify_save() -> void:
	# 실제 사용자 저장 경로를 절대 건드리지 않는다
	if _get_save_path() != VERIFY_SAVE_PATH:
		_vfail("검증 저장 경로 %s (테스트 경로 아님)" % _get_save_path()); return
	var pre := _build_save_dict()   # 진행 중 상태 백업(끝에 복원)
	_delete_save_file()

	# 1) 저장 없음 → 새 게임. 초기 상태 함수가 신규 게임 기본값을 만드는지 확인.
	if _load_game():
		_vfail("저장 없는데 load=true"); return
	_reset_to_new_game()
	if level != 1 or gold != 0 or trait_points != 0 or total_trait_points_earned != 0 \
		or power_trait_level != 0 or combo_trait_level != 0 or counter_trait_level != 0 \
		or boss_defeated or debt_remaining != STARTING_DEBT or fame_rank != FAME_NAMELESS \
		or merc.atk != MERC_ATK or merc.max_hp != MERC_MAX_HP or merc.defense != MERC_DEF:
		_vfail("신규 게임 상태 lv=%d gold=%d pts=%d atk=%d 임시포인트?" % [level, gold, trait_points, merc.atk]); return
	print("[VERIFY] TASK_011 fresh state PASS (lv1·골드0·포인트0·빚10000·무명, 임시 포인트 없음)")

	# 2) 저장·불러오기 왕복 (브루노 처치 상태)
	level = 12; exp = 7; gold = 123
	attack_upgrade_count = 2; hp_upgrade_count = 1; def_upgrade_count = 3
	power_trait_level = 1; combo_trait_level = 0; counter_trait_level = 0
	boss_defeated = true; bruno_settlement_done = true
	debt_remaining = 9500; debt_paid_total = 500; fame_rank = FAME_ROOKIE; fame_advanced = true
	_save_game()
	_reset_to_new_game()            # 모든 값을 초기화한 뒤 다시 불러온다
	if not _load_game():
		_vfail("왕복 load 실패"); return
	if level != 12 or exp != 7 or gold != 123 \
		or attack_upgrade_count != 2 or hp_upgrade_count != 1 or def_upgrade_count != 3 \
		or power_trait_level != 1 or combo_trait_level != 0 or counter_trait_level != 0 \
		or not boss_defeated or not bruno_settlement_done \
		or debt_remaining != 9500 or debt_paid_total != 500 or fame_rank != FAME_ROOKIE or not fame_advanced:
		_vfail("왕복 복원 lv=%d exp=%d gold=%d up=%d/%d/%d tr=%d/%d/%d bd=%s debt=%d fame=%s" % [level, exp, gold, attack_upgrade_count, hp_upgrade_count, def_upgrade_count, power_trait_level, combo_trait_level, counter_trait_level, str(boss_defeated), debt_remaining, fame_rank]); return
	print("[VERIFY] TASK_011 save roundtrip PASS (lv12·골드123·강화2/1/3·강타1·브루노·빚9500·풋내기)")

	# 3) 파생 능력치 (시작값 + 강화 + 레벨업으로 재계산)
	if merc.atk != 25 or merc.max_hp != 175 or merc.defense != 5 or merc.hp != merc.max_hp:
		_vfail("파생 atk=%d maxhp=%d def=%d hp=%d (기대 25/175/5/완전회복)" % [merc.atk, merc.max_hp, merc.defense, merc.hp]); return
	print("[VERIFY] TASK_011 derived stats PASS (공격 25·최대체력 175·방어 5·완전회복)")

	# 4) 강화 비용 재계산
	if atk_upgrade_cost != 39 or hp_upgrade_cost != 28 or def_upgrade_cost != 69:
		_vfail("비용 atk=%d hp=%d def=%d (기대 39/28/69)" % [atk_upgrade_cost, hp_upgrade_cost, def_upgrade_cost]); return
	print("[VERIFY] TASK_011 upgrade cost PASS (공격 39·체력 28·방어 69)")

	# 5) 특성 포인트 재계산 (레벨 12 → 총 1, 강타 투자 1 → 보유 0)
	if total_trait_points_earned != 1 or trait_points != 0:
		_vfail("포인트 총=%d 보유=%d (기대 1/0)" % [total_trait_points_earned, trait_points]); return
	print("[VERIFY] TASK_011 traits PASS (총 포인트 1·강타 1·보유 0)")

	# 6) 런타임 전투 상태는 복원하지 않는다 (첫 늑대부터, 카운터 0, boss_defeated만 유지)
	if enemy_seq_index != 0 or boss_due or boss_fight_active or power_attack_counter != 0 or counter_hit_counter != 0 or not is_equal_approx(boss_time_left, BOSS_TIME_LIMIT):
		_vfail("런타임 seq=%d due=%s active=%s 카운터=%d/%d" % [enemy_seq_index, str(boss_due), str(boss_fight_active), power_attack_counter, counter_hit_counter]); return
	if not boss_defeated:
		_vfail("boss_defeated 유지 실패"); return
	print("[VERIFY] TASK_011 runtime not restored PASS (첫 늑대·카운터0·보스처치 유지)")

	# 7) 손상 JSON → 새 게임 + 오류 안내 상태
	_write_test_save_raw("{ invalid json")
	if _load_game() or not load_error:
		_vfail("손상 JSON load=%s err=%s" % [str(false), str(load_error)]); return
	print("[VERIFY] TASK_011 corrupt save fallback PASS (크래시 없이 새 게임)")

	# 8) 지원하지 않는 버전 → 새 게임
	_write_test_save_raw('{"version": 999}')
	if _load_game() or not load_error:
		_vfail("버전 999 load 처리 실패"); return
	print("[VERIFY] TASK_011 unsupported version PASS")

	# 9) 잘못된 특성(획득보다 투자 많음) → 거부
	_write_test_save_raw('{"version":1,"player":{"level":1,"exp":0,"gold":0},"upgrades":{"attack":0,"hp":0,"defense":0},"traits":{"power":1,"combo":1,"counter":1},"progress":{"boss_defeated":false,"bruno_settlement_done":false,"debt_remaining":10000,"debt_paid_total":0,"fame_rank":"무명 용병","fame_advanced":false}}')
	if _load_game():
		_vfail("잘못된 특성 저장 수락됨"); return
	print("[VERIFY] TASK_011 invalid traits rejected PASS")

	# 10) 저장 초기화 (파일 삭제 + 초기 상태 함수)
	_save_game()                    # 파일 생성
	if not FileAccess.file_exists(VERIFY_SAVE_PATH):
		_vfail("초기화 전 저장 파일 없음"); return
	_reset_save()                   # 검증 모드: 삭제 + _reset_to_new_game
	if FileAccess.file_exists(VERIFY_SAVE_PATH):
		_vfail("초기화 후 저장 파일 잔존"); return
	if level != 1 or gold != 0 or boss_defeated or debt_remaining != STARTING_DEBT:
		_vfail("초기화 후 상태 lv=%d gold=%d" % [level, gold]); return
	print("[VERIFY] TASK_011 reset save PASS (파일 삭제·신규 상태)")

	# 테스트 저장 파일 정리 + 진행 중 상태 복원
	_delete_save_file()
	_apply_loaded_state(pre)
	v_save = true
	print("[VERIFY] task011 저장·불러오기 ALL PASS")


# ── TASK_014 프로필 분리·사운드 훅 경계 검증 (결정적) ────────────
func _verify_task014() -> void:
	# 1) 적 5종 프로필이 모두 존재하고, 보스 상수가 프로필을 단일 출처로 한다
	for id in ["wolf", "goblin", "shield", "ogre", "bruno"]:
		if not EnemyProfiles.PROFILES.has(id):
			_vfail("프로필 누락 %s" % id); return
	if BOSS_MAX_HP != int(EnemyProfiles.PROFILES["bruno"]["max_hp"]) \
		or BOSS_ATK != int(EnemyProfiles.PROFILES["bruno"]["atk"]) \
		or BOSS_GOLD != int(EnemyProfiles.PROFILES["bruno"]["gold"]) \
		or BOSS_EXP != int(EnemyProfiles.PROFILES["bruno"]["exp"]):
		_vfail("보스 상수≠프로필"); return
	if not EnemyProfiles.PROFILES["ogre"]["is_elite"] or not EnemyProfiles.PROFILES["bruno"]["is_boss"]:
		_vfail("엘리트·보스 플래그"); return
	print("[VERIFY] TASK_014 profile data PASS (적 5종·보스 단일 출처·엘리트/보스 플래그)")

	# 2) 조회 결과는 복사본 — 수정해도 원본 PROFILES가 변하지 않는다
	var c := EnemyProfiles.get_profile("wolf")
	c["max_hp"] = 99999
	c["size"] = Vector2(1, 1)
	if int(EnemyProfiles.PROFILES["wolf"]["max_hp"]) != 32 \
		or not EnemyProfiles.PROFILES["wolf"]["size"].is_equal_approx(Vector2(78, 44)):
		_vfail("복사본 수정이 원본에 전파됨"); return
	print("[VERIFY] TASK_014 profile copy PASS (복사본 변경이 원본 불변)")

	# 3) 잘못된 프로필 id는 빈 Dictionary로 안전 처리
	if not EnemyProfiles.get_profile("does_not_exist").is_empty():
		_vfail("잘못된 프로필 id 비안전"); return
	print("[VERIFY] TASK_014 bad id PASS (없는 id → 빈 프로필)")

	# 4) 사운드 훅: 유효 이벤트는 호출당 정확히 1씩 증가, 잘못된 이름은 무시
	AudioHooks.reset_counts()
	if AudioHooks.EVENTS.size() != 19:
		_vfail("사운드 이벤트 수=%d (기대 19)" % AudioHooks.EVENTS.size()); return
	AudioHooks.play("merc_basic_attack")
	if AudioHooks.get_count("merc_basic_attack") != 1:
		_vfail("사운드 1회 호출=%d" % AudioHooks.get_count("merc_basic_attack")); return
	AudioHooks.play("merc_basic_attack")
	if AudioHooks.get_count("merc_basic_attack") != 2:
		_vfail("사운드 2회 호출=%d" % AudioHooks.get_count("merc_basic_attack")); return
	AudioHooks.play("not_a_real_event")
	if AudioHooks.get_count("not_a_real_event") != 0:
		_vfail("잘못된 사운드 이벤트가 계측됨"); return
	AudioHooks.reset_counts()
	if AudioHooks.get_count("merc_basic_attack") != 0:
		_vfail("reset 후 카운트 잔존"); return
	print("[VERIFY] TASK_014 audio hooks PASS (19 이벤트·호출당 1·잘못된 이름 무시·리셋)")

	v_task014 = true
	print("[VERIFY] task014 프로필·사운드 ALL PASS")


func _kill_merc() -> void:
	AudioHooks.play("merc_death")
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
	AudioHooks.play("merc_revive")
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
	status_label.position = Vector2(16, 12)
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
	# 화면 전체를 덮는 정보 패널이라 터치를 가로채지 않게 한다(아래 강화 버튼 등 입력 통과)
	_ignore_mouse(boss_ui)


# 컨트롤과 그 자식 전부가 터치/마우스를 가로채지 않게 설정(정보 표시 전용 오버레이)
func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_ignore_mouse(c)


# 상단 상태·경험치·알림·배경 등 비상호작용 표시를 입력 통과로 설정(버튼만 입력 받게)
func _ignore_decorative_mouse() -> void:
	for n in [status_label, exp_bg, exp_fill, levelup_label, windup_label, notify_label, trait_status_label, boss_progress_label]:
		if n != null:
			(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in bg_stripes:
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_boss_progress_label() -> void:
	# 상단 한 줄로 빚·명성·보스 진행을 함께 표시(기존 상태 두 줄 아래, 경험치 바 위).
	boss_progress_label = Label.new()
	boss_progress_label.position = Vector2(16, 68)
	boss_progress_label.add_theme_font_size_override("font_size", 18)
	boss_progress_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	add_child(boss_progress_label)


func _build_boss_result_panel() -> void:
	# 보스 처치 결과 패널: 개인 보상·빚 상환·명성 상승을 약 3.5초 표시(버튼 없음).
	boss_result_panel = Control.new()
	boss_result_panel.position = Vector2.ZERO
	boss_result_panel.size = SCREEN
	boss_result_panel.z_index = 60
	boss_result_panel.visible = false
	add_child(boss_result_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.09, 0.96)
	bg.size = SCREEN
	boss_result_panel.add_child(bg)

	boss_result_label = Label.new()
	boss_result_label.position = Vector2(40, 150)
	boss_result_label.size = Vector2(SCREEN.x - 80, 660)
	boss_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_result_label.add_theme_font_size_override("font_size", 28)
	boss_result_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	boss_result_panel.add_child(boss_result_label)
	_ignore_mouse(boss_result_panel)   # 결과 표시 중 입력이 멈춘 것처럼 느껴지지 않게


# 천 단위 구분 기호로 빚을 표기 (10000 → "10,000")
func _format_debt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


func _show_boss_result() -> void:
	boss_result_label.text = "보스 처치!\n철퇴의 브루노 격파.\n\n개인 보상\n골드 +%d   경험치 +%d\n\n빚 자동 상환\n%d골드\n남은 빚 %s → %s\n\n명성 상승\n무명 용병 → %s\n\n첫 지역 클리어!\n\n다음 모험은 아직 준비 중입니다." % [BOSS_GOLD, BOSS_EXP, last_payment, _format_debt(last_debt_before), _format_debt(debt_remaining), fame_rank]
	boss_result_panel.visible = true
	boss_result_panel.modulate = Color(1, 1, 1, 1)
	# 명성 강조: 결과 문구가 살짝 커졌다 제자리로
	boss_result_label.scale = Vector2(0.94, 0.94)
	boss_result_label.pivot_offset = boss_result_label.size * 0.5
	var ts := create_tween()
	ts.tween_property(boss_result_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 약 3.5초 후 자동으로 닫힘(버튼 없음)
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(boss_result_panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: boss_result_panel.visible = false)


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


# 상단 한 줄: 빚·명성과 보스까지 진행 상황을 함께 표시
func _update_boss_progress() -> void:
	if boss_progress_label == null:
		return
	var prog := ""
	if boss_defeated:
		prog = "첫 지역 완료"
	elif boss_fight_active:
		prog = "보스 전투"
	elif boss_due:
		prog = "보스 등장 예정"
	else:
		prog = "보스까지 %d / 8" % (enemy_seq_index % ENEMY_SEQUENCE.size())
	boss_progress_label.text = "빚 %s   명성 %s   ·   %s" % [_format_debt(debt_remaining), fame_rank, prog]


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


# ── 저장·불러오기 (TASK_011) ─────────────────────────────────────
func _get_save_path() -> String:
	return VERIFY_SAVE_PATH if verify_mode else SAVE_PATH


# 변경 후 일정 시간 뒤 한 번 저장 (적 처치·레벨업 등 지연 저장)
func _mark_dirty() -> void:
	if verify_mode:
		return
	if not save_dirty:
		save_dirty = true
		autosave_timer = AUTOSAVE_DELAY   # 첫 변경에서만 타이머 시작(무한 미룸 방지)


# 강화·특성·정산 등 중요한 변경은 즉시 저장
func _save_now() -> void:
	if verify_mode:
		return
	_save_game()
	save_dirty = false


func _update_autosave(delta: float) -> void:
	if verify_mode or not save_dirty:
		return
	autosave_timer -= delta
	if autosave_timer <= 0.0:
		_save_game()
		save_dirty = false


# 현재 핵심 상태를 JSON 저장용 Dictionary로 반환 (Node·객체는 넣지 않는다)
func _build_save_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player": {"level": level, "exp": exp, "gold": gold},
		"upgrades": {"attack": attack_upgrade_count, "hp": hp_upgrade_count, "defense": def_upgrade_count},
		"traits": {"power": power_trait_level, "combo": combo_trait_level, "counter": counter_trait_level},
		"progress": {
			"boss_defeated": boss_defeated,
			"bruno_settlement_done": bruno_settlement_done,
			"debt_remaining": debt_remaining,
			"debt_paid_total": debt_paid_total,
			"fame_rank": fame_rank,
			"fame_advanced": fame_advanced,
		},
	}


func _save_game() -> void:
	var file := FileAccess.open(_get_save_path(), FileAccess.WRITE)
	if file == null:
		# 열기 실패해도 게임을 중단하지 않는다 (Web 영구 저장 제한 등)
		push_warning("저장 파일을 열 수 없습니다: %s" % str(FileAccess.get_open_error()))
		if not verify_mode:
			var msg := "브라우저 설정에 따라 저장이 유지되지 않을 수 있습니다.\n비공개 모드는 사용하지 마세요." if OS.has_feature("web") else "저장에 실패했습니다."
			_show_notice(msg, 1.6)
		return
	file.store_string(JSON.stringify(_build_save_dict()))
	file.flush()
	file.close()


# 저장 파일을 읽고 검증 후 적용한다. 성공하면 true, 없거나 손상이면 false(새 게임).
func _load_game() -> bool:
	load_error = false
	var path := _get_save_path()
	if not FileAccess.file_exists(path):
		return false   # 저장 없음 → 안내 없이 새 게임
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_error = true
		return false
	var text := file.get_as_text()
	file.close()
	# 인스턴스 parse()는 실패해도 콘솔에 오류를 찍지 않아 손상 파일 처리에 조용하다
	var json := JSON.new()
	var ok_parse := json.parse(text) == OK
	if not ok_parse or not _validate_save(json.data):
		load_error = true
		if not verify_mode:
			_show_notice("저장 파일을 불러올 수 없습니다.\n새 게임으로 시작합니다.", 1.8)
		return false
	_apply_loaded_state(json.data)
	return true


# 손상·미지원·일관성 위반이면 false. 부분 적용 금지를 위해 적용 전에 전부 검증한다.
func _validate_save(d: Variant) -> bool:
	if typeof(d) != TYPE_DICTIONARY:
		return false
	if not d.has("version") or int(d["version"]) != SAVE_VERSION:
		return false
	for k in ["player", "upgrades", "traits", "progress"]:
		if not d.has(k) or typeof(d[k]) != TYPE_DICTIONARY:
			return false
	var p: Dictionary = d["player"]
	var u: Dictionary = d["upgrades"]
	var t: Dictionary = d["traits"]
	var g: Dictionary = d["progress"]
	var lv := int(p.get("level", 0))
	if lv < 1 or int(p.get("exp", -1)) < 0 or int(p.get("gold", -1)) < 0:
		return false
	if int(u.get("attack", -1)) < 0 or int(u.get("hp", -1)) < 0 or int(u.get("defense", -1)) < 0:
		return false
	for tk in ["power", "combo", "counter"]:
		var tv := int(t.get(tk, -1))
		if tv != 0 and tv != 1:
			return false
	var invested := int(t.get("power", 0)) + int(t.get("combo", 0)) + int(t.get("counter", 0))
	if invested > lv / 10:
		return false
	var debt := int(g.get("debt_remaining", -1))
	var paid := int(g.get("debt_paid_total", -1))
	if debt < 0 or debt > STARTING_DEBT or paid < 0 or paid > STARTING_DEBT:
		return false
	var fame := str(g.get("fame_rank", ""))
	if fame != FAME_NAMELESS and fame != FAME_ROOKIE:
		return false
	# 진행 일관성: 정상 상태 2종만 인정 (미처치 / 브루노 처치)
	var bd := bool(g.get("boss_defeated", false))
	var sd := bool(g.get("bruno_settlement_done", false))
	var fa := bool(g.get("fame_advanced", false))
	if bd:
		if not sd or not fa or fame != FAME_ROOKIE or debt != STARTING_DEBT - BRUNO_DEBT_PAYMENT or paid != BRUNO_DEBT_PAYMENT:
			return false
	else:
		if sd or fa or fame != FAME_NAMELESS or debt != STARTING_DEBT or paid != 0:
			return false
	return true


# 검증된 저장 데이터를 적용하고 파생 능력치·비용·포인트를 재계산한다.
func _apply_loaded_state(d: Dictionary) -> void:
	var p: Dictionary = d["player"]
	var u: Dictionary = d["upgrades"]
	var t: Dictionary = d["traits"]
	var g: Dictionary = d["progress"]
	level = int(p["level"])
	exp = int(p["exp"])
	gold = int(p["gold"])
	attack_upgrade_count = int(u["attack"])
	hp_upgrade_count = int(u["hp"])
	def_upgrade_count = int(u["defense"])
	power_trait_level = int(t["power"])
	combo_trait_level = int(t["combo"])
	counter_trait_level = int(t["counter"])
	boss_defeated = bool(g["boss_defeated"])
	bruno_settlement_done = bool(g["bruno_settlement_done"])
	debt_remaining = int(g["debt_remaining"])
	debt_paid_total = int(g["debt_paid_total"])
	fame_rank = str(g["fame_rank"])
	fame_advanced = bool(g["fame_advanced"])
	_normalize_exp()
	_recalc_after_load()


# 저장된 경험치가 필요량 이상이면 레벨업 규칙으로 정규화(연출·패널 없이)
func _normalize_exp() -> void:
	while exp >= _exp_to_next(level):
		exp -= _exp_to_next(level)
		level += 1


# 레벨·강화 횟수로 능력치·비용·특성 포인트·런타임 상태를 다시 계산한다.
func _recalc_after_load() -> void:
	var levelups := level - START_LEVEL
	if not merc.is_empty():
		merc.atk = MERC_ATK + attack_upgrade_count * ATK_UPGRADE_AMOUNT + levelups * LEVEL_ATK_GAIN
		merc.max_hp = MERC_MAX_HP + hp_upgrade_count * HP_UPGRADE_AMOUNT + levelups * LEVEL_HP_GAIN
		merc.defense = MERC_DEF + def_upgrade_count * DEF_UPGRADE_AMOUNT
		merc.hp = merc.max_hp                 # 불러오기 직후 완전 회복
		merc.state = WALK
		merc.atk_timer = 0.0
		_update_hp_bar(merc)
	atk_upgrade_cost = _cost_after_upgrades(ATK_UPGRADE_BASE_COST, ATK_COST_MULTIPLIER, attack_upgrade_count)
	hp_upgrade_cost = _cost_after_upgrades(HP_UPGRADE_BASE_COST, HP_COST_MULTIPLIER, hp_upgrade_count)
	def_upgrade_cost = _cost_after_upgrades(DEF_UPGRADE_BASE_COST, DEF_COST_MULTIPLIER, def_upgrade_count)
	total_trait_points_earned = level / 10
	trait_points = total_trait_points_earned - (power_trait_level + combo_trait_level + counter_trait_level)
	# 런타임 전투 상태는 저장하지 않으므로 항상 첫 늑대부터 시작
	power_attack_counter = 0
	counter_hit_counter = 0
	enemy_seq_index = 0
	boss_due = false
	boss_fight_active = false
	boss_time_left = BOSS_TIME_LIMIT
	goblin_run_start = -1
	_update_upgrade_ui()
	_update_trait_ui()
	_update_boss_progress()
	_update_status()


# 반복 반올림으로 강화 횟수만큼 진행된 현재 비용을 계산한다.
func _cost_after_upgrades(base_cost: int, multiplier: float, count: int) -> int:
	var cost := base_cost
	for i in range(count):
		cost = int(round(cost * multiplier))
	return cost


func _delete_save_file() -> void:
	var path := _get_save_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# 모든 진행을 새 게임 기본값으로 되돌린다 (저장 초기화·검증용)
func _reset_to_new_game() -> void:
	level = START_LEVEL
	exp = 0
	gold = 0
	attack_upgrade_count = 0
	hp_upgrade_count = 0
	def_upgrade_count = 0
	power_trait_level = 0
	combo_trait_level = 0
	counter_trait_level = 0
	trait_points = 0
	total_trait_points_earned = 0
	power_attack_counter = 0
	counter_hit_counter = 0
	boss_defeated = false
	boss_due = false
	boss_fight_active = false
	bruno_settlement_done = false
	debt_remaining = STARTING_DEBT
	debt_paid_total = 0
	fame_rank = FAME_NAMELESS
	fame_advanced = false
	atk_upgrade_cost = ATK_UPGRADE_BASE_COST
	hp_upgrade_cost = HP_UPGRADE_BASE_COST
	def_upgrade_cost = DEF_UPGRADE_BASE_COST
	enemy_seq_index = 0
	goblin_run_start = -1
	if not merc.is_empty():
		merc.atk = MERC_ATK
		merc.max_hp = MERC_MAX_HP
		merc.hp = MERC_MAX_HP
		merc.defense = MERC_DEF


# 저장 초기화: 파일 삭제 후 씬 재시작(검증 모드는 초기 상태 함수만)
func _reset_save() -> void:
	_delete_save_file()
	if verify_mode:
		_reset_to_new_game()
	else:
		get_tree().reload_current_scene()


# 저장 초기화 버튼: 2회 확인 (첫 누름은 3초간 경고 문구)
func _on_save_reset_pressed() -> void:
	if reset_confirm_timer > 0.0:
		reset_confirm_timer = 0.0
		_reset_save()
		return
	reset_confirm_timer = 3.0
	if save_reset_btn != null:
		save_reset_btn.text = "다시 누르면 전체 진행 초기화"


func _update_reset_confirm(delta: float) -> void:
	if reset_confirm_timer <= 0.0:
		return
	reset_confirm_timer -= delta
	if reset_confirm_timer <= 0.0 and save_reset_btn != null:
		save_reset_btn.text = "저장 초기화"


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
	b.pressed.connect(func() -> void: AudioHooks.play("ui_button"))
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
	_update_upgrade_ui.call_deferred()   # 골드 소진 시 버튼 비활성화를 다음 프레임으로 미뤄 입력 삼킴 방지
	_save_now()


func _do_hp_upgrade() -> void:
	gold -= hp_upgrade_cost
	merc.max_hp += HP_UPGRADE_AMOUNT
	merc.hp = mini(merc.hp + HP_UPGRADE_AMOUNT, merc.max_hp)  # 잃은 체력 유지, 완전 회복 아님
	hp_upgrade_cost = int(round(hp_upgrade_cost * HP_COST_MULTIPLIER))
	hp_upgrade_count += 1
	_update_hp_bar(merc)
	_update_upgrade_ui.call_deferred()
	_save_now()


func _do_def_upgrade() -> void:
	gold -= def_upgrade_cost
	merc.defense += DEF_UPGRADE_AMOUNT
	def_upgrade_cost = int(round(def_upgrade_cost * DEF_COST_MULTIPLIER))
	def_upgrade_count += 1
	_update_upgrade_ui.call_deferred()
	_save_now()


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

	# 저장 초기화: 특성만 되돌리는 무료 초기화와 구분되는 전체 진행 초기화(2회 확인)
	save_reset_btn = Button.new()
	save_reset_btn.position = Vector2(40, 640)
	save_reset_btn.size = Vector2(460, 60)
	save_reset_btn.add_theme_font_size_override("font_size", 24)
	save_reset_btn.text = "저장 초기화"
	save_reset_btn.pressed.connect(_on_save_reset_pressed)
	trait_panel.add_child(save_reset_btn)


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
	b.pressed.connect(func() -> void: AudioHooks.play("ui_button"))
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
		_update_trait_ui.call_deferred()   # 다음 프레임 갱신 — 방금 누른 버튼 비활성화가 다음 터치를 삼키지 않게
		_save_now()


func _invest_combo() -> void:
	if trait_points > 0 and combo_trait_level < 1:
		combo_trait_level = 1
		trait_points -= 1
		_update_trait_ui.call_deferred()
		_save_now()


func _invest_counter() -> void:
	if trait_points > 0 and counter_trait_level < 1:
		counter_trait_level = 1
		trait_points -= 1
		_update_trait_ui.call_deferred()
		_save_now()


func _reset_traits() -> void:
	# 투자 포인트를 모두 보유로 반환하고 전투 카운터 초기화 (무료)
	trait_points += power_trait_level + combo_trait_level + counter_trait_level
	power_trait_level = 0
	combo_trait_level = 0
	counter_trait_level = 0
	power_attack_counter = 0
	counter_hit_counter = 0
	_update_trait_ui.call_deferred()
	_save_now()


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
