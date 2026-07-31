---
name: weather-lookup
description: Look up the current weather conditions for a named city or region.
---

# Weather Lookup

A minimal test-only skill fixture used by WP02's anchored-marker control
(T010). Its behavior is irrelevant beyond the frontmatter `name`/
`description` this file provides — `runBehavioralSkillCase`
(`src/cli/index.ts:1414-1482`@`a46148b`) reads only those two frontmatter
fields for an ordinary (non-control) case; the actual tool-call decision is
made by `tests/fixtures/stub-endpoint.js`, not by anything in this body text.
