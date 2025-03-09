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
var color: Color
var is_player: bool

var _target_zoom := 2.0
var _furthest_zoom_allowed := _target_zoom

var server_position: Vector2
var velocity: Vector2
var radius: float:
	set(new_radius):
		radius = new_radius
		_collision_shape.radius = new_radius
		_update_zoom()
		queue_redraw()

@onready var _camera: Camera2D = $Camera2D
@onready var _collision_shape: CircleShape2D = $CollisionShape2D.shape
@onready var _name_plate: Label = $NamePlate


static func instantiate(_actor_id: int, _actor_name: String, _x: float, _y: float, _radius: float, _speed: float, _color: Color, _is_player: bool) -> Actor:
	var actor := Scene.instantiate()
	actor.actor_id = _actor_id
	actor.actor_name = _actor_name
	actor.start_x = _x
	actor.start_y = _y
	actor.start_radius = _radius
	actor.speed = _speed
	actor.color = _color
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
	if is_player:
		if event is InputEventMouseButton and event.is_pressed():
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_target_zoom = min(4, _target_zoom + 0.1)
				MOUSE_BUTTON_WHEEL_DOWN:
					_target_zoom = max(_furthest_zoom_allowed, _target_zoom - 0.1)

		elif event is InputEventMagnifyGesture:
			# Positive factor means zooming in, negative means zooming out
			_target_zoom = clamp(_target_zoom * event.factor, _furthest_zoom_allowed, 4)

func _process(_delta: float) -> void:
	if not is_equal_approx(_camera.zoom.x, _target_zoom):
		_camera.zoom -= Vector2(1, 1) * (_camera.zoom.x - _target_zoom) * 0.05	

func _physics_process(delta: float) -> void:
	position += velocity * delta
	server_position += velocity * delta
	position += (server_position - position) * 0.05
	
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
	draw_circle(Vector2.ZERO, _collision_shape.radius, color)

func _update_zoom() -> void:
	if is_node_ready():
		_name_plate.add_theme_font_size_override("font_size", max(16, radius / 2))
		
	if not is_player:
		return
		
	var new_furthest_zoom_allow := start_radius / radius
	if is_equal_approx(_target_zoom, _furthest_zoom_allowed):
		_target_zoom = new_furthest_zoom_allow
		
	_furthest_zoom_allowed = new_furthest_zoom_allow / 2
