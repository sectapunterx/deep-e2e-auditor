# Safety rules (every agent gets these)

An audit that damages the user's data or accounts has failed, whatever it found. These rules are
copied verbatim into every agent brief.

## Data
- Run the target only against an isolated data location: a `--data-dir`/`--profile`/`--user-data-dir`
  flag, an env var the app honours, a fresh browser context, a copy of the app under another name
  (some frameworks key their test profile on the exe name), a VM/container, or a throwaway OS user.
  Find which one works in Intake and prove it in Harness *before* any agent starts.
- If the app has no isolation mechanism, stop and tell the user; propose one (e.g. `HOME`/`APPDATA`
  redirection that the app honours, a portable build, a VM) rather than running against real data.
- A copy of real data (for migration / scale / "does my actual profile still load") only with the
  user's explicit permission, read-only at the source: copy first, then work on the copy.
- A hard precondition before touching any data location: no instance of the app is running against
  it (the user may have one open). Check the process list; if one is running, ask.
- Never delete or overwrite anything outside the run dir and the isolated data dirs you created.

## Processes and machine
- Kill only processes you started (keep their PIDs). Never "kill all app.exe".
- Don't build over binaries another agent is using; each agent builds in its own worktree/dir or
  uses a shared build that nobody rebuilds during the run.
- Input that moves the user's real cursor or steals focus (`input.ps1 -Mode send`, macOS/Linux
  drivers on the live display) needs the user's OK. Prefer headless drivers, `post` mode, Xvfb.
- Watch memory. A probe that walks a huge item tree or opens thousands of windows can take the
  machine down; cap it, and stop an agent whose process runs away.

## Accounts, network, integrations
- Only the sandboxes/test accounts the user named (a test repo, a test project, a staging site).
  Write real queries so they cannot match production data (e.g. an explicit project filter).
- The user performs sign-ins, 2FA and consent screens. Never type their passwords, API keys, tokens
  or card numbers; never read them out of files to use them.
- No load testing, fuzzing or scanning of hosts the user does not own. A web crawl stays on the
  target origin, skips logout/delete-style links and never submits forms unless a brief says to, in
  a sandbox.
- Anything that sends messages, emails, payments or public posts: sandbox only, or ask.
- Remove what you created in sandboxes at the end (issues, pages, test users) or list it for the user.

## Reporting honestly
- Say what was not covered and why. Say when a finding is code-read rather than reproduced.
- A test that could not run is "not covered", not "passed".
