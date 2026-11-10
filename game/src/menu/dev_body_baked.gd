class_name DevBodyBaked
extends RefCounted
## Body > Legs > Baked legs (our layer): her legs and pelvis from the body workshop's bake (SDT_Body_Data,
## BODY156: baked/legs.json + legs.bin, see its BAKE.md "Формат снимков v1"), posed by the game's own transforms.
## The bake holds every leg piece as fixed points and triangles plus their positions on a grid of the two angles
## (thigh relative to the pelvis, knee bend) in the piece's bone frame; a shader blends the 4 neighbouring
## snapshots, so the CPU only places two bones per leg and sets a few numbers per frame. Lines: a strip along the
## contour edges the bake marks as drawn (nearest snapshot). The bake is drawn from the template's pieces: it is
## read from the save folder (body_bake/), never shipped.
## Placement (leg test step 1): the bake's space is the template's "Body Template"; her torso space is that moved by
## the vanilla thigh's start point minus its template place. Our thigh turns about our own hip by the game's thigh
## angle, our calf about our knee by the game's calf angle (the joints differ from the vanilla ones by ~22 / 29 px,
## so the game's pieces cannot match ours at both ends). The far leg: the same, inside the far leg's container,
## which copies the near thigh x0.95. Shoes ride our calf, so they stay on our foot.

const FOLDER := "body_bake"
const V_HIP := Vector2(-197.1, 5.0)         # the vanilla thigh's place in the Body Template (step 1)
const CALF_TO_VANILLA := Vector2(27.27, -8.38)   # our calf frame -> the vanilla calf frame (step 1)
const FOOT_FIT := Vector2(2.0, -22.5)   # fitted by eye by Dima (10.11): the heel inside the shoe as in the game
static var foot_fit := FOOT_FIT   # Body > Legs > Shoes along / across the foot (Dima fits it by eye)
const STAND := [90.0, -142.5215]            # card angles 0/0 in bone degrees (the doll's two_legs.gd)
const SLOT_THIGH := ["leg"]                 # drawn where the game's thigh is (before its group)
const SLOT_CALF := ["lower_bridge", "calf", "calf_muscle", "knee_cap", "foot_v"]   # where the calf is (over the thigh)

static var on := false
static var status := ""
static var data := {}            # the parsed legs.json
static var _bin := PackedByteArray()
static var _layers := {}         # "near/leg" -> {fill: MeshInstance2D, ink: MeshInstance2D, bone: String}
static var _nodes := []          # every node we added
static var _hidden := []         # the game's pictures we hid
static var _after := Callable()
static var _ticker: Node = null
static var _angles := {"prev": Vector2.ZERO, "now": Vector2.ZERO}   # card angles (hip, knee) at the last two ticks
static var _bones := {}          # the bake's bones: rest origins
static var _offset := Vector2.ZERO   # template -> torso
static var _shader: Shader = null


static func folder() -> String:
	return ProjectSettings.globalize_path(FlashSharedObject.save_dir.path_join(FOLDER))


## Reads the bake from the save folder (once). False with `status` saying why.
static func load_bake() -> bool:
	if not data.is_empty():
		return true
	var json_path := FlashSharedObject.save_dir.path_join(FOLDER).path_join("legs.json")
	if not FileAccess.file_exists(json_path):
		status = "no bake: copy SDT_Body_Data/baked/legs.json and legs.bin into %s" % folder()
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not d is Dictionary or d.get("format", "") != "sdt-body-bake":
		status = "legs.json is not a body bake"
		return false
	var bin := FileAccess.get_file_as_bytes(json_path.get_base_dir().path_join(str(d.positions_file)))
	return use_bake(d, bin, "bake: %s (%s)" % [d.source.body, d.source.baked])


## A bake given directly (the checks feed a small one).
static func use_bake(d: Dictionary, bin: PackedByteArray, label := "bake given") -> bool:
	if bin.is_empty():
		status = "legs.bin missing"
		return false
	data = d
	_bin = bin
	status = label
	return true


static func set_on(v: bool) -> void:
	on = v
	if v and (not DevBodyOverlay.ours or g.her == null or not load_bake()):
		on = false
	_sync()


