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

**Version pin — updated at implementation time (2026-07-31), do not use the SHA-checkout mechanism previously described here.** `spec.md`'s original Decision D1 proposed a git-spec reference (`npx -y '@garrison-hq/muster@github:garrison-hq/muster#a46148b...'`), which was empirically tested during planning and does not work (`GitFetcher requires an Arborist constructor to pack a tarball`, a real npm/npx limitation). Planning then adopted a checkout-and-build workaround (`plan.md`, "Spec Corrections Found During Planning #2"). **That workaround is now itself superseded** (`plan.md`, "Spec Corrections Found During Planning #2a"; `spec.md`, Post-Spec Review Correction #9): `@garrison-hq/muster@1.2.0` is published on npm, contains M5 (`git merge-base --is-ancestor a46148b969b28be4ada8fb3ba2045c77d8b97217 v1.2.0` is true), and ships a prebuilt `dist/` — no build step needed. **The corrected mechanism**: simply set `with: version: '1.2.0'` on this WP's behavioral job's muster-invocation step, using the composite action's existing `version` input and the ordinary `npx` path (`scripts/run.sh:20`, unchanged) — no `actions/checkout` of a second repo, no `npm ci`/`npm run build`, no direct `node dist/cli/index.js` invocation. Label the pin `# pinned to the first release containing M5 (a46148b) — see plan.md "Spec Corrections Found During Planning #2a"` (not `# pre-release pin`, since `1.2.0` is a real release, not a pre-release commit).

## Requirement/Constraint Cross-Reference

| ID | What this WP must satisfy |
|---|---|
| FR-003 | Example workflow: (a) static jobs on `pull_request` unchanged/no secrets; (b) behavioral job on `schedule`/`workflow_dispatch` using the new BYOM triple, fork-PR-guarded and documented; (c) control-inversion pattern scoped to skills `isControl` only, expressed as the conjunction (not a bare `result == 'failed'`). |
| FR-006 | README documents the evidence-artefact pattern (per-axis pass rates, `runsErrored`, model, endpoint host only, timestamp) — template/documentation only; muster-action itself does not execute a live gate. |
| C-005 | Conjunction pattern applies only to skills `isControl` cases, never a2a `control:` cases. |
| NFR-001 | Static (`pull_request`) jobs never reference the BYOM triple or contact a model provider. |
| NFR-002 | No shipped workflow uses `pull_request_target` without an explicit, reviewed justification comment. |

## Subtask T014: [RED] Author the failing User Story 3 acceptance test

**Purpose**: Prove, before implementation, that the conjunction check does not exist yet — and design the two-run falsification (healthy vs. dead endpoint) up front. **Fixed after post-tasks review**: the exact executable RED artifact and its fixture must be named explicitly, not left as "design it, don't fully wire it yet."

**Steps**:
1. This subtask depends on WP02 having already shipped `tests/fixtures/skills-control-anchor.yaml` + `tests/fixtures/skills-anchor/` + `tests/fixtures/stub-endpoint.js` (WP02's T010) — **reuse that exact fixture and stub, do not build a separate WP03-specific one**; two divergent control fixtures would be a needless maintenance burden and a place for the two to silently drift apart.
2. Add a new job to `examples/conformance.yml` (e.g. `skills-behavioral`) that references WP02's fixture, with the conjunction-assertion step present but pointed at a manifest/endpoint combination that cannot yet pass (e.g. no muster invocation wired yet, or the assertion step referencing an output that doesn't exist until T015-T017 land) — the concrete RED artifact is this job in `examples/conformance.yml` itself; state in your commit message exactly which line/step is expected to fail and why.
3. Commit this failing state before adding the real behavioral job wiring (T015-T017).

**Files**: `examples/conformance.yml` (scaffolding only at this point).

**Validation**: The RED commit's job fails because the behavioral job/conjunction step is genuinely absent or incomplete — not for an unrelated YAML error.

## Subtask T015: Add the behavioral job to `examples/conformance.yml`

**Purpose**: Ship the fork-PR-safe, schedule/dispatch-triggered example.

