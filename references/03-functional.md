# Phase 2 - Functional audit

Exercise every feature through the real UI, check what reached storage/network, and push on the
edges where products break. This is the half that finds data loss, broken flows and wrong results.

## Area map
Split the product into 4-8 areas that one agent can own (by feature and by code ownership), e.g.
desktop task app: persistence/profiles/CLI · board/tasks/editor · calendar/recurrence/reminders ·
notes/docs/markdown · shell/keyboard/i18n/themes · integrations/release. Web shop: auth/account ·
catalogue/search · cart/checkout/payments(sandbox) · admin · content/SEO · API. Every area lists
its features, the code that implements them, and the data they touch.

## What every functional agent does
1. **Inventory** its area: every feature, command, shortcut, setting and state (from code and UI).
2. **Happy path** for each feature through the real UI, then **read back** what was persisted
   (file, DB, request) - a UI that says "saved" is not evidence.
3. **Break it** - the probe patterns below. Riskiest first: anything that can lose or corrupt data.
4. **Round-trips**: save -> restart -> load; export -> import; sync out -> sync in; undo -> redo.
5. **Record** findings as it goes (`findings/<area>.jsonl`), with the probe that shows each.
6. **Report** what works (so the user knows it was covered) and what was not covered.

## Probe patterns that find real bugs
- **Storage**: kill during save; locked / read-only / full target; corrupt / truncated / empty /
  wrong-schema / newer-schema file on startup; two instances on one data dir; backup/restore with
  pending edits; unknown keys surviving a save.
- **Identity**: two records with the same name/title/empty id; ids reused after delete; the same id
  across profiles/tenants; rename while referenced.
- **Undo/history**: undo after switching profile/document/view; undo of actions that were never
  recorded; redo after a new action; the toast's Undo vs the stack top.
- **Time**: midnight passing while open; DST; time zones of imported data; "today" cached at
  startup; a time that already passed today; month-end (29-31) and leap days; locale week start.
- **Recurrence/series**: edit this / this-and-following / all; drag one occurrence; delete one;
  COUNT/UNTIL after a split; reminders for occurrences.
- **Input**: very long text, no spaces, emoji, RTL, Cyrillic, pasted rich text, empty, whitespace
  only; values at and past limits; locale decimal separators; typed dates in several formats.
- **Keyboard**: every shortcut in text fields, in menus, behind modals; Esc order (innermost first);
  Tab order reaches everything; focus visible; Enter in dialogs.
- **Concurrency/async**: double-click submit; action during a sync/load; slow/offline network; a
  request that fails halfway; token expiry during a session.
- **Integrations (sandbox only)**: scope/filter changes; remote edits vs local edits (conflicts);
  deletes on either side; labels/fields removed upstream; pagination past 100; rate limits.
- **Scale**: 1k/10k items, huge single documents; measure startup, view switches, typing latency,
  memory (a virtualised list builds what is on screen, not everything).
- **Release artifact** (when in scope): clean machine / clean PATH start, bundled dependencies,
  signing, CLI flags, `--version`, unknown flags.
- **Accessibility basics**: names on interactive elements (tree dump), keyboard-only completion of
  the main flows, contrast (see eyes audit).

## Evidence
- A probe file (test, step script, command sequence) that reproduces it, and the log line / output.
- For UI-visible results, a screenshot (the eyes half and the gallery use them).
- `code_refs` when the cause is found (file:line) - helps the fix, not required for the finding.
- Code-read-only findings are allowed but marked `"evidence": {"probe": "code-read"}` and never S/A
  without a reproduction.
