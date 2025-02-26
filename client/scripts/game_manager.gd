extends Node

enum State {
	ENTERED,
	INGAME,
}

var _state_scenes: Dictionary[State, String] = {
	State.ENTERED: "res://states/entered/entered.tscn",
	State.INGAME: "res://states/ingame/ingame.tscn"
}

var client_id: int
var _current_scnene_root: Node

func set_state(state: State) -> void:
	if _current_scnene_root != null:
		_current_scnene_root.queue_free()
		
	var scene: PackedScene = load(_state_scenes[state])
	_current_scnene_root = scene.instantiate()
	add_child(_current_scnene_root)
