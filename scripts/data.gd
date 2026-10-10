extends RefCounted
## Static game data: suits, hand types, mods, workshop cards, packs, boss races.
##
## Two independent visual themes change the card vocabulary:
##   classic_art   - cards are drawn as classic playing cards ("cards", Jack/Queen, Bonus/Glass...)
##                   instead of cars ("cars", Sport/Hyper, Nitro/Carbon...).
##   classic_suits - Hearts/Diamonds/Spades/Clubs instead of Muscle/JDM/Euro/Offroad.
## Text fields can have variants: <field>_cards (classic art), <field>_suits (classic suits),
## <field>_cards_suits (both). pick() chooses the most specific one; "%s" in a text is the suit name.

static var classic_art := false
static var classic_suits := true
static var back_style := 4  # Classic Red

const SUIT_NAMES := ["Muscle", "JDM", "Euro", "Offroad"]
const SUIT_COLORS := [Color("e2443a"), Color("f08a24"), Color("3b6fd6"), Color("3a9a4a")]
const CLASSIC_SUIT_NAMES := ["Hearts", "Diamonds", "Spades", "Clubs"]
const CLASSIC_SUIT_COLORS := [Color("d62828"), Color("e8590c"), Color("1f2a44"), Color("1e5631")]
const RANK_NAMES := {11: "Jack", 12: "Queen", 13: "King", 14: "Ace"}
const CAR_RANK_NAMES := {11: "Sport", 12: "Super", 13: "Hyper", 14: "Legend"}
const RANK_SHORT := {11: "J", 12: "Q", 13: "K", 14: "A"}
const FACE_TITLES := {11: "SPORT", 12: "SUPER", 13: "HYPER", 14: "LEGEND"}
const BACKS := ["Checkered Flag", "Racing Stripes", "Carbon Fiber", "Neon Grid", "Classic Red", "Classic Blue"]

const KIND_COLORS := {
	"mult": Color("ff4b3e"), "chips": Color("2f8cff"), "xmult": Color("c13cff"),
	"econ": Color("ffc93c"), "util": Color("3ecf6a"),
}
const RARITY_NAMES := ["COMMON", "UNCOMMON", "RARE"]
const RARITY_WEIGHTS := [70.0, 25.0, 6.0]

# Poker hands with car names. lc/lm = chips/mult gained per level.
const HANDS := [
	{"name": "Solo Drive", "poker": "High Card", "chips": 5, "mult": 1, "lc": 10, "lm": 1},
	{"name": "Tandem", "poker": "Pair", "chips": 10, "mult": 2, "lc": 15, "lm": 1},
	{"name": "Double Tandem", "poker": "Two Pair", "chips": 20, "mult": 2, "lc": 20, "lm": 1},
	{"name": "Convoy", "poker": "Three of a Kind", "chips": 30, "mult": 3, "lc": 20, "lm": 2},
	{"name": "Gear Shift", "poker": "Straight", "chips": 30, "mult": 4, "lc": 30, "lm": 3},
	{"name": "Same Garage", "poker": "Flush", "chips": 35, "mult": 4, "lc": 15, "lm": 2},
	{"name": "Full Garage", "poker": "Full House", "chips": 40, "mult": 4, "lc": 25, "lm": 2},
	{"name": "Fleet", "poker": "Four of a Kind", "chips": 60, "mult": 7, "lc": 30, "lm": 3},
	{"name": "Factory Line", "poker": "Straight Flush", "chips": 100, "mult": 8, "lc": 40, "lm": 4},
]

# Example cards for each hand type: [rank, suit].
const HAND_EXAMPLES := [
	[[14, 2]],
	[[13, 0], [13, 3]],
	[[12, 1], [12, 2], [5, 0], [5, 3]],
	[[7, 0], [7, 1], [7, 2]],
	[[9, 2], [8, 0], [7, 3], [6, 1], [5, 2]],
	[[13, 1], [9, 1], [7, 1], [4, 1], [2, 1]],
	[[11, 0], [11, 2], [11, 3], [4, 1], [4, 2]],
	[[8, 0], [8, 1], [8, 2], [8, 3]],
	[[11, 3], [10, 3], [9, 3], [8, 3], [7, 3]],
]