static func _sync() -> void:
	var want := on and DevBodyOverlay.ours and g.her != null
	if want and _nodes.is_empty():
		_build()
	elif not want and not _nodes.is_empty():
		_teardown()
	if want and not _after.is_valid():
		_after = func(_c): DevBodyBaked._update()
		Hooks.add_after(&"Her.updateElements", _after, "bakedlegs", 99)
	elif not want and _after.is_valid():
		Hooks.remove(&"Her.updateElements", _after)
		_after = Callable()
	if want:
		_update()
		_angles.prev = _angles.now
		for n in _nodes:
			(n as Node2D).reset_physics_interpolation()   # no glide in from the origin on the first frame
		_frame()


# ---------------------------------------------------------------- building

static func _build() -> void:
	var h = g.her
	var t = h.torso
	_bones = data.bones
	_offset = t.leg.position - V_HIP
	var keys := _keys()
	# over her back and its highlight (Dima: her back behind our legs, not over them as in the game), under her clothes
	var thigh_at: int = _anchor().get_index()
	if t.get("backHighlight") != null:
		thigh_at = maxi(thigh_at, t.backHighlight.get_index() + 1)
	var calf_at: int = t.rightCalfContainer.get_index()
	# near: the pelvis and the thigh before the game's leg group, the lower leg (and the kneecap, over the calf as in
	# the workshop) before the calf's container; fills first, then lines, per slot
	var pelvis := _pelvis_nodes(keys)
	var slot_a := [pelvis[0]]
	var slot_a_ink := [pelvis[1]]
	var slot_b := []
	var slot_b_ink := []
	var far := []
	var far_ink := []
	for leg in ["near", "far"]:
		var offset := 0
		for layer in data.legs[leg].layers:
			var size: int = int(layer.positions_bytes)
			var pair := _layer_nodes(layer, keys)
			_layers["%s/%s" % [leg, layer.name]] = {"fill": pair[0], "ink": pair[1], "bone": layer.bone}
			if leg == "far":
				far.append(pair[0])
				if pair[1]: far_ink.append(pair[1])
			elif layer.name in SLOT_THIGH:
				slot_a.append(pair[0])
				if pair[1]: slot_a_ink.append(pair[1])
			else:
				slot_b.append(pair[0])
				if pair[1]: slot_b_ink.append(pair[1])
			offset += size
	var k := 0
	for n in slot_a + slot_a_ink:
		t.add_child(n)
		t.move_child(n, thigh_at + k)
		k += 1
	calf_at = t.rightCalfContainer.get_index()
	k = 0
	for n in slot_b + slot_b_ink:
		t.add_child(n)
		t.move_child(n, calf_at + k)
		k += 1
	var flc = h.leftLegContainer
	var leg_at: int = flc.leg.get_index()
	k = 0
	for n in far + far_ink:
		flc.add_child(n)
		flc.move_child(n, leg_at + k)
		k += 1
	_nodes = slot_a + slot_a_ink + slot_b + slot_b_ink + far + far_ink
	# the game's skin pictures and their highlights (Dima: no vanilla highlights on ours), the backside's skin
	_hidden.clear()
	var pics := [t.leg.thigh, t.leg.highlights, h.leftLegContainer.leg.thigh]
	pics.append_array(_shapes(t.rightCalfContainer.calf))
	pics.append_array(_shapes(h.leftLegContainer.leg.calf))
	pics.append_array(_shapes(h.leftLegContainer.leg))   # the far thigh's highlight sits on the leg itself
	pics.append_array(_shapes(t.backside))
	for p in pics:
		if p != null and p.visible:
			p.visible = false
			_hidden.append(p)
	_ticker = Node.new()
	_ticker.name = "BakedLegsTicker"
	_ticker.set_script(_TickerScript)
	Flash.add_child(_ticker)


## Her thigh in her torso: itself, or the group it is drawn in.
static func _anchor() -> Node:
	var t = g.her.torso
	var n: Node = t.leg
	while n.get_parent() != t and n.get_parent() != null:
		n = n.get_parent()
	return n


static func _shapes(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is FlashShape:
			out.append(c)
	return out


static func _keys() -> Dictionary:
	return {"hip": data.drivers.hip["keys"], "knee": data.drivers.knee["keys"]}


static func _texture_rgf(bytes: PackedByteArray, width: int, height: int) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create_from_data(width, height, false, Image.FORMAT_RGF, bytes))


