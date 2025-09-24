extends Area2D

@export var panel_path: NodePath   # Укажешь в инспекторе

func _ready():
	print("[PC] ready. panel_path =", panel_path)

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if panel_path == NodePath():
			push_error("[PC] panel_path НЕ задан в инспекторе.")
			return
		var panel = get_node_or_null(panel_path)
		if panel == null:
			push_error("[PC] get_node(panel_path) вернул null. Текущий panel_path=" + str(panel_path))
			return
		print("[PC] panel=", panel, 
			  " open=", panel.has_method("open"),
			  " open_at_world=", panel.has_method("open_at_world"),
			  " script=", panel.get_script())
		if panel.has_method("open_at_world"):
			print("[PC] Calling open_at_world")
			panel.call("open_at_world", global_position)
		elif panel.has_method("open"):
			print("[PC] Calling open")
			panel.call("open")
		else:
			push_error("Panel at path has no methods (open / open_at_world).")
