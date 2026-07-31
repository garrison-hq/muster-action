---
work_package_id: WP03
title: 'Example workflow: behavioral job + scoped control-inversion conjunction'
dependencies:
- WP02
requirement_refs:
- FR-003
- FR-006
- C-005
- NFR-001
- NFR-002
planning_base_branch: kitty/mission-muster-action-behavioral-env
merge_target_branch: kitty/mission-muster-action-behavioral-env
branch_strategy: Planning artifacts for this mission were generated on kitty/mission-muster-action-behavioral-env. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into kitty/mission-muster-action-behavioral-env unless the human explicitly redirects the landing branch.
subtasks:
- T014
- T015
- T016
- T017
- T018
- T019
- T020
history:
- timestamp: '2026-07-31T00:00:00Z'
  agent: planner-priti
  action: Prompt generated via /spec-kitty.tasks (tasks-outline/tasks-packages)
agent_profile: implementer-ivan
authoritative_surface: examples/conformance.yml
create_intent: []
execution_mode: code_change
model: ''
owned_files:
- examples/conformance.yml
- README.md
- docs/spec.md
role: implementer
tags: []
tracker_refs: []
---

# Work Package Prompt: WP03 – Example workflow: behavioral job + scoped control-inversion conjunction

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `claude`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Extend `examples/conformance.yml` with a schedule/`workflow_dispatch`-triggered behavioral job (fork-PR-safe by construction) that demonstrates the **skills-only** control-inversion conjunction pattern from User Story 3 — using WP02's `report-file` + anchored markers — and prove, in CI, that the conjunction assertion passes against a healthy endpoint and **fails** against a dead one. Also ship FR-006's evidence-artefact template (documentation only, per Decision D4).

## Context

This is **IC-03** in `plan.md` — has a **hard dependency on WP02**: the conjunction assertion step reads `steps.muster.outputs.report-file`, which does not exist until WP02 lands.

**The central thing this WP proves, concretely (not just in prose)**: muster's aggregate `result`/`exit-code` outputs cannot, by themselves, distinguish (a) a genuine conformance problem, (b) a dead/broken endpoint, and (c) everything working correctly with the discrimination control firing as designed — all three can read `failed`/exit `1`. The **only** thing that can tell them apart is the conjunction: the ordinary case's marker is `[PASS]` **and** the control case's marker is `[FAIL]`. A dead endpoint breaks this conjunction too (the ordinary case also fails) — that is what makes the check non-vacuous, and it is the exact gap muster#76 found in muster's own test suite (a bare `expect(verdict.passed).toBe(false)` cannot distinguish "the control fired" from "the endpoint was unreachable").

**C-005 scoping — do not get this wrong**: the conjunction pattern applies **only** to skills-adapter `isControl: true` cases. It must **never** be applied to an a2a `control:` case — muster's own `applyControlInversion` (`src/adapters/a2a/index.ts:356-371`) already flips a correctly-firing a2a control's `passed` to `true` internally, so wrapping it in this WP's conjunction a second time would assert the wrong polarity. The existing `a2a-skip` job in `.github/workflows/test.yml` needs no equivalent wrapper — leave it alone.

**Exact-SHA-pin mechanism — do not use the mechanism `spec.md`'s Decision D1 literally describes.** It was empirically tested during planning and does not work: `npx -y '@garrison-hq/muster@github:garrison-hq/muster#a46148b...'` fails with `GitFetcher requires an Arborist constructor to pack a tarball` (a real npm/npx limitation, not a typo). The **corrected mechanism** (plan.md, "Spec Corrections Found During Planning #2"): for the job(s) in this WP that need the pinned SHA's actual runtime behavior (this WP's own conjunction demo), check out `garrison-hq/muster` at `a46148b969b28be4ada8fb3ba2045c77d8b97217` in a preceding step, run `npm ci && npm run build`, and invoke `node dist/cli/index.js <command> <args>` directly — bypassing this action's own `version`/`npx` mechanism for this specific job only. Label the pin `# pre-release pin — remove once vX.Y.0 (first release ≥ a46148b) ships`.

