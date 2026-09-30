# Phase 3 - The eyes audit

What a functional audit cannot see: the product *looks* wrong or *feels* wrong. A context menu with
different padding than every other menu. A ticket card carrying eleven chips so nothing stands
out. A dialog whose primary button is on the left while every other dialog has it on the right. A
label that clips only in German. An empty state nobody designed. You find these by capturing every
surface in every state, putting same-kind surfaces next to each other, judging them against
explicit heuristics, measuring what the eye estimates badly, and using the product like a person.

Screenshots come from the real renderer at real DPI (OS driver or a real browser), not from an
offscreen test renderer.

## 1. Surface census -> `surfaces.json`
Every distinct thing a user can see, grouped by kind. Build it from both directions:
- **Code**: search for the toolkit's surface types and list each instance with the file and how it
  opens. Qt/QML: `Menu|AppMenu|Popup|Dialog|Drawer|ToolTip|Window|ApplicationWindow` and every
  `onPressed/onClicked` with `Qt.RightButton`; Widgets: `QMenu|QDialog|QToolTip|QMessageBox`;
  WPF: `ContextMenu|Popup|Window|ToolTip`; Electron: `Menu.buildFromTemplate|BrowserWindow|dialog.`;
  React/Vue/Svelte: `Dialog|Modal|Popover|Dropdown|ContextMenu|Tooltip|Toast|Sheet|Drawer` (and the
  design-system package's names); HTML: `<dialog>`, `role=menu|dialog|tooltip|alert`.
- **Runtime**: walk every view; dump the element tree; **right-click one of every element kind**
  (card, row, header, chip, empty area, text field, list item, tab, tree node, link); long-press /
  hover everything that might show a tooltip; open every menu, dropdown, date/colour picker; trigger
  every toast and confirm. Anything that appeared and is not in the code list is still a surface.
- Kinds: `window, view/page, dialog/modal, sheet/drawer, context-menu, dropdown/menu, popover,
  picker, tooltip, toast/banner, card (per type), list-row (per type), form, table, empty-state,
  error-state, loading-state, onboarding`.
Each entry: `{id, kind, name, open: "how to get there", code: "file:line", states: [...]}`.

## 2. Capture matrix -> `shots/<group>/`
For each surface, capture the states that exist for it:
`default · hover · focus (keyboard) · pressed · selected · disabled · empty · loading · error ·
long content (longest real text, no-space strings, many items) · max density (all optional fields
filled) · min window size · wide window · 150% scale · each theme (light/dark/high-contrast) ·
the longest locale`. Prune by kind: a tooltip needs content + theme; a card needs content
variants, selection, hover, narrow width; a dialog needs every button state and the longest locale.
Name files `<surface-id>__<state>__<theme>__<width>.png` so sheets can be built by glob.
Seed data that produces the variants (a task with every field set, one with none, one with a
300-char title) - don't wait for them to occur.

## 3. Consistency sheets (the check that catches "this menu doesn't look like the others")
For every kind with 2+ members, build a contact sheet of all members in the same state/theme:
```
python scripts/visual/contact_sheet.py sheets/context-menus.png --glob "shots/menus/*__default__dark*.png" --cols 4 --title "Context menus (dark)"
```
Then an eyes agent reviews the sheet **against the group's majority** and lists every member that
differs in: container (background, border, radius, shadow, elevation), padding and item height,
typography (size, weight, case, letter-spacing), icon use and size, separators, colour of
destructive items, header/title treatment, keyboard hints, widths, alignment of labels and
shortcuts, disabled look, the position of primary/secondary/destructive buttons, close affordance,
title phrasing. Back each difference with `pixels.py compare` (palette) or a crop measurement
where it is a number. One finding per divergent member (or one per pattern if many share it), with
the sheet and the member's own screenshot as evidence, boxed.

## 4. Density and hierarchy of repeated units (the check that catches overloaded cards)
Cards, rows, tiles and list items are seen by the hundred; their load multiplies. For each type,
capture it at max density and at typical density, then judge:
- **Count** distinct information elements (text runs, chips, badges, icons, avatars, progress,
  dates). Flag > 7 on one unit, or > 4 chips/badges in one row.
- **Visual weights**: number of font sizes (> 3), font weights, accent colours (> 3 hues beyond the
  neutral palette), borders-within-borders.
- **Five-second test**: give a fresh reviewer the screenshot only, 5 seconds' worth of attention:
  "what is this card for, what is its most important fact, what can you do with it?" If the answer
  is wrong or hesitant, hierarchy is broken - finding.
- **Scan test**: a column of 10 units - can the reviewer find "the overdue one", "the one assigned
  to X" at a glance? If not, the distinguishing signal is too weak or drowned out.
- **Measure**: `pixels.py edges` density vs. sibling units and vs. the calmest unit type in the
  product; a unit at 1.5x+ the density of its siblings is a candidate.
- Recommend what to demote (hover/expand/detail view) in `fix_hint`, not just "too busy".

## 5. Heuristic walkthrough per screen
Walk every view/page and every dialog against this list; each violation is a finding with a box:
- **Hierarchy**: one clear primary action per screen; headings form a scale; the eye lands on the
  most important thing first; nothing important is below the fold on the default size.
- **Alignment and grid**: left edges line up (use the element tree's x values - clusters off by a
  few px are defects); consistent gutters; baselines of adjacent text align.
- **Spacing rhythm**: gaps come from a small set (4/8/12/16/24...); related things closer than
  unrelated ones (proximity); equal elements equally spaced.
- **Typography**: limited sizes; line length 45-90 chars for reading text; no clipped/ellipsised
  text that matters (check the tree for elided labels); truncation keeps the distinguishing part.
- **Colour and contrast**: text >= 4.5:1, large text/UI >= 3:1 (`pixels.py contrast`); colour
  never the only signal; the same colour means the same thing everywhere; dark and light both done.
- **Affordance and state**: clickable things look clickable; hover/focus/pressed/selected/disabled
  are visible and distinct; focus ring visible on every control and theme.
- **Feedback**: every action shows it happened (and where); errors say what to do; long operations
  show progress; destructive actions confirm or offer undo.
- **Consistency**: same thing, same name, same place, same look, across the product (and with the
  platform's conventions: Esc closes, Enter confirms, right-click menus, OS dialog button order).
- **Empty/error/loading states**: designed, helpful, with the next action; not a blank panel.
- **Microcopy and i18n**: consistent terms and tone; no untranslated strings, no raw keys, no
  mixed languages; the longest locale fits; plurals and dates localised.
- **Layout robustness**: min window size, very wide window, 150% scale, long names: nothing
  overlaps, clips, pushes controls off-screen or scrolls horizontally.
- **Motion**: nothing jumps (layout shift after load, list jumping to top after save).

## 6. Persona sessions ("use it like a person")
Two to four personas with real goals, each run by an agent that only uses the UI (no code, no
APIs), screenshotting every step and narrating in first person. Example for a task app:
"engineer starting the day: triage 20 new tickets, plan the day in the calendar, write meeting
notes, close three tickets from the keyboard". Each session: 20-40 steps, then a debrief:
- where they hesitated, what they looked for and did not find, what surprised them;
- steps/clicks to finish each goal vs. the obvious minimum; dead ends; places they needed the mouse
  in a keyboard-first product; anything that felt slow;
- first impressions of each new screen (the five-second test, again).
Every friction point with a screenshot becomes a `kind: "ux"` finding; severity by how much it costs
the persona (blocked goal = A, repeated friction on the main path = B, one-off = C).

## 7. Fresh eyes
The agent that captured a surface is primed by the code it read. Visual judgement is better from a
reviewer that gets only screenshots and sheets plus the heuristics - no code, no intent. Split:
capture agents (produce shots + surfaces.json) and review agents (read images, write findings).
Two reviewers disagreeing on a judgement call = mark `plausible`, let the user decide.

## 8. Measurements that back judgements
- `pixels.py contrast IMG x,y x2,y2` / `contrast-hex` - exact WCAG ratios.
- `pixels.py palette` / `compare` - "this dialog's background is #262626, all others #1f1f1f".
- `pixels.py edges` - density of one card vs. its siblings.
- `pixels.py diff` - theme A vs. B, before vs. after, run N vs. N-1 (regressions).
- Element tree / DOM inventory - x positions (alignment), sizes (touch targets >= 24-32 px),
  missing names (a11y), font sizes and colours actually used (web inventory has computed styles).
A number in `evidence.measure` turns "looks off" into a fact.

## Output of the eyes half
`surfaces.json`, `shots/`, `sheets/*.png`, persona transcripts (`personas/<name>.md` with their
screenshots) and `findings/eyes-*.jsonl` - each finding with at least one screenshot and a box.
