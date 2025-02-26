extends Node
const packets = preload("res://scripts/packets.gd")
@onready var _line_edit: LineEdit = $LineEdit
@onready var _log := $Log as Log 

#var client_id: int

func _ready() -> void:
	GameManager.set_state(GameManager.State.ENTERED)
	
