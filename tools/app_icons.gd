extends SceneTree
# Renders the app icons used by the installable web app (PWA): icons/app_512.png, app_180.png, app_144.png.
# Run: godot --path . -s res://tools/app_icons.gd

const D = preload("res://scripts/data.gd")
const CV = preload("res://scripts/card_view.gd")


func _initialize():
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.size = Vector2(512, 512)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/bg.gdshader")
	bg.material = mat
	vp.add_child(bg)
	# the classic King behind, the car Ace in front; all inside the safe zone of round masks
	var specs := [[true, true, {"rank": 13, "suit": 0, "enh": ""}, Vector2(318, 238), 0.26],
		[false, false, {"rank": 14, "suit": 0, "enh": ""}, Vector2(196, 276), -0.2]]
	for spec in specs:
		D.classic_art = spec[0]
		D.classic_suits = spec[1]
		var cv := CV.new()
		cv.kind = CV.CAR
		cv.data = spec[2]
		cv.interactive = false
		cv.base_scale = 2.05
		cv.scale = Vector2(2.05, 2.05)
		cv.target_pos = spec[3] - CV.SIZE / 2
		cv.position = cv.target_pos
		cv.target_rot = spec[4]
		cv.rotation = spec[4]
		vp.add_child(cv)
		for i in 3:
			await process_frame
		cv.set_process(false)  # freeze the idle wobble
	for i in 6:
		await process_frame
	var img := vp.get_texture().get_image()
	for size in [512, 180, 144]:
		var copy := img.duplicate()
		copy.resize(size, size, Image.INTERPOLATE_LANCZOS)
		copy.save_png(ProjectSettings.globalize_path("res://icons/app_%d.png" % size))
	print("icons rendered")
	quit()
