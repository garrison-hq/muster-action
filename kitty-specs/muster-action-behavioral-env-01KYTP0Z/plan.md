# Implementation Plan: muster-action behavioral env inputs

**Branch**: `kitty/mission-muster-action-behavioral-env` | **Date**: 2026-07-31 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `kitty-specs/muster-action-behavioral-env-01KYTP0Z/spec.md`

**Branch contract** (stated per the workflow's mandatory repeat-twice rule):
current branch at plan start is `kitty/mission-muster-action-behavioral-env`, which
**is** the mission's target/coordination branch (`meta.json.target_branch` and
`coordination_branch` both resolve here) — there is no separate planning-base vs.
merge-target split for this mission; `plan.md` is committed directly to this
branch, and this is also where the eventual merge lands.

## Tooling note (read before trusting `setup-plan`/`charter context` output)

`spec-kitty agent mission setup-plan --mission muster-action-behavioral-env-01KYTP0Z --json`
and `spec-kitty charter context --action plan --json` both currently fail with
`CHARTER_PACK_CONFIG_INVALID` in this repo checkout — reproduced with a
completely absent charter, with a hand-authored `charter.md` only, and with a
full-default `spec-kitty charter generate` output, so the failure is not caused
by this plan's charter content. This blocks the CLI-driven scaffold/auto-commit
path for `plan.md`. This plan was authored by hand at the path the CLI would
have used (`kitty-specs/muster-action-behavioral-env-01KYTP0Z/plan.md`),
following the same template (`.kittify/missions/software-dev/templates/plan-template.md`).
**Operator action needed**: this is a spec-kitty tooling defect independent of
this mission's content; it should be triaged (possibly via `spec-kitty upgrade`,
given the sibling `muster` repo's CLAUDE.md already flags a pending project
migration) before `/spec-kitty.tasks` is run, so `tasks-finalize`'s own gates
are not blocked the same way.

## Summary

Add a documented, guarded input surface (`model-endpoint`/`model`/`api-key` →
`MUSTER_ENDPOINT`/`MUSTER_MODEL`/`MUSTER_API_KEY`) to `muster-action`, mirroring
the empty-must-be-unset discipline the existing A2A pair already has, plus a new
`report-file` output that makes a non-vacuous CI assertion about a discrimination
control possible. The central technical fact driving this plan: **muster's exit
code cannot, by itself, distinguish "the agent has a real conformance problem"
from "the network/endpoint was broken" from "everything worked" for the
discrimination-control case** — all three can read `failed`/exit `1` (a
correctly-firing control) or collapse in confusing ways. The plan's job is to
make the actual mechanism that resolves this ambiguity (`report-file` +
anchored per-case markers + a conjunction assertion) concrete enough to build
and test, not to restate the principle.

## Technical Context

**Language/Version**: Bash 5 (GitHub Actions `shell: bash` steps) + YAML
(action metadata, example/test workflows). No new source language — this
mission extends the existing `action.yml`/`scripts/run.sh` composite-action
surface; it does not introduce a compiled component.
**Primary Dependencies**: `@garrison-hq/muster` (consumed via `npx`, version
pinned per Decision D1 below — see the SHA-pin implementability finding, which
changes *how* the pin is exercised, not that it is a dependency); GitHub's
`actions/setup-node@48b55a0` (existing); no new first-party dependency added.
**Storage**: N/A — the only persisted artifact this mission adds is the
evidence-artefact **template** (FR-006), which is documentation, not a runtime
store this repo's own CI populates.
**Testing**: GitHub Actions workflow-based integration tests
(`.github/workflows/test.yml`), following the existing pattern (`static-pass`,
`static-fail`, `a2a-skip` jobs) — shell `test "$X" = "Y"` assertions against the
action's own `outputs.result`/`outputs.exit-code`, extended with `report-file`
marker assertions (anchored `grep -x`). No unit-test framework is introduced;
this repo has no application code of its own to unit-test.
**Target Platform**: GitHub-hosted `ubuntu-latest` runners (existing).
**Project Type**: Single project — a composite GitHub Action repo, no
frontend/backend split.
**Performance Goals**: N/A in the traditional sense; the one bounded cost is
the control-inversion conjunction check's overhead (~10% extra run time per
scheduled behavioral job, per the source issue's own estimate) — accepted, not
optimized against.
**Constraints**: C-001 (backward compatible), C-002 (exit contract 0/1/2
unchanged and faithfully passed through, not widened/collapsed), C-003/C-004
(no `.env` instruction; no credential persistence beyond the process
environment and the (now-retained) report file, which must never contain the
credential value itself), NFR-002 (no `pull_request_target` without a reviewed
justification — this plan introduces none).
**Scale/Scope**: ~450 lines total across `action.yml`/`scripts/*` today; this
mission's diff is expected to stay in the same order of magnitude (new inputs,
a new output, guard-block extension, report-file retention, README/example
additions). Single repo, single lane (confirmed below, not re-litigated).

## Charter Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

