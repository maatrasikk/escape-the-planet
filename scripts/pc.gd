extends Area2D

@export_node_path("Control") var day_panel_path: NodePath
@export var use_world_position: bool = true

@onready var day_panel: Control = (
	get_tree().get_root().get_node_or_null("Main/CanvasLayer/DayPanel")
	if day_panel_path.is_empty()
	else get_node_or_null(day_panel_path)
)

func _ready() -> void:
	if not day_panel:
		push_warning("DayPanel не найден. Укажи путь в day_panel_path или проверь иерархию.")
	connect("input_event", Callable(self, "_on_input_event"))

func _on_input_event(viewport, event, shape_idx):
	print("input_event пришёл: ", event)
	if event is InputEventMouseButton \
		and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT:

		if not day_panel:
			print("Клик по объекту, но day_panel = null")
			return

		print("Клик: открываем панель")

		if use_world_position and day_panel.has_method("open_at_world"):
			day_panel.open_at_world(global_position)
		else:
			if day_panel.has_method("open"):
				day_panel.call("open")
			else:
				day_panel.show()

			if day_panel is Control:
				day_panel.position = Vector2(48, 48)
