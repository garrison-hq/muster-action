---
work_package_id: WP01
title: BYOM input surface + empty-unset guard
dependencies: []
requirement_refs:
- FR-001
- FR-002
- C-001
- C-003
- C-004
planning_base_branch: kitty/mission-muster-action-behavioral-env
merge_target_branch: kitty/mission-muster-action-behavioral-env
branch_strategy: Planning artifacts for this mission were generated on kitty/mission-muster-action-behavioral-env. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into kitty/mission-muster-action-behavioral-env unless the human explicitly redirects the landing branch.
subtasks:
- T001
- T002
- T003
- T004
- T005
- T006
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
role: implementer
tags: []
tracker_refs: []
---

# Work Package Prompt: WP01 – BYOM input surface + empty-unset guard

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `claude`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## Objective

Add a documented, guarded input surface — `model-endpoint` / `model` / `api-key` on `action.yml`, mapped to `MUSTER_ENDPOINT` / `MUSTER_MODEL` / `MUSTER_API_KEY` on the "Run muster" step — and extend the existing empty-must-be-unset guard block in `scripts/run.sh` to cover all three new vars independently, mirroring the discipline the A2A pair (`endpoint`/`token`) already has. Confirm the credential (`api-key`) never reaches argv or a log.

## Context

This is **IC-01** in `plan.md` — the foundation the other three concerns (report-file output, example workflow, integration test matrix) build on. It has no dependencies; it is the first WP to implement.