# Card upgrades (enhancements).
const ENH_INFO := {
	"nitro": {"name": "Nitro", "name_cards": "Bonus", "badge": "NITRO", "badge_cards": "BONUS", "desc": "[c]+30[/] Chips when scored"},
	"turbo": {"name": "Turbo", "name_cards": "Power", "badge": "TURBO", "badge_cards": "POWER", "desc": "[m]+4[/] Mult when scored"},
	"carbon": {"name": "Carbon", "name_cards": "Glass", "badge": "CARBON", "badge_cards": "GLASS", "desc": "[x]X2[/] Mult when scored,\n1 in 4 chance to break"},
	"gold": {"name": "Gold Rims", "name_cards": "Gold", "badge": "GOLD", "badge_cards": "GOLD", "desc": "[$]+$2[/] when scored"},
}
# Mod editions, like the original game. weight = % chance for a mod in the shop or a pack.
const EDITIONS := {
	"foil": {"name": "Chrome Wrap", "name_cards": "Foil", "badge": "CHROME", "badge_cards": "FOIL", "desc": "[c]+50[/] Chips", "extra": 2, "weight": 5.0, "mode": 1},
	"holo": {"name": "Holo Decal", "name_cards": "Holographic", "badge": "HOLO", "badge_cards": "HOLO", "desc": "[m]+10[/] Mult", "extra": 3, "weight": 3.5, "mode": 2},
	"poly": {"name": "Pearl Paint", "name_cards": "Polychrome", "badge": "PEARL", "badge_cards": "POLY", "desc": "[x]X1.5[/] Mult", "extra": 5, "weight": 1.5, "mode": 3},
	"negative": {"name": "Matte Black", "name_cards": "Negative", "badge": "MATTE", "badge_cards": "NEGATIVE", "desc": "[g]+1[/] Mod slot", "desc_cards": "[g]+1[/] Joker slot", "extra": 5, "weight": 1.5, "mode": 4},
}

const ENH_COLORS := {"nitro": Color("2f8cff"), "turbo": Color("ff4b3e"), "carbon": Color("555b66"), "gold": Color("c9971c")}

const CAR_BODIES := [
	[Vector2(-1, 0.2), Vector2(-1, -0.06), Vector2(-0.9, -0.12), Vector2(-0.5, -0.14), Vector2(-0.3, -0.42),
		Vector2(0.2, -0.42), Vector2(0.42, -0.14), Vector2(0.96, -0.1), Vector2(1.02, 0.04), Vector2(1, 0.2)],
	[Vector2(-1, 0.2), Vector2(-1, -0.1), Vector2(-0.62, -0.18), Vector2(-0.36, -0.44), Vector2(0.22, -0.44),
		Vector2(0.5, -0.2), Vector2(0.94, -0.14), Vector2(1, 0), Vector2(1, 0.2)],
	[Vector2(-1, 0.18), Vector2(-1, -0.06), Vector2(-0.75, -0.12), Vector2(-0.3, -0.34), Vector2(0.1, -0.34),
		Vector2(0.5, -0.14), Vector2(1.02, -0.04), Vector2(1, 0.18)],
	[Vector2(-1, 0.22), Vector2(-1, -0.46), Vector2(0.3, -0.46), Vector2(0.56, -0.14), Vector2(0.98, -0.1), Vector2(1, 0.22)],
]
const CAR_WINDOWS := [
	[Vector2(-0.24, -0.16), Vector2(-0.16, -0.36), Vector2(0.16, -0.36), Vector2(0.34, -0.16)],
	[Vector2(-0.3, -0.2), Vector2(-0.22, -0.38), Vector2(0.18, -0.38), Vector2(0.4, -0.2)],
	[Vector2(-0.28, -0.15), Vector2(-0.18, -0.29), Vector2(0.08, -0.29), Vector2(0.34, -0.15)],
	[Vector2(-0.6, -0.18), Vector2(-0.6, -0.38), Vector2(0.26, -0.38), Vector2(0.46, -0.18)],
]

