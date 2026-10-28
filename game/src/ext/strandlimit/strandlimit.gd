extends SDTExtension
## Built-in reimplementation of the Loader mod strandLimit (sby, V3): beyond a number of cum strands the oldest fade
## faster, the more so the older they are, and almost invisible strands fade out quickly (Effects > Fluids and marks).
## Off by default (the game's strands). The numbers are the mod's shipped settings file (its "linear" fade and alpha
## fades), applied every 6 ticks like the mod. Written from its source.
##
## Left out: the frames-per-second targets (the port's fluids are native and keep the frame rate far above them),
## the spit limit (the game already allows at most 20 spit strands, where the mod's started), deleting strands off
## screen and the instant-kill limit (both off in the shipped file).

const EVERY := 6                   # the mod's intervals (5) + 1; amounts are per tick times this
const LINEAR_BASE := 3.0           # cumagingbaselinear
const LINEAR_MULT := 0.5           # cumagingmultlinear: the oldest over the limit age fastest
const CUM_FAINT := 0.25            # fadecumstrandsalphalevel
const CUM_FAINT_AGE := 10          # cumalphafadeageincreaseamount
const SPIT_FAINT := 0.07           # fadespitstrandsalphalevel
const SPIT_FAINT_AGE := 1          # spitalphafadeageincreaseamount

var _counter := 0


func _init() -> void:
	id = "strandlimit"
	title = "strandLimit"
	description = "strandLimit (sby): beyond a number of cum strands the oldest fade faster; almost invisible strands fade out quickly (Effects > Fluids and marks)."
	default_enabled = true


func _setup() -> void:
	setting("limit_cum", false, {"label": "Limit cum strands",
		"desc": "Beyond this many cum strands the oldest fade faster, the oldest fastest."})
	setting("max_cum", 40, {"label": "Max cum strands", "min": 5, "max": 150, "step": 5,
		"desc": "Cum strands that fade normally; the oldest beyond this fade faster."})
	setting("faint", false, {"label": "Faint strands fade quickly",
		"desc": "Cum and spit strands that are almost invisible fade out quickly instead of lingering."})


func _enable() -> void:
	_counter = 0
	on_late_tick(_tick)
	var group := "Fluids and marks"
	menu_control("effects", group, MenuSchema.setting_control(self, "limit_cum"))
	menu_control("effects", group, MenuSchema.setting_control(self, "max_cum",
		{"after": "Limit cum strands", "visible": func(): return get_setting("limit_cum")}))
	menu_control("effects", group, MenuSchema.setting_control(self, "faint", {"after": "Max cum strands"}))


func _tick() -> void:
	var limit: bool = get_setting("limit_cum")
	var faint: bool = get_setting("faint")
	if not limit and not faint:
		return
	_counter += 1
	if _counter < EVERY:
		return
	_counter = 0
	var sc = g.strandControl
	if sc == null:
		return
	if faint:
		_fade_faint(sc, true, CUM_FAINT, CUM_FAINT_AGE * EVERY)
		_fade_faint(sc, false, SPIT_FAINT, SPIT_FAINT_AGE * EVERY)
	if limit:
		var over: int = sc.strand_count(true) - int(get_setting("max_cum"))
		if over > 0:
			var ages := PackedInt32Array()
			ages.resize(over)
			for i in over:
				ages[i] = int(((over - i) * LINEAR_MULT + LINEAR_BASE) * EVERY)
			sc.add_strand_ages(true, ages)


## Ages the strands of one kind whose alpha is below `level` by `amount`.
func _fade_faint(sc, cum: bool, level: float, amount: int) -> void:
	var alphas: PackedFloat32Array = sc.strand_alphas(cum)
	var ages := PackedInt32Array()
	ages.resize(alphas.size())
	var any := false
	for i in alphas.size():
		if alphas[i] < level:
			ages[i] = amount
			any = true
	if any:
		sc.add_strand_ages(cum, ages)
