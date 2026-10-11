extends SceneTree
# Clean screenshots for the README and the website, saved to docs/screenshots at 1280x720.
# Run: godot --path . --resolution 1280x720 -s res://tools/readme_shots.gd
const OUT = "res://docs/screenshots/"
var g
var D = preload("res://scripts/data.gd")

func shot(n):
	await process_frame
	await process_frame
	var im: Image = root.get_texture().get_image()
	im.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	im.save_png(ProjectSettings.globalize_path(OUT + n + ".png"))
	print("saved ", n)

func t(s): await create_timer(s).timeout

func add_mod(id, edition := ""):
	var m = D.mod_def(id).duplicate(true)
	if edition != "": m.edition = edition
	g.mods.append(m); g.mod_views.append(g._make_card(1, m))

func add_cons(c):
	g.consumables.append(c); g.cons_views.append(g._make_card(2, c))

func _initialize():
	DirAccess.remove_absolute("user://settings.cfg"); DirAccess.remove_absolute("user://run.save")
	TranslationServer.set_locale("en")
	seed(7)
	g = load("res://main.tscn").instantiate(); root.add_child(g)
	g.rng.seed = 7
	await t(0.3)
	g._show_setup(2); await t(0.8); await shot("setup")  # first launch: card look
	g._finish_setup()
	get_root_redraw()
	await t(1.0); await shot("title")  # the default look: classic cards

	D.set_themes("cars", "cars"); D.back_style = 0
	get_root_redraw()
	# race, car theme, mid-scoring
	g._start_run(); g._start_race(); await t(1.8)
	add_mod("nitro", "poly"); add_mod("twin_turbo"); add_mod("drift_king", "foil"); add_mod("v8"); add_mod("final_lap")
	add_cons({"id": "tune", "hand": 1, "cost": 3}); add_cons(D.WORKSHOP[0].duplicate(true))
	g._layout_slots(); g._update_sidebar()
	# make a pair of kings so the scoring shows mod effects
	g.hand[0].data.rank = 13; g.hand[1].data.rank = 13
	g.hand[0].data.suit = 0; g.hand[1].data.suit = 2
	for c in g.hand: c.queue_redraw()
	g._sort_hand(); g._layout_hand(); await t(0.4)
	for c in g.hand:
		if c.data.rank == 13: c.selected = true
	g._update_preview(); g._update_buttons(); await t(0.6)
	g.play_hand(); await t(2.6); await shot("race_cars")
	await t(6.0)

	# shop with a sponsor offer and packs
	g.hand.map(func(c): c.queue_free()); g.hand.clear()
	g.money = 34; g.voucher_offer = "antimatter"; g.state = "shop"; g._open_shop(); await t(1.2); await shot("pit_stop")
	g._clear(g.overlay); g.shop_views.clear()

	# collection
	g._show_collection(1); await t(0.6); await shot("collection_mods")
	g._clear(g.modal_layer)

	# classic theme race with a tooltip
	D.set_themes("classic", "classic"); D.back_style = 4
	g.busy = false; g.state = "blind"; g.blind_idx = 0; g._start_race(); await t(0.1)
	get_root_redraw(); g._update_sidebar(); await t(1.8)
	var court = null
	for c in g.hand:
		if c.data.rank >= 11 and c.data.rank <= 13: court = c
	if court == null: court = g.hand[0]
	court.data.enh = "nitro"; court.queue_redraw()
	g._on_card_hover(court, true); await t(0.4); await shot("race_classic")
	g._on_card_hover(court, false)

	g._show_collection(4); await t(0.6); await shot("collection_vouchers")
	g._clear(g.modal_layer)

	# Doctor Who theme race with a tooltip on the Doctor
	D.set_themes("who", "who"); D.back_style = 6
	g.hand.map(func(c): c.queue_free()); g.hand.clear()
	g.busy = false; g.state = "blind"; g._start_race(); await t(0.1)
	get_root_redraw(); g._update_sidebar(); await t(1.8)
	var doc = g.hand[0]
	doc.data.rank = 13; doc.queue_redraw()
	g._sort_hand(); g._layout_hand(); await t(0.5)
	g._on_card_hover(doc, true); await t(0.4); await shot("race_who")
	g._on_card_hover(doc, false)
	D.set_themes("classic", "classic"); D.back_style = 4
	get_root_redraw()

	g._show_settings(); await t(0.6); await shot("settings")
	g._clear(g.modal_layer)

	# How to Play, mid-animation on the Jokers step
	g._show_help(5); await t(3.4); await shot("how_to_play")
	g._clear(g.modal_layer)

	# interactive tutorial: the hint that asks for the two Kings
	g._start_run(true); await t(0.6)
	g.tutorial_node._go(1); await t(0.3)
	g._start_race(); await t(2.0)
	g.tutorial_node._go(5); await t(0.6); await shot("tutorial")
	g._show_title()
	quit()


func get_root_redraw():
	call_group("cards", "queue_redraw")
	if g and g.sort_suit_btn:
		g._refresh_texts()