A charter did not exist for this repo before this mission (confirmed via
`spec-kitty charter context --action plan --json` returning `mode: "missing"`
before any charter file existed). Per Decision D3 (accepted, not re-litigated),
a **minimal, hand-authored charter** was written to
`.kittify/charter/charter.md` — not generated via `spec-kitty charter
interview`/`generate`, both because the operator's brief said "you may author
it; do not run an interview" and because the installed generator's mission-type
default pulls in ~30 directives and 13 paradigms (atomic design, DDD, C4
modeling, mutation-testing-as-gate, semantic compression, …) that do not
describe a 450-line CI wrapper — confirmed empirically: a full-default
`charter generate` run was inspected and discarded as disproportionate before
this hand-authored version was written. (Separately, `charter generate` and
`charter context` both currently fail with `CHARTER_PACK_CONFIG_INVALID`
regardless of charter content — see the Tooling Note above; this is why the
charter is not wired into `config.yaml`'s `charter: .kittify/charter/charter.yaml`
pointer today. `config.yaml` still points at a `charter.yaml` path that does not
exist. This is a real gap between the config pointer and the charter this
mission actually authored — flagged for the operator, not silently
worked around.)

The hand-authored charter carries three directives, gated against below:

1. **Credential handling** — env vars only, never argv/manifest/log. **Gate
   check**: this plan's data-flow design (below) routes `model-endpoint` /
   `model` / `api-key` through `env:` mapping only, mirrors the existing
   A2A pair's argv-exclusion, and FR-004's `report-file` design explicitly
   never contains a credential value (the report is muster's own stdout/stderr,
   which never echoes `MUSTER_API_KEY`'s value — confirmed by reading
   `src/cli/index.ts`: the key is read from `process.env` at call time by
   `buildSopClient`/the skills trigger-client factory and passed to an HTTP
   client, never printed). **Pass.**
2. **Scope guard** — thin CI wrapper, not a framework/optimizer/registry/hosted
   service. **Gate check**: this mission adds inputs, an output, and
   documentation; it does not add a container build, a bundled model client, or
   any component that outlives the calling job. **Pass.**
3. **ATDD-first test discipline** — a failing acceptance test committed as its
   own first commit, RED-verified on the mission's `base_commit`. **Gate
   check**: this plan's Implementation Concern Map (below) and the eventual
   `/spec-kitty.tasks` decomposition must preserve one RED commit per IC before
   its GREEN commit; this plan does not itself violate the gate (no code is
   written at plan phase) but records the obligation for the tasks/implement
   phases. **Carried forward, not yet satisfied** (nothing to satisfy until
   implementation begins).

No violations requiring the Complexity Tracking table below to record an
exception.

## Component / Data-Flow Design

This is the concrete mechanism, not the principle, per the operator's brief.

```
                    ┌─────────────────────────────────────────────┐
                    │  action.yml inputs                           │
                    │  model-endpoint / model / api-key            │
                    │  (new; defaults '', mirrors endpoint/token)   │
                    └───────────────────┬───────────────────────────┘
                                        │ env: mapping (action.yml "Run muster" step)
                                        ▼
                    MUSTER_ENDPOINT / MUSTER_MODEL / MUSTER_API_KEY
                    (raw, possibly empty strings, in the step's env)
                                        │
                                        ▼
                    ┌─────────────────────────────────────────────┐
                    │  scripts/run.sh guard block (extended)       │
                    │  [ -z "$MUSTER_ENDPOINT" ] && unset ...      │
                    │  [ -z "$MUSTER_MODEL"    ] && unset ...      │
                    │  [ -z "$MUSTER_API_KEY"  ] && unset ...      │
                    │  (empty -> ABSENT, not "")                    │
                    └───────────────────┬───────────────────────────┘
                                        │ subprocess env inheritance
                                        ▼
                    npx -y "$PKG" ${MA_COMMAND} ${MA_ARGS}
                    (muster CLI process; PKG/version handling below
                    has its own implementability finding — see Decision D1)
                                        │
                     ┌──────────────────┼───────────────────────────┐
                     │ stdout+stderr    │                           │ process exit code
                     ▼                  │                           ▼
              tee'd to $OUT       (existing: printed to the       0 / 1 / 2
              (mktemp file)        Actions log unconditionally)   (muster's own
                     │                                             contract, unchanged)
                     │ FR-004: NO LONGER DELETED —                  │
                     │ survives to step end                         │
                     ▼                                              ▼
        ┌───────────────────────────┐                 ┌─────────────────────────────┐
        │ outputs.report-file        │                 │ case "$CODE" in              │
        │ = absolute path to $OUT    │                 │   0) skip-vs-passed via grep  │
        │ (new output)                │                 │      for /skip/i in $OUT     │
        └──────────────┬─────────────┘                 │   1) RESULT="failed"          │
                       │                                 │   *) RESULT="errored"         │
                       │                                 │ esac                          │
                       │                                 └──────────────┬────────────────┘
                       │                                                 │
                       │                                                 ▼
                       │                                  outputs.exit-code / outputs.result
                       │                                  (existing outputs, unchanged shape)
                       ▼                                                 │
        ┌─────────────────────────────────────────────────────────────────────────────┐
        │  DOWNSTREAM STEP (same job) — the exit-code-ambiguity resolution point       │
        │                                                                               │
        │  test -s "$report_file"                     # FR-004: file must exist/be non-│
        │                                              # empty; this alone proves the  │
        │                                              # step didn't silently vanish it│
        │                                                                               │
        │  command grep -qx '  [PASS] <ordinary-id>' "$report_file"   \                 │
        │    && command grep -qx '  [FAIL] <control-id>' "$report_file"                 │
        │                                                                               │
        │  This is the ONLY point in the whole pipeline that can tell the three        │
        │  cases apart:                                                                 │
        │    - real conformance problem in a *different* case: ordinary marker is       │
        │      [FAIL] too, or missing -> conjunction fails -> correctly flagged         │
        │    - network/endpoint was down: BOTH markers read [FAIL] (the ordinary case   │
        │      also errored) -> conjunction fails -> correctly flagged, NOT silently    │
        │      green, even though the aggregate exit-code/result alone (1/"failed")     │
        │      looks identical to "everything worked, control fired correctly"          │
        │    - everything worked: ordinary=[PASS], control=[FAIL] -> conjunction        │
        │      passes -> the ONLY case this check accepts                               │
        │                                                                               │
        │  The aggregate exit-code/result output is necessary (job-level gating,        │
        │  FR-005) but NOT sufficient for User Story 3 — report-file + anchored         │
        │  per-case markers is the only artifact with enough resolution to express      │
        │  "one case passed AND a different case failed," which is exactly the          │
        │  conjunction muster#76 proved a bare `result == 'failed'` check cannot.       │
        └─────────────────────────────────────────────────────────────────────────────┘
```

