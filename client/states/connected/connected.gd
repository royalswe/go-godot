extends Node

const packets = preload("res://scripts/packets.gd")

var _action_on_ok_received: Callable

@onready var _username: LineEdit = $UI/VBoxContainer/Username
@onready var _password: LineEdit = $UI/VBoxContainer/Password
@onready var _color_picker: ColorPicker = $UI/VBoxContainer/ColorPicker
@onready var _login_button: Button = $UI/VBoxContainer/HBoxContainer/LoginButton
@onready var _register_button: Button = $UI/VBoxContainer/HBoxContainer/RegisterButton
@onready var _play_as_guest_button: Button = $UI/VBoxContainer/HBoxContainer/PlayAsGuestButton
@onready var _log: Log = $UI/VBoxContainer/Log

func _ready() -> void:
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)
	_login_button.pressed.connect(_on_login_button_pressed)
	_register_button.pressed.connect(_on_register_button_pressed)
	_play_as_guest_button.pressed.connect(_on_guest_button_pressed)
	
func _on_ws_connection_closed() -> void:
	_log.info("Connection closed")
	
func _on_ws_packet_received(packet: packets.Packet) -> void:
	#var sender_id := packet.get_sender_id()
	if packet.has_deny_response():
		var deny_response_msg := packet.get_deny_response()
		_log.error(deny_response_msg.get_reason())
	elif packet.has_ok_response():
		_action_on_ok_received.call()
		
func _on_login_button_pressed() -> void:
	var packet := packets.Packet.new()
	var login_request_msg := packet.new_login_request()
	login_request_msg.set_username(_username.text)
	login_request_msg.set_password(_password.text)
	login_request_msg.set_color(_color_picker.color.to_rgba32())
	WS.send(packet)
	_action_on_ok_received = func (): GameManager.set_state(GameManager.State.INGAME)
	
func _on_register_button_pressed() -> void:
	var packet := packets.Packet.new()
	var register_request_msg := packet.new_register_request()
	register_request_msg.set_username(_username.text)
	register_request_msg.set_password(_password.text)
	WS.send(packet)
	_action_on_ok_received = func (): _log.success("Registration successful!")
	
func _on_guest_button_pressed() -> void:
	var username := _username.text.strip_edges()
	if username.is_empty():
		username = "Guest" + str(randi() % 10000) # Generates a random number from 0 to 9999
	var packet := packets.Packet.new()
	var guest_login_request_msg := packet.new_guest_login_request()
	guest_login_request_msg.set_username(username)
	guest_login_request_msg.set_color(_color_picker.color.to_rgba32())

	WS.send(packet)
	GameManager.set_state(GameManager.State.INGAME)
	
