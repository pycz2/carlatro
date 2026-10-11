extends Control
## Animated picture for one page of How to Play. Real card nodes act out the rule in a loop,
## and a pointer shows what the player clicks.

const Data = preload("res://scripts/data.gd")
const CardView = preload("res://scripts/card_view.gd")

const W := 820.0
const H := 330.0
const CHIP_COL := Color("2f8cff")
const MULT_COL := Color("ff4b3e")
const MONEY_COL := Color("ffc93c")

var g  # the game node
var page := 0
var ptr := Vector2(-100, -100)  # the pointer, hidden off the picture
var ptr_ring := 0.0
var bar := 0.0  # page 0: score bar fill, 0..1
var ante_at := -1  # page 0: the reached ante
var boxes := {}  # chips/mult boxes: {"chips": Label, "mult": Label, ...}
var ptr_layer: Control  # the pointer draws in its own child, above the cards


## Page titles; the game builds the list of steps from them.
static func titles() -> Array:
	return [tr_("The Goal"), tr_("Your Hand"), tr_("Poker Hands"), tr_("Scoring"), tr_("Discards"),
		Data.tv("Mods", "Jokers", "Allies"), tr_("Pit Stop"), tr_("Boss Races"), tr_("Upgrades and Editions"), tr_("All Rules")]


static func tr_(s: String) -> String:
	return TranslationServer.translate(s)


## Short points under the picture, one line each where possible.
static func bullets(p: int) -> Array:
	match p:
		0: return [tr_("Every race has a target score. Reach it before you run out of hands."),
			tr_("Every ante has 3 races: Street, Circuit and Boss."),
			tr_("Win the Grand Prix at Ante 8 to become Champion.")]
		1: return [Data.tv("You draw 8 cars from your garage of 52.", "You draw 8 cards from your deck of 52."),
			Data.tv("Click cars to select them: up to 5 at a time.", "Click cards to select them: up to 5 at a time."),
			Data.tv("Cars score in the order you pick them.", "Cards score in the order you pick them.")]
		2:
			var b := [tr_("Your selection makes a poker hand. Better hands give more Chips and Mult.")]
			if not Data.classic_art:
				b.append(tr_("A Tandem is a Pair, a Gear Shift is a Straight, a Same Garage is a Flush, and so on."))
			elif Data.who_art:
				b.append(tr_("Companions are a Pair, a Timeline is a Straight, a Home Planet is a Flush, and so on."))
			b.append(tr_("Only the cards that make the hand score. Other selected cards give nothing."))
			return b
		3: return [Data.tv("Score = [color=#2f8cff]Chips[/color] x [color=#ff4b3e]Mult[/color]. Every scored car adds its chips.",
				"Score = [color=#2f8cff]Chips[/color] x [color=#ff4b3e]Mult[/color]. Every scored card adds its chips."),
			tr_("The hand type sets the base Chips and Mult.")]
		4: return [Data.tv("Discard throws away the selected cars and draws new ones. It does not use a hand.",
				"Discard throws away the selected cards and draws new ones. It does not use a hand."),
			tr_("You have 3 discards in each race.")]
		5: return [tr_("%s change how you score: they add Chips, Mult or X Mult.") % Data.tv("Mods", "Jokers", "Allies"),
			Data.tv("Drag Mods to change their order: they work from left to right. Cars score in the order you pick them.",
				"Drag Jokers to change their order: they work from left to right. Cards score in the order you pick them.",
				"Drag Allies to change their order: they work from left to right. Cards score in the order you pick them."),
			tr_("Order matters: +Mult before X Mult gives more.")]
		6: return [tr_("After each race you get money: the reward, $1 for each hand left and interest."),
			Data.tv("Spend cash at the [color=#e8572f]Pit Stop[/color]: Mods change how you score, Dyno Tunes level up hands, Workshop cards upgrade your cars.",
				"Spend cash at the [color=#e8572f]Pit Stop[/color]: Jokers change how you score, Upgrades level up hands, Trick cards change your cards.",
				"Spend cash at the [color=#e8572f]Pit Stop[/color]: Allies change how you score, Adventures level up hands, Gadgets change your cards."),
			tr_("Booster packs: open one and take 1 of the choices.")]
		7: return [tr_("Each Ante has a Street Race, a Circuit Race and a [color=#ff4b3e]Boss Race[/color] with a nasty rule."),
			"[color=#ff4b3e]%s[/color]: %s" % [tr_("Debuffed"), Data.tv("the boss blocks this car: it gives no chips and no effects.", "the boss blocks this card: it gives no chips and no effects.")],
			tr_("Read the rule before the race and plan for it.")]
		8: return [Data.tv("Workshop cards upgrade your cars: they get a special effect.", "Trick cards upgrade your cards: they get a special effect.",
				"Gadgets upgrade your cards: they get a special effect."),
			Data.tv("Some Mods come with an edition (they cost more):", "Some Jokers come with an edition (they cost more):", "Some Allies come with an edition (they cost more):").trim_suffix(":") + ".",
			tr_("Hover any card in the game to read its effect.")]
	return []