# Jokers, but for cars. Text tokens: [c] chips, [m] mult, [x] xmult, [$] money, [g] highlight, [/] close.

const SUIT_MOD_DESC := "Played [g]%s[/] cars give\n[m]+3[/] Mult when scored"
const SUIT_MOD_DESC_CARDS := "Played [g]%s[/] cards give\n[m]+3[/] Mult when scored"
const SUIT_MOD_DESC_SUITS := "Played [g]%s[/] give\n[m]+3[/] Mult when scored"

# Jokers, but for cars. Text tokens: [c] chips, [m] mult, [x] xmult, [$] money, [g] highlight, [/] close.
const MODS := [
	{"id": "nitro", "name": "Nitro Boost", "name_cards": "Joker", "kind": "mult", "cost": 2, "desc": "[m]+4[/] Mult"},
	{"id": "v8", "name": "V8 Heart", "name_suits": "Heart Throb", "kind": "mult", "cost": 5, "suit": 0,
		"desc": SUIT_MOD_DESC, "desc_cards": SUIT_MOD_DESC_CARDS, "desc_suits": SUIT_MOD_DESC_SUITS},
	{"id": "rising_sun", "name": "Rising Sun", "name_suits": "Diamond Ring", "kind": "mult", "cost": 5, "suit": 1,
		"desc": SUIT_MOD_DESC, "desc_cards": SUIT_MOD_DESC_CARDS, "desc_suits": SUIT_MOD_DESC_SUITS},
	{"id": "autobahn", "name": "Autobahn", "name_suits": "Spade Digger", "kind": "mult", "cost": 5, "suit": 2,
		"desc": SUIT_MOD_DESC, "desc_cards": SUIT_MOD_DESC_CARDS, "desc_suits": SUIT_MOD_DESC_SUITS},
	{"id": "mud_tires", "name": "Mud Tires", "name_suits": "Club Regular", "kind": "mult", "cost": 5, "suit": 3,
		"desc": SUIT_MOD_DESC, "desc_cards": SUIT_MOD_DESC_CARDS, "desc_suits": SUIT_MOD_DESC_SUITS},
	{"id": "twin_turbo", "name": "Twin Turbo", "name_cards": "Double Trouble", "kind": "mult", "cost": 3,
		"desc": "[m]+8[/] Mult if hand contains\na [g]Tandem[/] (Pair)", "desc_cards": "[m]+8[/] Mult if hand\ncontains a [g]Pair[/]"},
	{"id": "wide_body", "name": "Wide Body", "name_cards": "Twin Peaks", "kind": "chips", "cost": 3,
		"desc": "[c]+50[/] Chips if hand contains\na [g]Tandem[/] (Pair)", "desc_cards": "[c]+50[/] Chips if hand\ncontains a [g]Pair[/]"},
	{"id": "convoy_leader", "name": "Convoy Leader", "name_cards": "Triple Threat", "kind": "mult", "cost": 4,
		"desc": "[m]+12[/] Mult if hand contains\na [g]Convoy[/] (Three of a Kind)", "desc_cards": "[m]+12[/] Mult if hand contains\na [g]Three of a Kind[/]"},
	{"id": "drift_king", "name": "Drift King", "name_cards": "Straight Shooter", "kind": "mult", "cost": 4,
		"desc": "[m]+12[/] Mult if hand contains\na [g]Gear Shift[/] (Straight)", "desc_cards": "[m]+12[/] Mult if hand\ncontains a [g]Straight[/]"},
	{"id": "brand_loyalty", "name": "Brand Loyalty", "name_cards": "Suit Up", "kind": "mult", "cost": 4,
		"desc": "[m]+10[/] Mult if hand contains\na [g]Same Garage[/] (Flush)", "desc_cards": "[m]+10[/] Mult if hand\ncontains a [g]Flush[/]"},
	{"id": "lightweight", "name": "Lightweight", "name_cards": "Minimalist", "kind": "mult", "cost": 5, "rarity": 1,
		"desc": "[m]+20[/] Mult if played hand\nhas [g]3 or fewer[/] cars", "desc_cards": "[m]+20[/] Mult if played hand\nhas [g]3 or fewer[/] cards"},
	{"id": "odometer", "name": "Odometer", "name_cards": "Card Counter", "kind": "mult", "cost": 5, "rarity": 1, "val": 0,
		"desc": "Gains [m]+1[/] Mult per hand played\n(Currently [m]+{val}[/] Mult)"},
	{"id": "chrome_bumper", "name": "Chrome Bumper", "name_cards": "Royal Guard", "kind": "chips", "cost": 4,
		"desc": "Played face cars (J, Q, K)\ngive [c]+30[/] Chips when scored", "desc_cards": "Played face cards (J, Q, K)\ngive [c]+30[/] Chips when scored"},
	{"id": "ace_driver", "name": "Ace Driver", "name_cards": "Ace Up the Sleeve", "kind": "mult", "cost": 4,
		"desc": "Played Aces give [c]+20[/] Chips\nand [m]+4[/] Mult when scored"},
	{"id": "even_gears", "name": "Even Gears", "name_cards": "Even Odds", "kind": "mult", "cost": 4,
		"desc": "Played 10, 8, 6, 4, 2\ngive [m]+4[/] Mult when scored"},
	{"id": "odd_gears", "name": "Odd Gears", "name_cards": "Odd One Out", "kind": "chips", "cost": 4,
		"desc": "Played A, 9, 7, 5, 3\ngive [c]+31[/] Chips when scored"},
	{"id": "car_show", "name": "Car Show", "name_cards": "Full Table", "kind": "mult", "cost": 5, "rarity": 1,
		"desc": "[m]+4[/] Mult for each Mod you own\n(Currently [m]+{val}[/] Mult)", "desc_cards": "[m]+4[/] Mult for each Joker you own\n(Currently [m]+{val}[/] Mult)"},
	{"id": "scrap_collector", "name": "Scrap Collector", "name_cards": "Thin Deck", "kind": "mult", "cost": 5, "rarity": 1,
		"desc": "[m]+3[/] Mult for each car below 52\nin your garage (Currently [m]+{val}[/])", "desc_cards": "[m]+3[/] Mult for each card below 52\nin your deck (Currently [m]+{val}[/])"},
	{"id": "rev_limiter", "name": "Rev Limiter", "name_cards": "Encore", "kind": "util", "cost": 5, "rarity": 1,
		"desc": "Retrigger the first scored\ncar [g]2[/] additional times", "desc_cards": "Retrigger the first scored\ncard [g]2[/] additional times"},
	{"id": "echo_exhaust", "name": "Echo Exhaust", "name_cards": "Small Fry", "kind": "util", "cost": 6, "rarity": 1,
		"desc": "Retrigger each played\n[g]2, 3, 4[/] and [g]5[/]"},
	{"id": "launch_control", "name": "Launch Control", "name_cards": "Opening Bet", "kind": "xmult", "cost": 6, "rarity": 1,
		"desc": "[x]X2[/] Mult on the [g]first[/]\nhand of each race"},
	{"id": "final_lap", "name": "Final Lap", "name_cards": "Last Call", "kind": "xmult", "cost": 7, "rarity": 1,
		"desc": "[x]X3[/] Mult on the [g]last[/]\nhand of each race"},
	{"id": "photo_finish", "name": "Photo Finish", "name_cards": "Portrait", "kind": "xmult", "cost": 6, "rarity": 1,
		"desc": "First played face car\ngives [x]X2[/] Mult when scored", "desc_cards": "First played face card\ngives [x]X2[/] Mult when scored"},
	{"id": "supercharger", "name": "Supercharger", "name_cards": "High Roller", "kind": "xmult", "cost": 9, "rarity": 2, "desc": "[x]X1.5[/] Mult"},
	{"id": "getaway", "name": "Getaway Driver", "name_cards": "Boss Hunter", "kind": "xmult", "cost": 8, "rarity": 2, "val": 1.0,
		"desc": "Gains [x]X0.25[/] Mult per Boss\nrace won (Currently [x]X{val}[/])"},
	{"id": "gas_station", "name": "Gas Station", "name_cards": "Allowance", "kind": "econ", "cost": 6, "desc": "Earn [$]$4[/] at the end\nof each race"},
	{"id": "street_cred", "name": "Street Cred", "name_cards": "Saver", "kind": "econ", "cost": 5, "desc": "Earn [$]$1[/] per unused discard\nat the end of each race"},
	{"id": "pit_crew", "name": "Pit Crew", "name_cards": "Extra Hand", "kind": "util", "cost": 6, "rarity": 1, "desc": "[c]+1[/] hand each race"},
	{"id": "tow_truck", "name": "Tow Truck", "name_cards": "Second Chance", "kind": "util", "cost": 5, "desc": "[m]+1[/] discard each race"},
	{"id": "big_trunk", "name": "Big Trunk", "name_cards": "Big Pockets", "kind": "util", "cost": 6, "rarity": 1, "desc": "[g]+1[/] hand size"},
]

