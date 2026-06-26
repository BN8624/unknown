# 적·보스 5종의 전투 중 변하지 않는 고정 프로필 데이터만 보관(전투 로직 없음)
extends RefCounted

# 일반 적 3종 + 엘리트 1종 + 보스 1종의 고정값.
# 이동 대상만 담는다: 이름·체력·공격력·방어력·공격 간격·접근 속도·골드/경험치 보상·엘리트/보스 여부·표시 크기/색상.
# 현재 체력·위치·타이머·공격 패턴·방어 태세·자세 붕괴 등 전투 상태값은 여기 두지 않는다(Battle.gd 소관).
const PROFILES := {
	"wolf": {
		"name": "굶주린 늑대", "max_hp": 32, "atk": 5, "defense": 0,
		"interval": 0.75, "approach_speed": 230.0, "gold": 5, "exp": 5,
		"is_elite": false, "is_boss": false,
		"size": Vector2(78, 44), "color": Color(0.64, 0.34, 0.24),
	},
	"goblin": {
		"name": "고블린", "max_hp": 22, "atk": 4, "defense": 0,
		"interval": 1.0, "approach_speed": 200.0, "gold": 4, "exp": 4,
		"is_elite": false, "is_boss": false,
		"size": Vector2(42, 64), "color": Color(0.32, 0.72, 0.34),
	},
	"shield": {
		"name": "방패병", "max_hp": 75, "atk": 8, "defense": 5,
		"interval": 1.5, "approach_speed": 130.0, "gold": 12, "exp": 10,
		"is_elite": false, "is_boss": false,
		"size": Vector2(66, 96), "color": Color(0.52, 0.57, 0.64),
	},
	"ogre": {
		"name": "오우거 징수꾼", "max_hp": 240, "atk": 16, "defense": 3,
		"interval": 2.0, "approach_speed": 100.0, "gold": 40, "exp": 30,
		"is_elite": true, "is_boss": false,
		"size": Vector2(108, 132), "color": Color(0.72, 0.42, 0.20),
	},
	"bruno": {
		"name": "철퇴의 브루노", "max_hp": 850, "atk": 15, "defense": 6,
		"interval": 2.0, "approach_speed": 95.0, "gold": 200, "exp": 100,
		"is_elite": false, "is_boss": true,
		"size": Vector2(132, 156), "color": Color(0.50, 0.12, 0.30),
	},
}

# 프로필 조회: 항상 깊은 복사본을 돌려준다.
# 전투 중 반환값을 수정해도 PROFILES 원본은 변하지 않는다.
# 잘못된 id면 경고 후 빈 Dictionary 반환(호출부에서 안전 처리).
static func get_profile(id: String) -> Dictionary:
	if not PROFILES.has(id):
		push_warning("EnemyProfiles: unknown profile id '%s'" % id)
		return {}
	return PROFILES[id].duplicate(true)
