extends Control
## Carlatro: a Balatro-like roguelike deckbuilder. Cars instead of cards.
## Builds the whole UI in code and runs the game flow:
## title -> blind select -> race -> cash out -> shop -> blind select ... -> end.

const Data = preload("res://scripts/data.gd")
const Scoring = preload("res://scripts/scoring.gd")
const CardView = preload("res://scripts/card_view.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Music = preload("res://scripts/music.gd")
const Art = preload("res://scripts/art.gd")
const Changelog = preload("res://scripts/changelog.gd")

const HAND_CX := 725.0
const HAND_Y := 492.0
const PLAY_Y := 262.0
const DECK_POS := Vector2(1168, 498)
const MOD_POS := Vector2(318, 24)
const CONS_POS := Vector2(1062, 24)
const MAX_MODS := 5
const MAX_CONS := 2
const CHIP_COL := Color("2f8cff")
const MULT_COL := Color("ff4b3e")
const MONEY_COL := Color("ffc93c")
const ACCENT := Color("e8572f")
const PANEL_BG := Color(0.07, 0.09, 0.12, 0.95)
const SPEEDS := [1.0, 1.6, 2.5]
const SAVE_PATH := "user://run.save"
const SETTINGS_PATH := "user://settings.cfg"
const STATS_PATH := "user://stats.cfg"
const STAT_KEYS := ["runs_started", "runs_won", "runs_lost", "best_ante", "best_hand", "races_won", "bosses_beaten",
	"hands_played", "cards_played", "discards", "money_earned", "mods_bought", "packs_opened"]
const SAVE_STATES := ["blind", "play", "cashout", "shop"]
const LANGS := [["en", "English"], ["ru", "Русский"], ["es", "Español"], ["de", "Deutsch"], ["fr", "Français"], ["pt_BR", "Português"]]
var rng := RandomNumberGenerator.new()
var sfx: Node
var music: AudioStreamPlayer
var music_on := true
var sfx_on := true
var music_vol := 0.8
var sfx_vol := 1.0
var shake_on := true
var show_fps := false
var fullscreen := false

# run state
var ante := 1
var blind_idx := 0
var round_num := 0
var money := 4
var deck: Array = []
var draw_pile: Array = []
var levels: Array = []
var played_count: Array = []
var mods: Array = []
var consumables: Array = []
var boss: Dictionary = {}
var last_boss_name := ""
var endless := false
var best_hand := 0
var next_id := 0
# race state
var score := 0
var target := 0
var hands_left := 0
var discards_left := 0
var hand_size := 8
var hands_played := 0
var played_types: Array = []
var state := "title"
var busy := false
var sort_by_suit := false
var speed_idx := 0
var reroll_cost := 5
var collection_tab := 0
var vouchers: Array = []  # ids of bought vouchers (permanent for the run)
var voucher_offer := ""
var stats := {}
var result_recorded := false  # a run counts once: won, or lost
var gallery_backs: Array = []
var cashout_lines: Array = []
var pack_open: Dictionary = {}
var shake := 0.0
var _time := 0.0

# card views
var hand: Array = []
var mod_views: Array = []
var cons_views: Array = []
var shop_views: Array = []
var pack_views: Array = []
var deck_view: Control
var action_card: Control = null
var tip_card: Control = null
var tip_above := true  # chosen once per hover, so the tooltip never flips sides
var tip_frames := 0

# ui nodes
var world: Control
var cards_layer: Control
var overlay: Control
var fx_layer: Control
var title_layer: Control
var modal_layer: Control
var shop_panel: Panel
var reroll_btn: Button
var title_lbl: Label
var blind_box: PanelContainer
var blind_name_lbl: Label
var blind_desc_lbl: Label
var target_lbl: Label
var reward_lbl: Label
var score_lbl: Label
var hand_name_lbl: Label
var hand_poker_lbl: Label
var chips_lbl: Label
var mult_lbl: Label
var hands_lbl: Label
var discards_lbl: Label
var money_lbl: Label
var ante_lbl: Label
var round_lbl: Label
var speed_btn: Button
var mods_lbl: Label
var cons_lbl: Label
var deck_lbl: Label
var hand_bar: HBoxContainer
var play_btn: Button
var discard_btn: Button
var action_box: HBoxContainer
var tooltip: PanelContainer
var tip_title: Label
var tip_text: RichTextLabel
var music_btn: Button
var sound_btn: Button
var fps_lbl: Label
var sort_suit_btn: Button
var continue_btn: Button
var pack_panel: Panel


func _ready() -> void:
	rng.randomize()
	sfx = Sfx.new()
	add_child(sfx)
	_load_settings()
	_load_stats()
	music = Music.new()
	add_child(music)
	_apply_settings()
	if fullscreen and not OS.has_feature("web"):  # browsers allow fullscreen only after a click
		_apply_fullscreen()
	_build_ui()
	_show_title()
	_refresh_texts()


func _process(delta: float) -> void:
	_time += delta
	if fps_lbl.visible:
		fps_lbl.text = "FPS %d" % Engine.get_frames_per_second()
	shake = move_toward(shake, 0.0, delta * 30.0)
	var sh := shake if shake_on else 0.0
	world.position = Vector2(randf_range(-sh, sh), randf_range(-sh, sh))
	if title_layer.visible:
		title_lbl.rotation = sin(_time * 1.3) * 0.04
		title_lbl.scale = Vector2.ONE * (1.0 + sin(_time * 2.1) * 0.03)
	if tooltip.visible and is_instance_valid(tip_card):
		tooltip.reset_size()
		var gp := tip_card.global_position
		var card_h := CardView.SIZE.y * tip_card.scale.y
		var y := gp.y - tooltip.size.y - 14 if tip_above else gp.y + card_h + 16
		y = clampf(y, 4, 716 - tooltip.size.y)  # slide inside the screen instead of flipping
		tooltip.position = Vector2(clampf(gp.x + CardView.SIZE.x / 2 - tooltip.size.x / 2, 8, 1272 - tooltip.size.x), y)
		# the rich text knows its height only after a frame: stay invisible until then
		tip_frames += 1
		if tip_frames >= 2:
			tooltip.modulate.a = 1.0
	elif tooltip.visible:
		tooltip.hide()
	if action_box.visible:
		if is_instance_valid(action_card):
			action_box.reset_size()
			action_box.position = action_card.global_position + Vector2(CardView.SIZE.x / 2 - action_box.size.x / 2, CardView.SIZE.y + 10)
		else:
			_hide_action()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_hide_action()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_M:
		_toggle_music()
	if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_F11 or (e.keycode == KEY_F and e.ctrl_pressed and e.meta_pressed)):
		_toggle_fullscreen()
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		if modal_layer.get_child_count() > 0:
			_clear(modal_layer)
		else:
			_show_menu()
	if e is InputEventKey and e.pressed and not e.echo and state == "play":
		match e.keycode:
			KEY_ENTER, KEY_KP_ENTER: play_hand()
			KEY_BACKSPACE, KEY_DELETE: discard()


func wait(t: float) -> void:
	await get_tree().create_timer(t / SPEEDS[speed_idx]).timeout


# ================================================================ UI building

func _layer(parent: Node) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _label(text: String, size: int, color := Color.WHITE, outline := 6) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color, size := 20, min_size := Vector2(130, 50)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	var styles := {"normal": color, "hover": color.lightened(0.12), "pressed": color.darkened(0.15), "disabled": Color(0.28, 0.29, 0.32)}
	for k in styles:
		var sb := Data.box(styles[k], 10, styles[k].darkened(0.4), 0, 8)
		sb.border_width_bottom = 2 if k == "pressed" else 5
		b.add_theme_stylebox_override(k, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.62))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	b.add_theme_constant_override("outline_size", 4)
	b.pressed.connect(func(): sfx.play("click"))
	b.mouse_entered.connect(func(): if not b.disabled: sfx.play("tick", 1.0, -6.0))
	return b


func _panel(bg: Color, border := Color(1, 1, 1, 0.08), bw := 2, margin := 10, radius := 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Data.box(bg, radius, border, bw, margin))
	return p


func _vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/bg.gdshader")
	bg.material = mat
	add_child(bg)

	world = _layer(self)
	_build_sidebar()
	for t in [[MOD_POS, MAX_MODS], [CONS_POS, MAX_CONS]]:
		var tray := Panel.new()
		tray.add_theme_stylebox_override("panel", Data.box(Color(0, 0, 0, 0.28), 14))
		tray.position = t[0] - Vector2(10, 10)
		tray.size = Vector2(t[1] * 104 + 12, 156)
		tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		world.add_child(tray)
	mods_lbl = _label("", 14, Color(1, 1, 1, 0.7), 4)
	mods_lbl.position = MOD_POS + Vector2(0, 138)
	world.add_child(mods_lbl)
	cons_lbl = _label("", 14, Color(1, 1, 1, 0.7), 4)
	cons_lbl.position = CONS_POS + Vector2(0, 138)
	world.add_child(cons_lbl)

	cards_layer = _layer(world)
	deck_view = _make_card(CardView.BACK, {})
	deck_view.position = DECK_POS
	deck_view.target_pos = DECK_POS
	deck_lbl = _label("", 16, Color.WHITE, 5)
	deck_lbl.position = DECK_POS + Vector2(20, 140)
	deck_lbl.size = Vector2(56, 20)
	world.add_child(deck_lbl)

	hand_bar = _hbox(14)
	hand_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_bar.position = Vector2(HAND_CX - 320, 648)
	hand_bar.size = Vector2(640, 60)
	play_btn = _button("Play Hand", CHIP_COL, 22, Vector2(170, 58))
	play_btn.pressed.connect(play_hand)
	hand_bar.add_child(play_btn)
	var sort_box := _panel(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 6, 10)
	var sv := _vbox(2)
	sv.add_child(_label("Sort Hand", 12, Color(1, 1, 1, 0.8), 3))
	var sh := _hbox(6)
	for by_suit in [false, true]:
		var b := _button("Rank", Color("d9822b"), 14, Vector2(64, 30))
		b.pressed.connect(func(): sort_by_suit = by_suit; _sort_hand(); _layout_hand())
		sh.add_child(b)
		if by_suit:
			sort_suit_btn = b
	sv.add_child(sh)
	sort_box.add_child(sv)
	hand_bar.add_child(sort_box)
	discard_btn = _button("Discard", MULT_COL, 22, Vector2(170, 58))
	discard_btn.pressed.connect(discard)
	hand_bar.add_child(discard_btn)
	world.add_child(hand_bar)

	overlay = _layer(world)
	fx_layer = _layer(self)
	action_box = _hbox(6)
	action_box.hide()
	add_child(action_box)
	_build_title()
	modal_layer = _layer(self)
	_build_tooltip()
	# Cards raise themselves with z_index (hover = 100), and z_index beats tree order,
	# so every layer above the table gets its own z band. Children are relative to it.
	for z in [[overlay, 200], [fx_layer, 400], [action_box, 450], [title_layer, 500], [modal_layer, 600], [tooltip, 900]]:
		z[0].z_index = z[1]
	# version number in the corner; click it to see the changelog
	var ver := Button.new()
	ver.text = "v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	ver.flat = true
	ver.focus_mode = Control.FOCUS_NONE
	ver.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ver.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	ver.add_theme_color_override("font_hover_color", Color("ffd23f"))
	ver.add_theme_color_override("font_pressed_color", Color("ffd23f"))
	ver.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	ver.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ver.position = Vector2(1180, -4)
	ver.size = Vector2(98, 22)
	ver.z_index = 950
	ver.pressed.connect(_show_changelog)
	add_child(ver)
	fps_lbl = _label("", 12, Color("7fe0d0"), 3)
	fps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	fps_lbl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	fps_lbl.position = Vector2(4, -2)
	fps_lbl.size = Vector2(90, 16)
	fps_lbl.z_index = 950
	fps_lbl.visible = show_fps
	add_child(fps_lbl)


