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

## Requirement/Constraint Cross-Reference

| ID | What this WP must satisfy |
|---|---|
| FR-005 | Four BYOM-triple test cases: (a) all empty → `skipped`/`0`; (b) dead endpoint → `failed`/`1`; (c) missing key, endpoint set → `failed`/`1`; (d) malformed manifest → `errored`/`2`. |
| C-002 | Exit contract untouched (`0`/`1`/`2`); the action passes muster's own code through faithfully — this WP proves `1` is genuinely produced for (b)/(c) and `2` genuinely only for (d), not miscoded either direction. |

## Subtask T021: [RED] Scaffold the four failing test cases

**Purpose**: Commit the four new job skeletons (or matrix entries) before the fixtures/assertions that make them pass exist, so the reviewer can verify each fails for the stated reason.

**Steps**:
1. Add four new jobs (or a matrix) to `.github/workflows/test.yml`: `byom-all-empty`, `byom-dead-endpoint`, `byom-missing-key`, `byom-malformed-manifest` — each currently pointing at a not-yet-existing fixture or asserting a not-yet-true outcome.
2. Commit this failing scaffold before T022-T025 make each case pass.

**Files**: `.github/workflows/test.yml` (scaffolding).

**Validation**: Each of the four jobs fails today, and the failure reason is traceable to "the fixture/wiring for this case doesn't exist yet" — not an unrelated YAML error.

## Subtask T022: Case (a) — all three empty → `skipped`/`0`

**Purpose**: Prove the fork-PR-shaped default path stays green without ever contacting a model (User Story 2, Scenario 1; SC-002).

**Steps**:
1. Job `byom-all-empty`: run this action against a manifest with a behavioral case, `model-endpoint`/`model`/`api-key` all left at default (empty).
2. Assert:
   ```bash
   test "${{ steps.muster.outputs.result }}" = "skipped"
   test "${{ steps.muster.outputs.exit-code }}" = "0"
   ```

**Files**: `.github/workflows/test.yml` (job body).

**Validation**: Per plan.md's falsification condition for FR-005(a): any of the three BYOM vars leaking through non-empty when the input is empty must make this fail — the same falsification as WP01's T003, exercised here at the whole-action-invocation level.

## Subtask T023: Case (b) — dead endpoint → `failed`/`1` (mandated negative-path run)

**Purpose**: This is **the mission's single most important negative-path proof** — a step with the endpoint configured but broken, asserted to fail, not skip, not silently pass.

**Steps**:
1. Job `byom-dead-endpoint`: set `model-endpoint: http://127.0.0.1:9` (guaranteed connection-refused), `model`/`api-key` empty, targeting a manifest with a behavioral case.
2. Assert:
   ```bash
   test "${{ steps.muster.outputs.result }}" = "failed"
   test "${{ steps.muster.outputs.exit-code }}" = "1"
   ```
3. **This job must be observed actually running and failing in CI** — not merely asserted in a PR description. After implementation, capture the actual `gh run` link/log showing this job's outcome as part of this WP's evidence.

**Files**: `.github/workflows/test.yml` (job body).

**Validation**: Per plan.md's falsification condition: the step reporting `skipped`/`0` (silent-green) or `errored`/`2` (miscoded failure class) are both the exact defect this mission exists to prevent — either outcome must fail this test.

## Subtask T024: Case (c) — missing key, endpoint set → `failed`/`1`

**Purpose**: Prove the skip decision is keyed **only** on endpoint presence, not key presence.

**Steps**:
1. Job `byom-missing-key`: set `model-endpoint` to a real-looking (but not necessarily reachable) value, `api-key` explicitly empty, and ensure `OPENAI_API_KEY` is **absent** from the runner env (do not let a stray ambient env var accidentally supply a fallback key).
2. Assert the same as case (b): `failed`/`1`.

**Files**: `.github/workflows/test.yml` (job body).

**Validation**: Per plan.md's falsification condition: this case is the one that most needs the per-run containment path to actually be reached — a regression that made a missing key throw before reaching that containment would flip this to `2`; the test must catch that (i.e., explicitly assert `exit-code` is `1`, not merely "non-zero").

## Subtask T025: Case (d) — malformed manifest → `errored`/`2`

**Purpose**: Prove C-002's reserved exit-`2` path is real and distinct from (b)/(c) — not merely asserted in prose.

**Steps**:
1. Create `tests/fixtures/malformed-manifest.yaml` — a genuinely invalid YAML file (not merely unusual-but-valid; per plan.md's falsification condition, a fixture that's valid YAML with an unexpected-but-schema-accepted shape does **not** exercise this path — it must be a real parse failure).
2. Job `byom-malformed-manifest`: run this action with `model-endpoint` set (endpoint presence is irrelevant here — the failure happens at manifest-read time, before any endpoint call), targeting the malformed fixture.
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

- [ ] Case (a): all empty → `skipped`/`0`.
- [ ] Case (b): dead endpoint → `failed`/`1` — observed actually failing in a real CI run (the mandated negative-path proof).
- [ ] Case (c): missing key, endpoint set, `OPENAI_API_KEY` absent → `failed`/`1`.
- [ ] Case (d): malformed-YAML fixture, endpoint set → `errored`/`2`.
- [ ] Cross-check confirms no case collapses to `passed`/`0` and only (d) yields exit `2`.
- [ ] RED/GREEN commit SHAs recorded; case (b)'s CI run captured as committed evidence.

## Risks

- **The single highest-value risk in this whole mission** (per the operator's own framing): a workflow step that "runs, prints, and exits 0 regardless." Mitigated structurally: (b)/(c) assert `failed`/`1` explicitly, not merely "not skipped" or "non-zero" — a regression to silent-`0` fails the assertion directly, not just the intent.
- **Case (d)'s fixture accidentally being parseable**: mitigated by T025's explicit local pre-verification that the fixture genuinely fails to parse.
- **Ambient `OPENAI_API_KEY` in the runner env accidentally supplying a fallback for case (c)**: mitigated by T024's explicit check that it's absent, not just that `api-key` input is empty.

## Reviewer Guidance

- Independently confirm case (b)'s CI run actually happened and actually failed — do not accept a summary claim.
- Manually inspect the malformed-manifest fixture; confirm it is a genuine parse failure, not merely unusual-but-valid YAML.
- Check that case (c)'s job definition explicitly excludes `OPENAI_API_KEY` from the runner environment (not merely omits setting it, if some ambient default could otherwise leak in).

## Implementation Command

Depends on WP01 and WP02:
```bash
spec-kitty agent action implement WP04 --agent claude
```