const RESPRAY_NAME := "Respray: %s"
const RESPRAY_NAME_CARDS := "Suit Swap: %s"
const RESPRAY_DESC := "Repaint up to 3 selected\ncars as [g]%s[/]"
const RESPRAY_DESC_CARDS := "Change up to 3 selected\ncards to [g]%s[/]"

# Workshop cards (like tarots). need = [min, max] selected cards.
const WORKSHOP := [
	{"id": "enh", "enh": "nitro", "name": "Nitro Kit", "name_cards": "Bonus Charm", "need": [1, 2],
		"desc": "Install [g]Nitro[/] on up to\n2 selected cars\n([c]+30[/] Chips when scored)",
		"desc_cards": "Turn up to 2 selected cards\ninto [g]Bonus[/] cards\n([c]+30[/] Chips when scored)"},
	{"id": "enh", "enh": "turbo", "name": "Turbo Kit", "name_cards": "Power Charm", "need": [1, 2],
		"desc": "Install [g]Turbo[/] on up to\n2 selected cars\n([m]+4[/] Mult when scored)",
		"desc_cards": "Turn up to 2 selected cards\ninto [g]Power[/] cards\n([m]+4[/] Mult when scored)"},
	{"id": "enh", "enh": "carbon", "name": "Carbon Kit", "name_cards": "Glass Charm", "need": [1, 1],
		"desc": "Install a [g]Carbon[/] body on\n1 selected car\n([x]X2[/] Mult, 1 in 4 breaks)",
		"desc_cards": "Turn 1 selected card\ninto a [g]Glass[/] card\n([x]X2[/] Mult, 1 in 4 breaks)"},
	{"id": "enh", "enh": "gold", "name": "Gold Rims", "name_cards": "Gold Charm", "need": [1, 2],
		"desc": "Install [g]Gold Rims[/] on up to\n2 selected cars\n([$]+$2[/] when scored)",
		"desc_cards": "Turn up to 2 selected cards\ninto [g]Gold[/] cards\n([$]+$2[/] when scored)"},
	{"id": "respray", "suit": 0, "need": [1, 3], "name": RESPRAY_NAME, "name_cards": RESPRAY_NAME_CARDS, "desc": RESPRAY_DESC, "desc_cards": RESPRAY_DESC_CARDS},
	{"id": "respray", "suit": 1, "need": [1, 3], "name": RESPRAY_NAME, "name_cards": RESPRAY_NAME_CARDS, "desc": RESPRAY_DESC, "desc_cards": RESPRAY_DESC_CARDS},
	{"id": "respray", "suit": 2, "need": [1, 3], "name": RESPRAY_NAME, "name_cards": RESPRAY_NAME_CARDS, "desc": RESPRAY_DESC, "desc_cards": RESPRAY_DESC_CARDS},
	{"id": "respray", "suit": 3, "need": [1, 3], "name": RESPRAY_NAME, "name_cards": RESPRAY_NAME_CARDS, "desc": RESPRAY_DESC, "desc_cards": RESPRAY_DESC_CARDS},
	{"id": "scrap", "name": "Scrapyard", "name_cards": "Shredder", "need": [1, 2],
		"desc": "Scrap up to 2 selected cars\n(removes them from your garage)", "desc_cards": "Destroy up to 2 selected cards\n(removes them from your deck)"},
	{"id": "clone", "name": "Clone Shop", "name_cards": "Mirror", "need": [1, 1],
		"desc": "Create a copy of\n1 selected car", "desc_cards": "Create a copy of\n1 selected card"},
	{"id": "swap", "name": "Engine Swap", "name_cards": "Promotion", "need": [1, 2],
		"desc": "Increase the rank of up to\n2 selected cars by 1", "desc_cards": "Increase the rank of up to\n2 selected cards by 1"},
	{"id": "cash", "name": "Cash Grab", "desc": "Double your money\n(max [$]$20[/])"},
]

