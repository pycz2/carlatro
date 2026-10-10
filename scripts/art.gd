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
	emblem(ci, Vector2(w * 0.08, h * 0.12), w * 0.24, suit, col)
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
	match id:
		"nitro":
			flame(ci, c + Vector2(0, -4), 1.15)
			ci.draw_line(c + Vector2(-6, 6), c + Vector2(6, 6), Color.WHITE, 4.0)
			ci.draw_line(c + Vector2(0, 0), c + Vector2(0, 12), Color.WHITE, 4.0)
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
			poly(ci, c, [Vector2(-4, -32), Vector2(4, -32), Vector2(28, 14), Vector2(-28, 14)], Color(1, 0.95, 0.6, 0.25))
			ci.draw_circle(c + Vector2(0, -31), 4, Color("fff3a0"))
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
			ci.draw_style_box(Data.box(INK, 5, Color("55585e"), 2, 0), Rect2(c + Vector2(-10, -30), Vector2(20, 50)))
			ci.draw_circle(c + Vector2(0, -20), 6, Color(RED, 0.3))
			ci.draw_circle(c + Vector2(0, -5), 6, Color(GOLD, 0.3))
			ci.draw_circle(c + Vector2(0, 10), 9, Color(GREEN, 0.35))
			ci.draw_circle(c + Vector2(0, 10), 6, GREEN)
			text(ci, c + Vector2(-22, -6), "1", 18, Color.WHITE, 3)
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
			ci.draw_style_box(Data.box(Color("3a3f4b"), 5, Color("8fa3b8"), 2, 0), Rect2(c + Vector2(-24, -16), Vector2(48, 30)))
			ci.draw_rect(Rect2(c + Vector2(-18, -21), Vector2(10, 6)), Color("8fa3b8"))
			ci.draw_circle(c + Vector2(2, -1), 12, Color("1b1f27"))
			ci.draw_circle(c + Vector2(2, -1), 9, Color("3b6fd6"))
			crown(ci, c + Vector2(2, 0), 0.38)
			sparkle(ci, c + Vector2(19, -24), 6, Color("fff3a0"))
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
