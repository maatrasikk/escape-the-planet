extends Node

signal day_changed(day: int, energy: int)
signal progress_changed()
signal enemy_state_changed(present: bool, last_damage: int)
signal shield_changed(hp: int, max_hp: int)
signal game_over(victory: bool, reason: String)

var day: int = 1
var energy_max: int = 100
var energy: int = energy_max

var daily_spend_cap: int = 10  # максимум энергии за день

# Прогресс целей
var debris_found: int = 0
const DEBRIS_NEEDED: int = 5
var antenna_progress: int = 0  # 0..100

# Щит
var shield_hp: int = 100
const SHIELD_HP_MAX: int = 100

# Распределения энергии на текущий день
var alloc_search: int = 0
var alloc_antenna: int = 0
var alloc_shield: int = 0

# Враги
var enemy_present: bool = false
var last_enemy_damage: int = 0

# Константы логики
const ENEMY_SPAWN_CHANCE: float = 0.5
const ENEMY_DAMAGE_MIN: int = 20
const ENEMY_DAMAGE_MAX: int = 40
const SHIELD_REPAIR_PER_ENERGY: int = 10  # 1 энергия = 10 HP щита

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func get_daily_limit() -> int:
	return min(daily_spend_cap, energy)

func get_daily_allocation_total() -> int:
	return alloc_search + alloc_antenna + alloc_shield

func get_daily_allocation_left() -> int:
	return max(0, get_daily_limit() - get_daily_allocation_total())

# КЛЮЧЕВАЯ ПРАВКА — упрощённая установка распределений:
# (не заполняем насильно остаток, просто следим за лимитом)
func set_allocations(search: int, antenna: int, shield: int) -> void:
	var limit := get_daily_limit()
	search = clampi(search, 0, limit)
	antenna = clampi(antenna, 0, limit)
	shield = clampi(shield, 0, limit)

	var total := search + antenna + shield
	if total > limit:
		var overflow := total - limit
		# Сначала режем shield, потом antenna, потом search (приоритет сохранения "поиска")
		if shield >= overflow:
			shield -= overflow
			overflow = 0
		else:
			overflow -= shield
			shield = 0
			if antenna >= overflow:
				antenna -= overflow
				overflow = 0
			else:
				overflow -= antenna
				antenna = 0
				search = max(0, search - overflow)

	alloc_search = search
	alloc_antenna = antenna
	alloc_shield = shield
	emit_signal("progress_changed")

func next_day() -> void:
	# 1. Списываем энергию за распределённое (но не больше реального доступного лимита)
	var limit := get_daily_limit()
	var total_alloc : int = min(get_daily_allocation_total(), limit)
	energy -= total_alloc
	if energy < 0:
		energy = 0

	# 2. Поиск обломка (максимум один за день)
	if debris_found < DEBRIS_NEEDED and alloc_search > 0:
		var chance: float = clampf(float(alloc_search) * 0.1, 0.0, 1.0)  # 1 энергия = 10% шанса
		if _rng.randf() < chance:
			debris_found += 1

	# 3. Починка антенны (1 энергия = +4%)
	if alloc_antenna > 0 and antenna_progress < 100:
		antenna_progress = min(100, antenna_progress + alloc_antenna * 4)

	# 4. Ремонт щита (перед ударом врагов)
	if alloc_shield > 0 and shield_hp < SHIELD_HP_MAX:
		var repaired := alloc_shield * SHIELD_REPAIR_PER_ENERGY
		shield_hp = min(SHIELD_HP_MAX, shield_hp + repaired)

	# 5. Применяем урон врагов, если они были на поле
	last_enemy_damage = 0
	if enemy_present:
		last_enemy_damage = _rng.randi_range(ENEMY_DAMAGE_MIN, ENEMY_DAMAGE_MAX)
		shield_hp -= last_enemy_damage
		if shield_hp < 0:
			shield_hp = 0

	# 6. Проверка победы / поражения
	var victory := get_victory_reached()
	var defeat := false
	var defeat_reason := ""

	if shield_hp <= 0 and not victory:
		defeat = true
		defeat_reason = "shield_destroyed"
	elif energy <= 0 and not victory:
		defeat = true
		defeat_reason = "out_of_energy"

	# 7. Спавн врагов на следующий день, если игра продолжается
	if not victory and not defeat:
		enemy_present = (_rng.randf() < ENEMY_SPAWN_CHANCE)
	else:
		enemy_present = false

	# 8. Сброс распределений
	alloc_search = 0
	alloc_antenna = 0
	alloc_shield = 0

	# 9. Увеличиваем день
	day += 1

	# 10. Сигналы
	emit_signal("day_changed", day, energy)
	emit_signal("progress_changed")
	emit_signal("shield_changed", shield_hp, SHIELD_HP_MAX)
	emit_signal("enemy_state_changed", enemy_present, last_enemy_damage)

	if victory or defeat:
		emit_signal("game_over", victory, victory if victory else defeat_reason)

func get_victory_reached() -> bool:
	return debris_found >= DEBRIS_NEEDED and antenna_progress >= 100

func get_status_dict() -> Dictionary:
	return {
		"day": day,
		"energy": energy,
		"energy_max": energy_max,
		"debris_found": debris_found,
		"debris_needed": DEBRIS_NEEDED,
		"antenna_progress": antenna_progress,
		"shield_hp": shield_hp,
		"shield_hp_max": SHIELD_HP_MAX,
		"enemy_present": enemy_present,
		"last_enemy_damage": last_enemy_damage,
		"alloc_search": alloc_search,
		"alloc_antenna": alloc_antenna,
		"alloc_shield": alloc_shield,
		"daily_limit": get_daily_limit(),
		"alloc_left": get_daily_allocation_left()
	}