**Steps**:
1. Confirm the existing `static:` job (on `push`/`pull_request`, per the current `examples/conformance.yml`) is unchanged and references no BYOM inputs (NFR-001).
2. Add the new `skills-behavioral` job. Add `schedule:`/`workflow_dispatch:` to the workflow's top-level `on:` block (currently only `push`/`pull_request`) — do **not** use `pull_request_target` (NFR-002; this mission introduces none). This job is distinct from the existing `behavioral:` job (which is the A2A example, untouched, C-005) — name it clearly, e.g. `skills-behavioral`, to avoid any reader confusing the two.
3. **Fixed after post-tasks review (the job-level form is invalid GitHub Actions syntax)**: the `secrets` context is **not available in `jobs.<id>.if`** — a job-level `if: ${{ secrets.MODEL_API_KEY != '' }}` would fail to parse/evaluate. Guard at the **step level** instead: give the muster-invocation step (and the assertion step after it) `if: ${{ secrets.MODEL_API_KEY != '' }}` (steps *can* reference `secrets` in their own `if:`). Document in a comment that the step-level unset guard from WP01 is the defense-in-depth backstop; this step-level `if:` is the primary skip mechanism for a fork PR with no secrets configured.
4. Reference WP02's exact fixture (`tests/fixtures/skills-control-anchor.yaml` + its skill dir/query set + `stub-endpoint.js`) — per T014, do not build a separate one.

**Files**: `examples/conformance.yml` (+~30-50 lines).

