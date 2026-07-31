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
| FR-004 | New output `report-file`: absolute path to the full captured stdout+stderr, surviving until the step completes. Marker checks use anchored, whole-line, **fixed-string** matches (`grep -qxF` — `-x` alone treats `[PASS]`/`[FAIL]` as a BRE bracket expression, not the literal string), not bare substring grep. |
| NFR-003 | `report-file` is not deleted before the step ends when requested; stays under a fresh `mktemp`-style path (never fixed/world-guessable). |

## Subtask T007: [RED] Author the failing acceptance test for FR-004

**Purpose**: Prove the report-file mechanism does not exist yet — before any implementation change. **Fixed after post-tasks review**: this must be self-contained (direct invocation of `scripts/run.sh`), not a `.github/workflows/test.yml` job — `test.yml` is WP04's owned file, not this WP's, and `steps.muster.outputs.report-file` (an Actions expression) only resolves meaningfully inside a real composite-action step, which this WP does not need in order to prove the mechanism.

**Steps**:
1. Run today's (pre-WP02) `scripts/run.sh` directly and confirm the `report-file` key is absent from `$GITHUB_OUTPUT`, and the captured temp file no longer exists after the run completes:
   ```bash
   OUT_MARKER="$(mktemp)"; rm -f "$OUT_MARKER"   # sentinel, not used by the script itself
   GITHUB_OUTPUT="$(mktemp)"
   MA_COMMAND=check MA_ARGS=tests/fixtures/Soul.md bash scripts/run.sh
   command grep -c '^report-file=' "$GITHUB_OUTPUT"   # must be 0 today
   ```
2. Commit this failing recipe (and its observed output) as its own commit, before any `action.yml`/`scripts/run.sh` change.

**Files**: none required beyond what's already in `owned_files`.

**Validation**: Re-running the recipe at the RED commit reproduces `report-file` being absent from `$GITHUB_OUTPUT` — not for an unrelated reason (e.g. the manifest fixture itself being broken).

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

**Validation**: Re-running T007's recipe now shows `report-file=<path>` present in `$GITHUB_OUTPUT`, and `test -s "<path>"` passes; re-run twice and confirm the path differs each time (fresh `mktemp`, never fixed/guessable — NFR-003).

## Subtask T010: Author the control-case fixture (owned by this WP, not split elsewhere)

**Purpose**: Build the manifest fixture that makes the anchored-vs-substring-grep distinction concrete and falsifiable — this is the "fixture" third of this WP's single-object control (fixture + assertion + falsification, T010/T011/T012). **Fixed after post-tasks review**: an earlier draft left the fixture's pass/fail split as "whatever you construct," which is vacuous — the exact split must be pinned, and the fixture must be genuinely schema-valid (a missing/invalid manifest would make later checks fail for the wrong reason, per debugger-debbie's finding on muster's `runBehavioralSkillCase` reading `skillDir`/`querySetPath` before any network call).

**Steps**:
1. Before writing anything, read muster's skills-manifest schema directly (`src/adapters/skills/schema.ts`, in the `garrison-hq/muster` checkout at `a46148b969b28be4ada8fb3ba2045c77d8b97217` — read-only reference, do not edit that repo) to confirm the exact required fields (at minimum: `skillDir`, `querySetPath`, `runsPerQuery`, `threshold`, and per-case `isControl`) and their exact key names/types as of that commit — do not guess the shape from this prompt alone.
2. Create a minimal, genuinely valid skill directory and query set under `tests/fixtures/` (e.g. `tests/fixtures/skills-anchor/` containing whatever `skillDir` requires — a real skill definition file — plus a query-set file `tests/fixtures/skills-anchor-queries.yaml` or similar) so the manifest parses and the skill/query lookups succeed regardless of network reachability.
3. Create the manifest itself (e.g. `tests/fixtures/skills-control-anchor.yaml`) referencing the above, with **exactly two cases**, IDs pinned as literal strings — do not leave these to be invented at implementation time:
   - Ordinary case: `id: case-1`, `isControl: false` (or omitted if the schema defaults it).
   - Control case: `id: case-1-control`, `isControl: true`.
   The control ID is deliberately a superstring of the ordinary ID: `command grep -q 'case-1'` would match both the `[PASS] case-1` line *and* the `[FAIL] case-1-control` line, because `case-1` is a literal substring of `case-1-control` — this is exactly the false-conjunction risk C-005/FR-004 exist to close.
