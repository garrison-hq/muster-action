# muster-action

Run [muster](https://github.com/garrison-hq/muster) agent-file conformance checks in your CI.

`muster` validates the files that define an AI agent: Soul.md personas, Agent Skills, OpenClaw
SOPs (AGENTS.md), tool manifests, agent memory, heartbeat checklists, cross-layer composition,
and A2A Agent Cards. It also drives a running agent over A2A and grades its multi-turn behavior.
This action wraps the `muster` CLI so a pull request can be gated on any of those checks.

## Quick start

```yaml
- uses: garrison-hq/muster-action@v1
  with:
    command: check
    args: souls/my-agent/Soul.md
```

The step fails the job if the file does not conform. That is the whole setup for a static gate.

## How it works

The action sets up Node, runs `npx @garrison-hq/muster@<version> <command> <args>`, and turns the
result into the job outcome:

- exit `0`: the check passed (or was skipped because no endpoint was configured)
- exit `1`: a conformance failure. The step fails and an inline annotation is added.
- exit `2`: an internal or endpoint error. The step fails.

Set `fail-on: never` to report the result through outputs without failing the step.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `command` | yes | | The muster subcommand, for example `check`, `cts run`, `a2a run`, `skills run`, `sop run`. |
| `args` | no | `''` | Positional argument: a manifest path, file, or glob. |
| `version` | no | `^1.1.0` | npm version or range of `@garrison-hq/muster` to run. |
| `endpoint` | no | `''` | A2A endpoint base URL for live behavioral cases. Sets `MUSTER_A2A_ENDPOINT`. Empty skips live cases. |
| `token` | no | `''` | Bearer token for the endpoint. Sets `MUSTER_A2A_TOKEN`. Pass a secret. Never logged. |
| `model-endpoint` | no | `''` | BYOM endpoint base URL for live behavioral cases (`skills run`/`sop run`/`crosslayer run`/`memory-utilization run`). Sets `MUSTER_ENDPOINT`. Empty skips live behavioral cases. |
| `model` | no | `''` | Model identifier for the BYOM endpoint. Sets `MUSTER_MODEL`. |
| `api-key` | no | `''` | API key for the BYOM endpoint. Sets `MUSTER_API_KEY`. Pass a secret. Never logged. |
| `health-url` | no | `''` | Readiness probe. The action polls it until it returns 200 before running muster. |
| `health-timeout` | no | `60` | Seconds to wait for `health-url`. |
| `annotations` | no | `true` | Emit an inline error annotation on failure. |
| `fail-on` | no | `error` | `error` fails the job on a non-zero exit. `never` reports through outputs only. |
| `node-version` | no | `22` | Node version. muster requires 22 or newer. |
| `working-directory` | no | `.` | Directory to run muster in. |

## Outputs

| Output | Description |
|--------|-------------|
| `exit-code` | The raw muster exit code: `0`, `1`, or `2`. |
| `result` | `passed`, `failed`, `errored`, or `skipped`. |
| `report-file` | Absolute path to the full captured stdout+stderr report from this run. Survives until the step completes; a downstream step in the same job can read it (e.g. for anchored per-case marker assertions). |

## Bring your own model (BYOM) behavioral inputs

`skills run`, `sop run`, `crosslayer run`, and `memory-utilization run` read a separate triple of
env vars than the A2A pair above: `MUSTER_ENDPOINT` / `MUSTER_MODEL` / `MUSTER_API_KEY`. Set them
via the `model-endpoint` / `model` / `api-key` inputs:

```yaml
- uses: garrison-hq/muster-action@v1
  with:
    command: skills run
    args: conformance/skills-behavioral.yaml
    model-endpoint: https://api.example-inference-host.com/v1
    model: gpt-4o-mini
    api-key: ${{ secrets.MODEL_API_KEY }}
```

These mirror the A2A pair's empty-must-be-unset discipline: if any of the three resolves to an
empty string (its default, or an unset `secrets.*` reference), the action unsets the corresponding
env var entirely rather than passing it through as `""`. An empty string and an absent variable are
not the same thing to muster's endpoint-resolution logic — only "absent" reliably triggers the skip
path, so the guard unsets each of the three independently.

Credentials always flow through `secrets:` → this action's `env:`-mapped inputs only. Never put
`api-key` (or any credential) directly in `args`/`command`, and never instruct a consumer to create
a repo-local `.env` file to hold it — this action reads no `.env` file, and none should be created
for it.

## Grading a running agent over A2A

The A2A behavioral path needs a running agent to talk to. The usual pattern is to boot the agent
inside the workflow, wait for it, then run the behavioral suite:

```yaml
- name: Start the agent
  run: ./scripts/start-agent.sh &
  env:
    MODEL_API_KEY: ${{ secrets.MODEL_API_KEY }}

- uses: garrison-hq/muster-action@v1
  with:
    command: a2a run
    args: conformance/behavioral.yaml
    endpoint: http://localhost:8080
    token: ${{ secrets.MUSTER_A2A_TOKEN }}
    health-url: http://localhost:8080/.well-known/agent-card.json
```

With no `endpoint`, muster skips the live cases and the step passes (exit 0), so this is safe to
keep in a workflow that also runs on fork PRs where secrets are absent. A full consumer workflow
is in [`examples/conformance.yml`](examples/conformance.yml).

A good split: run the cheap static checks on every PR, and the live behavioral suite on `main` or
on a schedule, since each behavioral run calls a model.

## Proving a discrimination control still fires (skills only)

A skills manifest can mark a case `isControl: true`: a case engineered so a genuinely working
grader makes it fail, proving the grader can still fail at all. Because muster's aggregate
`result`/`exit-code` outputs only report the manifest's overall pass/fail, they cannot by
themselves distinguish three situations that all read `failed`/exit `1`: a genuine conformance
problem, a dead/broken model endpoint, and everything working correctly with the control firing
exactly as designed. Asserting `result == 'failed'` alone is vacuous — a dead endpoint satisfies it
too.

The fix is a **conjunction**, read from the `report-file` output's anchored, per-case markers: the
ordinary case's marker is `[PASS]` **and** the control case's marker is `[FAIL]`. A dead endpoint
breaks this conjunction — the ordinary case fails too — which is exactly what makes the check
non-vacuous:

```yaml
- uses: garrison-hq/muster-action@v1
  id: muster
  with:
    command: skills run
    args: conformance/skills-behavioral.yaml
    model-endpoint: https://api.example-inference-host.com/v1
    model: gpt-4o-mini
    api-key: ${{ secrets.MODEL_API_KEY }}
    version: '1.2.0'
    fail-on: never   # required -- a genuinely-firing control makes muster exit 1

- name: Assert control-inversion conjunction
  run: |
    report_file="${{ steps.muster.outputs.report-file }}"
    command grep -qxF '  [PASS] <ordinary-case-id>' "$report_file" \
      && command grep -qxF '  [FAIL] <control-case-id>' "$report_file"
```

`fail-on: never` is required, not optional: the control case's genuine failure makes muster's own
exit code `1`, and under the default `fail-on: error` the step would fail the job before the
assertion step above ever runs. Use `grep -qxF` (anchored **and** fixed-string) — `-x` alone treats
`[PASS]`/`[FAIL]` as a POSIX bracket expression (one character from the set), not the literal
string, and silently fails to match the real report line; a bare substring `grep -q` cannot tell an
ordinary case's ID from a control ID that is its substring (e.g. `case-1` vs `case-1-control`). A
worked example against a local stub endpoint is in
[`examples/conformance.yml`](examples/conformance.yml)'s `skills-behavioral` job.

**This pattern is skills-only.** Never apply it to an a2a `control:` case: muster's own
`applyControlInversion` already flips a correctly-firing a2a control's `passed` to `true`
internally, so wrapping it in this conjunction a second time asserts the wrong polarity. The
existing A2A example (`behavioral:` job above) needs no equivalent wrapper.

### Fork-PR behavior

`secrets.MODEL_API_KEY` (or any secret reference) resolves to `''` — not an error, not a
skipped step — on a fork PR with no secrets configured. Because the empty-must-be-unset guard
above unsets `MUSTER_ENDPOINT`/`MUSTER_MODEL`/`MUSTER_API_KEY` when they're empty, this collapses
automatically into the all-empty skip path: `skipped`, exit `0`. The **primary** fork-PR guard for
a job like `skills-behavioral` is a **step-level** `if: ${{ secrets.MODEL_API_KEY != '' }}` on the
muster-invocation and assertion steps — a job-level `if` cannot reference the `secrets` context at
all, so `if: ${{ secrets.MODEL_API_KEY != '' }}` on `jobs.<id>.if` fails to parse/evaluate. The
step-level empty-unset guard above is a defense-in-depth backstop, not the primary mechanism.

## Evidence-artefact pattern for a scheduled live gate (FR-006)

`muster-action` itself carries no model credentials in its own CI and does not execute a live
behavioral gate. If your workflow runs one on a schedule, commit the result as evidence — to
`$GITHUB_STEP_SUMMARY` and/or a workflow artifact — rather than leaving the claim only in a PR
description or a spec document (a sibling programme once recorded a control at `0/24` fired when a
reviewer re-measured `4/24`, entirely from an unverified prose claim). A minimal, copyable schema:

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

- `endpointHost` is the **hostname only** — never the full URL, and never a key or token.
- `runsErrored` is reported separately from `casesPassed`/`casesTotal` — do not collapse an errored
  run into a failed one.
- `controlCasesFired` must reflect the conjunction mechanism above, not the manifest's aggregate
  `result`.
- Writing and committing this artefact is the **consuming workflow's** responsibility; this action
  ships the template only.

## Versioning

Pin to a major tag (`@v1`) for automatic patch and minor updates, or to an exact release
(`@v1.0.0`) for full reproducibility.

## License

Apache-2.0. See [LICENSE](LICENSE).
