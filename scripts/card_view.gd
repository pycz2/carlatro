extends Control
## One card on the table: a car (or classic playing card), a mod, a garage card, a pack or a card back.
## Moves smoothly toward target_pos; everything is drawn in code.

const Data = preload("res://scripts/data.gd")
const Art = preload("res://scripts/art.gd")
const EDITION_SHADER = preload("res://scripts/edition.gdshader")

signal clicked(card)
signal hover_changed(card, on)

enum { CAR, MOD, CONS, BACK, PACK }
const SIZE := Vector2(96, 134)

var kind := CAR
var data: Dictionary = {}
var selected := false
var lift := 0.0
var target_pos := Vector2.ZERO
var target_rot := 0.0
var base_z := 0
var base_scale := 1.0
var interactive := true
var hovered := false
var debuffed := false:
	set(v):
		debuffed = v
		queue_redraw()
var dimmed := false:
	set(v):
		dimmed = v
		queue_redraw()
var price := -1:
	set(v):
		price = v
		queue_redraw()

var face_down := false
var back_style := -1  # -1 = the back chosen in settings
var flip_x := 1.0  # x-scale factor for the flip animation

var _t := 0.0
var _punch := 0.0
var _wob := 0.0


func _ready() -> void:
	_t = randf() * 10.0
	size = SIZE
	pivot_offset = SIZE / 2
	mouse_filter = MOUSE_FILTER_STOP if interactive else MOUSE_FILTER_IGNORE
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	add_to_group("cards")  # redrawn when the card art, suits or back change
	if kind == MOD and data.get("edition", "") != "":
		var mat := ShaderMaterial.new()
		mat.shader = EDITION_SHADER
		mat.set_shader_parameter("mode", Data.EDITIONS[data.edition].mode)
		material = mat


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _on_hover(on: bool) -> void:
	hovered = on
	z_index = 100 if on else base_z
	hover_changed.emit(self, on)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()


## Draw above every UI layer while flying from the shop to a slot.
func fly_on_top() -> void:
	z_index = 1000
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(self):
		z_index = 100 if hovered else base_z


## Turn a face-down card face up with a quick flip.
func flip_up(delay := 0.0) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "flip_x", 0.0, 0.09)
	tw.tween_callback(func():
		face_down = false
		queue_redraw())
	tw.tween_property(self, "flip_x", 1.0, 0.09)


func punch(amount := 0.25) -> void:
	_punch = amount
	_wob = randf_range(-0.25, 0.25)


func _process(delta: float) -> void:
	_t += delta
	var k := 1.0 - exp(-delta * 12.0)
	var off := Vector2(0, -lift)
	if selected:
		off.y -= 34
	if hovered and interactive:
		off.y -= 4
	position = position.lerp(target_pos + off, k)
	rotation = lerp_angle(rotation, target_rot + _wob + sin(_t * 1.6) * 0.015, k)
	_wob = lerpf(_wob, 0.0, k)
	_punch = lerpf(_punch, 0.0, 1.0 - exp(-delta * 8.0))
	var s := base_scale * ((1.07 if hovered and interactive else 1.0) + _punch)
	scale = scale.lerp(Vector2(s, s), 1.0 - exp(-delta * 20.0))
	scale.x = scale.y * flip_x


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_style_box(Data.box(Color(0, 0, 0, 0.35), 10), Rect2(Vector2(4, 6), SIZE))
	match -1 if face_down else kind:
		-1: _draw_back()
		CAR: _draw_classic_card() if Data.classic_art else _draw_car_card()
		MOD: _draw_mod()
		CONS: _draw_cons()
		BACK: _draw_back()
		PACK: _draw_pack()
	if dimmed:
		draw_style_box(Data.box(Color(0, 0, 0, 0.55), 9), Rect2(Vector2.ZERO, SIZE))
	if price >= 0:
		draw_style_box(Data.box(Color("1b1f27"), 7, Color("ffc93c"), 2), Rect2(26, -28, 44, 24))
		draw_string(get_theme_default_font(), Vector2(26, -10), "$%d" % price, HORIZONTAL_ALIGNMENT_CENTER, 44, 16, Color("ffc93c"))