# Booster packs: open one in the pit stop, then take 1 of the choices.
const PACKS := [
	{"id": "pack", "type": "cars", "name": "Garage Pack", "name_cards": "Card Pack", "cost": 4, "weight": 30, "color": Color("d64545"),
		"desc": "Choose [g]1[/] of [g]3[/] cars\nto add to your garage", "desc_cards": "Choose [g]1[/] of [g]3[/] cards\nto add to your deck"},
	{"id": "pack", "type": "tunes", "name": "Dyno Pack", "name_cards": "Upgrade Pack", "cost": 4, "weight": 30, "color": Color("2f7fd6"),
		"desc": "Choose [g]1[/] of [g]3[/] Dyno Tunes\nand level up that hand", "desc_cards": "Choose [g]1[/] of [g]3[/] Upgrades\nand level up that hand"},
	{"id": "pack", "type": "workshop", "name": "Workshop Pack", "name_cards": "Trick Pack", "cost": 4, "weight": 25, "color": Color("d9822b"),
		"desc": "Choose [g]1[/] of [g]3[/] Workshop cards\nfor your Garage slots", "desc_cards": "Choose [g]1[/] of [g]3[/] Trick cards\nfor your item slots"},
	{"id": "pack", "type": "mods", "name": "Mod Pack", "name_cards": "Joker Pack", "cost": 6, "weight": 15, "color": Color("8e44d6"),
		"desc": "Choose [g]1[/] of [g]2[/] Mods", "desc_cards": "Choose [g]1[/] of [g]2[/] Jokers"},
]

