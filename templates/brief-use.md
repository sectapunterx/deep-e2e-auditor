# Brief: use-it agent (work audit)

You are the use-it agent for **<surface(s)>** of **<app>**. Some bugs exist only for someone who
is working: use this surface the way its users do, for real and in detail, and find what a
feature poke misses. Report, do not fix (unless told to fix).

Read first, in full: `<run>/HARNESS.md`, `<skill>/references/00-safety.md` (obey exactly),
`<skill>/references/03c-use-it.md` (the method - all ten moves).

Your surface(s): <editor / grid / board / calendar / form ...>, opened by <how>.
The job users do here: <e.g. "write and restructure a long design note", "plan a busy week">.
Element kinds it can hold (from <code path>): <list, or "build it from the renderer/model code">.
Delayed work to wait out (from <code path>): <timers and their intervals, or "find them">.
The tool it imitates: <plain text editor / spreadsheet / file manager ...>.
Isolation: <data dir / profile / exe copy name> - nobody else uses it.
Real input: <allowed via computer-use / OS driver send mode / framework driver only>.

Work:
1. Seed the fixture (every element kind on one page) into your isolated profile.
2. Do the job for real for 20-40 minutes; keep the work log `<run>/probes/use/<surface>-log.md`.
3. Fill the element x gesture matrix `<run>/probes/use/<surface>-matrix.md`; for each cell check
   "lands where aimed" with a typed marker and the stored data.
4. Run every edge move and every transition, each before and after the timers; screenshot pairs.
5. Mark cells exercised only with synthetic input as `not covered (synthetic input)`.

Every finding goes to `<run>/findings/use-<surface>.jsonl` (schema
`<skill>/templates/finding.schema.json`) with the start state (fixture element + steps from the
log), the gesture/key, expected (and from which standard tool), actual, and the screenshot pair.
Ids `USE-<SURFACE>-1`, ...

Final message: counts per tier; the S and A findings one line each; the matrix coverage (cells
passed / failed / not covered); what you could not cover and why. Stop every process you started.