func _build_sidebar() -> void:
	var sb := _panel(Color(0.06, 0.08, 0.1, 0.93), Color(1, 1, 1, 0.08), 2, 12, 16)
	sb.position = Vector2(12, 12)
	sb.custom_minimum_size = Vector2(272, 696)
	sb.size = Vector2(272, 696)
	world.add_child(sb)
	var v := _vbox(10)
	sb.add_child(v)

	blind_box = _panel(Color("2c6db5"))
	var bv := _vbox(2)
	blind_name_lbl = _label("", 24)
	blind_desc_lbl = _label("", 13, Color(1, 1, 1, 0.9), 4)
	blind_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blind_desc_lbl.custom_minimum_size = Vector2(230, 0)
	target_lbl = _label("", 18, Color.WHITE)
	reward_lbl = _label("", 15, MONEY_COL, 4)
	for l in [blind_name_lbl, blind_desc_lbl, target_lbl, reward_lbl]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 230
		bv.add_child(l)
	blind_box.add_child(bv)
	v.add_child(blind_box)

	var score_box := _panel(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 8)
	var scv := _vbox(0)
	scv.add_child(_label("Round Score", 14, Color(1, 1, 1, 0.7), 3))
	score_lbl = _label("0", 38)
	scv.add_child(score_lbl)
	score_box.add_child(scv)
	v.add_child(score_box)

	var hb := _panel(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 8)
	var hv := _vbox(4)
	hand_name_lbl = _label(" ", 22)
	hand_poker_lbl = _label(" ", 12, Color(1, 1, 1, 0.55), 3)
	hand_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hand_name_lbl.custom_minimum_size.x = 230
	hv.add_child(hand_name_lbl)
	hv.add_child(hand_poker_lbl)
	var cm := _hbox(6)
	cm.alignment = BoxContainer.ALIGNMENT_CENTER
	var cp := _panel(CHIP_COL, Color(0, 0, 0, 0), 0, 4, 8)
	cp.custom_minimum_size = Vector2(100, 46)
	chips_lbl = _label("0", 28)
	cp.add_child(chips_lbl)
	var mp := _panel(MULT_COL, Color(0, 0, 0, 0), 0, 4, 8)
	mp.custom_minimum_size = Vector2(100, 46)
	mult_lbl = _label("0", 28)
	mp.add_child(mult_lbl)
	cm.add_child(cp)
	cm.add_child(_label("X", 26, MULT_COL))
	cm.add_child(mp)
	hv.add_child(cm)
	hb.add_child(hv)
	v.add_child(hb)

	var counters := _hbox(8)
	for spec in [["Hands", CHIP_COL], ["Discards", MULT_COL]]:
		var p := _panel(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 6)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pv := _vbox(0)
		pv.add_child(_label(spec[0], 13, Color(1, 1, 1, 0.7), 3))
		var l := _label("0", 30, spec[1])
		pv.add_child(l)
		p.add_child(pv)
		counters.add_child(p)
		if spec[0] == "Hands":
			hands_lbl = l
		else:
			discards_lbl = l
	v.add_child(counters)

	var mbox := _panel(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 4)
	money_lbl = _label("$0", 36, MONEY_COL)
	mbox.add_child(money_lbl)
	v.add_child(mbox)

	var ar := _hbox(8)
	for spec in [["Ante", true], ["Race", false]]:
		var p := _panel(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 4)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pv := _vbox(0)
		pv.add_child(_label(spec[0], 13, Color(1, 1, 1, 0.7), 3))
		var l := _label("1", 24, Color("ffb347"))
		pv.add_child(l)
		p.add_child(pv)
		ar.add_child(p)
		if spec[1]:
			ante_lbl = l
		else:
			round_lbl = l
	v.add_child(ar)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var br := _hbox(8)
	var info_btn := _button("Run Info", Color("3a7bd5"), 14, Vector2(118, 40))
	info_btn.pressed.connect(_show_info)
	speed_btn = _button("", Color("6b5bd6"), 14, Vector2(118, 40))
	speed_btn.pressed.connect(func():
		speed_idx = (speed_idx + 1) % SPEEDS.size()
		_update_speed_text()
		_save_settings())
	for b in [info_btn, speed_btn]:
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		br.add_child(b)
	v.add_child(br)
	var br2 := _hbox(8)
	var menu_btn := _button("Menu", Color("555b66"), 14, Vector2(118, 36))
	menu_btn.pressed.connect(_show_menu)
	menu_btn.clip_text = true
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br2.add_child(menu_btn)
	v.add_child(br2)
	var br3 := _hbox(8)
	music_btn = _button("", Color("2f8f83"), 14, Vector2(118, 36))
	music_btn.pressed.connect(_toggle_music)
	sound_btn = _button("", Color("2f8f83"), 14, Vector2(118, 36))
	sound_btn.pressed.connect(_toggle_sfx)
	for b in [music_btn, sound_btn]:
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		br3.add_child(b)
	v.add_child(br3)


func _build_title() -> void:
	title_layer = Control.new()
	title_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(title_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_layer.add_child(dim)
	for i in 9:
		var cv := CardView.new()
		cv.kind = CardView.CAR
		cv.data = {"rank": [14, 13, 12, 11, 10, 11, 12, 13, 14][i], "suit": i % 4, "enh": ["", "", "nitro", "", "gold", "", "turbo", "", ""][i]}
		cv.interactive = false
		var x := i - 4.0
		cv.target_pos = Vector2(640 - 48 + x * 82, 286 + absf(x) * absf(x) * 4)
		cv.position = cv.target_pos + Vector2(0, 500)
		cv.target_rot = x * 0.09
		title_layer.add_child(cv)
	title_lbl = _label("CARLATRO", 124, Color("ffd23f"), 22)
	title_lbl.size = Vector2(1280, 150)
	title_lbl.position = Vector2(0, 70)
	title_lbl.pivot_offset = Vector2(640, 75)
	title_layer.add_child(title_lbl)
	var sub := _label("Cars instead of cards.", 34, Color.WHITE, 10)
	sub.size = Vector2(1280, 40)
	sub.position = Vector2(0, 222)
	title_layer.add_child(sub)
	var bv := _vbox(10)
	bv.position = Vector2(640 - 130, 446)
	bv.custom_minimum_size = Vector2(260, 0)
	bv.add_theme_constant_override("separation", 8)
	continue_btn = _button("Continue", Color("2fa65a"), 26, Vector2(260, 56))
	continue_btn.pressed.connect(_continue_run)
	bv.add_child(continue_btn)
	var play := _button("Start Engine", CHIP_COL, 26, Vector2(260, 56))
	play.pressed.connect(_start_run)
	bv.add_child(play)
	# two small buttons per row keep the menu below the card fan
	var rows := [[["How to Play", Color("d9822b"), _show_help], ["Collection", Color("2f8f83"), _show_collection.bind(-1)]],
		[["Settings", Color("6b5bd6"), _show_settings], ["Statistics", Color("3a7bd5"), _show_stats]]]
	if not OS.has_feature("web"):
		rows.append([["Quit", Color("555b66"), func(): get_tree().quit()]])
	for row in rows:
		var h := _hbox(8)
		for spec in row:
			var b := _button(spec[0], spec[1], 17, Vector2(126 if row.size() > 1 else 260, 40))
			b.clip_text = true
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(spec[2])
			h.add_child(b)
		bv.add_child(h)
	title_layer.add_child(bv)


func _build_tooltip() -> void:
	tooltip = _panel(Color(0.96, 0.95, 0.9, 0.98), Color(0.1, 0.1, 0.12), 3, 10, 10)
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := _vbox(4)
	tip_title = _label("", 18, Color("1b1f27"), 0)
	tip_text = RichTextLabel.new()
	tip_text.bbcode_enabled = true
	tip_text.fit_content = true
	tip_text.scroll_active = false
	tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_text.custom_minimum_size = Vector2(240, 0)
	tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_text.add_theme_color_override("default_color", Color("2b2f38"))
	tip_text.add_theme_font_size_override("normal_font_size", 15)
	v.add_child(tip_title)
	v.add_child(tip_text)
	tooltip.add_child(v)
	tooltip.hide()
	add_child(tooltip)


# ================================================================ helpers

func _make_card(kind: int, data: Dictionary, parent: Node = null) -> Control:
	var cv := CardView.new()
	cv.kind = kind
	cv.data = data
	cv.clicked.connect(_on_card_clicked)
	cv.hover_changed.connect(_on_card_hover)
	(parent if parent else cards_layer).add_child(cv)
	return cv


func _new_card(rank: int, suit: int) -> Dictionary:
	next_id += 1
	return {"id": next_id, "rank": rank, "suit": suit, "enh": ""}


func _has(id: String) -> bool:
	return mods.any(func(m): return m.id == id)


func _active_boss() -> Dictionary:
	return boss if blind_idx == 2 else {}


func _selected() -> Array:
	return hand.filter(func(c): return c.selected)


func _sell_value(m: Dictionary) -> int:
	return maxi(1, int(m.cost / 2.0))


func _fmt(n: float) -> String:
	if absf(n) >= 1e12:
		return "%.3e" % n
	var v := int(roundf(n))
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


func _fmt_mult(m: float) -> String:
	if is_equal_approx(m, roundf(m)) or m >= 1000:
		return _fmt(m)
	return "%.1f" % m


func _bb(s: String) -> String:
	return s.replace("[c]", "[color=#1f6fe0]").replace("[m]", "[color=#e8332a]").replace("[x]", "[color=#b02ad8]") \
		.replace("[$]", "[color=#c98f00]").replace("[g]", "[color=#1f8a45]").replace("[/]", "[/color]")


## Same markup as _bb, with brighter colors for dark panels.
func _bb_dark(s: String) -> String:
	return _bb(s).replace("#1f6fe0", "#4aa3ff").replace("#e8332a", "#ff5d52").replace("#b02ad8", "#d77cff") \
		.replace("#c98f00", "#ffc93c").replace("#1f8a45", "#5fd38a")


func _mod_val_str(m: Dictionary) -> String:
	match m.id:
		"car_show": return str(4 * mods.size())
		"scrap_collector": return str(3 * maxi(0, 52 - deck.size()))
		"getaway": return Scoring.num_str(m.get("val", 1.0))
	return str(m.get("val", 0))


func _punch_label(l: Label, amount := 0.25) -> void:
	l.pivot_offset = l.size / 2
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE * (1.0 + amount), 0.05)
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _popup(text: String, pos: Vector2, color: Color, size := 22) -> void:
	var p := _panel(color, color.darkened(0.45), 2, 6, 8)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(text, size, Color.WHITE, 5)
	p.add_child(l)
	fx_layer.add_child(p)
	p.reset_size()
	p.position = pos - p.size / 2
	p.pivot_offset = p.size / 2
	p.scale = Vector2(0.3, 0.3)
	p.rotation = randf_range(-0.12, 0.12)
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p, "position:y", p.position.y - 34, 0.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.25)
	tw.tween_callback(p.queue_free)


func _message(text: String, color := ACCENT) -> void:
	sfx.play("error")
	_popup(text, Vector2(HAND_CX, PLAY_Y + 60), color, 22)


func _sparks(pos: Vector2, color: Color, amount := 18) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 340.0
	p.gravity = Vector2(0, 700)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = color
	fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _confetti() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(790, -20)
	p.amount = 160
	p.lifetime = 2.6
	p.one_shot = true
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(520, 10)
	p.direction = Vector2(0, 1)
	p.spread = 35.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 260)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	g.colors = PackedColorArray([Color("e2443a"), Color("f08a24"), Color("ffd23f"), Color("3b6fd6"), Color("3ecf6a")])
	p.color_initial_ramp = g
	fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(4.0).timeout.connect(p.queue_free)


