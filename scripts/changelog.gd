extends RefCounted
## Release history, shown when the player clicks the version number.
## Add an entry for every release: deploy_web.sh refuses to release a version without one.

const ENTRIES := [
	{"version": "1.7.0", "date": "2026-10-11", "items": [
		"Interactive tutorial: a guided first race with hints; start it at any time from the main menu",
		"First launch: choose the language, sound, card look and card back, or skip it",
		"How to Play is now 10 short steps with animated pictures",
		"Classic card art and classic suits are the default",
	]},
	{"version": "1.6.0", "date": "2026-10-11", "items": [
		"New theme: Doctor Who (a fan tribute) for the card art and the suits",
		"TARDIS, Daleks, Cybermen and Gallifrey suits; the Doctor, a Time Lady and a Companion on the face cards",
		"Allies, Adventures, Gadgets and Favours with their own names and pictures; two new card backs",
	]},
	{"version": "1.5.0", "date": "2026-10-11", "items": [
		"Install the game as an app on Android, iPhone or a computer; it works offline after the first start",
		"Touch-friendly: on phones the game opens in full screen and asks to rotate to landscape",
		"One new icon everywhere: the app, the loading screen and the website",
	]},
	{"version": "1.4.0", "date": "2026-10-11", "items": [
		"Drag mods (jokers) to change their order: they work from left to right",
		"Cards are played and scored in the order you pick them",
	]},
	{"version": "1.3.4", "date": "2026-10-11", "items": [
		"Card tooltips no longer jump from above the card to below it",
		"Optional FPS counter in the top-left corner (Settings)",
	]},
	{"version": "1.3.3", "date": "2026-10-11", "items": [
		"Music and sound effects have separate on/off switches that work independently",
	]},
	{"version": "1.3.2", "date": "2026-10-11", "items": [
		"The website speaks all 6 languages and picks your system language",
		"The website has the same changelog as the game",
		"The game starts in the language chosen on the website",
	]},
	{"version": "1.3.1", "date": "2026-10-11", "items": [
		"New website with screenshots; you can play right on the page",
	]},
	{"version": "1.3.0", "date": "2026-10-11", "items": [
		"With car art, every picture is about cars: mods, items and mini cards",
		"With classic art, every picture is about playing cards",
		"Sponsors (car theme) or Vouchers (classic theme): permanent bonuses for the whole run, one offer per ante",
	]},
	{"version": "1.2.1", "date": "2026-10-10", "items": [
		"Classic suits and the Classic Red card back are now the default",
	]},
	{"version": "1.2.0", "date": "2026-10-10", "items": [
		"Unique pictures for every mod, garage item and boss race",
		"Classic King, Queen and Jack are easy to tell apart",
		"Mod editions from the original game: Foil, Holographic, Polychrome and Negative",
		"Changelog: click the version number",
		"Statistics of your runs, with a reset button",
	]},
	{"version": "1.1.1", "date": "2026-10-10", "items": [
		"Version number in the top-right corner",
	]},
	{"version": "1.1.0", "date": "2026-10-10", "items": [
		"Collection: all cards, mods, items, packs, bosses, hands and card backs",
		"Classic card art shows the full rank on the 10",
		"Easier to read colors on dark panels",
	]},
	{"version": "1.0.1", "date": "2026-10-10", "items": [
		"The Neon Grid card back stays inside the card",
	]},
	{"version": "1.0.0", "date": "2026-10-10", "items": [
		"First release: a Balatro-like deckbuilder where the cards are cars",
		"8 antes of races with boss rules, the Grand Prix and endless mode",
		"30 mods, Dyno Tunes, Workshop cards and booster packs",
		"Card art and suit themes: cars or classic playing cards, 6 card backs",
		"Procedural music, autosave, settings and 6 languages",
		"Play in the browser on GitHub Pages",
	]},
]
