extends SDTExtension
## Built-in reimplementation of the Loader mod strandLimit (sby, V3): beyond a number of cum or spit strands the oldest
## fade faster, the more so the older they are, and almost invisible strands fade out quickly (Effects > Fluids and
## marks).
## Off by default (the game's strands). The numbers are the mod's shipped settings file (its "linear" fade and alpha
## fades), applied every 6 ticks like the mod. Written from its source.
##
## Left out: the frames-per-second targets (the port's fluids are native and keep the frame rate far above them),
## deleting strands off screen and the instant-kill limit (both off in the shipped file). The game stops making new
## spit strands at 20, but strands that split add more, so the spit limit still matters.

const EVERY := 6                   # the mod's intervals (5) + 1; amounts are per tick times this
const CUM_LINEAR_BASE := 3.0       # cumagingbaselinear
const CUM_LINEAR_MULT := 0.5       # cumagingmultlinear: the oldest over the limit age fastest
const SPIT_LINEAR_BASE := 0.0      # spitagingbaselinear
const SPIT_LINEAR_MULT := 0.5      # spitagingmultlinear
const CUM_FAINT := 0.25            # fadecumstrandsalphalevel
const CUM_FAINT_AGE := 10          # cumalphafadeageincreaseamount
const SPIT_FAINT := 0.07           # fadespitstrandsalphalevel
const SPIT_FAINT_AGE := 1          # spitalphafadeageincreaseamount

var _counter := 0


func _init() -> void:
	id = "strandlimit"
	title = "strandLimit"
	description = "strandLimit (sby): beyond a number of cum or spit strands the oldest fade faster; almost invisible strands fade out quickly (Effects > Fluids and marks)."
	default_enabled = true


func _setup() -> void:
	setting("limit_cum", false, {"label": "Limit cum strands",
		"desc": "Beyond this many cum strands the oldest fade faster, the oldest fastest."})
	setting("max_cum", 40, {"label": "Max cum strands", "min": 5, "max": 150, "step": 5,
		"desc": "Cum strands that fade normally; the oldest beyond this fade faster."})
	setting("limit_spit", false, {"label": "Limit spit strands",
		"desc": "Beyond this many spit strands the oldest fade faster, the oldest fastest."})
	setting("max_spit", 20, {"label": "Max spit strands", "min": 5, "max": 150, "step": 5,
		"desc": "Spit strands that fade normally; the oldest beyond this fade faster."})
	setting("faint", false, {"label": "Faint strands fade quickly",
		"desc": "Cum and spit strands that are almost invisible fade out quickly instead of lingering."})


func _enable() -> void:
	_counter = 0
	on_late_tick(_tick)
	var group := "Fluids and marks"
	menu_control("effects", group, MenuSchema.setting_control(self, "limit_cum"))
	menu_control("effects", group, MenuSchema.setting_control(self, "max_cum",
		{"after": "Limit cum strands", "visible": func(): return get_setting("limit_cum")}))
	menu_control("effects", group, MenuSchema.setting_control(self, "limit_spit", {"after": "Max cum strands"}))
	menu_control("effects", group, MenuSchema.setting_control(self, "max_spit",
		{"after": "Limit spit strands", "visible": func(): return get_setting("limit_spit")}))
	menu_control("effects", group, MenuSchema.setting_control(self, "faint", {"after": "Max spit strands"}))


func _tick() -> void:
	var limit_cum: bool = get_setting("limit_cum")
	var limit_spit: bool = get_setting("limit_spit")
	var faint: bool = get_setting("faint")
	if not limit_cum and not limit_spit and not faint:
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
	if limit_cum:
		_limit(sc, true, int(get_setting("max_cum")), CUM_LINEAR_MULT, CUM_LINEAR_BASE)
	if limit_spit:
		_limit(sc, false, int(get_setting("max_spit")), SPIT_LINEAR_MULT, SPIT_LINEAR_BASE)


## The mod's linear fade: the strands of one kind over `most` age, the oldest most.
func _limit(sc, cum: bool, most: int, mult: float, base: float) -> void:
	var over: int = sc.strand_count(cum) - most
	if over <= 0:
		return
	var ages := PackedInt32Array()
	ages.resize(over)
	for i in over:
		ages[i] = int(((over - i) * mult + base) * EVERY)
	sc.add_strand_ages(cum, ages)


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