func _vanish(cv: Control) -> void:
	cv.set_process(false)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(cv, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(cv, "modulate:a", 0.0, 0.25)
	tw.tween_callback(cv.queue_free)


# ================================================================ layout

func _layout_hand() -> void:
	var n := hand.size()
	if n == 0:
		return
	var spacing := minf(104.0, (820.0 - CardView.SIZE.x) / maxf(n - 1, 1))
	var x0 := HAND_CX - (spacing * (n - 1) + CardView.SIZE.x) / 2
	for i in n:
		var c = hand[i]
		var t := 0.0 if n == 1 else (i - (n - 1) / 2.0) / ((n - 1) / 2.0)
		c.target_pos = Vector2(x0 + i * spacing, HAND_Y + t * t * 12)
		c.target_rot = t * 0.07
		c.base_z = i
		if not c.hovered:
			c.z_index = i


func _layout_row(views: Array, y: float, cx: float, spacing := 108.0) -> void:
	var x0 := cx - (spacing * (views.size() - 1) + CardView.SIZE.x) / 2
	for i in views.size():
		views[i].target_pos = Vector2(x0 + i * spacing, y)
		views[i].target_rot = 0.0
		views[i].base_z = i
		views[i].z_index = i


## Negative mods add a slot each.
func _mod_slots() -> int:
	return MAX_MODS + mods.filter(func(m): return m.get("edition", "") == "negative").size() + int(_voucher("antimatter"))


func _cons_slots() -> int:
	return MAX_CONS + int(_voucher("crystal_ball"))


func _voucher(id: String) -> bool:
	return vouchers.has(id)


## Shop price after the Clearance Sale voucher.
func _price(cost: int) -> int:
	return maxi(1, int(cost * 0.75)) if _voucher("clearance") else cost


## A new voucher offer every ante, from the ones not bought yet.
func _roll_voucher() -> void:
	var pool := Data.VOUCHERS.filter(func(v): return not vouchers.has(v.id))
	voucher_offer = "" if pool.is_empty() else pool[rng.randi() % pool.size()].id


## Maybe give a new mod an edition (foil, holo, polychrome, negative); it costs more.
func _roll_edition(m: Dictionary) -> Dictionary:
	var r := rng.randf() * 100.0
	for e in Data.EDITIONS:
		r -= Data.EDITIONS[e].weight * (2.0 if _voucher("hone") else 1.0)
		if r < 0.0:
			m.edition = e
			m.cost += Data.EDITIONS[e].extra
			break
	return m


func _layout_slots() -> void:
	# squeeze extra (negative) mods into the tray
	var step := minf(104.0, (MAX_MODS * 104.0 - CardView.SIZE.x) / maxf(mod_views.size() - 1, 1))
	for i in mod_views.size():
		mod_views[i].target_pos = MOD_POS + Vector2(i * step, 0)
		mod_views[i].target_rot = 0.0
		mod_views[i].base_z = i
	var cstep := minf(104.0, (MAX_CONS * 104.0 - CardView.SIZE.x) / maxf(cons_views.size() - 1, 1))
	for i in cons_views.size():
		cons_views[i].target_pos = CONS_POS + Vector2(i * cstep, 0)
		cons_views[i].target_rot = 0.0


func _sort_hand() -> void:
	hand.sort_custom(func(a, b):
		var ka: int = a.data.suit * 100 - a.data.rank if sort_by_suit else -a.data.rank * 10 + a.data.suit
		var kb: int = b.data.suit * 100 - b.data.rank if sort_by_suit else -b.data.rank * 10 + b.data.suit
		return ka < kb)


# ================================================================ sidebar

func _update_sidebar() -> void:
	var name := "Choose a Race"
	var desc := "Pick your next race"
	var col := Color("33415c")
	var tgt := ""
	var rew := ""
	if state in ["play", "cashout", "end"]:
		var info := _blind_info(blind_idx)
		name = info.name
		desc = info.desc
		col = info.color
		tgt = tr("Score at least") + "  " + _fmt(target)
		rew = tr("Reward:") + " " + "$".repeat(info.reward)
	elif state == "shop":
		name = "Pit Stop"
		desc = "Upgrade your ride"
		col = Color("8c1c13")
	elif state == "title":
		name = "Carlatro"
		desc = "Cars instead of cards"
	blind_name_lbl.text = tr(name)
	blind_desc_lbl.text = tr(desc)
	target_lbl.text = tgt
	target_lbl.visible = tgt != ""
	reward_lbl.text = rew
	reward_lbl.visible = rew != ""
	blind_box.add_theme_stylebox_override("panel", Data.box(col.darkened(0.15), 12, col.lightened(0.25), 2, 10))
	score_lbl.text = _fmt(score)
	hands_lbl.text = str(hands_left)
	discards_lbl.text = str(discards_left)
	money_lbl.text = "$%d" % money
	ante_lbl.text = str(ante) if endless else "%d/8" % ante
	round_lbl.text = str(round_num)
	mods_lbl.text = Data.tv("Mods", "Jokers") + " %d/%d" % [mods.size(), _mod_slots()]
	cons_lbl.text = Data.tv("Garage", "Items") + " %d/%d" % [consumables.size(), _cons_slots()]
	deck_view.visible = state == "play"
	deck_lbl.visible = deck_view.visible
	deck_lbl.text = "%d/%d" % [draw_pile.size(), deck.size()]
	_update_buttons()
	music.set_muffled(state == "shop")
	_save_run()


func _update_buttons() -> void:
	hand_bar.visible = state == "play"
	var n := _selected().size()
	var need5: bool = _active_boss().get("id", "") == "full_load"
	play_btn.disabled = busy or n == 0 or (need5 and n != 5)
	discard_btn.disabled = busy or n == 0 or discards_left <= 0


func _set_hand_info(name: String, poker: String, chips: float, mult: float) -> void:
	if hand_name_lbl.text != name and name != " ":
		_punch_label(hand_name_lbl, 0.15)
	hand_name_lbl.text = name
	hand_poker_lbl.text = poker
	chips_lbl.text = _fmt(chips)
	mult_lbl.text = _fmt_mult(mult)


func _show_hand_type(t: int, chips: float, mult: float) -> void:
	var h = Data.HANDS[t]
	_set_hand_info("%s  %s%d" % [tr(Data.hand_name(t)), tr("lvl."), levels[t]], " " if Data.classic_art else tr(h.poker), chips, mult)


func _update_preview() -> void:
	if busy:
		return
	var sel := _selected()
	if sel.is_empty():
		_set_hand_info(" ", " ", 0, 0)
		return
	var t: int = Scoring.evaluate(sel.map(func(c): return c.data)).type
	var h = Data.HANDS[t]
	var lvl: int = levels[t]
	_show_hand_type(t, h.chips + h.lc * (lvl - 1), h.mult + h.lm * (lvl - 1))


# ================================================================ input

func _on_card_clicked(cv: Control) -> void:
	if hand.has(cv):
		if busy or state != "play":
			return
		if cv.selected:
			cv.selected = false
		elif _selected().size() < 5:
			cv.selected = true
		else:
			cv.punch(0.08)
			sfx.play("error", 1.0, -6.0)
			return
		sfx.play("card", randf_range(1.1, 1.3))
		_update_preview()
		_update_buttons()
	elif mod_views.has(cv):
		_show_action(cv, [[tr("Sell") + " $%d" % _sell_value(cv.data), _sell_mod.bind(cv), MONEY_COL.darkened(0.2)]])
	elif cons_views.has(cv):
		_show_action(cv, [["Use", _use_cons.bind(cv), CHIP_COL], [tr("Sell") + " $1", _sell_cons.bind(cv), MONEY_COL.darkened(0.2)]])
	elif shop_views.has(cv):
		_show_action(cv, [["Buy", _buy.bind(cv), Color("3ecf6a").darkened(0.15)]])
	elif pack_views.has(cv):
		_show_action(cv, [["Take", _take_pack.bind(cv), Color("3ecf6a").darkened(0.15)]])
	elif cv == deck_view and state != "title":
		_show_deck()
	elif gallery_backs.has(cv):
		Data.back_style = cv.back_style
		_save_settings()
		get_tree().call_group("cards", "queue_redraw")
		sfx.play("card")
		_show_collection()


func _on_card_hover(cv: Control, on: bool) -> void:
	if on:
		sfx.play("tick", randf_range(0.9, 1.1), -10.0)
	if not on:
		if tip_card == cv:
			tip_card = null
			tooltip.hide()
		return
	var info := _tip_for(cv)
	if info.is_empty():
		return
	tip_title.text = info[0]
	tip_text.text = _bb(info[1])
	tip_card = cv
	tip_above = cv.global_position.y + CardView.SIZE.y * cv.scale.y / 2 > 360
	tip_frames = 0
	tooltip.modulate.a = 0.0
	tooltip.reset_size()
	tooltip.show()


func _tip_for(cv: Control) -> Array:
	var d: Dictionary = cv.data
	match cv.kind:
		CardView.CAR:
			if cv.face_down:
				return []
			var rank: int = d.rank
			var lines := ["[c]+%d[/] %s" % [Scoring.chip_value(rank), tr("Chips")]]
			var enh: String = d.get("enh", "")
			if enh != "":
				lines.append("[g]%s:[/] %s" % [Data.text(Data.ENH_INFO[enh], "name"), tr(Data.ENH_INFO[enh].desc)])
			if Scoring.is_face(rank):
				lines.append("[g]%s[/]" % Data.tv("Face car (J, Q, K)", "Face card (J, Q, K)"))
			if rank == 14:
				lines.append(tr("Counts high or low in a %s") % tr(Data.hand_name(Scoring.STRAIGHT)))
			if cv.debuffed:
				lines.append(Data.tv("[m]Debuffed:[/] this car gives no chips\nand no effects in this race", "[m]Debuffed:[/] this card gives no chips\nand no effects in this race"))
			return ["%s · %s" % [tr(Data.rank_name(rank)), tr(Data.suit_name(d.suit))], "\n".join(lines)]
		CardView.MOD:
			var s := Data.text(d, "desc").replace("{val}", _mod_val_str(d))
			if d.get("edition", "") != "":
				var ed: Dictionary = Data.EDITIONS[d.edition]
				s += "\n[g]%s:[/] %s" % [Data.text(ed, "name"), Data.text(ed, "desc")]
			if cv.price < 0:
				s += "\n[$]%s $%d[/]" % [tr("Sells for"), _sell_value(d)]
			return [Data.text(d, "name"), s]
		CardView.CONS:
			var title := ""
			var s := ""
			if d.id == "tune":
				var h = Data.HANDS[d.hand]
				var hn := tr(Data.hand_name(d.hand))
				title = Data.tv("Dyno: %s", "Upgrade: %s") % hn
				if Data.classic_art:
					s = tr("Level up [g]%s[/]\n[c]+%d[/] Chips, [m]+%d[/] Mult") % [hn, h.lc, h.lm]
				else:
					s = tr("Level up [g]%s[/] (%s)\n[c]+%d[/] Chips, [m]+%d[/] Mult") % [hn, tr(h.poker), h.lc, h.lm]
			else:
				title = Data.text(d, "name")
				s = Data.text(d, "desc")
			var need: Array = d.get("need", [0, 0])
			if need[1] > 0:
				var n := str(need[1]) if need[0] == need[1] else "1-%d" % need[1]
				s += "\n[g]%s[/]" % (Data.tv("Select %s cars in hand, then Use", "Select %s cards in hand, then Use") % n)
			else:
				s += "\n[g]%s[/]" % tr("Use any time")
			return [title, s]
		CardView.PACK:
			return [Data.text(d, "name"), Data.text(d, "desc")]
		CardView.VOUCHER:
			return [Data.text(d, "name"), Data.text(d, "desc") + "\n[g]%s[/]" % tr("Lasts for the whole run")]
		CardView.BACK:
			if gallery_backs.has(cv):
				return [tr(Data.BACKS[cv.back_style]), tr("Click a back to use it")]
			if state == "title":
				return []
			return [Data.tv("Your Garage", "Your Deck"), Data.tv("Cars in garage: %d", "Cards in deck: %d") % deck.size() + "\n" + tr("Left to draw: %d") % draw_pile.size() + "\n[g]" + tr("Click to view") + "[/]"]
	return []


func _show_action(cv: Control, actions: Array) -> void:
	if action_card == cv:
		_hide_action()
		return
	_clear(action_box)
	for a in actions:
		var b := _button(a[0], a[2], 16, Vector2(86, 38))
		b.pressed.connect(func():
			_hide_action()
			a[1].call())
		action_box.add_child(b)
	action_card = cv
	action_box.show()


func _unhover(c: Control) -> void:
	c.hovered = false
	if tip_card == c:
		tip_card = null
		tooltip.hide()


func _update_speed_text() -> void:
	speed_btn.text = tr("Speed") + " %sx" % Scoring.num_str(SPEEDS[speed_idx])


func _lang_idx() -> int:
	var loc := TranslationServer.get_locale()
	for i in LANGS.size():
		if loc.begins_with(LANGS[i][0].substr(0, 2)):
			return i
	return 0


func _refresh_texts() -> void:
	music_btn.text = tr("Music: On") if music_on else tr("Music: Off")
	sound_btn.text = tr("Sound: On") if sfx_on else tr("Sound: Off")
	for spec in [[music_btn, music_on], [sound_btn, sfx_on]]:
		var col := Color("2f8f83") if spec[1] else Color("3a3f4b")
		for k in ["normal", "hover", "pressed"]:
			var sb: StyleBoxFlat = spec[0].get_theme_stylebox(k).duplicate()
			sb.bg_color = col.lightened(0.12) if k == "hover" else (col.darkened(0.15) if k == "pressed" else col)
			spec[0].add_theme_stylebox_override(k, sb)
	sort_suit_btn.text = tr("Suit") if Data.classic_suits else tr("Class")
	_update_speed_text()
	_update_sidebar()


func _hide_action() -> void:
	action_box.hide()
	action_card = null


# ================================================================ run flow

func _show_title() -> void:
	state = "title"
	_clear_views()
	_clear(overlay)
	title_layer.visible = true
	world.visible = false  # the table UI exists only during a run
	money = 0
	score = 0
	hands_left = 0
	discards_left = 0
	_set_hand_info(" ", " ", 0, 0)
	_update_sidebar()
	continue_btn.visible = FileAccess.file_exists(SAVE_PATH)


func _clear_views() -> void:
	pack_open = {}
	for arr in [hand, mod_views, cons_views, shop_views, pack_views]:
		for cv in arr:
			cv.queue_free()
		arr.clear()
	_hide_action()


func _start_run() -> void:
	_stats_add({"runs_started": 1})
	result_recorded = false
	title_layer.visible = false
	world.visible = true
	_clear_views()
	_clear(overlay)
	ante = 1
	blind_idx = 0
	round_num = 0
	money = 4
	endless = false
	best_hand = 0
	score = 0
	deck = []
	for s in 4:
		for r in range(2, 15):
			deck.append(_new_card(r, s))
	draw_pile = []
	levels = []
	levels.resize(Data.HANDS.size())
	levels.fill(1)
	played_count = []
	played_count.resize(Data.HANDS.size())
	played_count.fill(0)
	mods = []
	consumables = []
	vouchers = []
	last_boss_name = ""
	_pick_boss()
	_show_blind_select()


func _pick_boss() -> void:
	_roll_voucher()
	if ante % 8 == 0:
		boss = Data.FINAL_BOSS
		return
	var pool := Data.BOSSES.filter(func(b): return b.get("min_ante", 1) <= ante and b.name != last_boss_name)
	boss = pool[rng.randi() % pool.size()]
	last_boss_name = boss.name


func _blind_target(i: int) -> int:
	var m: float = [1.0, 1.5, boss.get("mult", 2.0)][i]
	return int(Data.ante_base(ante) * m)


func _blind_info(i: int) -> Dictionary:
	match i:
		0: return {"name": "Street Race", "desc": "A quick sprint through town", "color": Color("2c6db5"), "reward": 3}
		1: return {"name": "Circuit Race", "desc": "A full lap of the circuit", "color": Color("c77d16"), "reward": 4}
	return {"name": Data.text(boss, "name"), "desc": Data.text(boss, "desc"), "color": boss.color, "reward": 5}


func _show_blind_select() -> void:
	state = "blind"
	_clear(overlay)
	score = 0
	hands_left = 0
	discards_left = 0
	_set_hand_info(" ", " ", 0, 0)
	_update_sidebar()
	var hdr := _label(tr("ANTE") + " %d" % ante, 34, Color("ffb347"), 10)
	hdr.size = Vector2(980, 40)
	hdr.position = Vector2(300, 182)
	overlay.add_child(hdr)
	for i in 3:
		var info := _blind_info(i)
		var cur := i == blind_idx
		var p := _panel(PANEL_BG, info.color if cur else Color(1, 1, 1, 0.1), 4 if cur else 2, 14, 14)
		p.position = Vector2(352 + i * 300, 232)
		p.custom_minimum_size = Vector2(270, 400)
		if not cur:
			p.modulate = Color(1, 1, 1, 0.55)
		var v := _vbox(8)
		p.add_child(v)
		var head := _panel(info.color, info.color.lightened(0.3), 2, 6, 8)
		head.add_child(_label(info.name, 23))
		v.add_child(head)
		v.add_child(_flag_icon(info.color, boss if i == 2 else {}))
		v.add_child(_label("Score at least", 15, Color(1, 1, 1, 0.7), 3))
		v.add_child(_label(_fmt(_blind_target(i)), 34, MULT_COL))
		v.add_child(_label(tr("Reward:") + " " + "$".repeat(info.reward), 18, MONEY_COL))
		var d := _label(info.desc, 15, Color(0.88, 0.88, 0.92), 3)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(240, 44)
		v.add_child(d)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(spacer)
		if cur:
			var b := _button("Race!", ACCENT, 26, Vector2(200, 58))
			b.pressed.connect(_start_race)
			v.add_child(b)
		else:
			v.add_child(_label("Defeated" if i < blind_idx else "Upcoming", 20, Color(1, 1, 1, 0.6)))
		overlay.add_child(p)
		p.pivot_offset = Vector2(135, 200)
		p.scale = Vector2(0.85, 0.85)
		var tw := create_tween()
		tw.tween_interval(i * 0.07)
		tw.tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flag_icon(color: Color, b: Dictionary) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 92)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var ctr := Vector2(c.size.x / 2, 46)
		c.draw_circle(ctr, 43, color.darkened(0.5))
		c.draw_circle(ctr, 37, color)
		if not b.is_empty():
			c.draw_circle(ctr, 33, color.darkened(0.35))
			Art.boss_art(c, b, ctr, 1.15)
			c.draw_arc(ctr, 40, 0, TAU, 48, Color("ffd23f"), 3.0, true)
			return
		for gx in range(-3, 3):
			for gy in range(-3, 3):
				var sq := ctr + Vector2(gx * 10 + 5, gy * 10 + 5)
				if (sq - ctr).length() < 30 and (gx + gy) % 2 == 0:
					c.draw_rect(Rect2(ctr + Vector2(gx * 10, gy * 10), Vector2(10, 10)), Color(1, 1, 1, 0.85)))
	return c


