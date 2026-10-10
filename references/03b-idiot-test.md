# Phase 2b - The idiot test (misuse audit)

**Rule: if the user can do it wrong, they will.** Every hint, label, key, button and gesture the
product offers will be used in the wrong place, at the wrong time, twice, half-way, and in the
wrong order. A product that only works for a user who does exactly what the designer meant is
broken. This phase is mandatory in every full run and in every acceptance run; `--quick` keeps it
for the main flows.

This is not the functional "break it" pass (that one pushes inputs and storage). This one pushes
the *user*: what a tired, hurried, literal, impatient or curious person does with what is on the
screen.

## The canonical example
A task document says at the bottom "press / to add a checklist". The user presses `/` - but the
caret is not in the text, so `/` reaches the app shortcut and opens the board's filter panel. Now
the task is hidden behind the panel and Esc closes the panel but not the way back to the task:
the user cannot return without the mouse. Three defects in one move: the hint is true only in one
focus state, the key falls through to a global shortcut, and the user is trapped.

## What the idiot does (probe every one, on every surface)
1. **Follows every on-screen instruction literally, in every focus state.** Every "press X",
   "type /", "drag here", "click to edit", placeholder and empty-state hint: do it with focus in
   the field, outside it, on the window, right after opening, after a click elsewhere, with a menu
   open. A hint that is true only sometimes is a finding.
2. **Presses global shortcuts while something else is open.** Each app-wide key (single letters,
   `/`, `?`, `Ctrl+K`, `Ctrl+F`, digits, Esc, Enter, Delete, Space, arrows, Tab) with every
   dialog, panel, popup, editor, inline field, drag and menu open. Expect: the key goes to the
   thing on top, or nowhere. Not: it acts on the hidden layer behind.
3. **Tries to get back.** From every state reached in (1)-(2): Esc (once, then again), Backspace,
   the key that opened it, `Ctrl+Z`, click on the dimmed area, the window close button. **Any
   state the keyboard cannot leave is a trap** - A in a keyboard-first product, B otherwise. Any
   state nothing can leave short of restarting is A everywhere. Count the presses back; more
   than two Esc to undo one key press is B.
4. **Does it twice / mashes.** Double-click every button and menu item; press Enter twice in every
   dialog; hold a key down (auto-repeat) on create/delete/move/toggle; click a toggle ten times
   fast. Expect one action, or a defined N; never duplicates, half-states or a crash.
5. **Stops half-way.** Opens a dialog/editor/inline field/drag/menu and then: switches view by
   shortcut, switches profile, opens another dialog on top, closes the window, minimises, resizes
   to tiny, lets the machine sleep, changes the theme or language. Comes back: is the typed text
   there, is the half-made record a ghost, is focus somewhere sensible?
6. **Does things in the wrong order.** Deletes the thing that is open in an editor; deletes the
   column/list/profile/tag a filter or view points at; undoes after switching context; edits a
   record while it syncs; renames to the name of another.
7. **Types the wrong thing in the wrong place.** Text typed while no field has focus (it must not
   fire a cascade of single-letter shortcuts unnoticed - or if it does, every one is reversible);
   paste of a 5 MB clipboard, an image, a file path, rich HTML; Enter in a single-line field that
   looks multi-line; Cyrillic layout pressing the "same" key for a Latin shortcut (`/` is `.` on
   the Russian layout).
8. **Clicks everything.** Every element that looks clickable (it must do something or not look
   clickable) and every element that doesn't (it must do nothing harmful). Right-click everywhere.
   Click on labels, counts, icons, dividers, the empty canvas, the scrim. Drag what looks
   draggable onto every invalid target, and drop outside the window.
9. **Ignores warnings.** Confirms every destructive dialog without reading; dismisses every toast
   before its Undo; closes the app right after "saved"; clicks Cancel then expects the edit to be
   gone - check it is.
10. **Gets lost.** From every deep state: is it obvious where you are and how to get home (one key
    or one click)? After a full minute of random use, can the user return to the start screen?

## How to run it
- Build the **instruction inventory** first: grep the UI strings for "press", "type", "click",
  "drag", key names and `/`; every hit is a probe for (1). Build the **global key inventory** from
  the shortcut catalog; every key x every open layer is a probe for (2)-(3) - a matrix, record it
  as a table in `probes/idiot/matrix.md` (key x layer -> what happened, how to get back).
- Drive it with the framework's test driver where possible (key matrix is cheap there), and
  confirm every trap in the real app with real keys (focus quirks differ).
- Each trap or misfire finding records: the start state, the wrong move, what happened, the
  shortest way back with keyboard only and with mouse, and the number of presses.
- Kind `ux` (or `functional` when data is lost/duplicated). Severity: data lost or duplicated by a
  misuse = S; trap with no keyboard way back or a misfire that acts on a hidden layer = A in a
  keyboard-first product (B otherwise); a hint that is false in a common focus state = B; a
  surprising but harmless reaction = C.

## When fixing (only if the user asked for fixes)
Fix the class, not the instance: a modal layer swallows global keys; every hint is reachable from
the state it is shown in (or the hint changes with focus); every layer closes on Esc and returns
focus to where it was; every repeated action is idempotent or guarded. Add a regression test per
trap (key in state -> stays in state / goes back).
