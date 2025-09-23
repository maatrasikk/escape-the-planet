extends Panel

@onready var day_label: Label        = $VBoxContainer/DayLabel
@onready var energy_label: Label     = $VBoxContainer/EnergyLabel
@onready var spend_spin: SpinBox     = $VBoxContainer/HBoxContainer/SpendSpin
@onready var next_day_button: Button = $VBoxContainer/HBoxContainer/NextDayButton
@onready var close_button: Button    = $VBoxContainer/CloseBtn

func _ready() -> void:
	if not GameState.is_connected("day_changed", Callable(self, "_on_day_changed")):
		GameState.connect("day_changed", Callable(self, "_on_day_changed"))
		next_day_button.connect("pressed", Callable(self, "_on_next_day_pressed"))
		close_button.connect("pressed", Callable(self, "_on_close_pressed"))
		hide()
		_debug_missing()

func open() -> void:
	_refresh()
	show()

func open_at_world(world_pos: Vector2) -> void:
	_refresh()
	var sp := world_to_screen(world_pos)
	sp += Vector2(-size.x * 0.5, -size.y - 8)
	var vp := get_viewport_rect().size
	sp.x = clampf(sp.x, 0.0, vp.x - size.x)
	sp.y = clampf(sp.y, 0.0, vp.y - size.y)
	position = sp
	show()

func _refresh() -> void:
	if day_label == null or energy_label == null or spend_spin == null: return
	day_label.text = "День: %d" % GameState.day
	energy_label.text = "Энергия: %d / %d" % [GameState.energy, GameState.energy_max]
	spend_spin.min_value = 0
	spend_spin.max_value = min(GameState.energy, GameState.daily_spend_cap)
	if spend_spin.value > spend_spin.max_value:
		spend_spin.value = spend_spin.max_value
		next_day_button.disabled = (spend_spin.max_value == 0)

func _on_day_changed(_d: int, _e: int) -> void:
	if visible:
		_refresh()

func _on_next_day_pressed() -> void:
	var amount: int = int(spend_spin.value)
	GameState.next_day(amount)
	hide()

func _on_close_pressed() -> void:
	hide()

func world_to_screen(world_pos: Vector2) -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam == null: return world_pos
	var vp_size := get_viewport_rect().size
	var screen_center := vp_size / 2
	return (world_pos - cam.global_position) * cam.zoom + screen_center

func _debug_missing() -> void:
	var miss := []
	if day_label == null: miss.append("DayLabel")
	if energy_label == null: miss.append("EnergyLabel")
	if spend_spin == null: miss.append("SpendSpin")
	if next_day_button == null: miss.append("NextDayButton")
	if close_button == null: miss.append("CloseBtn")
	if miss.size() > 0:
		push_error("DayPanel: не найдены узлы: %s" % miss)
		print_tree_pretty()
