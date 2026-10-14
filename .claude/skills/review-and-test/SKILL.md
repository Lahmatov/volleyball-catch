---
name: review-and-test
description: >
  Review a change or a whole project like the senior developer who gets paged
  when it breaks, then prove it with real tests: plain-language test scenarios,
  actually executed, each one passed or failed with evidence. Optionally fixes
  what failed and re-runs. Use for "review and test", "проверь и протестируй",
  "ревью и тесты", "check my code and test it", /review-and-test.
  Arguments: optional target (files, folder, branch, commit range, PR),
  and "--fix" to fix confirmed problems after the report.
---

Two halves, in this order: **review** (find what is wrong and why), then
**test** (run the code and prove what works and what does not). A review
finding is a claim; a test is evidence. The report the user gets is built
from both.

Reply in the user's language. Short sentences, everyday words. Explain a
technical term the first time you use it. The reader may never have seen
this code.

Ideas taken from [ponytail-review](https://github.com/DietrichGebert/ponytail)
(read the connected code, concrete case per finding, four-part findings,
lean) and [Shortest](https://github.com/antiwork/shortest) (tests written as
plain-language steps with explicit expectations, executed for real, strict
passed/failed with a one-sentence reason).

## 0. Scope

- Target = what the user names: files, a folder, a branch, a commit range,
  a PR. Nothing named: uncommitted changes; none → the current branch against
  the default branch; on the default branch → the whole project.
- Find how the project builds, runs and is tested: README, package/build
  files, CI config, existing tests, scripts. Note the expected load (one
  person, a few players, many users) and judge scale against it.
- `--fix` given: you may change code in step 4. Otherwise change nothing
  except adding test files.

## 1. Review

Read the diff, then the code it touches: callers of every changed function,
what it calls, its tests. Trace the real flow: where input comes in, what is
stored, what goes out, what runs every frame / request / tick.

Look for, in this order of importance:

1. **Bug:** wrong result, crash, missed edge case (empty, zero, last item,
   nil/null, rounding, time zones, a player leaving mid-action), a caller
   broken by the change.
2. **Risk:** security (injection, trusting client input, secrets in code,
   missing checks at a trust boundary), data loss (swallowed errors, writes
   in the wrong order, saves that can overwrite newer data).
3. **Scale:** fine for one, wrong for many: races, per-item queries, lists
   or tables that only grow, O(n²) on big input, work repeated every frame.
4. **Missing test:** risky logic (branch, parser, money, rewards, security,
   data writes, a bug fix) with no test that fails when it breaks.
5. **Speed:** big slowdowns are problems; small wins are suggestions.
6. **Lean:** dead code, near-copies that must change together, a helper the
   repo already has, abstraction with one use.

Before keeping a finding:
- It needs a concrete case: "this input / situation → this wrong result".
  No case, no finding.
- Re-read the lines and confirm the caller exists, the value can really be
  empty, the code really is unused (grep the whole tree).
- No style taste, no "consider", no vague worries.

## 2. Test plan (plain language)

Write the plan before writing any test code. Each scenario is:

```
T3. Buying a hat with too few coins
    Steps:   open shop · pick the 150-coin crown · press buy with 40 coins
    Expect:  refused with "not enough coins" · coins still 40 · no crown owned
    Covers:  finding 2 (or: main flow "shop")
```

Rules:
- At most 5 steps per scenario, each step at most 10 words, written as a
  user or caller would say it. Longer flows: split, or chain scenarios
  (`T4 = T1 then ...`).
- Every scenario has explicit expectations. A scenario with any expectation
  unmet is **failed**.
- Cover, in this order: every Must-fix and Should-fix finding (a scenario
  that reproduces it), then the main user flows (happy path), then edge cases
  (empty, zero, limit, leaving mid-way, twice in a row).
- 5 to 15 scenarios. More only when the user asks.

## 3. Run the tests

Run everything for real. Never mark a scenario passed without evidence
(command output, assertion result, screenshot).

1. **Existing checks first:** the project's own lint, type check, build and
   test commands. Record their exact result.
2. **Turn scenarios into code** with the project's own test framework and
   conventions. Pick the cheapest level that really exercises the behavior:
   - pure logic → unit test;
   - several modules together → integration test with real modules and
     only the outside world stubbed;
   - web UI → browser test (Playwright, headless Chromium). Act like a user:
     click visible text, type, wait for the result, then check the page.
     Take a screenshot when an expectation fails;
   - platform you cannot run here (game engine, phone, hardware, paid API) →
     a small harness that stubs only the platform API and runs the real
     logic modules; anything still not runnable goes on a manual checklist
     with exact steps.
3. Tests live in the repo next to the code (follow existing layout, else a
   `tests/` folder), with one command to run them all. Add that command to
   the README if the project has none.
4. A test that fails: check the test first (wrong setup or wrong
   expectation?). Only a failure that survives that check counts as a real
   failure. Never weaken an expectation to get green.

## 4. Fix (only with `--fix`, or after the user says so)

- Fix Must-fix findings and failed scenarios with the smallest change that
  works, at the root cause, in the shared code.
- Re-run the full suite plus the project checks after the fixes. Show the
  before → after for each fixed scenario.
- Do not fix what needs a product decision; ask instead.

## 5. Report

Start with `What this does:` in two or three sentences, and the load you
assumed.

**Findings**, numbered across groups, skip empty groups:
- **Must fix:** bug, security, data loss, breaks at the expected load.
- **Should fix:** risky code without a test, real slowness, duplication.
- **Nice to have:** small speed-ups, shorter forms.

Each finding, one or two short sentences per part:

```
2. **Coins can go negative** (`server/Shop.lua:L40-52`)
   - What this is: ...
   - Problem: <concrete case>
   - Fix: <smallest fix>
   - If we skip it: ...
   - Test: T3 — failed: "coins became -110 after buying the crown"
```

**Test results** as a table: scenario · passed/failed · one-sentence reason.
Then the totals (`12 passed, 2 failed`), the command that runs the suite,
and the existing-check results.

End with:
- `Verdict:` `Ship.` or `Fix 1 and 3 first.`
- `Manual checks:` the steps that could not run here, if any.
- `Not checked:` one line on what you could not read or run.

Nothing found and all tests pass: `What this does:`, the results table,
`Looks good. Ship.`