## Requirement/Constraint Cross-Reference

| ID | What this WP must satisfy |
|---|---|
| FR-003 | Example workflow: (a) static jobs on `pull_request` unchanged/no secrets; (b) behavioral job on `schedule`/`workflow_dispatch` using the new BYOM triple, fork-PR-guarded and documented; (c) control-inversion pattern scoped to skills `isControl` only, expressed as the conjunction (not a bare `result == 'failed'`). |
| FR-006 | README documents the evidence-artefact pattern (per-axis pass rates, `runsErrored`, model, endpoint host only, timestamp) — template/documentation only; muster-action itself does not execute a live gate. |
| C-005 | Conjunction pattern applies only to skills `isControl` cases, never a2a `control:` cases. |
| NFR-001 | Static (`pull_request`) jobs never reference the BYOM triple or contact a model provider. |
| NFR-002 | No shipped workflow uses `pull_request_target` without an explicit, reviewed justification comment. |

## Subtask T014: [RED] Author the failing User Story 3 acceptance test

**Purpose**: Prove, before implementation, that the conjunction check does not exist yet — and design the two-run falsification (healthy vs. dead endpoint) up front.

**Steps**:
1. Design (do not yet fully wire) the assertion this WP must ship: `test -s "$report_file" && command grep -qx '  [PASS] <ordinary-id>' "$report_file" && command grep -qx '  [FAIL] <control-id>' "$report_file"`.
2. Add a placeholder/failing version of this check to `examples/conformance.yml` (or a CI job that exercises it) that fails today because the behavioral job/conjunction step doesn't exist yet.
3. Commit this failing state before adding the real behavioral job (T015-T017).

**Files**: `examples/conformance.yml` (scaffolding only at this point).

**Validation**: The RED commit's job fails because the behavioral job/conjunction step is absent — not for an unrelated YAML error.

## Subtask T015: Add the behavioral job to `examples/conformance.yml`

**Purpose**: Ship the fork-PR-safe, schedule/dispatch-triggered example.

