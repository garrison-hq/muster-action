# muster-action

Run [muster](https://github.com/garrison-hq/muster) agent-file conformance checks in your CI.

This action wraps the `muster` CLI so a pull request can be gated on the validity of your
agent files: Soul.md personas, Agent Skills, OpenClaw SOPs (AGENTS.md), tool manifests,
agent memory, heartbeat checklists, cross-layer composition, and A2A Agent Cards, plus the
multi-turn A2A behavioral path against a running agent.

Status: in development. See `docs/spec.md` for the design.
