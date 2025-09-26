extends Panel

# Узлы интерфейса
@onready var day_label: Label            = $VBoxContainer/TopRow/DayLabel
@onready var energy_label: Label         = $VBoxContainer/TopRow/EnergyLabel
@onready var close_button: Button        = $VBoxContainer/TopRow/CloseBtn

@onready var debris_label: Label         = $VBoxContainer/ProgressGrid/DebrisValueLabel
@onready var antenna_label: Label        = $VBoxContainer/ProgressGrid/AntennaValueLabel
@onready var shield_label: Label         = $VBoxContainer/ProgressGrid/ShieldValueLabel
@onready var damage_label: Label         = $VBoxContainer/ProgressGrid/DamageValueLabel

@onready var daily_limit_label: Label    = $VBoxContainer/AllocBox/DailyLimitLabel
@onready var search_slider: HSlider      = $VBoxContainer/AllocBox/HBoxContainer/SearchSlider
@onready var antenna_slider: HSlider     = $VBoxContainer/AllocBox/HBoxContainer2/AntennaSlider
@onready var shield_slider: HSlider      = $VBoxContainer/AllocBox/HBoxContainer3/ShieldSlider
@onready var search_value_label: Label   = $VBoxContainer/AllocBox/HBoxContainer/SearchValueLabel
@onready var antenna_value_label: Label  = $VBoxContainer/AllocBox/HBoxContainer2/AntennaValueLabel
@onready var shield_value_label: Label   = $VBoxContainer/AllocBox/HBoxContainer3/ShieldValueLabel
@onready var alloc_left_label: Label     = $VBoxContainer/AllocBox/AllocLeftLabel

@onready var next_day_button: Button     = $VBoxContainer/NextDayButton

var _updating_sliders: bool = false
var _game_over: bool = false


func _ready() -> void:
	_connect_signals()
	_init_sliders()
	hide()
	_refresh_all()


func open() -> void:
	if _game_over:
		return
	_refresh_all()
	show()


func open_at_world(world_pos: Vector2) -> void:
	open()
	var cam := get_viewport().get_camera_2d()
	if cam:
		if size == Vector2.ZERO:
			size = get_minimum_size()
		var vp_size: Vector2 = get_viewport_rect().size
		var screen_center: Vector2 = vp_size * 0.5
		var screen: Vector2 = (world_pos - cam.global_position) * cam.zoom + screen_center
		screen += Vector2(-size.x * 0.5, -size.y - 8)
		screen.x = clampf(screen.x, 0.0, vp_size.x - size.x)
		screen.y = clampf(screen.y, 0.0, vp_size.y - size.y)
		position = screen


func _connect_signals() -> void:
	if not GameState.is_connected("day_changed", Callable(self, "_on_day_changed")):
		GameState.connect("day_changed", Callable(self, "_on_day_changed"))
		GameState.connect("progress_changed", Callable(self, "_on_progress_changed"))
		GameState.connect("shield_changed", Callable(self, "_on_shield_changed"))
		GameState.connect("enemy_state_changed", Callable(self, "_on_enemy_state_changed"))
		GameState.connect("game_over", Callable(self, "_on_game_over"))

		search_slider.value_changed.connect(_on_slider_changed.bind("search"))
		antenna_slider.value_changed.connect(_on_slider_changed.bind("antenna"))
		shield_slider.value_changed.connect(_on_slider_changed.bind("shield"))

		next_day_button.pressed.connect(_on_next_day_pressed)
		close_button.pressed.connect(func(): hide())


func _init_sliders() -> void:
	for s in [search_slider, antenna_slider, shield_slider]:
		s.min_value = 0
		s.step = 1
		s.value = 0
		s.max_value = 0  # пересчитаем позже


func _recalc_slider_maxes() -> void:
	var limit: int = GameState.get_daily_limit()
	var s: int = int(search_slider.value)
	var a: int = int(antenna_slider.value)
	var sh: int = int(shield_slider.value)

	search_slider.max_value = max(0, limit - a - sh)
	antenna_slider.max_value = max(0, limit - s - sh)
	shield_slider.max_value = max(0, limit - s - a)

	if s > search_slider.max_value:
		_set_slider_value(search_slider, search_slider.max_value)
	if a > antenna_slider.max_value:
		_set_slider_value(antenna_slider, antenna_slider.max_value)
	if sh > shield_slider.max_value:
		_set_slider_value(shield_slider, shield_slider.max_value)