func _ready() -> void:
	size = Vector2(W, H)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ptr_layer = Control.new()
	ptr_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ptr_layer.z_index = 200
	ptr_layer.draw.connect(_draw_ptr)
	add_child(ptr_layer)
	_loop()


func _process(_d: float) -> void:
	queue_redraw()
	ptr_layer.queue_redraw()


func _loop() -> void:
	while true:
		match page:
			0: await _goal()
			1: await _hand()
			2: await _hands()
			3: await _scoring()
			4: await _discards()
			5: await _mods()
			6: await _shop()
			7: await _boss()
			8: await _upgrades()
			_: return
		await _w(1.4)
		_reset()


func _reset() -> void:
	for c in get_children():
		if c != ptr_layer:
			c.queue_free()
	boxes = {}
	ptr = Vector2(-100, -100)
	bar = 0.0
	ante_at = -1


# ---------------------------------------------------------------- helpers

func _w(t: float) -> void:
	await create_tween().tween_interval(t).finished  # a freed page stops its tweens, so the loop just ends


func _card(kind: int, data: Dictionary, pos: Vector2, s := 0.8, from := Vector2.INF) -> Control:
	var cv := CardView.new()
	cv.kind = kind
	cv.data = data
	cv.interactive = false
	cv.base_scale = s
	cv.scale = Vector2(s, s)
	cv.target_pos = pos
	cv.position = pos if from == Vector2.INF else from
	add_child(cv)
	return cv


func _car(rank: int, suit: int, enh := "") -> Dictionary:
	return {"id": 0, "rank": rank, "suit": suit, "enh": enh}


func _mod(id: String, edition := "") -> Dictionary:
	var m: Dictionary = Data.MODS.filter(func(x): return x.id == id)[0].duplicate()
	if edition != "":
		m.edition = edition
	return m


func _lbl(text: String, fsize: int, col: Color, pos: Vector2, width := W) -> Label:
	var l: Label = g._label(text, fsize, col, 5)
	l.position = pos
	l.size = Vector2(width, fsize + 10)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(l)
	return l


func _pop(text: String, pos: Vector2, col: Color, fsize := 24) -> void:
	var l := _lbl(text, fsize, col, pos - Vector2(100, 0), 200)
	l.z_index = 50
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", pos.y - 40, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.4)


