# Mission Specification: muster-action behavioral env inputs

**Mission Branch**: `kitty/mission-muster-action-behavioral-env`
**Mission Slug**: `muster-action-behavioral-env-01KYTP0Z`
**Created**: 2026-07-30
**Status**: Draft
**Input**: garrison-hq/muster-action#2 ("[M8] muster-action-behavioral-env — supported behavioral env inputs + CI control-inversion patterns"), verified against garrison-hq/muster-action@b40681a and garrison-hq/muster@a46148b969b28be4ada8fb3ba2045c77d8b97217 (current `origin/main` tip at specify time).

## Domain Language

- **A2A behavioral pair** (`MUSTER_A2A_ENDPOINT` / `MUSTER_A2A_TOKEN`): the existing env vars this action already wires for the `a2a run` command (`action.yml:88-89`). Out of scope for this mission — untouched.
- **BYOM behavioral triple** (`MUSTER_ENDPOINT` / `MUSTER_MODEL` / `MUSTER_API_KEY`): the *separate* env-var family read by muster's `skills run`, `sop run`, `crosslayer run`, and `memory-utilization run` adapters (muster `.env.example:4-6,15,18,26`). This mission adds a supported input surface for this triple. Do not conflate it with the A2A pair — they are different variables read by different adapters, and a consumer workflow may need both simultaneously.
- **Discrimination control** / **control case**: a manifest case (`isControl: true` in skills manifests, `control: true` in a2a manifests) engineered so that a *correctly working* grader makes it fail — its purpose is to prove the grader can still fail at all. See muster#77 for why the two adapters treat this oppositely.
- **base-url-compat**: a shim proposed in the source issue to also export the deprecated `MUSTER_BASE_URL` alias. See Decision D2 below — this mission does **not** adopt it as scoped in the issue.

## Context & Verified Facts (specify-time)

All verified directly against the live repositories/registries, not taken on the issue's word:

1. **muster's `origin/main` tip is `a46148b969b28be4ada8fb3ba2045c77d8b97217`** — confirmed by `git fetch origin main && git rev-parse origin/main`. This is M5's own commit (`feat(skills): behavioral trigger conformance...`), i.e. the skills-behavioral-enablement work this mission depends on is already the tip of main, not a future commit.
2. **muster's `main` CI is red on the SonarCloud quality gate for three consecutive pushes**, each followed by a `skipped` `Release` run — confirmed via `gh run list --repo garrison-hq/muster --branch main` (runs `30588191684`/2026-07-30, `30297326411` and `30294760408`/2026-07-27) and by pulling the failing job's log (`22:47:17.050 ERROR QUALITY GATE STATUS: FAILED`).
3. **npm's published `@garrison-hq/muster` stops at `1.1.0`** (`npm view @garrison-hq/muster versions`), last modified 2026-06-20 — confirmed. `git merge-base --is-ancestor a46148b969b28be4ada8fb3ba2045c77d8b97217 v1.1.0` returns **false** — M5 (and the skills-behavioral env surface this mission targets) is provably **not** in any published release.
4. **muster-action's composite steps already inherit the calling job's environment** — `scripts/run.sh:20` runs `npx -y "$PKG" ${MA_COMMAND} ${MA_ARGS}` with no env sanitization, so a caller who sets `MUSTER_API_KEY` (or any of the BYOM triple) at job level already reaches the muster process today, with no input required. This confirms the issue's own "Correction #6" — the gap this mission closes is a **missing supported/guarded surface**, not a missing capability.
5. **The empty-must-be-unset pattern already exists, but only for the A2A pair**: `scripts/run.sh:9-10` (muster-action@b40681a). This mission's FR-001 mirrors it for the BYOM triple.
6. **muster's exit contract is 0 (pass/skip) / 1 (conformance failure) / 2 (internal/endpoint error)**, unchanged by this mission (`action.yml:53-59`, `docs/spec.md:28-31`).