## Largest font size (up to size) at which every word of text fits in max_w.
func _fit(text: String, max_w: float, size: int) -> int:
	var font := get_theme_default_font()
	for word in text.split(" "):
		while size > 7 and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
			size -= 1
	return size


func _pts(arr: Array, c: Vector2, w: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(c + p * w)
	return out


func _outline(pts: PackedVector2Array, col: Color, width := 2.0) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, col, width, true)


func _draw_car_card() -> void:
	var suit: int = data.suit
	var rank: int = data.rank
	var enh: String = data.get("enh", "")
	var sc: Color = Data.suit_color(suit)
	var bg := Color("f6f0e1")
	var ink := sc.darkened(0.25)
	match enh:
		"gold": bg = Color("f7d774")
		"carbon":
			bg = Color("272a31")
			ink = sc.lightened(0.25)
		"nitro": bg = Color("e1f0ff")
		"turbo": bg = Color("ffe4de")
	draw_style_box(Data.box(bg, 9, sc, 3), Rect2(Vector2.ZERO, SIZE))
	if enh == "carbon":
		for y in range(5, 126, 8):
			for x in range(5, 88, 8):
				if (x / 8 + y / 8) % 2 == 0:
					draw_rect(Rect2(x, y, mini(8, 91 - x), mini(8, 129 - y)), Color(1, 1, 1, 0.05))
	# road
	draw_rect(Rect2(5, 98, 86, 9), Color(0, 0, 0, 0.13))
	for x in range(10, 88, 16):
		draw_rect(Rect2(x, 101.5, 8, 2), Color(1, 1, 1, 0.55))
	_draw_car(Vector2(48, 86), 39.0, sc, suit, rank, enh)

	var font := get_theme_default_font()
	var rs := Data.rank_str(rank)
	for flip in [false, true]:
		if flip:
			draw_set_transform(SIZE, PI, Vector2.ONE)
		draw_string(font, Vector2(7, 27), rs, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)
		_draw_emblem(Vector2(16, 40), 7.0, suit, sc)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if rank >= 11:
		draw_string(font, Vector2(30, 21), tr(Data.FACE_TITLES[rank]), HORIZONTAL_ALIGNMENT_RIGHT, 58, _fit(tr(Data.FACE_TITLES[rank]), 58, 11), ink)
	_draw_card_status(enh)


## Upgrade badge and debuff cross, shared by both card arts.
func _draw_card_status(enh: String) -> void:
	if enh != "":
		var badge := Data.text(Data.ENH_INFO[enh], "badge")
		draw_style_box(Data.box(Data.ENH_COLORS[enh], 5), Rect2(6, 112, 50, 15))
		draw_string(get_theme_default_font(), Vector2(6, 124), badge, HORIZONTAL_ALIGNMENT_CENTER, 50, _fit(badge, 46, 9), Color.WHITE)
	if debuffed:
		draw_style_box(Data.box(Color(0.08, 0.08, 0.1, 0.6), 9), Rect2(Vector2.ZERO, SIZE))
		draw_line(Vector2(20, 30), Vector2(76, 104), Color("ff3b30"), 6.0, true)
		draw_line(Vector2(76, 30), Vector2(20, 104), Color("ff3b30"), 6.0, true)


