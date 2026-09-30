# deep-e2e-auditor

A Claude Code skill that runs a deep end-to-end audit of a desktop app (Windows, macOS, Linux) or
a web app/site. You get a tiered report and an annotated screenshot gallery covering two things:

- **Functional:** every feature is exercised through the real UI down to storage, network and
  integrations. Parallel area agents run in isolated sandboxes, and every serious finding is
  re-checked independently.
- **Eyes:** every surface is captured in every state, and same-kind surfaces are compared side by
  side. This catches the context menu that doesn't match the others and the overloaded card. It
  also includes a heuristic walkthrough, pixel measurements, and persona sessions that use the
  product like a person would.

## Install

```sh
git clone git@github.com:sectapunterx/deep-e2e-auditor.git ~/.claude/skills/deep-e2e-auditor
cd ~/.claude/skills/deep-e2e-auditor
pip install pillow                           # visual tools + report
cd scripts/web && npm run setup              # web/Electron drivers: Playwright + Chromium + axe (optional)
```

On Windows the path is `%USERPROFILE%\.claude\skills\deep-e2e-auditor`.

## Use

In Claude Code, inside the project you want audited:

```
/deep-e2e-auditor                      # both halves, whole product
/deep-e2e-auditor --visual             # eyes only
/deep-e2e-auditor https://staging.example.com --quick
```

The skill reads the repo first, then asks one round of questions: scope, sandboxes, what must
never be touched, and real-data permission. It then proves a harness, maps features and surfaces,
and fans out agents. It writes everything to `.deep-e2e/runs/<date>/` in the project, which is
git-excluded locally and never committed.

## What's inside

| Path | |
|---|---|
| `SKILL.md` | the workflow |
| `references/` | safety rules, intake, harness recipes per platform/framework, functional method, eyes method, report and verification |
| `templates/` | agent briefs (functional, eyes surfaces, persona, verification), finding schema |
| `scripts/win/` | capture (all windows of a process, occlusion-proof), input (posted or real), UI Automation tree |
| `scripts/mac/`, `scripts/linux/` | the same four jobs for macOS (JXA + screencapture) and X11/Xvfb (xdotool + ImageMagick + AT-SPI) |
| `scripts/web/` | Playwright session runner and site crawler (screens × widths × themes, axe, console, overflow) |
| `scripts/visual/` | contact sheets, pixel measurements (contrast, palette, density, diff), annotation |
| `scripts/report/` | builds `REPORT.md` and `gallery.html` from the findings |

## Status

- **Windows desktop drivers:** tested on a Qt 6 app.
- **Web drivers:** tested with Playwright 1.63.
- **macOS and Linux drivers:** follow the platform APIs but are not tested on real hardware. The
  harness phase checks every command once before agents rely on it.