const BAN_DESC := "All %s cars are debuffed"
const BAN_DESC_CARDS := "All %s cards are debuffed"
const BAN_DESC_SUITS := "All %s are debuffed"

const BOSSES := [
	{"id": "ban", "suit": 0, "name": "Emission Zone", "name_suits": "Heartbreak Hill", "color": Color("9b2226"),
		"desc": BAN_DESC, "desc_cards": BAN_DESC_CARDS, "desc_suits": BAN_DESC_SUITS},
	{"id": "ban", "suit": 1, "name": "Import Tax", "name_suits": "Diamond Lane", "color": Color("b5541a"),
		"desc": BAN_DESC, "desc_cards": BAN_DESC_CARDS, "desc_suits": BAN_DESC_SUITS},
	{"id": "ban", "suit": 2, "name": "Speed Camera", "name_suits": "Spade Bend", "color": Color("2a4d8f"),
		"desc": BAN_DESC, "desc_cards": BAN_DESC_CARDS, "desc_suits": BAN_DESC_SUITS},
	{"id": "ban", "suit": 3, "name": "Paved Only", "name_suits": "Club Corner", "color": Color("2f6b36"),
		"desc": BAN_DESC, "desc_cards": BAN_DESC_CARDS, "desc_suits": BAN_DESC_SUITS},
	{"id": "roadblock", "name": "Roadblock", "color": Color("7a3b8f"), "desc": "All face cars are debuffed", "desc_cards": "All face cards are debuffed"},
	{"id": "toll", "name": "Toll Road", "color": Color("8f7a1d"), "desc": "Lose $1 per car played", "desc_cards": "Lose $1 per card played"},
	{"id": "rain", "name": "Heavy Rain", "desc": "No discards", "color": Color("35607a")},
	{"id": "flat_tire", "name": "Flat Tire", "desc": "-1 hand size", "color": Color("5a5a5a")},
	{"id": "time_trial", "name": "Time Trial", "desc": "Only 1 hand, but the\ntarget is much lower", "mult": 0.5, "min_ante": 3, "color": Color("1d7a6e")},
	{"id": "full_load", "name": "Full Load", "color": Color("8f3b1d"), "min_ante": 2, "desc": "Must play exactly 5 cars", "desc_cards": "Must play exactly 5 cards"},
	{"id": "tunnel", "name": "Tunnel", "desc": "Base Chips and Mult\nare halved", "color": Color("3b3b5c"), "min_ante": 2},
	{"id": "rival", "name": "The Rival", "desc": "Each hand type can only\nbe played once this race", "color": Color("a3193f"), "min_ante": 2},
]
const FINAL_BOSS := {"id": "grand_prix", "name": "Grand Prix", "desc": "The championship final.\nThe target is huge!", "mult": 2.5, "color": Color("c9a227")}