## Corrections to Source Issue (garrison-hq/muster-action#2)

The issue is **not** treated as ground truth. Four claims in it are wrong or materially incomplete, verified against the actual source:

1. **Wrong citation.** FR-001 cites *"SOP: `buildSopClient` returns undefined on empty — `cli/index.ts:1377-1381`."* Lines 1377-1381 of `src/cli/index.ts`@`a46148b` are **not** `buildSopClient` — they are the `MUSTER_BASE_URL`-deprecation warning inside a *different* function, `resolveSkillsBehavioralEndpoint` (lines 1367-1389). The real `buildSopClient` is at **lines 1615-1629**, and does return `undefined` when `MUSTER_ENDPOINT` is empty (line 1617-1618) — but that is the **SOP** adapter's function, not the skills adapter's. The issue conflated two separate, adapter-specific "return undefined on absent endpoint" functions under one wrong line range. Corrected citations are used throughout this spec (see Normative Citations Index).
2. **FR-003's `base-url-compat` shim rests on a premise that doesn't hold for this mission's own target adapter.** The shim is framed as letting "pre-M5 muster versions run trigger suites" by also exporting the deprecated `MUSTER_BASE_URL` name. But M5's own issue (garrison-hq/muster#59) states the pre-M5 CLI "unconditionally records [skills behavioral cases] as skipped and never builds a client" (`src/cli/index.ts:1330-1334` pre-M5) — **regardless of which env var name is set**. There is no muster version that reads either `MUSTER_BASE_URL` or `MUSTER_ENDPOINT` to run skills-behavioral cases and predates M5; the shim bridges nothing for the skills use case this mission is built around. See Decision D2.
3. **FR-004's control-inversion pattern is stated as if it applies uniformly, but the two adapters are asymmetric (muster#77, independently re-verified below), and applying it uniformly breaks a2a.** `src/adapters/a2a/index.ts:356-371`@`a46148b` (`applyControlInversion`) explicitly flips a correctly-firing control's `passed` to `true` for a2a manifests. The skills adapter has no equivalent — `doSkillsRun`'s counting logic (`failed = nonSkipped.filter(r => !r.passed).length`) treats a correctly-firing `isControl` case as an ordinary failure, contributing to exit 1. Issue #2's "run with `fail-on: never`, assert `result == 'failed'`" pattern is *correct only for skills-adapter controls*. Applied to an a2a control manifest, the assertion would be backwards — muster's own a2a adapter has already flipped that case to `passed`, so the action's aggregate `result` would already read `'passed'`, not `'failed'`. This spec scopes the pattern explicitly (C-005).
4. **Even correctly scoped to skills, the pattern as stated is vacuously satisfiable (muster#76, independently re-verified below).** `tests/cts/skills-suite.test.ts:420-425`@`a46148b` shows `expect(verdict.passed).toBe(false)` cannot distinguish "the control genuinely fired" from "every call to the endpoint errored" — a dead endpoint produces the identical `passed: false` shape muster's *own* test suite already ships with this gap; this mission does not import it into the action-level example unmodified. FR-003/FR-004 below require a conjunction check instead of a bare `result == 'failed'` assertion.

Corrections 3 and 4 were confirmed by directly reading `src/adapters/a2a/index.ts` and `tests/cts/skills-suite.test.ts` in the muster working tree (read-only), not by trusting the issue's quoted snippets.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Wire live behavioral checks through inputs, not hand-rolled env (Priority: P1)

A workflow author wants `skills run` / `sop run` / `crosslayer run` behavioral cases to execute against their own model, using `with:` inputs on `muster-action` instead of hand-wiring `env:` at the job level.

**Why this priority**: This is the mission's stated purpose — a documented, guarded input surface for the BYOM triple, matching what the A2A pair already has.

**Independent Test**: Set `model-endpoint`/`model`/`api-key` on a step targeting a manifest with a behavioral case; observe `MUSTER_ENDPOINT`/`MUSTER_MODEL`/`MUSTER_API_KEY` are set in the step's process environment and the behavioral case is attempted (not skipped).

**Acceptance Scenarios**:

1. **Given** `model-endpoint`, `model`, `api-key` are all set to well-formed (possibly fake) values, **When** the step runs a manifest with a behavioral case, **Then** the case is attempted (not reported `skipped`) — verified by the absence of the word "skip" in the captured report for that case.
2. **Given** all three inputs are left at their default (`''`), **When** the step runs the same manifest, **Then** the three env vars are unset (not empty-string) in the child process, and the behavioral case reports `skipped`, exit `0`.

### User Story 2 - Fork PR and broken-config safety (Priority: P1)

A workflow author whose repo accepts external fork PRs needs: (a) a fork PR with no secrets configured to degrade safely, and (b) a *genuinely* broken configuration (endpoint reachable-looking but wrong key, or endpoint simply dead) to fail loudly — never silently pass.

**Why this priority**: This is the single most important design constraint in the mission (per BRIEF). A step that runs, prints, and exits 0 regardless is the exact failure mode this program keeps producing (muster#76, muster#77's sibling findings).

**Independent Test**: Run the action three ways — (i) all three inputs empty, (ii) `model-endpoint` set to a guaranteed-dead local port with all other inputs empty, (iii) `model-endpoint` set to a guaranteed-dead local port with `api-key` also empty — and check exit code / result output for each.

**Acceptance Scenarios**:

1. **Given** no `model-endpoint` (fork PR, secret absent → GitHub resolves `secrets.X` to `''`), **When** the step runs, **Then** result=`skipped`, exit-code=`0` — the job stays green without ever contacting a model.
2. **Given** `model-endpoint` set to `http://127.0.0.1:9` (connection refused) and `api-key` empty, **When** the step runs a manifest with a behavioral case, **Then** result=`errored`, exit-code=`2`, and (with default `fail-on: error`) the step/job fails. This is the mission's mandated negative-path run: **it must be observed failing**, not skipped.

### User Story 3 - Non-vacuous discrimination-control assertion in CI (Priority: P1)

A CI operator scheduling live behavioral suites wants a documented pattern that proves a discrimination control still works, without that proof being satisfiable by a dead endpoint or a fixture-pinned constant.

**Why this priority**: Directly answers muster having no xfail mechanism (garrison-hq/muster#59 correction #2) and closes the exact gap muster#76 found in muster's own test suite, at the CI-YAML layer where the action's current outputs (aggregate `result`/`exit-code` only) cannot express the needed conjunction.

**Independent Test**: Run the documented example workflow's behavioral job against (a) a healthy stub endpoint and (b) a dead endpoint. The example's assertion step must pass in (a) and **fail** in (b), because (b) cannot produce a genuine `passed` companion case.

**Acceptance Scenarios**:

1. **Given** a manifest containing one ordinary behavioral case and one `isControl: true` case, run against a healthy endpoint, **When** the example workflow's assertion step runs, **Then** it asserts BOTH: the ordinary case's marker is `[PASS]` in the captured report AND the control case's marker is `[FAIL]` — the conjunction, not either alone.
2. **Given** the same manifest run against a dead endpoint, **When** the assertion step runs, **Then** it fails, because the ordinary case's marker is also `[FAIL]` (endpoint down), breaking the conjunction — proving the check is not vacuously satisfiable by a dead endpoint (this is the falsification test for muster#76's failure mode).

### Edge Cases

- `model-endpoint` set, `api-key` absent, and `OPENAI_API_KEY` also absent in the job env → muster's `buildSopClient`/`resolveSkillsBehavioralEndpoint` fallback chain resolves no usable key; must surface as `errored`/exit 2, not `skipped` (skip is keyed only on endpoint absence, per `cli/index.ts:1367-1389,1615-1629`).
- `health-url` polling (existing `wait-health.sh`) times out while `model-endpoint` is set → the existing script already exits 1 (`wait-health.sh:22`) before the muster step even runs; this mission does not change that path but documents the interaction (a slow-to-boot agent plus a live BYOM endpoint both configured).
- A workflow declares `model-endpoint`/`api-key` at the step level from `secrets.*` on a **fork PR**: GitHub resolves the secret expression to `''` (not an error) — so this collapses into the "all empty" skip path automatically; no special-case handling is needed in `run.sh` beyond the existing unset guard, but the README must say this explicitly so authors don't add unnecessary job-level `if:` guards out of an unfounded fear that `secrets.X` errors on a fork PR.
- A discrimination-control manifest is authored using the **a2a** `control:` flag rather than skills' `isControl:` — the FR-003/FR-004 conjunction pattern must **not** be applied to it (C-005); a2a's own exit/result already reflects the correct (inverted) verdict.

## Requirements *(mandatory)*

### Functional Requirements

| ID | Requirement | Verification Command | Expected Outcome | Normative Citation | Priority | Status |
|----|---|---|---|---|---|---|
| FR-001 | New inputs `model-endpoint`, `model`, `api-key` on `action.yml`, mapped to env `MUSTER_ENDPOINT`, `MUSTER_MODEL`, `MUSTER_API_KEY` on the run step. Empty value → **unset** (not `""`), extending the existing guard block. | `bash -c 'MODEL_ENDPOINT="" ; [ -z "$MODEL_ENDPOINT" ] && unset MUSTER_ENDPOINT; env \| grep -c MUSTER_ENDPOINT'` inside `run.sh`'s guard section; integration case in `tests/fixtures/`. | Guard exits with `MUSTER_ENDPOINT` absent from `env` (grep count `0`) when input is empty; present with the exact input value when non-empty. | `scripts/run.sh:9-10`@muster-action`b40681a` (existing pattern for the A2A pair, mirrored); `src/cli/index.ts:1367-1389,1615-1629`@muster`a46148b` (`resolveSkillsBehavioralEndpoint`, `buildSopClient` — both return `undefined`/skip on absent `MUSTER_ENDPOINT`) | High | Open |
| FR-002 | `api-key` is documented secrets-only, never appears in `argv` (i.e., never concatenated into `MA_COMMAND`/`MA_ARGS`), never echoed to the log. | `command grep -n 'MUSTER_API_KEY' scripts/run.sh` — must show it only in the env-guard block, never interpolated into the `npx ... ${MA_COMMAND} ${MA_ARGS}` invocation line; post-run, `command grep -c "$FAKE_KEY_VALUE" "$OUT"` on a test run must be `0`. | Zero matches of the literal key value in captured stdout/stderr; zero matches of the var name in the argv-construction line. | BRIEF constraint 3 (env-var-only, never argv/manifest/log); `scripts/run.sh:20` (existing argv-construction line, unchanged) | High | Open |
| FR-003 | Extend `examples/conformance.yml` (and README) with: (a) static jobs on `pull_request` (no secrets, unchanged), (b) a behavioral job on `schedule`/`workflow_dispatch` using the new triple, explicitly guarded and documented for the fork-PR case, (c) the control-inversion pattern **scoped to skills-adapter `isControl` cases only** (C-005), expressed as the **conjunction** described in User Story 3 — not a bare `result == 'failed'` assertion. | Run the example workflow's behavioral job against a healthy stub and a dead stub (User Story 3, Acceptance Scenarios 1-2). | Assertion step passes against the healthy stub, fails against the dead stub. | This mission's own correction #3/#4 above; muster#76, muster#77 | High | Open |
| FR-004 | New action output `report-file`: absolute path to the full captured stdout+stderr text (today written to a `mktemp` file in `run.sh` and deleted at line 57). The file must survive until the step completes so a downstream step in the same job can read it. | `test -s "${{ steps.muster.outputs.report-file }}"` in a follow-up step within the same job; `command grep -q '\[PASS\] <ordinary-case-id>' "$file" && command grep -q '\[FAIL\] <control-case-id>' "$file"`. | File exists, is non-empty, and both markers are independently greppable — this is the mechanism User Story 3's conjunction check requires; without it, the aggregate `result`/`exit-code` outputs cannot express "one case passed AND another failed" (muster#76's gap re-appearing at the CI-YAML layer otherwise). | New requirement — no prior citation; addresses the gap in `scripts/run.sh:51-57` (report captured then unconditionally deleted) | High | Open |
| FR-005 | Action integration tests (`.github/workflows/test.yml`) extend the existing matrix with three BYOM-triple cases: (a) all three empty → env absent, behavioral case skips, exit `0`; (b) `model-endpoint` set to a guaranteed-dead local port, others empty → env present, execution errors, exit `2` (negative path, User Story 2 Acceptance Scenario 2); (c) `model-endpoint` set, `api-key` deliberately empty and no `OPENAI_API_KEY` in the runner env → still errors (exit `2`), proving the skip decision is keyed only on endpoint presence, not key presence. | `test "${{ steps.muster.outputs.result }}" = "..."` / `test "${{ steps.muster.outputs.exit-code }}" = "..."` per case, following the existing `test.yml` pattern (lines 12-60). | (a) `skipped`/`0`; (b) `errored`/`2`; (c) `errored`/`2`. None of the three collapse into `failed`/`1` or into a silent pass. | `.github/workflows/test.yml:45-60`@muster-action`b40681a` (existing `a2a-skip` job, pattern to extend) | High | Open |
| FR-006 | README documents the **evidence-artefact pattern** for any consumer (notably the SK fork's own reusable workflow) running a scheduled live gate: per-axis pass rates, `runsErrored`, `model`, endpoint **host only** (never the key, never the full URL if it embeds credentials), and a timestamp, written to `$GITHUB_STEP_SUMMARY` and/or committed as a workflow artifact — never left as prose-only claims in a PR description or spec. muster-action itself does not run such a live gate in its own CI (no model credentials are available there) — this FR ships the template/documentation only. | `command grep -n 'runsErrored\|GITHUB_STEP_SUMMARY' README.md examples/*.yml` | Pattern documented with a concrete snippet; explicitly labeled as the consuming workflow's responsibility to execute. | BRIEF: "a sibling mission's best evidence lived only in prose... recorded 0/24, re-measured 4/24" | Medium | Open |

### Non-Functional Requirements

| ID | Requirement | Category | Verification Command | Expected Outcome | Priority | Status |
|----|---|---|---|---|---|---|
| NFR-001 | Static (`pull_request`) jobs never reference the BYOM triple or contact a model provider. | Security/Cost | `command grep -A5 'pull_request:' examples/conformance.yml \| command grep -c 'model-endpoint\|api-key'` | `0` | High | Open |
| NFR-002 | No workflow shipped by this mission (examples, docs, or this repo's own `.github/workflows/`) uses `pull_request_target` without an explicit, reviewed justification comment. | Security | `command grep -rn 'pull_request_target' examples/ docs/ README.md .github/workflows/` | Zero matches, or each match carries an adjacent `# justification:` comment reviewed in this mission's PR. | High | Open |
| NFR-003 | The `report-file` (FR-004) is not deleted before the job step ends when the output is requested, and stays under the action's own temp/workspace path (never a fixed, world-guessable name). | Reliability | Re-run FR-004's verification after the step completes. | File readable post-step; path is a fresh `mktemp`-style path per run. | Medium | Open |

### Constraints

| ID | Constraint | Category | Verification Command | Expected Outcome | Priority | Status |
|----|---|---|---|---|---|---|
| C-001 | Backward compatible: all new inputs optional, default empty; the three existing `test.yml` jobs (`static-pass`, `static-fail`, `a2a-skip`) pass unmodified against the new `action.yml`/`run.sh`. | Technical | Run the unmodified pre-mission `test.yml` against the new action code. | All three jobs pass exactly as they do on `b40681a` today. | High | Open |
| C-002 | Exit contract untouched: `0` clean/skip, `1` conformance failure, `2` execution error; no code path collapses `2` into `1` or into `0`. | Technical | FR-005(b)/(c). | exit-code output is literally `2` in both negative-path cases, never `1`. | High | Open |
| C-003 | Never instruct a consumer to create a repo-local `.env` for credentials. Secrets flow only via GitHub `secrets:` → this action's `env:`-mapped inputs. | Security | `command grep -rn '\.env' README.md examples/ docs/` | No instruction to create/populate a `.env` file (the pre-existing defensive `.gitignore` entry for `.env` is unaffected and is not itself an instruction). | High | Open |
| C-004 | Credentials are never persisted to disk beyond the ephemeral, already-deleted report temp file (`run.sh:57`); never written into a manifest; never appear in a workflow log. | Security | Post-run `command grep -rn "$FAKE_KEY_VALUE" .` (excluding `.git`) after a test invocation with a fake key. | Zero matches anywhere in the working tree after the run completes. | High | Open |
| C-005 | The FR-003/FR-004 control-inversion conjunction pattern applies **only** to skills-adapter `isControl` cases. It must **not** be applied to a2a `control:` cases, whose result is already inverted internally by muster (`applyControlInversion`, `src/adapters/a2a/index.ts:356-371`@`a46148b`) — wrapping it a second time would assert the wrong polarity. | Technical | Manual doc review + example workflow only targets skills manifests for the inversion step. | Example workflow's inversion/conjunction step is documented as skills-only; the a2a-skip job (existing, unmodified) needs no equivalent wrapper. | High | Open |

### Key Entities

- **BYOM behavioral triple**: `MUSTER_ENDPOINT` / `MUSTER_MODEL` / `MUSTER_API_KEY`, treated as one cohesive unit for the empty-unset guard — never set independently of each other's absence semantics.
- **Discrimination control case**: an `isControl`/`control`-flagged manifest case; its genuinely-firing verdict must be provable as genuine (conjunction with a companion real case), never assumed from its own polarity alone.
- **Report artefact**: the full captured stdout+stderr text from a muster invocation, exposed via the new `report-file` output — the mechanism that makes non-vacuous per-case CI assertions possible.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A consumer wires a live behavioral check via `with:` inputs alone — zero custom shell scripting required beyond the documented example.
- **SC-002**: 100% of the fork-PR-shaped negative test matrix (User Story 2, Scenario 1) resolves to `skipped`/exit `0` — a fork PR with no secrets never fails due to missing model credentials.
- **SC-003**: 100% of the broken-configuration test matrix (FR-005 b/c) surfaces as `errored`/exit `2` — 0% silent-green rate for a dead endpoint or a missing key when an endpoint is configured.
- **SC-004**: The shipped example's discrimination-control assertion has a 0% false-pass rate against a dead-endpoint substitute in CI (User Story 3, Scenario 2) — the conjunction check never passes when the model was never actually reached.

## Fork-PR / Missing-Secret Behavior (explicit)

- A fork PR never has repo secrets in scope for `pull_request`-triggered jobs. `secrets.MUSTER_API_KEY` (or any secret reference) resolves to `''` on such a run — not an error, not a skipped step.
- Because FR-001's guard unsets on empty, this collapses automatically into the "all-empty" path: `MUSTER_ENDPOINT`/`MUSTER_MODEL`/`MUSTER_API_KEY` all absent, muster's own endpoint-resolution functions return `undefined`, the behavioral case(s) report `skipped`, exit `0`.
- This mission does **not** recommend `pull_request_target` for the behavioral job. If a future mission proposes it (e.g., to let a maintainer-approved fork PR run a live check), that proposal must carry its own explicit exfiltration-risk justification (NFR-002) — it is out of scope here, and this mission's example workflow uses `schedule`/`workflow_dispatch` on the repo's own refs instead, exactly as the existing A2A example already does (`README.md:30-51`).
- The step-level unset guard (FR-001) is a defense-in-depth backstop; the primary recommended consumer pattern is still a job-level `if: ${{ secrets.MUSTER_API_KEY != '' }}`-style guard so a fork PR's behavioral job doesn't even attempt setup (documented in FR-003's README update).

## Version-Pin Decision

This mission cannot respond to the version-pin question by ignoring it — every option has a real cost, verified above (Context & Verified Facts #1-3):

- Pinning `1.1.0` (today's `npm view` latest): a real, reproducible, published version — but it **cannot execute skills-behavioral cases at all** (pre-M5 hardcoded skip, Correction #2 above), so any FR-003/FR-004 example run against the default `version` input would only ever observe the static path, never actually exercising this mission's own reason for existing.
- Pinning `main`/`latest`: floating, non-reproducible, and currently red on CI (Context #2) — an explicit non-goal for a published action's default.
- Pinning the exact unreleased commit `a46148b969b28be4ada8fb3ba2045c77d8b97217` via a git-spec reference (e.g. `npx github:garrison-hq/muster#a46148b969b28be4ada8fb3ba2045c77d8b97217`): reproducible today, but non-standard (bypasses the npm registry, slower, not what `version`'s existing docstring — "npm version or range... passed to npx" — describes) and explicitly pre-release.

**Decision D1 (recommended)**: Do **not** change `action.yml`'s default `version` (`^1.1.0`) in this mission. Ship the new input surface as inert-but-safe against the current default — a consumer on `^1.1.0` gets the guarded env wiring with no behavioral effect until a release containing M5 ships (tracked externally; muster's own CI must go green first, per Context #2). For this mission's **own** example/validation workflow (FR-003), pin the exact commit SHA above, explicitly labeled `# pre-release pin — remove once vX.Y.0 (first release ≥ a46148b) ships` with a tracking reference back to this decision. Do not silently bake a floating range into anything this mission ships.

## Decisions (open, each with a recommendation — not resolved by assuming a default away)

- **D2 — `base-url-compat` shim (issue #2's FR-003)**: **Recommend dropping it from this mission's scope.** It solves no real problem for the skills use case this mission targets (Correction #2). If SOP/crosslayer/memory-utilization compatibility with a pre-M5 `MUSTER_BASE_URL`-only muster turns out to matter independently, it should be proposed as its own narrow, separately-evidenced follow-up — not bundled here on an unverified premise.
- **D3 — Charter for `muster-action`**: this repo has no charter (`.kittify/charter/charter.md` absent, confirmed via `spec-kitty charter context`). **Recommend a minimal charter**, not muster's full six-constraint one: this repo is a thin CI wrapper (~450 lines total across `action.yml`/`scripts/`), not a runtime with its own domain model. A minimal charter should still capture the one constraint that actually bites here — credential handling (env-only, never argv/manifest/log, C-003/C-004) — plus a scope-guard directive (this is a CI wrapper, not a framework/registry/hosted service). Running the full charter interview is out of scope for this specify pass; this is a decision for the operator, not something this mission resolves unilaterally.
- **D4 — Evidence artefact ownership (FR-006)**: **Recommend** muster-action ships the documented pattern only; the SK fork's own reusable workflow (a separate repository, explicitly off-limits to this specify session) is responsible for actually executing a live gate and committing the resulting evidence. This mission's own deliverable makes no live-verification claim it cannot back with a committed artifact.

## Scope Guard

- muster is not an agent framework, prompt optimizer, registry, or hosted service — `muster-action` remains a thin composite-action wrapper around `npx @garrison-hq/muster`. No bundling, no container build (unchanged D1 in `docs/spec.md`).
- SARIF/code-scanning output and per-finding annotations: explicitly deferred (`docs/spec.md` "Out of scope"), unchanged by this mission.
- Booting agents in CI is the consumer's job (`docs/spec.md` D5), unchanged.
- No muster CLI changes. An xfail mechanism for muster manifests is a separate, muster-repo-side open question (garrison-hq/muster#59's OQ-5) — this mission's FR-003/FR-004 are the CI-side answer for muster-action specifically, not a change to muster itself.
- The A2A input contract (`endpoint`, `token`, `health-url`, `health-timeout`) is untouched.
- This mission does not modify, execute, or commit anything in `garrison-hq/muster` or the SK fork repository — verified read-only inspection only (see closing confirmation).

## Anticipated Work-Package Lanes (guidance for `/spec-kitty.tasks`)

Single lane, matching the issue's own assessment: `action.yml` + `scripts/run.sh` + `README.md` + `examples/conformance.yml` + `.github/workflows/test.yml` are one coupled surface — the env-guard extension (FR-001), the new output (FR-004), the test matrix (FR-005), and the README/example updates (FR-003/FR-006) all touch overlapping files in the same small repo. Splitting into parallel lanes here would recreate the "lane cannot read a sibling's files, including existence" hazard for no benefit — there is no independent slice smaller than "the action + its own tests + its own docs" that is separately mergeable. When `/spec-kitty.tasks` runs:
- Every WP's `dependencies` must list `action.yml`, `scripts/run.sh`, `scripts/wait-health.sh`, `README.md`, `examples/conformance.yml`, `.github/workflows/test.yml`, and `tests/fixtures/*` explicitly — a mechanical check walking each acceptance command's referenced path against declared dependencies is recommended before finalizing, since this mission's own FR table already references files across all of those.
- One WP should own the discrimination-control pattern (fixture + assertion + the dead-endpoint falsification test) as a single object — splitting fixture/assertion/falsification across WPs is exactly how a pinned-constant or vacuous control ships (BRIEF).
- Nothing under `kitty-specs/` may be committed on a lane branch.

## Assumptions

- `gpt-4o-mini` remains a reasonable default model reference in documentation examples (matches muster's own CLI default seen throughout `src/cli/index.ts`).
- The SK fork's reusable workflow (issue #2 WP03, "published in the SK fork") is tracked as a dependency of, not a deliverable within, this mission — this specify session did not enter that repository.
- `runsPerQuery`/threshold defaults for any example manifest this mission ships follow the existing convention already in this repo's fixtures (`defaults: runs: 3, pass_threshold: 2`, `examples/a2a/behavioral-explicit.yaml` — note: this file does not currently exist in `muster-action`; it is muster's own convention, cited here only as the pattern to follow, not as an existing local file).

## Normative Citations Index

| Citation | Pins to |
|---|---|
| `scripts/run.sh:9-10,20,51-57` | `garrison-hq/muster-action@b40681a` |
| `.github/workflows/test.yml:12-60` | `garrison-hq/muster-action@b40681a` |
| `src/cli/index.ts:1367-1389` (`resolveSkillsBehavioralEndpoint`) | `garrison-hq/muster@a46148b969b28be4ada8fb3ba2045c77d8b97217` |
| `src/cli/index.ts:1615-1629` (`buildSopClient`) | `garrison-hq/muster@a46148b969b28be4ada8fb3ba2045c77d8b97217` |
| `src/adapters/a2a/index.ts:356-371` (`applyControlInversion`) | `garrison-hq/muster@a46148b969b28be4ada8fb3ba2045c77d8b97217` |
| `tests/cts/skills-suite.test.ts:420-425` | `garrison-hq/muster@a46148b969b28be4ada8fb3ba2045c77d8b97217` |
| `.env.example:1,4-6,9,12,15,18,26` | `garrison-hq/muster@a46148b969b28be4ada8fb3ba2045c77d8b97217` (per muster#79) |
| `npm view @garrison-hq/muster versions/time` | npm registry, queried 2026-07-30 |
| `gh run list --repo garrison-hq/muster --branch main` | GitHub Actions history, queried 2026-07-30 |
