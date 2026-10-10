"""Merge i18n/<locale>.json translations into i18n/strings.csv (Godot imports it as .translation files)."""
import csv, json, pathlib

D = pathlib.Path(__file__).resolve().parent
LOCALES = ["ru", "es", "de", "fr", "pt_BR"]
keys = json.loads((D / "source.json").read_text())
tr = {l: json.loads((D / f"{l}.json").read_text()) for l in LOCALES}
with open(D / "strings.csv", "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n")
    w.writerow(["keys"] + LOCALES)
    for k in keys:
        w.writerow([k] + [tr[l].get(k, k) for l in LOCALES])
for l in LOCALES:
    missing = [k for k in keys if k not in tr[l]]
    print(l, "missing:", len(missing), missing[:5])