func _point(to: Vector2, t := 0.45) -> void:
	if ptr.x < 0:
		ptr = Vector2(W - 40, H + 30)
	var tw := create_tween()
	tw.tween_property(self, "ptr", to, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _click() -> void:
	ptr_ring = 1.0
	create_tween().tween_property(self, "ptr_ring", 0.0, 0.35)
	g.sfx.play("click", 1.2, -10.0)
	await _w(0.2)


func _center(cv: Control) -> Vector2:
	return cv.target_pos + CardView.SIZE / 2  # cards scale around their center


## Positions for n cards in a centered row; y is the top edge of the scaled cards.
func _row(n: int, y: float, s: float, gap := 8.0) -> Array:
	var w := CardView.SIZE.x * s
	var x0 := W / 2 - (n * w + (n - 1) * gap) / 2
	var shift := CardView.SIZE * (1.0 - s) / 2  # target_pos is the unscaled corner
	var out := []
	for i in n:
		out.append(Vector2(x0 + i * (w + gap), y) - shift)
	return out


## Chips x Mult = total, as in the sidebar.
func _score_boxes(y: float, chips: float, mult: float) -> void:
	for spec in [["chips", CHIP_COL, W / 2 - 190], ["mult", MULT_COL, W / 2 + 10]]:
		var p: PanelContainer = g._panel(spec[1], Color(0, 0, 0, 0), 0, 4, 8)
		p.position = Vector2(spec[2], y)
		p.custom_minimum_size = Vector2(130, 44)
		var l: Label = g._label("", 26, Color.WHITE, 5)
		p.add_child(l)
		add_child(p)
		boxes[spec[0]] = l
	boxes.x = _lbl("X", 26, MULT_COL, Vector2(W / 2 - 60, y + 4), 70)
	boxes.total = _lbl("", 30, MONEY_COL, Vector2(W / 2 + 150, y + 2), 200)
	boxes.total.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_set_score(chips, mult)


func _set_score(chips: float, mult: float, total := -1.0) -> void:
	boxes.chips.text = g._fmt(chips)
	boxes.mult.text = g._fmt_mult(mult)
	boxes.total.text = "" if total < 0 else "= " + g._fmt(total)


# ---------------------------------------------------------------- pages

func _goal() -> void:
	_lbl(tr("Score at least") + " 300", 22, Color(1, 1, 1, 0.8), Vector2(0, 28))
	var cur := _lbl("0", 30, Color.WHITE, Vector2(0, 104))
	var score := 0.0
	for add in [60.0, 110.0, 150.0]:
		await _w(0.6)
		_pop("+" + str(int(add)), Vector2(160 + 500 * (score + add) / 300.0 * 0.9, 70), CHIP_COL)
		g.sfx.play("score", 1.0, -12.0)
		var tw := create_tween()
		tw.tween_property(self, "bar", minf((score + add) / 300.0, 1.0), 0.4)
		score += add
		cur.text = str(int(score))
		await tw.finished
	_pop(tr("RACE WON!"), Vector2(W / 2, 150), MONEY_COL, 34)
	g.sfx.play("win", 1.0, -12.0)
	await _w(0.8)
	for a in 8:
		ante_at = a
		g.sfx.play("card", 1.0 + a * 0.05, -12.0)
		await _w(0.28)
	_pop(tr("CHAMPION!"), Vector2(W / 2, 280), MONEY_COL, 30)
	await _w(1.0)


func _hand() -> void:
	var deck := _card(CardView.BACK, {}, Vector2(W - 90, 20), 0.6)
	var ranks := [[14, 0], [13, 1], [9, 2], [9, 3], [7, 0], [5, 1], [4, 2], [2, 3]]
	var pos := _row(8, 110, 0.8, 4)
	var cards := []
	for i in 8:
		var cv := _card(CardView.CAR, _car(ranks[i][0], ranks[i][1]), pos[i], 0.8, deck.position)
		cv.face_down = true
		cv.flip_up(0.25)
		cards.append(cv)
		g.sfx.play("card", randf_range(0.9, 1.1), -14.0)
		await _w(0.09)
	await _w(0.7)
	for i in [2, 3]:
		await _point(_center(cards[i]))
		await _click()
		cards[i].selected = true
		await _w(0.25)
	_lbl(tr(Data.hand_name(1)), 26, Color("ffd23f"), Vector2(0, 30))
	await _w(1.2)


func _hands() -> void:
	for t in range(1, Data.HANDS.size()):
		var ex: Array = Data.HAND_EXAMPLES[t]
		var pos := _row(ex.size(), 120, 0.85, 10)
		var views := []
		for i in ex.size():
			views.append(_card(CardView.CAR, _car(ex[i][0], ex[i][1]), pos[i], 0.85, pos[i] + Vector2(0, 260)))
		var h: Dictionary = Data.HANDS[t]
		var name := tr(Data.hand_name(t))
		if Data.hand_name(t) != h.poker:
			name += "  (" + tr(h.poker) + ")"
		var nl := _lbl(name, 28, Color("ffd23f"), Vector2(0, 26))
		var sl := _lbl("%d  x  %d" % [h.chips, h.mult], 20, Color.WHITE, Vector2(0, 66))
		sl.add_theme_color_override("font_color", CHIP_COL.lightened(0.3))
		g.sfx.play("card", 1.0, -12.0)
		await _w(1.7)
		for v in views:
			v.target_pos.y = -200
		nl.queue_free()
		sl.queue_free()
		await _w(0.3)
		for v in views:
			v.queue_free()


func _scoring() -> void:
	var pos := _row(3, 60, 0.85, 10)
	var cards := [_card(CardView.CAR, _car(13, 0), pos[0], 0.85), _card(CardView.CAR, _car(13, 1), pos[1], 0.85),
		_card(CardView.CAR, _car(6, 2), pos[2], 0.85)]
	var hl := _lbl(tr(Data.hand_name(1)), 24, Color("ffd23f"), Vector2(0, 14))
	_score_boxes(220, 10, 2)
	await _w(0.8)
	cards[2].dimmed = true  # not part of the Pair: it does not score
	await _w(0.5)
	var chips := 10.0
	for i in 2:
		cards[i].lift = 18
		cards[i].punch(0.3)
		chips += 10
		_pop("+10", _center(cards[i]) - Vector2(0, 70), CHIP_COL)
		g.sfx.play("chips", 1.0 + i * 0.1, -10.0)
		_set_score(chips, 2)
		g._punch_label(boxes.chips)
		await _w(0.6)
	_set_score(chips, 2, chips * 2)
	g._punch_label(boxes.total, 0.3)
	g.sfx.play("score", 1.0, -10.0)
	hl.text += "  =  " + g._fmt(chips * 2)
	await _w(1.6)


func _discards() -> void:
	var deck := _card(CardView.BACK, {}, Vector2(W - 90, 20), 0.6)
	var pos := _row(6, 120, 0.8, 8)
	var ranks := [[12, 0], [12, 1], [3, 2], [8, 3], [2, 0], [12, 2]]
	var cards := []
	for i in 6:
		cards.append(_card(CardView.CAR, _car(ranks[i][0], ranks[i][1]), pos[i], 0.8))
	var dl := _lbl(tr("Discards") + ": 3", 22, MULT_COL, Vector2(20, 20), 300)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var btn: Button = g._button("Discard", MULT_COL, 18, Vector2(140, 44))
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.position = Vector2(W / 2 - 70, 270)
	add_child(btn)
	await _w(0.6)
	for i in [2, 3, 4]:
		await _point(_center(cards[i]))
		await _click()
		cards[i].selected = true
	await _point(btn.position + btn.size / 2)
	await _click()
	dl.text = tr("Discards") + ": 2"
	g._punch_label(dl)
	for i in [2, 3, 4]:
		cards[i].selected = false
		cards[i].target_pos = Vector2(-150, 60)
		cards[i].target_rot = -0.8
	g.sfx.play("card", 0.8, -10.0)
	await _w(0.5)
	var news := [[12, 3], [10, 1], [10, 0]]
	for k in 3:
		var i: int = [2, 3, 4][k]
		cards[i].queue_free()
		var cv := _card(CardView.CAR, _car(news[k][0], news[k][1]), pos[i], 0.8, deck.position)
		cv.face_down = true
		cv.flip_up(0.25)
		g.sfx.play("card", 1.1, -12.0)
		await _w(0.12)
	await _w(0.6)
	_lbl(tr(Data.hand_name(3)), 26, Color("ffd23f"), Vector2(0, 50))
	await _w(1.2)


func _mods() -> void:
	var mpos := [Vector2(W / 2 - 110, 6), Vector2(W / 2 + 14, 6)]
	var add := _card(CardView.MOD, _mod("nitro"), mpos[0], 0.72)
	var xm := _card(CardView.MOD, _mod("supercharger"), mpos[1], 0.72)
	var cpos := _row(2, 128, 0.62, 8)
	_card(CardView.CAR, _car(13, 0), cpos[0], 0.62)
	_card(CardView.CAR, _car(13, 1), cpos[1], 0.62)
	_score_boxes(232, 30, 2)
	var order := [add, xm]
	for pass_i in 2:
		await _w(0.7)
		var mult := 2.0
		for m in order:
			m.punch(0.3)
			if m == add:
				mult += 4
				_pop("+4", _center(m) + Vector2(0, -40), MULT_COL)
			else:
				mult *= 1.5
				_pop("X1.5", _center(m) + Vector2(0, -40), Color("d77cff"))
			g.sfx.play("mult", 1.0, -10.0)
			_set_score(30, mult)
			g._punch_label(boxes.mult)
			await _w(0.7)
		_set_score(30, mult, 30 * mult)
		g._punch_label(boxes.total, 0.3)
		await _w(1.2)
		if pass_i == 0:
			# drag X Mult to the left: now it works first, and the score is lower
			await _point(_center(xm))
			await _click()
			xm.target_pos = mpos[0]
			add.target_pos = mpos[1]
			await _point(mpos[0] + CardView.SIZE * 0.36, 0.5)
			order = [xm, add]
			_set_score(30, 2)
			ptr = Vector2(-100, -100)
	await _w(0.4)


func _shop() -> void:
	var money := 12
	var ml := _lbl("$%d" % money, 30, MONEY_COL, Vector2(20, 10), 200)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var tray := Panel.new()
	tray.add_theme_stylebox_override("panel", Data.box(Color(0, 0, 0, 0.3), 12))
	tray.position = Vector2(W - 230, 8)
	tray.size = Vector2(220, 112)
	add_child(tray)
	var pos := _row(4, 150, 0.8, 22)
	var items := [_card(CardView.MOD, _mod("twin_turbo"), pos[0], 0.8), _card(CardView.CONS, Data.WORKSHOP[0], pos[1], 0.8),
		_card(CardView.PACK, Data.PACKS[0], pos[2], 0.8), _card(CardView.VOUCHER, Data.VOUCHERS[0], pos[3], 0.8)]
	for i in items.size():
		items[i].price = [3, 3, 4, 10][i]
	await _w(0.8)
	await _point(_center(items[0]))
	await _click()
	items[0].selected = true
	var buy: Button = g._button("Buy", Color("2fa65a"), 16, Vector2(90, 36))
	buy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy.position = Vector2(pos[0].x + 3, 284)
	add_child(buy)
	await _w(0.3)
	await _point(buy.position + buy.size / 2)
	await _click()
	buy.queue_free()
	money -= 3
	ml.text = "$%d" % money
	g._punch_label(ml)
	_pop("-$3", Vector2(80, 40), MONEY_COL)
	g.sfx.play("coin", 1.0, -10.0)
	items[0].selected = false
	items[0].price = -1
	items[0].base_scale = 0.66
	items[0].target_pos = Vector2(W - 168, -8)
	ptr = Vector2(-100, -100)
	await _w(1.2)


func _boss() -> void:
	var b: Dictionary = Data.BOSSES.filter(func(x): return x.id == "ban")[0]
	var head: PanelContainer = g._panel(b.color, b.color.lightened(0.3), 2, 8, 8)
	head.add_child(g._label(Data.text(b, "name"), 22))
	head.position = Vector2(W / 2 - 160, 8)
	head.custom_minimum_size = Vector2(320, 0)
	add_child(head)
	var dl := _lbl(Data.text(b, "desc").replace("\n", " "), 17, Color(1, 1, 1, 0.85), Vector2(0, 58))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var pos := _row(6, 130, 0.8, 8)
	var suits := [0, 1, 0, 2, 3, 0]
	var ranks := [14, 11, 9, 9, 6, 3]
	var cards := []
	for i in 6:
		cards.append(_card(CardView.CAR, _car(ranks[i], suits[i]), pos[i], 0.8, pos[i] + Vector2(0, 260)))
	await _w(1.0)
	for cv in cards:
		if cv.data.suit == b.suit:
			cv.debuffed = true
			cv.punch(0.3)
			g.sfx.play("break", 1.2, -14.0)
			await _w(0.3)
	await _w(1.6)


func _upgrades() -> void:
	var keys := Data.ENH_INFO.keys()
	var pos := _row(4, 2, 0.6, 112)
	for i in keys.size():
		var e: String = keys[i]
		var cv := _card(CardView.CAR, _car(13 - i, i, e), pos[i], 0.6, pos[i] + Vector2(0, -200))
		cv.punch(0.2)
		_caption(Data.text(Data.ENH_INFO[e], "name"), tr(Data.ENH_INFO[e].desc), Data.ENH_COLORS[e].lightened(0.35), pos[i] + Vector2(-37, 108))
		g.sfx.play("card", 1.0 + i * 0.08, -12.0)
		await _w(0.35)
	var eds := Data.EDITIONS.keys()
	var mods := ["nitro", "twin_turbo", "wide_body", "convoy_leader"]
	pos = _row(4, 168, 0.6, 112)
	for i in eds.size():
		var cv := _card(CardView.MOD, _mod(mods[i], eds[i]), pos[i], 0.6, pos[i] + Vector2(0, 300))
		cv.punch(0.2)
		_caption(Data.text(Data.EDITIONS[eds[i]], "name"), Data.text(Data.EDITIONS[eds[i]], "desc"), Color("7fe0d0"), pos[i] + Vector2(-37, 108))
		g.sfx.play("coin", 1.0 + i * 0.08, -14.0)
		await _w(0.35)
	await _w(2.2)


## Name and effect under a card.
func _caption(name: String, desc: String, col: Color, pos: Vector2) -> void:
	_lbl(name, 16, col, pos, 170)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", 13)
	r.position = pos + Vector2(0, 22)
	r.size = Vector2(170, 40)
	r.text = "[center]" + g._bb_dark(desc).replace("\n", " ") + "[/center]"
	add_child(r)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_style_box(Data.box(Color(0, 0, 0, 0.3), 14), Rect2(Vector2.ZERO, size))
	if page == 0:
		var r := Rect2(160, 66, 500, 30)
		draw_style_box(Data.box(Color(1, 1, 1, 0.08), 8), r)
		if bar > 0.0:
			draw_style_box(Data.box(CHIP_COL if bar < 1.0 else MONEY_COL, 8), Rect2(r.position, Vector2(r.size.x * bar, r.size.y)))
		draw_line(Vector2(r.end.x, r.position.y - 8), Vector2(r.end.x, r.end.y + 8), MULT_COL, 3.0)
		if ante_at >= 0:
			for a in 8:
				var c := Vector2(W / 2 - 280 + a * 80, 236)
				var done := a <= ante_at
				draw_circle(c, 22, Color("ffd23f") if a == 7 and done else (Color("2fa65a") if done else Color(1, 1, 1, 0.12)))
				draw_string(get_theme_default_font(), c + Vector2(-20, 7), str(a + 1), HORIZONTAL_ALIGNMENT_CENTER, 40, 20,
					Color("1b1f27") if done else Color(1, 1, 1, 0.6))
				for k in 3:
					draw_circle(c + Vector2(-10 + k * 10, 32), 3.5, (MULT_COL if k == 2 else Color.WHITE) if done else Color(1, 1, 1, 0.15))


func _draw_ptr() -> void:
	var ci := ptr_layer
	if ptr.x < 0:
		return
	if ptr_ring > 0.0:
		ci.draw_arc(ptr, 12 + (1.0 - ptr_ring) * 30, 0, TAU, 32, Color(1, 0.82, 0.25, ptr_ring), 4.0)
	var shape := [Vector2(0, 0), Vector2(0, 26), Vector2(7, 20), Vector2(12, 31), Vector2(17, 29), Vector2(12, 18), Vector2(21, 18)]
	var arrow := PackedVector2Array()
	var shadow := PackedVector2Array()
	for v in shape:
		arrow.append(ptr + v * 1.6)
		shadow.append(ptr + v * 1.6 + Vector2(3, 4))
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.5))
	ci.draw_colored_polygon(arrow, Color.WHITE)
	ci.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color("1b1f27"), 3.0)
