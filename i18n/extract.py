"""Collect user-facing string literals from the GDScript sources into i18n/source.json.
Run: python3 i18n/extract.py   (then translate, then python3 i18n/build_csv.py)"""
import json, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')
SKIP_RE = re.compile(r'^[a-z0-9_./:%]*$|^#?[0-9a-fA-F]{6}$|^res://|^\[/?[a-z$]\]$|^\[/?color(=#[0-9a-f]{6})?\]$')
SKIP = {"CARLATRO", "Carlatro", "JDM", "English", "Русский", "Español", "Deutsch", "Français", "Português",
        "$%d", "+$%d", "-$%d %s", "+%d", "+%d %s", "X%s %s", "%s  %s%d", "%s  (%s)", "%s %s", "%s %s%d!",
        "[c]+%d[/] %s", "\\n[g]%s:[/] %s", "\\n[m]%s[/]", "\\n[$]%s $%d[/]", "\\n[g]", "%.3e", "%.1f", "%.2f",
        "%d/8", "%d/%d", "- [color=%s]%s[/color]: %s\\n", "J", "Q", "K", "A", "pt_BR", "{val}", "\\n", " %d", " %d/%d", " $%d", " (%d)", " %sx", "1-%d", "$%d", "X", "Mult"}
KEEP_LOWER = {"lvl."}

def unescape(s):
    return s.encode().decode("unicode_escape").encode("latin-1").decode("utf-8")

out = []
for f in ["scripts/data.gd", "scripts/game.gd", "scripts/card_view.gd", "scripts/changelog.gd"]:
    src = (ROOT / f).read_text()
    # join GDScript line continuations of concatenated literals: "a" \ + "b"
    for m in LIT.finditer(src):
        raw = m.group(1)
        letters = re.sub(r"\[/?color[^\]]*\]|\[/?[a-z$]\]|%[sd]|\\n", "", raw)
        if "window." in raw:  # JavaScript passed to the browser, not UI text
            continue
        if raw in KEEP_LOWER or (not SKIP_RE.match(raw) and raw not in SKIP and re.search(r"[A-Za-z]{2}", letters)):
            s = unescape(raw)
            if s not in out:
                out.append(s)
out.append("Mult")
(ROOT / "i18n/source.json").write_text(json.dumps(out, ensure_ascii=False, indent=1))
print(len(out), "strings")