**Steps**:
1. Confirm the existing static jobs (on `pull_request`) are unchanged and reference no BYOM inputs (NFR-001).
2. Add a new job triggered on `schedule`/`workflow_dispatch` (never `pull_request_target` — NFR-002; this mission introduces none) that sets `model-endpoint`/`model`/`api-key` from `secrets.*`.
3. Guard the job with a job-level `if: ${{ secrets.MUSTER_API_KEY != '' }}`-style condition (per `spec.md`'s Fork-PR/Missing-Secret Behavior section) — the step-level unset guard from WP01 is a defense-in-depth backstop, not the primary mechanism; document why in a comment.
4. Reference a skills manifest with one ordinary case and one `isControl: true` case (you may reuse WP02's `tests/fixtures/skills-control-anchor.yaml` shape, or build a dedicated example-facing fixture under `tests/fixtures/` if the WP02 fixture is stub-endpoint-specific and unsuitable for the example's own docs-facing purpose — your call, document which).

**Files**: `examples/conformance.yml` (+~30-50 lines).

**Validation**: `command grep -A5 'pull_request:' examples/conformance.yml | command grep -c 'model-endpoint\|api-key'` → `0` (NFR-001); `command grep -rn 'pull_request_target' examples/` → zero matches (NFR-002).

## Subtask T016: Implement the exact-SHA-pin workaround

**Purpose**: Make the pinned, unreleased muster commit (`a46148b969b28be4ada8fb3ba2045c77d8b97217`) actually runnable in this WP's own validation job — the literal mechanism `spec.md` describes does not work (see Context above).

**Steps**:
1. Add a preceding step in the behavioral job (or a dedicated validation job) that:
   ```yaml
   - name: Checkout pinned muster (pre-release)
     uses: actions/checkout@<pinned-sha>
     with:
       repository: garrison-hq/muster
       ref: a46148b969b28be4ada8fb3ba2045c77d8b97217
       path: muster-pinned
   - name: Build pinned muster
     run: |
       cd muster-pinned
       npm ci
       npm run build
   ```
2. Invoke `node muster-pinned/dist/cli/index.js <command> <args>` directly for this job's muster invocations, instead of going through this action's own `version`/`npx` mechanism.
3. Label the pin clearly: `# pre-release pin — remove once vX.Y.0 (first release ≥ a46148b) ships — see plan.md Decision D1 / Spec Correction #2`.
4. Before implementing, re-confirm the premise still holds: `npm view @garrison-hq/muster versions` and the status of muster PR/CI for `main` — if a release containing this commit has shipped since planning, flag it and reconsider whether the pin is still necessary (do not silently carry forward a stale premise).

**Files**: `examples/conformance.yml` (the checkout+build+invoke steps).

**Validation**: The pinned build actually runs and produces real skills-behavioral output (not a static/pre-M5 skip) — confirm by checking the captured report shows an attempted (not skipped) case.

## Subtask T017: Add the skills-only control-inversion conjunction assertion

**Purpose**: Ship the actual User Story 3 mechanism, scoped correctly per C-005.

**Steps**:
1. Add a downstream step in the same job (after the muster run) that reads `steps.<muster-step-id>.outputs.report-file` and asserts the conjunction:
   ```bash
   command grep -qx '  [PASS] <ordinary-case-id>' "$report_file" \
     && command grep -qx '  [FAIL] <control-case-id>' "$report_file"
   ```
2. **Verify this step targets a skills manifest only** — add an explicit comment or a fixture-level guarantee (not just a comment) that this assertion is never run against an a2a `control:` manifest. Consider a lightweight guard: assert the manifest path/fixture used in this job is the skills fixture, not `tests/fixtures/a2a-behavioral.yaml`.
3. Confirm the existing `a2a-skip` job is completely untouched — it needs no equivalent wrapper (C-005).

**Files**: `examples/conformance.yml` (the assertion step).

**Validation**: This is User Story 3's own falsification test — see T020 below for the two-run proof (healthy vs. dead endpoint).

## Subtask T018: FR-006 — Document the evidence-artefact template

**Purpose**: Ship the concrete, copyable evidence-artefact pattern (Decision D4: template/documentation only — muster-action does not execute a live gate itself).

**Steps**:
1. In `README.md` (or `examples/conformance.yml` as a commented example), document the evidence-artefact JSON schema from `plan.md`:
   ```json
   {
     "schema": "muster-action/evidence-artefact/v1",
     "generatedAt": "2026-07-31T00:00:00Z",
     "model": "gpt-4o-mini",
     "endpointHost": "api.example-inference-host.com",
     "runsErrored": 0,
     "axes": [
       { "axis": "verbosity", "casesTotal": 12, "casesPassed": 11, "passRate": 0.9167 }
     ],
     "controlCasesFired": true
   }
   ```
2. Document the rules: `endpointHost` is hostname-only (never the full URL/key); `runsErrored` reported separately from `casesPassed`/`casesTotal` (do not collapse errored into failed); `controlCasesFired` boolean must reflect this WP's own conjunction mechanism.
3. State explicitly that this is the **consuming workflow's** responsibility to execute and commit (`$GITHUB_STEP_SUMMARY` and/or a workflow artifact) — muster-action itself has no model credentials in its own CI and does not run this live.

**Files**: `README.md` (~20-30 new lines, a distinct section from WP01's input docs).

**Validation**: `command grep -n 'runsErrored\|GITHUB_STEP_SUMMARY' README.md examples/*.yml` finds the pattern documented with a literal, copyable snippet — not narrative-only text.

## Subtask T019: Fork-PR guidance + `docs/spec.md` sync

**Purpose**: Close the near-miss the spec's own review found: `docs/spec.md` is cited by NFR-002's verification command and the Scope Guard section three times, but was nearly omitted from WP dependency lists.

**Steps**:
1. In `README.md`, document the fork-PR behavior explicitly: `secrets.MUSTER_API_KEY` (or any secret ref) resolves to `''` on a fork PR — not an error, not a skip — so it collapses into the all-empty skip path automatically; the primary guard is still the job-level `if: secrets.X != ''` pattern (T015), not just the step-level unset guard.
2. Update `docs/spec.md` so its D1/D5/scope-guard citations stay in sync with what this mission actually shipped (per plan.md's Project Structure note: "D1/D5/scope-guard citations already point here — must stay in sync").
3. Re-run NFR-002's verification command (`command grep -rn 'pull_request_target' examples/ docs/ README.md .github/workflows/`) after this subtask — it spans all three files/dirs this WP (and WP01) touch; confirm zero matches, or a reviewed justification comment if any ever appears.

**Files**: `README.md`, `docs/spec.md`.

**Validation**: NFR-002's grep across `examples/`, `docs/`, `README.md`, `.github/workflows/` returns zero matches (or justified ones); `docs/spec.md` citations are current.

## Subtask T020: [GREEN] Two-run falsification proof + commit SHAs

**Purpose**: Close the ATDD loop, and produce the concrete, committed evidence User Story 3 requires — not a prose-only claim.

**Steps**:
1. Run the behavioral job's conjunction assertion against a **healthy stub endpoint** — confirm it passes (ordinary case `[PASS]`, control case `[FAIL]`).
2. Run the same job against a **dead endpoint substitute** (e.g. `http://127.0.0.1:9`) — confirm the assertion **fails**, because the ordinary case's marker is now also `[FAIL]` (the endpoint is down), breaking the conjunction. This is the falsification test for muster#76's failure mode: a dead endpoint alone cannot satisfy this check.
3. Record both observed run results (actual CI run links/logs, not prose paraphrase) as this WP's acceptance evidence.
4. Record the RED commit SHA (T014) and GREEN commit SHA in this WP's history.
5. Run `spec-kitty agent tasks mark-status T014 T015 T016 T017 T018 T019 T020 --status done` once verified.

**Files**: none new (verification + evidence recording).

**Validation**: Two committed, observed CI outcomes — pass on healthy, fail on dead — not an assertion made only in a PR description.

## Definition of Done

- [ ] Static (`pull_request`) jobs unchanged, reference no BYOM inputs (NFR-001).
- [ ] Behavioral job on `schedule`/`workflow_dispatch`, fork-PR-guarded (`if: secrets.X != ''`), no `pull_request_target` (NFR-002).
- [ ] Exact-SHA-pin workaround (checkout + build + direct `node dist/cli/index.js` invocation) actually runs the pinned commit's behavior.
- [ ] Conjunction assertion targets a skills manifest only; a2a `control:` cases are never wrapped (C-005); existing `a2a-skip` job untouched.
- [ ] FR-006's evidence-artefact schema is documented with a literal, grep-able snippet.
- [ ] `docs/spec.md` citations synced; fork-PR behavior documented in README.
- [ ] Two-run falsification (healthy passes, dead fails) observed and recorded as committed evidence, not prose.
- [ ] RED/GREEN commit SHAs recorded.

## Risks

- **Applying the conjunction to an a2a manifest by mistake** (C-005's named hazard): mitigated by T017's explicit fixture-level guarantee, not just a comment.
- **SHA-pin premise going stale** (muster ships a release containing `a46148b` before this WP implements): mitigated by T016's re-confirmation step before implementing.
- **Evidence recorded only in prose** (a named hazard from a sibling mission: a control recorded at `0/24` where a reviewer measured `4/24`): mitigated by T020 requiring committed run evidence, not narrative claims.

## Reviewer Guidance

- Re-run T020's two-run falsification yourself; do not accept a PR description's claim that it was done.
- Confirm the conjunction assertion's fixture is unambiguously a skills manifest, and that the existing `a2a-skip` job is byte-for-byte unchanged.
- Confirm the SHA-pin comment cites the correct commit and a removal tracker.

## Implementation Command

Depends on WP02:
```bash
spec-kitty agent action implement WP03 --agent claude
```
