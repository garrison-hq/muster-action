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
  job (documented in the README); the action itself never fails for a missing endpoint. The same
  empty-must-be-unset pattern applies to the separate BYOM behavioral triple below (`muster-action`
  mission 01KYTP0Z, FR-001): a fork PR's absent secrets collapse into the same skip path.
- **D6 — Skills-only control-inversion conjunction, not a bare exit-code check** (mission
  01KYTP0Z, FR-003/FR-004). Muster's aggregate `result`/`exit-code` cannot distinguish a genuine
  conformance failure, a dead endpoint, and a correctly-firing discrimination control — all three
  read `failed`/exit `1`. The action exposes a `report-file` output (the full captured report,
  no longer deleted after the step) so a downstream step can assert the conjunction — ordinary
  case `[PASS]` **and** control case `[FAIL]` — via an anchored, fixed-string match
  (`grep -qxF`). Scoped to skills-adapter `isControl` cases only; never applied to an a2a
  `control:` case, whose polarity muster already inverts internally. See README, "Proving a
  discrimination control still fires."
- **D7 — Explicit version pin for this repo's own behavioral validation.** `version` defaults to
  a floating range (`^1.1.0`); this repo's own example/validation jobs that exercise live
  behavioral cases pin an exact release (`version: '1.2.0'`, the first published release
  containing the skills-behavioral-trigger commit) rather than relying on whatever the default
  range currently resolves to, so a future patch/minor release cannot silently change what those
  jobs exercise.

## Input → env contract

`endpoint` and `token` set `MUSTER_A2A_ENDPOINT` / `MUSTER_A2A_TOKEN` verbatim — the exact env
vars muster's A2A adapter reads. Empty values are unset (not passed as `""`) so muster's
absent-endpoint skip path triggers correctly. The token is never echoed or logged.

`model-endpoint` / `model` / `api-key` set `MUSTER_ENDPOINT` / `MUSTER_MODEL` / `MUSTER_API_KEY` —
the separate BYOM behavioral triple read by `skills run` / `sop run` / `crosslayer run` /
`memory-utilization run` (mission 01KYTP0Z, FR-001). Same empty-must-be-unset discipline as the
A2A pair, applied independently per variable; `api-key` is documented secrets-only and never
appears in argv or the log (FR-002).

## Exit contract (passed through from muster)

`0` pass (or skipped), `1` conformance failure, `2` internal/endpoint error. With `fail-on: error`
(default) the step fails the job on non-zero; `fail-on: never` reports via outputs without failing.
A dead endpoint or a missing key against a *configured* endpoint surfaces as `1` (an ordinary
conformance failure, via muster's own per-run error containment) — `2` is reserved for a manifest
that cannot be read/parsed, or a genuine internal exception (mission 01KYTP0Z, FR-005/C-002).

## Outputs

`exit-code` (raw 0/1/2), `result` (`passed` | `failed` | `errored` | `skipped`), and `report-file`
(absolute path to the full captured stdout+stderr report; survives until the step completes —
mission 01KYTP0Z, FR-004/NFR-003).

## Out of scope (follow-ups)

- SARIF / GitHub code-scanning output (needs `--format sarif` in the muster CLI).
- Per-finding annotations richer than the failure summary (depends on stable per-command JSON).
- Booting the agent under test — that is the consumer workflow's job (boot-in-CI), not the action.
