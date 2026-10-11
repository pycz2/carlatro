extends RefCounted
## Procedural pictures shared by cards and UI: suit emblems, mini cards,
## and a unique picture for every mod, garage item and boss.
## All functions draw on the given Control and must be called from its draw step.
## Pictures show what the thing does, so they fit both the car and the classic theme.

const Data = preload("res://scripts/data.gd")

const RED := Color("ff4b3e")
const BLUE := Color("2f8cff")
const PURPLE := Color("c13cff")
const GOLD := Color("ffc93c")
const GREEN := Color("3ecf6a")
const ORANGE := Color("f08a24")
const INK := Color("1b1f27")
const CREAM := Color("f6f0e1")

const FLAME := [Vector2(0, -28), Vector2(10, -12), Vector2(17, 0), Vector2(15, 12), Vector2(7, 18), Vector2(-7, 18),
	Vector2(-15, 12), Vector2(-17, 0), Vector2(-9, -8), Vector2(-5, 3), Vector2(-2, -14)]
const FLAME_CORE := [Vector2(0, -4), Vector2(6, 5), Vector2(6, 12), Vector2(0, 17), Vector2(-6, 12), Vector2(-5, 5)]
const BOLT := [Vector2(5, -25), Vector2(-13, 3), Vector2(-1, 3), Vector2(-7, 25), Vector2(13, -5), Vector2(1, -5), Vector2(9, -25)]


# ---------------------------------------------------------------- primitives

static func poly(ci: Control, c: Vector2, pts: Array, col: Color, s := 1.0) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p * s)
	ci.draw_colored_polygon(out, col)


static func outline(ci: Control, c: Vector2, pts: Array, col: Color, width := 2.0, s := 1.0) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p * s)
	out.append(c + pts[0] * s)
	ci.draw_polyline(out, col, width, true)


static func text(ci: Control, center: Vector2, s: String, size: int, col: Color, outline_px := 0) -> void:
	var f := ci.get_theme_default_font()
	var pos := center + Vector2(-f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0, size * 0.36)
	if outline_px > 0:
		ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline_px, Color(0, 0, 0, 0.85))
	ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Effect pill in the bottom-right corner of a picture centered at c.
static func badge(ci: Control, c: Vector2, s: String, col: Color) -> void:
	var f := ci.get_theme_default_font()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8.0
	var r := Rect2(c + Vector2(37 - w, 19), Vector2(w, 16))
	ci.draw_style_box(Data.box(col.darkened(0.25), 5, Color(0, 0, 0, 0.6), 1, 0), r)
	text(ci, r.get_center(), s, 12, Color.WHITE)


static func flame(ci: Control, c: Vector2, s := 1.0, col := RED) -> void:
	poly(ci, c, FLAME, col, s)
	poly(ci, c, FLAME_CORE, Color("ffd166"), s)


static func arrow(ci: Control, from: Vector2, to: Vector2, col: Color, width := 3.0) -> void:
	var d := (to - from).normalized()
	ci.draw_line(from, to - d * 5, col, width, true)
	var n := Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([to, to - d * 8 + n * 5, to - d * 8 - n * 5]), col)


static func coin(ci: Control, c: Vector2, r := 9.0, label := "$") -> void:
	ci.draw_circle(c, r, GOLD.darkened(0.25))
	ci.draw_circle(c, r * 0.78, GOLD)
	text(ci, c, label, int(r * 1.2), Color("8a5a00"))


static func chip(ci: Control, c: Vector2, r := 9.0) -> void:
	ci.draw_circle(c, r, BLUE)
	for i in 6:
		var d := Vector2.from_angle(i * TAU / 6)
		ci.draw_line(c + d * r * 0.65, c + d * r, Color.WHITE, 2.0)
	ci.draw_circle(c, r * 0.45, Color.WHITE)


static func sparkle(ci: Control, c: Vector2, r := 6.0, col := Color.WHITE) -> void:
	var pts := []
	for i in 8:
		pts.append(Vector2.from_angle(-PI / 2 + i * TAU / 8) * (r if i % 2 == 0 else r * 0.3))
	poly(ci, c, pts, col)


static func crown(ci: Control, c: Vector2, s := 1.0) -> void:
	poly(ci, c, [Vector2(-18, 6), Vector2(-18, -10), Vector2(-9, -2), Vector2(0, -16), Vector2(9, -2), Vector2(18, -10), Vector2(18, 6)], GOLD, s)
	for p in [Vector2(-9, 2), Vector2(0, 1), Vector2(9, 2)]:
		ci.draw_circle(c + p * s, 2.2 * s, RED)


static func no_sign(ci: Control, c: Vector2, r: float) -> void:
	ci.draw_arc(c, r, 0, TAU, 40, RED, 4.0, true)
	ci.draw_line(c + Vector2(-r, -r) * 0.7, c + Vector2(r, r) * 0.7, RED, 4.0, true)


# ---------------------------------------------------------------- suits and mini cards

static func emblem(ci: Control, c: Vector2, r: float, suit: int, col: Color) -> void:
	if Data.who_suits:
		who_suit(ci, c, r, suit, col)
		return
	if Data.classic_suits:
		classic_suit(ci, c, r, suit, col)
		return
	match suit:
		0:  # star
			var pts := PackedVector2Array()
			for i in 10:
				pts.append(c + Vector2.from_angle(-PI / 2 + i * TAU / 10) * (r if i % 2 == 0 else r * 0.45))
			ci.draw_colored_polygon(pts, col)
		1:  # rising sun
			ci.draw_circle(c, r * 0.6, col)
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8)
				ci.draw_line(c + d * r * 0.8, c + d * r * 1.25, col, maxf(1.5, r * 0.2))
		2:  # shield
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r) * 0.9, c + Vector2(r, -r) * 0.9,
				c + Vector2(r, 0.1 * r) * 0.9, c + Vector2(0, 1.15 * r) * 0.9, c + Vector2(-r, 0.1 * r) * 0.9]), col)
		3:  # mountains
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-1.15, 0.8) * r, c + Vector2(-0.35, -0.85) * r,
				c + Vector2(0.1, 0.0) * r, c + Vector2(0.45, -0.5) * r, c + Vector2(1.15, 0.8) * r]), col)


static func classic_suit(ci: Control, c: Vector2, r: float, suit: int, col: Color) -> void:
	match suit:
		0:  # heart
			ci.draw_circle(c + Vector2(-0.48, -0.25) * r, 0.55 * r, col)
			ci.draw_circle(c + Vector2(0.48, -0.25) * r, 0.55 * r, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-1.0, -0.1) * r, c + Vector2(1.0, -0.1) * r, c + Vector2(0, 1.0) * r]), col)
		1:  # diamond
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -1.1) * r, c + Vector2(0.75, 0) * r, c + Vector2(0, 1.1) * r, c + Vector2(-0.75, 0) * r]), col)
		2:  # spade
			ci.draw_circle(c + Vector2(-0.48, 0.2) * r, 0.52 * r, col)
			ci.draw_circle(c + Vector2(0.48, 0.2) * r, 0.52 * r, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.98, 0.1) * r, c + Vector2(0, -1.05) * r, c + Vector2(0.98, 0.1) * r]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0.3) * r, c + Vector2(0.35, 1.05) * r, c + Vector2(-0.35, 1.05) * r]), col)
		3:  # club
			ci.draw_circle(c + Vector2(0, -0.45) * r, 0.45 * r, col)
			ci.draw_circle(c + Vector2(-0.5, 0.15) * r, 0.45 * r, col)
			ci.draw_circle(c + Vector2(0.5, 0.15) * r, 0.45 * r, col)
			ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(0.35, 1.05) * r, c + Vector2(-0.35, 1.05) * r]), col)