func _start_race() -> void:
	if state != "blind":
		return
	_clear(overlay)
	state = "play"
	round_num += 1
	score = 0
	target = _blind_target(blind_idx)
	hands_played = 0
	played_types = []
	hands_left = 4 + int(_has("pit_crew")) + int(_voucher("grabber"))
	discards_left = 3 + int(_has("tow_truck")) + int(_voucher("wasteful"))
	hand_size = 8 + int(_has("big_trunk")) + int(_voucher("paint_brush"))
	match _active_boss().get("id", ""):
		"rain": discards_left = 0
		"flat_tire": hand_size -= 1
		"time_trial": hands_left = 1
	draw_pile = deck.duplicate()
	draw_pile.shuffle()
	_set_hand_info(" ", " ", 0, 0)
	_update_sidebar()
	sfx.play("engine")
	busy = true
	_update_buttons()
	await _draw_to_full()
	busy = false
	_update_sidebar()


func _draw_to_full() -> void:
	var b := _active_boss()
	while hand.size() < hand_size and not draw_pile.is_empty():
		var cv := _make_card(CardView.CAR, draw_pile.pop_back())
		cv.position = DECK_POS
		cv.rotation = 0.4
		cv.debuffed = Scoring.card_debuffed(cv.data, b)
		cv.face_down = true
		cv.flip_up(0.15)
		hand.append(cv)
		_layout_hand()
		sfx.play("card", randf_range(0.9, 1.15), -4.0)
		deck_lbl.text = "%d/%d" % [draw_pile.size(), deck.size()]
		await wait(0.06)
	_sort_hand()
	_layout_hand()


func play_hand() -> void:
	var sel := _selected()
	if busy or sel.is_empty() or state != "play":
		return
	if _active_boss().get("id", "") == "full_load" and sel.size() != 5:
		_message(Data.tv("Must play exactly 5 cars!", "Must play exactly 5 cards!"))
		return
	busy = true
	_hide_action()
	sel.sort_custom(func(a, b): return hand.find(a) < hand.find(b))
	for c in sel:
		hand.erase(c)
		c.selected = false
		_unhover(c)
	_layout_row(sel, PLAY_Y, HAND_CX)
	_layout_hand()
	_update_buttons()
	sfx.play("engine")
	if _active_boss().get("id", "") == "toll":
		money = maxi(0, money - sel.size())
		_popup("-$%d %s" % [sel.size(), tr("Toll")], Vector2(148, 470), MONEY_COL.darkened(0.3))
	await wait(0.45)

	var ctx := {"boss": _active_boss(), "hands_left": hands_left, "hands_played": hands_played,
		"deck_size": deck.size(), "played_types": played_types}
	var res := Scoring.score_hand(sel.map(func(c): return c.data), mods, levels, ctx, rng)
	hands_left -= 1
	hands_played += 1
	played_types.append(res.type)
	played_count[res.type] += 1
	stats.hand_counts[res.type] += 1
	_stats_add({"hands_played": 1, "cards_played": sel.size()}, {"best_hand": res.total})
	_update_sidebar()
	_show_hand_type(res.type, res.base_chips, res.base_mult)
	for i in res.scoring:
		sel[i].lift = 26
	sfx.play("click")
	await wait(0.4)

	var step := 0
	for e in res.events:
		await _animate_event(e, sel, step)
		step += 1

	var total: int = res.total
	best_hand = maxi(best_hand, total)
	_popup("+" + _fmt(total), Vector2(HAND_CX, PLAY_Y - 34), Color("1b1f27"), 34)
	sfx.play("score")
	if total >= target / 2:
		shake = 8.0
	var start := score
	score += total
	var tw := create_tween()
	tw.tween_method(func(v: float): score_lbl.text = _fmt(v), float(start), float(score), 0.6 / SPEEDS[speed_idx])
	await tw.finished
	_punch_label(score_lbl, 0.3)
	if score >= target:
		score_lbl.add_theme_color_override("font_color", MONEY_COL)
		var tw2 := create_tween()
		tw2.tween_interval(0.8)
		tw2.tween_callback(func(): score_lbl.add_theme_color_override("font_color", Color.WHITE))

	for i in res.broken:
		var cv = sel[i]
		_remove_from_deck(cv.data)
		_sparks(cv.global_position + CardView.SIZE / 2, Color("aab4c3"), 30)
		_popup("Broken!", cv.global_position + Vector2(48, -20), Color("555b66"))
		sfx.play("break")
		_vanish(cv)
	var keep := []
	for i in sel.size():
		if not res.broken.has(i):
			keep.append(sel[i])
	await wait(0.35)
	for cv in keep:
		cv.lift = 0
		cv.target_pos = Vector2(1400, PLAY_Y - 60)
		cv.target_rot = 0.8
	sfx.play("card", 0.8)
	await wait(0.35)
	for cv in keep:
		cv.queue_free()
	_set_hand_info(" ", " ", 0, 0)
	_update_sidebar()

	if score >= target:
		await _round_won()
		return
	if hands_left <= 0 or (hand.is_empty() and draw_pile.is_empty()):
		_show_end(false)
		return
	await _draw_to_full()
	busy = false
	_update_sidebar()


func _animate_event(e: Dictionary, sel: Array, step: int) -> void:
	var view: Control
	var below := false
	match e.src:
		"card": view = sel[e.i]
		"mod":
			view = mod_views[e.i]
			below = true
		_: view = null
	if e.at >= 0:
		sel[e.at].punch(0.12)
	var pos := Vector2(HAND_CX, PLAY_Y + 60)
	if view:
		view.punch()
		pos = view.global_position + Vector2(CardView.SIZE.x / 2, CardView.SIZE.y + 22 if below else -20)
	var pitch := 1.0 + minf(step, 24) * 0.035
	match e.kind:
		"chips":
			_popup("+%d" % e.v, pos, CHIP_COL)
			sfx.play("chips", pitch)
			_punch_label(chips_lbl)
		"mult":
			_popup("+%d %s" % [e.v, tr("Mult")], pos, MULT_COL)
			sfx.play("mult", pitch)
			_punch_label(mult_lbl)
		"xmult":
			_popup("X%s %s" % [Scoring.num_str(e.v), tr("Mult")], pos, Color("b02ad8"), 26)
			sfx.play("xmult")
			_punch_label(mult_lbl, 0.5)
			shake = 7.0
			_sparks(pos, Color("ff7af0"))
		"money":
			money += int(e.v)
			_popup("+$%d" % e.v, pos, MONEY_COL.darkened(0.15))
			sfx.play("coin")
			_punch_label(money_lbl)
			money_lbl.text = "$%d" % money
		"again":
			_popup(tr("Again!"), pos, Color("d9822b"))
			sfx.play("click", 0.8)
		"debuff":
			_popup(tr("Debuffed"), pos, Color("555b66"))
			sfx.play("error", 1.0, -4.0)
		"zero":
			_popup(tr("Already played!"), pos, Color("555b66"), 28)
			sfx.play("error")
	chips_lbl.text = _fmt(e.c)
	mult_lbl.text = _fmt_mult(e.m)
	await wait(0.18 if e.kind == "again" else 0.34)


func discard() -> void:
	var sel := _selected()
	if busy or sel.is_empty() or discards_left <= 0 or state != "play":
		return
	busy = true
	_hide_action()
	discards_left -= 1
	_stats_add({"discards": 1})
	for c in sel:
		hand.erase(c)
		c.selected = false
		_unhover(c)
		c.target_pos = Vector2(1400, c.target_pos.y - 120)
		c.target_rot = 0.7
	sfx.play("card", 0.8)
	_layout_hand()
	_set_hand_info(" ", " ", 0, 0)
	_update_sidebar()
	await wait(0.3)
	for c in sel:
		c.queue_free()
	await _draw_to_full()
	busy = false
	_update_sidebar()


func _remove_from_deck(card: Dictionary) -> void:
	deck = deck.filter(func(d): return d.id != card.id)
	draw_pile = draw_pile.filter(func(d): return d.id != card.id)


func _round_won() -> void:
	state = "cashout"
	_stats_add({"races_won": 1, "bosses_beaten": 1 if blind_idx == 2 else 0}, {"best_ante": ante})
	sfx.play("win")
	_confetti()
	_popup("RACE WON!", Vector2(HAND_CX, PLAY_Y + 40), ACCENT, 40)
	await wait(0.8)
	for c in hand:
		c.target_pos.y = 900
	await wait(0.35)
	for c in hand:
		c.queue_free()
	hand.clear()
	var info := _blind_info(blind_idx)
	var lines := [[tr("%s won") % tr(info.name), info.reward]]
	if hands_left > 0:
		lines.append([tr("Remaining hands") + " (%d)" % hands_left, hands_left])
	var cap := 10 if _voucher("seed_money") else 5
	var interest := mini(floori(money / 5.0), cap)
	if interest > 0:
		lines.append([tr("Interest ($1 per $5, max $%d)") % cap, interest])
	for m in mods:
		if m.id == "gas_station":
			lines.append([Data.text(m, "name"), 4])
		if m.id == "street_cred" and discards_left > 0:
			lines.append([Data.text(m, "name"), discards_left])
		if m.id == "getaway" and blind_idx == 2:
			m.val = m.get("val", 1.0) + 0.25
	busy = false
	if blind_idx == 2 and ante == 8 and not endless:
		_show_end(true, lines)
		return
	_show_cashout(lines)


func _show_cashout(lines: Array) -> void:
	state = "cashout"
	cashout_lines = lines
	_clear(overlay)
	_update_sidebar()
	var p := _panel(PANEL_BG, ACCENT, 3, 18, 16)
	p.position = Vector2(520, 200)
	p.custom_minimum_size = Vector2(500, 0)
	var v := _vbox(10)
	p.add_child(v)
	v.add_child(_label("RACE WON!", 38, MONEY_COL, 10))
	var total := 0
	var rows := []
	for ln in lines:
		total += ln[1]
		var h := _hbox(8)
		var l := _label(ln[0], 18, Color.WHITE, 4)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(_label("$%d" % ln[1], 22, MONEY_COL, 5))
		h.modulate.a = 0.0
		v.add_child(h)
		rows.append(h)
	var b := _button(tr("Cash Out:") + " $%d" % total, ACCENT, 24, Vector2(300, 60))
	b.pressed.connect(func():
		money += total
		_stats_add({"money_earned": total})
		sfx.play("coin")
		_open_shop())
	v.add_child(b)
	overlay.add_child(p)
	for i in rows.size():
		var tw := create_tween()
		tw.tween_interval(0.12 * i / SPEEDS[speed_idx])
		tw.tween_callback(func(): sfx.play("coin", 1.0 + i * 0.08, -6.0))
		tw.tween_property(rows[i], "modulate:a", 1.0, 0.15)


# ================================================================ shop

func _open_shop(saved := {}) -> void:
	state = "shop"
	reroll_cost = saved.get("reroll_cost", 3 if _voucher("reroll_surplus") else 5)
	_clear(overlay)
	shop_panel = Panel.new()
	shop_panel.add_theme_stylebox_override("panel", Data.box(PANEL_BG, 16, ACCENT, 3))
	shop_panel.position = Vector2(326, 196)
	shop_panel.size = Vector2(928, 456)
	overlay.add_child(shop_panel)
	var t := _label("PIT STOP", 30, ACCENT, 8)
	t.size = Vector2(928, 40)
	t.position = Vector2(0, 8)
	shop_panel.add_child(t)
	var next_btn := _button("Next Race", MULT_COL, 22, Vector2(170, 70))
	next_btn.position = Vector2(26, 76)
	next_btn.clip_text = true
	next_btn.pressed.connect(_next_race)
	shop_panel.add_child(next_btn)
	reroll_btn = _button("", Color("2fa65a"), 20, Vector2(170, 70))
	reroll_btn.position = Vector2(26, 170)
	reroll_btn.clip_text = true
	reroll_btn.pressed.connect(_reroll)
	shop_panel.add_child(reroll_btn)
	for s in [[Data.tv("MODS", "JOKERS"), 230.0, 50.0, 3], [Data.tv("GARAGE", "ITEMS"), 622.0, 50.0, 2], [tr("BOOSTER PACKS"), 230.0, 250.0, 2],
			[Data.tv("SPONSOR", "VOUCHER"), 622.0, 250.0, 2]]:
		var l := _label(s[0], 14, Color(1, 1, 1, 0.6), 3)
		l.size = Vector2(s[3] * 112 - 16, 20)
		l.position = Vector2(s[1], s[2])
		shop_panel.add_child(l)
	_fill_shop(saved.get("shop_items", []))
	if not saved.has("shop_items") and voucher_offer != "":
		var vd: Dictionary = Data.VOUCHERS.filter(func(v): return v.id == voucher_offer)[0].duplicate(true)
		var vcv := _make_card(CardView.VOUCHER, vd, shop_panel)
		vcv.price = _price(Data.VOUCHER_COST)
		_shop_place(vcv, Vector2(678, 300), 7)
	if saved.get("pack_open", {}).has("data"):
		_open_pack(saved.pack_open.data, saved.pack_open.choices)
	_update_sidebar()


