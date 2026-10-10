extends SceneTree
# Renders single cards with a transparent background for the website (site/cards/*.png).
# Run: godot --path . -s res://tools/site_cards.gd

const D = preload("res://scripts/data.gd")
const CV = preload("res://scripts/card_view.gd")
const OUT = "res://site/cards/"

const CARDS := [
	["car_ace", false, false, CV.CAR, {"rank": 14, "suit": 0, "enh": ""}],
	["car_king", false, false, CV.CAR, {"rank": 13, "suit": 2, "enh": "nitro"}],
	["car_jdm", false, false, CV.CAR, {"rank": 11, "suit": 1, "enh": "gold"}],
	["classic_king", true, true, CV.CAR, {"rank": 13, "suit": 0, "enh": ""}],
	["classic_queen", true, true, CV.CAR, {"rank": 12, "suit": 1, "enh": ""}],
	["classic_ace", true, true, CV.CAR, {"rank": 14, "suit": 2, "enh": ""}],
	["mod_nitro", false, false, CV.MOD, {"id": "nitro", "edition": "poly"}],
	["mod_drift", false, false, CV.MOD, {"id": "drift_king"}],
	["joker", true, true, CV.MOD, {"id": "nitro", "edition": "foil"}],
	["voucher", false, false, CV.VOUCHER, {"id": "antimatter"}],
	["pack", false, false, CV.PACK, {}],
	["back", true, true, CV.BACK, {}],
]


func _initialize():
	for spec in CARDS:
		D.classic_art = spec[1]
		D.classic_suits = spec[2]
		D.back_style = 4
		var vp := SubViewport.new()
		vp.size = Vector2i(220, 300)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var data: Dictionary = spec[4]
		if spec[3] == CV.MOD:
			var m := D.mod_def(data.id).duplicate(true)
			m.merge(data, true)
			data = m
		elif spec[3] == CV.VOUCHER:
			data = D.VOUCHERS.filter(func(v): return v.id == spec[4].id)[0]
		elif spec[3] == CV.PACK:
			data = D.PACKS[0]
		var cv := CV.new()
		cv.kind = spec[3]
		cv.data = data
		cv.interactive = false
		cv.base_scale = 2.0
		cv.target_pos = Vector2(110, 150) - CV.SIZE / 2
		cv.position = cv.target_pos
		cv.scale = Vector2(2, 2)
		vp.add_child(cv)
		for i in 4:
			await process_frame
		vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + spec[0] + ".png"))
		vp.queue_free()
	print("cards rendered")
	quit()