## A tiny playing card (w wide) with its rank and suit, rotated around its center.
static func mini_card(ci: Control, c: Vector2, rank: String, suit: int, w := 18.0, rot := 0.0, bg := CREAM) -> void:
	var h := w * 1.4
	var col := Data.suit_color(suit)
	ci.draw_set_transform(c, rot, Vector2.ONE)
	ci.draw_style_box(Data.box(Color(0, 0, 0, 0.3), 3), Rect2(-w / 2 + 1.5, -h / 2 + 2, w, h))
	ci.draw_style_box(Data.box(bg, 3, col, 1, 0), Rect2(-w / 2, -h / 2, w, h))
	var f := ci.get_theme_default_font()
	var size := int(maxf(7.0, w * 0.42))
	ci.draw_string(f, Vector2(-w / 2 + 2, -h / 2 + size), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	if Data.classic_art:
		emblem(ci, Vector2(w * 0.08, h * 0.12), w * 0.24, suit, col)
	else:
		_car_shape(ci, Vector2(0, h * 0.18), w * 0.4, col, suit)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Cards fanned around a pivot below them.
static func fan(ci: Control, c: Vector2, cards: Array, w := 18.0, spread := 0.28, radius := 24.0) -> void:
	var n := cards.size()
	for i in n:
		var a := (i - (n - 1) / 2.0) * spread
		mini_card(ci, c + Vector2(0, radius) + Vector2(sin(a), -cos(a)) * radius, cards[i][0], cards[i][1], w, a)


## Cards in a row, centered at c.
static func row(ci: Control, c: Vector2, cards: Array, w := 15.0, gap := 2.0) -> void:
	var n := cards.size()
	for i in n:
		mini_card(ci, c + Vector2((i - (n - 1) / 2.0) * (w + gap), 0), cards[i][0], cards[i][1], w)


static func rank_text(r: int) -> String:
	return Data.rank_str(r)


# ---------------------------------------------------------------- mods

## Picture and effect badge of a mod, centered at c (art area about 76 x 70).
static func mod_art(ci: Control, id: String, c: Vector2) -> void:
	if Data.who_art and not (id in ["v8", "rising_sun", "autobahn", "mud_tires"] and not Data.who_suits):
		_mod_art_who(ci, id, c)
	elif Data.classic_art:
		_mod_art_classic(ci, id, c)
	elif id in ["v8", "rising_sun", "autobahn", "mud_tires"] and Data.classic_suits:
		_mod_art_classic(ci, id, c)  # classic suits: the suit emblem tells the effect
	else:
		_mod_art_car(ci, id, c)


## Card-table pictures for the classic card art.
static func _mod_art_classic(ci: Control, id: String, c: Vector2) -> void:
	match id:
		"nitro":
			jester(ci, c + Vector2(-2, -4), 1.1)
			badge(ci, c, "+4", RED)
		"v8", "rising_sun", "autobahn", "mud_tires":
			var suit: int = Data.mod_def(id).suit
			ci.draw_circle(c + Vector2(-4, -4), 25, Color(1, 1, 1, 0.12))
			emblem(ci, c + Vector2(-4, -4), 19, suit, Data.suit_color(suit).lightened(0.15))
			flame(ci, c + Vector2(22, -20), 0.42)
			badge(ci, c, "+3", RED)
		"twin_turbo":
			mini_card(ci, c + Vector2(-10, -2), "K", 0, 26, -0.18)
			mini_card(ci, c + Vector2(10, -2), "K", 2, 26, 0.18)
			flame(ci, c + Vector2(0, -26), 0.4)
			badge(ci, c, "+8", RED)
		"wide_body":
			mini_card(ci, c + Vector2(-12, 0), "Q", 1, 24, -0.2)
			mini_card(ci, c + Vector2(8, 0), "Q", 3, 24, 0.2)
			chip(ci, c + Vector2(22, -20), 9)
			badge(ci, c, "+50", BLUE)
		"convoy_leader":
			fan(ci, c + Vector2(0, -8), [["7", 0], ["7", 1], ["7", 2]], 22, 0.35, 26)
			badge(ci, c, "+12", RED)
		"drift_king":
			for i in 4:
				mini_card(ci, c + Vector2(-21 + i * 13, 8 - i * 8), rank_text(5 + i), i % 4, 17, -0.1)
			arrow(ci, c + Vector2(-26, -12), c + Vector2(6, -28), Color.WHITE, 2.5)
			badge(ci, c, "+12", RED)
		"brand_loyalty":
			fan(ci, c + Vector2(-2, -6), [["K", 1], ["9", 1], ["6", 1], ["3", 1]], 19, 0.3, 24)
			badge(ci, c, "+10", RED)
		"lightweight":
			poly(ci, c, [Vector2(-22, 18), Vector2(-15, 2), Vector2(-4, -14), Vector2(10, -25), Vector2(18, -28),
				Vector2(14, -14), Vector2(4, 0), Vector2(-8, 12)], Color("eef3ff"))
			ci.draw_line(c + Vector2(-24, 20), c + Vector2(16, -26), Color("9aa8c0"), 2.0, true)
			for i in 5:
				var p := c + Vector2(-16, 10).lerp(Vector2(10, -20), i / 4.0)
				ci.draw_line(p, p + Vector2(-6, -2), Color("9aa8c0"), 1.0)
			text(ci, c + Vector2(20, 2), "3", 16, Color.WHITE, 3)
			badge(ci, c, "+20", RED)
		"odometer":
			ci.draw_style_box(Data.box(INK, 4, Color("8fa3b8"), 2, 0), Rect2(c + Vector2(-28, -14), Vector2(56, 22)))
			var digits := ["0", "4", "2", "7"]
			for i in 4:
				var cell := Rect2(c + Vector2(-25 + i * 13, -11), Vector2(11, 16))
				ci.draw_rect(cell, RED if i == 3 else Color("2b2f38"))
				text(ci, cell.get_center(), digits[i], 12, Color.WHITE)
			arrow(ci, c + Vector2(0, -16), c + Vector2(0, -30), GREEN, 3.0)
			badge(ci, c, "+1", RED)
		"chrome_bumper":
			crown(ci, c + Vector2(-4, -6), 1.2)
			chip(ci, c + Vector2(20, 6), 9)
			badge(ci, c, "+30", BLUE)
		"ace_driver":
			mini_card(ci, c + Vector2(-4, -2), "A", 2, 32, -0.08)
			sparkle(ci, c + Vector2(18, -22), 7, GOLD)
			badge(ci, c, "+4", RED)
		"even_gears":
			fan(ci, c + Vector2(0, -6), [["2", 0], ["4", 3], ["6", 1], ["8", 2]], 18, 0.3, 24)
			badge(ci, c, "+4", RED)
		"odd_gears":
			fan(ci, c + Vector2(0, -6), [["A", 2], ["3", 0], ["7", 3], ["9", 1]], 18, 0.3, 24)
			badge(ci, c, "+31", BLUE)
		"car_show":
			ci.draw_set_transform(c + Vector2(0, 4), 0.0, Vector2(1, 0.5))
			ci.draw_circle(Vector2.ZERO, 34, Color("5a3a1a"))
			ci.draw_circle(Vector2.ZERO, 30, Color("1e6b3a"))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for i in 3:
				var r := Rect2(c + Vector2(-24 + i * 17, -4), Vector2(14, 20))
				ci.draw_style_box(Data.box(Color("20242e"), 3, [RED, BLUE, PURPLE][i], 1, 0), r)
				sparkle(ci, r.get_center(), 4, [RED, BLUE, PURPLE][i])
			badge(ci, c, "+4", RED)
		"scrap_collector":
			mini_card(ci, c + Vector2(8, -22), "5", 0, 14, 0.6)
			poly(ci, c, [Vector2(-15, -6), Vector2(15, -6), Vector2(11, 18), Vector2(-11, 18)], Color("8a96a8"))
			ci.draw_rect(Rect2(c + Vector2(-18, -11), Vector2(36, 5)), Color("aab4c3"))
			for x in [-6, 0, 6]:
				ci.draw_line(c + Vector2(x, -2), c + Vector2(x * 0.8, 14), Color("5f6a7a"), 2.0)
			badge(ci, c, "+3", RED)
		"rev_limiter":
			mini_card(ci, c + Vector2(-2, -2), "K", 1, 22)
			ci.draw_arc(c + Vector2(-2, -2), 24, -2.7, 1.9, 32, ORANGE, 3.0, true)
			var tip := c + Vector2(-2, -2) + Vector2.from_angle(1.9) * 24
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-6, -2), tip + Vector2(5, -5), tip + Vector2(1, 7)]), ORANGE)
			badge(ci, c, "+2", ORANGE)
		"echo_exhaust":
			mini_card(ci, c + Vector2(-14, -2), "5", 3, 22)
			for i in 3:
				ci.draw_arc(c + Vector2(0, -2), 8.0 + i * 7, -0.8, 0.8, 12, ORANGE.lightened(i * 0.15), 3.0, true)
			badge(ci, c, "2-5", ORANGE)
		"launch_control":
			chip_stack(ci, c + Vector2(-4, 6), 3)
			text(ci, c + Vector2(-22, -14), "1", 20, Color.WHITE, 3)
			badge(ci, c, "X2", PURPLE)
		"final_lap":
			var wood := Color("c08a4a")
			ci.draw_rect(Rect2(c + Vector2(-16, -28), Vector2(32, 4)), wood)
			ci.draw_rect(Rect2(c + Vector2(-16, 14), Vector2(32, 4)), wood)
			outline(ci, c, [Vector2(-12, -24), Vector2(12, -24), Vector2(2, -5), Vector2(12, 14), Vector2(-12, 14), Vector2(-2, -5)], Color("cfe8ff"), 2.0)
			poly(ci, c, [Vector2(-3, -9), Vector2(3, -9), Vector2(1, -6), Vector2(-1, -6)], GOLD)
			poly(ci, c, [Vector2(-10, 13), Vector2(10, 13), Vector2(0, 2)], GOLD)
			badge(ci, c, "X3", PURPLE)
		"photo_finish":
			ci.draw_style_box(Data.box(Color("8a5a2b"), 3, Color("c9a227"), 3, 0), Rect2(c + Vector2(-18, -26), Vector2(36, 44)))
			ci.draw_rect(Rect2(c + Vector2(-13, -21), Vector2(26, 34)), Color("e8dcc0"))
			ci.draw_circle(c + Vector2(0, -6), 6, Color("f2c9a0"))
			poly(ci, c, [Vector2(-10, 13), Vector2(-8, 3), Vector2(8, 3), Vector2(10, 13)], RED)
			crown(ci, c + Vector2(0, -15), 0.35)
			badge(ci, c, "X2", PURPLE)
		"supercharger":
			ci.draw_circle(c + Vector2(0, -4), 25, Color(PURPLE, 0.2))
			ci.draw_arc(c + Vector2(0, -4), 25, 0, TAU, 40, PURPLE, 2.5, true)
			poly(ci, c + Vector2(0, -4), BOLT, Color("ffd23f"), 0.9)
			badge(ci, c, "X1.5", PURPLE)
		"getaway":
			ci.draw_circle(c + Vector2(0, -6), 12, CREAM)
			ci.draw_rect(Rect2(c + Vector2(-7, 2), Vector2(14, 8)), CREAM)
			ci.draw_circle(c + Vector2(-4.5, -7), 3.5, INK)
			ci.draw_circle(c + Vector2(4.5, -7), 3.5, INK)
			for x in [-4, 0, 4]:
				ci.draw_line(c + Vector2(x, 4), c + Vector2(x, 10), INK, 1.5)
			ci.draw_arc(c + Vector2(0, -4), 22, 0, TAU, 40, RED, 2.5, true)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				ci.draw_line(c + Vector2(0, -4) + d * 16, c + Vector2(0, -4) + d * 28, RED, 2.5)
			badge(ci, c, "+X", PURPLE)
		"gas_station":
			for i in 4:
				var p := c + Vector2(-6 + (i % 2) * 2, 12 - i * 7)
				ci.draw_set_transform(p, 0.0, Vector2(1, 0.45))
				ci.draw_circle(Vector2.ZERO, 16, GOLD.darkened(0.3))
				ci.draw_circle(Vector2(0, -3), 16, GOLD)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			text(ci, c + Vector2(-5, -10), "$", 14, Color("8a5a00"))
			sparkle(ci, c + Vector2(18, -18), 6, Color("fff3a0"))
			badge(ci, c, "$4", GOLD)
		"street_cred":
			mini_card(ci, c + Vector2(-16, -2), "8", 0, 20, -0.15)
			ci.draw_line(c + Vector2(-24, -12), c + Vector2(-8, 8), RED, 3.0, true)
			ci.draw_line(c + Vector2(-8, -12), c + Vector2(-24, 8), RED, 3.0, true)
			arrow(ci, c + Vector2(-3, -2), c + Vector2(8, -2), Color.WHITE, 2.5)
			coin(ci, c + Vector2(20, -2), 10)
			badge(ci, c, "$1", GOLD)
		"pit_crew":
			var glove := Color("e8eef8")
			ci.draw_style_box(Data.box(glove, 6), Rect2(c + Vector2(-12, -6), Vector2(24, 24)))
			for i in 4:
				ci.draw_style_box(Data.box(glove, 4), Rect2(c + Vector2(-12 + i * 6.5, -26 + absf(i - 1.5) * 3), Vector2(5.5, 22)))
			poly(ci, c, [Vector2(-12, 2), Vector2(-22, -8), Vector2(-18, -12), Vector2(-10, -4)], glove)
			ci.draw_line(c + Vector2(-12, 12), c + Vector2(12, 12), BLUE, 3.0)
			badge(ci, c, "+1", BLUE)
		"tow_truck":
			mini_card(ci, c + Vector2(-10, 4), "4", 2, 22, -0.3)
			ci.draw_arc(c + Vector2(0, 0), 22, -2.6, -0.5, 20, RED, 3.0, true)
			var tip2 := c + Vector2.from_angle(-0.5) * 22
			ci.draw_colored_polygon(PackedVector2Array([tip2 + Vector2(-4, -6), tip2 + Vector2(6, -1), tip2 + Vector2(-5, 5)]), RED)
			badge(ci, c, "+1", RED)
		"big_trunk":
			mini_card(ci, c + Vector2(-10, -14), "A", 0, 16, -0.4)
			mini_card(ci, c + Vector2(0, -18), "K", 2, 16, 0.0)
			mini_card(ci, c + Vector2(10, -14), "Q", 1, 16, 0.4)
			ci.draw_style_box(Data.box(Color("8a5a2b"), 4, Color("5a3a1a"), 2, 0), Rect2(c + Vector2(-24, -6), Vector2(48, 24)))
			ci.draw_rect(Rect2(c + Vector2(-24, 2), Vector2(48, 4)), Color("c9a227"))
			ci.draw_rect(Rect2(c + Vector2(-3, -2), Vector2(6, 9)), Color("c9a227"))
			badge(ci, c, "+1", GREEN)