func _update_slider_editable() -> void:
	var energy_ok: bool = GameState.energy > 0 and not _game_over
	search_slider.editable = energy_ok and (GameState.debris_found < GameState.DEBRIS_NEEDED)
	antenna_slider.editable = energy_ok and (GameState.antenna_progress < 100)
	shield_slider.editable = energy_ok and (GameState.shield_hp < GameState.SHIELD_HP_MAX)


func _set_slider_value(slider: HSlider, v: int) -> void:
	if slider.has_method("set_value_no_signal"):
		slider.set_value_no_signal(v)
	else:
		slider.value = v


func _on_slider_changed(val: float, kind: String) -> void:
	if _updating_sliders:
		return
	_updating_sliders = true

	var limit: int = GameState.get_daily_limit()

	var s: int = int(search_slider.value)
	var a: int = int(antenna_slider.value)
	var sh: int = int(shield_slider.value)

	match kind:
		"search":
			var max_allowed: int = max(0, limit - (a + sh))
			s = clamp(int(val), 0, max_allowed)
		"antenna":
			var max_allowed: int = max(0, limit - (s + sh))
			a = clamp(int(val), 0, max_allowed)
		"shield":
			var max_allowed: int = max(0, limit - (s + a))
			sh = clamp(int(val), 0, max_allowed)

	if GameState.debris_found >= GameState.DEBRIS_NEEDED:
		s = 0
	if GameState.antenna_progress >= 100:
		a = 0
	if GameState.shield_hp >= GameState.SHIELD_HP_MAX:
		sh = 0

	_set_slider_value(search_slider, s)
	_set_slider_value(antenna_slider, a)
	_set_slider_value(shield_slider, sh)

	GameState.set_allocations(s, a, sh)

	_recalc_slider_maxes()
	_update_slider_editable()
	_update_alloc_labels()

	_updating_sliders = false


func _update_alloc_labels() -> void:
	var left: int = GameState.get_daily_allocation_left()
	search_value_label.text = str(int(search_slider.value))
	antenna_value_label.text = str(int(antenna_slider.value))
	shield_value_label.text = str(int(shield_slider.value))
	alloc_left_label.text = "To replenish: %d" % left
	daily_limit_label.text = "Day limit: %d" % GameState.get_daily_limit()
	next_day_button.disabled = (_game_over or GameState.energy <= 0)


func _refresh_all() -> void:
	var st: Dictionary = GameState.get_status_dict()
	day_label.text = "Day: %d" % st.day
	energy_label.text = "Energy: %d / %d" % [st.energy, st.energy_max]
	debris_label.text = "%d / %d" % [st.debris_found, st.debris_needed]
	antenna_label.text = "%d%%" % st.antenna_progress
	shield_label.text = "%d / %d" % [st.shield_hp, st.shield_hp_max]
	damage_label.text = str(st.last_enemy_damage)

	_set_slider_value(search_slider, GameState.alloc_search)
	_set_slider_value(antenna_slider, GameState.alloc_antenna)
	_set_slider_value(shield_slider, GameState.alloc_shield)

	_recalc_slider_maxes()
	_update_slider_editable()
	_update_alloc_labels()


func _on_next_day_pressed() -> void:
	if _game_over:
		return
	next_day_button.disabled = true
	GameState.next_day()
	next_day_button.disabled = false
	_refresh_all()


func _on_day_changed(_d: int, _e: int) -> void:
	if not visible:
		return
	_refresh_all()


func _on_progress_changed() -> void:
	if not visible:
		return
	_refresh_all()


func _on_shield_changed(_hp: int, _max: int) -> void:
	if not visible:
		return
	_refresh_all()


func _on_enemy_state_changed(_present: bool, _last_damage: int) -> void:
	if not visible:
		return
	damage_label.text = str(GameState.last_enemy_damage)


func _on_game_over(victory: bool, reason: String) -> void:
	_game_over = true
	next_day_button.disabled = true

	search_slider.editable = false
	antenna_slider.editable = false
	shield_slider.editable = false

	if victory:
		damage_label.text = "Victory"
	else:
		match reason:
			"shield_destroyed":
				damage_label.text = "Defeat: shield"
			"out_of_energy":
				damage_label.text = "Defeat: energy"
			_:
				damage_label.text = "Defeated"

	hide()
