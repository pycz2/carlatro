extends Control
## Interactive tutorial: the first race of a scripted run, with pop-up hints that point at the table.
## The game owns the run; this node only dims the screen around the target and waits for the player.

const Data = preload("res://scripts/data.gd")
const Scoring = preload("res://scripts/scoring.gd")
const CardView = preload("res://scripts/card_view.gd")

var g  # the game node
var step := -1
var steps: Array = []
var hole := Rect2()
var panel: PanelContainer
var text_lbl: RichTextLabel
var step_lbl: Label
var btns: HBoxContainer
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # the player plays through the dim
	z_index = 420  # above the table and the shop (z 200-350), below the menu (600)
	steps = _steps()
	panel = g._panel(Color(0.06, 0.08, 0.11, 0.97), Color("ffd23f"), 3, 16, 14)
	panel.custom_minimum_size = Vector2(420, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var v: VBoxContainer = g._vbox(10)
	panel.add_child(v)
	step_lbl = g._label("", 14, Color("ffd23f"), 3)
	step_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(step_lbl)
	text_lbl = RichTextLabel.new()
	text_lbl.bbcode_enabled = true
	text_lbl.fit_content = true
	text_lbl.scroll_active = false
	text_lbl.custom_minimum_size = Vector2(388, 0)
	text_lbl.add_theme_font_size_override("normal_font_size", 18)
	text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(text_lbl)
	btns = g._hbox(8)
	btns.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(btns)
	_go(0)


## One step: text, the rect to point at (Callable -> Rect2, or null), and when to move on:
## "wait" (Callable -> bool) moves on by itself; without it the step has a Next button.
func _steps() -> Array:
	var cars := not Data.classic_art
	return [
		{"text": tr("[b]Goal of the game[/b]: win races. In each race, reach the target score before you run out of hands.") + "\n\n" + tr("Every ante has 3 races. Win the Grand Prix at Ante 8 to become Champion.")},
		{"text": tr("This is the first race. The panel shows the target score and the reward.") + "\n\n" + tr("Press [color=#e8572f]Race![/color] to start."),
			"rect": func(): return Rect2(352, 232, 270, 400), "wait": func(): return g.state == "play"},
		{"text": Data.tv("This is your hand: 8 cars from your garage. Every car is a playing card with a rank (2 to Ace) and a suit.",
			"This is your hand: 8 cards from your deck. Every card has a rank (2 to Ace) and a suit."),
			"rect": _hand_rect},
		{"text": tr("Here is the target score of the race and your current score. Every hand you play adds to your score."),
			"rect": func(): return g.blind_box.get_global_rect().merge(g.score_lbl.get_parent().get_parent().get_global_rect())},
		{"text": tr("In every race you have [color=#2f8cff]4 hands[/color] and [color=#ff4b3e]3 discards[/color]. Use them well."),
			"rect": func(): return g.hands_lbl.get_parent().get_parent().get_parent().get_global_rect()},
		{"text": (tr("Click the two Kings to select them. Two cars of the same rank make the hand “%s”.") if cars else tr("Click the two Kings to select them. Two cards of the same rank make the hand “%s”.")) % tr(Data.hand_name(Scoring.PAIR)),
			"rect": _kings_rect, "wait": func(): return _selected_type() >= Scoring.PAIR},
		{"text": tr("The game shows the hand and its score: [color=#2f8cff]Chips[/color] x [color=#ff4b3e]Mult[/color]. Every scored card adds its chips."),
			"rect": func(): return g.hand_name_lbl.get_parent().get_parent().get_global_rect()},
		{"text": tr("Press [color=#2f8cff]Play Hand[/color]."),
			"rect": func(): return g.play_btn.get_global_rect(), "wait": func(): return g.hands_played >= 1 and not g.busy},
		{"text": Data.tv("Not a strong hand? Select the cars you do not need and press [color=#ff4b3e]Discard[/color]: new cars come from your garage.",
			"Not a strong hand? Select the cards you do not need and press [color=#ff4b3e]Discard[/color]: new cards come from your deck."),
			"rect": func(): return _hand_rect().merge(g.discard_btn.get_global_rect()), "wait": func(): return g.discards_left < 3 and not g.busy},
		{"text": tr("Now find your best hand and play it. You can select up to 5 cards. The hand name and score show before you play.") + "\n\n" + tr("Beat the target to win the race!"),
			"rect": func(): return _hand_rect().merge(g.hand_bar.get_global_rect()), "wait": func(): return g.state == "cashout"},
		{"text": tr("You won the race! You get money: the reward, $1 for each hand left and interest on your savings.") + "\n\n" + tr("Press [color=#e8572f]Cash Out[/color]."),
			"rect": _overlay_panel_rect, "wait": func(): return g.state == "shop"},
		{"text": tr("This is the [color=#e8572f]Pit Stop[/color]. Here you spend money between races."),
			"rect": func(): return g.shop_panel.get_global_rect()},
		{"text": tr("%s change how you score. Click one and press Buy.") % Data.tv("Mods", "Jokers", "Allies") + "\n\n" + tr("Hover any card to read what it does."),
			"rect": func(): return Rect2(g.shop_panel.global_position + Vector2(218, 40), Vector2(352, 200)),
			"wait": func(): return not g.mods.is_empty(), "next": true,
			"enter": func():
				g.money = maxi(g.money, 12)  # enough for any mod in the tutorial
				g._update_sidebar()},
		{"text": tr("Your %s are here. They work from left to right: drag them to change the order.") % Data.tv("Mods", "Jokers", "Allies"),
			"rect": func(): return Rect2(g.MOD_POS - Vector2(10, 10), Vector2(g.MAX_MODS * 104 + 12, 156))},
		{"text": tr("%s work at once or change your cards. Booster packs let you take 1 of several cards. %s give a bonus for the whole run.") % [Data.tv("Garage cards", "Items", "Pockets"), Data.tv("Sponsors", "Vouchers", "Favours")],
			"rect": func(): return Rect2(g.shop_panel.global_position + Vector2(218, 40), Vector2(700, 400))},
		{"text": tr("The third race of every ante is a [color=#ff4b3e]Boss Race[/color] with a special rule. Read it before you start.") + "\n\n" + tr("That is all! You know the basics. Good luck in the races!"),
			"rect": func(): return Rect2(g.shop_panel.global_position + Vector2(26, 76), Vector2(170, 70)), "last": true},
	]


func _go(i: int) -> void:
	step = i
	var s: Dictionary = steps[i]
	if s.has("enter"):
		s.enter.call()
	step_lbl.text = tr("TUTORIAL") + "  %d/%d" % [i + 1, steps.size()]
	text_lbl.text = s.text
	for c in btns.get_children():
		c.queue_free()
	if s.get("last", false):
		var keep: Button = g._button("Keep Playing", Color("2fa65a"), 17, Vector2(170, 44))
		keep.pressed.connect(g._stop_tutorial)
		btns.add_child(keep)
		var menu: Button = g._button("Main Menu", g.ACCENT, 17, Vector2(170, 44))
		menu.pressed.connect(g._show_title)
		btns.add_child(menu)
		return
	var skip: Button = g._button("Skip Tutorial", Color("555b66"), 15, Vector2(150, 40))
	skip.pressed.connect(g._show_title)
	btns.add_child(skip)
	if not s.has("wait") or s.get("next", false):
		var nb: Button = g._button("Next", Color("2fa65a"), 17, Vector2(130, 40))
		nb.pressed.connect(func(): _go(step + 1))
		btns.add_child(nb)
	g.sfx.play("click")


func _process(delta: float) -> void:
	_t += delta
	if g.state == "end":  # out of hands: the end screen takes over
		g._stop_tutorial()
		return
	var s: Dictionary = steps[step]
	if s.has("wait") and s.wait.call():
		_go(step + 1)
		return
	# stay out of the way while cards fly and score
	visible = not g.busy
	hole = s.rect.call().grow(8) if s.has("rect") else Rect2()
	_place_panel()
	queue_redraw()


func _place_panel() -> void:
	panel.reset_size()
	var sz := panel.size
	var pos := Vector2(640, 360) - sz / 2
	if hole.size != Vector2.ZERO:
		var c := hole.get_center()
		if hole.end.y + 16 + sz.y < 712:
			pos = Vector2(c.x - sz.x / 2, hole.end.y + 16)
		elif hole.position.y - 16 - sz.y > 8:
			pos = Vector2(c.x - sz.x / 2, hole.position.y - 16 - sz.y)
		elif hole.end.x + 16 + sz.x < 1272:
			pos = Vector2(hole.end.x + 16, c.y - sz.y / 2)
		else:
			pos = Vector2(hole.position.x - 16 - sz.x, c.y - sz.y / 2)
	panel.position = Vector2(clampf(pos.x, 8, 1272 - sz.x), clampf(pos.y, 8, 712 - sz.y))


func _draw() -> void:
	var dim := Color(0, 0, 0, 0.55)
	if hole.size == Vector2.ZERO:
		draw_rect(Rect2(0, 0, 1280, 720), dim)
		return
	var h := hole
	draw_rect(Rect2(0, 0, 1280, h.position.y), dim)
	draw_rect(Rect2(0, h.end.y, 1280, 720 - h.end.y), dim)
	draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), dim)
	draw_rect(Rect2(h.end.x, h.position.y, 1280 - h.end.x, h.size.y), dim)
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	draw_rect(h.grow(2 + pulse * 3), Color(1, 0.82, 0.25, 0.5 + pulse * 0.5), false, 3.0)


func _cards_rect(views: Array) -> Rect2:
	if views.is_empty():
		return Rect2(g.HAND_CX - 400, g.HAND_Y - 40, 800, 180)
	var r := Rect2(views[0].target_pos, CardView.SIZE)
	for cv in views:
		r = r.merge(Rect2(cv.target_pos - Vector2(0, 34 if cv.selected else 0), CardView.SIZE))
	return r


func _hand_rect() -> Rect2:
	return _cards_rect(g.hand)


func _kings_rect() -> Rect2:
	return _cards_rect(g.hand.filter(func(cv): return cv.data.rank == 13))


func _selected_type() -> int:
	var sel: Array = g._selected()
	return -1 if sel.is_empty() else Scoring.evaluate(sel.map(func(c): return c.data)).type


func _overlay_panel_rect() -> Rect2:
	for c in g.overlay.get_children():
		if c is PanelContainer:
			return c.get_global_rect()
	return Rect2()
