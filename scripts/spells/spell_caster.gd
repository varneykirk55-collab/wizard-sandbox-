extends Node
## Spell selection + casting. No mana, no charges, no cooldowns: every press
## spawns a new independent spell node, so effects stack freely.

signal spell_changed(index: int)
signal cast(index: int)

const THUNDER_REPEAT := 0.11   # auto-repeat while held (clicking faster also works)

var info: Array = [
	{"name": "CATACLYSM", "color": Color(1.0, 0.5, 0.12)},
	{"name": "THUNDER GOD", "color": Color(0.55, 0.75, 1.0)},
	{"name": "GRAVITY WELL", "color": Color(0.7, 0.35, 1.0)},
	{"name": "INFERNO", "color": Color(1.0, 0.3, 0.05)},
	{"name": "METEOR", "color": Color(1.0, 0.75, 0.35)},
	{"name": "BLACK FIRE", "color": Color(0.9, 0.08, 0.12)},
]
var current := 0

var _scripts: Array = []
var _held_tornado = null
var _thunder_t := 0.0
var _holding := false
var _dark                       # shared resources for Black Fire / Oblivion
var _charge = null              # Black Fire orb being charged in the hand
var _last_aim := Vector3.ZERO
var _last_hand := Vector3.ZERO


func _ready() -> void:
	for f in ["cataclysm", "thunder", "gravity_well", "inferno", "meteor", "black_fire"]:
		_scripts.append(load("res://scripts/spells/%s.gd" % f))
	_dark = load("res://scripts/spells/dark_fx.gd").new()
	add_child(_dark)


func select(i: int) -> void:
	var idx := wrapi(i, 0, info.size())
	if idx == current:
		return
	release()
	current = idx
	spell_changed.emit(current)
	AudioManager.play_ui("chime", -14.0, 1.6 + 0.12 * current)


func _spawn(i: int):
	var n = _scripts[i].new()
	FX.spell_root.add_child(n)
	return n


## hand: world position of the casting hand. aim: crosshair hit point.
## ground: aim point projected to the ground. normal: surface normal at aim.
func press(hand: Vector3, aim: Vector3, ground: Vector3, normal: Vector3) -> void:
	_holding = true
	_last_aim = aim
	_last_hand = hand
	match current:
		0:
			_spawn(0).launch(hand, aim)
		1:
			_spawn(1).strike(aim)
			_thunder_t = THUNDER_REPEAT
		2:
			var p := aim + normal * 1.5
			p.y = maxf(p.y, 3.2)
			_spawn(2).start(p)
		3:
			_held_tornado = _spawn(3)
			_held_tornado.start(ground)
		4:
			_spawn(4).start(ground)
		5:
			# Nothing is launched on press: a tap fires on release, a hold charges.
			_charge = _spawn(5)
			_charge.dark = _dark
			_charge.begin(hand)
	cast.emit(current)


func hold(delta: float, aim: Vector3, ground: Vector3) -> void:
	if not _holding:
		return
	_last_aim = aim
	if is_instance_valid(_charge):
		_charge.charging(delta, _hand())
	if current == 1:
		_thunder_t -= delta
		if _thunder_t <= 0.0:
			_thunder_t = THUNDER_REPEAT
			_spawn(1).strike(aim)
			cast.emit(current)
	elif current == 3:
		if is_instance_valid(_held_tornado):
			_held_tornado.sustain(ground)


func release() -> void:
	_holding = false
	if is_instance_valid(_charge):
		_charge.fire(_hand(), _last_aim)
	_charge = null
	if is_instance_valid(_held_tornado):
		_held_tornado.release()
	_held_tornado = null


## Current cast origin: the player's existing hand anchor, read every frame so
## a charging orb stays in the hand while moving or flying.
func _hand() -> Vector3:
	var pl = get_parent()
	if pl != null and "_orb" in pl and is_instance_valid(pl._orb):
		_last_hand = pl._orb.global_position
	return _last_hand
