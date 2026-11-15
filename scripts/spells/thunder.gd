extends Node3D
## SPELL 2 - THUNDER GOD: branching sky bolts, ground impacts and chain arcs.

const CHAIN_RANGE := 16.0
const CHAIN_COUNT := 4


func strike(target: Vector3) -> void:
	global_position = target
	# Main bolt from the clouds.
	var sky := target + Vector3(randf_range(-14.0, 14.0), 75.0, randf_range(-14.0, 14.0))
	FX.bolt(sky, target, 1.0, 4, 0.38)
	_impact(target, 1.0)
	AudioManager.play_at("thunder", target, 4.0, randf_range(0.85, 1.15), 50.0)
	AudioManager.play_at("zap", target, 0.0, randf_range(0.8, 1.2), 25.0)
	# Follow-up forks landing around the target.
	for i in 2:
		var off := Vector3(randf_range(-3.5, 3.5), 0.0, randf_range(-3.5, 3.5))
		var t2 := Vector3(target.x + off.x, maxf(0.0, target.y - 0.5), target.z + off.z)
		var sky2 := sky + Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
		FX.after(0.06 * (i + 1), _fork.bind(sky2, t2))
	# Chain to nearby destructibles.
	var prev := target + Vector3.UP * 0.6
	var chain: Array = DM.nearest_intact(target, CHAIN_RANGE, CHAIN_COUNT)
	for i in chain.size():
		var cp: Vector3 = chain[i]
		FX.after(0.07 * (i + 1), _chain_hit.bind(prev, cp))
		prev = cp
	get_tree().create_timer(1.5, false).timeout.connect(queue_free)


func _fork(sky: Vector3, target: Vector3) -> void:
	FX.bolt(sky, target, 0.5, 2, 0.28)
	_impact(target, 0.6)


func _impact(pos: Vector3, power: float) -> void:
	FX.electric_impact(pos, power)
	DM.explode(pos, 6.5 * power, 260.0 * power, 15.0 * power, 0.5, true)


func _chain_hit(from: Vector3, to: Vector3) -> void:
	FX.bolt(from, to, 0.4, 2, 0.26)
	FX.emit("electric_sparks", to, 0.7)
	FX.flash_light(to, Color(0.65, 0.8, 1.0), 14.0, 14.0, 0.25)
	DM.explode(to, 3.2, 190.0, 10.0, 0.4, true)
	AudioManager.play_at("zap", to, -3.0, randf_range(1.0, 1.5), 18.0)
