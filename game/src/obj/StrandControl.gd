class_name StrandControl
extends RefCounted
## Port of obj.StrandControl: owns the spit / cum strands.

var strands: Array = []
var cumStrands: Array = []
var lockedStrands: Array = []
const maxStrands := 20


func newStrand(layer: FlashSprite, links: int, mass: float, a = null, b = null, long: bool = false,
		initialSpeed = null, back: bool = false) -> Strand:
	var s := Strand.new(layer, links, mass, a, b, long, back)
	s.instancePoints(initialSpeed)
	layer.addChild(s)
	strands.append(s)
	return s


func checkElementAnchors(element: FlashDisplayObject) -> void:
	for s in strands + cumStrands:
		s.checkElementAnchors(element)


func checkCostumeAnchors() -> void:
	for s in strands + cumStrands:
		s.checkCostumeAnchors()


func clearSpitStrands() -> void:
	for i in strands.size():
		strands[0].killMe()


func clearCumStrands() -> void:
	for i in cumStrands.size():
		cumStrands[0].killMe()
	for i in lockedStrands.size():
		lockedStrands[0].kill()


func smearStrands(p: Vector2, radius: float = 25.0) -> void:
	for s in strands + cumStrands:
		s.smear(p, radius)


func newCumStrand(p: Vector2, container: FlashDisplayObject) -> Strand:
	var s := Strand.new(g.cumLayer, 1, g.randomCumMass())
	s.addSourceLink(p, container)
	g.cumLayer.addChild(s)
	cumStrands.append(s)
	return s


func addStrand(from: Strand, links: Array, mass: float) -> void:
	var s := Strand.new(from.layer, 0, mass)
	s.giveLinks(links)
	s.age = from.age
	s.ageMax = from.ageMax
	s.cumStrand = from.cumStrand
	from.layer.addChild(s)
	if from.cumStrand:
		cumStrands.append(s)
	else:
		strands.append(s)
	s.distSplitDelay = 10
	s.graphics.copyFrom(from.graphics)


func delistStrand(s: Strand) -> void:
	if s.cumStrand:
		cumStrands.erase(s)
	else:
		strands.erase(s)


func delistLockedStrand(s) -> void:
	lockedStrands.erase(s)


func maxPop() -> bool:
	return strands.size() >= maxStrands
