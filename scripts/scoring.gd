extends RefCounted
## Hand evaluation and scoring. Pure functions over card dictionaries,
## except that scaling mods (Odometer) update their own "val".

const Data = preload("res://scripts/data.gd")

enum { HIGH, PAIR, TWO_PAIR, THREE, STRAIGHT, FLUSH, FULL_HOUSE, FOUR, STRAIGHT_FLUSH }


static func chip_value(rank: int) -> int:
	return 11 if rank == 14 else mini(rank, 10)


static func is_face(rank: int) -> bool:
	return rank >= 11 and rank <= 13


static func card_debuffed(card: Dictionary, boss: Dictionary) -> bool:
	match boss.get("id", ""):
		"ban":
			return card.suit == boss.suit
		"roadblock":
			return is_face(card.rank)
	return false


## Returns {type, scoring (indices into cards), has (what the hand contains)}.
static func evaluate(cards: Array) -> Dictionary:
	var n := cards.size()
	if n == 0:
		return {"type": -1, "scoring": [], "has": {}}
	var by_rank := {}
	for i in n:
		var r: int = cards[i].rank
		if not by_rank.has(r):
			by_rank[r] = []
		by_rank[r].append(i)
	var groups: Array = by_rank.values()
	groups.sort_custom(func(a, b):
		if a.size() != b.size():
			return a.size() > b.size()
		return cards[a[0]].rank > cards[b[0]].rank)
	var flush := n == 5
	for c in cards:
		if c.suit != cards[0].suit:
			flush = false
	var straight := false
	if n == 5 and groups.size() == 5:
		var ranks: Array = by_rank.keys()
		ranks.sort()
		straight = ranks[4] - ranks[0] == 4 or ranks == [2, 3, 4, 5, 14]
	var g0: int = groups[0].size()
	var g1: int = groups[1].size() if groups.size() > 1 else 0
	var has := {"pair": g0 >= 2, "two_pair": g0 >= 2 and g1 >= 2, "three": g0 >= 3,
		"four": g0 >= 4, "straight": straight, "flush": flush}
	var all := range(n)
	var t: int
	var scoring: Array
	if straight and flush:
		t = STRAIGHT_FLUSH; scoring = all
	elif g0 >= 4:
		t = FOUR; scoring = groups[0]
	elif g0 == 3 and g1 >= 2:
		t = FULL_HOUSE; scoring = all
	elif flush:
		t = FLUSH; scoring = all
	elif straight:
		t = STRAIGHT; scoring = all
	elif g0 == 3:
		t = THREE; scoring = groups[0]
	elif g0 == 2 and g1 == 2:
		t = TWO_PAIR; scoring = groups[0] + groups[1]
	elif g0 == 2:
		t = PAIR; scoring = groups[0]
	else:
		t = HIGH; scoring = [groups[0][0]]
	scoring = scoring.duplicate()
	scoring.sort()
	return {"type": t, "scoring": scoring, "has": has}


