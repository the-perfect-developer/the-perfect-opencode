---
name: copilot-sdk
description: This skill should be used when the user asks to "integrate GitHub Copilot into an app", "use the Copilot SDK", "build a Copilot-powered agent", "embed Copilot in a service", or needs guidance on the GitHub Copilot SDK for Python, TypeScript, Go, or .NET.
---

# GitHub Copilot SDK

Guidance for building applications with the GitHub Copilot SDK across TypeScript, Python, Go, and .NET. Covers project setup, session management, custom tools, hooks, MCP integration, custom agents, authentication, and production deployment.

## Installation

Install the SDK for the target language:

```bash
# TypeScript / Node.js
npm install @github/copilot-sdk

# Python
pip install github-copilot-sdk

# Go
go get github.com/github/copilot-sdk/go

# .NET
dotnet add package GitHub.Copilot.SDK
```

**Prerequisite:** GitHub Copilot CLI must be installed and authenticated.

```bash
copilot --version   # verify CLI is available
```

## Core Concepts

The SDK manages a **client → session** hierarchy:

- `CopilotClient` — starts the CLI process (or connects to an external one) and handles authentication
- `Session` — a stateful conversation; send prompts, define tools, subscribe to events
- A client can hold many sessions; sessions are identified by `sessionId`

```
CopilotClient
 └── Session (sessionId: "user-123-task-456")
      ├── Tools (custom functions Copilot may call)
      ├── Hooks (intercept lifecycle events)
      └── Events (stream real-time output)
```

## Creating a Client and Session

```typescript
import { CopilotClient } from "@github/copilot-sdk";

const client = new CopilotClient();
const session = await client.createSession({ model: "gpt-4.1" });

const response = await session.sendAndWait({ prompt: "What is 2 + 2?" });
console.log(response?.data.content);

await client.stop();
```

Python equivalent:

```python
from copilot import CopilotClient
from copilot.session import PermissionHandler

client = CopilotClient()
await client.start()
session = await client.create_session(
    on_permission_request=PermissionHandler.approve_all,
    model="gpt-4.1"
)
response = await session.send_and_wait("What is 2 + 2?")
print(response.data.content)
await client.stop()
```

## Streaming Responses

Enable streaming to receive tokens as they arrive instead of waiting for the full response:

```typescript
const session = await client.createSession({
    model: "gpt-4.1",
    streaming: true,
});

session.on("assistant.message_delta", (event) => {
    process.stdout.write(event.data.deltaContent);
});
session.on("session.idle", () => console.log());

await session.sendAndWait({ prompt: "Tell me a joke" });
```

Use `session.on(handler)` to subscribe to all events, or `session.on(eventType, handler)` in TypeScript for type-safe subscriptions. Both return an unsubscribe function.

## Custom Tools

Define tools to give Copilot the ability to call application code:

```typescript
import { CopilotClient, defineTool } from "@github/copilot-sdk";

const getWeather = defineTool("get_weather", {
    description: "Get the current weather for a city",
    parameters: {
        type: "object",
        properties: {
            city: { type: "string", description: "The city name" },
        },
        required: ["city"],
    },
    handler: async ({ city }: { city: string }) => {
        // Call real weather API in production
        return { city, temperature: "62°F", condition: "cloudy" };
    },
});

const session = await client.createSession({
    model: "gpt-4.1",
    tools: [getWeather],
});
```

Python uses Pydantic for parameter definitions:

```python
from copilot.tools import define_tool
from pydantic import BaseModel, Field

class GetWeatherParams(BaseModel):
    city: str = Field(description="The name of the city")

@define_tool(description="Get the current weather for a city")
async def get_weather(params: GetWeatherParams) -> dict:
    return {"city": params.city, "temperature": "62°F"}
```

How tool invocation works:
1. Copilot sends a tool-call request with resolved parameters
2. The SDK runs the handler function
3. The result is sent back to Copilot
4. Copilot incorporates the result into its response

## Hooks

Hooks intercept session lifecycle events to implement permissions, auditing, and prompt enrichment.