# ---------------------------------------------------------------- garage items

## Picture of a garage item (Dyno Tune / Workshop card), centered at c (about 76 x 56).
static func item_art(ci: Control, d: Dictionary, c: Vector2) -> void:
	if not Data.classic_art and _item_art_car(ci, d, c):
		return
	if Data.who_art and _item_art_who(ci, d, c):
		return
	match d.id:
		"tune":
			var ex: Array = Data.HAND_EXAMPLES[d.hand]
			var cards := []
			for e in ex:
				cards.append([rank_text(e[0]), e[1]])
			var w := 13.0 if cards.size() == 5 else 15.0
			row(ci, c + Vector2(0, 8), cards, w, 1.5)
			arrow(ci, c + Vector2(0, -8), c + Vector2(0, -26), GREEN, 4.0)
		"enh":
			var info: Array = {"nitro": [Color("e1f0ff"), BLUE, "+30"], "turbo": [Color("ffe4de"), RED, "+4"],
				"carbon": [Color(0.85, 0.95, 1.0, 0.85), Color("9fd8ff"), "X2"], "gold": [Color("f7d774"), GOLD, "$2"]}[d.enh]
			ci.draw_circle(c + Vector2(-6, 0), 24, Color(info[1], 0.25))
			mini_card(ci, c + Vector2(-6, 0), "K", 0, 28, -0.1, info[0])
			if d.enh == "carbon":
				ci.draw_line(c + Vector2(-16, 14), c + Vector2(2, -16), Color.WHITE, 2.0)
				ci.draw_line(c + Vector2(-8, 16), c + Vector2(8, -10), Color.WHITE, 1.5)
			text(ci, c + Vector2(20, 12), info[2], 13, info[1].lightened(0.2), 3)
			sparkle(ci, c + Vector2(20, -16), 7, Color("fff3a0"))
		"respray":
			var target: int = d.suit
			mini_card(ci, c + Vector2(-20, 2), "7", (target + 1) % 4, 22, -0.1)
			ci.draw_arc(c + Vector2(0, 6), 16, -2.8, -0.4, 16, Color.WHITE, 2.5, true)
			var tip := c + Vector2(0, 6) + Vector2.from_angle(-0.4) * 16
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-5, -5), tip + Vector2(5, 0), tip + Vector2(-3, 5)]), Color.WHITE)
			ci.draw_circle(c + Vector2(20, 2), 14, Color(1, 1, 1, 0.15))
			emblem(ci, c + Vector2(20, 2), 11, target, Data.suit_color(target).lightened(0.2))
		"scrap":
			ci.draw_set_transform(c + Vector2(-8, 0), -0.2, Vector2.ONE)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-12, -18), Vector2(2, -18), Vector2(-2, -8), Vector2(3, 2), Vector2(-1, 10), Vector2(2, 18), Vector2(-12, 18)]), CREAM)
			ci.draw_set_transform(c + Vector2(10, 2), 0.25, Vector2.ONE)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-1, -18), Vector2(12, -18), Vector2(12, 18), Vector2(-2, 18), Vector2(1, 10), Vector2(-3, 2), Vector2(1, -8)]), CREAM)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in [Vector2(0, -22), Vector2(4, 20), Vector2(-2, 24)]:
				ci.draw_rect(Rect2(c + p, Vector2(3, 3)), CREAM)
			sparkle(ci, c + Vector2(1, -2), 8, RED)
		"clone":
			mini_card(ci, c + Vector2(-10, 2), "9", 3, 24, -0.12)
			mini_card(ci, c + Vector2(6, -2), "9", 3, 24, 0.12)
			ci.draw_circle(c + Vector2(22, 14), 8, GREEN)
			ci.draw_line(c + Vector2(17, 14), c + Vector2(27, 14), Color.WHITE, 3.0)
			ci.draw_line(c + Vector2(22, 9), c + Vector2(22, 19), Color.WHITE, 3.0)
		"swap":
			mini_card(ci, c + Vector2(-20, 6), "7", 1, 20)
			arrow(ci, c + Vector2(-6, 6), c + Vector2(6, -8), GREEN, 3.0)
			mini_card(ci, c + Vector2(20, -2), "8", 1, 24)
		"cash":
			coin(ci, c + Vector2(-10, 2), 13)
			coin(ci, c + Vector2(8, -4), 13)
			text(ci, c + Vector2(22, 14), "X2", 14, GOLD, 3)


# ---------------------------------------------------------------- bosses

