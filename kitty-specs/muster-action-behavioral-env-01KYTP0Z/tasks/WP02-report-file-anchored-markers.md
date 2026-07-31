---
work_package_id: WP02
title: report-file output + anchored per-case markers
dependencies:
- WP01
requirement_refs:
- FR-004
- NFR-003
planning_base_branch: kitty/mission-muster-action-behavioral-env
merge_target_branch: kitty/mission-muster-action-behavioral-env
branch_strategy: Planning artifacts for this mission were generated on kitty/mission-muster-action-behavioral-env. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into kitty/mission-muster-action-behavioral-env unless the human explicitly redirects the landing branch.
subtasks:
- T007
- T008
- T009
- T010
- T011
- T012
- T013
history:
- timestamp: '2026-07-31T00:00:00Z'
  agent: planner-priti
  action: Prompt generated via /spec-kitty.tasks (tasks-outline/tasks-packages)
agent_profile: implementer-ivan
authoritative_surface: scripts/run.sh
create_intent: []
execution_mode: code_change
model: ''
owned_files:
- action.yml
- scripts/run.sh
- README.md
- tests/fixtures/**
role: implementer
tags: []
tracker_refs: []
---

# Work Package Prompt: WP02 – report-file output + anchored per-case markers

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `claude`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Stop deleting the captured muster report (`scripts/run.sh:57`'s `rm -f "$OUT"`), expose its path as a new `report-file` action output, and prove that anchored (`grep -qx`, exact-line) matching against that file's per-case markers is the mechanism that resolves the central design problem this whole mission exists to solve: **muster's exit code alone cannot distinguish a genuine conformance failure, a dead endpoint, or a correctly-firing discrimination control** — all three can read `failed`/exit `1`. This WP builds and proves the report-file + anchored-marker mechanism in isolation, as **one coupled object** (fixture + assertion + falsification test), before WP03/WP04 build on top of it.

## Context

This is **IC-02** in `plan.md` — depends on **WP01** (shares the same `run.sh` guard-block region; sequencing avoids two concerns editing overlapping lines out of order). **WP03 has a hard dependency on this WP**: its conjunction assertion step reads `steps.muster.outputs.report-file`, which does not exist until this WP lands.

**This WP owns the discrimination-control mechanism as a single object.** Per the mission's own hazard record: splitting the control's fixture, its assertion, and its falsification test across separate work packages is exactly how a pinned-constant or vacuously-satisfiable control has shipped before on sibling missions. Do not let a future refactor split T010 (fixture)/T011 (assertion)/T012 (falsification) across different commits or hand them to different reviewers in isolation — they must be reviewed and verified together.

Key source fact this WP's marker format depends on: `formatSkillsResultHuman` (`src/cli/index.ts:1592-1602`@muster `a46148b969b28be4ada8fb3ba2045c77d8b97217`) emits report lines in the exact shape `  [${icon}] ${id}` (two leading spaces, `[PASS]` or `[FAIL]`, the case ID). The anchored grep in this WP must match that literal shape — not a paraphrase of it.

## Requirement/Constraint Cross-Reference

| ID | What this WP must satisfy |
|---|---|
| FR-004 | New output `report-file`: absolute path to the full captured stdout+stderr, surviving until the step completes. Marker checks use anchored, whole-line matches (`grep -qx`), not bare substring grep. |
| NFR-003 | `report-file` is not deleted before the step ends when requested; stays under a fresh `mktemp`-style path (never fixed/world-guessable). |

## Subtask T007: [RED] Author the failing acceptance test for FR-004

**Purpose**: Prove the report-file output does not exist yet, and that a bare substring grep is the wrong tool — both before any implementation change.

**Steps**:
1. Add a step (in a new or existing `.github/workflows/test.yml` job) that runs the action against a manifest, then attempts `test -s "${{ steps.muster.outputs.report-file }}"` — this must fail today (the output doesn't exist; `${{ steps.muster.outputs.report-file }}` resolves to an empty string, `test -s ""` fails).
2. Commit this failing step before any `action.yml`/`scripts/run.sh` change.

**Files**: `.github/workflows/test.yml` (new job or step, later reconciled with WP04's matrix — do not worry about overlap yet, WP04 depends on this WP and will build on top).

**Validation**: The RED commit's job fails specifically at the `test -s ...` assertion, with the output variable empty — not for an unrelated reason (e.g. the manifest fixture itself being broken).

## Subtask T008: Add the `report-file` output to `action.yml`

**Purpose**: Declare the new output.

**Steps**:
1. In `action.yml`'s `outputs:` block, add (alongside the existing `exit-code`/`result`):
   ```yaml
   report-file:
     description: 'Absolute path to the full captured stdout+stderr report from this run. Survives until the step completes; a downstream step in the same job can read it (e.g. for anchored per-case marker assertions).'
     value: ${{ steps.run.outputs.report-file }}
   ```

**Files**: `action.yml` (+4-5 lines).

**Validation**: `command grep -n 'report-file' action.yml` shows the new output declaration.

## Subtask T009: Retain the report file and emit its path in `scripts/run.sh`

**Purpose**: Stop deleting the report; expose its absolute path.

**Steps**:
1. Remove the `rm -f "$OUT"` line (currently `scripts/run.sh:57`).
2. Add `echo "report-file=${OUT}"` to the block that already writes `exit-code=`/`result=` to `$GITHUB_OUTPUT` (currently lines 51-54).
3. **NFR-003**: `$OUT` is already a fresh `mktemp` path per run (`scripts/run.sh:14`, unchanged) — confirm this remains true; do not switch to any fixed/predictable filename.
4. Leave the rest of `scripts/run.sh` (annotation logic, exit-code classification, `fail-on` handling) untouched.

**Files**: `scripts/run.sh` (-1 line, +1 line; net 0, but at different points — do not just comment out the `rm`, remove it cleanly).

**Validation**: T007's `test -s "${{ steps.muster.outputs.report-file }}"` now passes; the file is non-empty and its path is a fresh `mktemp`-style path (re-run twice, confirm the path differs each time).

## Subtask T010: Author the control-case fixture (owned by this WP, not split elsewhere)

**Purpose**: Build the manifest fixture that makes the anchored-vs-substring-grep distinction concrete and falsifiable — this is the "fixture" third of this WP's single-object control (fixture + assertion + falsification, T010/T011/T012).

**Steps**:
1. Create a skills manifest fixture (e.g. `tests/fixtures/skills-control-anchor.yaml`, following muster's skills-manifest shape) containing **at least two cases** whose IDs are constructed so a naive substring grep would produce a false match: one ordinary case (e.g. `id: case-1`) and one `isControl: true` case whose ID is a **superstring** of the ordinary case's ID (e.g. `id: case-1-control`). This is deliberate: `grep -q 'case-1'` would match both the `[PASS] case-1` line *and* the `[FAIL] case-1-control` line, because `case-1` is a substring of `case-1-control` — this is exactly the false-conjunction risk C-005/FR-004 exist to close.
2. Point this fixture at a lightweight stub/mock endpoint you control for this WP's own verification (a local stub server or a fixture that fails deterministically) — you do not need real muster/model access to prove the anchoring mechanism; you need a manifest where you can control which case reports `[PASS]` and which reports `[FAIL]`.

**Files**: `tests/fixtures/skills-control-anchor.yaml` (new).

**Validation**: Running the fixture through muster produces a report with both `  [PASS] case-1` and `  [FAIL] case-1-control` (or whatever concrete pass/fail split you construct) as literal lines in the report file.

## Subtask T011: Add the anchored-grep assertion

**Purpose**: Prove the anchored (`-x`, exact-line) grep correctly and independently matches both markers.

**Steps**:
1. Add an assertion step reading `steps.muster.outputs.report-file` and running:
   ```bash
   command grep -qx '  [PASS] case-1' "$report_file" && command grep -qx '  [FAIL] case-1-control' "$report_file"
   ```
2. This step must pass against T010's fixture.

**Files**: `.github/workflows/test.yml` (new step, in the same job as T007/T010's fixture run).

**Validation**: The conjunction (`&&`) passes; each half is independently verifiable via `command grep -qx ...; echo $?`.

## Subtask T012: [Falsification] Prove a bare substring grep would falsely pass

**Purpose**: This is the falsification test for FR-004's own failure mode — the reason anchoring matters, made concrete and testable, not just asserted in prose.

**Steps**:
1. Add a companion check (in the same job, clearly labeled as a **demonstration of the wrong approach**, not a step whose failure blocks CI) that runs the *unanchored* substring form: `command grep -q 'case-1' "$report_file"` — and shows this **also matches** the `case-1-control` control line, i.e. a bare substring grep cannot tell the two apart.
2. State explicitly, adjacent to this check (in a comment or an inline echo), why this matters: an unanchored grep re-introduces a false-conjunction risk (a control-case marker satisfying the ordinary-case's pattern, or vice versa) that the anchored form (T011) closes.
3. Do not let this demonstration step cause the job to fail (it is intentionally showing the *wrong* tool "succeeding" at the wrong thing) — but do assert its behavior (that it matches both lines) so a future accidental removal of `-x` from the real assertion (T011) would be caught if this demonstration step's own expectation ever silently changed.

**Files**: `.github/workflows/test.yml` (extends T011's job with one more step/assertion).

**Validation**: The unanchored grep matches both the ordinary and control lines (proving the false-conjunction risk is real, not hypothetical); the anchored grep (T011) does not have this problem.

## Subtask T013: [GREEN] Confirm RED→GREEN and record commit SHAs

**Purpose**: Close the ATDD loop for this WP.

**Steps**:
1. Re-run T007's test and confirm it now passes (report-file exists, is non-empty, survives to step end).
2. Record the RED commit SHA (T007) and the GREEN commit SHA in this WP's history — this is the commit a reviewer checks out to verify RED. State it explicitly; do not let it drift silently (a sibling mission's `base_commit` pointed reviewers at the wrong commit and no one noticed).
3. Run `spec-kitty agent tasks mark-status T007 T008 T009 T010 T011 T012 T013 --status done` once all subtasks are verified complete.

**Files**: none (verification + record-keeping only).

**Validation**: RED commit reproduces the T007 failure standalone; GREEN commit passes standalone.

## Definition of Done

- [ ] `action.yml` declares `report-file` output.
- [ ] `scripts/run.sh` no longer deletes the report; writes `report-file=<path>` to `$GITHUB_OUTPUT`.
- [ ] The report-file path is a fresh `mktemp`-style path per run (never fixed/guessable) — verified by re-running twice.
- [ ] The control-case fixture (T010) exists with a case ID that is a substring of another case's ID.
- [ ] The anchored (`grep -qx`) conjunction assertion (T011) passes against the fixture.
- [ ] The unanchored substring-grep falsification (T012) demonstrably matches both lines, proving why anchoring is required.
- [ ] RED commit observed failing for the stated reason; GREEN commit observed passing; both SHAs recorded.
- [ ] This WP's fixture, assertion, and falsification test (T010/T011/T012) are reviewed together, as one object — flag in the PR/review if any reviewer is asked to approve them separately.

## Risks

- **Control split across commits/reviewers** (the mission's highest-named risk for this concern): mitigated by keeping T010/T011/T012 in this single WP, explicitly called out for joint review.
- **Report-file path predictability regression**: mitigated by T009's explicit re-verification that `mktemp` is still used, not a fixed name.
- **`scripts/run.sh:20` (argv line) drift**: this WP also edits `run.sh` — re-run WP01's T004 argv-safety grep after this WP's changes to confirm the credential-exclusion property still holds.

## Reviewer Guidance

- Confirm T010/T011/T012 were reviewed together, not as isolated diffs — this WP's entire point is that the control is a single, jointly-verified object.
- Manually inspect the fixture's case IDs; confirm the substring relationship is real (not accidentally two unrelated strings that happen to look similar).
- Re-run the unanchored-grep falsification (T012) yourself; don't take the implementer's demonstration on faith.

## Implementation Command

Depends on WP01:
```bash
spec-kitty agent action implement WP02 --agent claude
```