| Hook | Fires when | Returns |
|---|---|---|
| `onSessionStart` | Session begins | `additionalContext` to inject |
| `onUserPromptSubmitted` | User sends a message | `modifiedPrompt` to rewrite |
| `onPreToolUse` | Before a tool executes | `permissionDecision`: `"allow"`, `"deny"`, or `"ask"` |
| `onPostToolUse` | After a tool returns | `modifiedResult` to transform output |
| `onSessionEnd` | Session ends | Cleanup, metrics |
| `onErrorOccurred` | An error is raised | `errorHandling`: `"retry"` or notification |

Register hooks in `createSession`:

```typescript
const session = await client.createSession({
    hooks: {
        onPreToolUse: async (input) => {
            const ALLOWED = new Set(["read_file", "glob", "grep"]);
            if (!ALLOWED.has(input.toolName)) {
                return {
                    permissionDecision: "deny",
                    permissionDecisionReason: `Tool "${input.toolName}" is not permitted.`,
                };
            }
            return { permissionDecision: "allow" };
        },
        onPostToolUse: async (input) => {
            // Redact secrets from tool results before they reach the model
            if (typeof input.toolResult === "string") {
                const redacted = input.toolResult.replace(
                    /api[_-]?key\s*[:=]\s*["']?[\w\-.]+["']?/gi,
                    "[REDACTED]"
                );
                return redacted !== input.toolResult ? { modifiedResult: redacted } : null;
            }
            return null;
        },
    },
    onPermissionRequest: async () => ({ kind: "approved" }),
});
```

**Best practices for hooks:**
- Return `null` when no change is needed — avoids unnecessary allocations
- Keep hooks fast; offload heavy I/O to a background queue
- Scope per-session state by `invocation.sessionId`; clean up in `onSessionEnd`
- Prefer `additionalContext` over `modifiedPrompt` to preserve user intent

For detailed patterns (audit logging, retry on error, prompt shortcuts, metrics), see `references/hooks-patterns.md`.

## Custom Agents and Sub-Agent Orchestration

Define specialized agents scoped to particular tools and system prompts:

```typescript
const session = await client.createSession({
    model: "gpt-4.1",
    customAgents: [
        {
            name: "researcher",
            displayName: "Research Agent",
            description: "Analyzes codebases using read-only tools",
            tools: ["grep", "glob", "view"],
            prompt: "You are a research assistant. Analyze code and answer questions. Do not modify files.",
        },
        {
            name: "editor",
            displayName: "Editor Agent",
            description: "Makes targeted code changes",
            tools: ["view", "edit", "bash"],
            prompt: "You are a code editor. Make minimal, surgical changes.",
        },
    ],
    agent: "researcher",   // pre-select on session start
    onPermissionRequest: async () => ({ kind: "approved" }),
});
```

The runtime auto-selects agents based on user intent and agent `description`. Set `infer: false` on an agent to prevent auto-selection. Sub-agent lifecycle emits events: `subagent.selected`, `subagent.started`, `subagent.completed`, `subagent.failed`.

**Agent design best practices:**
- Write specific `description` values — vague descriptions cause poor delegation
- Use `tools: null` only for unrestricted agents; prefer explicit allow-lists
- Listen for `subagent.failed` and surface errors to users

## MCP Servers

Connect to Model Context Protocol servers for external tool access:

```typescript
const session = await client.createSession({
    mcpServers: {
        // Local process (stdio)
        "filesystem": {
            type: "local",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"],
            tools: ["*"],   // "*" = all tools
        },
        // Remote HTTP server
        "github": {
            type: "http",
            url: "https://api.githubcopilot.com/mcp/",
            headers: { "Authorization": "Bearer ${TOKEN}" },
            tools: ["*"],
        },
    },
});
```

MCP servers can also be scoped per custom agent via the `mcpServers` property on each agent config.

## System Message Customization

Control the model's behavior by appending instructions:

```typescript
const session = await client.createSession({
    systemMessage: {
        content: "Always be concise. Focus on TypeScript best practices.",
    },
});
```

