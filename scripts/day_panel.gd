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
		s.max_value = 10
		s.step = 1
		s.value = 0


func _on_slider_changed(kind: String, val: float) -> void:
	if _updating_sliders:
		return
	_updating_sliders = true

	var limit: int = GameState.get_daily_limit()

	var s: int = int(search_slider.value)
	var a: int = int(antenna_slider.value)
	var sh: int = int(shield_slider.value)

	match kind:
		"search":
			s = int(val)
		"antenna":
			a = int(val)
		"shield":
			sh = int(val)

	# Ограничиваем перебор
	var total: int = s + a + sh
	if total > limit:
		var overflow: int = total - limit
		match kind:
			"search":
				s = max(0, s - overflow)
			"antenna":
				a = max(0, a - overflow)
			"shield":
				sh = max(0, sh - overflow)

	# Обнуляем если цель уже достигнута
	if GameState.debris_found >= GameState.DEBRIS_NEEDED:
		s = 0
	if GameState.antenna_progress >= 100:
		a = 0
	if GameState.shield_hp >= GameState.SHIELD_HP_MAX:
		sh = 0

	search_slider.value = s
	antenna_slider.value = a
	shield_slider.value = sh

	GameState.set_allocations(s, a, sh)
	_update_alloc_labels()

	_updating_sliders = false


func _update_alloc_labels() -> void:
	var left: int = GameState.get_daily_allocation_left()
	search_value_label.text = str(int(search_slider.value))
	antenna_value_label.text = str(int(antenna_slider.value))
	shield_value_label.text = str(int(shield_slider.value))
	alloc_left_label.text = "Осталось распределить: %d" % left
	daily_limit_label.text = "Лимит дня: %d" % GameState.get_daily_limit()
	next_day_button.disabled = (_game_over or GameState.energy <= 0)


func _refresh_all() -> void:
	var st: Dictionary = GameState.get_status_dict()
	day_label.text = "День: %d" % st.day
	energy_label.text = "Энергия: %d / %d" % [st.energy, st.energy_max]
	debris_label.text = "%d / %d" % [st.debris_found, st.debris_needed]
	antenna_label.text = "%d%%" % st.antenna_progress
	shield_label.text = "%d / %d" % [st.shield_hp, st.shield_hp_max]
	damage_label.text = str(st.last_enemy_damage)

	var limit: int = GameState.get_daily_limit()
	for s in [search_slider, antenna_slider, shield_slider]:
		s.max_value = limit

	search_slider.editable = (GameState.debris_found < GameState.DEBRIS_NEEDED and GameState.energy > 0)
	antenna_slider.editable = (GameState.antenna_progress < 100 and GameState.energy > 0)
	shield_slider.editable = (GameState.shield_hp < GameState.SHIELD_HP_MAX and GameState.energy > 0)

	search_slider.value = GameState.alloc_search
	antenna_slider.value = GameState.alloc_antenna
	shield_slider.value = GameState.alloc_shield

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
		damage_label.text = "ПОБЕДА"
	else:
		match reason:
			"shield_destroyed":
				damage_label.text = "Поражение: щит"
			"out_of_energy":
				damage_label.text = "Поражение: энергия"
			_:
				damage_label.text = "Поражение"

	hide()
