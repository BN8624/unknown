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

# 일반 적 외형 풀(이름·색·반지름·스프라이트). color는 파티클/오라용, sprite는 Kenney CC0 픽셀 타일.
const ENEMY_LOOKS := [
	{"name": "들개",      "color": Color(0.62, 0.45, 0.30), "r": 30.0, "sprite": "wild_dog"},
	{"name": "부패 정령", "color": Color(0.45, 0.70, 0.45), "r": 28.0, "sprite": "rot_spirit"},
	{"name": "균열 고블린","color": Color(0.55, 0.60, 0.35), "r": 30.0, "sprite": "rift_goblin"},
	{"name": "가시벌레",   "color": Color(0.70, 0.45, 0.55), "r": 26.0, "sprite": "spike_bug"},
	{"name": "그림자 망령","color": Color(0.55, 0.50, 0.72), "r": 30.0, "sprite": "shadow_wraith"},
]
# 보스 외형 풀(5·10·15·20 순서) — 스프라이트를 크게 확대해 표시
const BOSS_LOOKS := [
	{"name": "거대 거미 아라크",  "color": Color(0.80, 0.30, 0.35), "r": 52.0, "sprite": "arachne"},
	{"name": "이끼 골렘 모스",    "color": Color(0.45, 0.75, 0.45), "r": 58.0, "sprite": "moss_golem"},
	{"name": "망령군주 베일",     "color": Color(0.60, 0.45, 0.85), "r": 56.0, "sprite": "wraith_lord"},
	{"name": "균열의 수호자",     "color": Color(0.85, 0.50, 0.30), "r": 64.0, "sprite": "rift_guardian"},
]

# ── 지역(테마·적 외형·하늘) ──────────────────────────────────────
# 스탯은 전역 스테이지 공식으로 연속 유지하고, 지역은 이름·외형·하늘색만 바꾼다(밸런스 불연속 방지).
const REGIONS := [
	{
		"name": "갈라진 변경", "end": 20, "sky": Color(0.18, 0.14, 0.30),
		"enemy_looks": ENEMY_LOOKS, "boss_looks": BOSS_LOOKS,
	},
	{
		"name": "잿빛 협곡", "end": 40, "sky": Color(0.22, 0.13, 0.12),
		"enemy_looks": [
			{"name": "잿불 박쥐",   "color": Color(0.72, 0.40, 0.28), "r": 26.0, "sprite": "ember_bat"},
			{"name": "용암 슬라임", "color": Color(0.80, 0.46, 0.22), "r": 28.0, "sprite": "lava_slime"},
			{"name": "그을린 늑대", "color": Color(0.50, 0.36, 0.30), "r": 30.0, "sprite": "scorched_wolf"},
			{"name": "재 정령",     "color": Color(0.62, 0.55, 0.50), "r": 30.0, "sprite": "ash_spirit"},
			{"name": "불씨 골렘",   "color": Color(0.70, 0.34, 0.24), "r": 32.0, "sprite": "cinder_golem"},
		],
		"boss_looks": [
			{"name": "화염군주 이그", "color": Color(0.95, 0.40, 0.22), "r": 54.0, "sprite": "flame_lord"},
			{"name": "용암 거인 칼",  "color": Color(0.90, 0.50, 0.25), "r": 60.0, "sprite": "lava_giant"},
			{"name": "잿빛 드레이크", "color": Color(0.70, 0.55, 0.50), "r": 58.0, "sprite": "ashen_drake"},
			{"name": "협곡의 지배자", "color": Color(0.95, 0.35, 0.25), "r": 66.0, "sprite": "canyon_ruler"},
		],
	},
	{
		"name": "얼어붙은 심연", "end": 60, "sky": Color(0.10, 0.14, 0.24),
		"enemy_looks": [
			{"name": "서리 망령",   "color": Color(0.55, 0.70, 0.95), "r": 30.0, "sprite": "frost_wraith"},
			{"name": "얼음 슬라임", "color": Color(0.50, 0.75, 0.95), "r": 28.0, "sprite": "ice_slime"},
			{"name": "동토 늑대",   "color": Color(0.60, 0.70, 0.85), "r": 30.0, "sprite": "tundra_wolf"},
			{"name": "심연 술사",   "color": Color(0.62, 0.58, 0.92), "r": 30.0, "sprite": "abyss_sorcerer"},
			{"name": "한기 거미",   "color": Color(0.55, 0.65, 0.92), "r": 26.0, "sprite": "chill_spider"},
		],
		"boss_looks": [
			{"name": "빙결군주 헬름", "color": Color(0.55, 0.75, 1.0),  "r": 56.0, "sprite": "frost_lord"},
			{"name": "심연 거미 여왕","color": Color(0.50, 0.62, 0.95), "r": 60.0, "sprite": "spider_queen"},
			{"name": "얼어붙은 망령왕","color": Color(0.62, 0.72, 1.0), "r": 58.0, "sprite": "frozen_wraith_king"},
			{"name": "심연의 지배자", "color": Color(0.55, 0.70, 1.0),  "r": 68.0, "sprite": "abyss_ruler"},
		],
	},
]