For fine-grained control, use `mode: "customize"` to override individual prompt sections (`tone`, `guidelines`, `code_change_rules`, etc.):

```typescript
systemMessage: {
    mode: "customize",
    sections: {
        tone: { action: "replace", content: "Respond in a professional tone." },
        code_change_rules: { action: "remove" },
        guidelines: { action: "append", content: "\n* Always cite data sources" },
    },
}
```

Available actions: `replace`, `remove`, `append`, `prepend`.

## Session Persistence and Resume

Provide a `sessionId` to make sessions resumable:

```typescript
// Create
const session = await client.createSession({
    sessionId: "user-alice-pr-review-42",
    model: "gpt-4.1",
});

// Later — resume from any client instance
const resumed = await client.resumeSession("user-alice-pr-review-42");
await resumed.sendAndWait({ prompt: "Continue where we left off" });
```

**Session ID naming convention:** encode ownership and purpose — `{userId}-{taskType}-{timestamp}` — to simplify auditing and cleanup.

Session state (conversation history, planning state, artifacts) is persisted to `~/.copilot/session-state/{sessionId}/`. API keys are never persisted; provide BYOK `provider` config again on resume.

Lifecycle management:
- `session.disconnect()` — releases in-memory resources, session remains resumable
- `client.deleteSession(id)` — permanently removes all state from disk
- `client.listSessions()` — enumerate sessions for cleanup or UI

For infinite sessions with automatic context compaction and production deployment patterns, see `references/scaling-deployment.md`.

## Authentication

| Method | When to use |
|---|---|
| Signed-in CLI (default) | Interactive desktop apps, local development |
| OAuth GitHub App token | Web apps acting on behalf of users |
| Environment variable (`COPILOT_GITHUB_TOKEN`) | CI/CD, automation, server-side services |
| BYOK (Bring Your Own Key) | No Copilot subscription; Azure, OpenAI, Anthropic, Ollama |

Priority order: explicit `githubToken` → HMAC key → direct API token → env vars → stored OAuth credentials → `gh` CLI.

BYOK example (Azure AI Foundry):

```typescript
const session = await client.createSession({
    model: "gpt-5.2-codex",
    provider: {
        type: "openai",
        baseUrl: "https://your-resource.openai.azure.com/openai/v1/",
        apiKey: process.env.FOUNDRY_API_KEY,
        wireApi: "responses",   // for GPT-5 series; "completions" for older models
    },
});
```

For complete BYOK provider configs, bearer token auth, Azure native endpoint vs. AI Foundry distinction, and limitations, see `references/authentication.md`.

## Telemetry

Enable OpenTelemetry tracing by passing a `telemetry` config to the client:

```typescript
const client = new CopilotClient({
    telemetry: {
        otlpEndpoint: "http://localhost:4318",
    },
});
```

Trace context (`traceparent`, `tracestate`) propagates automatically between the SDK and CLI. Write to a file instead: `{ filePath: "./traces.jsonl", exporterType: "file" }`.

## Quick Reference

| Task | API |
|---|---|
| Create session | `client.createSession({ model, tools, hooks, ... })` |
| Send and wait | `session.sendAndWait({ prompt })` |
| Stream response | `session.on("assistant.message_delta", handler)` |
| Resume session | `client.resumeSession(sessionId)` |
| Delete session | `client.deleteSession(sessionId)` |
| List sessions | `client.listSessions()` |
| Connect to external CLI | `new CopilotClient({ cliUrl: "localhost:4321" })` |
| BYOK provider | `createSession({ provider: { type, baseUrl, apiKey } })` |

## Additional Resources

### Reference Files

- **`references/authentication.md`** — All auth methods, BYOK provider configs, Ollama/Foundry Local, limitations
- **`references/hooks-patterns.md`** — Audit logging, permission control, prompt enrichment, error recovery, metrics
- **`references/scaling-deployment.md`** — Multi-tenancy patterns, horizontal scaling, Kubernetes/Azure Container deployment, infinite sessions
