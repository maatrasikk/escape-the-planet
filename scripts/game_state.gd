extends Node

signal day_changed(day: int, energy: int)

var day: int = 1
var energy_max: int = 100
var energy: int = energy_max

var daily_spend_cap:int = 10

func next_day(spent:int) -> int:
# разрешим потратить не больше daily_spend_cap и не больше имеющейся энергии
	var allowed := clampi(spent, 0, min(energy, daily_spend_cap))
	energy -= allowed
	day += 1
	emit_signal("day_changed", day, energy)
	return allowed