# 스테이지가 속한 지역(마지막 지역으로 클램프 — 그 너머는 마지막 지역 테마 유지).
static func region_for(stage: int) -> Dictionary:
	for reg in REGIONS:
		if stage <= int(reg["end"]):
			return reg
	return REGIONS[REGIONS.size() - 1]

# 이 스테이지가 어느 지역의 마지막(최종 보스)인가.
static func is_region_final(stage: int) -> bool:
	for reg in REGIONS:
		if stage == int(reg["end"]):
			return true
	return false

static func is_boss_stage(stage: int) -> bool:
	return stage % BOSS_EVERY == 0

# 일반 적 스탯(스테이지 기반 스케일). 보스는 배수 적용.
# 밸런스 검증(tools/sim.py): 첫보스 ~1분, 20층 ~5분, 30층 ~14분, 40층 ~40분 → 이후 환생 유도.
# hp 스케일 1.17→1.16로 2지역 벽 완화(52분→40분). 환생 배수(x1.5~3)로 재주행 가속.
static func enemy_hp(stage: int) -> int:
	return int(round(30.0 * pow(1.16, stage - 1)))

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
static func make_enemy(stage: int, force_normal := false) -> Dictionary:
	var boss := is_boss_stage(stage) and not force_normal
	var hp := enemy_hp(stage)
	var atk := enemy_atk(stage)
	var gold := enemy_gold(stage)
	var exp := enemy_exp(stage)
	var reg := region_for(stage)
	var look: Dictionary
	if boss:
		hp = int(round(hp * BOSS_HP_MULT))
		atk = int(round(atk * BOSS_ATK_MULT))
		gold = int(round(gold * BOSS_GOLD_MULT))
		exp = int(round(exp * BOSS_EXP_MULT))
		var bl: Array = reg["boss_looks"]
		look = bl[(int(stage / BOSS_EVERY) - 1) % bl.size()]
	else:
		var el: Array = reg["enemy_looks"]
		look = el[(stage * 3 + _kill_salt) % el.size()]
	return {
		"name": look["name"], "color": look["color"], "r": look["r"],
		"sprite": look.get("sprite", ""), "tint": look.get("tint", Color.WHITE),
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
	{"id": "s_crit", "name": "처형",       "desc": "치명타 피해",  "per": 0.15, "cost": 3, "mult": 1.7},
	{"id": "s_cd",   "name": "각성",       "desc": "스킬 쿨감",    "per": 0.05, "cost": 5, "mult": 1.9},
]

static func soul_upgrade_def(id: String) -> Dictionary:
	for u in SOUL_UPGRADES:
		if u["id"] == id:
			return u
	return {}

static func soul_upgrade_cost(udef: Dictionary, level: int) -> int:
	return int(round(float(udef["cost"]) * pow(float(udef["mult"]), level)))

# ── 임무(리텐션) ─────────────────────────────────────────────────
# type: kill/stage/upgrade/boss/gold 누적 카운터. w: 보상 가중치(현재 스테이지 골드 수입 기준 배수).
const MISSION_POOL := [
	{"type": "kill",    "amount": 50,     "w": 50,  "text": "마물 %d마리 처치"},
	{"type": "kill",    "amount": 200,    "w": 120, "text": "마물 %d마리 처치"},
	{"type": "stage",   "amount": 5,      "w": 70,  "text": "%d개 층 전진"},
	{"type": "stage",   "amount": 15,     "w": 160, "text": "%d개 층 전진"},
	{"type": "upgrade", "amount": 10,     "w": 60,  "text": "강화 %d회"},
	{"type": "upgrade", "amount": 30,     "w": 130, "text": "강화 %d회"},
	{"type": "boss",    "amount": 2,      "w": 90,  "text": "보스 %d처치"},
	{"type": "gold",    "amount": 5000,   "w": 80,  "text": "골드 %s 획득"},
]