## Picture of a boss race, centered at c; s scales the ~60 px design.
static func boss_art(ci: Control, b: Dictionary, c: Vector2, s := 1.0) -> void:
	if b.id == "full_load":  # mini cards set their own transform, so draw them in absolute coordinates
		fan(ci, c + Vector2(0, -6) * s, [["5", 0], ["5", 1], ["5", 2], ["5", 3], ["5", 0]], 14 * s, 0.3, 20 * s)
		return
	ci.draw_set_transform(c, 0.0, Vector2(s, s))
	var o := Vector2.ZERO
	match b.id:
		"ban":
			emblem(ci, o, 15, b.suit, Data.suit_color(b.suit).lightened(0.3))
			no_sign(ci, o, 22)
		"roadblock":
			crown(ci, o + Vector2(0, 2), 0.9)
			no_sign(ci, o, 22)
		"toll":
			ci.draw_rect(Rect2(o + Vector2(-20, -8), Vector2(6, 30)), Color("8fa3b8"))
			for i in 5:
				ci.draw_rect(Rect2(o + Vector2(-14 + i * 7, -8), Vector2(7, 6)), RED if i % 2 == 0 else Color.WHITE)
			coin(ci, o + Vector2(8, 10), 10, "-$")
		"rain":
			for p in [[Vector2(-10, -6), 9.0], [Vector2(2, -11), 11.0], [Vector2(13, -5), 8.0]]:
				ci.draw_circle(o + p[0], p[1], Color("c9d3e0"))
			ci.draw_rect(Rect2(o + Vector2(-18, -6), Vector2(38, 9)), Color("c9d3e0"))
			for x in [-12, -2, 8, 16]:
				ci.draw_line(o + Vector2(x, 8), o + Vector2(x - 4, 20), Color("4aa3ff"), 2.5, true)
		"flat_tire":
			ci.draw_set_transform(c + Vector2(0, 4) * s, 0.0, Vector2(s, s * 0.72))
			ci.draw_circle(Vector2.ZERO, 20, Color("17171b"))
			ci.draw_circle(Vector2.ZERO, 9, Color("c9ccd1"))
			ci.draw_set_transform(c, 0.0, Vector2(s, s))
			ci.draw_rect(Rect2(o + Vector2(-22, 16), Vector2(44, 4)), Color("55585e"))
			text(ci, o + Vector2(18, -14), "-1", 13, RED, 3)
		"time_trial":
			ci.draw_rect(Rect2(o + Vector2(-4, -26), Vector2(8, 6)), Color("8fa3b8"))
			ci.draw_circle(o, 20, Color("8fa3b8"))
			ci.draw_circle(o, 16, Color.WHITE)
			for i in 12:
				var d := Vector2.from_angle(i * TAU / 12)
				ci.draw_line(o + d * 13, o + d * 15, INK, 1.5)
			ci.draw_line(o, o + Vector2.from_angle(-1.2) * 12, RED, 2.5, true)
			ci.draw_circle(o, 2, INK)
		"tunnel":
			ci.draw_circle(o + Vector2(0, 2), 22, Color("6b5e52"))
			ci.draw_rect(Rect2(o + Vector2(-22, 2), Vector2(44, 18)), Color("6b5e52"))
			ci.draw_circle(o + Vector2(0, 4), 14, Color("0b0d10"))
			ci.draw_rect(Rect2(o + Vector2(-14, 4), Vector2(28, 16)), Color("0b0d10"))
			text(ci, o + Vector2(0, 8), "1/2", 12, GOLD)
		"rival":
			text(ci, o + Vector2(-8, -2), "V", 26, BLUE.lightened(0.2), 4)
			text(ci, o + Vector2(9, 4), "S", 26, RED, 4)
		"grand_prix":
			poly(ci, o, [Vector2(-14, -20), Vector2(14, -20), Vector2(11, -4), Vector2(4, 4), Vector2(-4, 4), Vector2(-11, -4)], GOLD)
			ci.draw_arc(o + Vector2(-14, -12), 7, PI / 2, PI * 1.5, 12, GOLD, 3.0, true)
			ci.draw_arc(o + Vector2(14, -12), 7, -PI / 2, PI / 2, 12, GOLD, 3.0, true)
			ci.draw_rect(Rect2(o + Vector2(-3, 4), Vector2(6, 8)), GOLD.darkened(0.2))
			ci.draw_rect(Rect2(o + Vector2(-11, 12), Vector2(22, 6)), GOLD.darkened(0.35))
			sparkle(ci, o + Vector2(0, -12), 5, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- car pictures

## Car silhouette in local coordinates (no transform change), w = half length.
static func _car_shape(ci: Control, c: Vector2, w: float, col: Color, suit := 0) -> void:
	var body := PackedVector2Array()
	for p in Data.CAR_BODIES[suit]:
		body.append(c + p * w)
	ci.draw_colored_polygon(body, col)
	var win := PackedVector2Array()
	for p in Data.CAR_WINDOWS[suit]:
		win.append(c + p * w)
	ci.draw_colored_polygon(win, Color("bfe3ff"))
	var wr := (0.27 if suit == 3 else 0.21) * w
	for x in [-0.6, 0.6]:
		ci.draw_circle(c + Vector2(x, 0.2) * w, wr, Color("17171b"))
		ci.draw_circle(c + Vector2(x, 0.2) * w, wr * 0.5, Color("c9ccd1"))


static func car_side(ci: Control, c: Vector2, w: float, col: Color, suit := 0, rot := 0.0) -> void:
	ci.draw_set_transform(c, rot, Vector2.ONE)
	_car_shape(ci, Vector2.ZERO, w, col, suit)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func tire(ci: Control, c: Vector2, r: float, knobby := false, rim := Color("c9ccd1")) -> void:
	if knobby:
		for i in 12:
			var d := Vector2.from_angle(i * TAU / 12)
			ci.draw_circle(c + d * r * 0.95, r * 0.2, Color("2a2a2e"))
	ci.draw_circle(c, r, Color("17171b"))
	ci.draw_arc(c, r * 0.82, 0, TAU, 32, Color("2e2e34"), r * 0.12, true)
	ci.draw_circle(c, r * 0.5, rim)
	ci.draw_circle(c, r * 0.18, Color("55585e"))


static func turbo(ci: Control, c: Vector2, r: float) -> void:
	ci.draw_rect(Rect2(c + Vector2(r * 0.4, -r * 1.05), Vector2(r * 0.9, r * 0.6)), Color("9aa3ad"))
	ci.draw_circle(c, r, Color("aab4c3"))
	ci.draw_arc(c, r * 0.65, 0.3, TAU - 0.3, 24, Color("5f6a7a"), 2.0, true)
	ci.draw_arc(c, r * 0.35, 0.8, TAU + 0.4, 16, Color("5f6a7a"), 2.0, true)
	ci.draw_circle(c, r * 0.15, Color("3a3f4b"))


static func gauge(ci: Control, c: Vector2, r: float, needle: float, red_zone := false) -> void:
	ci.draw_circle(c, r, Color("1b1f27"))
	ci.draw_arc(c, r, 0, TAU, 32, Color("8fa3b8"), 2.0, true)
	ci.draw_arc(c, r * 0.8, PI * 0.75, PI * 2.25, 24, Color(1, 1, 1, 0.6), 2.0, true)
	if red_zone:
		ci.draw_arc(c, r * 0.8, PI * 1.85, PI * 2.25, 10, RED, 3.0, true)
	for i in 7:
		var d := Vector2.from_angle(PI * 0.75 + i * PI * 0.25)
		ci.draw_line(c + d * r * 0.62, c + d * r * 0.78, Color.WHITE, 1.5)
	ci.draw_line(c, c + Vector2.from_angle(needle) * r * 0.75, RED, 2.5, true)
	ci.draw_circle(c, r * 0.12, RED)


static func checker_flag(ci: Control, c: Vector2, size := 1.0) -> void:
	ci.draw_line(c + Vector2(-16, 26) * size, c + Vector2(-16, -26) * size, Color("8fa3b8"), 3.0 * size)
	for gy in 4:
		for gx in 5:
			var p := c + Vector2(-15 + gx * 7, -26 + gy * 7 + sin(gx * 0.9) * 2) * size
			ci.draw_rect(Rect2(p, Vector2(7, 7) * size), INK if (gx + gy) % 2 == 0 else Color.WHITE)


static func engine_block(ci: Control, c: Vector2, label := "V8") -> void:
	for side in [-1, 1]:
		for i in 4:
			ci.draw_set_transform(c + Vector2(side * (6 + i * 1.5), -14 + i * 2.5), side * 0.5, Vector2.ONE)
			ci.draw_rect(Rect2(-4, -9, 8, 9), Color("aab4c3"))
			ci.draw_rect(Rect2(-4, -11, 8, 3), Color("5f6a7a"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_style_box(Data.box(Color("6b7686"), 4, Color("3a3f4b"), 2, 0), Rect2(c + Vector2(-18, -8), Vector2(36, 22)))
	text(ci, c + Vector2(0, 3), label, 13, Color.WHITE)


static func bottle(ci: Control, c: Vector2, rot := -0.35) -> void:
	ci.draw_set_transform(c, rot, Vector2.ONE)
	ci.draw_style_box(Data.box(Color("2f6fd6"), 7, Color("1d3f80"), 2, 0), Rect2(-8, -18, 16, 36))
	ci.draw_rect(Rect2(-8, -4, 16, 8), RED)
	ci.draw_rect(Rect2(-3, -24, 6, 6), Color("aab4c3"))
	ci.draw_rect(Rect2(-6, -27, 12, 3), Color("5f6a7a"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func helmet(ci: Control, c: Vector2, col: Color, letter := "A") -> void:
	ci.draw_circle(c, 19, col)
	ci.draw_rect(Rect2(c + Vector2(-19, 0), Vector2(30, 13)), col)
	ci.draw_style_box(Data.box(Color("1b1f27"), 5), Rect2(c + Vector2(-2, -8), Vector2(22, 11)))
	ci.draw_line(c + Vector2(-17, 6), c + Vector2(10, 6), Color.WHITE, 2.5)
	text(ci, c + Vector2(-9, -6), letter, 14, Color.WHITE, 2)


static func shifter(ci: Control, c: Vector2, lit: Array) -> void:
	var pos := {1: Vector2(-16, -18), 2: Vector2(-16, 14), 3: Vector2(0, -18), 4: Vector2(0, 14), 5: Vector2(16, -18), 6: Vector2(16, 14)}
	ci.draw_line(c + Vector2(-16, -2), c + Vector2(16, -2), Color("8fa3b8"), 3.0)
	for x in [-16, 0, 16]:
		ci.draw_line(c + Vector2(x, -18), c + Vector2(x, 14), Color("8fa3b8"), 3.0)
	for g in pos:
		var on: bool = lit.has(g)
		ci.draw_circle(c + pos[g], 7, GREEN if on else Color("3a3f4b"))
		text(ci, c + pos[g], str(g), 10, Color.WHITE)


static func jester(ci: Control, c: Vector2, s := 1.0) -> void:
	poly(ci, c, [Vector2(-18, 12), Vector2(-20, -14), Vector2(-6, 2), Vector2(0, -20), Vector2(6, 2), Vector2(20, -14), Vector2(18, 12)], PURPLE, s)
	poly(ci, c, [Vector2(-18, 12), Vector2(-6, 2), Vector2(0, 12)], RED, s)
	poly(ci, c, [Vector2(18, 12), Vector2(6, 2), Vector2(0, 12)], GREEN, s)
	for p in [Vector2(-20, -16), Vector2(0, -22), Vector2(20, -16)]:
		ci.draw_circle(c + p * s, 4 * s, GOLD)
	ci.draw_rect(Rect2(c + Vector2(-20, 12) * s, Vector2(40, 6) * s), GOLD.darkened(0.2))


static func chip_stack(ci: Control, c: Vector2, n: int) -> void:
	for i in n:
		var p := c + Vector2(0, -i * 7)
		ci.draw_set_transform(p, 0.0, Vector2(1, 0.45))
		ci.draw_circle(Vector2.ZERO, 16, RED.darkened(0.3))
		ci.draw_circle(Vector2(0, -3), 16, RED)
		ci.draw_arc(Vector2(0, -3), 11, 0, TAU, 16, Color.WHITE, 3.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _mod_art_car(ci: Control, id: String, c: Vector2) -> void:
	match id:
		"nitro":
			bottle(ci, c + Vector2(-6, -2))
			flame(ci, c + Vector2(16, 6), 0.55, BLUE.lightened(0.2))
			badge(ci, c, "+4", RED)
		"v8":
			engine_block(ci, c + Vector2(0, 0), "V8")
			badge(ci, c, "+3", RED)
		"rising_sun":
			for i in 12:
				var a := i * TAU / 12
				poly(ci, c + Vector2(0, -4), [Vector2.ZERO, Vector2.from_angle(a - 0.13) * 30, Vector2.from_angle(a + 0.13) * 30], RED if i % 2 == 0 else Color.WHITE)
			ci.draw_circle(c + Vector2(0, -4), 11, RED)
			badge(ci, c, "+3", RED)
		"autobahn":
			poly(ci, c, [Vector2(-32, 18), Vector2(32, 18), Vector2(6, -18), Vector2(-6, -18)], Color("3a3f4b"))
			for i in 4:
				var y := -14.0 + i * 9
				ci.draw_line(c + Vector2(0, y), c + Vector2(0, y + 4 + i), Color.WHITE, 1.5 + i * 0.6)
			ci.draw_style_box(Data.box(Color("2a4d8f"), 3, Color.WHITE, 2, 0), Rect2(c + Vector2(10, -30), Vector2(22, 16)))
			text(ci, c + Vector2(21, -22), "A", 12, Color.WHITE)
			badge(ci, c, "+3", RED)
		"mud_tires":
			tire(ci, c + Vector2(-2, -4), 20, true)
			for p in [Vector2(-22, 12), Vector2(18, -18), Vector2(20, 10), Vector2(-20, -20)]:
				ci.draw_circle(c + p, 4, Color("7a4a1d"))
			badge(ci, c, "+3", RED)
		"twin_turbo":
			turbo(ci, c + Vector2(-13, -2), 12)
			turbo(ci, c + Vector2(13, -2), 12)
			badge(ci, c, "+8", RED)
		"wide_body":
			car_side(ci, c + Vector2(0, 2), 30, Color("e2443a"), 2)
			for x in [-18, 18]:
				ci.draw_arc(c + Vector2(x, 9), 10, PI, TAU, 12, Color("ffd23f"), 2.5, true)
			chip(ci, c + Vector2(22, -22), 8)
			badge(ci, c, "+50", BLUE)
		"convoy_leader":
			for i in 3:
				car_side(ci, c + Vector2(-22 + i * 22, 4 - i * 3), 12 - i, [Color("e2443a"), Color("f08a24"), Color("3b6fd6")][i], 3)
			badge(ci, c, "+12", RED)
		"drift_king":
			for p in [[Vector2(-22, 8), 9.0], [Vector2(-28, -2), 7.0], [Vector2(-16, 14), 6.0]]:
				ci.draw_circle(c + p[0], p[1], Color(0.85, 0.85, 0.9, 0.7))
			ci.draw_arc(c + Vector2(0, 30), 30, PI * 1.15, PI * 1.6, 12, Color("2b2f38"), 3.0)
			car_side(ci, c + Vector2(6, -4), 22, Color("f08a24"), 1, 0.35)
			badge(ci, c, "+12", RED)
		"brand_loyalty":
			poly(ci, c, [Vector2(-28, -6), Vector2(0, -28), Vector2(28, -6)], Color("8a5a2b"))
			ci.draw_rect(Rect2(c + Vector2(-24, -6), Vector2(48, 26)), Color("c9b48a"))
			ci.draw_rect(Rect2(c + Vector2(-18, 0), Vector2(36, 20)), Color("2b2f38"))
			car_side(ci, c + Vector2(0, 12), 14, Color("3b6fd6"), 2)
			emblem(ci, c + Vector2(0, -15), 5, 2, Color.WHITE)
			badge(ci, c, "+10", RED)
		"lightweight":
			car_side(ci, c + Vector2(-2, 8), 24, Color("3ecf6a"), 2)
			poly(ci, c, [Vector2(-8, -12), Vector2(0, -22), Vector2(14, -28), Vector2(8, -18), Vector2(-2, -10)], Color("eef3ff"))
			ci.draw_line(c + Vector2(-10, -10), c + Vector2(14, -28), Color("9aa8c0"), 1.5)
			badge(ci, c, "+20", RED)
		"odometer":
			gauge(ci, c + Vector2(0, -8), 22, PI * 1.5)
			ci.draw_style_box(Data.box(INK, 2, Color("8fa3b8"), 1, 0), Rect2(c + Vector2(-14, 2), Vector2(28, 10)))
			text(ci, c + Vector2(0, 7), "0427", 9, Color.WHITE)
			badge(ci, c, "+1", RED)
		"chrome_bumper":
			ci.draw_style_box(Data.box(Color("aab4c3"), 6, Color("5f6a7a"), 2, 0), Rect2(c + Vector2(-32, 0), Vector2(64, 14)))
			ci.draw_rect(Rect2(c + Vector2(-28, 2), Vector2(56, 3)), Color(1, 1, 1, 0.8))
			for x in [-20, 20]:
				ci.draw_circle(c + Vector2(x, 9), 2.5, Color("3a3f4b"))
			crown(ci, c + Vector2(0, -14), 0.9)
			badge(ci, c, "+30", BLUE)
		"ace_driver":
			helmet(ci, c + Vector2(-2, -2), Color("e2443a"), "A")
			badge(ci, c, "+4", RED)
		"even_gears":
			shifter(ci, c + Vector2(-2, 0), [2, 4, 6])
			badge(ci, c, "+4", RED)
		"odd_gears":
			shifter(ci, c + Vector2(-2, 0), [1, 3, 5])
			badge(ci, c, "+31", BLUE)
		"car_show":
			for x in [-26, 26]:
				poly(ci, c, [Vector2(x * 0.9, -32), Vector2(x * 0.9 + 4, -32), Vector2(4, 12), Vector2(-4, 12)], Color(1, 0.95, 0.6, 0.22))
			ci.draw_set_transform(c + Vector2(0, 14), 0.0, Vector2(1, 0.3))
			ci.draw_circle(Vector2.ZERO, 30, Color("5f6a7a"))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			car_side(ci, c + Vector2(0, 4), 24, Color("c13cff"), 2)
			badge(ci, c, "+4", RED)
		"scrap_collector":
			ci.draw_line(c + Vector2(0, -32), c + Vector2(0, -18), Color("8fa3b8"), 2.0)
			ci.draw_rect(Rect2(c + Vector2(-12, -20), Vector2(24, 6)), RED)
			poly(ci, c, [Vector2(-16, -10), Vector2(14, -12), Vector2(18, 14), Vector2(-14, 16)], Color("b5541a"))
			for i in 4:
				ci.draw_line(c + Vector2(-14, -6 + i * 6), c + Vector2(16, -8 + i * 6 + (i % 2) * 3), Color("6b2f12"), 2.0)
			badge(ci, c, "+3", RED)
		"rev_limiter":
			gauge(ci, c + Vector2(0, -2), 26, PI * 2.15, true)
			badge(ci, c, "+2", ORANGE)
		"echo_exhaust":
			ci.draw_rect(Rect2(c + Vector2(-32, -6), Vector2(26, 10)), Color("8fa3b8"))
			ci.draw_rect(Rect2(c + Vector2(-8, -9), Vector2(8, 16)), Color("aab4c3"))
			for i in 3:
				ci.draw_arc(c + Vector2(2, -1), 8.0 + i * 7, -0.8, 0.8, 12, ORANGE.lightened(i * 0.15), 3.0, true)
			badge(ci, c, "2-5", ORANGE)
		"launch_control":
			ci.draw_style_box(Data.box(INK, 5, Color("55585e"), 2, 0), Rect2(c + Vector2(-10, -30), Vector2(20, 50)))
			ci.draw_circle(c + Vector2(0, -20), 6, Color(RED, 0.3))
			ci.draw_circle(c + Vector2(0, -5), 6, Color(GOLD, 0.3))
			ci.draw_circle(c + Vector2(0, 10), 9, Color(GREEN, 0.35))
			ci.draw_circle(c + Vector2(0, 10), 6, GREEN)
			text(ci, c + Vector2(-22, -6), "1", 18, Color.WHITE, 3)
			badge(ci, c, "X2", PURPLE)
		"final_lap":
			checker_flag(ci, c + Vector2(2, -2))
			badge(ci, c, "X3", PURPLE)
		"photo_finish":
			for gy in 8:
				ci.draw_rect(Rect2(c + Vector2(4, -30 + gy * 7), Vector2(5, 7)), INK if gy % 2 == 0 else Color.WHITE)
				ci.draw_rect(Rect2(c + Vector2(9, -30 + gy * 7), Vector2(5, 7)), Color.WHITE if gy % 2 == 0 else INK)
			car_side(ci, c + Vector2(-8, 8), 18, Color("e2443a"), 2)
			sparkle(ci, c + Vector2(22, -20), 8, Color("fff3a0"))
			badge(ci, c, "X2", PURPLE)
		"supercharger":
			ci.draw_rect(Rect2(c + Vector2(-20, -6), Vector2(40, 20)), Color("6b7686"))
			for i in 6:
				ci.draw_rect(Rect2(c + Vector2(-18 + i * 7, -14), Vector2(4, 8)), Color("aab4c3"))
			ci.draw_circle(c + Vector2(-24, 4), 8, Color("3a3f4b"))
			ci.draw_circle(c + Vector2(-24, 4), 3, Color("aab4c3"))
			poly(ci, c + Vector2(12, -18), BOLT, Color("ffd23f"), 0.5)
			badge(ci, c, "X1.5", PURPLE)
		"getaway":
			for i in 3:
				ci.draw_line(c + Vector2(-34, -2 + i * 6), c + Vector2(-20, -2 + i * 6), Color(1, 1, 1, 0.5), 2.0)
			car_side(ci, c + Vector2(2, 6), 22, Color("1b1f27"), 0)
			ci.draw_circle(c + Vector2(4, -14), 7, Color("c9a227"))
			text(ci, c + Vector2(4, -14), "$", 9, Color("5a3a1a"))
			badge(ci, c, "+X", PURPLE)
		"gas_station":
			ci.draw_style_box(Data.box(RED, 4, RED.darkened(0.4), 2, 0), Rect2(c + Vector2(-16, -26), Vector2(24, 44)))
			ci.draw_rect(Rect2(c + Vector2(-12, -21), Vector2(16, 10)), Color("bfe3ff"))
			ci.draw_arc(c + Vector2(12, -4), 8, -PI / 2, PI / 2, 10, INK, 3.0)
			ci.draw_rect(Rect2(c + Vector2(10, 2), Vector2(8, 4)), INK)
			badge(ci, c, "$4", GOLD)
		"street_cred":
			ci.draw_set_transform(c + Vector2(-10, 0), -0.4, Vector2.ONE)
			ci.draw_style_box(Data.box(Color("3ecf6a"), 4), Rect2(-7, -14, 14, 28))
			ci.draw_rect(Rect2(-3, -19, 6, 5), Color("aab4c3"))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in [Vector2(2, -22), Vector2(6, -18), Vector2(0, -16)]:
				ci.draw_circle(c + p, 2.5, Color(GREEN, 0.6))
			coin(ci, c + Vector2(16, -2), 10)
			badge(ci, c, "$1", GOLD)
		"pit_crew":
			tire(ci, c + Vector2(-2, -2), 18)
			ci.draw_line(c + Vector2(-20, -20), c + Vector2(16, 16), Color("aab4c3"), 4.0, true)
			ci.draw_line(c + Vector2(16, -20), c + Vector2(-20, 16), Color("aab4c3"), 4.0, true)
			badge(ci, c, "+1", BLUE)
		"tow_truck":
			ci.draw_line(c + Vector2(0, -32), c + Vector2(0, -8), Color("8fa3b8"), 2.0)
			ci.draw_arc(c + Vector2(4, -2), 7, PI * 0.1, PI * 1.1, 10, Color("ffd23f"), 4.0)
			mini_card(ci, c + Vector2(10, 12), "4", 2, 18, 0.3)
			badge(ci, c, "+1", RED)
		"big_trunk":
			car_side(ci, c + Vector2(4, 8), 24, Color("3b6fd6"), 0)
			mini_card(ci, c + Vector2(-16, -12), "A", 0, 14, -0.5)
			mini_card(ci, c + Vector2(-8, -16), "K", 2, 14, -0.2)
			poly(ci, c, [Vector2(-26, -2), Vector2(-30, -16), Vector2(-24, -18), Vector2(-18, -2)], Color("3b6fd6").darkened(0.2))
			badge(ci, c, "+1", GREEN)


## Car pictures for some garage items; returns false to use the default picture.
static func _item_art_car(ci: Control, d: Dictionary, c: Vector2) -> bool:
	match d.id:
		"enh":
			mini_card(ci, c + Vector2(-10, 2), "K", 0, 26, -0.1, {"nitro": Color("e1f0ff"), "turbo": Color("ffe4de"), "carbon": Color("2a2d34"), "gold": Color("f7d774")}[d.enh])
			match d.enh:
				"nitro": bottle(ci, c + Vector2(18, -4), 0.3)
				"turbo": turbo(ci, c + Vector2(18, -4), 11)
				"carbon":
					for gy in 4:
						for gx in 4:
							ci.draw_rect(Rect2(c + Vector2(8 + gx * 5, -16 + gy * 5), Vector2(5, 5)), Color("1b1d22") if (gx + gy) % 2 == 0 else Color("4a4f5a"))
				"gold": tire(ci, c + Vector2(18, -4), 11, false, GOLD)
		"respray":
			ci.draw_set_transform(c + Vector2(-16, 2), -0.3, Vector2.ONE)
			ci.draw_style_box(Data.box(Data.suit_color(d.suit), 4, Color.WHITE, 1, 0), Rect2(-8, -16, 16, 30))
			ci.draw_rect(Rect2(-3, -21, 6, 5), Color("aab4c3"))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for i in 6:
				ci.draw_circle(c + Vector2(-2 + i * 3, -16 + (i % 3) * 3), 2.5, Color(Data.suit_color(d.suit), 0.7))
			car_side(ci, c + Vector2(16, 8), 15, Data.suit_color(d.suit), d.suit if not Data.classic_suits else 0)
		"scrap":
			ci.draw_rect(Rect2(c + Vector2(-30, -24), Vector2(60, 6)), Color("5f6a7a"))
			ci.draw_rect(Rect2(c + Vector2(-30, 16), Vector2(60, 6)), Color("5f6a7a"))
			poly(ci, c, [Vector2(-18, -16), Vector2(16, -14), Vector2(20, 14), Vector2(-16, 14)], Color("e2443a"))
			for i in 3:
				ci.draw_line(c + Vector2(-16, -8 + i * 8), c + Vector2(18, -6 + i * 8), Color("8a1c1c"), 2.0)
		"swap":
			engine_block(ci, c + Vector2(-8, 4), "+1")
			arrow(ci, c + Vector2(16, 14), c + Vector2(16, -22), GREEN, 4.0)
		_:
			return false
	return true



static func price_tag(ci: Control, c: Vector2, label: String) -> void:
	poly(ci, c, [Vector2(-22, -12), Vector2(14, -12), Vector2(26, 0), Vector2(14, 12), Vector2(-22, 12)], RED)
	ci.draw_circle(c + Vector2(15, 0), 3, Color("f3e6c4"))
	text(ci, c + Vector2(-5, 0), label, 13, Color.WHITE)


static func piggy(ci: Control, c: Vector2) -> void:
	var pink := Color("f08ab0")
	ci.draw_set_transform(c, 0.0, Vector2(1, 0.8))
	ci.draw_circle(Vector2.ZERO, 18, pink)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_circle(c + Vector2(16, -2), 7, pink.darkened(0.1))
	ci.draw_circle(c + Vector2(18, -2), 1.5, INK)
	poly(ci, c, [Vector2(-6, -14), Vector2(-2, -22), Vector2(2, -13)], pink.darkened(0.1))
	for x in [-10, 8]:
		ci.draw_rect(Rect2(c + Vector2(x, 10), Vector2(5, 7)), pink.darkened(0.15))
	ci.draw_rect(Rect2(c + Vector2(-6, -15), Vector2(10, 2)), INK)
	ci.draw_circle(c + Vector2(6, -5), 1.6, INK)


static func document(ci: Control, c: Vector2) -> void:
	ci.draw_style_box(Data.box(Color.WHITE, 2, Color("8fa3b8"), 1, 0), Rect2(c + Vector2(-14, -18), Vector2(28, 36)))
	for i in 4:
		ci.draw_line(c + Vector2(-9, -11 + i * 6), c + Vector2(9, -11 + i * 6), Color("aab4c3"), 1.5)
	ci.draw_line(c + Vector2(-8, 12), c + Vector2(0, 10), Color("2f6fd6"), 1.5)
	ci.draw_line(c + Vector2(0, 10), c + Vector2(8, 13), Color("2f6fd6"), 1.5)


## Picture of a voucher (sponsor deal) centered at c, drawn on a light coupon.
static func voucher_art(ci: Control, id: String, c: Vector2) -> void:
	if Data.who_art and _voucher_art_who(ci, id, c):
		return
	var classic := Data.classic_art
	match id:
		"clearance":
			price_tag(ci, c, "-25%")
		"reroll_surplus":
			if classic:
				ci.draw_arc(c, 18, 0.3, PI * 1.6, 20, Color("2f8f83"), 4.0, true)
				ci.draw_arc(c, 18, PI + 0.3, PI * 2.6, 20, Color("2f8f83"), 4.0, true)
				text(ci, c, "$", 18, Color("8a5a00"))
			else:
				car_side(ci, c + Vector2(0, 8), 22, Color("3b6fd6"), 2)
				for p in [Vector2(-16, -14), Vector2(-4, -20), Vector2(10, -16), Vector2(20, -8)]:
					ci.draw_arc(c + p, 5, 0, TAU, 12, Color("4aa3ff"), 2.0, true)
		"crystal_ball":
			if classic:
				ci.draw_circle(c + Vector2(0, -4), 18, Color("8ec5ff"))
				ci.draw_circle(c + Vector2(-6, -10), 5, Color(1, 1, 1, 0.7))
				ci.draw_rect(Rect2(c + Vector2(-12, 12), Vector2(24, 6)), Color("8a5a2b"))
			else:
				ci.draw_style_box(Data.box(Color("3a3f4b"), 4, INK, 2, 0), Rect2(c + Vector2(-24, -6), Vector2(48, 22)))
				poly(ci, c, [Vector2(-24, -6), Vector2(24, -6), Vector2(20, -18), Vector2(-20, -18)], Color("5f6a7a"))
				mini_card(ci, c + Vector2(0, -8), "+1", 1, 16)
		"antimatter":
			if classic:
				ci.draw_circle(c, 18, INK)
				ci.draw_arc(c, 20, 0, TAU, 32, PURPLE, 3.0, true)
				text(ci, c, "+1", 14, Color.WHITE)
			else:
				car_side(ci, c + Vector2(0, 10), 24, Color("e2443a"), 0)
				ci.draw_rect(Rect2(c + Vector2(-14, -12), Vector2(28, 3)), INK)
				ci.draw_style_box(Data.box(Color("8a5a2b"), 2), Rect2(c + Vector2(-10, -22), Vector2(20, 10)))
				text(ci, c + Vector2(0, -17), "+1", 9, Color.WHITE)
		"grabber":
			if classic:
				var glove := Color("e8eef8")
				ci.draw_style_box(Data.box(glove, 6, Color("8fa3b8"), 1, 0), Rect2(c + Vector2(-12, -4), Vector2(24, 20)))
				for i in 4:
					ci.draw_style_box(Data.box(glove, 3, Color("8fa3b8"), 1, 0), Rect2(c + Vector2(-12 + i * 6.5, -22), Vector2(5.5, 20)))
			else:
				ci.draw_style_box(Data.box(RED, 4, RED.darkened(0.4), 2, 0), Rect2(c + Vector2(-14, -16), Vector2(28, 34)))
				ci.draw_rect(Rect2(c + Vector2(-4, -22), Vector2(8, 6)), Color("5f6a7a"))
				ci.draw_line(c + Vector2(-8, -10), c + Vector2(8, 10), RED.darkened(0.3), 3.0)
				ci.draw_line(c + Vector2(8, -10), c + Vector2(-8, 10), RED.darkened(0.3), 3.0)
			text(ci, c + Vector2(22, 14), "+1", 13, BLUE, 2)
		"wasteful":
			if classic:
				poly(ci, c, [Vector2(-14, -8), Vector2(14, -8), Vector2(11, 18), Vector2(-11, 18)], Color("8a96a8"))
				ci.draw_rect(Rect2(c + Vector2(-17, -13), Vector2(34, 5)), Color("5f6a7a"))
				mini_card(ci, c + Vector2(4, -20), "3", 0, 14, 0.5)
			else:
				tire(ci, c + Vector2(-8, 4), 13)
				tire(ci, c + Vector2(10, -6), 13)
			text(ci, c + Vector2(22, 14), "+1", 13, RED, 2)
		"paint_brush":
			if classic:
				ci.draw_line(c + Vector2(-18, 18), c + Vector2(6, -6), Color("8a5a2b"), 5.0, true)
				poly(ci, c, [Vector2(4, -4), Vector2(14, -18), Vector2(20, -12), Vector2(8, 0)], Color("aab4c3"))
				poly(ci, c, [Vector2(14, -18), Vector2(22, -26), Vector2(26, -20), Vector2(20, -12)], RED)
			else:
				car_side(ci, c + Vector2(-14, 8), 12, Color("3b6fd6"), 0)
				ci.draw_rect(Rect2(c + Vector2(-2, -8), Vector2(28, 18)), Color("aab4c3"))
				ci.draw_line(c + Vector2(-4, 6), c + Vector2(-2, 6), INK, 2.0)
				ci.draw_circle(c + Vector2(12, 12), 4, Color("17171b"))
			text(ci, c + Vector2(-16, -16), "+1", 13, GREEN.darkened(0.2), 2)
		"seed_money":
			piggy(ci, c + Vector2(-2, 0))
			coin(ci, c + Vector2(14, -16), 8, "10")
		"hone":
			if classic:
				ci.draw_style_box(Data.box(Color("8a96a8"), 3, Color("5f6a7a"), 1, 0), Rect2(c + Vector2(-24, 4), Vector2(48, 10)))
				mini_card(ci, c + Vector2(0, -8), "J", 3, 18, -0.2)
			else:
				car_side(ci, c + Vector2(0, 6), 24, Color("c13cff"), 2)
			for p in [Vector2(-18, -16), Vector2(16, -18), Vector2(22, 4)]:
				sparkle(ci, c + p, 6, Color("c13cff"))
		"tune_merchant":
			document(ci, c + Vector2(-8, 0))
			if classic:
				arrow(ci, c + Vector2(16, 14), c + Vector2(16, -16), GREEN, 4.0)
			else:
				gauge(ci, c + Vector2(14, 6), 12, PI * 1.9)
		"workshop_merchant":
			document(ci, c + Vector2(-8, 0))
			if classic:
				sparkle(ci, c + Vector2(16, 0), 12, ORANGE)
			else:
				ci.draw_line(c + Vector2(6, 14), c + Vector2(20, -2), ORANGE, 5.0, true)
				ci.draw_circle(c + Vector2(21, -4), 6, ORANGE)
				ci.draw_circle(c + Vector2(24, -7), 3, Color("f3e6c4"))



# ---------------------------------------------------------------- Doctor Who theme (fan tribute, original drawings)

const TARDIS_BLUE := Color("1f4fa0")
const BRONZE := Color("b5832a")
const STEEL := Color("9aa8b5")
const SONIC_GREEN := Color("5dff8a")


## Suit symbols: TARDIS, Dalek, Cyberman head, Gallifreyan seal.
static func who_suit(ci: Control, c: Vector2, r: float, suit: int, col: Color) -> void:
	var light := col.lightened(0.75)
	match suit:
		0:  # police box
			ci.draw_rect(Rect2(c + Vector2(-0.6, -0.78) * r, Vector2(1.2, 1.78) * r), col)
			ci.draw_rect(Rect2(c + Vector2(-0.72, -0.95) * r, Vector2(1.44, 0.22) * r), col)
			ci.draw_rect(Rect2(c + Vector2(-0.12, -1.18) * r, Vector2(0.24, 0.24) * r), col)
			for x in [-0.42, 0.08]:
				ci.draw_rect(Rect2(c + Vector2(x, -0.6) * r, Vector2(0.32, 0.26) * r), light)
		1:  # dalek
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.78, 1.0) * r, c + Vector2(0.78, 1.0) * r, c + Vector2(0.45, -0.05) * r, c + Vector2(-0.45, -0.05) * r]), col)
			ci.draw_rect(Rect2(c + Vector2(-0.45, -0.38) * r, Vector2(0.9, 0.33) * r), col.darkened(0.25))
			ci.draw_circle(c + Vector2(0, -0.45) * r, 0.42 * r, col)
			ci.draw_line(c + Vector2(0.15, -0.6) * r, c + Vector2(0.85, -0.78) * r, col, maxf(1.5, r * 0.14))
			for p in [Vector2(-0.3, 0.35), Vector2(0.3, 0.35), Vector2(0, 0.7)]:
				ci.draw_circle(c + p * r, 0.11 * r, light)
		2:  # cyberman head
			ci.draw_line(c + Vector2(-0.78, -0.2) * r, c + Vector2(-0.4, -0.85) * r, col, maxf(1.5, r * 0.14))
			ci.draw_line(c + Vector2(0.78, -0.2) * r, c + Vector2(0.4, -0.85) * r, col, maxf(1.5, r * 0.14))
			ci.draw_circle(c + Vector2(-0.78, -0.2) * r, 0.2 * r, col)
			ci.draw_circle(c + Vector2(0.78, -0.2) * r, 0.2 * r, col)
			ci.draw_style_box(Data.box(col, int(maxf(2.0, r * 0.35)), Color(0, 0, 0, 0), 0, 0), Rect2(c + Vector2(-0.55, -0.85) * r, Vector2(1.1, 1.8) * r))
			for x in [-0.24, 0.24]:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - 0.13, -0.3) * r, c + Vector2(x + 0.13, -0.3) * r, c + Vector2(x, 0.05) * r]), light)
			ci.draw_rect(Rect2(c + Vector2(-0.2, 0.35) * r, Vector2(0.4, 0.1) * r), light)
		3:  # gallifreyan seal
			ci.draw_circle(c, r, col)
			ci.draw_arc(c, r * 0.68, 0, TAU, 24, light, maxf(1.0, r * 0.12), true)
			ci.draw_circle(c + Vector2(0, -0.35) * r, 0.16 * r, light)
			ci.draw_circle(c + Vector2(0.3, 0.2) * r, 0.12 * r, light)
			ci.draw_line(c + Vector2(-0.6, 0.4) * r, c + Vector2(0.15, -0.2) * r, light, maxf(1.0, r * 0.1))