func _fill_shop(saved_items := []) -> void:
	# a reroll replaces everything except the voucher
	for cv in shop_views.filter(func(v): return v.kind != CardView.VOUCHER):
		cv.queue_free()
		shop_views.erase(cv)
	reroll_btn.text = tr("Reroll") + " $%d" % reroll_cost
	if not saved_items.is_empty():
		for i in saved_items.size():
			var it: Dictionary = saved_items[i]
			var scv := _make_card(it.kind, it.data, shop_panel)
			scv.price = it.price
			_shop_place(scv, it.pos, i)
		return
	var taken: Array = mods.map(func(m): return m.id)
	for i in 3:
		var def := _random_mod(taken)
		if def.is_empty():
			continue
		taken.append(def.id)
		var md := _roll_edition(def.duplicate(true))
		md.cost = _price(md.cost)
		var cv := _make_card(CardView.MOD, md, shop_panel)
		cv.price = md.cost
		_shop_place(cv, Vector2(230 + i * 112, 112), i)
	var all := Data.consumables()
	var tunes := all.filter(func(x): return x.id == "tune")
	var work := all.filter(func(x): return x.id != "tune")
	var p_tune := float(tunes.size()) / all.size() + 0.3 * int(_voucher("tune_merchant")) - 0.3 * int(_voucher("workshop_merchant"))
	for i in 2:
		var pool: Array = tunes if rng.randf() < p_tune else work
		var c: Dictionary = pool[rng.randi() % pool.size()]
		var cv := _make_card(CardView.CONS, c, shop_panel)
		cv.price = _price(c.cost)
		_shop_place(cv, Vector2(622 + i * 112, 112), i + 3)
	for i in 2:
		var pk := _random_pack()
		var cv := _make_card(CardView.PACK, pk.duplicate(true), shop_panel)
		cv.price = _price(pk.cost)
		_shop_place(cv, Vector2(230 + i * 112, 300), i + 5)


func _shop_place(cv: Control, pos: Vector2, i: int) -> void:
	cv.position = pos + Vector2(0, 260 + i * 20)
	cv.target_pos = pos
	shop_views.append(cv)


func _random_mod(exclude: Array) -> Dictionary:
	var pool := Data.MODS.filter(func(m): return not exclude.has(m.id))
	if pool.is_empty():
		return {}
	var total := 0.0
	for m in pool:
		total += Data.RARITY_WEIGHTS[m.get("rarity", 0)]
	var r := rng.randf() * total
	for m in pool:
		r -= Data.RARITY_WEIGHTS[m.get("rarity", 0)]
		if r <= 0.0:
			return m
	return pool[-1]


func _reroll() -> void:
	if money < reroll_cost:
		_message("Not enough cash!")
		return
	money -= reroll_cost
	reroll_cost += 1
	sfx.play("coin", 0.9)
	_fill_shop()
	_update_sidebar()


func _buy(cv: Control) -> void:
	if state != "shop" or not shop_views.has(cv):
		return
	if money < cv.price:
		_message("Not enough cash!")
		return
	if cv.kind == CardView.MOD and mods.size() >= _mod_slots() and cv.data.get("edition", "") != "negative":
		_message(Data.tv("Mod slots are full!", "Joker slots are full!"))
		return
	if cv.kind == CardView.CONS and consumables.size() >= _cons_slots():
		_message(Data.tv("Garage is full!", "Item slots are full!"))
		return
	money -= cv.price
	cv.price = -1
	shop_views.erase(cv)
	if cv.kind == CardView.VOUCHER:
		vouchers.append(cv.data.id)
		voucher_offer = ""
		_popup(Data.text(cv.data, "name"), cv.global_position + Vector2(48, -20), Color("b58a2a"), 20)
		sfx.play("win")
		_vanish(cv)
		_layout_slots()
		_update_sidebar()
		return
	if cv.kind == CardView.PACK:
		sfx.play("break", 1.4)
		_vanish(cv)
		_open_pack(cv.data)
		return
	cv.reparent(cards_layer)
	cv.fly_on_top()
	if cv.kind == CardView.MOD:
		mods.append(cv.data)
		mod_views.append(cv)
		_stats_add({"mods_bought": 1})
	else:
		consumables.append(cv.data)
		cons_views.append(cv)
	cv.punch(0.3)
	sfx.play("coin")
	_layout_slots()
	_update_sidebar()


func _sell_mod(cv: Control) -> void:
	if busy or not mod_views.has(cv):
		return
	money += _sell_value(cv.data)
	sfx.play("coin")
	_popup("+$%d" % _sell_value(cv.data), cv.global_position + Vector2(48, 150), MONEY_COL.darkened(0.15))
	var i := mod_views.find(cv)
	mods.remove_at(i)
	mod_views.remove_at(i)
	_vanish(cv)
	_layout_slots()
	_update_sidebar()


func _sell_cons(cv: Control) -> void:
	if busy or not cons_views.has(cv):
		return
	money += 1
	sfx.play("coin")
	_drop_cons(cv)


func _drop_cons(cv: Control) -> void:
	var i := cons_views.find(cv)
	consumables.remove_at(i)
	cons_views.remove_at(i)
	_vanish(cv)
	_layout_slots()
	_update_sidebar()


func _use_cons(cv: Control) -> void:
	if busy or not cons_views.has(cv):
		return
	var c: Dictionary = cv.data
	var sel := _selected()
	var need: Array = c.get("need", [0, 0])
	if need[1] > 0:
		if state != "play":
			_message("Use it during a race")
			return
		if sel.size() < need[0] or sel.size() > need[1]:
			_message(Data.tv("Select cars: %s", "Select cards: %s") % (str(need[1]) if need[0] == need[1] else "1-%d" % need[1]))
			return
	match c.id:
		"tune":
			_level_up(c.hand)
		"enh":
			for s in sel:
				s.data.enh = c.enh
				s.queue_redraw()
				s.punch()
			sfx.play("xmult")
		"respray":
			for s in sel:
				s.data.suit = c.suit
				s.debuffed = Scoring.card_debuffed(s.data, _active_boss())
				s.queue_redraw()
				s.punch()
			sfx.play("mult")
		"swap":
			for s in sel:
				s.data.rank = 2 if s.data.rank == 14 else s.data.rank + 1
				s.debuffed = Scoring.card_debuffed(s.data, _active_boss())
				s.queue_redraw()
				s.punch()
			sfx.play("mult", 1.3)
		"scrap":
			for s in sel:
				_remove_from_deck(s.data)
				hand.erase(s)
				_sparks(s.global_position + CardView.SIZE / 2, Color("aab4c3"), 24)
				_vanish(s)
			sfx.play("break")
			_layout_hand()
		"clone":
			var d: Dictionary = sel[0].data.duplicate()
			next_id += 1
			d.id = next_id
			deck.append(d)
			var ncv := _make_card(CardView.CAR, d)
			ncv.position = sel[0].position
			ncv.debuffed = sel[0].debuffed
			hand.append(ncv)
			ncv.punch(0.4)
			_sort_hand()
			_layout_hand()
			sfx.play("score", 1.2)
		"cash":
			var gain := mini(money, 20)
			money += gain
			_popup("+$%d" % gain, Vector2(148, 470), MONEY_COL.darkened(0.15), 26)
			sfx.play("coin")
	_drop_cons(cv)
	if c.id != "tune":
		_update_preview()


func _next_race() -> void:
	if state != "shop":
		return
	for cv in shop_views:
		cv.queue_free()
	shop_views.clear()
	_hide_action()
	blind_idx += 1
	if blind_idx > 2:
		blind_idx = 0
		ante += 1
		_pick_boss()
	_show_blind_select()


func _level_up(t: int) -> void:
	levels[t] += 1
	var h = Data.HANDS[t]
	_show_hand_type(t, h.chips + h.lc * (levels[t] - 1), h.mult + h.lm * (levels[t] - 1))
	_popup("%s %s%d!" % [tr(Data.hand_name(t)), tr("lvl."), levels[t]], Vector2(148, 300), CHIP_COL, 24)
	sfx.play("score")
	get_tree().create_timer(1.5).timeout.connect(_update_preview)


# ================================================================ booster packs

func _random_pack() -> Dictionary:
	var total := 0.0
	for p in Data.PACKS:
		total += p.weight
	var r := rng.randf() * total
	for p in Data.PACKS:
		r -= p.weight
		if r <= 0.0:
			return p
	return Data.PACKS[-1]


func _roll_pack(type: String) -> Array:
	var out := []
	match type:
		"cars":
			for i in 3:
				var c := _new_card(rng.randi_range(2, 14), rng.randi_range(0, 3))
				if rng.randf() < 0.35:
					c.enh = Data.ENH_INFO.keys()[rng.randi() % Data.ENH_INFO.size()]
				out.append(c)
		"tunes", "workshop":
			var pool := Data.consumables().filter(func(c): return (c.id == "tune") == (type == "tunes"))
			pool.shuffle()
			out = pool.slice(0, 3)
		"mods":
			var taken: Array = mods.map(func(m): return m.id)
			for i in 2:
				var def := _random_mod(taken)
				if not def.is_empty():
					taken.append(def.id)
					out.append(_roll_edition(def.duplicate(true)))
	return out


func _open_pack(pack: Dictionary, choices := []) -> void:
	if choices.is_empty():
		choices = _roll_pack(pack.type)
		_stats_add({"packs_opened": 1})
	pack_open = {"data": pack, "choices": choices}
	pack_panel = Panel.new()
	pack_panel.add_theme_stylebox_override("panel", Data.box(Color(0.05, 0.06, 0.09, 0.97), 16, pack.color, 3))
	pack_panel.position = Vector2(326, 196)
	pack_panel.size = Vector2(928, 456)
	pack_panel.z_index = 150  # above hovered shop cards (z 100) in the same overlay band
	overlay.add_child(pack_panel)
	var t := _label(Data.text(pack, "name"), 34, pack.color.lightened(0.3), 8)
	t.size = Vector2(928, 44)
	t.position = Vector2(0, 16)
	pack_panel.add_child(t)
	var sub := _label("Choose 1", 18, Color(1, 1, 1, 0.75), 4)
	sub.size = Vector2(928, 24)
	sub.position = Vector2(0, 62)
	pack_panel.add_child(sub)
	var kind: int = {"cars": CardView.CAR, "tunes": CardView.CONS, "workshop": CardView.CONS, "mods": CardView.MOD}[pack.type]
	var x0 := 464.0 - (choices.size() * 130 - 34) / 2.0
	for i in choices.size():
		var cv := _make_card(kind, choices[i], pack_panel)
		cv.base_scale = 1.25
		cv.scale = Vector2.ZERO
		cv.target_pos = Vector2(x0 + i * 130, 150)
		cv.position = Vector2(416, 180)
		pack_views.append(cv)
	var skip := _button("Skip", Color("555b66"), 20, Vector2(180, 50))
	skip.position = Vector2(374, 380)
	skip.pressed.connect(_close_pack)
	pack_panel.add_child(skip)
	sfx.play("xmult", 1.3)
	_update_sidebar()


func _take_pack(cv: Control) -> void:
	if not pack_views.has(cv):
		return
	match cv.kind:
		CardView.CAR:
			deck.append(cv.data)
			_popup(Data.tv("Added to garage!", "Added to deck!"), cv.global_position + Vector2(60, -24), Color("3ecf6a").darkened(0.2))
			sfx.play("score", 1.2)
		CardView.CONS:
			if cv.data.id == "tune":
				_level_up(cv.data.hand)
			elif consumables.size() >= _cons_slots():
				_message(Data.tv("Garage is full!", "Item slots are full!"))
				return
			else:
				consumables.append(cv.data)
				cons_views.append(cv)
		CardView.MOD:
			if mods.size() >= _mod_slots() and cv.data.get("edition", "") != "negative":
				_message(Data.tv("Mod slots are full!", "Joker slots are full!"))
				return
			mods.append(cv.data)
			mod_views.append(cv)
	if cons_views.has(cv) or mod_views.has(cv):
		pack_views.erase(cv)
		cv.base_scale = 1.0
		cv.reparent(cards_layer)
		cv.fly_on_top()
		cv.punch(0.3)
		sfx.play("coin")
		_layout_slots()
	_close_pack()


func _close_pack() -> void:
	for cv in pack_views:
		_vanish(cv)
	pack_views.clear()
	pack_open = {}
	if is_instance_valid(pack_panel):
		pack_panel.queue_free()
	_update_sidebar()


# ================================================================ save / settings

func _save_run() -> void:
	if busy or not SAVE_STATES.has(state):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_var({
		"v": 1, "state": state, "ante": ante, "blind_idx": blind_idx, "round_num": round_num, "money": money,
		"deck": deck, "draw_pile": draw_pile.map(func(c): return c.id), "hand": hand.map(func(cv): return cv.data.id),
		"levels": levels, "played_count": played_count, "mods": mods, "consumables": consumables,
		"boss": boss, "last_boss_name": last_boss_name, "endless": endless, "best_hand": best_hand, "next_id": next_id,
		"score": score, "target": target, "hands_left": hands_left, "discards_left": discards_left,
		"hand_size": hand_size, "hands_played": hands_played, "played_types": played_types,
		"cashout_lines": cashout_lines, "reroll_cost": reroll_cost, "pack_open": pack_open, "result_recorded": result_recorded, "vouchers": vouchers, "voucher_offer": voucher_offer,
		"shop_items": shop_views.map(func(cv): return {"kind": cv.kind, "data": cv.data, "price": cv.price, "pos": cv.target_pos}),
	})


