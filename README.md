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

## Versioning

Pin to a major tag (`@v1`) for automatic patch and minor updates, or to an exact release
(`@v1.0.0`) for full reproducibility.

## License

Apache-2.0. See [LICENSE](LICENSE).
