#!/usr/bin/env bash
# Linux (X11) driver: windows, capture, input, accessibility tree for one process.
# Needs: xdotool, ImageMagick (import) or xwd+convert, python3-gi with Atspi (at-spi2) for the tree.
# Wayland: capture/input of other apps is blocked by design - run the app under Xwayland
# (QT_QPA_PLATFORM=xcb, GDK_BACKEND=x11, --ozone-platform=x11) or in a nested X server:
#   Xvfb :99 -screen 0 1920x1080x24 &  DISPLAY=:99 app ...   (headless, and the user's desktop is untouched)
#
#   driver.sh windows PID                     -> JSON list {id,title,x,y,w,h}
#   driver.sh capture PID OUT.png [--all]     main window, or every window of the process (OUT_N.png)
#   driver.sh click|rclick|dclick|move PID X Y  coordinates relative to the main window
#   driver.sh key PID ctrl+k | Escape | Return | Tab | Down ...
#   driver.sh type PID "text"
#   driver.sh ax PID OUT.json                 AT-SPI tree: role, name, extents (rel. to main window)
# On the user's own display input moves their pointer; prefer an Xvfb display for long sessions.
set -euo pipefail
cmd=${1:?command}; pid=${2:?pid}; shift 2

windows_json() {
  python3 - "$pid" <<'PY'
import json, subprocess, sys
pid = sys.argv[1]
ids = subprocess.run(["xdotool", "search", "--onlyvisible", "--pid", pid], capture_output=True, text=True).stdout.split()
rows = []
for i in ids:
    g = subprocess.run(["xdotool", "getwindowgeometry", "--shell", i], capture_output=True, text=True).stdout
    kv = dict(l.split("=", 1) for l in g.splitlines() if "=" in l)
    name = subprocess.run(["xdotool", "getwindowname", i], capture_output=True, text=True).stdout.strip()
    w, h = int(kv.get("WIDTH", 0)), int(kv.get("HEIGHT", 0))
    if w > 1 and h > 1:
        rows.append({"id": int(i), "title": name, "x": int(kv.get("X", 0)), "y": int(kv.get("Y", 0)), "w": w, "h": h})
rows.sort(key=lambda r: -r["w"] * r["h"])
print(json.dumps(rows))
PY
}

main() { windows_json | python3 -c 'import json,sys; w=json.load(sys.stdin); print(w[0]["id"], w[0]["x"], w[0]["y"]) if w else sys.exit("no window")'; }

grab() { # window id -> png
  if command -v import >/dev/null; then import -window "$1" "$2"; else xwd -silent -id "$1" | convert xwd:- "$2"; fi
}

case "$cmd" in
  windows) windows_json ;;
  capture)
    out=${1:?out.png}; all=${2:-}
    ids=$(windows_json | python3 -c 'import json,sys; print(" ".join(str(w["id"]) for w in json.load(sys.stdin)))')
    [ -z "$ids" ] && { echo "NO WINDOW for pid $pid"; exit 2; }
    if [ "$all" = "--all" ]; then n=0; for id in $ids; do grab "$id" "${out%.png}_$n.png"; n=$((n+1)); done; echo "OK $n windows"
    else set -- $ids; grab "$1" "$out"; echo "OK -> $out"; fi ;;
  click|rclick|dclick|move)
    read -r wid ox oy < <(main)
    xdotool mousemove $(( ox + ${1:?x} )) $(( oy + ${2:?y} ))
    case "$cmd" in click) xdotool click 1 ;; rclick) xdotool click 3 ;; dclick) xdotool click --repeat 2 1 ;; esac
    echo "OK $cmd $1 $2" ;;
  key) read -r wid _ _ < <(main); xdotool windowactivate --sync "$wid" key --clearmodifiers "${1:?key}"; echo "OK key $1" ;;
  type) read -r wid _ _ < <(main); xdotool windowactivate --sync "$wid" type --delay 20 "${1:?text}"; echo "OK type" ;;
  ax)
    out=${1:?out.json}; read -r wid ox oy < <(main)
    python3 - "$pid" "$ox" "$oy" "$out" <<'PY'
import json, sys
import gi
gi.require_version("Atspi", "2.0")
from gi.repository import Atspi
pid, ox, oy, out = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
rows = []
def walk(acc, depth, path):
    if depth > 30 or acc is None:
        return
    try:
        e = acc.get_extents(Atspi.CoordType.SCREEN)
        rows.append({"depth": depth, "path": path, "role": acc.get_role_name(), "name": (acc.get_name() or "")[:80],
                     "x": e.x - ox, "y": e.y - oy, "w": e.width, "h": e.height})
    except Exception:
        pass
    for i in range(acc.get_child_count()):
        walk(acc.get_child_at_index(i), depth + 1, f"{path}/{i}")
desk = Atspi.get_desktop(0)
for i in range(desk.get_child_count()):
    app = desk.get_child_at_index(i)
    if app and app.get_process_id() == pid:
        walk(app, 0, f"a{i}")
json.dump(rows, open(out, "w"))
print(f"OK {len(rows)} elements -> {out}")
PY
    ;;
  *) echo "unknown command $cmd"; exit 1 ;;
esac
