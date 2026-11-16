extends Node
## Optional checks for the village expansion. Not used during normal play.
##   VILLAGE_AUDIT=1 godot --headless --path . --quit-after 3
##   VILLAGE_CAPTURE=1 godot --path . --quit-after 30
## Capture needs a real rendering driver (not the headless dummy renderer).

const OUT := "/opt/cursor/artifacts"


func _ready() -> void:
	_audit()
	if OS.get_environment("VILLAGE_CAPTURE") == "1":
		_capture()
	elif OS.get_environment("VILLAGE_AUDIT") == "1":
		var code := 0 if _floating == 0 else 2
		get_tree().quit(code)


var _floating := 0


func _audit() -> void:
	var dm := get_node("/root/DM")
	var counts := {}
	var piece_counts := {}
	var pieces := 0
	var old_pieces := 0
	var new_pieces := 0
	var good := {}
	var stack: Array = []
	for st in dm.structures:
		var label := _label(str(st.name))
		counts[label] = int(counts.get(label, 0)) + 1
		piece_counts[label] = int(piece_counts.get(label, 0)) + st.pieces.size()
		pieces += st.pieces.size()
		if dm.structures.find(st) < 36:
			old_pieces += st.pieces.size()
		else:
			new_pieces += st.pieces.size()
		for p in st.pieces:
			if p.grounded:
				good[p] = true
				stack.append(p)
	while stack.size() > 0:
		var p = stack.pop_back()
		for d in p.dependents:
			if is_instance_valid(d) and not good.has(d):
				good[d] = true
				stack.append(d)
	var floating: Array = []
	for st in dm.structures:
		for p in st.pieces:
			if not good.has(p):
				floating.append("%s %s pos=%s" % [st.name, p.mat_name, p.position])
	_floating = floating.size()
	var boxes: Array = []
	for st in dm.structures:
		boxes.append([st, _world_aabb(st)])
	var overlaps: Array = []
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a: AABB = boxes[i][1]
			var b: AABB = boxes[j][1]
			if not a.intersects(b):
				continue
			var mn: Vector3 = a.position.max(b.position)
			var mx: Vector3 = a.end.min(b.end)
			var ov: Vector3 = mx - mn
			if ov.x > 0.4 and ov.y > 0.4 and ov.z > 0.4:
				var involves_new := _is_expansion(boxes[i][0]) or _is_expansion(boxes[j][0])
				var tag := "NEW" if involves_new else "legacy"
				overlaps.append("%s %s vs %s overlap=%s" % [tag, boxes[i][0].name, boxes[j][0].name, ov])
	var root := get_tree().current_scene
	var bodies := root.find_children("*", "RigidBody3D", true, false).size()
	var meshes := root.find_children("*", "MeshInstance3D", true, false).size()
	var omnis := root.find_children("*", "OmniLight3D", true, false).size()
	var dirs := root.find_children("*", "DirectionalLight3D", true, false).size()
	print("AUDIT structures=%d pieces=%d old_pieces=%d new_pieces=%d rigid_bodies=%d mesh_instances=%d" % [dm.structures.size(), pieces, old_pieces, new_pieces, bodies, meshes])
	print("AUDIT lights omni=%d directional=%d" % [omnis, dirs])
	print("AUDIT materials=%d mesh_cache=%d shape_cache=%d" % [dm.materials.size(), dm._mesh_cache.size(), dm._shape_cache.size()])
	print("AUDIT restore_s=%.0f debris_cap=%d startup_debris=%d" % [dm.RESTORE_TIME, dm.MAX_DEBRIS, dm.debris.size()])
	var keys: Array = counts.keys()
	keys.sort()
	for k in keys:
		print("AUDIT kind %s %d pieces=%d" % [k, counts[k], piece_counts[k]])
	print("AUDIT floating=%d" % floating.size())
	for line in floating.slice(0, 50):
		print("AUDIT FLOAT ", line)
	print("AUDIT overlaps=%d" % overlaps.size())
	for line in overlaps.slice(0, 50):
		print("AUDIT OVERLAP ", line)
	if OS.get_environment("VILLAGE_CAPTURE") != "1":
		_smoke(dm)


