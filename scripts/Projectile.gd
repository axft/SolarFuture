extends Area2D

# get_node_or_null prevents crashes if the node name doesn't match
@onready var anim_sprite = get_node_or_null("AnimatedSprite2D")
@onready var static_sprite = get_node_or_null("Sprite2D")

var target: Node2D = null
var speed: float = 480.0
var damage: float = 22.0

func _ready():
	if anim_sprite and anim_sprite.sprite_frames:
		anim_sprite.play()

func _process(delta: float):
	if not is_instance_valid(target):
		queue_free()
		return
		
	var direction = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()
	
	if global_position.distance_to(target.global_position) < 18.0:
		if target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()
