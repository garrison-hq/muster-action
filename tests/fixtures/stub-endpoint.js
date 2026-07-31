#!/usr/bin/env node
// WP02 T010 fixture: a minimal local stub of an OpenAI-compatible
// `/chat/completions` endpoint, used only to verify the report-file +
// anchored-marker mechanism in isolation (no real model/network access).
//
// Contract verified directly against muster's own client, not invented:
//   POST {baseUrl}/chat/completions
//   body: { model, messages: [{ role: "user", content }], tools, tool_choice }
//   (src/core/behavioral/client.ts:120-184@a46148b, makeClientWithTools)
// Response shape read back by the adapter (src/adapters/skills/trigger.ts:134-160
// @a46148b, extractToolCallName): OpenAI-style
//   { choices: [{ message: { tool_calls: [{ function: { name } }] } }] }
// or `{ choices: [{ message: {} }] }` when no tool should be called.
//
// Grading behavior (genuinely graded, not merely absent/erroring — T010 step 4):
//   - tools[0].function.name === "rigged-impossible-control" (the name
//     runBehavioralSkillCase forces for an isControl case, src/cli/index.ts
//     :1442-1444@a46148b): NEVER call the tool, for any query. This is a
//     real 200 response with a real (empty) choices[0].message every time —
//     the control's should-trigger rate is genuinely computed as 0, which is
//     < the manifest's 0.5 threshold, so it genuinely fails via the same
//     grading path an ordinary case uses, not via a network error.
//   - any other tool name (the ordinary case-1's own skill tool): call the
//     tool only when the incoming user message contains the "SHOULDTRIGGER"
//     marker (tests/fixtures/skills-anchor-queries.yaml's shouldTrigger
//     list); never call it for a "NEARMISS"-marked message. This makes
//     case-1 pass both axes genuinely (shouldTrigger rate 1.0 >= 0.5,
//     nearMiss rate 0.0 < 0.5).

const http = require("node:http");

const PORT = Number(process.env.STUB_PORT || 18337);

function readBody(req) {
  return new Promise((resolvePromise, rejectPromise) => {
    let raw = "";
    req.on("data", (chunk) => {
      raw += chunk;
    });
    req.on("end", () => resolvePromise(raw));
    req.on("error", rejectPromise);
  });
}

function toolCallResponse(toolName) {
  return {
    choices: [
      {
        message: {
          tool_calls: [
            {
              id: "call_1",
              type: "function",
              function: { name: toolName, arguments: "{}" },
            },
          ],
        },
      },
    ],
  };
}

function noToolCallResponse() {
  return { choices: [{ message: {} }] };
}

const server = http.createServer((req, res) => {
  if (req.method !== "POST" || !req.url.endsWith("/chat/completions")) {
    res.writeHead(404, { "content-type": "application/json" });
    res.end(JSON.stringify({ error: "not found" }));
    return;
  }

  readBody(req)
    .then((raw) => {
      const parsed = JSON.parse(raw);
      const userMessage = (parsed.messages || []).find((m) => m.role === "user");
      const content = userMessage ? String(userMessage.content) : "";
      const firstTool = (parsed.tools || [])[0];
      const requestedToolName = firstTool?.function ? firstTool.function.name : "";

      let payload;
      if (requestedToolName === "rigged-impossible-control") {
        // Discrimination control: genuinely never fires — real 200/graded response.
        payload = noToolCallResponse();
      } else if (content.includes("SHOULDTRIGGER")) {
        payload = toolCallResponse(requestedToolName);
      } else {
        payload = noToolCallResponse();
      }

      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify(payload));
    })
    .catch((error) => {
      res.writeHead(400, { "content-type": "application/json" });
      res.end(JSON.stringify({ error: String(error) }));
    });
});

server.listen(PORT, () => {
  // Single startup line the caller can grep for readiness.
  console.log(`stub-endpoint listening on http://127.0.0.1:${PORT}`);
});