func _smoke(dm) -> void:
	var cottage = null
	var cluster = null
	for st in dm.structures:
		var n := str(st.name)
		if cottage == null and n.begins_with("Cottage"):
			cottage = st
		if cluster == null and n.begins_with("Cluster"):
			cluster = st
	if cottage == null:
		print("AUDIT SMOKE missing cottage")
		return
	var decorated := 0
	var lit := 0
	for p in cottage.pieces:
		decorated += p.mesh_instance.get_child_count()
		lit += p.mesh_instance.find_children("*", "OmniLight3D", true, false).size()
	var before: int = cottage.loose_count
	dm.explode(cottage.center, 4.0, 800.0, 6.0, 0.3, false)
	print("AUDIT SMOKE cottage pieces=%d decor_nodes=%d lights=%d loose %d->%d" % [cottage.pieces.size(), decorated, lit, before, cottage.loose_count])
	if cluster != null:
		var mats := {}
		for p in cluster.pieces:
			mats[p.mat_name] = true
		var before_c: int = cluster.loose_count
		dm.explode(cluster.center, 2.2, 400.0, 3.0, 0.2, true)
		print("AUDIT SMOKE cluster mats=%s loose %d->%d" % [mats.keys(), before_c, cluster.loose_count])


func _capture() -> void:
	for i in 2:
		await get_tree().process_frame
	for cam in get_tree().current_scene.find_children("*", "Camera3D", true, false):
		cam.current = false
	DirAccess.make_dir_recursive_absolute(OUT)
	var views := [
		["village_aerial", Vector3(16.0, 46.0, 24.0), Vector3(0.0, 0.0, -6.0), 52.0],
		["village_ground_market", Vector3(0.2, 1.65, 28.5), Vector3(-6.0, 1.6, 16.0), 72.0],
		["village_ground_residential", Vector3(-17.6, 1.75, -0.6), Vector3(-25.2, 2.2, -6.3), 68.0],
		["village_ground_towers", Vector3(6.0, 2.6, -20.4), Vector3(-7.0, 4.2, -28.0), 66.0],
	]
	for view in views:
		var cam := Camera3D.new()
		cam.fov = float(view[3])
		cam.current = true
		get_parent().add_child(cam)
		cam.global_position = view[1]
		cam.look_at(view[2], Vector3.UP)
		for i in 3:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path: String = "%s/%s.png" % [OUT, view[0]]
		var err := img.save_png(path)
		var bytes := 0
		if err == OK and FileAccess.file_exists(path):
			bytes = FileAccess.get_file_as_bytes(path).size()
		print("CAPTURE %s %dx%d err=%d bytes=%d" % [view[0], img.get_width(), img.get_height(), err, bytes])
		cam.queue_free()
	get_tree().quit(0 if _floating == 0 else 2)


func _is_expansion(st) -> bool:
	var label := _label(str(st.name))
	if label in ["Cottage", "Shop", "Workshop", "Spire", "MarketStall", "Arch", "GardenWall", "Cluster", "Lantern", "Shrub"]:
		return true
	if label == "Tree":
		var parts := str(st.name).split("_")
		return parts.size() == 2 and int(parts[1]) >= 36
	return false


func _label(name: String) -> String:
	var i := name.rfind("_")
	if i <= 0:
		return name
	return name.substr(0, i)


func _world_aabb(st) -> AABB:
	var box := AABB()
	var first := true
	for p in st.pieces:
		var d: Vector3 = p.dim
		var wb: AABB = p.global_transform * AABB(-d * 0.5, d)
		if first:
			box = wb
			first = false
		else:
			box = box.merge(wb)
	return box
