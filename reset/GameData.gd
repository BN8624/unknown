# 게임 밸런스·콘텐츠 데이터 (화면 코드와 분리, 수치는 여기서만 조정한다) — 균열기사 v0.1
extends RefCounted

const GAME_TITLE := "균열기사"
const REGION_NAME := "갈라진 변경"
const SCREEN := Vector2(540, 960)

# ── 플레이어 기본값 ──────────────────────────────────────────────
const PLAYER_BASE := {
	"atk": 10, "hp": 100, "def": 0,
	"crit": 0.03, "crit_mult": 2.0,
	"atk_interval": 0.85,   # 초당 약 1.2회 공격
}
# 레벨업 보상(자동 성장)
const LVL_ATK := 2
const LVL_HP := 12

# ── 성장 항목(5종) ───────────────────────────────────────────────
# per: 레벨당 증가량(crit·gold는 비율). cost/mult: 비용 base와 증가 배수. kind: 표시 방식.
const UPGRADES := [
	{"id": "atk",  "name": "공격력",     "per": 3,    "cost": 12, "mult": 1.15, "kind": "int"},
	{"id": "hp",   "name": "체력",       "per": 22,   "cost": 12, "mult": 1.15, "kind": "int"},
	{"id": "def",  "name": "방어력",     "per": 1,    "cost": 18, "mult": 1.18, "kind": "int"},
	{"id": "crit", "name": "치명타",     "per": 0.01, "cost": 40, "mult": 1.22, "kind": "pct"},
	{"id": "gold", "name": "골드 획득",  "per": 0.08, "cost": 50, "mult": 1.22, "kind": "pct"},
]

# ── 스테이지 ─────────────────────────────────────────────────────
const STAGE_COUNT := 20        # 지역 최종 스테이지(이후는 엔드리스)
const BOSS_EVERY := 5          # 5,10,15,20 = 보스
const KILLS_PER_STAGE := 8     # 일반 스테이지 클리어에 필요한 처치 수

# 일반 적 외형 풀(이름·색·반지름) — 표시용 순환(스탯은 스테이지로 계산)
const ENEMY_LOOKS := [
	{"name": "들개",      "color": Color(0.62, 0.45, 0.30), "r": 30.0},
	{"name": "부패 정령", "color": Color(0.45, 0.70, 0.45), "r": 28.0},
	{"name": "균열 고블린","color": Color(0.55, 0.60, 0.35), "r": 30.0},
	{"name": "가시벌레",   "color": Color(0.70, 0.45, 0.55), "r": 26.0},
	{"name": "그림자 망령","color": Color(0.45, 0.45, 0.62), "r": 32.0},
]
# 보스 외형 풀(5·10·15·20 순서)
const BOSS_LOOKS := [
	{"name": "거대 거미 아라크",  "color": Color(0.55, 0.25, 0.30), "r": 52.0},
	{"name": "이끼 골렘 모스",    "color": Color(0.35, 0.55, 0.40), "r": 58.0},
	{"name": "망령군주 베일",     "color": Color(0.40, 0.35, 0.62), "r": 56.0},
	{"name": "균열의 수호자",     "color": Color(0.70, 0.35, 0.25), "r": 64.0},
]

static func is_boss_stage(stage: int) -> bool:
	return stage % BOSS_EVERY == 0

# 일반 적 스탯(스테이지 기반 스케일). 보스는 배수 적용.
static func enemy_hp(stage: int) -> int:
	return int(round(30.0 * pow(1.17, stage - 1)))

static func enemy_atk(stage: int) -> int:
	return int(round(6.0 * pow(1.11, stage - 1)))

static func enemy_gold(stage: int) -> int:
	return int(round(5.0 * pow(1.12, stage - 1)))

static func enemy_exp(stage: int) -> int:
	return int(round(4.0 * pow(1.10, stage - 1)))

const BOSS_HP_MULT := 9.0
const BOSS_ATK_MULT := 1.6
const BOSS_GOLD_MULT := 12.0
const BOSS_EXP_MULT := 7.0
const ENEMY_ATK_INTERVAL := 1.25

