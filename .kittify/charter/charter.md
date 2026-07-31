# Project Charter — muster-action

**Status**: Minimal charter, hand-authored (Decision D3, mission
`muster-action-behavioral-env-01KYTP0Z`). Not generated via
`spec-kitty charter interview`/`generate` — this repo is a thin composite
GitHub Action (~450 lines total across `action.yml`/`scripts/`), not a
runtime with its own domain model, and does not warrant the full
multi-paradigm/directive doctrine bundle those commands would otherwise
attach (verified: the default `software-dev` template set pulls in ~30
directives and 13 paradigms — atomic design, DDD, mutation testing, C4
modeling, etc. — none of which describe a bash-and-YAML CI wrapper).

This file is the authoritative charter for `muster-action` until an
operator decides otherwise. It intentionally has no companion
`charter.yaml` doctrine-pack bundle.

## Directive 1 — Credential Handling

Credentials (model API keys, endpoint bearer tokens, any secret this action
forwards) flow **only** through environment variables, mapped from GitHub
Actions `with:` inputs to `env:` on the run step.

- **Never argv.** A credential must never be concatenated into the
  muster CLI invocation's command line (`MA_COMMAND`/`MA_ARGS` construction
  in `scripts/run.sh`). Argv is visible in process listings and, on some
  runners, in job logs.
- **Never a manifest.** A credential must never be written into a manifest
  file (skills/sop/a2a YAML) or any other file this action reads or
  produces.
- **Never a log.** A credential must never be echoed to stdout/stderr, and
  must not appear in the captured report file this action exposes as an
  output. Verification is mechanical: after any test run using a
  known-fake credential value, grep the full captured output and the
  repository tree (excluding `.git`) for that literal value — the match
  count must be zero.
- Applies uniformly to the existing A2A pair (`endpoint`/`token`) and to
  any new credential-shaped input this action adds (the BYOM triple:
  `model-endpoint`/`model`/`api-key`).

## Directive 2 — Scope Guard

`muster-action` is a thin composite-action wrapper around
`npx @garrison-hq/muster@<version> <command> <args>`. It is:

- **Not an agent framework.** It does not define, run, or orchestrate
  agents — it only reports on files/manifests that describe them and,
  optionally, drives a live behavioral check against an agent the
  *consumer* workflow booted.
- **Not a prompt optimizer.** It has no opinion on prompt content beyond
  what muster's own manifests express.
- **Not a registry.** It does not store, version, or discover agent
  artifacts on behalf of consumers.
- **Not a hosted service.** Everything it does runs inside the consumer's
  own GitHub Actions job; it has no server component, no persistent
  state, no network surface of its own beyond what `npx` and the
  consumer-configured model endpoint already imply.
- Concretely, this means: no bundling, no container build, no CLI change
  to muster itself, and no feature that would require this action to run
  outside the calling job's lifetime.

## Directive 3 — ATDD-First Test Discipline

This repo had no charter and no recorded test-process constraint before
this mission. Every mission touching `muster-action` from this point
follows ATDD: for each functional requirement or constraint, the failing
acceptance test (a workflow job, an integration-test case, or a shell
assertion) is committed as its own first commit, before the change that
makes it pass.

- The RED commit must be independently verifiable: a reviewer checks it
  out on the mission's `base_commit` (before the fix/feature commit) and
  confirms the test fails for the *reason the requirement describes*, not
  for an unrelated reason (a typo, a missing fixture, a wrong path).
- This is not optional for "just a CI wrapper" work — this repo's entire
  product is test assertions about exit codes and outputs; an
  unverified-RED acceptance test here is a control that was never proven
  able to fail (the same hazard User Story 3 exists to close for muster's
  own discrimination controls, applied reflexively to this repo's own
  development process).
- Applies at whatever granularity the mission's work packages are cut at;
  it does not require one commit per FR when several FRs share one
  coupled acceptance test (e.g., this mission's single-lane FR-001/FR-004
  coupling), but every acceptance test committed still needs its own
  observed-RED commit before the corresponding GREEN commit.

## Applicability

These three directives govern every change in this repo, including this
mission's own scope (the BYOM behavioral-env input surface). Any future
mission that would violate any of them (e.g., a proposal to persist
credentials, to bundle a model client, to host any part of this action as
a service, or to commit a passing test without ever having observed it
fail) must revisit this charter explicitly rather than route around it
silently.

## Non-adoption of the full doctrine bundle

This charter deliberately does **not** adopt: atomic design, DDD, C4
modeling, mutation-testing-as-gate, semantic compression, or the other
paradigms/directives the `software-dev` mission-type template defaults to.
If a future mission's scope genuinely grows this repo into something with
its own domain model, revisit this decision rather than silently
accumulating unused doctrine.