static func _texture_bits(rows: Array, edges: int) -> ImageTexture:
	var bytes := PackedByteArray()
	bytes.resize(edges * rows.size())
	for r in rows.size():
		var bits := Marshalls.base64_to_raw(rows[r])
		for e in edges:
			if bits[e / 8] & (1 << (e % 8)):
				bytes[r * edges + e] = 255
	return ImageTexture.create_from_image(Image.create_from_data(edges, rows.size(), false, Image.FORMAT_R8, bytes))


## A layer: a fill mesh (its triangles; each vertex's x is its index into the snapshot texture) and, unless it is
## a filler, a line strip (4 vertices per contour edge: x = edge, y = corner).
static func _layer_nodes(layer: Dictionary, keys: Dictionary) -> Array:
	var count: int = keys.hip.size() * keys.knee.size()
	var verts: int = int(layer.positions_bytes) / count / 8
	var start: int = int(layer.positions_offset)
	var snaps := _texture_rgf(_bin.slice(start, start + int(layer.positions_bytes)), verts, count)
	var fill_xf := PackedVector2Array()
	for i in verts:
		fill_xf.append(Vector2(i, 0))
	var fill := _mesh_node(fill_xf, PackedInt32Array(layer.triangles), snaps, null, 0, false)
	fill.name = "Baked_%s" % layer.name
	var ink: MeshInstance2D = null
	if layer.kind != "filler" and not (layer.ink_visible as Array).is_empty():
		var n: int = int(layer.outline)
		ink = _ink_node(n, snaps, _texture_bits(layer.ink_visible, n))
		ink.name = "BakedInk_%s" % layer.name
	# the vertices hold indices, not places: tell Godot where the piece really is, or it is culled when zoomed in
	var box := _bounds(_bin.slice(start, start + int(layer.positions_bytes)).to_float32_array(), verts, count)
	_set_rect(fill, box)
	if ink:
		_set_rect(ink, box)
	return [fill, ink]


## The rectangle every snapshot of a piece stays in (every 7th snapshot read, and the last; a margin for the rest
## and the lines).
static func _bounds(pos: PackedFloat32Array, verts: int, count: int) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var snaps := range(0, count, 7)
	if not snaps.has(count - 1):
		snaps.append(count - 1)
	for s in snaps:
		var base: int = s * verts * 2
		for i in verts:
			var p := Vector2(pos[base + i * 2], pos[base + i * 2 + 1])
			lo = lo.min(p)
			hi = hi.max(p)
	return Rect2(lo, hi - lo).grow(40.0)


static func _set_rect(node: CanvasItem, box: Rect2) -> void:
	RenderingServer.canvas_item_set_custom_rect(node.get_canvas_item(), true, box)


static func _pelvis_nodes(keys: Dictionary) -> Array:
	var flat: Array = data.pelvis.outline
	var pts := PackedVector2Array()
	var bytes := PackedFloat32Array()
	for i in range(0, flat.size(), 2):
		pts.append(Vector2(flat[i], flat[i + 1]))
		bytes.append(flat[i])
		bytes.append(flat[i + 1])
	var snaps := _texture_rgf(bytes.to_byte_array(), pts.size(), 1)
	var idx := PackedVector2Array()
	for i in pts.size():
		idx.append(Vector2(i, 0))
	var fill := _mesh_node(idx, Geometry2D.triangulate_polygon(pts), snaps, null, 0, true)
	fill.name = "Baked_pelvis"
	var ink := _ink_node(pts.size(), snaps, _texture_bits(data.pelvis.ink_visible, pts.size()))
	ink.name = "BakedInk_pelvis"
	ink.material.set_shader_parameter("static_rows", true)
	var box := _bounds(bytes, pts.size(), 1)
	_set_rect(fill, box)
	_set_rect(ink, box)
	_layers["pelvis"] = {"fill": fill, "ink": ink, "bone": "torso"}
	return [fill, ink]


