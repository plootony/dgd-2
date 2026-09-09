extends RefCounted
## Local art direction. Environment correction affects the 3D image, not the HUD.
const NAMES = ["Нейтральный", "Пасмурный лес", "Холодные сумерки", "Лунная ночь"]
const LOOKS = [
	{"sun":1.3, "light":"ffffff", "ambient":0.65, "fill":"b8d1e3", "sky":1.0, "saturation":1.04, "contrast":1.03, "fog":0.20, "mist":"b8ccdb"},
	{"sun":0.65, "light":"d8ded1", "ambient":0.48, "fill":"a6b9ae", "sky":0.65, "saturation":0.60, "contrast":1.04, "fog":0.28, "mist":"a8bcb0"},
	{"sun":0.60, "light":"aac7dc", "ambient":0.42, "fill":"6b96b0", "sky":0.70, "saturation":0.72, "contrast":1.02, "fog":0.22, "mist":"7598b0"},
	{"sun":0.48, "light":"98cae4", "ambient":0.34, "fill":"527c98", "sky":0.55, "saturation":0.58, "contrast":1.01, "fog":0.24, "mist":"628fa7"}
]
static var _curves: Dictionary = {}

static func _curve(index: int) -> GradientTexture1D:
	if _curves.has(index): return _curves[index]
	# Per-channel curves: retain neutral highlights and a readable black level.
	var colors = [
		PackedColorArray([Color(0,0,0), Color(0.25,0.25,0.25), Color(0.5,0.5,0.5), Color(1,1,1)]),
		PackedColorArray([Color(0.016,0.024,0.021), Color(0.22,0.245,0.23), Color(0.48,0.51,0.48), Color(0.94,0.96,0.91)]),
		PackedColorArray([Color(0.006,0.015,0.027), Color(0.19,0.23,0.28), Color(0.43,0.49,0.55), Color(0.94,0.97,1.0)]),
		PackedColorArray([Color(0.004,0.012,0.022), Color(0.17,0.23,0.28), Color(0.39,0.49,0.55), Color(0.85,0.96,1.0)])
	]
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.25,0.5,1.0])
	gradient.colors = colors[index]
	var texture = GradientTexture1D.new()
	texture.width = 256
	texture.gradient = gradient
	_curves[index] = texture
	return texture

static func apply(env: Environment, sun: DirectionalLight3D, scene: Node, index: int, effects: bool) -> void:
	var active = clampi(index,0,LOOKS.size()-1) if effects else 0
	var look: Dictionary = LOOKS[active]
	sun.light_energy = look.sun
	sun.light_color = Color(look.light)
	env.ambient_light_energy = look.ambient
	env.ambient_light_color = Color(look.fill)
	env.background_energy_multiplier = look.sky
	env.adjustment_color_correction = _curve(active) if active > 0 else null
	env.adjustment_saturation = look.saturation
	env.adjustment_contrast = look.contrast
	var fog = scene.get_node_or_null("DriftingFog") as FogVolume
	if fog and fog.material is ShaderMaterial:
		fog.material.set_shader_parameter("density",look.fog)
		fog.material.set_shader_parameter("tint",Color(look.mist))
