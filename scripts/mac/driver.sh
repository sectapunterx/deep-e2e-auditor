#!/usr/bin/env bash
# macOS driver: windows, capture, input, accessibility tree for one process.
# Needs: Screen Recording + Accessibility permission for the terminal running Claude Code
# (System Settings > Privacy & Security). No extra installs: JXA (osascript -l JavaScript) + screencapture.
#
#   driver.sh windows PID                      -> JSON list {id,title,x,y,w,h,layer}
#   driver.sh capture PID OUT.png [--all]      main window (or every window of the process, one PNG each: OUT_N.png)
#   driver.sh click|rclick|dclick|move PID X Y  coordinates relative to the main window's top-left (points)
#   driver.sh key PID "cmd+k" | "escape" | "return" | "tab" | "down" ...
#   driver.sh type PID "text"
#   driver.sh ax PID OUT.json                  accessibility tree: role, title/description, frame (rel. to main window)
# Input moves the real cursor (CGEvent) - tell the user before a session that uses it.
set -euo pipefail
cmd=${1:?command}; pid=${2:?pid}; shift 2

windows_json() {
  osascript -l JavaScript -e "
ObjC.import('CoreGraphics');
const list = ObjC.deepUnwrap(\$.CGWindowListCopyWindowInfo(\$.kCGWindowListOptionOnScreenOnly, 0)) || [];
const mine = list.filter(w => w.kCGWindowOwnerPID == $pid && w.kCGWindowBounds.Width > 1)
  .map(w => ({id: w.kCGWindowNumber, title: w.kCGWindowName || '', layer: w.kCGWindowLayer,
              x: w.kCGWindowBounds.X, y: w.kCGWindowBounds.Y, w: w.kCGWindowBounds.Width, h: w.kCGWindowBounds.Height}))
  .sort((a, b) => b.w * b.h - a.w * a.h);
JSON.stringify(mine);"
}

main_origin() {
  windows_json | python3 -c 'import json,sys; w=json.load(sys.stdin); print(int(w[0]["x"]), int(w[0]["y"])) if w else sys.exit("no window")'
}

case "$cmd" in
  windows) windows_json ;;
  capture)
    out=${1:?out.png}; all=${2:-}
    ids=$(windows_json | python3 -c 'import json,sys; print(" ".join(str(w["id"]) for w in json.load(sys.stdin)))')
    [ -z "$ids" ] && { echo "NO WINDOW for pid $pid"; exit 2; }
    if [ "$all" = "--all" ]; then
      n=0; for id in $ids; do screencapture -x -o -l "$id" "${out%.png}_$n.png"; n=$((n+1)); done
      echo "OK $n windows -> ${out%.png}_N.png"
    else
      set -- $ids; screencapture -x -o -l "$1" "$out"; echo "OK -> $out"
    fi ;;
  click|rclick|dclick|move)
    read -r ox oy < <(main_origin); x=$(( ox + ${1:?x} )); y=$(( oy + ${2:?y} ))
    osascript -l JavaScript -e "
ObjC.import('CoreGraphics');
const p = \$.CGPointMake($x, $y);
function ev(t, b) { const e = \$.CGEventCreateMouseEvent(null, t, p, b); \$.CGEventPost(\$.kCGHIDEventTap, e); }
const kind = '$cmd';
ev(\$.kCGEventMouseMoved, 0); delay(0.05);
if (kind === 'click' || kind === 'dclick') { const n = kind === 'dclick' ? 2 : 1;
  for (let i = 0; i < n; i++) { ev(\$.kCGEventLeftMouseDown, 0); ev(\$.kCGEventLeftMouseUp, 0); } }
if (kind === 'rclick') { ev(\$.kCGEventRightMouseDown, 1); ev(\$.kCGEventRightMouseUp, 1); }"
    echo "OK $cmd $1 $2" ;;
  key)
    chord=${1:?key}
    osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $pid) to true" >/dev/null
    python3 - "$chord" <<'PY' | osascript
import sys
codes = {"return": 36, "enter": 36, "escape": 53, "esc": 53, "tab": 48, "space": 49, "delete": 51, "backspace": 51,
         "up": 126, "down": 125, "left": 123, "right": 124, "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
         **{f"f{i}": c for i, c in zip(range(1, 13), [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111])}}
mods = {"cmd": "command down", "command": "command down", "ctrl": "control down", "control": "control down",
        "alt": "option down", "option": "option down", "shift": "shift down"}
parts = sys.argv[1].lower().split("+"); key = parts[-1]
using = ", ".join(mods[m] for m in parts[:-1])
using = f" using {{{using}}}" if using else ""
if key in codes:
    print(f'tell application "System Events" to key code {codes[key]}{using}')
else:
    print(f'tell application "System Events" to keystroke "{key}"{using}')
PY
    echo "OK key $chord" ;;
  type)
    osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $pid) to true" \
              -e "tell application \"System Events\" to keystroke \"${1//\"/\\\"}\""
    echo "OK type" ;;
  ax)
    out=${1:?out.json}
    read -r ox oy < <(main_origin)
    osascript -l JavaScript -e "
const se = Application('System Events');
const proc = se.processes.whose({unixId: $pid})[0];
const rows = [];
function walk(el, depth, path) {
  if (depth > 30) return;
  let role = '', name = '', pos = [0, 0], size = [0, 0];
  try { role = el.role(); } catch (e) {}
  try { name = el.title() || el.description() || el.name() || ''; } catch (e) {}
  try { pos = el.position(); size = el.size(); } catch (e) {}
  rows.push({depth, path, role, name: String(name).slice(0, 80), x: pos[0] - $ox, y: pos[1] - $oy, w: size[0], h: size[1]});
  let kids = []; try { kids = el.uiElements(); } catch (e) {}
  for (let i = 0; i < kids.length; i++) walk(kids[i], depth + 1, path + '/' + i);
}
proc.windows().forEach((w, i) => walk(w, 0, 'w' + i));
JSON.stringify(rows);" > "$out"
    echo "OK $(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$out") elements -> $out" ;;
  *) echo "unknown command $cmd"; exit 1 ;;
esac
