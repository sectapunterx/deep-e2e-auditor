# Phase 4 - Verify and report

## Severity scale (user impact)
| Tier | Meaning | Examples |
|---|---|---|
| S | data loss, security, crash, corruption | save overwrites the real file; undo deletes another user's record; token in logs |
| A | a core feature is broken or unusable | drag in the week view snaps back; editor loses typed text; search misses most content |
| B | a visible bug or a real UX defect on a normal path | context menu styled unlike the others; card so dense its state is unreadable; Esc closes the wrong layer |
| C | minor, polish, edge case | 2 px misalignment; English word in the Russian UI; tooltip clipped at the edge |
| D | nit | wording, a slightly off colour on a rarely seen surface |
Visual/UX defects are B when users meet them on the main path every day (overloaded cards,
inconsistent core menus), C when occasional, D when cosmetic and rare. They are never "not a bug".

## Verification pass
Spawn verification agents (`templates/brief-verify.md`) that did not produce the findings:
- every S and A: re-run the repro on a fresh isolated profile; `confirmed` / `rejected` / `plausible`
  (reproduced partly, or depends on timing/environment);
- every visual finding that rests on judgement (consistency, density, hierarchy): a second reviewer
  looks at the evidence only and agrees or not; disagreement -> `plausible`;
- duplicates across areas: merge into one (`duplicate_of`), keep the best evidence.
Update the JSONL in place (the verifier sets `verdict`); never delete a finding silently.

## Run dir layout
```
.deep-e2e/runs/2026-09-30-1/
  run.json  HARNESS.md  surfaces.json  areas.md
  findings/<area>.jsonl        one finding per line (templates/finding.schema.json)
  shots/<area-or-group>/...    screenshots (relative paths in findings)
  sheets/*.png                 contact sheets
  personas/<name>.md           persona transcripts
  probes/<area>/...            probe/test files and their logs
  REPORT.md  gallery.html  annotated/    (generated)
```

## Build the deliverables
```
python scripts/report/build_report.py .deep-e2e/runs/2026-09-30-1 --title "App 1.2 - deep e2e audit" --lang en
```
`REPORT.md` = tier list (S -> D tables: id, kind, defect, where; ✔ = re-verified) + counts;
`gallery.html` = every finding with its screenshots, boxes drawn, filters by tier and kind, all
contact sheets at the end. Then add by hand to REPORT.md, above the tables:
- **How it was tested** (build, platforms, sizes/themes/locales, sandboxes, agents, number of probes
  and screenshots);
- **Top items** - the S and A findings in one line each;
- **What works** (selected; so coverage is visible) and **Not covered** (and why);
- **Cleanup** - what was created in sandboxes and removed, what is left for the user.

## Tell the user
Counts per tier, the S/A list in a few lines, the paths to REPORT.md and gallery.html, the not-covered
list. Offer to publish the gallery as an Artifact page (images embedded or uploaded as assets) if they
want a link to share. Do not start fixing unless asked.
