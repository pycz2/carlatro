"""Write the website's changelog.json from scripts/changelog.gd and the game translations,
so the site shows exactly the same changelog as the game.
Usage: python3 tools/site_changelog.py OUT.json"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LOCALES = ["ru", "es", "de", "fr", "pt_BR"]
tr = {l: json.loads((ROOT / f"i18n/{l}.json").read_text()) for l in LOCALES}


def all_langs(text):
    return {"en": text, **{l: tr[l].get(text, text) for l in LOCALES}}


src = (ROOT / "scripts/changelog.gd").read_text()
entries = []
for m in re.finditer(r'\{"version": "([^"]+)", "date": "([^"]+)", "items": \[(.*?)\]\}', src, re.S):
    items = re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(3))
    entries.append({"version": m.group(1), "date": m.group(2),
                    "items": {l: [all_langs(i)[l] for i in items] for l in ["en"] + LOCALES}})
out = {"title": all_langs("CHANGELOG"), "back": all_langs("Back"), "entries": entries}
pathlib.Path(sys.argv[1]).write_text(json.dumps(out, ensure_ascii=False, indent=1))
print(f"changelog.json: {len(entries)} releases")