**Where the exit code is interpreted**: `scripts/run.sh`'s `case "$CODE" in
...` block (existing, unchanged in shape — 0/1/2 map to
skipped-or-passed/failed/errored). **Where the report file overrides/refines
that**: a *downstream* step in the same job (new; documented in the example
workflow, FR-003) that greps the anchored markers. The aggregate output is
never overridden in the sense of being changed — it is *supplemented*: the job
can still `fail-on: error` on the aggregate (catches "some case failed," which
is what CI needs for the common path), while the *separate* assertion step is
the only thing that can prove the control genuinely fired versus merely
riding along on a dead endpoint.

## Per-FR Verification, Command, Expected Exit Code, and Falsification Condition

Extending the spec's own table with the falsification column the operator
asked for explicitly — the concrete input that *makes the check fail*, not
just what makes it pass.

| FR | Verification command | Expected | Falsification condition (what must make this fail) |
|----|---|---|---|
| FR-001 | Guard snippet + `tests/fixtures` integration case; `env \| grep -c MUSTER_ENDPOINT` inside the run step | `0` when input empty, present with exact value when non-empty | Ship the guard for `MUSTER_ENDPOINT`/`MODEL` but forget `MUSTER_API_KEY` (partial triple) — the fixture must assert all three independently, not just one, or a partial-unset regression passes silently |
| FR-002 | `command grep -n 'MUSTER_API_KEY' scripts/run.sh`; `command grep -c "$FAKE_KEY_VALUE" "$OUT"` post-run | Zero argv-line matches; zero value matches in captured output | Interpolate `${MUSTER_API_KEY}` into the `MA_ARGS`/`npx` invocation line — the grep must be scoped to the exact invocation line (not the whole file) or a key that merely appears in a *comment* would falsely pass the file-wide grep while the real leak (argv) goes undetected |
| FR-003 | Run the example behavioral job against a healthy stub and a dead stub (User Story 3) | Assertion passes on healthy, fails on dead | A conjunction check that only asserts the control's own polarity (`result=='failed'` alone, muster#76's shape) — must fail this plan's own review, since it is satisfiable by a dead endpoint alone |
| FR-004 | `test -s "${{ steps.muster.outputs.report-file }}"`; anchored `grep -x` for both markers | File exists, non-empty, both markers independently greppable | Use a bare substring `grep` instead of `-x`/anchored — must fail against a manifest where one case ID is a literal substring of another (`case-1` vs `case-1-control`), which is exactly the false-conjunction risk C-005/FR-004 exist to close |
| FR-005(a) | `test.yml` matrix case, all three empty | `skipped`/`0` | Any of the three BYOM vars leaking through non-empty when the input is empty — same falsification as FR-001, at the whole-action-invocation level |
| FR-005(b) | `test.yml` matrix case, `model-endpoint=http://127.0.0.1:9`, others empty | `failed`/`1` | The step reporting `skipped`/`0` (silent-green) or `errored`/`2` (miscoded failure class) — both are the exact defect this mission exists to prevent |
| FR-005(c) | `test.yml` matrix case, `model-endpoint` set, `api-key` empty, `OPENAI_API_KEY` absent from runner env | `failed`/`1` (see spec-correction note below — **not** `errored`/`2`) | Same collapse risks as (b); additionally, this case is the one that most needs the per-run containment path (`runBehavioralSkillCaseSafe`/SOP per-probe try/catch) to actually be reached — a regression that made a missing key throw before reaching that containment would flip this to `2`, which the test must catch |
| FR-005(d) | `test.yml` matrix case, deliberately unparseable manifest, `model-endpoint` set | `errored`/`2` | The manifest-read try/catch (`doSkillsRun`'s own, throwing `ExecutionError`) being bypassed or the fixture accidentally being *parseable* (e.g., valid YAML with a merely-unexpected shape that the schema validator still accepts) — must produce a genuine parse/validation failure, not just an unusual-but-valid manifest |
| FR-006 | `command grep -n 'runsErrored\|GITHUB_STEP_SUMMARY' README.md examples/*.yml` | Pattern documented with a concrete snippet | README documents the pattern only in prose without a literal snippet a consumer can copy — the grep target (`runsErrored`, `GITHUB_STEP_SUMMARY`) must appear in actual example code, not only in narrative text |

**Fixture-design note (not a spec defect, an implementation recommendation
carried to tasks)**: FR-005(d)'s manifest is described as "unreadable/
unparseable." Recommend the fixture be a **malformed-YAML file** (guaranteed,
portable parse failure) rather than a chmod-based "unreadable" file —
GitHub-hosted runners execute as a non-root user where `chmod 000` behavior is
usually reliable, but git does not reliably preserve restrictive permission
bits across clone/checkout, and container-based runners occasionally run
differently-privileged processes. A malformed-YAML fixture reaches the exact
same `doSkillsRun` try/catch deterministically regardless of runner identity
or git's permission-bit handling.