func _continue_run(sound := true) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = f.get_var() if f else null
	if typeof(d) != TYPE_DICTIONARY or d.get("v") != 1:
		_message("Save file is damaged")
		DirAccess.remove_absolute(SAVE_PATH)
		continue_btn.hide()
		return
	title_layer.visible = false
	world.visible = true
	_clear_views()
	_clear(overlay)
	for k in ["ante", "blind_idx", "round_num", "money", "deck", "levels", "played_count", "mods", "consumables",
			"boss", "last_boss_name", "endless", "best_hand", "next_id", "score", "target", "hands_left",
			"discards_left", "hand_size", "hands_played", "played_types", "reroll_cost"]:
		set(k, d[k])
	result_recorded = d.get("result_recorded", false)
	vouchers = d.get("vouchers", [])
	voucher_offer = d.get("voucher_offer", "")
	var by_id := {}
	for c in deck:
		by_id[c.id] = c
	draw_pile = d.draw_pile.map(func(i): return by_id[i])
	for m in mods:
		mod_views.append(_make_card(CardView.MOD, m))
	for c in consumables:
		cons_views.append(_make_card(CardView.CONS, c))
	for cv in mod_views + cons_views:
		cv.position = DECK_POS
	_layout_slots()
	match d.state:
		"blind":
			_show_blind_select()
		"cashout":
			_show_cashout(d.cashout_lines)
		"shop":
			_open_shop(d)
		"play":
			state = "play"
			for i in d.hand:
				var cv := _make_card(CardView.CAR, by_id[i])
				cv.position = DECK_POS
				cv.debuffed = Scoring.card_debuffed(cv.data, _active_boss())
				hand.append(cv)
			_sort_hand()
			_layout_hand()
			_set_hand_info(" ", " ", 0, 0)
			_update_sidebar()
	if sound:
		sfx.play("engine")


func _toggle_sfx() -> void:
	sfx_on = not sfx_on
	_apply_settings()
	if sfx_on:
		sfx.play("click")
	_refresh_texts()
	_save_settings()


func _toggle_music() -> void:
	music_on = not music_on
	_apply_settings()
	_refresh_texts()
	_save_settings()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_apply_url_lang()
		return
	music_on = cfg.get_value("settings", "music", true)
	sfx_on = cfg.get_value("settings", "sfx", true)
	show_fps = cfg.get_value("settings", "fps", false)
	music_vol = cfg.get_value("settings", "music_volume", 0.8)
	sfx_vol = cfg.get_value("settings", "sfx_volume", 1.0)
	speed_idx = clampi(cfg.get_value("settings", "speed", 0), 0, SPEEDS.size() - 1)
	shake_on = cfg.get_value("settings", "shake", true)
	fullscreen = cfg.get_value("settings", "fullscreen", false)
	Data.classic_art = cfg.get_value("settings", "classic_art", false)
	Data.classic_suits = cfg.get_value("settings", "classic_suits", true)
	Data.back_style = posmod(cfg.get_value("settings", "back", 4), Data.BACKS.size())
	if cfg.get_value("settings", "version", 1) < 2:  # v1.2.1: classic suits and back became the default
		Data.classic_suits = true
		Data.back_style = 4
	var loc: String = cfg.get_value("settings", "locale", "")
	if loc != "":
		TranslationServer.set_locale(loc)
	else:
		_apply_url_lang()


## Web build: the website passes its language as ?lang=xx; used until the player picks one in the game.
func _apply_url_lang() -> void:
	if not OS.has_feature("web"):
		return
	var lang = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('lang') || ''", true)
	if typeof(lang) == TYPE_STRING and LANGS.any(func(l): return l[0] == lang):
		TranslationServer.set_locale(lang)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "music", music_on)
	cfg.set_value("settings", "sfx", sfx_on)
	cfg.set_value("settings", "fps", show_fps)
	cfg.set_value("settings", "music_volume", music_vol)
	cfg.set_value("settings", "sfx_volume", sfx_vol)
	cfg.set_value("settings", "speed", speed_idx)
	cfg.set_value("settings", "shake", shake_on)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "classic_art", Data.classic_art)
	cfg.set_value("settings", "classic_suits", Data.classic_suits)
	cfg.set_value("settings", "back", Data.back_style)
	cfg.set_value("settings", "version", 2)
	cfg.set_value("settings", "locale", TranslationServer.get_locale())
	cfg.save(SETTINGS_PATH)


func _apply_settings() -> void:
	music.set_muted(not music_on)
	music.set_volume(music_vol)
	sfx.volume = sfx_vol if sfx_on else 0.0


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	_apply_fullscreen()
	_save_settings()


## Redraw every card and rebuild the current screen so all texts follow the new language/theme.
func _rebuild_screen() -> void:
	get_tree().call_group("cards", "queue_redraw")
	_refresh_texts()
	if not busy and SAVE_STATES.has(state):
		_save_run()
		_continue_run(false)


func _set_lang(code: String) -> void:
	TranslationServer.set_locale(code)
	_save_settings()
	_rebuild_screen()
	_show_settings()


func _set_theme(classic_art: bool, classic_suits: bool) -> void:
	Data.classic_art = classic_art
	Data.classic_suits = classic_suits
	_save_settings()
	_rebuild_screen()
	_show_settings()


func _set_back(i: int) -> void:
	Data.back_style = posmod(i, Data.BACKS.size())
	_save_settings()
	get_tree().call_group("cards", "queue_redraw")
	_show_settings()


func _choice(options: Array, current: int, cb: Callable, width := 112.0) -> HBoxContainer:
	var h := _hbox(6)
	for i in options.size():
		var b := _button(options[i], Color("6b5bd6") if i == current else Color("3a3f4b"), 15, Vector2(width, 36))
		b.pressed.connect(cb.bind(i))
		h.add_child(b)
	return h


func _show_settings() -> void:
	var p := _panel(PANEL_BG, Color("6b5bd6"), 3, 22, 16)
	p.position = Vector2(110, 40)
	p.custom_minimum_size = Vector2(1060, 0)
	var v := _vbox(12)
	p.add_child(v)
	v.add_child(_label("SETTINGS", 32, Color("b9aaff"), 8))
	var cols := _hbox(36)
	v.add_child(cols)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 12)
	cols.add_child(g)

	var langs := GridContainer.new()
	langs.columns = 3
	langs.add_theme_constant_override("h_separation", 6)
	langs.add_theme_constant_override("v_separation", 6)
	var cur := _lang_idx()
	for i in LANGS.size():
		var b := _button(LANGS[i][1], CHIP_COL if i == cur else Color("3a3f4b"), 15, Vector2(104, 36))
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.pressed.connect(_set_lang.bind(LANGS[i][0]))
		langs.add_child(b)
	_settings_row(g, "Language", langs)
	var mus := _hbox(10)
	var mt := _button(tr("Music: On") if music_on else tr("Music: Off"), Color("2f8f83") if music_on else Color("3a3f4b"), 15, Vector2(130, 36))
	mt.pressed.connect(func():
		_toggle_music()
		_show_settings())
	mus.add_child(mt)
	mus.add_child(_slider(music_vol, func(x):
		music_vol = x
		music.set_volume(x)))
	_settings_row(g, "Music", mus)
	var snd := _hbox(10)
	var st := _button(tr("Sound: On") if sfx_on else tr("Sound: Off"), Color("2f8f83") if sfx_on else Color("3a3f4b"), 15, Vector2(130, 36))
	st.pressed.connect(func():
		_toggle_sfx()
		_show_settings())
	snd.add_child(st)
	snd.add_child(_slider(sfx_vol, func(x):
		sfx_vol = x
		sfx.volume = x if sfx_on else 0.0
		sfx.play("chips")))
	_settings_row(g, "Sound effects", snd)
	_settings_row(g, "Game speed", _choice(SPEEDS.map(func(x): return "%sx" % Scoring.num_str(x)), speed_idx, func(i):
		speed_idx = i
		_update_speed_text()
		_save_settings()
		_show_settings(), 70.0))
	_settings_row(g, "Screen shake", _toggle(shake_on, func():
		shake_on = not shake_on
		shake = 10.0
		_save_settings()
		_show_settings()))
	_settings_row(g, "Fullscreen", _toggle(fullscreen, func():
		_toggle_fullscreen()
		_show_settings()))
	_settings_row(g, "Show FPS", _toggle(show_fps, func():
		show_fps = not show_fps
		fps_lbl.visible = show_fps
		_save_settings()
		_show_settings()))

	var right := _vbox(12)
	cols.add_child(right)
	var g2 := GridContainer.new()
	g2.columns = 2
	g2.add_theme_constant_override("h_separation", 16)
	g2.add_theme_constant_override("v_separation", 12)
	right.add_child(g2)
	_settings_row(g2, "Card art", _choice([tr("Cars"), tr("Classic")], int(Data.classic_art), func(i): _set_theme(i == 1, Data.classic_suits), 130.0))
	_settings_row(g2, "Suits", _choice([tr("Car brands"), tr("Classic")], int(Data.classic_suits), func(i): _set_theme(Data.classic_art, i == 1), 130.0))
	var bk := _hbox(6)
	var prev_b := _button("<", Color("3a3f4b"), 18, Vector2(40, 36))
	prev_b.pressed.connect(func(): _set_back(Data.back_style - 1))
	var name_l := _label(Data.BACKS[Data.back_style], 16, Color.WHITE, 4)
	name_l.custom_minimum_size = Vector2(176, 36)
	var next_b := _button(">", Color("3a3f4b"), 18, Vector2(40, 36))
	next_b.pressed.connect(func(): _set_back(Data.back_style + 1))
	for c in [prev_b, name_l, next_b]:
		bk.add_child(c)
	_settings_row(g2, "Card back", bk)
	# live preview of the chosen art, suits and back
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(440, 150)
	var samples := [{"rank": 14, "suit": 0, "enh": ""}, {"rank": 13, "suit": 2, "enh": "nitro"}, {"rank": 12, "suit": 1, "enh": ""},
		{"rank": 7, "suit": 3, "enh": "carbon"}]
	for i in 5:
		var cv := CardView.new()
		cv.kind = CardView.BACK if i == 4 else CardView.CAR
		cv.data = {} if i == 4 else samples[i]
		cv.interactive = false
		cv.base_scale = 0.95
		cv.target_pos = Vector2(i * 88, 8)
		cv.position = cv.target_pos
		cv.target_rot = (i - 2) * 0.04
		preview.add_child(cv)
	right.add_child(preview)

	var back := _button("Back", ACCENT, 20, Vector2(200, 50))
	back.pressed.connect(func():
		_save_settings()
		if state == "title":
			_clear(modal_layer)
		else:
			_show_menu())
	v.add_child(back)
	_modal(p)