Why this exists (do not re-litigate, just build against it):
- **Verified Fact #4** (`spec.md`): `scripts/run.sh:20` already runs `npx -y "$PKG" ${MA_COMMAND} ${MA_ARGS}` with no env sanitization — a caller who sets `MUSTER_API_KEY` at job level already reaches the muster process today. This WP's job is to add a **documented, guarded `with:` input surface**, not a new capability.
- **Existing pattern to mirror**: `scripts/run.sh:9-10` (muster-action `b40681a`) already does the empty-unset dance for `MUSTER_A2A_ENDPOINT`/`MUSTER_A2A_TOKEN`:
  ```bash
  [ -z "${MUSTER_A2A_ENDPOINT:-}" ] && unset MUSTER_A2A_ENDPOINT
  [ -z "${MUSTER_A2A_TOKEN:-}" ] && unset MUSTER_A2A_TOKEN
  ```
  Add three more lines in the same shape, one `unset` per var — **do not** combine them into one conditional. A guard that unsets `MUSTER_ENDPOINT`/`MUSTER_MODEL` but forgets `MUSTER_API_KEY` (or vice versa) is a real, cited risk (plan.md's FR-001 falsification condition): a partial-triple regression must be caught by asserting all three independently, not with one combined grep.
- **`action.yml`'s existing A2A inputs** (`endpoint`, `token`) show the exact input-declaration + `env:`-mapping shape to copy for `model-endpoint`/`model`/`api-key`. Default `''` for all three (backward compatible, C-001).
- **Charter Directive 1 (credential handling)**: `api-key` must flow only through `env:` mapping — never argv, never a manifest, never a log. `scripts/run.sh:20`'s argv-construction line (`npx -y "$PKG" ${MA_COMMAND} ${MA_ARGS}`) is explicitly **not** to be touched by this WP; the credential must never be concatenated into it.
- **Charter Directive 3 (ATDD-first)**: the failing acceptance test for this WP's own FR/constraints must be committed *before* the `action.yml`/`scripts/run.sh` change that makes it pass. The reviewer will check out this WP's base commit and confirm the test fails **for the reason FR-001/FR-002 describe** (the guard/inputs don't exist yet), not for an unrelated reason (YAML typo, missing fixture).

## Requirement/Constraint Cross-Reference

| ID | What this WP must satisfy |
|---|---|
| FR-001 | New inputs `model-endpoint`/`model`/`api-key`, mapped to `MUSTER_ENDPOINT`/`MUSTER_MODEL`/`MUSTER_API_KEY`; empty → **unset**, not `""`. |
| FR-002 | `api-key` is secrets-only: never in argv, never echoed to the log. |
| C-001 | Backward compatible: existing `static-pass`/`static-fail`/`a2a-skip` jobs in `.github/workflows/test.yml` pass unmodified against the new `action.yml`/`run.sh`. |
| C-003 | Never instruct a consumer to create a repo-local `.env`. |
| C-004 | Credentials never persisted to disk beyond the (still, at this point) ephemeral report temp file; never in a manifest; never in a log. |

## Subtask T001: [RED] Author the failing acceptance test for FR-001/FR-002

**Purpose**: Prove, before any implementation change, that the guard/inputs do not yet exist — and that the test fails for that specific reason. Fixed after post-tasks review: this test must be **self-contained** (direct invocation of `scripts/run.sh`, not a `.github/workflows/test.yml` job) because `test.yml` is WP04's owned file, not this WP's, and because it must be **distinct** from WP04's later `byom-all-empty` case (T022) rather than duplicating it — that duplicate existed in an earlier draft of this prompt and was removed.

**Steps**:
1. Do **not** touch `.github/workflows/test.yml` or add a CI job — `scripts/run.sh` is a standalone bash script and can be invoked directly on the command line with controlled env vars, which is both simpler and keeps this subtask inside WP01's own `owned_files`.
2. The RED condition this subtask proves is **mapping existence**, not the empty/skip path (WP04's T022 already owns proving the empty/skip path via the real composite action in CI — testing it again here would be a duplicate, not independent coverage). Concretely: today, `action.yml` has no `model-endpoint`/`model`/`api-key` inputs, so there is no mapping from any `with:` value to `MUSTER_ENDPOINT`/`MUSTER_MODEL`/`MUSTER_API_KEY` at all. Write a short recipe (a script or a documented set of commands, your choice, checked in as e.g. a comment block or left as commit-message-documented manual steps — this repo has no test framework, per plan.md) that:
   - Sets `MUSTER_ENDPOINT=http://127.0.0.1:9`, `MUSTER_MODEL=fake-model`, `MUSTER_API_KEY=fake-key-value` directly as env vars (simulating what `action.yml`'s future `env:` mapping will produce), then invokes `GITHUB_OUTPUT="$(mktemp)" bash scripts/run.sh` with `MA_COMMAND=check MA_ARGS=tests/fixtures/Soul.md` (a cheap, static, already-existing fixture — no network call happens for this specific check).
   - Asserts (today, before this WP lands) that these three vars, once set, are **not** unset by `scripts/run.sh` even when re-set to empty — i.e., confirm the *guard itself* doesn't exist yet: `MUSTER_ENDPOINT="" MUSTER_MODEL="" MUSTER_API_KEY="" GITHUB_OUTPUT="$(mktemp)" bash -c 'source <(sed -n "1,11p" scripts/run.sh); env | command grep -c "MUSTER_ENDPOINT\|MUSTER_MODEL\|MUSTER_API_KEY"'` should currently print `0` only for the two pre-existing A2A vars' pattern coverage, **not** for these three (since lines 1-11 of the pre-WP01 script don't mention them at all) — pick the exact line range that reflects the script's real current line count and state it in your commit message so the reviewer can re-run it verbatim.
3. Commit this failing recipe (and its observed failing output, e.g. as a comment or a short markdown note) as its own commit, before any `action.yml`/`scripts/run.sh` change.

**Files**: none required beyond what's already in `owned_files` — no new fixture files needed (`tests/fixtures/Soul.md` already exists).

**Validation**: `git log` shows this commit before the T002/T003 commits; re-running the recipe at this commit reproduces the failure, and the failure reason is "the guard doesn't exist yet for these three vars" — not a YAML syntax error or missing fixture.

**Falsification condition** (what would make this check wrong if skipped): if the RED commit's failure is actually caused by something unrelated (e.g. a fixture path typo), the ATDD discipline is not actually verified — the reviewer must reject a RED commit that fails for the wrong reason. Also: if this subtask's RED condition duplicates WP04's T022 (all-empty → skip), that is itself a defect — the reviewer should reject any version of this subtask that re-tests the empty/skip path instead of mapping-existence.

## Subtask T002: Add the three new inputs to `action.yml`

**Purpose**: Declare `model-endpoint`, `model`, `api-key` as new optional inputs and map them to env on the "Run muster" step.

**Steps**:
1. In `action.yml`'s `inputs:` block, add (mirroring the existing `endpoint`/`token` inputs' shape and doc-comment style):
   ```yaml
   model-endpoint:
     description: 'BYOM endpoint base URL for live behavioral cases (skills/sop/crosslayer/memory-utilization). Sets MUSTER_ENDPOINT. Leave empty to skip live behavioral cases.'
     required: false
     default: ''
   model:
     description: 'Model identifier passed through to MUSTER_MODEL.'
     required: false
     default: ''
   api-key:
     description: 'API key for the BYOM endpoint (pass a secret). Sets MUSTER_API_KEY. Never logged.'
     required: false
     default: ''
   ```
2. In the "Run muster" step's `env:` block, add:
   ```yaml
   MUSTER_ENDPOINT: ${{ inputs.model-endpoint }}
   MUSTER_MODEL: ${{ inputs.model }}
   MUSTER_API_KEY: ${{ inputs.api-key }}
   ```
3. Do **not** touch the `outputs:` block in this WP (that is WP02's `report-file`, T008).

**Files**: `action.yml` (~6-9 new lines: 3 inputs + 3 env mappings).

**Validation**: `command grep -n 'model-endpoint\|MUSTER_ENDPOINT' action.yml` shows the new input and mapping; existing `endpoint`/`token`/A2A inputs are untouched.

## Subtask T003: Extend the empty-unset guard block in `scripts/run.sh`

**Purpose**: Make empty values for the three new vars resolve to **absent**, not `""`, exactly like the existing A2A pair.

**Steps**:
1. In `scripts/run.sh`, immediately after the existing two-line A2A guard (lines 9-10), add three more lines, one per var:
   ```bash
   [ -z "${MUSTER_ENDPOINT:-}" ] && unset MUSTER_ENDPOINT
   [ -z "${MUSTER_MODEL:-}" ] && unset MUSTER_MODEL
   [ -z "${MUSTER_API_KEY:-}" ] && unset MUSTER_API_KEY
   ```
2. Do **not** touch line 20 (the `npx ... ${MA_COMMAND} ${MA_ARGS}` invocation) — FR-002 requires `api-key` never reach argv, and this line already only reads `MA_COMMAND`/`MA_ARGS`, not the BYOM vars.

**Files**: `scripts/run.sh` (+3 lines).

**Validation**: the prompt's original one-liner (`bash -c 'MUSTER_ENDPOINT="" ... ; env | grep -c ...'`) assigns the vars *inside* the single-quoted `-c` string, so they are never exported into that subshell's environment — `env` never lists them regardless of whether the guard runs, so it silently prints `0` even against a pre-T003 baseline with no guard at all. Use the env-prefixed `source` form instead (assignment prefixed *before* `bash -c`, sourcing only the guard lines via `sed`/process substitution — the form T001's own recipe and this WP's actual T003 commit both use):

All three empty (must print `0`):
```bash
MUSTER_ENDPOINT="" MUSTER_MODEL="" MUSTER_API_KEY="" \
  bash -c 'source <(sed -n "1,13p" scripts/run.sh); env | command grep -c "MUSTER_ENDPOINT\|MUSTER_MODEL\|MUSTER_API_KEY"'
```

Falsification check for the partial-triple regression (plan.md's FR-001 falsification condition) — each of the three must be tested independently, not as one combined grep. Run each of the following three, one at a time; each must print exactly `1` (never `0`, never `3`):
```bash
MUSTER_ENDPOINT="http://x" MUSTER_MODEL="" MUSTER_API_KEY="" \
  bash -c 'source <(sed -n "1,13p" scripts/run.sh); env | command grep -c "MUSTER_ENDPOINT\|MUSTER_MODEL\|MUSTER_API_KEY"'
MUSTER_ENDPOINT="" MUSTER_MODEL="fake" MUSTER_API_KEY="" \
  bash -c 'source <(sed -n "1,13p" scripts/run.sh); env | command grep -c "MUSTER_ENDPOINT\|MUSTER_MODEL\|MUSTER_API_KEY"'
MUSTER_ENDPOINT="" MUSTER_MODEL="" MUSTER_API_KEY="fake" \
  bash -c 'source <(sed -n "1,13p" scripts/run.sh); env | command grep -c "MUSTER_ENDPOINT\|MUSTER_MODEL\|MUSTER_API_KEY"'
```
(`sed -n "1,13p"` reflects the guard block's post-T003 line range — re-check this range if `run.sh`'s header is ever restructured.)

## Subtask T004: Verify FR-002's argv-safety mechanically

**Purpose**: Prove `MUSTER_API_KEY` never reaches the `npx` invocation line or the captured log.

**Steps**:
1. `command grep -n 'MUSTER_API_KEY' scripts/run.sh` — confirm it appears only in the guard block (T003's new line), never on the invocation line (`scripts/run.sh:20`, unchanged). This part needs no execution, only a static grep, so it has no dependency on WP02/WP04.
2. **Fixed after post-tasks review**: do not reference `$OUT` — it is an internal variable local to `scripts/run.sh`'s own subshell (created by `mktemp` at line 14, deleted at line 57) and is not accessible to a caller invoking the script from outside; the `report-file` output that WOULD expose this path doesn't exist until WP02 lands, so this WP cannot depend on it either. Instead, capture the script's own stdout+stderr directly at the shell level, since `scripts/run.sh` already unconditionally echoes the captured muster output to its own stdout (the `cat "$OUT"` at line 24, between the two `-----` banner lines, is not redirected anywhere else): run it with a known-fake, distinctive `api-key` value (e.g. `FAKE_KEY_VALUE_$(date +%s)`) set as `MUSTER_API_KEY`, targeting `tests/fixtures/Soul.md` (cheap, static — no live model call needed for this check):
   ```bash
   FAKE_KEY_VALUE="FAKE_KEY_VALUE_$(date +%s)"
   MUSTER_ENDPOINT=http://127.0.0.1:9 MUSTER_MODEL=fake MUSTER_API_KEY="$FAKE_KEY_VALUE" \
     MA_COMMAND=check MA_ARGS=tests/fixtures/Soul.md GITHUB_OUTPUT="$(mktemp)" \
     bash scripts/run.sh > /tmp/wp01-t004-capture.txt 2>&1
   command grep -q "muster result:" /tmp/wp01-t004-capture.txt   # assert the run actually happened (not a silent no-op) — must exit 0
   command grep -c "$FAKE_KEY_VALUE" /tmp/wp01-t004-capture.txt   # must be 0
   ```
3. **Do not use a bare `grep -rq` without the leading `!`/exit-code check** — per C-004's own verification command, the assertion is that grep finds nothing; a dropped negation is the inverted-assertion trap this programme has shipped before. Use `! command grep -rq "$FAKE_KEY_VALUE" . --exclude-dir=.git` and check its exit code is `0` (meaning zero matches).

**Files**: no new files — this is a self-contained verification pass, invoked directly via the shell, not folded into any CI job (`.github/workflows/test.yml` is WP04's owned file, not this WP's).

**Validation**: Zero matches of the literal fake key value anywhere in the captured stdout+stderr or repo tree (excluding `.git`); zero matches of `MUSTER_API_KEY` on the argv-construction line specifically.

## Subtask T005: Document the new inputs in `README.md`

**Purpose**: Consumer-facing documentation for the new inputs, the guard behavior, and the "never create `.env`" constraint (C-003).

**Steps**:
1. Add a section documenting `model-endpoint`/`model`/`api-key`: what they do, that they're optional/default-empty, and that they mirror the existing A2A pair's empty-unset discipline.
2. State explicitly: secrets flow only via GitHub `secrets:` → this action's `env:`-mapped inputs; do **not** instruct a consumer to create a repo-local `.env` file for credentials (C-003). Do not merely omit `.env` mention — say it explicitly, since a later `command grep -rn '\.env' README.md examples/ docs/` (C-003's verification command) must find no such instruction.
3. Keep this WP's README edit scoped to the input/guard documentation — the fork-PR guidance and evidence-artefact pattern belong to WP03 (README is a shared file across WP01/WP02/WP03; do not duplicate sections another WP owns).

**Files**: `README.md` (~15-25 new lines).

**Validation**: `command grep -rn '\.env' README.md` shows no instruction to create/populate one; the new inputs are documented with their env-var mapping and default.

## Subtask T006: [GREEN] Confirm RED→GREEN and record commit SHAs

**Purpose**: Close the ATDD loop for this WP.

**Steps**:
1. Re-run T001's test job (or the mechanism you built) and confirm it now passes.
2. Record in this WP's history/PR description: the RED commit SHA (T001) and the GREEN commit SHA (the commit that made it pass) — this is the `base_commit` a reviewer must check out to verify RED. Do not let this drift; a sibling mission's `base_commit` field pointed reviewers at the wrong commit and nobody noticed because nothing keyed off it — state it explicitly here.
3. Run `spec-kitty agent tasks mark-status T001 T002 T003 T004 T005 T006 --status done` once all subtasks are verified complete.

**Files**: none (verification + record-keeping only).

**Validation**: The RED commit, checked out standalone, reproduces the T001 failure; the GREEN commit, checked out standalone, passes.

## Definition of Done

- [ ] `action.yml` declares `model-endpoint`/`model`/`api-key`, mapped to `MUSTER_ENDPOINT`/`MUSTER_MODEL`/`MUSTER_API_KEY`, default `''`.
- [ ] `scripts/run.sh`'s guard block unsets all three independently when empty (verified per-var, not combined).
- [ ] `scripts/run.sh:20` (argv construction) is unmodified; `MUSTER_API_KEY` never appears there.
- [ ] A fake credential value never appears in captured output or the repo tree after a test run.
- [ ] The three existing `test.yml` jobs (`static-pass`, `static-fail`, `a2a-skip`) still pass unmodified (C-001).
- [ ] README documents the new inputs; no `.env`-creation instruction anywhere touched by this WP.
- [ ] RED commit observed failing for the stated reason; GREEN commit observed passing; both SHAs recorded.

## Risks

- **Partial-triple guard regression** (unsetting only 1-2 of the 3 vars): mitigated by T003's per-var (not combined) assertion.
- **Argv leak via a future refactor of `scripts/run.sh:20`**: mitigated by T004's dedicated, repeatable grep check — re-run this check if `run.sh` is touched again by a later WP (WP02 also edits `run.sh`; WP02's own acceptance test should re-verify this line is unchanged).
- **README section collision with WP03** (both touch `README.md`): keep this WP's edit scoped strictly to inputs/guard documentation; do not write the fork-PR/evidence-artefact sections WP03 owns.

## Reviewer Guidance

- Check out this WP's declared RED commit; confirm the acceptance test fails, and fails **because the guard/input surface doesn't exist yet** — not for an unrelated reason.
- Independently re-run T004's grep checks with your own fake key value (don't trust the implementer's own value) to make sure the leak-check isn't itself pinned to a fixture that happens to pass.
- Confirm `scripts/run.sh:20` is byte-for-byte unmodified from the pre-WP baseline.

## Implementation Command

No dependencies — implement directly:
```bash
spec-kitty agent action implement WP01 --agent claude
```
