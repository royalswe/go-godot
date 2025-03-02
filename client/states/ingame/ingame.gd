extends Node

const packets = preload("res://scripts/packets.gd")
const Actor = preload("res://objects/actor/actor.gd")
const Spore = preload("res://objects/spore/spore.gd")

@onready var _line_edit: LineEdit = $UI/LineEdit
@onready var _log: Log = $UI/Log
@onready var _world: Node2D = $World

var _players: Dictionary[int, Actor]
var _spores: Dictionary[int, Spore]

func _ready() -> void:
	WS.connection_closed.connect(_on_ws_connection_closed)
	WS.packet_received.connect(_on_ws_packet_received)
	
	_line_edit.text_submitted.connect(_on_line_edit_text_submitted)

func _handle_chat_msg(sender_id: int, chat_msg: packets.ChatMessage) -> void:
	if sender_id in _players:
		var actor := _players[sender_id]
		_log.chat(actor.actor_name, chat_msg.get_msg())

func _handle_player_msg(_sender_id: int, player_msg: packets.PlayerMessage) -> void:
	var actor_id := player_msg.get_id()
	var actor_name := player_msg.get_name()
	var x := player_msg.get_x()
	var y := player_msg.get_y()
	var radius := player_msg.get_radius()
	var speed := player_msg.get_speed()
	var is_player := actor_id == GameManager.client_id
	
	if actor_id not in _players:
		_add_actor(actor_id, actor_name, x, y, radius, speed, is_player)
	else:
		_update_player(actor_id, player_msg.get_direction(), x, y, radius, speed, is_player)
		
func _add_actor(actor_id: int, actor_name: String, x: float, y: float, radius: float, speed: float, is_player: bool) -> void:
	var actor := Actor.instantiate(actor_id, actor_name, x, y, radius, speed, is_player)
	_world.add_child(actor)
	_players[actor_id] = actor
	
	if is_player:
		actor.area_entered.connect(_on_player_area_entered)
	
func _update_player(actor_id: int, direction: float, x: float, y: float, radius: float, speed: float, is_player: bool) -> void:
	var actor := _players[actor_id]
	actor.radius = radius
	
	# Prevent update position to often, player needs to move at least around 10px
	if actor.position.distance_squared_to(Vector2.from_angle(direction)) > 100: 
		actor.position.x = x
		actor.position.y = y
	
	# Don't update is_player position because we know wheret it is
	if not is_player:
		actor.velocity = speed * Vector2.from_angle(direction)

func _on_line_edit_text_submitted(text: String) -> void:
	var packet := packets.Packet.new()
	var chat_msg := packet.new_chat()
	chat_msg.set_msg(text)
	
	var err := WS.send(packet)
	if err:
		_log.error("Error sending chat message")
	else:
		_log.chat("You", text)
	_line_edit.text = ""
		
func _on_ws_connection_closed() -> void:
	_log.info("Connection closed")
	
func _on_ws_packet_received(packet: packets.Packet) -> void:
	var sender_id := packet.get_sender_id()

	if packet.has_chat():
		_handle_chat_msg(sender_id, packet.get_chat())
	elif packet.has_player():
		_handle_player_msg(sender_id, packet.get_player())
	elif packet.has_spore():
		_handle_spore_msg(sender_id, packet.get_spore())
	elif packet.has_spores_batch():
		_handle_spores_batch_msg(sender_id, packet.get_spores_batch())

func _handle_spore_msg(sender_id: int, spore_msg: packets.SporeMessage) -> void:
	var spore_id := spore_msg.get_id()
	var x := spore_msg.get_x()
	var y := spore_msg.get_y()
	var radius := spore_msg.get_radius()
	
	if spore_id not in _spores:
		var spore := Spore.instantiate(spore_id, x, y, radius)
		_world.add_child(spore)
		_spores[spore_id] = spore
		
func _handle_spores_batch_msg(sender_id: int, spores_batch_msg: packets.SporesBatchMessage) -> void:
	for spore_msg in spores_batch_msg.get_spores():
		_handle_spore_msg(sender_id, spore_msg)
		
func _on_player_area_entered(area: Area2D) -> void:
	if area is Spore:
		_consume_spore(area as Spore)

func _consume_spore(spore: Spore) -> void:
	var packet := packets.Packet.new()
	var spore_consumed_msg := packet.new_spore_consumed()
	spore_consumed_msg.set_spore_id(spore.spore_id)
	WS.send(packet)
	_remove_spore(spore)
	
func _remove_spore(spore: Spore) -> void:
	_spores.erase(spore.spore_id)
	spore.queue_free()
