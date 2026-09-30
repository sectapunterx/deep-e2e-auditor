# Phase 1 - Harness: launch isolated, capture, drive, read structure

Before any agent starts, prove four things on the real target and write the recipe to `HARNESS.md`:

1. **Launch isolated** - the command that starts the app against a fresh data location (and a
   seeded one: demo data, a fixture, N thousand items for scale).
2. **Capture** - a PNG of the window *with* its popups/menus, taken without grabbing whatever
   covers it.
3. **Drive** - click, right-click, double-click, drag, wheel, type, key chords; open a context menu
   and capture it.
4. **Read structure** - the element tree with boxes (UIA / AX / AT-SPI / DOM / the framework's own
   object tree), so agents can find "every card", "every button without a name", "the menu's rows".

Use two drivers when that is better: the framework's own test driver for behaviour (fast,
deterministic, headless, real input events inside the app) and the OS driver for pixels (the real
renderer, real fonts, real DPI). Offscreen/headless renderers often use fallback fonts and skip
icons - do not judge visuals from them.

## Desktop - Windows (`scripts/win/`)
Run from PowerShell (not git-bash). Call scripts with `&` inside PowerShell; `pwsh -File` treats an
argument that starts with `--` as the end of its parameters.
```powershell
$S = "<skill>\scripts\win"
$j = & "$S\capture.ps1" -Exe "C:\path\app.exe" -AppArgs "--data-dir C:\run\dd1" -Out C:\run\shots\board.png -Wait 5 -Keep -Size 1440x900 -Json -LogDir C:\run\dd1
$procId = ($j | ConvertFrom-Json).pid
& "$S\uia_tree.ps1" -ProcessId $procId -Out C:\run\tree.json -Visible
& "$S\input.ps1" -ProcessId $procId rclick 360 300      # posted: user's cursor untouched
& "$S\capture.ps1" -ProcessId $procId -Out C:\run\shots\card_menu.png
& "$S\input.ps1" -ProcessId $procId key Esc
Stop-Process -Id $procId
```
- Coordinates are relative to the main window's outer top-left in physical pixels - the same frame
  as a `-MainOnly` capture, so a point read off a screenshot can be clicked directly. With `-Size`
  and a fixed DPI, coordinates are stable across runs.
- `post` mode delivers mouse messages without moving the cursor; Qt, WPF, WinForms and Win32 accept
  them. Two limits: key *chords* (Ctrl+K) need `send` mode because posted modifiers do not change
  key state; and a popup that opens "at the pointer" lands at the *real* cursor position - judge
  popup placement only in `send` mode (ask the user first) or place it via the app's own API.
- Menus/popups of native toolkits are separate top-level windows; `capture.ps1` composites all of
  the process's visible windows. Qt Quick / web-based UIs draw popups inside the main window.
- Qt Quick exposes only items with `Accessible.*` set (plus Controls) to UIA - a card without an
  accessible role is invisible in the tree; find it on the screenshot instead (and note the a11y gap).
- Electron/Chromium: add `--force-renderer-accessibility` for a full UIA tree, or drive it with
  `web/session.mjs` (`"target": {"electron": "main.js"}`) instead.
- GPU/driver quirks: if PrintWindow returns black or a frozen splash, try the app's software/basic
  render loop (Qt: `QSG_RENDER_LOOP=basic`, `QT_QUICK_BACKEND=software`; Chromium:
  `--disable-gpu`), pass it with `-Env`.

## Desktop - macOS (`scripts/mac/driver.sh`)
Needs Screen Recording + Accessibility permission for the terminal. `capture` uses
`screencapture -l <windowid>` (a window, not the screen); `ax` walks System Events UI elements;
input is real CGEvent input (moves the cursor - ask first). Launch isolated with the app's flags or
`HOME=/tmp/run/home open -n -a App --args ...`. Untested by the skill author on real hardware:
check each command once in Harness and note fixes in HARNESS.md.

## Desktop - Linux (`scripts/linux/driver.sh`)
X11 via xdotool + ImageMagick + AT-SPI. Best practice: run the app on a virtual display
(`Xvfb :99 -screen 0 1920x1080x24 & DISPLAY=:99 ...`) so input never touches the user's session,
and screenshots are deterministic. Wayland blocks cross-app capture/input: force X11 for the app
(`QT_QPA_PLATFORM=xcb`, `GDK_BACKEND=x11`, `--ozone-platform=x11`).

## Web (`scripts/web/`)
One-time: `cd scripts/web && npm run setup` (Playwright + Chromium + axe).
- `crawl.mjs URL --out DIR` - the surface census of a site: every same-origin page at 375/768/1280/1920
  in light and dark, full-page screenshots, axe violations, console errors, failed requests,
  horizontal overflow, element inventory. Never follows logout/delete links or submits forms.
- `session.mjs steps.json --out DIR` - a scripted session in one context: goto/click/right-click/
  hover/fill/type/press/drag/scroll/viewport/emulate(colorScheme)/offline, `shot`, `a11y`, `axe`,
  `inventory`, `expect`. Agents write step files like tests; a failing step leaves a FAILED screenshot.
- Auth: log in once as the test user in a headed session (`"headless": false`, the user types the
  password), save `storageState`, reuse it in every session/crawl.
- The in-app browser tools of Claude Code (if present) are good for exploratory looking; use the
  scripts for anything that must be repeatable or run at several widths.
- Electron: the same `session.mjs` with `"target": {"electron": "path/to/main.js"}`.

## Framework-native drivers (behaviour)
- **Qt Quick / QML**: a QuickTest runner loading the real `Main.qml` (`Qt.createComponent(...)
  .createObject(null)`), real `mouseClick/keyClick/mouseDrag`, offscreen platform; a copy of the
  runner exe under a unique name gives an isolated QStandardPaths test profile per agent. Walk
  `window.contentData` for popups. Log with `console.log("PROBE ...")` to a `-o file,txt`.
- **Qt Widgets**: QTest + the real main window, or pywinauto/UIA on the running app.
- **WPF / WinForms**: FlaUI (UIA3) or pywinauto; Appium WinAppDriver where installed.
- **Electron / web**: Playwright (above). **Tauri**: tauri-driver (WebDriver) or Playwright on the
  dev server for the webview part. **GTK**: dogtail / AT-SPI.
- **Backend / storage**: read the files the app writes (JSON/SQLite/logs) after each action; hit
  its local API; a fake server for integrations (record/replay) when no sandbox exists.

## HARNESS.md (write it; agents follow it literally)
- Build commands, binary paths, how to make a per-agent copy/profile.
- Launch command (fresh / seeded / scale), env vars that matter, how to stop.
- Capture, drive and tree commands with a worked example that was run.
- Where the app writes data and logs; how to read them back.
- Known quirks found while proving the harness (as above).
- Rules: the safety file, the run dir layout, the finding format.