func _settings_row(g: GridContainer, name: String, control: Control) -> void:
	var l := _label(name, 17, Color(1, 1, 1, 0.85), 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	g.add_child(l)
	g.add_child(control)


func _toggle(on: bool, cb: Callable) -> Button:
	var b := _button("On" if on else "Off", Color("2fa65a") if on else Color("3a3f4b"), 15, Vector2(90, 36))
	b.pressed.connect(cb)
	return b


func _slider(value: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(180, 36)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(cb)
	s.drag_ended.connect(func(_changed): _save_settings())
	return s


# ================================================================ end / modals

func _show_end(win: bool, lines := []) -> void:
	state = "end"
	busy = false
	if not result_recorded:  # endless mode after a win does not count as a loss later
		result_recorded = true
		_stats_add({"runs_won" if win else "runs_lost": 1}, {"best_ante": ante})
	DirAccess.remove_absolute(SAVE_PATH)
	_clear(overlay)
	_update_sidebar()
	if win:
		sfx.play("win")
		_confetti()
	else:
		sfx.play("lose")
		shake = 14.0
		for c in hand:
			c.target_pos.y = 900
			c.target_rot = randf_range(-1.0, 1.0)
	var p := _panel(PANEL_BG, MONEY_COL if win else MULT_COL, 4, 22, 18)
	p.position = Vector2(540, 160)
	p.custom_minimum_size = Vector2(460, 0)
	var v := _vbox(10)
	p.add_child(v)
	v.add_child(_label("CHAMPION!" if win else "WRECKED!", 58, MONEY_COL if win else MULT_COL, 14))
	v.add_child(_label("You won the Grand Prix!" if win else "You ran out of hands.", 18, Color(1, 1, 1, 0.8), 4))
	var most := 0
	for i in played_count.size():
		if played_count[i] > played_count[most]:
			most = i
	for row in [["Ante reached", str(ante)], ["Best hand", _fmt(best_hand)],
			["Most played", tr(Data.hand_name(most)) if played_count[most] > 0 else "-"], [Data.tv("Cars in garage", "Cards in deck"), str(deck.size())]]:
		var h := _hbox(8)
		var l := _label(row[0], 18, Color(1, 1, 1, 0.75), 3)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(_label(row[1], 20, Color("ffb347"), 4))
		v.add_child(h)
	if win:
		var e := _button("Keep Racing (Endless)", Color("6b5bd6"), 20, Vector2(300, 52))
		e.pressed.connect(func():
			endless = true
			_show_cashout(lines))
		v.add_child(e)
	var nr := _button("New Run", CHIP_COL, 22, Vector2(300, 56))
	nr.pressed.connect(_start_run)
	v.add_child(nr)
	var mm := _button("Main Menu", Color("555b66"), 18, Vector2(300, 44))
	mm.pressed.connect(_show_title)
	v.add_child(mm)
	overlay.add_child(p)
	p.pivot_offset = Vector2(230, 200)
	p.scale = Vector2(0.6, 0.6)
	create_tween().tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _modal(content: Control) -> void:
	_clear(modal_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_clear(modal_layer))
	modal_layer.add_child(dim)
	modal_layer.add_child(content)


func _show_menu() -> void:
	if state == "title":
		return
	var p := _panel(PANEL_BG, Color("8fa3b8"), 3, 22, 16)
	p.position = Vector2(500, 150)
	p.custom_minimum_size = Vector2(320, 0)
	var v := _vbox(10)
	p.add_child(v)
	v.add_child(_label("MENU", 32, Color.WHITE, 8))
	var resume := _button("Resume", CHIP_COL, 22, Vector2(280, 54))
	resume.pressed.connect(func(): _clear(modal_layer))
	v.add_child(resume)
	var how := _button("How to Play", Color("d9822b"), 18, Vector2(280, 44))
	how.pressed.connect(_show_help)
	v.add_child(how)
	var st := _button("Settings", Color("6b5bd6"), 18, Vector2(280, 44))
	st.pressed.connect(_show_settings)
	v.add_child(st)
	var col := _button("Collection", Color("2f8f83"), 18, Vector2(280, 44))
	col.pressed.connect(_show_collection.bind(-1))
	v.add_child(col)
	var stb := _button("Statistics", Color("3a7bd5"), 18, Vector2(280, 44))
	stb.pressed.connect(_show_stats)
	v.add_child(stb)
	var mm := _button("Main Menu", ACCENT, 18, Vector2(280, 44))
	mm.disabled = busy  # never tear down the table in the middle of a scoring animation
	mm.pressed.connect(func():
		_save_run()
		_clear(modal_layer)
		_show_title())
	v.add_child(mm)
	if SAVE_STATES.has(state):
		v.add_child(_label("Your run is saved", 13, Color(1, 1, 1, 0.6), 3))
	if not OS.has_feature("web"):
		var quit := _button("Quit", Color("555b66"), 18, Vector2(280, 40))
		quit.pressed.connect(func():
			_save_run()
			get_tree().quit())
		v.add_child(quit)
	_modal(p)


# ================================================================ collection

## Encyclopedia of everything in the game, one tab per kind of thing.
func _show_collection(tab := -1) -> void:
	if tab >= 0:
		collection_tab = tab
	gallery_backs.clear()
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", Data.box(Color(PANEL_BG, 1.0), 16, Color("2f8f83"), 3))
	p.position = Vector2(40, 20)
	p.size = Vector2(1200, 680)
	var t := _label("COLLECTION", 30, Color("7fe0d0"), 8)
	t.size = Vector2(1200, 40)
	t.position = Vector2(0, 10)
	p.add_child(t)
	var tabs := _hbox(6)
	tabs.position = Vector2(24, 58)
	tabs.size = Vector2(1152, 40)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	var names := [Data.tv("Cars", "Cards"), Data.tv("Mods", "Jokers"), Data.tv("Garage cards", "Items"), tr("Packs"),
		Data.tv("Sponsors", "Vouchers"), tr("Bosses"), tr("Poker hands"), tr("Card backs")]
	for i in names.size():
		var b := _button(names[i], Color("2f8f83") if i == collection_tab else Color("3a3f4b"), 14, Vector2(136, 38))
		b.clip_text = true
		b.pressed.connect(_show_collection.bind(i))
		tabs.add_child(b)
	p.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 108)
	scroll.size = Vector2(1160, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := 0.0
	match collection_tab:
		0: h = _gal_cards(c)
		1: h = _gal_mods(c)
		2: h = _gal_items(c)
		3: h = _gal_packs(c)
		4: h = _gal_vouchers(c)
		5: h = _gal_bosses(c)
		6: h = _gal_hands(c)
		7: h = _gal_backs(c)
	c.custom_minimum_size = Vector2(1140, h)
	scroll.add_child(c)
	var back := _button("Back", ACCENT, 20, Vector2(200, 50))
	back.position = Vector2(500, 618)
	back.pressed.connect(func():
		if state == "title":
			_clear(modal_layer)
		else:
			_show_menu())
	p.add_child(back)
	_modal(p)


## A card in the gallery; pos is the visible top-left corner after scaling.
func _gal_card(parent: Control, kind: int, data: Dictionary, pos: Vector2, s := 0.8) -> Control:
	var cv := _make_card(kind, data, parent)
	cv.base_scale = s
	cv.scale = Vector2(s, s)
	cv.target_pos = pos - CardView.SIZE * (1.0 - s) / 2.0
	cv.position = cv.target_pos
	cv.mouse_filter = Control.MOUSE_FILTER_PASS  # let the mouse wheel reach the scroll container
	return cv


func _gal_label(parent: Control, text: String, pos: Vector2, size := 18, color := Color("ffd23f"), width := 1140.0) -> Label:
	var l := _label(text, size, color, 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.position = pos
	l.size = Vector2(width, size + 8)
	parent.add_child(l)
	return l


func _gal_cards(c: Control) -> float:
	_gal_label(c, tr("Hover any card for details"), Vector2(0, 0), 14, Color(1, 1, 1, 0.6))
	for s in 4:
		var y := 30.0 + s * 112
		_gal_label(c, tr(Data.suit_name(s)), Vector2(0, y + 38), 17, Data.suit_color(s).lightened(0.35), 110)
		for i in 13:
			_gal_card(c, CardView.CAR, {"id": -1, "rank": 14 - i, "suit": s, "enh": ""}, Vector2(110 + i * 79, y), 0.75)
	var y2 := 30.0 + 4 * 112 + 10
	_gal_label(c, tr("Card upgrades"), Vector2(0, y2))
	var enhs := Data.ENH_INFO.keys()
	for i in enhs.size():
		var x := 110.0 + i * 250
		_gal_card(c, CardView.CAR, {"id": -1, "rank": 13, "suit": i, "enh": enhs[i]}, Vector2(x, y2 + 34), 0.75)
		var info: Dictionary = Data.ENH_INFO[enhs[i]]
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.position = Vector2(x + 82, y2 + 50)
		r.size = Vector2(160, 80)
		r.add_theme_font_size_override("normal_font_size", 14)
		r.text = "[color=%s]%s[/color]\n%s" % [Data.ENH_COLORS[enhs[i]].lightened(0.35).to_html(false), Data.text(info, "name"), _bb_dark(tr(info.desc))]
		c.add_child(r)
	return y2 + 150


func _gal_mods(c: Control) -> float:
	var y := 0.0
	for r in 3:
		var list := Data.MODS.filter(func(m): return m.get("rarity", 0) == r)
		list.sort_custom(func(a, b): return a.cost < b.cost)
		_gal_label(c, "%s (%d)" % [tr(Data.RARITY_NAMES[r]), list.size()], Vector2(0, y), 17, [Color("8fa3b8"), Color("3ecf6a"), Color("ff4b3e")][r])
		y += 56
		for i in list.size():
			var cv := _gal_card(c, CardView.MOD, list[i].duplicate(true), Vector2((i % 11) * 103, y + (i / 11) * 150), 0.9)
			cv.price = list[i].cost
		y += ceili(list.size() / 11.0) * 150 + 6
	_gal_label(c, tr("Editions"), Vector2(0, y), 17, Color("7fe0d0"))
	y += 56
	var eds := Data.EDITIONS.keys()
	for i in eds.size():
		var ed: Dictionary = Data.EDITIONS[eds[i]]
		var md: Dictionary = Data.mod_def("supercharger").duplicate(true)
		md.edition = eds[i]
		_gal_card(c, CardView.MOD, md, Vector2(i * 280, y), 0.9)
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.position = Vector2(i * 280 + 96, y + 20)
		r.size = Vector2(170, 90)
		r.add_theme_font_size_override("normal_font_size", 14)
		r.text = "[color=#7fe0d0]%s[/color]\n%s\n[color=#aaaaaa]%s[/color]" % [Data.text(ed, "name"), _bb_dark(Data.text(ed, "desc")), tr("Chance: %s%%") % Scoring.num_str(ed.weight)]
		c.add_child(r)
	return y + 140


func _gal_items(c: Control) -> float:
	var all := Data.consumables()
	var groups := [[Data.tv("DYNO TUNE", "UPGRADE"), all.filter(func(x): return x.id == "tune")],
		[Data.tv("WORKSHOP", "TRICK"), all.filter(func(x): return x.id != "tune")]]
	var y := 0.0
	for g in groups:
		_gal_label(c, "%s (%d)" % [g[0], g[1].size()], Vector2(0, y), 17)
		y += 56
		for i in g[1].size():
			var cv := _gal_card(c, CardView.CONS, g[1][i], Vector2((i % 11) * 103, y + (i / 11) * 150), 0.9)
			cv.price = g[1][i].cost
		y += ceili(g[1].size() / 11.0) * 150 + 6
	return y


func _gal_packs(c: Control) -> float:
	_gal_label(c, tr("BOOSTER PACKS"), Vector2(0, 0), 17)
	for i in Data.PACKS.size():
		var pk: Dictionary = Data.PACKS[i]
		var x := (i % 2) * 570.0
		var y := 56.0 + (i / 2) * 190
		var cv := _gal_card(c, CardView.PACK, pk, Vector2(x, y), 1.0)
		cv.price = pk.cost
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.position = Vector2(x + 115, y + 20)
		r.size = Vector2(420, 120)
		r.add_theme_font_size_override("normal_font_size", 16)
		r.text = "[color=%s]%s[/color]\n%s" % [pk.color.lightened(0.35).to_html(false), Data.text(pk, "name"), _bb_dark(Data.text(pk, "desc"))]
		c.add_child(r)
	return 56.0 + 2 * 190


func _gal_vouchers(c: Control) -> float:
	_gal_label(c, Data.tv("Sponsors give a permanent bonus for the whole run. The Pit Stop offers one each ante.",
		"Vouchers give a permanent bonus for the whole run. The Pit Stop offers one each ante."), Vector2(0, 0), 14, Color(1, 1, 1, 0.7))
	for i in Data.VOUCHERS.size():
		var v: Dictionary = Data.VOUCHERS[i]
		var x := (i % 3) * 380.0
		var y := 46.0 + (i / 3) * 164
		var cv := _gal_card(c, CardView.VOUCHER, v, Vector2(x, y), 0.95)
		cv.price = Data.VOUCHER_COST
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.position = Vector2(x + 104, y + 20)
		r.size = Vector2(260, 100)
		r.add_theme_font_size_override("normal_font_size", 15)
		var owned := "\n[color=#5fd38a]%s[/color]" % tr("Owned") if vouchers.has(v.id) and state != "title" else ""
		r.text = "[color=#ffd23f]%s[/color]\n%s%s" % [Data.text(v, "name"), _bb_dark(Data.text(v, "desc")), owned]
		c.add_child(r)
	return 46.0 + ceili(Data.VOUCHERS.size() / 3.0) * 164


func _gal_bosses(c: Control) -> float:
	var list := Data.BOSSES + [Data.FINAL_BOSS]
	for i in list.size():
		var b: Dictionary = list[i]
		var pnl := _panel(b.color.darkened(0.35), b.color.lightened(0.25), 2, 10, 10)
		pnl.position = Vector2((i % 3) * 380, (i / 3) * 118)
		pnl.custom_minimum_size = Vector2(366, 106)
		pnl.size = pnl.custom_minimum_size
		pnl.mouse_filter = Control.MOUSE_FILTER_PASS
		var hb := _hbox(8)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(70, 80)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.draw.connect(func():
			icon.draw_circle(Vector2(35, 42), 33, b.color.darkened(0.6))
			Art.boss_art(icon, b, Vector2(35, 42), 1.0))
		hb.add_child(icon)
		var v := _vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_label(Data.text(b, "name"), 19, Color.WHITE, 5))
		var d := _label(Data.text(b, "desc"), 14, Color(1, 1, 1, 0.9), 3)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(266, 0)
		v.add_child(d)
		var note := tr("Final race") if b.id == "grand_prix" else (tr("From ante %d") % b.min_ante if b.get("min_ante", 1) > 1 else "")
		if note != "":
			v.add_child(_label(note, 12, Color("ffd23f"), 3))
		hb.add_child(v)
		pnl.add_child(hb)
		c.add_child(pnl)
	return ceili(list.size() / 3.0) * 118


func _gal_hands(c: Control) -> float:
	var row_h := 76.0
	for t in range(Data.HANDS.size() - 1, -1, -1):
		var h = Data.HANDS[t]
		var y := (Data.HANDS.size() - 1 - t) * row_h
		var name := tr(Data.hand_name(t))
		if not Data.classic_art:
			name += "  (%s)" % tr(h.poker)
		_gal_label(c, name, Vector2(0, y + 10), 18, Color.WHITE, 420)
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.position = Vector2(0, y + 38)
		r.size = Vector2(440, 30)
		r.add_theme_font_size_override("normal_font_size", 14)
		r.text = _bb_dark("[c]%d[/] x [m]%d[/]    %s: [c]+%d[/] / [m]+%d[/]" % [h.chips, h.mult, tr("Per level"), h.lc, h.lm])
		c.add_child(r)
		var ex: Array = Data.HAND_EXAMPLES[t]
		for i in ex.size():
			_gal_card(c, CardView.CAR, {"id": -1, "rank": ex[i][0], "suit": ex[i][1], "enh": ""}, Vector2(470 + i * 58, y + 4), 0.5)
	return Data.HANDS.size() * row_h


func _gal_backs(c: Control) -> float:
	_gal_label(c, tr("Click a back to use it"), Vector2(0, 0), 14, Color(1, 1, 1, 0.6))
	for i in Data.BACKS.size():
		var x := 20.0 + i * 186
		var cv := _gal_card(c, CardView.BACK, {}, Vector2(x, 70), 1.3)
		cv.back_style = i
		cv.selected = i == Data.back_style
		gallery_backs.append(cv)
		_gal_label(c, tr(Data.BACKS[i]), Vector2(x - 20, 270), 15, Color("ffd23f") if i == Data.back_style else Color.WHITE, 165).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return 320.0


func _show_changelog() -> void:
	sfx.play("click")
	var p := _panel(Color(PANEL_BG, 1.0), Color("ffd23f"), 3, 22, 16)
	p.position = Vector2(290, 50)
	p.custom_minimum_size = Vector2(700, 0)
	var v := _vbox(10)
	p.add_child(v)
	v.add_child(_label("CHANGELOG", 30, Color("ffd23f"), 8))
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = true
	r.custom_minimum_size = Vector2(650, 460)
	r.add_theme_font_size_override("normal_font_size", 16)
	var t := ""
	for e in Changelog.ENTRIES:
		t += "[color=#ffd23f]v%s[/color]   [color=#8fa3b8]%s[/color]\n" % [e.version, e.date]
		for item in e.items:
			t += "- %s\n" % tr(item)
		t += "\n"
	r.text = t
	v.add_child(r)
	var b := _button("Back", ACCENT, 20, Vector2(200, 50))
	b.pressed.connect(func(): _clear(modal_layer))
	v.add_child(b)
	_modal(p)


# ================================================================ statistics

func _load_stats() -> void:
	var cfg := ConfigFile.new()
	cfg.load(STATS_PATH)
	for k in STAT_KEYS:
		stats[k] = int(cfg.get_value("stats", k, 0))
	var counts: Array = cfg.get_value("stats", "hand_counts", [])
	counts.resize(Data.HANDS.size())
	stats.hand_counts = counts.map(func(x): return int(x) if x != null else 0)


## Add to counters and raise records, then save.
func _stats_add(add: Dictionary, best := {}) -> void:
	for k in add:
		stats[k] += add[k]
	for k in best:
		stats[k] = maxi(stats[k], best[k])
	var cfg := ConfigFile.new()
	for k in STAT_KEYS:
		cfg.set_value("stats", k, stats[k])
	cfg.set_value("stats", "hand_counts", stats.hand_counts)
	cfg.save(STATS_PATH)


func _show_stats(confirm_reset := false) -> void:
	var p := _panel(Color(PANEL_BG, 1.0), Color("3a7bd5"), 3, 22, 16)
	p.position = Vector2(390, 50)
	p.custom_minimum_size = Vector2(500, 0)
	var v := _vbox(10)
	p.add_child(v)
	v.add_child(_label("STATISTICS", 30, Color("8ec5ff"), 8))
	var played: int = stats.runs_won + stats.runs_lost
	var fav := 0
	for i in stats.hand_counts.size():
		if stats.hand_counts[i] > stats.hand_counts[fav]:
			fav = i
	var rows := [
		["Runs started", _fmt(stats.runs_started)],
		["Runs won", _fmt(stats.runs_won)],
		["Runs lost", _fmt(stats.runs_lost)],
		["Win rate", "%d%%" % roundi(100.0 * stats.runs_won / played) if played > 0 else "-"],
		["Best ante", _fmt(stats.best_ante)],
		["Best hand", _fmt(stats.best_hand)],
		["Races won", _fmt(stats.races_won)],
		["Bosses beaten", _fmt(stats.bosses_beaten)],
		["Hands played", _fmt(stats.hands_played)],
		[Data.tv("Cars played", "Cards played"), _fmt(stats.cards_played)],
		["Discards used", _fmt(stats.discards)],
		["Money earned", "$" + _fmt(stats.money_earned)],
		[Data.tv("Mods bought", "Jokers bought"), _fmt(stats.mods_bought)],
		["Packs opened", _fmt(stats.packs_opened)],
		["Favorite hand", tr(Data.hand_name(fav)) if stats.hand_counts[fav] > 0 else "-"],
	]
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 4)
	for row in rows:
		var l := _label(row[0], 16, Color(1, 1, 1, 0.75), 3)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(l)
		var val := _label(row[1], 17, Color("ffb347"), 4)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(val)
	v.add_child(g)
	var h := _hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var reset := _button("Press again to reset" if confirm_reset else "Reset statistics", MULT_COL if confirm_reset else Color("555b66"), 16, Vector2(210, 46))
	reset.pressed.connect(func():
		if confirm_reset:
			for k in STAT_KEYS:
				stats[k] = 0
			stats.hand_counts.fill(0)
			_stats_add({})
			sfx.play("break")
			_show_stats()
		else:
			_show_stats(true))
	h.add_child(reset)
	var back := _button("Back", ACCENT, 18, Vector2(170, 46))
	back.pressed.connect(func():
		if state == "title":
			_clear(modal_layer)
		else:
			_show_menu())
	h.add_child(back)
	v.add_child(h)
	_modal(p)


func _close_button() -> Button:
	var b := _button("Back", ACCENT, 20, Vector2(200, 50))
	b.pressed.connect(func(): _clear(modal_layer))
	return b


func _show_info() -> void:
	if state == "title" or levels.is_empty():
		return
	var p := _panel(PANEL_BG, CHIP_COL, 3, 20, 16)
	p.position = Vector2(330, 70)
	p.custom_minimum_size = Vector2(620, 0)
	var v := _vbox(10)
	p.add_child(v)
	v.add_child(_label("HAND LEVELS", 30, CHIP_COL, 8))
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 6)
	for hdr in ["Hand", "Level", "Chips", "Mult", "Played"]:
		g.add_child(_label(hdr, 14, Color(1, 1, 1, 0.55), 3))
	for i in range(Data.HANDS.size() - 1, -1, -1):
		var h = Data.HANDS[i]
		var lvl: int = levels[i]
		var name_lbl := _label(tr(h.poker) if Data.classic_art else "%s  (%s)" % [tr(h.name), tr(h.poker)], 16, Color.WHITE, 3)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		g.add_child(name_lbl)
		g.add_child(_label(tr("lvl.") + str(lvl), 16, Color("ffb347") if lvl > 1 else Color.WHITE, 3))
		g.add_child(_label(str(h.chips + h.lc * (lvl - 1)), 16, CHIP_COL, 3))
		g.add_child(_label(str(h.mult + h.lm * (lvl - 1)), 16, MULT_COL, 3))
		g.add_child(_label(str(played_count[i]), 16, Color.WHITE, 3))
	v.add_child(g)
	if not vouchers.is_empty():
		var owned := _label(Data.tv("Sponsors", "Vouchers") + ": " + ", ".join(vouchers.map(func(id): return Data.text(Data.VOUCHERS.filter(func(x): return x.id == id)[0], "name"))), 15, Color("ffd23f"), 3)
		owned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		owned.custom_minimum_size = Vector2(580, 0)
		v.add_child(owned)
	v.add_child(_close_button())
	_modal(p)


