# muster-action — design

A reusable GitHub Action that wraps the `muster` CLI so a downstream repo can gate its CI on
agent-file conformance. Derived from the briefing in the muster repo
(`briefings/muster-github-action.md`).

## Decisions (locked)

- **D1 — Composite action.** `setup-node` + `npx @garrison-hq/muster@<version> <command>`. No
  container build, no bundling; pins to the npm version.
- **D2 — Dedicated repo** (`garrison-hq/muster-action`) for a clean Marketplace listing and
  versioning independent of the muster npm release train.
- **D3 — Action-only annotations.** Translate a non-zero muster run into a workflow `::error::`
  annotation (attributed to the manifest file when the argument is a path). SARIF / code-scanning
  is a deferred follow-up; no change to the muster CLI in this version.
- **D4 — Readiness wait.** Optional `health-url` + `health-timeout`: the action polls until the
  endpoint returns 200 before invoking muster, so consumers booting an agent in CI do not race it.
- **D5 — Skip-safe.** With no `endpoint`, the action does not set `MUSTER_A2A_ENDPOINT`, so muster
  skips live A2A behavioral cases (exit 0). On a fork PR with no secrets, the consumer guards the
  job (documented in the README); the action itself never fails for a missing endpoint.

## Input → env contract

`endpoint` and `token` set `MUSTER_A2A_ENDPOINT` / `MUSTER_A2A_TOKEN` verbatim — the exact env
vars muster's A2A adapter reads. Empty values are unset (not passed as `""`) so muster's
absent-endpoint skip path triggers correctly. The token is never echoed or logged.

## Exit contract (passed through from muster)

`0` pass (or skipped), `1` conformance failure, `2` internal/endpoint error. With `fail-on: error`
(default) the step fails the job on non-zero; `fail-on: never` reports via outputs without failing.

## Outputs

`exit-code` (raw 0/1/2) and `result` (`passed` | `failed` | `errored` | `skipped`).

## Out of scope (follow-ups)

- SARIF / GitHub code-scanning output (needs `--format sarif` in the muster CLI).
- Per-finding annotations richer than the failure summary (depends on stable per-command JSON).
- Booting the agent under test — that is the consumer workflow's job (boot-in-CI), not the action.
