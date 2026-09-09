extends Control
## A bounded, read-only history; values are already sampled by the monitor.
var series: Array = []
var colors: Array = []
var minimum_max: float = 1.0
var unit: String = ""

func _draw() -> void:
	var maximum = minimum_max
	for values in series:
		for value in values: maximum = maxf(maximum,value)
	maximum *= 1.15
	var area = Rect2(0,18,size.x,size.y-21)
	for fraction in [0.0,0.5,1.0]:
		var y = area.position.y+area.size.y*fraction
		draw_line(Vector2(0,y),Vector2(size.x,y),Color(1,1,1,0.09))
	draw_string(ThemeDB.fallback_font,Vector2(0,12),"0 — %.1f %s" % [maximum,unit],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("97aabd"))
	for s in series.size():
		var values = series[s]
		if values.size()<2: continue
		var points = PackedVector2Array()
		for i in values.size():
			points.append(Vector2(area.size.x*i/59.0,area.end.y-area.size.y*values[i]/maximum))
		draw_polyline(points,colors[s],1.8,true)
