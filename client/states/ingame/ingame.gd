extends Node

const packets = preload("res://scripts/packets.gd")
const Actor = preload("res://objects/actor/actor.gd")

@onready var _line_edit: LineEdit = $UI/LineEdit
@onready var _log: Log = $UI/Log
@onready var _world: Node2D = $World

var _players: Dictionary[int, Actor]

func _ready() -> void:
	WS.connection_closed.connect(_on_ws_connection_closed)
	WS.packet_received.connect(_on_ws_packet_received)
	
	_line_edit.text_submitted.connect(_on_line_edit_text_submitted)

func _handle_chat_msg(sender_id: int, chat_msg: packets.ChatMessage) -> void:
	_log.chat("Client %d" % sender_id, chat_msg.get_msg())

func _handle_player_msg(_sender_id: int, player_msg: packets.PlayerMessage) -> void:
	var actor_id := player_msg.get_id()

	if actor_id not in _players:
		var actor := Actor.instantiate(
			actor_id,
			player_msg.get_name(),
			player_msg.get_x(),
			player_msg.get_y(),
			player_msg.get_radius(),
			player_msg.get_speed(),
			actor_id == GameManager.client_id
		)
	
		_world.add_child(actor)
		_players[actor_id] = actor
	else:
		var actor := _players[actor_id]
		actor.position.x = player_msg.get_x()
		actor.position.y = player_msg.get_y()
	
	
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