static func tardis(ci: Control, c: Vector2, s := 1.0) -> void:
	var col := TARDIS_BLUE
	ci.draw_rect(Rect2(c + Vector2(-14, -20) * s, Vector2(28, 44) * s), col)
	ci.draw_rect(Rect2(c + Vector2(-17, -24) * s, Vector2(34, 5) * s), col.darkened(0.15))
	ci.draw_rect(Rect2(c + Vector2(-13, -19) * s, Vector2(26, 4) * s), Color("101820"))
	ci.draw_rect(Rect2(c + Vector2(-3, -30) * s, Vector2(6, 6) * s), Color("e8f4ff"))
	for x in [-11, 2]:
		for y in [-12, 0, 11]:
			ci.draw_rect(Rect2(c + Vector2(x, y) * s, Vector2(9, 9) * s), col.darkened(0.25))
		ci.draw_rect(Rect2(c + Vector2(x + 1, -12 + 1) * s, Vector2(7, 6) * s), Color("dff0ff"))
	ci.draw_line(c + Vector2(0, -15) * s, c + Vector2(0, 24) * s, col.darkened(0.35), 1.5 * s)


static func sonic(ci: Control, c: Vector2, rot := -0.6, s := 1.0) -> void:
	ci.draw_set_transform(c, rot, Vector2(s, s))
	ci.draw_circle(Vector2(0, -22), 7, Color(SONIC_GREEN, 0.35))
	ci.draw_rect(Rect2(-3, -24, 6, 6), SONIC_GREEN)
	ci.draw_rect(Rect2(-4, -18, 8, 10), Color("8a96a8"))
	ci.draw_rect(Rect2(-3.5, -8, 7, 26), Color("5a3a1a"))
	for y in [-2, 6]:
		ci.draw_rect(Rect2(-4, y, 8, 2), Color("c9a227"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func dalek(ci: Control, c: Vector2, s := 1.0) -> void:
	who_suit(ci, c, 22 * s, 1, BRONZE)


static func hearts2(ci: Control, c: Vector2, s := 1.0) -> void:
	classic_suit(ci, c + Vector2(-9, 0) * s, 11 * s, 0, RED)
	classic_suit(ci, c + Vector2(9, 0) * s, 11 * s, 0, RED.lightened(0.15))


static func clock(ci: Control, c: Vector2, r: float, col := Color("f3e6c4")) -> void:
	ci.draw_circle(c, r, col)
	ci.draw_arc(c, r, 0, TAU, 32, Color("5a3a12"), 2.0, true)
	ci.draw_line(c, c + Vector2(0, -r * 0.7), INK, 2.0)
	ci.draw_line(c, c + Vector2(r * 0.5, 0), INK, 2.0)


static func spiral(ci: Control, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := i * 0.45
		pts.append(c + Vector2.from_angle(a) * r * i / 40.0)
	ci.draw_polyline(pts, col, 2.5, true)


static func regen_glow(ci: Control, c: Vector2, s := 1.0) -> void:
	for i in 10:
		var d := Vector2.from_angle(-PI / 2 + (i - 4.5) * 0.3)
		ci.draw_line(c + d * 14 * s, c + d * 30 * s, Color(GOLD, 0.7), 3.0 * s)
	ci.draw_circle(c + Vector2(0, -10) * s, 7 * s, Color("ffe7a0"))
	poly(ci, c, [Vector2(-10, 18), Vector2(-8, -2), Vector2(8, -2), Vector2(10, 18)], Color("ffd166"), s)


static func _mod_art_who(ci: Control, id: String, c: Vector2) -> void:
	match id:
		"nitro":
			sonic(ci, c + Vector2(0, 0), -0.7, 1.15)
			badge(ci, c, "+4", RED)
		"v8":
			tardis(ci, c + Vector2(-2, -2), 0.9)
			badge(ci, c, "+3", RED)
		"rising_sun":
			dalek(ci, c + Vector2(-2, -2))
			ci.draw_line(c + Vector2(16, -14), c + Vector2(34, -24), Color("7fdcff"), 2.0)
			badge(ci, c, "+3", RED)
		"autobahn":
			who_suit(ci, c + Vector2(-2, -2), 22, 2, STEEL)
			badge(ci, c, "+3", RED)
		"mud_tires":
			who_suit(ci, c + Vector2(-2, -4), 22, 3, Color("e08a00"))
			badge(ci, c, "+3", RED)
		"twin_turbo":  # K-9
			ci.draw_rect(Rect2(c + Vector2(-22, -6), Vector2(34, 16)), STEEL)
			ci.draw_rect(Rect2(c + Vector2(8, -16), Vector2(16, 12)), STEEL)
			ci.draw_rect(Rect2(c + Vector2(20, -12), Vector2(6, 4)), Color("5f6a7a"))
			ci.draw_line(c + Vector2(-20, -6), c + Vector2(-26, -18), Color("5f6a7a"), 2.0)
			ci.draw_rect(Rect2(c + Vector2(-18, -2), Vector2(12, 6)), RED)
			for x in [-18, 0]:
				ci.draw_rect(Rect2(c + Vector2(x, 10), Vector2(8, 6)), Color("5f6a7a"))
			ci.draw_line(c + Vector2(14, -16), c + Vector2(12, -24), Color("5f6a7a"), 2.0)
			badge(ci, c, "+8", RED)
		"wide_body":  # bow tie
			poly(ci, c, [Vector2(-26, -14), Vector2(-4, -4), Vector2(-26, 8)], Color("c62828"))
			poly(ci, c, [Vector2(26, -14), Vector2(4, -4), Vector2(26, 8)], Color("c62828"))
			ci.draw_rect(Rect2(c + Vector2(-5, -9), Vector2(10, 10)), Color("8a1c1c"))
			chip(ci, c + Vector2(22, -22), 8)
			badge(ci, c, "+50", BLUE)
		"convoy_leader":  # UNIT
			poly(ci, c, [Vector2(-20, -24), Vector2(20, -24), Vector2(20, 2), Vector2(0, 18), Vector2(-20, 2)], Color("2f6b36"))
			text(ci, c + Vector2(0, -8), "UNIT", 12, Color("ffd23f"))
			badge(ci, c, "+12", RED)
		"drift_king":  # timey-wimey
			clock(ci, c + Vector2(-4, -2), 20)
			spiral(ci, c + Vector2(-4, -2), 26, Color("8ec5ff"))
			badge(ci, c, "+12", RED)
		"brand_loyalty":  # shadow proclamation
			var pts := []
			for i in 12:
				pts.append(Vector2.from_angle(-PI / 2 + i * TAU / 12) * (24.0 if i % 2 == 0 else 14.0))
			poly(ci, c + Vector2(-2, -4), pts, Color("3a3f4b"))
			ci.draw_circle(c + Vector2(-2, -4), 8, Color("c9a227"))
			badge(ci, c, "+10", RED)
		"lightweight":  # fez
			poly(ci, c, [Vector2(-16, 12), Vector2(-11, -16), Vector2(11, -16), Vector2(16, 12)], Color("b3202a"))
			ci.draw_line(c + Vector2(0, -16), c + Vector2(10, -6), INK, 2.0)
			ci.draw_rect(Rect2(c + Vector2(8, -7), Vector2(5, 8)), INK)
			text(ci, c + Vector2(22, 0), "3", 16, Color.WHITE, 3)
			badge(ci, c, "+20", RED)
		"odometer":  # River's diary
			ci.draw_style_box(Data.box(TARDIS_BLUE, 3, Color("101820"), 2, 0), Rect2(c + Vector2(-16, -24), Vector2(32, 42)))
			for y in [-14, -2, 10]:
				ci.draw_rect(Rect2(c + Vector2(-12, y), Vector2(24, 8)), TARDIS_BLUE.darkened(0.25))
			text(ci, c + Vector2(20, -20), "+", 14, GREEN, 2)
			badge(ci, c, "+1", RED)
		"chrome_bumper":  # psychic paper
			ci.draw_style_box(Data.box(INK, 3), Rect2(c + Vector2(-26, -16), Vector2(52, 32)))
			ci.draw_rect(Rect2(c + Vector2(-22, -12), Vector2(20, 24)), Color.WHITE)
			crown(ci, c + Vector2(12, 0), 0.6)
			badge(ci, c, "+30", BLUE)
		"ace_driver":
			tardis(ci, c + Vector2(-4, -2), 0.9)
			text(ci, c + Vector2(18, -18), "A", 16, Color.WHITE, 3)
			badge(ci, c, "+4", RED)
		"even_gears":  # jelly babies
			for i in 4:
				var p := c + Vector2(-18 + i * 12, -4 + (i % 2) * 6)
				var col: Color = [RED, GREEN, GOLD, PURPLE][i]
				ci.draw_circle(p + Vector2(0, -7), 4, col)
				ci.draw_style_box(Data.box(col, 4), Rect2(p + Vector2(-5, -3), Vector2(10, 14)))
			badge(ci, c, "+4", RED)
		"odd_gears":  # long scarf
			var cols := [Color("8a5a2b"), Color("c9a227"), Color("b3202a"), Color("2f6b36")]
			for i in 7:
				ci.draw_set_transform(c + Vector2(-24 + i * 7, -14 + absf(i - 3) * 5), 0.4, Vector2.ONE)
				ci.draw_rect(Rect2(-4, -8, 8, 16), cols[i % 4])
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			badge(ci, c, "+31", BLUE)
		"car_show":  # time war council
			for i in 5:
				who_suit(ci, c + Vector2.from_angle(-PI / 2 + i * TAU / 5) * 20 + Vector2(0, -2), 6, 3, Color("e08a00"))
			who_suit(ci, c + Vector2(0, -2), 9, 3, GOLD)
			badge(ci, c, "+4", RED)
		"scrap_collector":  # junkyard gate on Totter's Lane
			for x in [-22, 18]:
				ci.draw_rect(Rect2(c + Vector2(x, -22), Vector2(4, 40)), Color("5f6a7a"))
			for x in range(-16, 18, 6):
				ci.draw_line(c + Vector2(x, -18), c + Vector2(x, 16), Color("8a96a8"), 2.0)
			ci.draw_rect(Rect2(c + Vector2(-14, -30), Vector2(28, 8)), Color("c9b48a"))
			badge(ci, c, "+3", RED)
		"rev_limiter":  # time loop
			clock(ci, c + Vector2(-2, -2), 14)
			ci.draw_arc(c + Vector2(-2, -2), 24, -2.7, 1.9, 32, ORANGE, 3.0, true)
			var tip := c + Vector2(-2, -2) + Vector2.from_angle(1.9) * 24
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-6, -2), tip + Vector2(5, -5), tip + Vector2(1, 7)]), ORANGE)
			badge(ci, c, "+2", ORANGE)
		"echo_exhaust":  # time echo
			clock(ci, c + Vector2(-14, -2), 12)
			for i in 3:
				ci.draw_arc(c + Vector2(-2, -2), 10.0 + i * 7, -0.8, 0.8, 12, ORANGE.lightened(i * 0.15), 3.0, true)
			badge(ci, c, "2-5", ORANGE)
		"launch_control":  # first Doctor
			text(ci, c + Vector2(-6, -2), "1", 34, Color("ffd23f"), 4)
			clock(ci, c + Vector2(18, -16), 9)
			badge(ci, c, "X2", PURPLE)
		"final_lap":  # last of the Time Lords
			who_suit(ci, c + Vector2(-2, -2), 20, 3, Color("8a5a2b"))
			ci.draw_line(c + Vector2(-14, -18), c + Vector2(8, 14), INK, 3.0)
			flame(ci, c + Vector2(18, -18), 0.4)
			badge(ci, c, "X3", PURPLE)
		"photo_finish":  # don't blink
			ci.draw_arc(c + Vector2(-16, -6), 14, PI * 0.6, PI * 1.4, 10, Color("aab0a0"), 5.0)
			ci.draw_arc(c + Vector2(12, -6), 14, -PI * 0.4, PI * 0.4, 10, Color("aab0a0"), 5.0)
			ci.draw_circle(c + Vector2(-2, -6), 13, Color("c9cbbd"))
			ci.draw_style_box(Data.box(Color("aab0a0"), 3), Rect2(c + Vector2(-14, -12), Vector2(11, 9)))
			ci.draw_style_box(Data.box(Color("aab0a0"), 3), Rect2(c + Vector2(0, -12), Vector2(11, 9)))
			badge(ci, c, "X2", PURPLE)
		"supercharger":  # bad wolf
			for y in range(-22, 16, 8):
				for x in range(-30, 30, 14):
					ci.draw_rect(Rect2(c + Vector2(x + (y / 8 % 2) * 7, y), Vector2(12, 6)), Color("8a4a2b"))
			text(ci, c + Vector2(-2, -10), "BAD", 13, GOLD, 2)
			text(ci, c + Vector2(-2, 4), "WOLF", 13, GOLD, 2)
			badge(ci, c, "X1.5", PURPLE)
		"getaway":  # the oncoming storm
			for p in [[Vector2(-10, -10), 10.0], [Vector2(4, -14), 12.0], [Vector2(14, -8), 9.0]]:
				ci.draw_circle(c + p[0], p[1], Color("3a3f4b"))
			ci.draw_rect(Rect2(c + Vector2(-18, -10), Vector2(36, 8)), Color("3a3f4b"))
			poly(ci, c + Vector2(0, 10), BOLT, Color("ffd23f"), 0.5)
			badge(ci, c, "+X", PURPLE)
		"gas_station":  # bank vault
			ci.draw_circle(c + Vector2(-4, -4), 22, Color("8a96a8"))
			ci.draw_circle(c + Vector2(-4, -4), 16, Color("5f6a7a"))
			for i in 6:
				var d := Vector2.from_angle(i * TAU / 6)
				ci.draw_line(c + Vector2(-4, -4) + d * 4, c + Vector2(-4, -4) + d * 14, Color("c9ccd1"), 2.0)
			coin(ci, c + Vector2(18, 10), 8)
			badge(ci, c, "$4", GOLD)
		"street_cred":  # time credit
			coin(ci, c + Vector2(-4, -4), 18)
			ci.draw_line(c + Vector2(-4, -4), c + Vector2(-4, -16), INK, 2.0)
			ci.draw_line(c + Vector2(-4, -4), c + Vector2(6, -4), INK, 2.0)
			badge(ci, c, "$1", GOLD)
		"pit_crew":
			regen_glow(ci, c + Vector2(-2, 0))
			badge(ci, c, "+1", BLUE)
		"tow_truck":  # reverse the polarity
			ci.draw_arc(c + Vector2(-2, -4), 16, PI, TAU, 16, RED, 8.0)
			ci.draw_rect(Rect2(c + Vector2(-22, -4), Vector2(8, 14)), RED)
			ci.draw_rect(Rect2(c + Vector2(10, -4), Vector2(8, 14)), RED)
			ci.draw_rect(Rect2(c + Vector2(-22, 6), Vector2(8, 5)), Color.WHITE)
			ci.draw_rect(Rect2(c + Vector2(10, 6), Vector2(8, 5)), Color.WHITE)
			arrow(ci, c + Vector2(-8, 18), c + Vector2(8, 18), Color.WHITE, 2.0)
			badge(ci, c, "+1", RED)
		"big_trunk":  # bigger on the inside
			for i in 7:
				var d := Vector2.from_angle(PI * 0.15 + i * PI * 0.12)
				ci.draw_line(c + Vector2(4, 8), c + Vector2(4, 8) + d * 34, Color(1, 0.95, 0.7, 0.45), 3.0)
			tardis(ci, c + Vector2(-10, -2), 0.6)
			badge(ci, c, "+1", GREEN)


