extends Node

const packets := preload("res://packets.gd")
@onready var _line_edit: LineEdit = $LineEdit
@onready var _log := $Log as Log 

var client_id: int

func _ready() -> void:
	WS.connected_to_server.connect(_on_ws_connected_to_server)
	WS.connection_closed.connect(_on_ws_connection_closed)
	WS.packet_received.connect(_on_ws_packet_received)
	
	_line_edit.text_submitted.connect(_on_line_edit_text_submitted)

	_log.info("Connecting to server...")
	
	WS.connect_to_url("ws://localhost:8080/ws")
	
func _on_ws_connected_to_server() -> void:
	_log.success("Connected successfully")

func _on_ws_connection_closed() -> void:
	_log.info("Connection closed")
	
func _on_ws_packet_received(packet: packets.Packet) -> void:
	var sender_id := packet.get_sender_id()
	if packet.has_id():
		_handle_id_msg(sender_id, packet.get_id())
	elif packet.has_chat():
		_handle_chat_msg(sender_id, packet.get_chat())
		
func _handle_id_msg(sender_id: int, id_msg: packets.IdMessage) -> void:
	var client_id := id_msg.get_id()
	_log.info("Received client ID: %d" % client_id)
	
func _handle_chat_msg(sender_id: int, chat_msg: packets.ChatMessage) -> void:
	_log.chat("Client %d" % sender_id, chat_msg.get_msg())

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
	
