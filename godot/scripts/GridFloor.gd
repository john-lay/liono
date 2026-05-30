extends MeshInstance

const SIZE := 64
const LIGHT := Color(0.50, 0.50, 0.50)
const DARK := Color(0.38, 0.38, 0.38)
const LINE := Color(0.18, 0.18, 0.18)

func _ready() -> void:
	var img := Image.new()
	img.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	img.lock()
	for y in range(SIZE):
		for x in range(SIZE):
			if x == 0 or y == 0:
				img.set_pixel(x, y, LINE)
			else:
				var checker := ((x / (SIZE / 2)) + (y / (SIZE / 2))) % 2 == 0
				img.set_pixel(x, y, LIGHT if checker else DARK)
	img.unlock()

	var tex := ImageTexture.new()
	tex.create_from_image(img, Texture.FLAG_REPEAT)

	var mat := SpatialMaterial.new()
	mat.albedo_texture = tex
	mat.flags_unshaded = true
	mat.uv1_scale = Vector3(40.0, 40.0, 1.0)
	set_surface_material(0, mat)