# 적 한 마리의 완성 스탯 딕셔너리(외형 포함)를 만든다.
static func make_enemy(stage: int) -> Dictionary:
	var boss := is_boss_stage(stage)
	var hp := enemy_hp(stage)
	var atk := enemy_atk(stage)
	var gold := enemy_gold(stage)
	var exp := enemy_exp(stage)
	var look: Dictionary
	if boss:
		hp = int(round(hp * BOSS_HP_MULT))
		atk = int(round(atk * BOSS_ATK_MULT))
		gold = int(round(gold * BOSS_GOLD_MULT))
		exp = int(round(exp * BOSS_EXP_MULT))
		look = BOSS_LOOKS[(int(stage / BOSS_EVERY) - 1) % BOSS_LOOKS.size()]
	else:
		look = ENEMY_LOOKS[(stage * 3 + _kill_salt) % ENEMY_LOOKS.size()]
	return {
		"name": look["name"], "color": look["color"], "r": look["r"],
		"boss": boss, "max_hp": hp, "hp": hp, "atk": atk,
		"gold": gold, "exp": exp, "interval": ENEMY_ATK_INTERVAL,
	}

# 같은 스테이지 안에서도 일반 적 외형이 조금씩 바뀌도록 흔드는 값(시각 변화용, 스탯 무관).
static var _kill_salt := 0
static func bump_salt() -> void:
	_kill_salt += 1

# ── 레벨·성장 비용 ───────────────────────────────────────────────
static func exp_to_next(level: int) -> int:
	return 20 + level * 12

static func upgrade_cost(udef: Dictionary, level: int) -> int:
	return int(round(float(udef["cost"]) * pow(float(udef["mult"]), level)))

# 성장 항목 정의를 id로 찾는다.
static func upgrade_def(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}

# ── 환생(프레스티지) ─────────────────────────────────────────────
const SOUL_NAME := "균열석"
const SOUL_MIN_STAGE := 5        # 첫 보스(5층) 클리어부터 환생 가능
const SOUL_PER_MULT := 0.04      # 균열석 1개당 전투력·골드 +4%

# 지금 환생하면 얻을 균열석. 도달한 최고 스테이지가 높을수록 많이.
static func souls_for(max_stage_cleared: int) -> int:
	if max_stage_cleared < SOUL_MIN_STAGE:
		return 0
	return int(floor(pow(float(max_stage_cleared), 1.55) * 0.5))

# 보유 균열석으로 인한 영구 배수(전투력·골드에 곱).
static func global_mult(souls: int) -> float:
	return 1.0 + souls * SOUL_PER_MULT

# 균열석 상점(환생해도 유지되는 영구 강화). per=레벨당 효과, cost/mult=균열석 비용.
const SOUL_UPGRADES := [
	{"id": "s_atk",  "name": "예리함",     "desc": "공격력",       "per": 0.06, "cost": 2, "mult": 1.6},
	{"id": "s_gold", "name": "탐욕",       "desc": "골드 획득",    "per": 0.10, "cost": 2, "mult": 1.6},
	{"id": "s_hp",   "name": "불굴",       "desc": "체력",         "per": 0.10, "cost": 3, "mult": 1.7},
	{"id": "s_off",  "name": "잠든 부대",  "desc": "오프라인 효율","per": 0.12, "cost": 4, "mult": 1.8},
]

static func soul_upgrade_def(id: String) -> Dictionary:
	for u in SOUL_UPGRADES:
		if u["id"] == id:
			return u
	return {}

static func soul_upgrade_cost(udef: Dictionary, level: int) -> int:
	return int(round(float(udef["cost"]) * pow(float(udef["mult"]), level)))

# ── 오프라인 보상 ────────────────────────────────────────────────
const OFFLINE_CAP_SEC := 8 * 3600   # 최대 8시간 정산
const OFFLINE_EFFICIENCY := 0.6     # 활동 대비 효율
const OFFLINE_MIN_SEC := 60         # 1분 미만은 정산·표시 안 함
