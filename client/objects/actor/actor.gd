extends Area2D

const packets = preload("res://scripts/packets.gd")
const Scene := preload("res://objects/actor/actor.tscn")
const Actor := preload("res://objects/actor/actor.gd")

var actor_id: int
var actor_name: String
var start_x: float
var start_y: float
var start_radius: float
var speed: float
var is_player: bool

var velocity: Vector2
var radius: float

@onready var _camera: Camera2D = $Camera2D
@onready var _collision_shape: CircleShape2D = $CollisionShape2D.shape
@onready var _name_plate: Label = $NamePlate


static func instantiate(_actor_id: int, _actor_name: String, _x: float, _y: float, _radius: float, _speed: float, _is_player: bool) -> Actor:
	var actor := Scene.instantiate()
	actor.actor_id = _actor_id
	actor.actor_name = _actor_name
	actor.start_x = _x
	actor.start_y = _y
	actor.start_radius = _radius
	actor.speed = _speed
	actor.is_player = _is_player

	return actor
	
func _ready() -> void:
	position.x = start_x
	position.y = start_y
	velocity = Vector2.RIGHT * speed
	radius = start_radius
 
	_collision_shape.radius = radius
	_name_plate.text = actor_name

func _input(event: InputEvent) -> void:
	if is_player and event is InputEventMouseButton and event.is_pressed():
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_camera.zoom.x = min(4, _camera.zoom.x + 0.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_camera.zoom.x = max(0.1, _camera.zoom.x - 0.1)
				
		_camera.zoom.y = _camera.zoom.x

func _physics_process(delta: float) -> void:
	position += velocity * delta
	
	if not is_player:
		return

	var mouse_pos := get_global_mouse_position()
	
	var input_vector := position.direction_to(mouse_pos).normalized()
	if abs(velocity.angle_to(input_vector)) > TAU / 15:
		velocity	 = input_vector * speed
		var packet := packets.Packet.new()
		var player_direction_message := packet.new_player_direction()
		player_direction_message.set_direction(velocity.angle())
		WS.send(packet)

func _draw() -> void:
	draw_circle(Vector2.ZERO, _collision_shape.radius, Color.CORNFLOWER_BLUE)