# 임무 보상 골드(현재 스테이지 골드 수입 × 가중치). 진행도에 맞춰 항상 의미 있게.
static func mission_reward(udef: Dictionary, stage: int) -> int:
	return int(round(enemy_gold(stage) * float(udef["w"])))

# 일일 보상 골드(연속일 보너스 포함, 현재 스테이지 기준).
const DAILY_W := 200
static func daily_reward(stage: int, streak: int) -> int:
	return int(round(enemy_gold(stage) * DAILY_W * (1.0 + mini(streak, 6) * 0.25)))

# ── 업적(영구 보상) ──────────────────────────────────────────────
# stat: max_stage/kill/boss/prestige/upgrade/gold 기준. 달성 시 bonus(전투력·골드 영구 배수)에 가산.
const ACHIEVEMENTS := [
	{"id": "f10",  "stat": "max_stage", "target": 10,      "name": "변경의 개척자",   "bonus": 0.03},
	{"id": "f25",  "stat": "max_stage", "target": 25,      "name": "협곡의 도전자",   "bonus": 0.04},
	{"id": "f40",  "stat": "max_stage", "target": 40,      "name": "협곡 정복자",     "bonus": 0.05},
	{"id": "f60",  "stat": "max_stage", "target": 60,      "name": "심연의 답사자",   "bonus": 0.06},
	{"id": "f80",  "stat": "max_stage", "target": 80,      "name": "심연 깊은 곳",     "bonus": 0.08},
	{"id": "f100", "stat": "max_stage", "target": 100,     "name": "100층 등정",      "bonus": 0.10},
	{"id": "f150", "stat": "max_stage", "target": 150,     "name": "무한의 방랑자",   "bonus": 0.15},
	{"id": "k100", "stat": "kill",      "target": 100,     "name": "첫 사냥",         "bonus": 0.02},
	{"id": "k1k",  "stat": "kill",      "target": 1000,    "name": "마물 사냥꾼",     "bonus": 0.04},
	{"id": "k10k", "stat": "kill",      "target": 10000,   "name": "마물의 천적",     "bonus": 0.07},
	{"id": "k100k","stat": "kill",      "target": 100000,  "name": "학살자",         "bonus": 0.12},
	{"id": "b10",  "stat": "boss",      "target": 10,      "name": "보스 사냥",       "bonus": 0.04},
	{"id": "b50",  "stat": "boss",      "target": 50,      "name": "보스 학살",       "bonus": 0.07},
	{"id": "b150", "stat": "boss",      "target": 150,     "name": "지배자 처형인",   "bonus": 0.12},
	{"id": "p1",   "stat": "prestige",  "target": 1,       "name": "첫 환생",         "bonus": 0.05},
	{"id": "p5",   "stat": "prestige",  "target": 5,       "name": "거듭난 기사",     "bonus": 0.08},
	{"id": "p15",  "stat": "prestige",  "target": 15,      "name": "윤회의 기사",     "bonus": 0.12},
	{"id": "p30",  "stat": "prestige",  "target": 30,      "name": "영겁의 기사",     "bonus": 0.18},
	{"id": "u50",  "stat": "upgrade",   "target": 50,      "name": "단련",           "bonus": 0.03},
	{"id": "u200", "stat": "upgrade",   "target": 200,     "name": "정진",           "bonus": 0.05},
	{"id": "u500", "stat": "upgrade",   "target": 500,     "name": "극한 단련",       "bonus": 0.09},
	{"id": "g1m",  "stat": "gold",      "target": 1000000, "name": "백만장자",       "bonus": 0.05},
	{"id": "g1b",  "stat": "gold",      "target": 1000000000, "name": "억만장자",    "bonus": 0.10},
]

# ── 오프라인 보상 ────────────────────────────────────────────────
const OFFLINE_CAP_SEC := 8 * 3600   # 최대 8시간 정산
const OFFLINE_EFFICIENCY := 0.6     # 활동 대비 효율
const OFFLINE_MIN_SEC := 60         # 1분 미만은 정산·표시 안 함
