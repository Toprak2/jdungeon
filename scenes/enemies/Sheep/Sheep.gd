extends Enemy

signal destination_reached
signal stuck

@onready var animation_player := $AnimationPlayer
@onready var animation_synchronizer: AnimationSynchronizerComponent = $AnimationSynchronizerComponent
@onready var avoidance_rays := $AvoidanceRays
@onready var beehave_tree := $BeehaveTree
@onready var destination = self.global_position:
	set(new_destination):
		destination = new_destination
		enroute_to_destination = true
@onready var stuck_timer := $StuckTimer
@onready var sprite := $Sprite2D
@onready var loot: LootComponent = $LootComponent
var enroute_to_destination = false
var movement_multiplier := 1.0


func _init():
	super()
	enemy_class = "Sheep"


func _ready():
	if J.is_server():
		beehave_tree.enabled = true
		stuck_timer.timeout.connect(_on_stuck_timer_timeout)
		stats.got_hurt.connect(_on_got_hurt)
		stats.died.connect(_on_died)

		_add_loot()
	else:
		avoidance_rays.queue_free()
		beehave_tree.queue_free()
		stuck_timer.queue_free()
		$Blackboard.queue_free()

	$InterfaceComponent.display_name = enemy_class


func _add_loot():
	loot.add_item_to_loottable("Gold", 0.5, 20)


func _physics_process(_delta):
	if J.is_server():
		if position.distance_to(destination) > J.ARRIVAL_DISTANCE:
			velocity = position.direction_to(destination) * stats.movement_speed
			velocity = (
				avoidance_rays.find_avoidant_velocity(stats.movement_speed) * movement_multiplier
			)
			move_and_slide()
			animation_synchronizer.send_new_loop_animation("Move")
			if get_slide_collision_count() > 0:
				if stuck_timer.is_stopped():
					stuck_timer.start()
			else:
				stuck_timer.stop()
		else:
			if enroute_to_destination:
				enroute_to_destination = false
				velocity = Vector2.ZERO
				animation_synchronizer.send_new_loop_animation("Idle")
				destination_reached.emit()


func _on_died():
	animation_synchronizer.send_new_action_animation("Die")


func _on_got_hurt(_from: String, _damage: int):
	if not stats.is_dead:
		animation_synchronizer.send_new_action_animation("Hurt")


func _on_stuck_timer_timeout():
	stuck.emit()