# Pip positions of classic number cards in unit space (x -1..1, y -1..1).
const PIPS := {
	2: [Vector2(0, -0.8), Vector2(0, 0.8)],
	3: [Vector2(0, -0.8), Vector2(0, 0), Vector2(0, 0.8)],
	4: [Vector2(-0.5, -0.8), Vector2(0.5, -0.8), Vector2(-0.5, 0.8), Vector2(0.5, 0.8)],
	5: [Vector2(-0.5, -0.8), Vector2(0.5, -0.8), Vector2(0, 0), Vector2(-0.5, 0.8), Vector2(0.5, 0.8)],
	6: [Vector2(-0.5, -0.8), Vector2(0.5, -0.8), Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(-0.5, 0.8), Vector2(0.5, 0.8)],
	7: [Vector2(-0.5, -0.8), Vector2(0.5, -0.8), Vector2(0, -0.4), Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(-0.5, 0.8), Vector2(0.5, 0.8)],
	8: [Vector2(-0.5, -0.8), Vector2(0.5, -0.8), Vector2(0, -0.4), Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(0, 0.4), Vector2(-0.5, 0.8), Vector2(0.5, 0.8)],
	9: [Vector2(-0.5, -0.8), Vector2(0.5, -0.8), Vector2(-0.5, -0.27), Vector2(0.5, -0.27), Vector2(0, 0), Vector2(-0.5, 0.27), Vector2(0.5, 0.27), Vector2(-0.5, 0.8), Vector2(0.5, 0.8)],
	10: [Vector2(-0.5, -0.8), Vector2(0.5, -0.8), Vector2(0, -0.55), Vector2(-0.5, -0.27), Vector2(0.5, -0.27), Vector2(-0.5, 0.27), Vector2(0.5, 0.27), Vector2(0, 0.55), Vector2(-0.5, 0.8), Vector2(0.5, 0.8)],
}


func _draw_classic_card() -> void:
	var suit: int = data.suit
	var rank: int = data.rank
	var enh: String = data.get("enh", "")
	var sc := Data.suit_color(suit)
	var bg := Color("fbf8f0")
	var ink := sc
	match enh:
		"gold": bg = Color("f7d774")
		"nitro": bg = Color("e1f0ff")
		"turbo": bg = Color("ffe4de")
		"carbon": bg = Color(0.85, 0.95, 1.0, 0.75)  # glass
	draw_style_box(Data.box(bg, 9, Color("2b2f38") if enh != "carbon" else Color("9fd8ff"), 2), Rect2(Vector2.ZERO, SIZE))
	if enh == "carbon":
		for i in 3:
			draw_line(Vector2(14 + i * 26, 128), Vector2(44 + i * 26, 6), Color(1, 1, 1, 0.7), 3.0)
	var font := get_theme_default_font()
	var rs := Data.rank_str(rank)
	for flip in [false, true]:
		if flip:
			draw_set_transform(SIZE, PI, Vector2.ONE)
		draw_string(font, Vector2(3, 25), rs, HORIZONTAL_ALIGNMENT_CENTER, 26, _fit(rs, 25, 20), ink)
		_draw_emblem(Vector2(16, 36), 6.0, suit, sc)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var c := Vector2(48, 67)
	if rank == 14:
		_draw_emblem(c, 22.0, suit, sc)
	elif rank >= 11:
		_draw_court(c, suit, rank, sc)
	else:
		for p in PIPS[rank]:
			var pos := c + Vector2(p.x * 20, p.y * 38)
			if p.y > 0.05:  # bottom-half pips are upside down, like real cards
				draw_set_transform(pos, PI, Vector2.ONE)
				_draw_emblem(Vector2.ZERO, 7.5, suit, sc)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				_draw_emblem(pos, 7.5, suit, sc)
	_draw_card_status(enh)


