# Phase 0 - Intake

Goal: know enough to plan the run, and have the user's decisions on the things only they can
decide. One round of questions, after you have read what you can.

## Read first (don't ask what the repo answers)
- README, docs/, CONTRIBUTING, CHANGELOG: features, supported platforms, how to build and run.
- Build files (CMakeLists, package.json, *.csproj, Cargo.toml, pyproject): framework, entry point,
  test targets, existing test harnesses (Qt Quick Test, Playwright, Cypress, pytest-qt, FlaUI...).
- The app's CLI flags / env vars: `--help`, main(), argument parsers - look for data-dir, profile,
  view/route, safe/smoke/test modes, locale and theme switches, feature flags.
- Where it stores data (QStandardPaths, app.getPath, Environment.SpecialFolder, localStorage,
  IndexedDB, a backend DB) and whether that can be redirected.
- Integrations (trackers, auth providers, payments, email, sync servers) and their config.
- Previous audit reports, open issues labelled bug/ui/ux: known problems to re-check, not re-find.

## Ask (one AskUserQuestion round, 2-4 questions, only what is still open)
Typical questions - drop the ones the repo answered:
1. **Scope**: functional + eyes (default), or one of them; whole product or some areas; quick or deep.
2. **Targets**: which platforms/builds (dev build, release artifact, installer, staging URL,
   production URL read-only), which window sizes / locales / themes matter most.
3. **Sandboxes**: which test accounts / repos / projects / staging environments may be written to,
   and what must never be touched (name it exactly - e.g. "project LUX is real, only use TEST").
4. **Real data**: may you read a copy of their real profile/DB to test migration and scale?
5. **Output**: language of the report; report only (default) or also file issues / fix.

Sign-ins: if integrations need OAuth/login, plan a moment where the user signs in themselves
(browser device flow, the app's own login) into the isolated profile; say when you will need them.

## Write down (run dir)
`run.json`:
```json
{"app": "name", "version": "x.y.z", "commit": "abc1234", "platforms": ["windows"],
 "targets": ["build/app.exe", "https://staging..."], "scope": "both", "lang": "en",
 "sandboxes": {"github": "user/test-repo"}, "never": ["project LUX"], "notes": "..."}
```
`HARNESS.md` is written in phase 1. Keep both short; every agent reads them.

## Plan size
From the area map and surface map (phase 3 of SKILL.md): list agents, what each covers, and rough
cost. For a big product tell the user the plan in a few lines before fanning out.