## ctx: {boss, hands_left (before this hand), hands_played, deck_size, played_types}.
## Returns events for the animation; each event stores the running chips (c) and mult (m).
static func score_hand(played: Array, mods: Array, levels: Array, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var ev := evaluate(played)
	var t: int = ev.type
	var h: Dictionary = Data.HANDS[t]
	var lvl: int = levels[t]
	var boss: Dictionary = ctx.get("boss", {})
	var s := {"chips": float(h.chips + h.lc * (lvl - 1)), "mult": float(h.mult + h.lm * (lvl - 1)), "money": 0, "events": []}
	if boss.get("id", "") == "tunnel":
		s.chips = ceilf(s.chips / 2.0)
		s.mult = maxf(1.0, ceilf(s.mult / 2.0))
	var res := {"type": t, "scoring": ev.scoring, "base_chips": s.chips, "base_mult": s.mult, "broken": []}
	if boss.get("id", "") == "rival" and ctx.get("played_types", []).has(t):
		s.chips = 0.0
		s.mult = 0.0
		_add(s, "hand", 0, "zero", 0)
		return _finish(res, s)

	var first_face_done := false
	var first_scored := true
	for idx in ev.scoring:
		var card: Dictionary = played[idx]
		if card_debuffed(card, boss):
			_add(s, "card", idx, "debuff", 0)
			continue
		var triggers := 1
		if first_scored and _has(mods, "rev_limiter"):
			triggers += 2
		if card.rank <= 5 and _has(mods, "echo_exhaust"):
			triggers += 1
		first_scored = false
		var photo := false
		if is_face(card.rank) and not first_face_done:
			photo = true
			first_face_done = true
		for k in triggers:
			if k > 0:
				_add(s, "card", idx, "again", 0)
			_add(s, "card", idx, "chips", chip_value(card.rank))
			match card.get("enh", ""):
				"nitro": _add(s, "card", idx, "chips", 30)
				"turbo": _add(s, "card", idx, "mult", 4)
				"carbon": _add(s, "card", idx, "xmult", 2)
				"gold": _add(s, "card", idx, "money", 2)
			for mi in mods.size():
				var id: String = mods[mi].id
				var r: int = card.rank
				match id:
					"v8", "rising_sun", "autobahn", "mud_tires":
						if card.suit == Data.mod_def(id).suit:
							_add(s, "mod", mi, "mult", 3, idx)
					"chrome_bumper":
						if is_face(r):
							_add(s, "mod", mi, "chips", 30, idx)
					"ace_driver":
						if r == 14:
							_add(s, "mod", mi, "chips", 20, idx)
							_add(s, "mod", mi, "mult", 4, idx)
					"even_gears":
						if r <= 10 and r % 2 == 0:
							_add(s, "mod", mi, "mult", 4, idx)
					"odd_gears":
						if r == 14 or (r <= 10 and r % 2 == 1):
							_add(s, "mod", mi, "chips", 31, idx)
					"photo_finish":
						if photo:
							_add(s, "mod", mi, "xmult", 2, idx)
		if card.get("enh", "") == "carbon" and rng.randf() < 0.25:
			res.broken.append(idx)

	var has: Dictionary = ev.has
	for mi in mods.size():
		var m: Dictionary = mods[mi]
		match m.get("edition", ""):
			"foil": _add(s, "mod", mi, "chips", 50)
			"holo": _add(s, "mod", mi, "mult", 10)
		match m.id:
			"nitro": _add(s, "mod", mi, "mult", 4)
			"twin_turbo":
				if has.pair: _add(s, "mod", mi, "mult", 8)
			"wide_body":
				if has.pair: _add(s, "mod", mi, "chips", 50)
			"convoy_leader":
				if has.three: _add(s, "mod", mi, "mult", 12)
			"drift_king":
				if has.straight: _add(s, "mod", mi, "mult", 12)
			"brand_loyalty":
				if has.flush: _add(s, "mod", mi, "mult", 10)
			"lightweight":
				if played.size() <= 3: _add(s, "mod", mi, "mult", 20)
			"odometer":
				m.val = m.get("val", 0) + 1
				_add(s, "mod", mi, "mult", m.val)
			"car_show": _add(s, "mod", mi, "mult", 4 * mods.size())
			"scrap_collector":
				var missing: int = 52 - ctx.get("deck_size", 52)
				if missing > 0: _add(s, "mod", mi, "mult", 3 * missing)
			"launch_control":
				if ctx.get("hands_played", 0) == 0: _add(s, "mod", mi, "xmult", 2)
			"final_lap":
				if ctx.get("hands_left", 0) == 1: _add(s, "mod", mi, "xmult", 3)
			"supercharger": _add(s, "mod", mi, "xmult", 1.5)
			"getaway":
				if m.get("val", 1.0) > 1.0: _add(s, "mod", mi, "xmult", m.val)
		if m.get("edition", "") == "poly":
			_add(s, "mod", mi, "xmult", 1.5)
	return _finish(res, s)


static func num_str(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return ("%.2f" % v).rstrip("0")


static func _has(mods: Array, id: String) -> bool:
	return mods.any(func(m): return m.id == id)


static func _finish(res: Dictionary, s: Dictionary) -> Dictionary:
	res.events = s.events
	res.chips = s.chips
	res.mult = s.mult
	res.money = s.money
	res.total = int(floor(s.chips * s.mult))
	return res


static func _add(s: Dictionary, src: String, i: int, kind: String, v: float, at := -1) -> void:
	match kind:
		"chips": s.chips += v
		"mult": s.mult += v
		"xmult": s.mult *= v
		"money": s.money += int(v)
	s.events.append({"src": src, "i": i, "at": at, "kind": kind, "v": v, "c": s.chips, "m": s.mult})