**Validation**: `command awk '/^  static:/{p=1} /^  [a-z][a-z0-9_-]*:/ && !/^  static:/{p=0} p' examples/conformance.yml | command grep -c 'model-endpoint\|api-key'` → `0` (NFR-001 — **fixed after post-tasks review**: a bare `grep -A5 'pull_request:' ... | grep -c ...` matches the workflow's top-level `on:` trigger-key block, never a job body, and always returns `0` regardless of what any job actually contains — a hollow assertion; this awk form scopes to the `static:` job block by indentation instead); `command grep -rn 'pull_request_target' examples/` → zero matches (NFR-002).

## Subtask T016: Pin `version: '1.2.0'` on the behavioral job's muster step

**Purpose**: Make M5's actual runtime behavior reachable in this WP's own validation job. (Renamed at implementation time, 2026-07-31: the originally-specified "exact-SHA-pin workaround" — checkout `a46148b`, `npm ci && npm run build`, invoke `node dist/cli/index.js` directly — is superseded now that `@garrison-hq/muster@1.2.0` is a real, published, M5-containing release; see `plan.md` "Spec Corrections Found During Planning #2a" and `spec.md` Post-Spec Review Correction #9 for the evidence. Re-confirmed directly for this implementation, not taken on the plan's word: `npm view @garrison-hq/muster@1.2.0 gitHead` → `b5d6214f559b7c322e7238d267045c05a4b54f84`; `git merge-base --is-ancestor a46148b969b28be4ada8fb3ba2045c77d8b97217 v1.2.0` → true.)

**Steps**:
1. On the behavioral job's muster-invocation step (the existing composite-action `uses:` step, e.g. `garrison-hq/muster-action@<ref>` or `./` for same-repo testing), add:
   ```yaml
   with:
     version: '1.2.0'
     # pinned to the first release containing M5 (a46148b) — see plan.md
     # "Spec Corrections Found During Planning #2a"
   ```
   alongside this job's other `with:` inputs (`command`, `args`, `model-endpoint`, `model`, `api-key`, etc.). No `actions/checkout` of a second repository, no build step, and no bypass of this action's own `version`/`npx` mechanism — `scripts/run.sh:20`'s existing `npx -y "@garrison-hq/muster@${VERSION}"` line already handles a real semver version like any other.
2. Do not use `version: '^1.1.0'` (the action's default) for this job even though it currently also resolves to `1.2.0` (npm's range resolution picks the highest satisfying published version) — an explicit `1.2.0` pin is required for reproducibility; a future `1.3.0` release must not silently change what this validation job exercises.

**Files**: `examples/conformance.yml` (the `version: '1.2.0'` input, in place of the previously-scaffolded checkout+build steps).

**Validation**: The behavioral job's muster step actually runs M5 behavior and produces real skills-behavioral output (not a static/pre-M5 skip) — confirm by checking the captured report shows an attempted (not skipped) case.

## Subtask T017: Add the skills-only control-inversion conjunction assertion

**Purpose**: Ship the actual User Story 3 mechanism, scoped correctly per C-005.

**Steps**:
1. On the muster-invocation step in the `skills-behavioral` job, set `fail-on: never`. **This is required, not optional**: WP02's control case fires and fails by design, which makes muster's own exit code `1` — under the default `fail-on: error`, the composite action's step would fail the job right there and the downstream assertion step below would never run at all (GitHub Actions skips subsequent steps in a job once one fails, unless they declare `if: always()` or similar). `fail-on: never` reports the outcome via outputs only and lets the job continue to the assertion step, exactly like the existing `static-fail` job in `.github/workflows/test.yml` already does for the same reason.
2. Add a downstream step in the same job (after the muster run) that reads `steps.<muster-step-id>.outputs.report-file` and asserts the conjunction:
   ```bash
   command grep -qxF '  [PASS] <ordinary-case-id>' "$report_file" \
     && command grep -qxF '  [FAIL] <control-case-id>' "$report_file"
   ```
   **Fixed after post-tasks review (critical)**: use `-qxF` (fixed-string), not `-qx` alone — `[PASS]`/`[FAIL]` are literal brackets, and `-x` without `-F` treats them as a BRE bracket expression (matching one character from the set, e.g. `P`/`A`/`S`), which does **not** match the real report line at all. `debugger-debbie` confirmed this empirically during post-tasks review.
3. **Verify this step targets a skills manifest only** — add an explicit comment or a fixture-level guarantee (not just a comment) that this assertion is never run against an a2a `control:` manifest. Consider a lightweight guard: assert the manifest path/fixture used in this job is the skills fixture, not `tests/fixtures/a2a-behavioral.yaml`.
4. Confirm the existing `a2a-skip` job (in `.github/workflows/test.yml`, WP04's file, not this WP's) and the existing `behavioral:` job (in `examples/conformance.yml`, this WP's file but the A2A example, unrelated to this WP's new `skills-behavioral` job) are completely untouched — neither needs an equivalent wrapper (C-005).

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
1. In `README.md`, document the fork-PR behavior explicitly: `secrets.MUSTER_API_KEY` (or any secret ref) resolves to `''` on a fork PR — not an error, not a skip — so it collapses into the all-empty skip path automatically; the primary guard is still the **step-level** `if: secrets.X != ''` pattern (T015 — job-level would be invalid, `secrets` is unavailable in `jobs.<id>.if`), not just WP01's step-level unset guard (which is the defense-in-depth backstop, not the primary mechanism).
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
- [ ] `skills-behavioral` job on `schedule`/`workflow_dispatch`, fork-PR-guarded via a **step-level** `if: secrets.X != ''` (job-level is invalid — the `secrets` context is unavailable in `jobs.<id>.if`), no `pull_request_target` (NFR-002).
- [ ] `version: '1.2.0'` pin on the behavioral job's muster step (superseding the checkout + build + direct `node dist/cli/index.js` mechanism) actually runs M5's behavior.
- [ ] Conjunction assertion targets a skills manifest only; a2a `control:` cases are never wrapped (C-005); existing `a2a-skip` job untouched.
- [ ] FR-006's evidence-artefact schema is documented with a literal, grep-able snippet.
- [ ] `docs/spec.md` citations synced; fork-PR behavior documented in README.
- [ ] Two-run falsification (healthy passes, dead fails) observed and recorded as committed evidence, not prose.
- [ ] RED/GREEN commit SHAs recorded.

## Risks

- **Applying the conjunction to an a2a manifest by mistake** (C-005's named hazard): mitigated by T017's explicit fixture-level guarantee, not just a comment.
- **Version-pin premise going stale** (muster ships a release containing `a46148b` before this WP implements): **this already happened** — `1.2.0` shipped before implementation began, and T016 was updated at implementation time (2026-07-31) to pin the real release instead of the checkout-and-build workaround it originally specified. Re-confirm again before implementing, the same way: `npm view @garrison-hq/muster versions` / `gitHead` and `git merge-base --is-ancestor <sha> <tag>`, in case a newer release has shipped since this correction was written.
- **Evidence recorded only in prose** (a named hazard from a sibling mission: a control recorded at `0/24` where a reviewer measured `4/24`): mitigated by T020 requiring committed run evidence, not narrative claims.

## Reviewer Guidance

- Re-run T020's two-run falsification yourself; do not accept a PR description's claim that it was done.
- Confirm the conjunction assertion's fixture is unambiguously a skills manifest, and that the existing `a2a-skip` job is byte-for-byte unchanged.
- Confirm the `version: '1.2.0'` pin's comment cites `plan.md` "Spec Corrections Found During Planning #2a" and the M5 commit it corresponds to.

## Implementation Command

Depends on WP02:
```bash
spec-kitty agent action implement WP03 --agent claude
```