func _show_deck() -> void:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", Data.box(PANEL_BG, 16, Color("8c1c13"), 3))
	p.position = Vector2(300, 40)
	p.size = Vector2(960, 640)
	var t := _label(Data.tv("YOUR GARAGE", "YOUR DECK") + "  (" + Data.tv("Cars in garage: %d", "Cards in deck: %d") % deck.size() + ", " + tr("Left to draw: %d") % draw_pile.size() + ")", 24, Color("ffd23f"), 6)
	t.size = Vector2(960, 40)
	t.position = Vector2(0, 10)
	p.add_child(t)
	var left_ids := {}
	for d in draw_pile:
		left_ids[d.id] = true
	for s in 4:
		var cards := deck.filter(func(d): return d.suit == s)
		cards.sort_custom(func(a, b): return a.rank > b.rank)
		var sl := _label(tr(Data.suit_name(s)), 16, Data.suit_color(s).lightened(0.3), 4)
		sl.position = Vector2(14, 92 + s * 128)
		sl.size = Vector2(90, 20)
		p.add_child(sl)
		var spacing := minf(56.0, 800.0 / maxf(cards.size(), 1))
		for i in cards.size():
			var cv := _make_card(CardView.CAR, cards[i], p)
			cv.base_scale = 0.62
			cv.scale = Vector2(0.62, 0.62)
			cv.target_pos = Vector2(90 + i * spacing, 36 + s * 128)
			cv.position = cv.target_pos
			cv.base_z = i
			cv.z_index = i
			cv.dimmed = state == "play" and not left_ids.has(cards[i].id)
	var b := _close_button()
	b.position = Vector2(380, 578)
	p.add_child(b)
	_modal(p)


func _help_text() -> String:
	var suits := ", ".join(range(4).map(func(i): return tr(Data.suit_name(i))))
	var hd := func(t: String) -> String: return "\n[color=#ffd23f]%s[/color]\n" % t
	var t := Data.tv("Your deck is a [color=#ffd23f]garage of 52 cars[/color]: 4 suits (%s) x 13 ranks.",
		"Your deck has [color=#ffd23f]52 cards[/color]: 4 suits (%s) x 13 ranks.") % suits + "\n\n"
	t += "- " + Data.tv("Select up to 5 cars and [color=#2f8cff]Play[/color] them as a poker hand.", "Select up to 5 cards and [color=#2f8cff]Play[/color] them as a poker hand.")
	if not Data.classic_art:
		t += " " + tr("A Tandem is a Pair, a Gear Shift is a Straight, a Same Garage is a Flush, and so on.")
	t += "\n- " + Data.tv("Score = [color=#2f8cff]Chips[/color] x [color=#ff4b3e]Mult[/color]. Every scored car adds its chips.", "Score = [color=#2f8cff]Chips[/color] x [color=#ff4b3e]Mult[/color]. Every scored card adds its chips.")
	t += "\n- " + Data.tv("Beat the target score before you run out of hands. [color=#ff4b3e]Discard[/color] to dig for better cars.", "Beat the target score before you run out of hands. [color=#ff4b3e]Discard[/color] to dig for better cards.")
	t += "\n- " + tr("Each Ante has a Street Race, a Circuit Race and a [color=#ff4b3e]Boss Race[/color] with a nasty rule.")
	t += "\n- " + Data.tv("Spend cash at the [color=#e8572f]Pit Stop[/color]: Mods change how you score, Dyno Tunes level up hands, Workshop cards upgrade your cars.",
		"Spend cash at the [color=#e8572f]Pit Stop[/color]: Jokers change how you score, Upgrades level up hands, Trick cards change your cards.")
	t += "\n- " + tr("Booster packs: open one and take 1 of the choices.")
	t += "\n- " + Data.tv("Sponsors give a permanent bonus for the whole run. The Pit Stop offers one each ante.",
		"Vouchers give a permanent bonus for the whole run. The Pit Stop offers one each ante.")
	t += "\n- " + tr("Win the Grand Prix at Ante 8 to become Champion.") + "\n"
	t += hd.call(tr("Card upgrades"))
	for e in Data.ENH_INFO:
		var info: Dictionary = Data.ENH_INFO[e]
		t += "- [color=%s]%s[/color]: %s\n" % [Data.ENH_COLORS[e].lightened(0.3).to_html(false), Data.text(info, "name"), _bb_dark(tr(info.desc)).replace("\n", " ")]
	t += hd.call(tr("Editions"))
	t += Data.tv("Some Mods come with an edition (they cost more):", "Some Jokers come with an edition (they cost more):") + "\n"
	for e in Data.EDITIONS:
		var ed: Dictionary = Data.EDITIONS[e]
		t += "- [color=#7fe0d0]%s[/color]: %s\n" % [Data.text(ed, "name"), _bb_dark(Data.text(ed, "desc"))]
	t += hd.call(tr("Card statuses"))
	t += "- [color=#ff4b3e]%s[/color]: %s\n" % [tr("Debuffed"), Data.tv("the boss blocks this car: it gives no chips and no effects.", "the boss blocks this card: it gives no chips and no effects.")]
	t += "- [color=#ffd23f]%s[/color]: %s\n" % [Data.tv("Face cars", "Face cards"), tr("J, Q and K. Some effects count only them.")]
	t += "- [color=#ffd23f]%s[/color]: %s\n" % [tr(Data.rank_name(14)), tr("Counts high or low in a %s") % tr(Data.hand_name(Scoring.STRAIGHT))]
	t += "- [color=#d9822b]%s[/color]: %s\n" % [tr("Again!"), Data.tv("the car scores one more time.", "the card scores one more time.")]
	t += "- [color=#aab4c3]%s[/color]: %s\n" % [tr("Broken!"), Data.tv("a Carbon car broke and left your garage.", "a Glass card broke and left your deck.")]
	t += hd.call(Data.tv("Garage cards", "Items"))
	t += Data.tv("Dyno Tunes and Cash Grab work at once. Workshop cards need cars: select them in your hand, then click the card and press Use.",
		"Upgrades and Cash Grab work at once. Trick cards need cards: select them in your hand, then click the item and press Use.") + "\n\n"
	t += "[color=#aaaaaa]%s[/color]" % tr("Keys: Enter = Play hand, Backspace = Discard, Esc = Menu, M = Music, F11 = Fullscreen. Hover any card for details.")
	return t


func _show_help() -> void:
	var p := _panel(PANEL_BG, Color("d9822b"), 3, 22, 16)
	p.position = Vector2(290, 50)
	p.custom_minimum_size = Vector2(700, 0)
	var v := _vbox(10)
	p.add_child(v)
	v.add_child(_label("HOW TO PLAY", 30, Color("ffb347"), 8))
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = true
	r.custom_minimum_size = Vector2(650, 430)
	r.add_theme_font_size_override("normal_font_size", 16)
	r.text = _help_text()
	v.add_child(r)
	v.add_child(_close_button())
	_modal(p)