4. Create a minimal local stub HTTP endpoint (e.g. `tests/fixtures/stub-endpoint.js`, run with the Node version this action already requires — `node-version` default `22`) that this WP starts and stops itself for its own verification — no real model/network access needed. Before writing the stub's response logic, read muster's actual skills-adapter HTTP client (the code that calls `MUSTER_ENDPOINT` for a skills-behavioral case) to confirm the real request/response contract (headers, body shape, expected success/failure signal) — do not invent a plausible-looking contract; verify it against the source. Configure the stub to respond so `case-1` genuinely passes (a real graded response the ordinary case's grader accepts) and `case-1-control` genuinely fails (the discrimination control firing as designed, not by construction of the fixture alone — i.e., the stub's response for the control case must be graded, not merely absent/erroring, so the "control genuinely fires" property this WP exists to prove is real).
5. Record, in this WP's implementation notes, exactly which fields you confirmed against the live schema/client code and their file:line, so the reviewer can re-verify without re-deriving the contract from scratch.

**Files**: `tests/fixtures/skills-control-anchor.yaml`, `tests/fixtures/skills-anchor/` (skill dir + query set), `tests/fixtures/stub-endpoint.js` (new).

**Validation**: Running this fixture through muster (endpoint pointed at the local stub, started first) produces a report containing **both** the literal line `  [PASS] case-1` **and** the literal line `  [FAIL] case-1-control` — pinned, not "whatever split you construct."

## Subtask T011: Add the anchored-grep assertion

**Purpose**: Prove the anchored (`-x`, exact-line) **and fixed-string** (`-F`) grep correctly and independently matches both markers. **Fixed after post-tasks review (critical)**: `grep -qx` without `-F` treats `[PASS]`/`[FAIL]` as a POSIX basic-regex bracket expression (matching one character from the set `P`/`A`/`S`, or `F`/`A`/`I`/`L`), **not** the literal string — `debugger-debbie` confirmed empirically this returns exit `1` against the real, literal report line. The anchoring mechanism as originally drafted did not work at all.

**Steps**:
1. Run this WP's own recipe end-to-end and self-contained (no `.github/workflows/test.yml` dependency — that file is WP04's, though WP04 or WP03 may later choose to also wire this same recipe into a CI job, which is their call to make since they own that file):
   ```bash
   node tests/fixtures/stub-endpoint.js &  # background the local stub
   STUB_PID=$!
   GITHUB_OUTPUT="$(mktemp)"
   MUSTER_ENDPOINT=http://127.0.0.1:<stub-port> MUSTER_MODEL=fake MUSTER_API_KEY=fake \
     MA_COMMAND="skills run" MA_ARGS=tests/fixtures/skills-control-anchor.yaml MA_FAIL_ON=never \
     bash scripts/run.sh
   kill "$STUB_PID"
   report_file="$(command grep '^report-file=' "$GITHUB_OUTPUT" | cut -d= -f2-)"
   command grep -qxF '  [PASS] case-1' "$report_file" && command grep -qxF '  [FAIL] case-1-control' "$report_file"
   ```
2. **`MA_FAIL_ON=never` is required, not optional**: `case-1-control` genuinely fires and fails by design, which makes muster's own exit code `1` — under the default `fail-on: error` semantics, `scripts/run.sh` would `exit 1` itself (line 60-61) before this recipe's own downstream grep checks ever run. Setting `MA_FAIL_ON=never` makes `run.sh` always exit `0` and report the real outcome only via `$GITHUB_OUTPUT`/the report file, which is exactly what this recipe (and any CI job built on it later) needs.

**Files**: none new — this step exercises T009/T010's artifacts directly.

**Validation**: The conjunction (`&&`) passes; each half is independently verifiable via `command grep -qxF ...; echo $?`.

## Subtask T012: [Falsification] Prove a bare substring grep would falsely pass

**Purpose**: This is the falsification test for FR-004's own failure mode — the reason anchoring matters, made concrete and testable, not just asserted in prose.