const ANTE_BASE := [300, 800, 1800, 4500, 9000, 16000, 28000, 42000]


static func ante_base(ante: int) -> int:
	if ante <= ANTE_BASE.size():
		return ANTE_BASE[ante - 1]
	return int(ANTE_BASE[-1] * pow(1.8, ante - ANTE_BASE.size()))


static func rank_str(rank: int) -> String:
	return RANK_SHORT.get(rank, str(rank))


## Untranslated name of a rank in the current card art ("King" or "Hyper", "7").
static func rank_name(rank: int) -> String:
	return (RANK_NAMES if classic_art else CAR_RANK_NAMES).get(rank, str(rank))


## Untranslated suit name in the current suit theme.
static func suit_name(suit: int) -> String:
	return (CLASSIC_SUIT_NAMES if classic_suits else SUIT_NAMES)[suit]


static func suit_color(suit: int) -> Color:
	return (CLASSIC_SUIT_COLORS if classic_suits else SUIT_COLORS)[suit]


## Untranslated hand name: car name with car art, poker name with classic art.
static func hand_name(t: int) -> String:
	return HANDS[t].poker if classic_art else HANDS[t].name


## The most specific variant of a text field for the current themes (untranslated).
static func pick(d: Dictionary, field: String) -> String:
	var a := "_cards" if classic_art else ""
	var s := "_suits" if classic_suits else ""
	for k in [field + a + s, field + s, field + a, field]:
		if d.has(k):
			return d[k]
	return ""


## Translated text of a field, with the suit name filled in.
static func text(d: Dictionary, field: String) -> String:
	var s := TranslationServer.translate(pick(d, field))
	if d.has("suit") and s.contains("%s"):
		s = s % TranslationServer.translate(suit_name(d.suit))
	return s


## Translated pair of words: the car version or the classic-card version.
static func tv(car_text: String, card_text: String) -> String:
	return TranslationServer.translate(card_text if classic_art else car_text)


static func mod_def(id: String) -> Dictionary:
	for m in MODS:
		if m.id == id:
			return m
	return {}


static func consumables() -> Array:
	var out := []
	for i in HANDS.size():
		out.append({"id": "tune", "hand": i, "cost": 3})
	for w in WORKSHOP:
		var c = w.duplicate(true)
		c.cost = 4 if w.id == "cash" else 3
		out.append(c)
	return out


static func box(bg: Color, radius := 10, border := Color(0, 0, 0, 0), bw := 0, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(margin)
	return s