## Doctor Who pictures for some garage items; false = use the classic picture.
static func _item_art_who(ci: Control, d: Dictionary, c: Vector2) -> bool:
	match d.id:
		"enh":
			mini_card(ci, c + Vector2(-12, 2), "K", 0, 26, -0.1, {"nitro": Color("e1f0ff"), "turbo": Color("fff2cc"), "carbon": Color("efe2ff"), "gold": Color("f7d774")}[d.enh])
			match d.enh:
				"nitro": sonic(ci, c + Vector2(18, -2), 0.5, 0.9)
				"turbo": regen_glow(ci, c + Vector2(18, 0), 0.6)
				"carbon": poly(ci, c + Vector2(18, -2), BOLT, PURPLE, 0.7)
				"gold":
					ci.draw_circle(c + Vector2(18, -12), 5, GREEN)
					ci.draw_style_box(Data.box(GREEN, 5), Rect2(c + Vector2(12, -8), Vector2(12, 18)))
		"scrap":
			dalek(ci, c + Vector2(-16, 4), 0.75)
			ci.draw_line(c + Vector2(-6, -10), c + Vector2(14, -6), Color("7fdcff"), 2.0)
			mini_card(ci, c + Vector2(20, 2), "5", 0, 18, 0.3)
		"swap":
			mini_card(ci, c + Vector2(-4, 4), "7", 1, 24)
			regen_glow(ci, c + Vector2(16, 0), 0.5)
		"cash":
			coin(ci, c + Vector2(-12, 6), 12)
			clock(ci, c + Vector2(12, -6), 13)
		_:
			return false
	return true


