extends SceneTree
## Run: godot --headless --path . -s res://tests/test_scoring.gd

const S = preload("res://scripts/scoring.gd")

var fails := 0


func c(r: int, s: int, e := "") -> Dictionary:
	return {"id": 0, "rank": r, "suit": s, "enh": e}


func check(name: String, got, want) -> void:
	if got != want:
		fails += 1
		print("FAIL %s: got %s, want %s" % [name, got, want])


func score(cards: Array, mods := [], ctx := {}) -> Dictionary:
	var base := {"hands_left": 4, "hands_played": 1, "deck_size": 52, "played_types": []}
	base.merge(ctx, true)
	var lv := []
	lv.resize(9)
	lv.fill(1)
	return S.score_hand(cards, mods, lv, base, RandomNumberGenerator.new())


func _init() -> void:
	check("high", S.evaluate([c(3, 0), c(9, 1), c(14, 2)]).type, S.HIGH)
	check("high scoring", S.evaluate([c(3, 0), c(9, 1), c(14, 2)]).scoring, [2])
	check("pair", S.evaluate([c(5, 0), c(5, 1), c(9, 2)]).type, S.PAIR)
	check("pair scoring", S.evaluate([c(5, 0), c(9, 2), c(5, 1)]).scoring, [0, 2])
	check("two pair", S.evaluate([c(5, 0), c(5, 1), c(9, 2), c(9, 3), c(2, 0)]).type, S.TWO_PAIR)
	check("three", S.evaluate([c(7, 0), c(7, 1), c(7, 2)]).type, S.THREE)
	check("straight", S.evaluate([c(6, 0), c(7, 1), c(8, 2), c(9, 3), c(10, 0)]).type, S.STRAIGHT)
	check("wheel", S.evaluate([c(14, 0), c(2, 1), c(3, 2), c(4, 3), c(5, 0)]).type, S.STRAIGHT)
	check("not straight wrap", S.evaluate([c(13, 0), c(14, 1), c(2, 2), c(3, 3), c(4, 0)]).type, S.HIGH)
	check("flush", S.evaluate([c(2, 1), c(7, 1), c(9, 1), c(11, 1), c(4, 1)]).type, S.FLUSH)
	check("full house", S.evaluate([c(3, 0), c(3, 1), c(3, 2), c(8, 0), c(8, 1)]).type, S.FULL_HOUSE)
	check("four", S.evaluate([c(12, 0), c(12, 1), c(12, 2), c(12, 3), c(2, 0)]).type, S.FOUR)
	check("four scoring", S.evaluate([c(12, 0), c(12, 1), c(12, 2), c(12, 3), c(2, 0)]).scoring, [0, 1, 2, 3])
	check("straight flush", S.evaluate([c(9, 2), c(10, 2), c(11, 2), c(12, 2), c(13, 2)]).type, S.STRAIGHT_FLUSH)

	# Pair of kings: (10 + 10 + 10) x 2 = 60
	check("pair score", score([c(13, 0), c(13, 1)]).total, 60)
	# Nitro Boost +4 mult: 30 x 6 = 180
	check("nitro mod", score([c(13, 0), c(13, 1)], [{"id": "nitro"}]).total, 180)
	# Nitro enhancement on one king: 60 x 2 = 120
	check("nitro enh", score([c(13, 0, "nitro"), c(13, 1)]).total, 120)
	# Rev limiter: first king scores 3 times: (10 + 30 + 10) x 2 = 100
	check("rev limiter", score([c(13, 0), c(13, 1)], [{"id": "rev_limiter"}]).total, 100)
	# Boss bans Muscle: only second king scores: (10 + 10) x 2 = 40
	check("debuff", score([c(13, 0), c(13, 1)], [], {"boss": {"id": "ban", "suit": 0}}).total, 40)
	# Rival: repeated hand scores 0
	check("rival", score([c(13, 0), c(13, 1)], [], {"boss": {"id": "rival"}, "played_types": [S.PAIR]}).total, 0)
	# Final lap x3 on last hand: 30 x 6 = 180
	check("final lap", score([c(13, 0), c(13, 1)], [{"id": "final_lap"}], {"hands_left": 1}).total, 180)
	# Odometer scales
	var odo := {"id": "odometer", "val": 0}
	score([c(2, 0)], [odo])
	check("odometer", odo.val, 1)
	# Gold rims give money
	check("gold", score([c(2, 0, "gold")]).money, 2)
	check("num_str", S.num_str(1.5), "1.5")
	check("num_str int", S.num_str(2.0), "2")

	print("ALL TESTS PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
