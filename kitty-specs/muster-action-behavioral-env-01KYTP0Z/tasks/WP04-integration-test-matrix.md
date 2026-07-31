---
work_package_id: WP04
title: Integration test matrix (FR-005) including mandated negative-path run
dependencies:
- WP01
- WP02
requirement_refs:
- FR-005
- C-002
planning_base_branch: kitty/mission-muster-action-behavioral-env
merge_target_branch: kitty/mission-muster-action-behavioral-env
branch_strategy: Planning artifacts for this mission were generated on kitty/mission-muster-action-behavioral-env. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into kitty/mission-muster-action-behavioral-env unless the human explicitly redirects the landing branch.
subtasks:
- T021
- T022
- T023
- T024
- T025
- T026
- T027
history:
- timestamp: '2026-07-31T00:00:00Z'
  agent: planner-priti
  action: Prompt generated via /spec-kitty.tasks (tasks-outline/tasks-packages)
agent_profile: implementer-ivan
authoritative_surface: .github/workflows/test.yml
create_intent: []
execution_mode: code_change
model: ''
owned_files:
- .github/workflows/test.yml
- tests/fixtures/**
role: implementer
tags: []
tracker_refs: []
---

# Work Package Prompt: WP04 – Integration test matrix (FR-005) including mandated negative-path run

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `claude`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Extend `.github/workflows/test.yml` with FR-005's four-case BYOM-triple matrix: (a) all empty → skip; (b) dead endpoint → fail; (c) missing key → fail; (d) malformed manifest → error. Case (b) is **the mission's mandated negative-path run** — it must be observed genuinely failing in CI, not skipped, not silently green.

## Context

This is **IC-04** in `plan.md` — depends on **WP01** (the env-wiring these cases exercise must exist) and **WP02** (noted for completeness; the four FR-005 cases as specified only need the existing `result`/`exit-code` outputs, which already exist independent of `report-file` — do not assume `report-file` is required for this WP's own assertions; it is not).

**Why case (b)/(c) resolve to exit `1`, not `2` (corrected, do not build against the stale claim)**: `spec.md`'s Edge Cases section originally claimed exit `2` for a missing-key scenario — this was a **stale, corrected claim**; the mission's own "Post-Spec Review Corrections" (spec.md, item 5) and `plan.md`'s own "Spec Corrections Found During Planning #1" both establish that a dead endpoint or missing key against a *configured* endpoint resolves to `failed`/exit `1`, via muster's per-run error containment (`runBehavioralSkillCaseSafe`, `src/cli/index.ts:1498-1523`; SOP's per-probe containment, `src/adapters/openclaw-sop/runner.ts:259-403`) — never the top-level `ExecutionError`/exit-`2` path. **Exit `2` is reserved for case (d) only** — a manifest that cannot be read/parsed, or a genuine internal exception. Build against FR-005's own table values (a=skipped/0, b=failed/1, c=failed/1, d=errored/2), not the (now-corrected) Edge Cases wording — if you see a copy of the old exit-2 claim anywhere else in the repo docs, flag it, do not propagate it into a test fixture.

**Fixture-design note (carried from plan.md, not optional)**: build case (d)'s fixture as a **malformed-YAML file**, not a chmod-based "unreadable" file. GitHub-hosted runners' `chmod 000` behavior is not reliably preserved across git clone/checkout, and container-based runners may run differently-privileged processes — a malformed-YAML fixture reaches the exact same `doSkillsRun` try/catch deterministically regardless of runner identity.

**Fixed after post-tasks review (HIGH, two findings, both closed the same way)**:

1. **Cases (a)/(b)/(c) need the exact-SHA-pin workaround too, or they are vacuous.** This action's default `version` input (`^1.1.0`) pre-dates M5 and **hardcodes a skip for every skills-behavioral case regardless of env vars** (Verified Fact #2/#3 in `spec.md`) — so if this WP's cases run against the default version, case (a)'s "skipped/0" assertion would pass even if WP01's guard were completely broken (leaving fake values set), because the pre-M5 CLI never attempts a behavioral case at all, for any reason. That is exactly the "satisfiable without the guard actually working" vacuity `reviewer-renata` flagged. **Fix**: cases (a), (b), and (c) must invoke the pinned, real M5 build — the same checkout-`a46148b969b28be4ada8fb3ba2045c77d8b97217`-and-`npm run build`-then-`node dist/cli/index.js` mechanism WP03's T016 already builds (do not re-derive it independently; reuse the identical steps, labeled with the same removal tracker). **Case (d) does not need the pin** — a manifest read/parse failure (`doSkillsRun`'s own try/catch) happens before any version-specific behavioral-trigger logic and is not M5-specific; the default `version` is fine for case (d) alone.
2. **A missing/invalid skills-manifest fixture would make case (b)'s "mandated negative-path" failure vacuous** (`debugger-debbie`'s finding): muster's `runBehavioralSkillCase` reads `skillDir`/`querySetPath` *before* any network call — pointing case (b)/(c) at a manifest that doesn't parse, or that references a non-existent skill dir, would report `failed`/`1` for a **fixture defect**, not the dead endpoint. **Fix**: T022-T024 must use a genuinely schema-valid skills manifest fixture (real `skillDir` + query set — reuse WP02's `tests/fixtures/skills-anchor/` assets if suitable, or build a WP04-owned equivalent under `tests/fixtures/`, since `tests/fixtures/**` is this WP's own owned glob), and case (b)'s assertion must additionally grep the report content for a connection-refused/network-error signature (not just check the aggregate `exit-code`), to prove the failure came from the dead endpoint specifically.

## Requirement/Constraint Cross-Reference

| ID | What this WP must satisfy |
|---|---|
| FR-005 | Four BYOM-triple test cases: (a) all empty → `skipped`/`0`; (b) dead endpoint → `failed`/`1`; (c) missing key, endpoint set → `failed`/`1`; (d) malformed manifest → `errored`/`2`. |
| C-002 | Exit contract untouched (`0`/`1`/`2`); the action passes muster's own code through faithfully — this WP proves `1` is genuinely produced for (b)/(c) and `2` genuinely only for (d), not miscoded either direction. |

## Subtask T021: [RED] Scaffold the four failing test cases

**Purpose**: Commit the four new job skeletons (or matrix entries) before the fixtures/assertions that make them pass exist, so the reviewer can verify each fails for the stated reason.

**Steps**:
1. Add four new jobs (or a matrix) to `.github/workflows/test.yml`: `byom-all-empty`, `byom-dead-endpoint`, `byom-missing-key`, `byom-malformed-manifest` — each currently pointing at a not-yet-existing fixture or asserting a not-yet-true outcome.
2. For the three jobs that need it (`byom-all-empty`, `byom-dead-endpoint`, `byom-missing-key` — not `byom-malformed-manifest`, see the Context note above), scaffold the exact-SHA-pin checkout+build steps (reused from WP03's T016) as part of this same commit, even though they won't be exercised meaningfully until T022-T024 land.
3. Create a genuinely schema-valid skills manifest fixture for these three jobs to share (per the Context note above) — verify it against muster's real schema before committing it, the same way WP02's T010 does.
4. Commit this failing scaffold before T022-T025 make each case pass.

**Files**: `.github/workflows/test.yml` (scaffolding), `tests/fixtures/*` (the shared valid manifest fixture for cases a/b/c).

**Validation**: Each of the four jobs fails today, and the failure reason is traceable to "the fixture/wiring for this case doesn't exist yet" — not an unrelated YAML error.

## Subtask T022: Case (a) — all three empty → `skipped`/`0`

**Purpose**: Prove the fork-PR-shaped default path stays green without ever contacting a model (User Story 2, Scenario 1; SC-002).

**Steps**:
1. Job `byom-all-empty`: using the pinned M5 build (T021 step 2/3 — **required, see Context**: the default `version` hardcodes a skip regardless of env vars, which would make this assertion pass vacuously even if the guard were broken), run against the shared valid skills manifest fixture, `model-endpoint`/`model`/`api-key` all left at default (empty).
2. Assert:
   ```bash
   test "${{ steps.muster.outputs.result }}" = "skipped"
   test "${{ steps.muster.outputs.exit-code }}" = "0"
   ```

**Files**: `.github/workflows/test.yml` (job body).

**Validation**: Per plan.md's falsification condition for FR-005(a): any of the three BYOM vars leaking through non-empty when the input is empty must make this fail — the same falsification as WP01's T003, exercised here at the whole-action-invocation level. Because this case now runs the real M5 build, a broken guard (fake values leaking through) would cause an actual attempted call rather than a version-hardcoded skip, so the assertion is non-vacuous.

## Subtask T023: Case (b) — dead endpoint → `failed`/`1` (mandated negative-path run)

**Purpose**: This is **the mission's single most important negative-path proof** — a step with the endpoint configured but broken, asserted to fail, not skip, not silently pass.

**Steps**:
1. Job `byom-dead-endpoint`: using the pinned M5 build (required — see Context), set `model-endpoint: http://127.0.0.1:9` (guaranteed connection-refused), `model`/`api-key` empty, targeting the shared valid skills manifest fixture. Set `fail-on: never` on the muster step — **required**: this case's exit code is `1` by design, and under default `fail-on: error` the step itself would fail and the assertion step below would never run (GitHub Actions skips subsequent steps once one fails, without `if: always()`).
2. Assert:
   ```bash
   test "${{ steps.muster.outputs.result }}" = "failed"
   test "${{ steps.muster.outputs.exit-code }}" = "1"
   ```
3. **Fixed after post-tasks review**: also assert the failure is genuinely network-caused, not a fixture defect (`debugger-debbie`'s finding — `runBehavioralSkillCase` reads the manifest/skill dir before any network call, so a broken fixture would produce the identical `failed`/`1` shape for the wrong reason). Capture the muster invocation's own stdout/stderr for this step (e.g. via the job's own log, or by also wiring WP02's `report-file` output onto this step if convenient) and grep it for a connection-refused/network-error signature — confirm locally what muster's actual error text looks like for a refused connection before pinning the exact string in this assertion.
4. **This job must be observed actually running and failing in CI** — not merely asserted in a PR description. After implementation, capture the actual `gh run` link/log showing this job's outcome as part of this WP's evidence.

**Files**: `.github/workflows/test.yml` (job body).

**Validation**: Per plan.md's falsification condition: the step reporting `skipped`/`0` (silent-green) or `errored`/`2` (miscoded failure class) are both the exact defect this mission exists to prevent — either outcome must fail this test. The added network-error-signature check additionally catches a `failed`/`1` that came from a broken fixture rather than the dead endpoint.

## Subtask T024: Case (c) — missing key, endpoint set → `failed`/`1`

**Purpose**: Prove the skip decision is keyed **only** on endpoint presence, not key presence.

**Steps**:
1. Job `byom-missing-key`: using the pinned M5 build (required — see Context), set `model-endpoint` to a real-looking (but not necessarily reachable) value, `api-key` explicitly empty, targeting the shared valid skills manifest fixture, and ensure `OPENAI_API_KEY` is **absent** from the runner env (do not let a stray ambient env var accidentally supply a fallback key). Set `fail-on: never` on the muster step, same reason as case (b).
2. Assert the same as case (b): `failed`/`1`.

**Files**: `.github/workflows/test.yml` (job body).

**Validation**: Per plan.md's falsification condition: this case is the one that most needs the per-run containment path to actually be reached — a regression that made a missing key throw before reaching that containment would flip this to `2`; the test must catch that (i.e., explicitly assert `exit-code` is `1`, not merely "non-zero").

## Subtask T025: Case (d) — malformed manifest → `errored`/`2`

**Purpose**: Prove C-002's reserved exit-`2` path is real and distinct from (b)/(c) — not merely asserted in prose.

**Steps**:
1. Create `tests/fixtures/malformed-manifest.yaml` — a genuinely invalid YAML file (not merely unusual-but-valid; per plan.md's falsification condition, a fixture that's valid YAML with an unexpected-but-schema-accepted shape does **not** exercise this path — it must be a real parse failure).
2. Job `byom-malformed-manifest`: run this action with `model-endpoint` set (endpoint presence is irrelevant here — the failure happens at manifest-read time, before any endpoint call), targeting the malformed fixture. **This case does not need the exact-SHA-pin** (see Context note above) — a manifest read/parse failure is not M5-specific, so the default `version` is fine here. Set `fail-on: never` on the muster step (exit `2` would otherwise fail the step before the assertion runs, same reason as cases (b)/(c)).
3. Assert:
   ```bash
   test "${{ steps.muster.outputs.result }}" = "errored"
   test "${{ steps.muster.outputs.exit-code }}" = "2"
   ```

**Files**: `tests/fixtures/malformed-manifest.yaml` (new), `.github/workflows/test.yml` (job body).

**Validation**: Per plan.md's falsification condition: the manifest-read try/catch being bypassed, or the fixture accidentally being parseable, must be caught — verify by first confirming locally (or via a quick muster invocation) that the fixture genuinely fails to parse, not just "looks weird."

## Subtask T026: Cross-check — no silent-green collapse, (d) uniquely produces exit `2`

**Purpose**: Prove, in one place, that none of the four cases collapse into a silent pass and that exit `2` is produced by exactly one of the four (SC-003's full claim, not just the per-case assertions).

**Steps**:
1. Add a summary check (a final job depending on all four, or a `$GITHUB_STEP_SUMMARY` write) that lists all four outcomes together and asserts:
   - None of (a)-(d) report `passed`/`0` (that would be a defect — none of these scenarios is a genuine pass).
   - Exactly one of (a)-(d) — case (d) — reports exit `2`; (b) and (c) report exit `1`, not `2`.
2. This is the mechanical proof, not a restated assertion, that (b)/(c) are not miscoded as `2` and (d) is not miscoded as `1`.

**Files**: `.github/workflows/test.yml` (summary job/step).

**Validation**: The four-way comparison is explicit and machine-checked, not left as an implicit consequence of the four separate per-case assertions passing individually.

## Subtask T027: [GREEN] Confirm RED→GREEN and record CI evidence

**Purpose**: Close the ATDD loop and produce committed evidence for the mandated negative-path run — not a prose-only claim (the same evidence-fidelity bar as WP03's T020).

**Steps**:
1. Re-run T021's scaffolded jobs and confirm all four now pass with their correct outcomes.
2. Capture the actual CI run for case (b) (the mandated negative-path run) — link or log excerpt showing it genuinely failed, as committed evidence, not narrative.
3. Record the RED commit SHA (T021) and GREEN commit SHA in this WP's history.
4. Run `spec-kitty agent tasks mark-status T021 T022 T023 T024 T025 T026 T027 --status done` once verified.

**Files**: none new (verification + evidence recording).

**Validation**: RED commit reproduces T021's failures standalone; GREEN commit passes standalone; case (b)'s negative-path evidence is a real, committed CI artifact.

## Definition of Done

- [ ] Cases (a)/(b)/(c) run the pinned M5 build (not the default `^1.1.0`, which hardcodes a skip regardless of env vars and would make these assertions vacuous); case (d) correctly does not need the pin.
- [ ] Cases (a)/(b)/(c) target a genuinely schema-valid skills manifest fixture (verified against muster's real schema).
- [ ] Case (a): all empty → `skipped`/`0`, non-vacuously (see above).
- [ ] Case (b): dead endpoint → `failed`/`1`, with `fail-on: never` so the assertion step runs, and the failure text confirmed network-caused (not a fixture defect) — observed actually failing in a real CI run (the mandated negative-path proof).
- [ ] Case (c): missing key, endpoint set, `OPENAI_API_KEY` absent → `failed`/`1`, with `fail-on: never`.
- [ ] Case (d): malformed-YAML fixture, endpoint set → `errored`/`2`, with `fail-on: never`.
- [ ] Cross-check confirms no case collapses to `passed`/`0` and only (d) yields exit `2`.
- [ ] RED/GREEN commit SHAs recorded; case (b)'s CI run captured as committed evidence.

## Risks

- **The single highest-value risk in this whole mission** (per the operator's own framing): a workflow step that "runs, prints, and exits 0 regardless." Mitigated structurally: (b)/(c) assert `failed`/`1` explicitly, not merely "not skipped" or "non-zero" — a regression to silent-`0` fails the assertion directly, not just the intent.
- **Case (d)'s fixture accidentally being parseable**: mitigated by T025's explicit local pre-verification that the fixture genuinely fails to parse.
- **Ambient `OPENAI_API_KEY` in the runner env accidentally supplying a fallback for case (c)**: mitigated by T024's explicit check that it's absent, not just that `api-key` input is empty.
- **Running cases (a)/(b)/(c) against the default (pre-M5) `version` would make all three assertions vacuously satisfiable regardless of whether WP01's guard actually works** (post-tasks finding, `reviewer-renata`): mitigated by mandating the exact-SHA-pin build for these three cases (T021-T024).
- **A missing/invalid fixture would make case (b)'s "mandated negative-path" fail for the wrong reason** (post-tasks finding, `debugger-debbie`): mitigated by requiring a genuinely schema-valid manifest and a network-error-signature check in T023, not just the aggregate exit-code.
- **A firing exit-1/exit-2 step aborting the job before the assertion step runs** (post-tasks finding, `debugger-debbie` — the same class of bug as WP02/WP03's missing `fail-on: never`): mitigated by requiring `fail-on: never` explicitly on every muster step in cases (b)/(c)/(d).

## Reviewer Guidance

- Independently confirm case (b)'s CI run actually happened and actually failed — do not accept a summary claim.
- Manually inspect the malformed-manifest fixture; confirm it is a genuine parse failure, not merely unusual-but-valid YAML.
- Check that case (c)'s job definition explicitly excludes `OPENAI_API_KEY` from the runner environment (not merely omits setting it, if some ambient default could otherwise leak in).

## Implementation Command

Depends on WP01 and WP02:
```bash
spec-kitty agent action implement WP04 --agent claude
```