## Doctor Who pictures for vouchers (favours); false = use the default picture.
static func _voucher_art_who(ci: Control, id: String, c: Vector2) -> bool:
	match id:
		"reroll_surplus":
			clock(ci, c, 16)
			ci.draw_arc(c, 22, 0.4, PI * 1.7, 20, Color("2f8f83"), 4.0, true)
			var tip := c + Vector2.from_angle(0.4) * 22
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-6, -4), tip + Vector2(6, -2), tip + Vector2(0, 7)]), Color("2f8f83"))
		"crystal_ball":
			ci.draw_style_box(Data.box(Color("8a5a2b"), 6, Color("5a3a1a"), 2, 0), Rect2(c + Vector2(-20, -10), Vector2(40, 30)))
			mini_card(ci, c + Vector2(-4, -12), "+1", 0, 16, -0.2)
			sonic(ci, c + Vector2(12, -12), 0.3, 0.6)
		"antimatter":
			ci.draw_style_box(Data.box(TARDIS_BLUE, 2), Rect2(c + Vector2(-14, -24), Vector2(28, 44)))
			ci.draw_rect(Rect2(c + Vector2(-10, -20), Vector2(20, 36)), Color(1, 0.95, 0.7, 0.6))
			text(ci, c + Vector2(0, -2), "+1", 14, TARDIS_BLUE, 2)
		"grabber":
			hearts2(ci, c + Vector2(0, -4))
			text(ci, c + Vector2(22, 14), "+1", 13, BLUE, 2)
		"wasteful":
			ci.draw_line(c + Vector2(-24, 14), c + Vector2(0, 0), Color("8ec5ff"), 4.0)
			ci.draw_line(c + Vector2(0, 0), c + Vector2(22, -18), Color("8ec5ff"), 4.0)
			ci.draw_line(c + Vector2(0, 0), c + Vector2(24, 12), Color("ff9ad5"), 4.0)
			text(ci, c + Vector2(-16, -14), "+1", 13, RED, 2)
		"paint_brush":
			ci.draw_line(c + Vector2(0, -24), c + Vector2(0, -16), INK, 2.0)
			ci.draw_arc(c + Vector2(0, -20), 4, -PI, 0, 8, INK, 2.0)
			poly(ci, c, [Vector2(-20, -10), Vector2(0, -16), Vector2(20, -10), Vector2(14, 22), Vector2(-14, 22)], Color("8a5a2b"))
			text(ci, c + Vector2(22, -16), "+1", 13, GREEN.darkened(0.2), 2)
		"hone":
			ci.draw_style_box(Data.box(INK, 4), Rect2(c + Vector2(-24, -6), Vector2(48, 14)))
			ci.draw_style_box(Data.box(Color("5f6a7a"), 3, Color("aab4c3"), 1, 0), Rect2(c + Vector2(-10, -12), Vector2(20, 24)))
			for p in [Vector2(-18, -18), Vector2(16, -20)]:
				sparkle(ci, c + p, 6, PURPLE)
		"tune_merchant":
			ci.draw_style_box(Data.box(Color("10284a"), 4), Rect2(c + Vector2(-22, -20), Vector2(44, 40)))
			for p in [Vector2(-12, -10), Vector2(6, -14), Vector2(14, 6), Vector2(-6, 10)]:
				sparkle(ci, c + p, 4, Color("fff3a0"))
			ci.draw_line(c + Vector2(-12, -10), c + Vector2(6, -14), Color(1, 1, 1, 0.5), 1.0)
			ci.draw_line(c + Vector2(6, -14), c + Vector2(14, 6), Color(1, 1, 1, 0.5), 1.0)
		"workshop_merchant":
			ci.draw_rect(Rect2(c + Vector2(-26, 0), Vector2(52, 8)), Color("5a3a1a"))
			ci.draw_rect(Rect2(c + Vector2(-5, -1), Vector2(10, 10)), Color("c9a227"))
			sonic(ci, c + Vector2(-12, -10), -0.2, 0.6)
			sonic(ci, c + Vector2(14, -10), 0.2, 0.6)
		_:
			return false
	return true