static func _mesh_node(verts: PackedVector2Array, tris: PackedInt32Array, snaps: Texture2D, vis: Texture2D, n_outline: int, static_rows: bool) -> MeshInstance2D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = tris
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance2D.new()
	node.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = _get_shader()
	mat.set_shader_parameter("snaps", snaps)
	mat.set_shader_parameter("static_rows", static_rows)
	mat.set_shader_parameter("fill", Color8(240, 211, 191))
	mat.set_shader_parameter("ink", vis != null)
	if vis != null:
		mat.set_shader_parameter("vis", vis)
		mat.set_shader_parameter("n_outline", n_outline)
		mat.set_shader_parameter("color", Color8(92, 66, 52))
		mat.set_shader_parameter("half_width", 1.2)
	node.material = mat
	return node


static func _ink_node(n: int, snaps: Texture2D, vis: Texture2D) -> MeshInstance2D:
	var verts := PackedVector2Array()
	var tris := PackedInt32Array()
	for e in n:
		for corner in 4:
			verts.append(Vector2(e, corner))
		var b := e * 4
		tris.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	return _mesh_node(verts, tris, snaps, vis, n, false)


static func _get_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader


const SHADER := """
shader_type canvas_item;
// Baked legs: blend the 4 neighbouring snapshots (rows of `snaps`, texel x = vertex) in the piece's bone frame.
uniform sampler2D snaps : filter_nearest;
uniform sampler2D vis : filter_nearest;
uniform ivec4 rows;          // (hip lo, knee lo), (hip lo, knee hi), (hip hi, knee lo), (hip hi, knee hi)
uniform vec2 weights;        // hip, knee
uniform int ink_row;         // the nearest snapshot (lines)
uniform bool static_rows = false;
uniform bool ink = false;
uniform int n_outline = 0;
uniform float half_width = 1.2;
uniform vec4 fill : source_color = vec4(0.941, 0.827, 0.749, 1.0);
uniform vec4 color : source_color = vec4(0.361, 0.259, 0.204, 1.0);
varying float shown;

vec2 point(int i) {
	if (static_rows) {
		return texelFetch(snaps, ivec2(i, 0), 0).xy;
	}
	vec2 a = texelFetch(snaps, ivec2(i, rows.x), 0).xy;
	vec2 b = texelFetch(snaps, ivec2(i, rows.y), 0).xy;
	vec2 c = texelFetch(snaps, ivec2(i, rows.z), 0).xy;
	vec2 d = texelFetch(snaps, ivec2(i, rows.w), 0).xy;
	return mix(mix(a, b, weights.y), mix(c, d, weights.y), weights.x);
}

void vertex() {
	shown = 1.0;
	if (!ink) {
		VERTEX = point(int(VERTEX.x + 0.5));
	} else {
		int e = int(VERTEX.x + 0.5);
		int corner = int(VERTEX.y + 0.5);
		vec2 p0 = point(e);
		vec2 p1 = point((e + 1) % n_outline);
		vec2 d = p1 - p0;
		float len = length(d);
		d = len > 0.0001 ? d / len : vec2(1.0, 0.0);
		vec2 n = vec2(-d.y, d.x);
		float side = (corner % 2 == 0) ? -1.0 : 1.0;
		vec2 p = (corner < 2) ? p0 - d * half_width : p1 + d * half_width;
		VERTEX = p + n * side * half_width;
		shown = texelFetch(vis, ivec2(e, static_rows ? ink_row : ink_row), 0).r;
	}
}

void fragment() {
	if (ink) {
		if (shown < 0.5) discard;
		COLOR = color;
	} else {
		COLOR = fill;
	}
}
"""


static func _teardown() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	_layers.clear()
	for p in _hidden:
		if is_instance_valid(p):
			p.visible = true
	_hidden.clear()
	if is_instance_valid(_ticker):
		_ticker.queue_free()
	_ticker = null


# ---------------------------------------------------------------- every tick: bones; every frame: angles

static func set_foot_fit(v: Vector2) -> void:
	foot_fit = v
	if on and not _layers.is_empty():
		_update()


## The game's thigh (torso space) and calf (thigh space) transforms.
static func game_bones() -> Array:
	var t = g.her.torso
	var tt: Transform2D = t.leg.transform
	var n: Node = t.leg.get_parent()
	while n != t and n is Node2D:
		tt = (n as Node2D).transform * tt
		n = n.get_parent()
	return [tt, t.rightCalfContainer.calf.transform]


