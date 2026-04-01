# Scaling and Deployment

Production deployment patterns for the GitHub Copilot SDK: multi-tenancy, horizontal scaling, infinite sessions, and containerized deployments.

## Table of Contents

- [Session ID Design for Multi-Tenancy](#session-id-design-for-multi-tenancy)
- [Infinite Sessions with Context Compaction](#infinite-sessions-with-context-compaction)
- [Session Locking (Multi-Process)](#session-locking-multi-process)
- [Horizontal Scaling Pattern](#horizontal-scaling-pattern)
- [External CLI Server Mode](#external-cli-server-mode)
- [Kubernetes Deployment](#kubernetes-deployment)
- [Azure Container Apps Deployment](#azure-container-apps-deployment)
- [Health Checks and Graceful Shutdown](#health-checks-and-graceful-shutdown)
- [Session Lifecycle Management](#session-lifecycle-management)
- [Resource Limits and Timeouts](#resource-limits-and-timeouts)

---

## Session ID Design for Multi-Tenancy

Session IDs are arbitrary strings — encode ownership and purpose to enable auditing, routing, and cleanup.

**Recommended format:** `{tenantId}-{userId}-{taskType}-{timestamp}`

```typescript
// TypeScript
function makeSessionId(tenantId: string, userId: string, taskType: string): string {
    return `${tenantId}-${userId}-${taskType}-${Date.now()}`;
}

// Examples
makeSessionId("acme", "user-alice", "pr-review");   // acme-user-alice-pr-review-1712345678901
makeSessionId("acme", "user-bob",   "refactor");    // acme-user-bob-refactor-1712345679001
```

```python
# Python
import time

def make_session_id(tenant_id: str, user_id: str, task_type: str) -> str:
    return f"{tenant_id}-{user_id}-{task_type}-{int(time.time() * 1000)}"
```

**Benefits:**
- Easy per-tenant cleanup: `listSessions()` and filter by prefix
- Audit logs are naturally grouped by tenant and user
- Session routing is deterministic — any server handling `acme-*` sessions can resume them

---

## Infinite Sessions with Context Compaction

Long-running sessions will eventually hit the model's context window. Use the `maxTurns` option and handle the `context.compacted` event to summarize and continue.

```typescript
// TypeScript
const session = await client.createSession({
    sessionId: makeSessionId(tenantId, userId, "chat"),
    model: "gpt-4.1",
    maxTurns: 50,    // compact after 50 turns
});

session.on("context.compacted", async (event) => {
    // SDK auto-compacts — resume seamlessly
    console.log(`Context compacted: ${event.data.removedTurns} turns summarized`);
});

// Disconnect and resume pattern for long-running tasks
await session.sendAndWait({ prompt: "Start the analysis" });
await session.disconnect();   // release in-memory resources, state persisted to disk

// Later (same or different process)
const resumed = await client.resumeSession(sessionId);
await resumed.sendAndWait({ prompt: "Continue the analysis" });
```

```python
# Python
session = await client.create_session(
    session_id=make_session_id(tenant_id, user_id, "chat"),
    model="gpt-4.1",
    max_turns=50,
)

async def on_context_compacted(event):
    print(f"Context compacted: {event['data']['removedTurns']} turns summarized")

session.on("context.compacted", on_context_compacted)

await session.send_and_wait("Start the analysis")
await session.disconnect()

# Later
resumed = await client.resume_session(session_id)
await resumed.send_and_wait("Continue the analysis")
```

**Session state persisted:** Conversation history, planning state, artifacts — stored at `~/.copilot/session-state/{sessionId}/`.

**API keys are never persisted.** Provide BYOK `provider` config again when resuming.

---

## Session Locking (Multi-Process)

The SDK does not handle concurrent access to the same session across processes. Implement application-level locking with Redis or a database.

```typescript
// TypeScript — Redis-based session lock
import { createClient } from "redis";

const redis = createClient();

async function withSessionLock<T>(
    sessionId: string,
    ttlMs: number,
    fn: () => Promise<T>
): Promise<T> {
    const lockKey = `copilot:lock:${sessionId}`;
    const acquired = await redis.set(lockKey, "1", {
        PX: ttlMs,
        NX: true,   // only set if not exists
    });

    if (!acquired) {
        throw new Error(`Session ${sessionId} is already in use`);
    }

    try {
        return await fn();
    } finally {
        await redis.del(lockKey);
    }
}

// Usage
const response = await withSessionLock(sessionId, 30_000, async () => {
    const session = await client.resumeSession(sessionId);
    return session.sendAndWait({ prompt: userPrompt });
});
```

```python
# Python — Redis-based session lock
import aioredis
from contextlib import asynccontextmanager

redis = aioredis.from_url("redis://localhost")

@asynccontextmanager
async def session_lock(session_id: str, ttl_ms: int = 30_000):
    lock_key = f"copilot:lock:{session_id}"
    acquired = await redis.set(lock_key, "1", px=ttl_ms, nx=True)
    if not acquired:
        raise RuntimeError(f"Session {session_id} is already in use")
    try:
        yield
    finally:
        await redis.delete(lock_key)

# Usage
async with session_lock(session_id):
    session = await client.resume_session(session_id)
    response = await session.send_and_wait(user_prompt)
```

---

## Horizontal Scaling Pattern

Because session state is persisted to disk by the CLI, multi-process scaling requires a shared filesystem or session affinity.

**Option A — Shared filesystem (NFS / Azure Files / EFS):**
Mount the session state directory (`~/.copilot/session-state/`) to a shared volume. All instances read and write the same sessions. Combined with Redis locking (see above) to prevent concurrent access.

**Option B — Session affinity (sticky sessions):**
Route all requests for a given `sessionId` to the same process. Use a consistent hash ring or a routing table in Redis keyed by `sessionId → instanceId`.

```
                   ┌─ instance-1 ─ sessions: [alice-*, bob-*]
Load balancer ────┤
                   └─ instance-2 ─ sessions: [carol-*, dave-*]
```

**Option C — Single CLI server with multiple SDK clients:**
Run one CLI process in `--server` mode; connect multiple SDK clients to it via `cliUrl`. The CLI serializes session access internally.

```typescript
// TypeScript — connect to shared external CLI
const client = new CopilotClient({
    cliUrl: process.env.COPILOT_CLI_URL ?? "localhost:4321",
});
```

---

## External CLI Server Mode

Run the Copilot CLI as a standalone server and connect multiple SDK clients to it. Useful for sharing one authenticated CLI process across many app instances.

```bash
# Start the CLI server
copilot --server --port 4321
```

```typescript
// TypeScript — connect all clients to the shared server
const client = new CopilotClient({
    cliUrl: "localhost:4321",
});
```

```python
# Python
client = CopilotClient({"cli_url": "localhost:4321"})
await client.start()
```

**Constraints:**
- `cliUrl` is mutually exclusive with `useLoggedInUser: false`
- The CLI server must be running before any client connects
- The server uses a single authentication context — all sessions share the same GitHub token

---

## Kubernetes Deployment

Recommended deployment for production multi-tenant workloads:

```yaml
# k8s deployment snippet
apiVersion: apps/v1
kind: Deployment
metadata:
  name: copilot-service
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: app
          image: your-registry/copilot-service:latest
          env:
            - name: COPILOT_GITHUB_TOKEN
              valueFrom:
                secretKeyRef:
                  name: copilot-secrets
                  key: github-token
            - name: REDIS_URL
              value: redis://redis-service:6379
          volumeMounts:
            - name: session-state
              mountPath: /root/.copilot/session-state
      volumes:
        - name: session-state
          persistentVolumeClaim:
            claimName: copilot-session-pvc   # ReadWriteMany (NFS/EFS/Azure Files)
```

**Session state PVC** must be `ReadWriteMany` if multiple replicas share sessions. Combine with Redis locking.

**Liveness probe example:**

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 15
  periodSeconds: 20
```

---

## Azure Container Apps Deployment

```yaml
# Azure Container Apps job definition (abbreviated)
properties:
  configuration:
    secrets:
      - name: copilot-token
        value: $(COPILOT_GITHUB_TOKEN)
  template:
    containers:
      - name: copilot-service
        image: your-registry.azurecr.io/copilot-service:latest
        env:
          - name: COPILOT_GITHUB_TOKEN
            secretRef: copilot-token
        volumeMounts:
          - volumeName: session-state
            mountPath: /root/.copilot/session-state
    volumes:
      - name: session-state
        storageType: AzureFile
        storageName: copilot-session-storage
```

Use **Azure Files** (SMB) or **NFS** mount for the session state volume. Enable **session affinity** on the Container Apps ingress if using Option B routing.

---

## Health Checks and Graceful Shutdown

```typescript
// TypeScript — Express health check + graceful shutdown
import express from "express";
import { CopilotClient } from "@github/copilot-sdk";

const app = express();
const client = new CopilotClient();
await client.start();

app.get("/health", (_req, res) => {
    res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// Graceful shutdown
async function shutdown(): Promise<void> {
    console.log("Shutting down...");
    // Disconnect all active sessions (preserves state)
    for (const sessionId of activeSessions) {
        const session = activeSessions.get(sessionId);
        await session?.disconnect();
    }
    await client.stop();
    process.exit(0);
}

process.on("SIGTERM", shutdown);
process.on("SIGINT",  shutdown);
```

```python
# Python — FastAPI health check + shutdown
from fastapi import FastAPI
from copilot import CopilotClient
import asyncio, signal

app = FastAPI()
client = CopilotClient()

@app.on_event("startup")
async def startup():
    await client.start()

@app.on_event("shutdown")
async def shutdown():
    for session in active_sessions.values():
        await session.disconnect()
    await client.stop()

@app.get("/health")
def health():
    return {"status": "ok"}
```

---

## Session Lifecycle Management

Implement a reaper to clean up stale sessions and prevent unbounded disk growth.

```typescript
// TypeScript — session reaper
const MAX_AGE_MS = 24 * 60 * 60 * 1000;  // 24 hours

async function reapStaleSessions(): Promise<void> {
    const sessions = await client.listSessions();
    const now = Date.now();

    for (const session of sessions) {
        const age = now - new Date(session.lastActivity).getTime();
        if (age > MAX_AGE_MS) {
            await client.deleteSession(session.sessionId);
            console.log(`Deleted stale session: ${session.sessionId}`);
        }
    }
}

// Run every hour
setInterval(reapStaleSessions, 60 * 60 * 1000);
```

```python
# Python — session reaper
import asyncio
from datetime import datetime, timedelta

MAX_AGE = timedelta(hours=24)

async def reap_stale_sessions():
    while True:
        await asyncio.sleep(3600)
        sessions = await client.list_sessions()
        now = datetime.utcnow()
        for session in sessions:
            age = now - datetime.fromisoformat(session["lastActivity"])
            if age > MAX_AGE:
                await client.delete_session(session["sessionId"])
```

**Session state APIs:**

| Method | Description |
|---|---|
| `session.disconnect()` | Release in-memory resources; state preserved on disk |
| `client.resumeSession(id)` | Re-attach to a persisted session |
| `client.deleteSession(id)` | Permanently remove all state from disk |
| `client.listSessions()` | Enumerate all persisted sessions |

---

## Resource Limits and Timeouts

**CLI idle timeout:** The CLI process has a built-in 30-minute idle timeout. For long-running sessions, ensure steady activity or implement a keep-alive ping.

```typescript
// TypeScript — keep-alive ping every 20 minutes
const keepAlive = setInterval(async () => {
    if (session.isIdle()) {
        await session.sendAndWait({ prompt: "/noop" });
    }
}, 20 * 60 * 1000);

// Clear on session end
session.hooks.onSessionEnd = async () => clearInterval(keepAlive);
```

**Memory management:** Each SDK client holds one CLI subprocess. For services handling thousands of concurrent sessions, prefer the External CLI Server mode (one subprocess shared across all clients) over per-request client instantiation.

**Recommended resource allocation per CLI process:**

| Resource | Recommended |
|---|---|
| CPU | 0.5–1 vCPU |
| Memory | 512 MB – 1 GB |
| Disk (session state) | 1–10 GB depending on session volume |
| Network | Outbound HTTPS to `api.github.com` |
