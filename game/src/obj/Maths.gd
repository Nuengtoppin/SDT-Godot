class_name Maths
extends RefCounted
## Port of obj.Maths, plus ActionScript numeric helpers whose semantics differ from GDScript's.


## ActionScript Math.round: rounds half up (towards +infinity), unlike GDScript's round().
static func round(v: float) -> float:
	return floor(v + 0.5)


static func getUnitVector(a: float) -> Vector2:
	return Vector2(sin(a), -cos(a))


static func getAngle(px: float, py: float) -> float:
	return radToDeg(atan2(py, px)) + 90.0


static func getRadAngle(px: float, py: float) -> float:
	return atan2(py, px) + PI * 0.5


static func getDist(dx: float, dy: float) -> float:
	return sqrt(dx * dx + dy * dy)


static func degToRad(a: float) -> float:
	return a / 180.0 * PI


static func radToDeg(a: float) -> float:
	return a / PI * 180.0


static func angleDiff(a: float, b: float) -> float:
	var d := a - b
	if d < -180.0:
		d += 360.0
	elif d > 180.0:
		d -= 360.0
	return d


static func normaliseAngle(a: float) -> float:
	while a >= 180.0:
		a -= 360.0
	while a <= -180.0:
		# (sic) the original adds 180 here
		a += 180.0
	return a


static func cross(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x


static func dot(a: Vector2, b: Vector2) -> float:
	return a.x * b.x + a.y * b.y


static func vectorLength(v: Vector2) -> float:
	return sqrt(v.x * v.x + v.y * v.y)


static func sigRound(places: int, v: float) -> float:
	v *= pow(10.0, places)
	v = Maths.round(v)
	return v / pow(10.0, places)


static func intersect(l1: Line, l2: Line) -> Dictionary:
	var d := l1.A * l2.B - l2.A * l1.B
	if d == 0:
		return {"intersect": false}
	var ix := (l2.B * l1.C - l1.B * l2.C) / d
	var iy := (l1.A * l2.C - l2.A * l1.C) / d
	var on1 := false
	var on2 := false
	if ix >= minf(l1.x1, l1.x2) and ix < maxf(l1.x1, l1.x2):
		on1 = true
	elif iy >= minf(l1.y1, l1.y2) and iy < maxf(l1.y1, l1.y2):
		on1 = true
	if ix >= minf(l2.x1, l2.x2) and ix < maxf(l2.x1, l2.x2):
		on2 = true
	elif iy >= minf(l2.y1, l2.y2) and iy < maxf(l2.y1, l2.y2):
		on2 = true
	return {"intersect": true, "d": d, "x": ix, "y": iy, "onLine1": on1, "onLine2": on2}


static func pointDot(a: Vector2, b: Vector2, c: Vector2) -> float:
	return dot(Vector2(b.x - a.x, b.y - a.y), Vector2(c.x - a.x, c.y - a.y))


static func normal(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var ab := Vector2(b.x - a.x, b.y - a.y)
	var ac := Vector2(c.x - a.x, c.y - a.y)
	var t := dot(ab, ac) / (ab.x * ab.x + ab.y * ab.y)
	return Vector2(a.x + ab.x * t, a.y + ab.y * t)


static func mirrorPoint(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var n := normal(a, b, c)
	return Vector2(n.x - (c.x - n.x), n.y - (c.y - n.y))


static func generateEdges(points: Array) -> Array:
	var out: Array = []
	var n := points.size()
	for i in n:
		var a := Vector2(points[i].x, points[i].y)
		var b := Vector2(points[0].x, points[0].y) if i == n - 1 else Vector2(points[i + 1].x, points[i + 1].y)
		out.append(Line.new(a, b))
	return out