## Our bones for the game's pose, torso space: [thigh, calf] (our thigh about our hip by the game's thigh angle,
## our calf about our knee by the game's calf angle).
static func our_bones() -> Array:
	var gb := game_bones()
	var hip: Vector2 = _v(_bones.thigh.rest_origin)
	var knee: Vector2 = _v(_bones.calf.rest_origin)
	var thigh := Transform2D(gb[0].get_rotation(), _offset + hip)
	var calf := thigh * Transform2D(gb[1].get_rotation(), knee - hip)
	return [thigh, calf]


static func _v(a: Array) -> Vector2:
	return Vector2(a[0], a[1])


## Each tick after the game's updateElements: bones and the shoes; the angles for the frames until the next tick.
static func _update() -> void:
	if g.her == null or not DevBodyOverlay.ours:
		_sync()
		return
	var h = g.her
	var gb := game_bones()
	var ob := our_bones()
	var near := {"thigh": ob[0], "calf": ob[1], "torso": Transform2D(0.0, _offset)}   # the pelvis: rigid on the torso
	# the far leg: our near bones taken relative to the game's near thigh, put on the far leg's (x0.95 copy)
	var far_base: Transform2D = h.leftLegContainer.leg.transform * gb[0].affine_inverse()
	var far := {"thigh": far_base * ob[0], "calf": far_base * ob[1]}
	for key in _layers:
		var l: Dictionary = _layers[key]
		var xf: Transform2D = (far if key.begins_with("far/") else near)[l.bone]
		l.fill.transform = xf
		if l.ink:
			l.ink.transform = xf
	# shoes: drawn in the vanilla calf's frame; ours sits at CALF_TO_VANILLA in it, so they ride our calf
	var shoe: Transform2D = gb[0].affine_inverse() * ob[1] * Transform2D(0.0, -CALF_TO_VANILLA + foot_fit)
	h.torso.rightCalfContainer.footwear.transform = shoe
	h.leftLegContainer.leg.footwear.transform = shoe
	_angles.prev = _angles.now
	_angles.now = Vector2(STAND[0] - rad_to_deg(gb[0].get_rotation()), -(rad_to_deg(gb[1].get_rotation()) - STAND[1]))


## Every frame: the angles between the last two ticks (Godot glides the bones the same way), into the shaders.
static func _frame() -> void:
	if _layers.is_empty():
		return
	var f := Engine.get_physics_interpolation_fraction() if FlashRectClip.smooth and not g.gamePaused else 1.0
	var a: Vector2 = _angles.prev.lerp(_angles.now, f)
	var keys := _keys()
	var hk := _cell(keys.hip, a.x)
	var kk := _cell(keys.knee, a.y)
	var nk: int = keys.knee.size()
	var rows := Vector4i(int(hk.x) * nk + int(kk.x), int(hk.x) * nk + int(kk.y), int(hk.y) * nk + int(kk.x), int(hk.y) * nk + int(kk.y))
	var nearest := int(hk.x if hk.z < 0.5 else hk.y) * nk + int(kk.x if kk.z < 0.5 else kk.y)
	var w := Vector2(hk.z, kk.z)
	for key in _layers:
		var l: Dictionary = _layers[key]
		for n in [l.fill, l.ink]:
			if n == null:
				continue
			var m: ShaderMaterial = n.material
			m.set_shader_parameter("rows", rows)
			m.set_shader_parameter("weights", w)
			m.set_shader_parameter("ink_row", nearest)


## The two neighbouring keys around `v` and the weight of the second (keys ascending or descending).
static func _cell(keys: Array, v: float) -> Vector3:
	var n := keys.size()
	if n == 1:
		return Vector3.ZERO
	var asc: bool = keys[n - 1] > keys[0]
	for i in n - 1:
		var lo: float = keys[i]
		var hi: float = keys[i + 1]
		if (asc and v <= hi) or (not asc and v >= hi):
			return Vector3(i, i + 1, clampf(inverse_lerp(lo, hi, v), 0.0, 1.0))
	return Vector3(n - 2, n - 1, 1.0)


const _TickerScript := preload("res://src/menu/dev_body_baked_ticker.gd")
