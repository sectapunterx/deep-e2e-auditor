---
name: deep-e2e-auditor
description: >-
  Deep end-to-end audit of a desktop app (Windows, macOS, Linux - Qt, WPF, WinForms, Electron,
  Tauri, GTK, native) or a web app/site: a full functional e2e audit from UI to backend and
  integrations, plus an "eyes" audit of what only shows when you look at and use the product -
  inconsistent context menus and dialogs, overloaded cards, broken hierarchy, clipping, contrast,
  states nobody designed. Parallel area agents, isolated sandboxes, independent re-verification,
  and a tiered report with an annotated screenshot gallery. Use for "e2e test the app", "audit the
  UI/UX", "find everything that is broken", "QA pass before release", "deep test my site".
argument-hint: "[path-or-url] [--functional|--visual|--both] [--quick]"
---

# deep-e2e-auditor

You run a deep audit of the user's product and hand back a report they can fix from. Two halves,
done together unless the user narrows it:

- **Functional** - every feature exercised end to end through the real UI and down to storage,
  network and integrations: data loss, wrong results, broken flows, races, performance cliffs.
- **Eyes** - the product looked at and used like a person would: every surface captured in every
  state, compared with its siblings, judged against design heuristics and measured. This is what a
  functional audit misses: a context menu styled unlike the others, a card with eleven chips, a
  dialog whose buttons swap sides, a label that clips in the second language.

Report only, no fixes, unless the user asks for fixes. Findings need evidence; an unverified
hunch is not a finding.

Read these before the phase that needs them (they are the method; this file is the map):

| Phase | Read |
|---|---|
| 0 Intake + safety | `references/00-safety.md`, `references/01-intake.md` |
| 1 Harness (how to drive and capture the target) | `references/02-harness.md` |
| 2 Functional audit | `references/03-functional.md` |
| 3 Eyes audit | `references/04-eyes.md` |
| 4 Verify + report | `references/05-report.md` |

Agent briefs to hand to subagents: `templates/brief-functional.md`, `templates/brief-eyes-surface.md`,
`templates/brief-eyes-persona.md`, `templates/brief-verify.md`. Finding format:
`templates/finding.schema.json`.

## Tools in this skill (`scripts/`)

| Script | What it does |
|---|---|
| `win/capture.ps1` | Launch or attach, capture every window of the process (menus/popups included) into one PNG via PrintWindow - never grabs what covers it |
| `win/input.ps1` | Click / right-click / drag / keys / text. `post` mode leaves the user's cursor alone; `send` mode is real input |
| `win/uia_tree.ps1` | UI Automation tree: every element's role, name, box - the map of what to click |
| `mac/driver.sh`, `linux/driver.sh` | Same four jobs on macOS (JXA + screencapture) and X11/Xvfb (xdotool + import + AT-SPI) |
| `web/session.mjs` | Playwright: one scripted session (URL or Electron), screenshots, a11y tree, axe, console, failed requests, element inventory |
| `web/crawl.mjs` | Map a site: every same-origin page x widths x light/dark, axe, overflow, console errors, inventory |
| `visual/contact_sheet.py` | Same-kind surfaces side by side on one labelled sheet |
| `visual/pixels.py` | Contrast, palette, palette diff between two surfaces, visual density, image diff |
| `visual/annotate.py` | Numbered boxes on a screenshot |
| `report/build_report.py` | findings/*.jsonl -> `REPORT.md` (tier list) + `gallery.html` (every finding with boxed screenshots, sheets) |

Scripts are run from the skill dir (`~/.claude/skills/deep-e2e-auditor` or wherever it is
installed). Web tools need a one-time `npm run setup` in `scripts/web`; the visual tools need
Python 3 with Pillow (`pip install pillow`).

## The run, end to end

1. **Intake** (`01-intake.md`). Find out what the product is, how to build and launch it, how to
   isolate its data, which accounts/sandboxes are allowed, what must never be touched, and what the
   user wants back. Ask only what the code and docs cannot tell you - in one round of questions.
   Create the run dir `<project>/.deep-e2e/runs/<YYYY-MM-DD>-<n>/` (add `.deep-e2e/` to
   `.git/info/exclude`, never to a tracked file) and write `run.json` + `HARNESS.md` there.
2. **Harness** (`02-harness.md`). Prove you can launch the target isolated, capture it, drive it
   (click, right-click, type, keys), and read its structure (UIA/AX/AT-SPI tree or DOM). Prefer the
   framework's own test driver for behaviour (Qt Quick Test with the real main window, Playwright
   for web/Electron, FlaUI/UIA for WPF) and the OS driver for pixels. Write the recipe into
   `HARNESS.md` - every agent reads it.
3. **Maps.** Build the *area map* (features, from code + docs + UI) and the *surface map* (every
   window, view, dialog, menu, popup, toast, card/row type, empty/error state and how to open it -
   from code search and from walking the UI). Both go to the run dir; the plan is sized from them.
4. **Fan out** (Agent tool, background, in parallel). Functional agents take areas; eyes agents take
   surface groups and personas. Each gets its brief from `templates/`, the harness recipe, its own
   isolated profile, and writes `findings/<area>.jsonl` + screenshots under `shots/<area>/`.
   Size the fan-out to the machine (builds and GUI sessions are heavy; 4-8 agents is typical).
5. **Verify** (`05-report.md`). Every S and A finding, and every visual finding that rests on a
   judgement, is re-run by an agent that did not find it: confirmed / plausible / rejected.
   Duplicates across areas are merged.
6. **Report.** Contact sheets for every surface group, then `build_report.py`. Give the user the
   tier counts, the top S/A items in a few lines, and the paths to `REPORT.md` and `gallery.html`
   (publish the gallery as an Artifact if the user wants a link). Leave everything you started
   stopped and every sandbox cleaned up; list what you could not cover and why.

`--quick`: one functional agent for the riskiest areas + the surface census, consistency sheets and
one persona session; same report format.

## Non-negotiables

- The user's real data, accounts and machine are never at risk: isolated data dirs/profiles/
  browser contexts, never the real one; read-only copies only with permission; never kill a process
  you did not start; destructive actions on real services only in sandboxes the user named.
- You do not type the user's passwords, tokens or payment details. When a sign-in is needed, the
  user does it in the browser/app themselves; you continue after.
- Input that takes over the user's mouse/keyboard (`send` mode, macOS/Linux real input) needs their
  OK first; prefer `post` mode, headless drivers, or a virtual display.
- Every finding has repro steps, expected vs actual, and evidence (a probe, a log line, a
  screenshot with a box, a number). Visual findings always carry a screenshot.
- Severity is about user impact, not about how easy it is to fix (`05-report.md` has the scale).
