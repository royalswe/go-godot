class_name Highscores
extends ScrollContainer

var _scores: Array[int]

@onready var _vbox: VBoxContainer = $VBoxContainer
@onready var _entry_template: HBoxContainer = $VBoxContainer/HBoxContainer


func set_highscore(name: String, score: int) -> void:
	remove_highscore(name)
	_add_highscore(name, score)

func remove_highscore(name: String) -> void:
	for i in range(len(_scores)):
		var entry: HBoxContainer = _vbox.get_child(i)
		var name_label: Label = entry.get_child(0)
		
		if name_label.text == name:
			_scores.remove_at(len(_scores) - i - 1)
			
			entry.free()
			return

func _add_highscore(name: String, score: int) -> void:
	_scores.append(score)
	_scores.sort()
	
	var pos := len(_scores) - _scores.find(score) -1
	
	var entry := _entry_template.duplicate()
	var name_label: Label = entry.get_child(0)
	var score_label: Label = entry.get_child(1)
	
	_vbox.add_child(entry)
	_vbox.move_child(entry, pos)
	
	name_label.text = name
	score_label.text = str(score)
	
	entry.show()
