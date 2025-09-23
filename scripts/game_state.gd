extends Node

signal day_changed(day: int, energy: int)

var day: int = 1
var energy_max: int = 100
var energy: int = energy_max

func next_day(spent: int) -> int:
	var allowed: int = clampi(spent, 0, energy)
	energy -= allowed
	day += 1
	emit_signal("day_changed", day, energy)
	return allowed
