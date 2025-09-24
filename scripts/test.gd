extends Area2D

func _ready():
	input_pickable = true
	
func _input_event(v,e,idx):
	print("CLICK!", e)