## Spec Corrections Found During Planning (not re-litigating D1-D4; these are new)

Per the operator's instruction that "being agreeable about a mistaken premise
is a defect," two concrete issues were found in `spec.md` itself while
grounding this plan in the actual source and actual npm/npx behavior:

### 1. Edge Cases section contradicts FR-005(c) for the identical scenario

`spec.md`'s **Edge Cases** section states: *"`model-endpoint` set, `api-key`
absent, and `OPENAI_API_KEY` also absent... must surface as `errored`/exit 2,
not `skipped`."* But `spec.md`'s own **FR-005(c)** states the same scenario
(`model-endpoint` set, `api-key` empty, `OPENAI_API_KEY` absent) resolves to
**`failed`/exit `1`** via the per-run containment path — the corrected
behavior from the mission's own post-spec adversarial review.

Re-verified directly against source for this plan: `buildSopClient()`
(`src/cli/index.ts:1615-1629`) returns a real client whenever `MUSTER_ENDPOINT`
is non-empty — it does **not** check whether the resolved `apiKeyEnv` variable
is actually populated, and does not return `undefined` for a missing key. The
same is true of `resolveSkillsBehavioralEndpoint` (returns an `EndpointConfig`
once `baseUrl` resolves, independent of key presence). Either adapter then
attempts a real (or failing) HTTP call with an effectively-empty
Authorization value, and that call's failure (401, connection-refused,
whatever the dead-or-misconfigured endpoint returns) is caught by the same
per-run/per-probe containment already established for FR-005(b) — never by
the top-level `ExecutionError`/exit-2 path. **FR-005(c)'s claim (exit `1`) is
correct and matches source; the Edge Cases bullet is stale** — it was written
before the mission's own "Post-Spec Review Corrections" pass, and that pass's
own text names exactly which sections it fixed ("FR-005, C-002, SC-003, and
User Story 2 Scenario 2 below reflect the corrected behavior") — the Edge
Cases section is not in that list. This is the same class of near-miss the
spec's own "Anticipated Work-Package Lanes" section already flagged once
(the `docs/spec.md` dependency omission) recurring a second time, inside the
same document, in the section meant to prevent exactly this kind of drift.
**Recommendation**: fix the Edge Cases bullet to read `failed`/exit `1`
before `/spec-kitty.tasks` runs, so a task-writer does not build a test
fixture against the stale claim. This plan treats exit `1` as authoritative
for FR-005(c) (matching FR-005's own row and the source), not the Edge Cases
wording.

### 2. Decision D1's exact-SHA pin mechanism does not work as literally described — empirically verified

D1 recommends pinning the mission's own example/validation workflow to the
exact commit `a46148b969b28be4ada8fb3ba2045c77d8b97217` "via a git-spec
reference (e.g. `npx github:garrison-hq/muster#a46148b...`)." This was tested
directly (Node 22.22.2 / npm 10.9.7 — the same versions `action.yml`'s own
`setup-node@22` step would provision):

- `npx -y '@garrison-hq/muster@github:garrison-hq/muster#a46148b...' --version`
  → `npm error GitFetcher requires an Arborist constructor to pack a tarball`
- `npx -y 'github:garrison-hq/muster#a46148b...' --version` (unaliased) → same error
- `npx -y --package='github:garrison-hq/muster#a46148b...' -- muster --version` → same error

This is a real, reproducible npm/npx limitation (npx's single-shot install
path does not correctly pack a git-fetched tarball), not a typo in the pinned
SHA. A workaround exists — plain `npm install --no-save
'github:garrison-hq/muster#a46148b...'` (bypassing `npx`'s install path)
succeeds — but the installed package is **source-only**: `muster`'s
`package.json` has a `build` script (`tsc && ...`) but **no `prepare` or
`postinstall` hook**, so a git-dependency install never runs it. `dist/`
(and therefore `dist/cli/index.js`, the declared `bin` entry) does not exist
after install; the `muster` command cannot run at all through this path either,
without an explicit extra build step.

**Consequence for this plan**: `action.yml`'s existing `version` input /
`scripts/run.sh`'s `PKG="@garrison-hq/muster@${VERSION}"` construction cannot
be used to exercise the pinned SHA at all — neither through `npx` (broken) nor
by merely changing the `version` value (still routes through the same broken
`npx` call, and even if it didn't, ships no build output). **This plan adopts
a corrected mechanism**: the mission's own example/validation workflow job(s)
that need the pinned SHA's actual runtime behavior (FR-003's User Story 3
conjunction, FR-005's b/c/d matrix) check out `garrison-hq/muster` at that SHA
in a preceding step, run `npm ci && npm run build`, and invoke
`node dist/cli/index.js <command> <args>` **directly** — bypassing
`muster-action`'s own `version`/`npx` mechanism for those specific validation
jobs only. This does not change the *pin* (still the exact SHA, still
labeled pre-release with a removal tracker per D1) — it changes how that
pinned build is *reached*, because the originally-proposed mechanism cannot
reach it at all. The parts of the test matrix that only need to prove
env-wiring (FR-001/FR-002, "does the action correctly set/unset the three
env vars") do **not** need real muster or this workaround — a lightweight
stub script fixture suffices for those, and should stay on the ordinary
`version`/`npx` path since it never needs the pinned SHA's actual behavior.

### 2a. Update (implementation time, 2026-07-31): Risk #4 materialized — the checkout-and-build workaround above is superseded

Risk #4 in this plan's own Premortem table named this exact possibility:
*"muster's `main` gate (PR #83) merges and cuts a release between this plan
and implementation, making D1's 'not in any release' premise stale... 
re-check `npm view @garrison-hq/muster versions` and PR #83's CI status at
`/spec-kitty.tasks` time; if it has shipped, D1 should be revisited before
task generation, not silently carried forward."` That re-check did not happen
before `/spec-kitty.tasks` ran (WP03/WP04 were cut with the checkout-and-build
mechanism from Correction #2 above still in them). Re-verified now, directly,
before WP01 implementation begins:

- `npm view @garrison-hq/muster versions` → `..., "1.1.0", "1.2.0"` — `1.2.0`
  is published.
- `npm view @garrison-hq/muster@1.2.0 gitHead` →
  `b5d6214f559b7c322e7238d267045c05a4b54f84` — matches `garrison-hq/muster`'s
  `main` tip after PR #83 merged (`git log -1 v1.2.0` on the muster checkout
  confirms the same SHA and subject "fix(security): remove ReDoS-prone
  regexes; clear SonarCloud new-code gate (#83)").
- `git merge-base --is-ancestor a46148b969b28be4ada8fb3ba2045c77d8b97217 v1.2.0`
  → true (exit `0`) — M5 is an ancestor of the released tag, not merely
  claimed by version-number proximity.
- `npm pack @garrison-hq/muster@1.2.0` and inspecting the tarball directly
  (not just registry metadata) shows `dist/adapters/skills/{trigger,validate,
  schema}.js` and `dist/cli/index.js` (the declared `bin` entry) already
  present — the published package ships a prebuilt `dist/`, so no `npm ci &&
  npm run build` step is needed to run it, unlike the git-spec-reference path
  Correction #2 found broken.

**Consequence**: the checkout-`a46148b`-and-build-and-invoke-`node
dist/cli/index.js`-directly mechanism (Correction #2's fix) is no longer the
correct design. Replace it, everywhere WP03/WP04 currently reference it, with
a plain `with: version: '1.2.0'` input on the composite action's existing
`version` input, run through the ordinary `npx -y "@garrison-hq/muster@${VERSION}"`
path (`scripts/run.sh:20`, unchanged) — the ordinary path *now* reaches real
M5 behavior because a real release contains it. This is strictly simpler than
Correction #2's workaround (no `actions/checkout` of a second repo, no build
step, no bypassing this action's own `version`/`npx` mechanism) and remains
reproducible (an exact version number, not a floating range — see the note
below on why the *default* range is insufficient for this purpose despite
technically also resolving to `1.2.0` today).

**Does this fully resolve WP04's "cases (a)/(b)/(c) are vacuous against the
default version" finding (post-tasks review, Fixed-after-post-tasks-review
item 1 in `tasks/WP04-*.md`)?** Yes, with one caveat worth recording: `npm
install --no-save '@garrison-hq/muster@^1.1.0'` (the action's actual default
range) was verified during this re-check to *already* resolve to `1.2.0`
today, purely because npm's range resolution always picks the highest
satisfying published version — so the default is, as of today, no longer
vacuous either. That is an incidental fact about the registry's current
state, not a designed guarantee: a future `1.3.0` release could regress or
change behavior, and this test matrix's own correctness must not depend on
"whatever the floating range happens to resolve to right now." **WP04's
cases (a)/(b)/(c) still require an explicit `version: '1.2.0'` pin** (not
reliance on the default), for reproducibility — this is a stricter, not a
weaker, requirement than what Correction #2 originally shipped, just reached
through the much simpler mechanism above.

## Fork-PR Path Confirmation

Per the operator's explicit check: `secrets.MODEL_API_KEY`-shaped references
resolve to `''` on a fork PR (GitHub's own behavior, not something this action
controls) — never an error, never a skipped step at the GitHub level. Given
FR-001's guard unsets on empty, this collapses automatically into the
all-empty path: all three BYOM vars absent, muster's own resolvers return
`undefined`, cases report `skipped`, exit `0`. **This is confirmed the
intended behavior for fork PRs** (User Story 2 Scenario 1, SC-002) and it
**cannot** mask a configured-but-broken endpoint, because the two conditions
are mutually exclusive by construction: "configured" means `model-endpoint`
resolved to a non-empty value (which is exactly what makes the guard *not*
unset it), and "all-empty skip" only happens when it did resolve empty. There
is no code path where a non-empty, broken endpoint is silently treated as
absent.

**This plan does not touch `pull_request_target`.** NFR-002 is satisfied by
omission — no workflow shipped by this mission uses it, and none is proposed.
Confirmed by design, not merely by grep: the mission's recommended pattern
(job-level `if: ${{ secrets.MUSTER_API_KEY != '' }}`-style guard, `schedule`/
`workflow_dispatch` triggers on the repo's own refs) has no reason to reach for
elevated-trust event types, since it never needs to run against fork-PR-authored
code with secrets in scope.

## ATDD-First Test Strategy (mission constraint, carried by charter Directive 3)

Since this repo had no charter before this mission, the ATDD-first discipline
is stated here as a plan-level constraint that the hand-authored charter now
also carries forward permanently (not just for this mission):

- Each Implementation Concern below (IC-01..IC-04) corresponds to one
  acceptance-test-first commit boundary: the failing `test.yml` case (or
  README/example assertion) is committed **before** the `action.yml`/
  `scripts/run.sh`/`README.md`/`examples/conformance.yml` change that makes
  it pass.
- The reviewer's obligation: check out the RED commit on the WP's declared
  `base_commit`, run the new/changed job, and confirm it fails **for the
  reason the FR describes** (e.g., FR-005(b)'s RED commit should fail because
  the guard doesn't yet exist / the assertion doesn't yet exist — not because
  of an unrelated YAML syntax error in the test fixture).
- This mission's single-lane shape (see below) means ATDD commits land
  sequentially inside one lane's history, not as separate lanes' RED commits
  racing each other — simpler to verify than a multi-lane mission, but still
  mandatory per-IC, not collapsed into one giant RED commit for the whole
  mission (which would make "RED for the right reason" unverifiable).

## Evidence-Artefact Template (FR-006, Decision D4)

Per D4 (accepted): `muster-action` ships the **template only** — the SK
fork's own reusable workflow (out of bounds for this mission) is responsible
for actually executing a live gate and committing the resulting evidence.
Formalizing "per-axis rates, `runsErrored`, model, endpoint host, timestamp"
into a concrete schema so a downstream consumer has something to literally
copy, not just a description:

```json
{
  "schema": "muster-action/evidence-artefact/v1",
  "generatedAt": "2026-07-31T00:00:00Z",
  "model": "gpt-4o-mini",
  "endpointHost": "api.example-inference-host.com",
  "runsErrored": 0,
  "axes": [
    { "axis": "verbosity", "casesTotal": 12, "casesPassed": 11, "passRate": 0.9167 },
    { "axis": "refusal",   "casesTotal": 8,  "casesPassed": 8,  "passRate": 1.0 }
  ],
  "controlCasesFired": true
}
```

Rules this template documents (in README, per FR-006's own verification
command grepping for `runsErrored`/`GITHUB_STEP_SUMMARY`):

- `endpointHost` is a **hostname only** (`new URL(endpoint).host`-shape
  extraction) — never the full URL if it embeds credentials, never the key.
- `runsErrored` is the count of cases whose `errored: true` (network/execution
  containment fired), reported **separately** from `casesPassed`/`casesTotal`
  — collapsing errored cases into "failed" silently would re-introduce
  muster#76's ambiguity at the evidence-artefact layer instead of the CI-YAML
  layer.
- `controlCasesFired`: boolean, true only if every discrimination control's
  companion conjunction check (this mission's FR-003/FR-004 mechanism) passed
  — an evidence artefact making a "the model is compliant" claim without this
  field, or with it silently omitted, is not trustworthy per this mission's
  own reasoning.
- Written to `$GITHUB_STEP_SUMMARY` for human visibility and/or committed as
  a workflow artifact for auditability — this mission documents both,
  execution is the consumer's responsibility (D4).

## Project Structure

### Documentation (this mission)

```
kitty-specs/muster-action-behavioral-env-01KYTP0Z/
├── plan.md              # This file
├── checklists/requirements.md   # Already present (specify phase)
└── tasks/                # NOT populated by this plan — /spec-kitty.tasks territory
```

No `research.md`/`data-model.md`/`contracts/`/`quickstart.md` are generated as
separate files for this mission: the spec's own Normative Citations Index
already carries the "research" this mission needed (direct source citations,
independently re-verified by the post-spec squad), and there are no new
entities/API contracts in the traditional sense — this repo has no domain
model of its own to model. The Component/Data-Flow Design and Evidence-Artefact
Template sections above serve the role `data-model.md`/`contracts/` would play
for a mission with real entities.

### Source (repository root) — files this mission's single lane touches

```
action.yml                       # new inputs (model-endpoint/model/api-key), new output (report-file)
scripts/run.sh                   # guard-block extension, report-file retention, argv-safety unchanged
scripts/wait-health.sh           # unchanged; cited only for edge-case interaction (health-url timeout)
README.md                        # new inputs/outputs documented; fork-PR guidance; evidence-artefact pattern
examples/conformance.yml         # behavioral job (schedule/workflow_dispatch), control-inversion example
.github/workflows/test.yml       # FR-005's four-case BYOM matrix extension
docs/spec.md                     # D1/D5/scope-guard citations already point here — must stay in sync
tests/fixtures/*                 # new: dead-endpoint-shaped manifest, malformed-manifest fixture, control-manifest
```

**Structure Decision**: single project, no new top-level directories. This
matches the spec's own "Anticipated Work-Package Lanes" guidance exactly — a
~450-line coupled surface, one lane, sequenced ICs rather than parallel ones.

## Complexity Tracking

*Empty — no charter violations to justify.* The one thing that could have
appeared here (the exact-SHA pin being "pre-release"/non-standard) is already
accepted and bounded by Decision D1 itself, with an explicit removal tracker,
not an unbounded exception.

## Implementation Concern Map

Single lane (confirmed, not re-litigated): `action.yml` + `scripts/run.sh` +
`README.md` + `examples/conformance.yml` + `.github/workflows/test.yml` +
`docs/spec.md` + `tests/fixtures/*` are one coupled surface. The four concerns
below are **sequenced**, not parallelizable — IC-02 is a hard dependency of
IC-03 and IC-04, exactly as the spec's own lane guidance states (this plan
does not reopen that; it makes the sequencing explicit for `/spec-kitty.tasks`
to consume).

> Per the operator's lane-design hazards: when `/spec-kitty.tasks`
> materializes work packages from these concerns, every WP's `dependencies`
> must be checked by a **mechanical walk** of every path referenced by that
> WP's own acceptance commands (not just the files it edits) — this spec
> already names `docs/spec.md` as a near-miss found only during post-spec
> review, and NFR-002's own verification command greps `examples/`, `docs/`,
> and `README.md` together, so a WP whose acceptance test runs NFR-002's grep
> must declare all three as dependencies even if its own edits only touch one
> of them. This mechanical check is a `tasks-finalize` gate requirement, not a
> plan-phase artifact — recorded here so it is not dropped between this
> document and that step.

### IC-01 — BYOM input surface + empty-unset guard

- **Purpose**: Add `model-endpoint`/`model`/`api-key` inputs, map them to
  `MUSTER_ENDPOINT`/`MUSTER_MODEL`/`MUSTER_API_KEY`, extend the existing
  empty-unset guard block to cover all three, and confirm the credential
  (`api-key`) never reaches argv or a log (FR-002, C-003, C-004, charter
  Directive 1).
- **Relevant requirements**: FR-001, FR-002, C-001, C-003, C-004.
- **Affected surfaces**: `action.yml` (inputs + `env:` mapping),
  `scripts/run.sh` (guard block extension only — the existing argv-
  construction line at `scripts/run.sh:20` is explicitly NOT touched, per
  FR-002's own verification command).
- **Sequencing/depends-on**: none — this is the foundation the other three
  concerns build on.
- **Risks**: A guard that unsets only `MUSTER_ENDPOINT` and forgets `MODEL`/
  `API_KEY` (partial-triple regression) — mitigated by FR-001's falsification
  condition above requiring all three to be asserted independently, not as
  one combined grep.

### IC-02 — `report-file` output + anchored per-case markers

- **Purpose**: Stop deleting the captured report, expose its path as a new
  `report-file` output, and confirm the anchored-grep marker shape
  (`  [PASS]`/`  [FAIL]` exact-line match) actually matches
  `formatSkillsResultHuman`'s real output shape — this is the single
  mechanism that makes User Story 3's conjunction check possible at all.
- **Relevant requirements**: FR-004, NFR-003.
- **Affected surfaces**: `scripts/run.sh` (remove the unconditional `rm -f
  "$OUT"`; add the `report-file` line to `$GITHUB_OUTPUT`), `action.yml`
  (new output declaration).
- **Sequencing/depends-on**: IC-01 (shares the same `run.sh` guard-block
  region; sequencing avoids two concerns editing overlapping lines out of
  order).
- **Risks**: This is the one identified as a **single control** in the
  operator's brief — fixture, assertion, and the dead-endpoint falsification
  test must be owned by one WP, not split across three, or a control could
  ship pinned by fixture construction (the exact failure mode the brief
  names as already having happened on a sibling mission). This concern's
  future WP must carry all three together.

### IC-03 — Example workflow: behavioral job + scoped control-inversion conjunction

- **Purpose**: Extend `examples/conformance.yml` with the schedule/dispatch
  behavioral job (fork-PR-safe by construction, no `pull_request_target`),
  and the skills-only control-inversion conjunction pattern (C-005 scoping
  respected — never applied to an a2a `control:` manifest).
- **Relevant requirements**: FR-003, C-005, NFR-001, NFR-002.
- **Affected surfaces**: `examples/conformance.yml`, `README.md` (fork-PR
  guidance, job-level `if:` guard recommendation), `docs/spec.md` (scope-guard
  citation currency).
- **Sequencing/depends-on**: IC-02 (hard dependency — the conjunction
  assertion step reads `steps.muster.outputs.report-file`, which does not
  exist until IC-02 lands). Also depends on the version-pin design (Spec
  Correction #2, superseded by #2a — a plain `version: '1.2.0'` input pin,
  not the checkout-and-build workaround) being resolved in this IC's own
  acceptance design, since this is the concern whose negative-path job needs
  the pinned M5 behavior to actually run.
- **Risks**: Applying the conjunction pattern to an a2a manifest by mistake
  (C-005's exact hazard) — mitigated by this IC's acceptance test asserting
  the example workflow's inversion step targets a skills manifest by
  construction (fixture-level guarantee, not just a comment).

### IC-04 — Integration test matrix (FR-005) including the mandated negative-path run

- **Purpose**: Extend `.github/workflows/test.yml` with the four BYOM-triple
  cases, of which (b) and (c) are the operator's explicitly mandated
  **negative-path run that must be observed failing** — a job with the
  endpoint configured but broken, asserted to fail, not skip.
- **Relevant requirements**: FR-005 (a/b/c/d), C-002, SC-003.
- **Affected surfaces**: `.github/workflows/test.yml`, `tests/fixtures/*`
  (dead-endpoint-shaped manifest reused from IC-02/IC-03's fixtures where
  possible; a dedicated malformed-YAML fixture for case (d), per the
  fixture-design note above).
- **Sequencing/depends-on**: IC-01 (env-wiring must exist), IC-02
  (report-file needed if any of these cases also want per-case marker
  assertions, though the four FR-005 cases as specified only need the
  aggregate `result`/`exit-code` outputs, which already exist — noted so a
  future task-writer doesn't assume report-file is required here when it
  is not).
- **Risks**: The single highest-value risk in this whole mission — a
  workflow step that "runs, prints, and exits 0 regardless" (the operator's
  own framing). Mitigated structurally: case (b)'s and (c)'s assertions
  check for `failed`/`1` explicitly (not merely "not skipped"), so a
  regression to silent-`0` fails the assertion, not just the intent.

## Risks (Premortem)

Assuming this mission has already shipped and gone wrong — the concrete ways
it could have failed, ranked by impact and likelihood, each with a mitigation
or an accepted risk:

| # | Failure scenario | Impact | Likelihood | Mitigation / accepted risk |
|---|---|---|---|---|
| 1 | The exact-SHA pin mechanism (D1) ships as literally described in spec.md (`npx github:...`) and silently never runs — the example/validation workflow's behavioral job always hits the `npx` GitFetcher error, which is *itself* a non-zero exit, so the job "fails" but for the wrong reason (tooling breakage, not a real conformance signal), and nobody notices because "the job failed" looks like the mandated negative-path win | High — the mission's entire proof that its own example works would be an accidental true-negative for the wrong reason | Confirmed already happening if unaddressed (empirically reproduced above) | **Mitigated in this plan**: Spec Correction #2 replaces the mechanism with a direct source-checkout-and-build step for the SHA-dependent jobs specifically; this must be verified working (not just written) as part of IC-03/IC-04's own ATDD RED→GREEN cycle |
| 2 | A future WP's `dependencies` list omits `docs/spec.md` (already almost happened once inside this spec itself) | Medium — a worktree turns up missing a file mid-implementation, costing a review cycle | Medium (recurring pattern per the operator's brief) | Mechanical dependency-walk gate at `tasks-finalize`, stated explicitly in the Implementation Concern Map section above so it survives into `/spec-kitty.tasks` |
| 3 | IC-02's control-case mechanism gets split across multiple WPs at tasks time (fixture in one, assertion in another, falsification test in a third) | High — this is the exact way the operator says a control shipped "pinned by fixture construction" on a prior mission | Medium | This plan explicitly states IC-02 (and its extension into IC-03) is one WP's object, not three, in both the IC description and this risk table — redundant on purpose |
| 4 | muster's `main` gate (PR #83) merges and cuts a release between this plan and implementation, making D1's "not in any release" premise stale | Low-medium — would not break anything, but would leave the mission recommending a pin that's no longer necessary | **Materialized** — PR #83 merged, `1.2.0` published containing M5, confirmed at implementation time (2026-07-31, before WP01 implementation began) | **Resolved, not merely accepted**: re-check performed at implementation time since it was not performed at `/spec-kitty.tasks` time as this row recommended; see "Spec Corrections Found During Planning #2a" above — the checkout-and-build workaround is superseded by a plain `version: '1.2.0'` pin on the existing input; `spec.md`'s D1 and `tasks/WP03-*.md`/`tasks/WP04-*.md` updated accordingly |
| 5 | The `charter.yaml`/`config.yaml` pointer mismatch (charter.md exists, `config.yaml` still points at a non-existent `charter.yaml`) causes a future charter-aware command to behave unexpectedly (beyond the already-reproduced `CHARTER_PACK_CONFIG_INVALID`) | Medium | High (already reproduced) | Flagged explicitly in the Charter Check section and the Tooling Note; explicitly an operator decision, not something this plan resolves by guessing at `config.yaml`'s schema |
| 6 | The Edge Cases/FR-005(c) contradiction (Spec Correction #1) is missed by a task-writer who reads only the Edge Cases section | Medium — a task/fixture gets built against exit `2` for a scenario that actually produces exit `1`, and its own acceptance test would then fail against real muster, discovered only late | Low once flagged here, since it's now written down twice (spec.md needs a one-line fix, and this plan states the correct value) | This plan treats FR-005(c)'s value (exit `1`) as authoritative; recommend the one-line spec.md fix before/alongside `/spec-kitty.tasks` |

## Handoff

- **Next command**: `/spec-kitty.tasks`, run explicitly by the operator (not
  automatically continued from here, per this command's own stop rule).
- **What `/spec-kitty.tasks` inherits from this plan**: the four sequenced
  ICs (single lane, IC-02 as the hard dependency of IC-03/IC-04), the
  falsification conditions per FR (so each WP's acceptance test has a
  concrete "what would make this wrong" check built in from the start, not
  discovered during review), the corrected exit-code values (FR-005(c) = 1,
  not the stale Edge Cases claim), and the version-pin design — **superseded
  at implementation time (see "Spec Corrections Found During Planning #2a")**:
  originally the exact-SHA-pin workaround (source checkout + build, not `npx`
  git-spec), now a plain `version: '1.2.0'` input pin against the real
  published release, since `1.2.0` shipped before implementation began.
- **What still needs an operator decision before/alongside tasks**: (1) the
  `CHARTER_PACK_CONFIG_INVALID` tooling blocker (Tooling Note), (2) the
  `config.yaml` → `charter.yaml` pointer mismatch, (3) the one-line spec.md
  fix for the Edge Cases/FR-005(c) contradiction, (4) re-confirming muster PR
  #83's status hasn't changed the D1 premise by the time tasks are cut.

## Open Questions Carried Forward

None marked `[NEEDS CLARIFICATION]` — every material question surfaced during
this plan was either resolved with a concrete design decision (the SHA-pin
mechanism) or handed to the operator as an explicit above-the-line action item
(charter tooling, spec corrections), consistent with the mission's own prior
practice of resolving opens into decisions-with-recommendations rather than
deferring them.
