# Hooks Patterns

Practical patterns for the six Copilot SDK session lifecycle hooks. See `tools-and-hooks.md` for the full hook API reference.

## Table of Contents

- [Permission Control — Allow-List](#permission-control--allow-list)
- [Permission Control — Ask User](#permission-control--ask-user)
- [Audit Logging](#audit-logging)
- [Prompt Enrichment](#prompt-enrichment)
- [Prompt Shortcuts](#prompt-shortcuts)
- [Secret Redaction from Tool Results](#secret-redaction-from-tool-results)
- [Error Recovery — Automatic Retry](#error-recovery--automatic-retry)
- [Error Recovery — Notify and Abort](#error-recovery--notify-and-abort)
- [Session Metrics](#session-metrics)
- [Per-Session State Management](#per-session-state-management)
- [Combining Multiple Patterns](#combining-multiple-patterns)

---

## Permission Control — Allow-List

Restrict tools to an explicit allow-list. Deny everything else with a clear reason.

```typescript
// TypeScript
onPreToolUse: async (input) => {
    const ALLOWED = new Set([
        "read_file", "glob", "grep", "view", "list_files",
    ]);
    if (!ALLOWED.has(input.toolName)) {
        return {
            permissionDecision: "deny",
            permissionDecisionReason:
                `Tool "${input.toolName}" is not in the approved list.`,
        };
    }
    return { permissionDecision: "allow" };
},
```

```python
# Python
ALLOWED_TOOLS = {"read_file", "glob", "grep", "view", "list_files"}

async def on_pre_tool_use(input, invocation):
    if input["toolName"] not in ALLOWED_TOOLS:
        return {
            "permissionDecision": "deny",
            "permissionDecisionReason": f"Tool \"{input['toolName']}\" is not in the approved list.",
        }
    return {"permissionDecision": "allow"}
```

**When to use:** Read-only agents, security-hardened sessions, sandboxed environments.

---

## Permission Control — Ask User

Prompt the user for confirmation before running high-risk tools.

```typescript
// TypeScript
onPreToolUse: async (input, invocation) => {
    const HIGH_RISK = new Set(["bash", "delete_file", "write_file"]);
    if (HIGH_RISK.has(input.toolName)) {
        const confirmed = await promptConfirm(
            `Allow "${input.toolName}" with args: ${JSON.stringify(input.toolArgs)}?`
        );
        return {
            permissionDecision: confirmed ? "allow" : "deny",
            permissionDecisionReason: confirmed
                ? "User approved"
                : "User declined",
        };
    }
    return { permissionDecision: "allow" };
},
```

```python
# Python
HIGH_RISK_TOOLS = {"bash", "delete_file", "write_file"}

async def on_pre_tool_use(input, invocation):
    if input["toolName"] in HIGH_RISK_TOOLS:
        answer = input("Allow '{}' with args {}? [y/N]: ".format(
            input["toolName"], input.get("toolArgs")
        ))
        approved = answer.strip().lower() == "y"
        return {
            "permissionDecision": "allow" if approved else "deny",
            "permissionDecisionReason": "User approved" if approved else "User declined",
        }
    return {"permissionDecision": "allow"}
```

**When to use:** Interactive CLI tools, developer agents requiring human-in-the-loop approval.

---

## Audit Logging

Log every tool execution — name, arguments, result summary, timing, and session ID.

```typescript
// TypeScript
hooks: {
    onPreToolUse: async (input, invocation) => {
        auditLog.write({
            event: "tool_start",
            sessionId: invocation.sessionId,
            tool: input.toolName,
            args: input.toolArgs,
            timestamp: Date.now(),
        });
        return { permissionDecision: "allow" };
    },
    onPostToolUse: async (input, invocation) => {
        auditLog.write({
            event: "tool_end",
            sessionId: invocation.sessionId,
            tool: input.toolName,
            durationMs: Date.now() - input.startTime,  // if start time was stored
            resultSize: JSON.stringify(input.toolResult ?? "").length,
            timestamp: Date.now(),
        });
        return null;
    },
},
```

```python
# Python
import time

async def on_pre_tool_use(input, invocation):
    audit_log.write({
        "event": "tool_start",
        "session_id": invocation["sessionId"],
        "tool": input["toolName"],
        "args": input.get("toolArgs"),
        "timestamp": time.time(),
    })
    return {"permissionDecision": "allow"}

async def on_post_tool_use(input, invocation):
    audit_log.write({
        "event": "tool_end",
        "session_id": invocation["sessionId"],
        "tool": input["toolName"],
        "result_size": len(str(input.get("toolResult", ""))),
        "timestamp": time.time(),
    })
    return None
```

**Best practice:** Write to a structured log (JSONL, database) rather than stdout. Include `sessionId` on every record so audit trails are linkable per conversation.

---

## Prompt Enrichment

Inject dynamic context into the session at start time — user preferences, role, environment info.

```typescript
// TypeScript
onSessionStart: async (input, invocation) => {
    const userId = extractUserId(invocation.sessionId);
    const [prefs, role] = await Promise.all([
        userStore.getPreferences(userId),
        authService.getRole(userId),
    ]);
    return {
        additionalContext: [
            `User role: ${role}`,
            `Language preference: ${prefs.language}`,
            `Timezone: ${prefs.timezone}`,
            `Environment: ${process.env.NODE_ENV}`,
        ].join("\n"),
    };
},
```

```python
# Python
async def on_session_start(input, invocation):
    user_id = extract_user_id(invocation["sessionId"])
    prefs, role = await asyncio.gather(
        user_store.get_preferences(user_id),
        auth_service.get_role(user_id),
    )
    return {
        "additionalContext": "\n".join([
            f"User role: {role}",
            f"Language preference: {prefs['language']}",
            f"Timezone: {prefs['timezone']}",
        ]),
    }
```

**When to use:** Multi-tenant apps where the model needs per-user context injected at session start without modifying user prompts.

**Prefer `additionalContext` over `modifiedPrompt`** when adding context — it preserves original user intent. Use `modifiedPrompt` only to transform or sanitize the prompt itself.

---

## Prompt Shortcuts

Expand shorthand triggers in user prompts before they reach the model.

```typescript
// TypeScript
const SHORTCUTS: Record<string, string> = {
    "/review": "Review the current code for correctness, style, and performance.",
    "/test":   "Write comprehensive unit tests for the selected code.",
    "/doc":    "Write JSDoc/docstring documentation for the selected code.",
};

onUserPromptSubmitted: async (input) => {
    const expanded = SHORTCUTS[input.prompt.trim()];
    return expanded ? { modifiedPrompt: expanded } : null;
},
```

```python
# Python
SHORTCUTS = {
    "/review": "Review the current code for correctness, style, and performance.",
    "/test":   "Write comprehensive unit tests for the selected code.",
    "/doc":    "Write docstring documentation for the selected code.",
}

async def on_user_prompt_submitted(input, invocation):
    expanded = SHORTCUTS.get(input["prompt"].strip())
    return {"modifiedPrompt": expanded} if expanded else None
```

---

## Secret Redaction from Tool Results

Strip API keys and tokens from tool outputs before they reach the model context.

```typescript
// TypeScript
const SECRET_PATTERN = /(?:api[_-]?key|secret|token|password)\s*[:=]\s*["']?[\w\-.]+["']?/gi;

onPostToolUse: async (input) => {
    if (typeof input.toolResult !== "string") return null;
    const redacted = input.toolResult.replace(SECRET_PATTERN, "[REDACTED]");
    return redacted !== input.toolResult ? { modifiedResult: redacted } : null;
},
```

```python
# Python
import re

SECRET_PATTERN = re.compile(
    r"(?:api[_\-]?key|secret|token|password)\s*[:=]\s*[\"']?[\w\-.]+[\"']?",
    re.IGNORECASE,
)

async def on_post_tool_use(input, invocation):
    result = input.get("toolResult")
    if not isinstance(result, str):
        return None
    redacted = SECRET_PATTERN.sub("[REDACTED]", result)
    return {"modifiedResult": redacted} if redacted != result else None
```

**Note:** Return `null` / `None` when nothing changes — avoids unnecessary result replacement overhead.

---

## Error Recovery — Automatic Retry

Retry transient errors (network timeouts, rate limits) automatically; abort on permanent failures.

```typescript
// TypeScript
onErrorOccurred: async (input) => {
    const TRANSIENT = ["ECONNRESET", "ETIMEDOUT", "429"];
    const isTransient = TRANSIENT.some(code =>
        String(input.error).includes(code)
    );

    logger.warn({
        event: "copilot_error",
        context: input.errorContext,
        error: String(input.error),
        handling: isTransient ? "retry" : "abort",
    });

    return { errorHandling: isTransient ? "retry" : "abort" };
},
```

```python
# Python
TRANSIENT_CODES = {"ECONNRESET", "ETIMEDOUT", "429"}

async def on_error_occurred(input, invocation):
    error_str = str(input["error"])
    is_transient = any(code in error_str for code in TRANSIENT_CODES)

    logger.warning({
        "event": "copilot_error",
        "context": input["errorContext"],
        "error": error_str,
        "handling": "retry" if is_transient else "abort",
    })

    return {"errorHandling": "retry" if is_transient else "abort"}
```

**`errorHandling` values:**

| Value | Behavior |
|---|---|
| `"retry"` | Retry the failed operation once |
| `"skip"` | Skip the failed step and continue the session |
| `"abort"` | Abort the current request entirely |

---

## Error Recovery — Notify and Abort

Surface errors to the user via a notification system, then abort the request.

```typescript
// TypeScript
onErrorOccurred: async (input, invocation) => {
    await notificationService.send({
        userId: extractUserId(invocation.sessionId),
        message: `Copilot encountered an error: ${input.errorContext}`,
        severity: "error",
    });
    return { errorHandling: "abort" };
},
```

```python
# Python
async def on_error_occurred(input, invocation):
    user_id = extract_user_id(invocation["sessionId"])
    await notification_service.send(
        user_id=user_id,
        message=f"Copilot encountered an error: {input['errorContext']}",
        severity="error",
    )
    return {"errorHandling": "abort"}
```

---

## Session Metrics

Track session duration, tool call counts, and prompt/response counts per session.

```typescript
// TypeScript
// Store created in module scope, keyed by sessionId
const sessionMetrics = new Map<string, {
    startTime: number;
    toolCalls: number;
    promptCount: number;
}>();

hooks: {
    onSessionStart: async (input, invocation) => {
        sessionMetrics.set(invocation.sessionId, {
            startTime: Date.now(),
            toolCalls: 0,
            promptCount: 0,
        });
        return null;
    },
    onPreToolUse: async (input, invocation) => {
        const m = sessionMetrics.get(invocation.sessionId);
        if (m) m.toolCalls++;
        return { permissionDecision: "allow" };
    },
    onUserPromptSubmitted: async (input, invocation) => {
        const m = sessionMetrics.get(invocation.sessionId);
        if (m) m.promptCount++;
        return null;
    },
    onSessionEnd: async (input, invocation) => {
        const m = sessionMetrics.get(invocation.sessionId);
        if (m) {
            metrics.record("session_ended", {
                sessionId: invocation.sessionId,
                durationMs: Date.now() - m.startTime,
                toolCalls: m.toolCalls,
                promptCount: m.promptCount,
            });
            sessionMetrics.delete(invocation.sessionId);
        }
    },
},
```

```python
# Python
from collections import defaultdict
import time

session_metrics: dict[str, dict] = {}

async def on_session_start(input, invocation):
    session_metrics[invocation["sessionId"]] = {
        "start_time": time.time(),
        "tool_calls": 0,
        "prompt_count": 0,
    }
    return None

async def on_pre_tool_use(input, invocation):
    m = session_metrics.get(invocation["sessionId"])
    if m:
        m["tool_calls"] += 1
    return {"permissionDecision": "allow"}

async def on_user_prompt_submitted(input, invocation):
    m = session_metrics.get(invocation["sessionId"])
    if m:
        m["prompt_count"] += 1
    return None

async def on_session_end(input, invocation):
    m = session_metrics.pop(invocation["sessionId"], None)
    if m:
        metrics.record("session_ended", {
            "session_id": invocation["sessionId"],
            "duration_s": time.time() - m["start_time"],
            "tool_calls": m["tool_calls"],
            "prompt_count": m["prompt_count"],
        })
```

---

## Per-Session State Management

Use `invocation.sessionId` as the key for all in-process session state; always clean up in `onSessionEnd`.

```typescript
// TypeScript
type SessionState = {
    userId: string;
    startTime: number;
    toolCallLog: Array<{ tool: string; ts: number }>;
};

const state = new Map<string, SessionState>();

hooks: {
    onSessionStart: async (input, invocation) => {
        state.set(invocation.sessionId, {
            userId: extractUserId(invocation.sessionId),
            startTime: Date.now(),
            toolCallLog: [],
        });
        return null;
    },
    onPreToolUse: async (input, invocation) => {
        state.get(invocation.sessionId)?.toolCallLog.push({
            tool: input.toolName,
            ts: Date.now(),
        });
        return { permissionDecision: "allow" };
    },
    onSessionEnd: async (input, invocation) => {
        state.delete(invocation.sessionId);   // prevent memory leaks
    },
},
```

**Rules:**
- Always scope state by `sessionId` — never by user ID alone (users may have concurrent sessions)
- Always delete state in `onSessionEnd` to prevent unbounded memory growth
- For multi-process deployments, use Redis or a shared store instead of in-process `Map`

---

## Combining Multiple Patterns

Production hooks typically compose several patterns. Register them all in a single `hooks` object:

```typescript
// TypeScript — production hook composition
const session = await client.createSession({
    model: "gpt-4.1",
    hooks: {
        onSessionStart:        enrichWithUserContext,
        onUserPromptSubmitted: expandShortcuts,
        onPreToolUse:          enforceAllowListAndLog,
        onPostToolUse:         redactSecretsAndLog,
        onSessionEnd:          flushMetricsAndCleanup,
        onErrorOccurred:       retryOrNotify,
    },
    onPermissionRequest: async () => ({ kind: "approved" }),
});
```

Keep each handler focused on a single responsibility — compose behavior by chaining separate concerns within each hook function, and use shared module-level state (keyed by `sessionId`) to pass data between hooks.
