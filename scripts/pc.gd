extends Area2D

@export var panel_path: NodePath  # Укажи панель в инспекторе

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel = get_node_or_null(panel_path)
		if panel == null:
			return
		if panel.has_method("open_at_world"):
			panel.call("open_at_world", global_position)
		elif panel.has_method("open"):
			panel.call("open")