## Classic court card: a framed, double-headed figure (J: cap, Q: tiara, K: crown).
## Classic court card: a framed, double-headed figure.
## King: big crown, beard, ermine and scepter (gold frame). Queen: long hair, tiara,
## pearls and a rose (rose frame). Jack: feathered cap, no beard, halberd (teal frame).
func _draw_court(c: Vector2, suit: int, rank: int, sc: Color) -> void:
	var accent: Color = {13: Color("c9a227"), 12: Color("c2185b"), 11: Color("2f8f83")}[rank]
	draw_style_box(Data.box(accent.lightened(0.78), 4, accent, 2, 0), Rect2(c - Vector2(25, 43), Vector2(50, 86)))
	var skin := Color("f2c9a0")
	var gold := Color("ffd166")
	var ink := Color("2b2f38")
	for half in [false, true]:
		draw_set_transform(c, PI if half else 0.0, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(-22, 0), Vector2(-20, -14), Vector2(-8, -19), Vector2(8, -19), Vector2(20, -14), Vector2(22, 0)]), sc)
		match rank:
			13:  # King
				draw_colored_polygon(PackedVector2Array([Vector2(-13, -19), Vector2(13, -19), Vector2(10, -13), Vector2(-10, -13)]), Color.WHITE)
				for x in [-8, -2, 4, 9]:
					draw_circle(Vector2(x, -16), 1.0, ink)
				draw_line(Vector2(15, -1), Vector2(19, -33), gold, 2.5)
				draw_circle(Vector2(19, -35), 3.0, gold)
				draw_circle(Vector2(0, -28), 7.0, skin)
				draw_colored_polygon(PackedVector2Array([Vector2(-7, -27), Vector2(7, -27), Vector2(6, -20), Vector2(0, -16), Vector2(-6, -20)]), Color("8a5a2b"))
				draw_line(Vector2(-3, -24), Vector2(3, -24), Color("5a3a1a"), 1.5)
				draw_colored_polygon(PackedVector2Array([Vector2(-9, -33), Vector2(-10, -43), Vector2(-5, -37), Vector2(0, -44),
					Vector2(5, -37), Vector2(10, -43), Vector2(9, -33)]), gold)
				draw_circle(Vector2(0, -36), 1.6, Color("ff4b3e"))
			12:  # Queen
				draw_colored_polygon(PackedVector2Array([Vector2(-9, -35), Vector2(9, -35), Vector2(12, -17), Vector2(7, -15),
					Vector2(7, -29), Vector2(-7, -29), Vector2(-7, -15), Vector2(-12, -17)]), Color("c47a2c"))
				draw_circle(Vector2(0, -28), 6.5, skin)
				draw_line(Vector2(-2, -24), Vector2(2, -24), Color("d62828"), 1.5)
				for i in 5:
					draw_circle(Vector2(-6 + i * 3, -18 + absf(i - 2) * -0.6), 1.2, Color.WHITE)
				draw_arc(Vector2(0, -35), 6, PI, TAU, 10, gold, 2.0)
				draw_circle(Vector2(0, -41), 1.8, Color("4cc9f0"))
				draw_line(Vector2(15, -4), Vector2(15, -14), Color("2f8f3a"), 1.5)
				draw_circle(Vector2(15, -16), 3.0, Color("d62828"))
			11:  # Jack
				draw_circle(Vector2(0, -27), 6.5, skin)
				draw_colored_polygon(PackedVector2Array([Vector2(-10, -30), Vector2(-7, -36), Vector2(8, -36), Vector2(12, -30)]), sc.darkened(0.35))
				draw_colored_polygon(PackedVector2Array([Vector2(7, -35), Vector2(17, -45), Vector2(12, -33)]), accent)
				draw_line(Vector2(-17, 0), Vector2(-17, -40), Color("8fa3b8"), 2.0)
				draw_colored_polygon(PackedVector2Array([Vector2(-17, -40), Vector2(-11, -35), Vector2(-17, -31)]), Color("c9ccd1"))
				for x in [-6, 0, 6]:
					draw_line(Vector2(x, -19), Vector2(x, -14), gold, 1.5)
		draw_circle(Vector2(-2.5, -29), 0.9, ink)
		draw_circle(Vector2(2.5, -29), 0.9, ink)
		_draw_emblem(Vector2(0, -7), 4.0, suit, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(c + Vector2(-25, 0), c + Vector2(25, 0), accent, 1.0)


func _draw_car(c: Vector2, w: float, col: Color, suit: int, rank: int, enh: String) -> void:
	var paint := Color("30343c") if enh == "carbon" else col
	var dark := paint.darkened(0.5)
	# ground shadow
	draw_set_transform(c + Vector2(0, 0.38 * w), 0.0, Vector2(1, 0.16))
	draw_circle(Vector2.ZERO, w * 1.08, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# nitro flame from the exhaust
	if enh == "nitro":
		draw_colored_polygon(_pts([Vector2(-0.98, 0.04), Vector2(-1.55, 0.12), Vector2(-0.98, 0.2)], c, w), Color("2f8cff"))
		draw_colored_polygon(_pts([Vector2(-0.98, 0.09), Vector2(-1.3, 0.12), Vector2(-0.98, 0.15)], c, w), Color("bff0ff"))
	var body := _pts(Data.CAR_BODIES[suit], c, w)
	draw_colored_polygon(body, paint)
	# highlight band along the lower body
	draw_line(c + Vector2(-0.95, 0.06) * w, c + Vector2(0.95, 0.06) * w, paint.lightened(0.2), 2.0)
	if rank >= 11:
		var stripe := Color("ffd166") if rank == 14 else Color(1, 1, 1, 0.9)
		draw_line(c + Vector2(-0.96, -0.02) * w, c + Vector2(0.97, -0.02) * w, stripe, 3.0)
	_outline(body, dark, 2.0)
	var win := _pts(Data.CAR_WINDOWS[suit], c, w)
	draw_colored_polygon(win, Color("bfe3ff"))
	draw_line(win[1] + Vector2(3, 1), win[0] + Vector2(6, -1), Color(1, 1, 1, 0.8), 1.5)
	_outline(win, dark, 1.5)
	if suit == 3:  # offroad: B-pillar and roof rack
		draw_line(c + Vector2(-0.15, -0.38) * w, c + Vector2(-0.15, -0.18) * w, dark, 2.0)
		draw_line(c + Vector2(-0.9, -0.54) * w, c + Vector2(0.2, -0.54) * w, dark, 2.0)
	if suit == 1 or rank >= 12:  # rear wing
		var wing := _pts([Vector2(-1.08, -0.36), Vector2(-0.66, -0.36), Vector2(-0.66, -0.29), Vector2(-1.08, -0.29)], c, w)
		draw_colored_polygon(wing, dark)
		draw_line(c + Vector2(-0.88, -0.29) * w, c + Vector2(-0.88, -0.12) * w, dark, 2.0)
	if enh == "turbo":
		draw_circle(c + Vector2(0.66, -0.02) * w, 0.11 * w, Color("ff4b3e"))
		draw_circle(c + Vector2(0.66, -0.02) * w, 0.05 * w, Color.WHITE)
	# lights
	draw_circle(c + Vector2(0.95, -0.03) * w, 2.5, Color("fff3a0"))
	draw_rect(Rect2(c + Vector2(-1.0, -0.06) * w, Vector2(3, 4)), Color("ff2d2d"))
	# wheels
	var off := suit == 3
	var wr := (0.27 if off else 0.21) * w
	var gold := rank >= 13 or enh == "gold"
	for x in [-0.6, 0.6]:
		var p := c + Vector2(x, 0.2) * w
		draw_circle(p, wr, Color("17171b"))
		draw_circle(p, wr * 0.55, Color("ffd166") if gold else Color("c9ccd1"))
		draw_circle(p, wr * 0.2, Color("55585e"))
	if rank == 14:
		_outline(body, Color("ffd166"), 1.2)


func _draw_emblem(c: Vector2, r: float, suit: int, col: Color) -> void:
	Art.emblem(self, c, r, suit, col)


func _draw_classic_suit(c: Vector2, r: float, suit: int, col: Color) -> void:
	Art.classic_suit(self, c, r, suit, col)


func _draw_icon(c: Vector2, k: String, col: Color, bg: Color) -> void:
	match k:
		"mult":
			draw_colored_polygon(_pts([Vector2(0, -24), Vector2(9, -10), Vector2(15, 2), Vector2(13, 13), Vector2(6, 19),
				Vector2(-6, 19), Vector2(-13, 13), Vector2(-15, 2), Vector2(-8, -6), Vector2(-4, 4), Vector2(-2, -12)], c, 1.0), col)
			draw_colored_polygon(_pts([Vector2(0, -4), Vector2(6, 5), Vector2(6, 12), Vector2(0, 17), Vector2(-6, 12), Vector2(-5, 5)], c, 1.0), Color("ffd166"))
		"chips":
			var pts := PackedVector2Array()
			for i in 32:
				var rr := 21.0 if (i / 2) % 2 == 0 else 15.0
				pts.append(c + Vector2.from_angle(i * TAU / 32 + 0.1) * rr)
			draw_colored_polygon(pts, col)
			draw_circle(c, 7, bg)
		"xmult":
			draw_colored_polygon(_pts([Vector2(5, -25), Vector2(-13, 3), Vector2(-1, 3), Vector2(-7, 25),
				Vector2(13, -5), Vector2(1, -5), Vector2(9, -25)], c, 1.0), col)
		"econ":
			draw_circle(c, 20, col)
			draw_circle(c, 15, col.darkened(0.25))
			draw_string(get_theme_default_font(), c + Vector2(-20, 9), "$", HORIZONTAL_ALIGNMENT_CENTER, 40, 26, col.lightened(0.4))
		"util":
			draw_line(c + Vector2(-13, 13), c + Vector2(8, -8), col, 8.0, true)
			draw_circle(c + Vector2(10, -10), 10, col)
			draw_circle(c + Vector2(14, -14), 5, bg)
			draw_circle(c + Vector2(-13, 13), 5, col)
		"gauge":
			draw_arc(c + Vector2(0, 6), 22, PI, TAU, 24, col, 4.0, true)
			for i in 5:
				var d := Vector2.from_angle(PI + i * PI / 4)
				draw_line(c + Vector2(0, 6) + d * 15, c + Vector2(0, 6) + d * 20, col, 2.0)
			draw_line(c + Vector2(0, 6), c + Vector2(0, 6) + Vector2.from_angle(-0.6) * 18, Color("ff4b3e"), 3.0, true)
			draw_circle(c + Vector2(0, 6), 4, col)
		"arrow":  # classic hand upgrade
			draw_colored_polygon(_pts([Vector2(0, -22), Vector2(18, -2), Vector2(7, -2), Vector2(7, 20), Vector2(-7, 20), Vector2(-7, -2), Vector2(-18, -2)], c, 1.0), col)
		"spark":  # classic trick card
			var pts := PackedVector2Array()
			for i in 8:
				pts.append(c + Vector2.from_angle(-PI / 2 + i * TAU / 8) * (22.0 if i % 2 == 0 else 6.0))
			draw_colored_polygon(pts, col)
			draw_circle(c + Vector2(14, -14), 3, col)
			draw_circle(c + Vector2(-15, 12), 2, col)
		"fan":  # classic card pack
			for i in 3:
				draw_set_transform(c + Vector2(0, 8), (i - 1) * 0.35, Vector2.ONE)
				draw_style_box(Data.box(Color("fbf8f0"), 3, Color("2b2f38"), 1, 0), Rect2(-10, -28, 20, 28))
				_draw_classic_suit(Vector2(0, -14), 5.0, [0, 2, 1][i], Data.CLASSIC_SUIT_COLORS[[0, 2, 1][i]])
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"jester":  # classic joker pack
			draw_colored_polygon(_pts([Vector2(-18, 10), Vector2(-14, -16), Vector2(0, 2), Vector2(14, -16), Vector2(18, 10)], c, 1.0), col)
			for p in [Vector2(-14, -18), Vector2(14, -18), Vector2(0, 0)]:
				draw_circle(c + p, 4, Color("ffd166"))
			draw_rect(Rect2(c + Vector2(-18, 10), Vector2(36, 6)), col.darkened(0.3))


func _draw_mod() -> void:
	var kc: Color = Data.KIND_COLORS[data.kind]
	var inner := kc.darkened(0.62)
	draw_style_box(Data.box(Color("20242e"), 9, kc, 3), Rect2(Vector2.ZERO, SIZE))
	draw_style_box(Data.box(inner, 6), Rect2(8, 8, 80, 72))
	var c := Vector2(48, 44)
	for i in 12:
		var d := Vector2.from_angle(i * TAU / 12)
		draw_line(c + d * 14, c + d * 34, Color(kc, 0.12), 3.0)
	Art.mod_art(self, data.id, c)
	var font := get_theme_default_font()
	var name := Data.text(data, "name")
	draw_multiline_string(font, Vector2(5, 96), name, HORIZONTAL_ALIGNMENT_CENTER, 86, _fit(name, 86, 12), 2, Color.WHITE)
	var r: int = data.get("rarity", 0)
	draw_string(font, Vector2(5, 128), tr(Data.RARITY_NAMES[r]), HORIZONTAL_ALIGNMENT_CENTER, 86, 9, [Color("8fa3b8"), Color("3ecf6a"), Color("ff4b3e")][r])
	if data.get("edition", "") != "":
		var ed := Data.text(Data.EDITIONS[data.edition], "badge")
		draw_style_box(Data.box(Color(1, 1, 1, 0.9), 4), Rect2(10, 10, 46, 13))
		draw_string(font, Vector2(10, 20), ed, HORIZONTAL_ALIGNMENT_CENTER, 46, _fit(ed, 42, 9), Color("1b1f27"))


func _draw_cons() -> void:
	var tune: bool = data.id == "tune"
	var border := Color("4cc9f0") if tune else Color("f4a259")
	var bg := Color("10284a") if tune else Color("3d2412")
	draw_style_box(Data.box(bg, 9, border, 3), Rect2(Vector2.ZERO, SIZE))
	draw_style_box(Data.box(bg.lightened(0.08), 6), Rect2(8, 22, 80, 60))
	var font := get_theme_default_font()
	var head := Data.tv("DYNO TUNE", "UPGRADE") if tune else Data.tv("WORKSHOP", "TRICK")
	draw_string(font, Vector2(5, 17), head, HORIZONTAL_ALIGNMENT_CENTER, 86, _fit(head, 86, 10), border)
	Art.item_art(self, data, Vector2(48, 52))
	var label: String = tr(Data.hand_name(data.hand)) if tune else Data.text(data, "name")
	draw_multiline_string(font, Vector2(5, 100), label, HORIZONTAL_ALIGNMENT_CENTER, 86, _fit(label, 86, 13), 2, Color.WHITE)


func _draw_back() -> void:
	var r := Rect2(Vector2.ZERO, SIZE)
	var font := get_theme_default_font()
	var style := back_style if back_style >= 0 else Data.back_style
	match style:
		0:  # checkered flag
			draw_style_box(Data.box(Color("8c1c13"), 9, Color("f6f0e1"), 3), r)
			for gy in 8:
				for gx in 6:
					draw_rect(Rect2(21 + gx * 9, 31 + gy * 9, 9, 9), Color("101010") if (gx + gy) % 2 == 0 else Color("f6f0e1"))
			draw_rect(Rect2(21, 31, 54, 72), Color("f6f0e1"), false, 2.0)
			draw_string(font, Vector2(4, 22), "CARLATRO", HORIZONTAL_ALIGNMENT_CENTER, 88, 11, Color("ffd23f"))
			draw_string(font, Vector2(4, 122), "CARLATRO", HORIZONTAL_ALIGNMENT_CENTER, 88, 11, Color("ffd23f"))
		1:  # racing stripes
			draw_style_box(Data.box(Color("1f4fa0"), 9, Color("f6f0e1"), 3), r)
			draw_rect(Rect2(33, 3, 10, 128), Color("f6f0e1"))
			draw_rect(Rect2(53, 3, 10, 128), Color("f6f0e1"))
			draw_circle(Vector2(48, 67), 17, Color("f6f0e1"))
			draw_circle(Vector2(48, 67), 14, Color("e2443a"))
			draw_string(font, Vector2(28, 74), "C", HORIZONTAL_ALIGNMENT_CENTER, 40, 20, Color.WHITE)
		2:  # carbon fiber
			draw_style_box(Data.box(Color("1b1d22"), 9, Color("8a1c1c"), 3), r)
			for y in range(5, 127, 6):
				for x in range(5, 89, 6):
					if (x / 6 + y / 6) % 2 == 0:
						draw_rect(Rect2(x, y, 6, 3), Color(1, 1, 1, 0.07))
					else:
						draw_rect(Rect2(x, y + 3, 3, 3), Color(1, 1, 1, 0.04))
			draw_circle(Vector2(48, 67), 15, Color("8a1c1c"))
			draw_string(font, Vector2(28, 74), "C", HORIZONTAL_ALIGNMENT_CENTER, 40, 20, Color("ffd23f"))
		3:  # neon grid (synthwave sunset)
			draw_style_box(Data.box(Color("1a0b2e"), 9, Color("ff3fa4"), 3), r)
			draw_circle(Vector2(48, 66), 22, Color("ff9a3c"))
			for i in 4:
				draw_rect(Rect2(24, 58 + i * 6, 48, 2), Color("1a0b2e"))
			draw_rect(Rect2(4, 70, 88, 60), Color("1a0b2e"))
			# floor area inside the border; bottom corners cut to stay inside the rounded frame
			var floor_area := PackedVector2Array([Vector2(4, 70), Vector2(92, 70), Vector2(92, 124), Vector2(86, 130), Vector2(10, 130), Vector2(4, 124)])
			for i in 6:
				var y := 72.0 + pow(i, 1.6) * 4.5
				_clip_line(Vector2(5, y), Vector2(91, y), floor_area, Color("ff3fa4"), 1.5)
			for i in range(-4, 5):
				_clip_line(Vector2(48 + i * 4, 70), Vector2(48 + i * 22, 130), floor_area, Color("3ff0ff"), 1.0)
		_:  # classic lattice, red or blue
			var col := Color("b3202a") if style == 4 else Color("1d4e9e")
			draw_style_box(Data.box(Color("fbf8f0"), 9, Color("2b2f38"), 1), r)
			draw_style_box(Data.box(col, 5), Rect2(8, 8, 80, 118))
			var panel := PackedVector2Array([Vector2(8, 8), Vector2(88, 8), Vector2(88, 126), Vector2(8, 126)])
			for i in range(-14, 12):
				for line in [[Vector2(8 + i * 8, 8), Vector2(126 + i * 8, 126)], [Vector2(8 + i * 8, 126), Vector2(126 + i * 8, 8)]]:
					_clip_line(line[0], line[1], panel, Color(1, 1, 1, 0.35), 1.0)
			draw_rect(Rect2(12, 12, 72, 110), Color(1, 1, 1, 0.8), false, 1.5)


## Draw the part of the line a-b that lies inside the polygon.
func _clip_line(a: Vector2, b: Vector2, poly: PackedVector2Array, col: Color, width: float) -> void:
	for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly):
		draw_polyline(seg, col, width)


func _draw_pack() -> void:
	var col: Color = data.color
	var pts := PackedVector2Array()
	for x in range(2, 95, 8):
		pts.append(Vector2(x, 2 if (x / 8) % 2 == 0 else 8))
	for x in range(94, 1, -8):
		pts.append(Vector2(x, 132 if (x / 8) % 2 == 0 else 126))
	draw_colored_polygon(pts, col.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(10, 14), Vector2(40, 14), Vector2(16, 120), Vector2(10, 120)]), Color(1, 1, 1, 0.12))
	_outline(pts, col.lightened(0.35), 2.0)
	draw_style_box(Data.box(Color(0, 0, 0, 0.25), 8), Rect2(12, 22, 72, 62))
	var c := Vector2(48, 53)
	var classic := Data.classic_art
	match data.type:
		"cars":
			if classic:
				_draw_icon(c, "fan", Color.WHITE, col)
			else:
				_draw_car(c + Vector2(0, 2), 30.0, Color("ffd23f"), 0, 13, "")
		"tunes": _draw_icon(c, "arrow" if classic else "gauge", Color("bfe3ff"), col.darkened(0.25))
		"workshop": _draw_icon(c, "spark" if classic else "util", Color("ffe0b0"), Color(0, 0, 0, 0.25))
		"mods": _draw_icon(c, "jester" if classic else "xmult", Color("ffd23f"), col.darkened(0.25))
	var font := get_theme_default_font()
	var label := Data.text(data, "name")
	draw_multiline_string(font, Vector2(5, 102), label, HORIZONTAL_ALIGNMENT_CENTER, 86, _fit(label, 86, 13), 2, Color.WHITE)
