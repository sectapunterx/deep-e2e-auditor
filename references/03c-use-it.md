# Phase 2c - Use it (the work audit)

**Rule: some bugs exist only for someone who is working.** A feature poke - open it, see it
respond, move on - passes them every time. They show on the third edit, at the edge between two
things, after a timer fires, on the kind of element nobody clicked, or when the user switches mode
with input still pending. This phase *uses* the product the way its users do, long enough and in
enough detail to meet them. Mandatory in every full and acceptance run; `--quick` keeps it for the
one or two surfaces the product is for.

This is not the functional pass (one feature at a time, read back storage), not the idiot test
(misuse) and not the persona walk (can a newcomer reach the goal). It is the regular user on an
ordinary day, doing real work, with the auditor watching every step closely.

## The canonical example
A notes app draws markdown and edits the block under the caret. A functional agent clicked two
paragraphs, saw a field open, typed a word: "editing works". A user found three defects in a
day: a click on a table opened nothing (the table's scroll area took the press); the caret
always went to the end of the block, not where they clicked; and nothing past one block could
be selected, copied or joined - Backspace at a block's start did nothing. Fixing the last one
showed a fourth: after a join the edit field fell to the end of the note 400 ms later, when
the commit timer rebuilt the rows, and the text being typed vanished from sight. None of them is
exotic. Each needs one of the moves below.

## The moves (do every one on every surface where users make or change things)

1. **Work, don't poke.** Pick the product's real jobs (write a long note, plan a week, triage a
   backlog of 200 tickets, fill a big form, build a report) and do one of them for real, for
   20-40 minutes, on one document/board/record. Each action's result is the next one's input:
   create, edit it many times, reorganise, undo a few steps, restart, carry on. A bug that needs
   "a document someone has been working on" appears only here.

2. **Fixture with every kind of thing.** Before you start, seed content that holds every element
   kind the product can render or store - read the renderer/model/schema code for the real list,
   don't guess. A markdown editor: every block and inline type, nested ones, and the degenerate
   ones (empty heading in a list item, empty item, trailing blank lines). A calendar: all-day,
   timed, overnight, recurring, cross-time-zone, overlapping. A board: cards with every field
   set, none set, very long ones, with attachments, blocked, archived. A table/grid: every column
   type, empty cells, merged/wrapped cells. Put it on one page so each pass covers all of it.

3. **Element x gesture matrix.** For every element kind in the fixture, every gesture the surface
   accepts: click at the start, middle and end of its content, on its empty area, double-click,
   triple-click, Shift+click and Ctrl+click on another element, right-click, drag, Enter/Space
   from the keyboard cursor. Write it down as a table in `probes/use/<surface>-matrix.md`
   (element x gesture -> what happened). Check each cell against the next two moves.

4. **It lands where aimed.** After every gesture: the thing that reacted is the one under the
   pointer or cursor - not its neighbour, not the title, not the last row. Where the product puts
   a caret, selection or insertion point, it is exactly where the user aimed. Oracle: type a
   unique marker (`§17`), then read the stored data and find where the marker went.

5. **Across the edges.** Every boundary between two elements (two paragraphs, two cells, two
   cards, two days, two list items, a parent and a child): the edit and navigation keys at the
   edge (Enter in the middle and at the end, Backspace at the start, Delete at the end,
   Up/Down/Left/Right across, Home/End, PageUp/PageDown, Tab/Shift+Tab); selecting across it
   (drag, Shift+arrows, Shift+click, Ctrl+A then Ctrl+A again); copy, cut and paste of a
   selection that spans it (compare the clipboard with the stored data); drag one thing onto or
   between others. "Nothing happens at the edge" is a finding.

6. **Through the transitions.** Every change of mode or container with input still pending:
   view -> edit -> view, preview <-> source, collapsed <-> expanded, list <-> board, one document
   -> another, one profile -> another, window hidden and shown, the app closed right after typing.
   Do each **before** any autosave/commit timer fires and again after it. Expect: no input lost,
   caret/selection/scroll close to where they were, nothing duplicated.

7. **Look again after the timers.** Find the product's delayed work in the code (grep `Timer`,
   `setTimeout`, `debounce`, `throttle`, `interval`, autosave, reparse, sync, animation
   durations). After every edit take a screenshot at once **and** after the longest such delay +
   200 ms. Invariants, checked by zooming in on the spot:
   - what the user just typed is visible, where they typed it;
   - the thing being edited did not move or jump (compare its box before and after);
   - nothing else re-laid out, vanished or doubled.
   Edits that change structure (join, split, paste of several lines/rows, indent/outdent, move to
   another group) rebuild views most often: run each of them against these invariants.

8. **Behaves like the tool it imitates.** A text area behaves like a plain text editor, a grid like
   a spreadsheet, a file tree like the system file manager, a date field like the OS date picker.
   For each surface name the tool users already know and check its standard moves (the ones in
   5-6 are a start). A deviation with no visible reason is a finding; "the product does it
   differently on purpose" needs evidence from the code or docs.

9. **Real input for real gestures.** Pointer semantics - which item takes a press, scroll areas,
   drag thresholds, focus on click, double-click timing - must be exercised with real input (OS
   driver in real-input mode, computer-use, or the framework's driver delivering real events, e.g.
   Qt Quick Test `mouseClick`, Playwright). Synthetic window messages (posted/sent clicks) are fine
   for navigation but do not count as coverage for those cells: mark them `not covered (synthetic
   input)` instead of passing them. Ask the user before taking over their mouse (00-safety.md).

10. **The screen and the data agree.** After each step compare what is drawn with what is stored:
    the stored data differs from the step before only by the intended change (diff the file/DB
    record, not just "it saved"); what is drawn is what is stored; a restart shows the same.

## How to run it
- Build the **surface list** from the surface map: every place users create or change content
  (editors, inline fields, grids, boards, calendars, canvases, forms, tables, trees). Each gets a
  fixture (move 2) and a matrix (move 3).
- One agent per one or two dense surfaces (`templates/brief-use.md`); it works on its own isolated
  profile, seeded with the fixture, and keeps a short work log in `probes/use/<surface>-log.md`
  (what it did, in order) - the log is the repro for sequence bugs.
- Prefer the framework driver for the matrix (cheap, real events); confirm every finding in the
  real app with real input and a screenshot pair (before / after the timers).
- Each finding records the start state (fixture element, prior steps from the log), the gesture
  or key, what was expected (and from which standard tool, for move 8), what happened, and the
  screenshot pair.
- Severity: input lost or written to the wrong place = S; input that vanishes from sight, an
  element kind that cannot be edited, or an edge where the standard move does nothing on a core
  surface = A; the caret/selection/insertion point landing away from the aim, a jump or re-layout
  after a timer, a standard move that behaves differently = B; the same on a rarely used surface
  or with an obvious workaround = C.

## When fixing (only if the user asked for fixes)
Fix the class: one place maps a pointer position to the model position (and every element kind
uses it); views that rebuild under an open editor re-find the edited item from the model, not from
a cached index; edge keys and cross-element selection follow the imitated tool; pending input is
flushed before every mode/container change. Add a regression test per finding that runs the
gesture, waits past the timer, and checks both the data and the position.