**Steps**:
1. Against the same report file from T011, run the *unanchored* substring form: `command grep -q 'case-1' "$report_file"` — and confirm this **also matches** the `case-1-control` control line (exit `0`), i.e. a bare substring grep cannot tell the two apart. This is a demonstration of the wrong approach, not something whose own pass/fail should gate anything — its point is to show the risk is real, not hypothetical.
2. Also confirm the specific bracket-expression bug T011 fixed is real: show that `command grep -qx '  [PASS] case-1' "$report_file"` (anchored but **without** `-F`) fails to match the literal line — this is the regression check for the exact defect this WP's own first draft shipped, so a future accidental drop of `-F` from the real assertion is caught by this same falsification test, not just by T011 quietly breaking.
3. State explicitly, adjacent to these checks (in a comment or an inline echo), why each matters.

**Files**: none new.

**Validation**: (a) the unanchored substring grep matches both lines; (b) the anchored-but-not-fixed-string grep fails to match the real line — both are the concrete evidence for why T011's `grep -qxF` (both flags together) is the only correct form.

## Subtask T013: [GREEN] Confirm RED→GREEN and record commit SHAs

**Purpose**: Close the ATDD loop for this WP.

**Steps**:
1. Re-run T007's recipe and confirm it now passes (report-file exists, is non-empty, survives to script end).
2. Record the RED commit SHA (T007) and the GREEN commit SHA in this WP's history — this is the commit a reviewer checks out to verify RED. State it explicitly; do not let it drift silently (a sibling mission's `base_commit` pointed reviewers at the wrong commit and no one noticed).
3. Run `spec-kitty agent tasks mark-status T007 T008 T009 T010 T011 T012 T013 --status done` once all subtasks are verified complete.

**Files**: none (verification + record-keeping only).

**Validation**: RED commit reproduces the T007 failure standalone; GREEN commit passes standalone.

## Definition of Done

- [ ] `action.yml` declares `report-file` output.
- [ ] `scripts/run.sh` no longer deletes the report; writes `report-file=<path>` to `$GITHUB_OUTPUT`.
- [ ] The report-file path is a fresh `mktemp`-style path per run (never fixed/guessable) — verified by re-running twice.
- [ ] The control-case fixture (T010) is genuinely schema-valid (real `skillDir`/query set, verified against muster's actual schema) with a pinned case ID that is a substring of another case's ID.
- [ ] The anchored, fixed-string (`grep -qxF`) conjunction assertion (T011) passes against the fixture, with `MA_FAIL_ON=never` so the firing control doesn't abort the recipe before the assertion runs.
- [ ] The two falsification checks (T012) — unanchored substring grep matching both lines, and anchored-without-`-F` failing to match — both demonstrate their respective risks concretely.
- [ ] RED commit observed failing for the stated reason; GREEN commit observed passing; both SHAs recorded.
- [ ] This WP's fixture, assertion, and falsification test (T010/T011/T012) are reviewed together, as one object — flag in the PR/review if any reviewer is asked to approve them separately.

## Risks

- **Control split across commits/reviewers** (the mission's highest-named risk for this concern): mitigated by keeping T010/T011/T012 in this single WP, explicitly called out for joint review.
- **Report-file path predictability regression**: mitigated by T009's explicit re-verification that `mktemp` is still used, not a fixed name.
- **`scripts/run.sh:20` (argv line) drift**: this WP also edits `run.sh` — re-run WP01's T004 argv-safety grep after this WP's changes to confirm the credential-exclusion property still holds.
- **The bracket-expression bug** (`grep -qx '[PASS]'` treating brackets as a BRE character class, not a literal) **is exactly the kind of defect this mission's own falsification-condition discipline exists to catch — and it shipped in this WP's own first draft.** Mitigated by T011 using `-qxF` and T012's second falsification check specifically re-proving the bug so a future regression is caught mechanically, not just by code review.
- **A missing or schema-invalid fixture makes the control "fire" for the wrong reason** (a parse/read failure, not a genuine graded response) — debugger-debbie's finding on `runBehavioralSkillCase` reading `skillDir`/`querySetPath` before any network call. Mitigated by T010 step 1's requirement to verify the schema directly against muster's source before writing the fixture, and step 4's requirement that the stub's response is genuinely graded, not merely absent/erroring.

## Reviewer Guidance

- Confirm T010/T011/T012 were reviewed together, not as isolated diffs — this WP's entire point is that the control is a single, jointly-verified object.
- Manually inspect the fixture's case IDs; confirm the substring relationship is real (not accidentally two unrelated strings that happen to look similar).
- Re-run the unanchored-grep falsification (T012) yourself; don't take the implementer's demonstration on faith.

## Implementation Command

Depends on WP01:
```bash
spec-kitty agent action implement WP02 --agent claude
```
