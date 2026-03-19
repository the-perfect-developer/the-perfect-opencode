---
name: perfectcode-zen-implement
description: This skill should be used when the user asks to "implement a zen plan", "execute the zen workflow", "run parallel agent implementation", "build from an opencode plan", or needs to execute a written plan from .opencode/plans/ using parallel engineering agents with quality gates.
---

# PerfectCode Zen — Implement

A structured implementation workflow that executes a written plan from
`.opencode/plans/` using parallel engineering agents, followed by quality gates
and testing. Nothing is declared done until all tests pass.

**Orchestrator**: `build` agent — this workflow is always started and driven by
the `build` agent. The build agent reads the plan, decomposes work, delegates
to coders, escalates to consultants when blocked, and closes the workflow.

**Prerequisite**: A plan file must exist in `.opencode/plans/`. Read it
carefully and thoroughly before doing anything else. Every decision must trace
back to the plan. Do not improvise, skip, or reinterpret scope.

---

## Step 1 — Start as the Build Agent

This workflow is owned by the `build` agent from start to finish. The build
agent does not write code — it orchestrates. Its responsibilities are:

- Read and deeply understand the plan in `.opencode/plans/`
- Decompose the plan into atomic implementation tasks
- Delegate tasks to `developer-prime` and `developer-fast`
- Escalate to consultants the moment anything is unclear, blocked, or risky
- Verify quality gates and ensure all tests pass before closing

**Do not skip this agent assignment.** The build agent is the single point of
accountability for the entire workflow.

---

## Step 2 — Read the Plan Carefully and Thoroughly

Locate the plan file in `.opencode/plans/`. Read it in full before taking any
action. Pay close attention to:

- Goals and scope
- Architecture and design decisions
- Implementation tasks and their dependencies
- Security, performance, and database considerations
- Testing strategy and acceptance criteria

**Follow every instruction in the plan thoroughly.** The plan is the source of
truth. If the plan says to do something a specific way, do it that way exactly.
Do not improvise. If something in the plan is ambiguous, escalate to the
appropriate consultant before proceeding (see Step 4).

---

## Step 3 — Decompose and Track All Tasks

Break every implementation item in the plan into atomic, actionable tasks.
Register all tasks in TodoWrite immediately. Rules:

- Mark a task `in_progress` the moment work begins on it
- Mark a task `completed` the moment it is verifiably done — do not batch
- Only one task should be `in_progress` at a time
- Never declare a task complete without evidence (tests pass, code reviewed)

---

## Step 4 — Delegate to Coders

Assign implementation tasks to the appropriate coder agent and run independent
tasks in parallel:

| Task type | Assigned agent |
|---|---|
| Complex, multi-file, or long-context work | `developer-prime` |
| Scoped, single-file, boilerplate, or high-volume tasks | `developer-fast` |

Run all independent tasks simultaneously. Never serialise work that can be
parallelised.

---

## Step 5 — Consult Immediately When Blocked or Uncertain

If anything goes wrong, gets stuck, requires a decision not covered by the
plan, or carries architectural/security/data risk — **stop and consult before
continuing**. Do not guess. Do not proceed on assumptions.

Escalate to the relevant consultant(s) immediately and in parallel if multiple
perspectives are needed:

| Situation | Consult |
|---|---|
| Architecture or system design question | `principal-architect` |
| Service design or cross-component decision | `solution-architect` |
| Data model, schema, or query concern | `database-architect` |
| Security, auth, or threat modelling concern | `security-expert` |

Consultants operate in **Think → Advise → Review** mode: they analyse the
situation, give a concrete recommendation, and review the outcome. Their
guidance must be incorporated before work continues.

**Consultation is not optional when blocked.** It is a required part of the
workflow.

---

## Step 6 — Quality Gates

After all coding tasks complete, run the following reviews **in parallel**
before declaring the implementation done:

- `security-expert` — verify all security mitigations from the plan are correctly implemented
- `principal-architect` — verify the implementation matches the agreed design
- `solution-architect` — verify service boundaries and interfaces are correct
- `database-architect` — verify schema, migrations, and queries are sound

Address every finding before moving to testing.

---

## Step 7 — Testing and Validation

Run the project's full test suite. If tests are missing for new code, delegate
to `developer-fast` to add them per the testing strategy defined in the plan.
All tests must pass before the workflow closes. No exceptions.

---

## Step 8 — Final Summary

Present a concise summary covering:

- What was built
- Which agents contributed
- Any deviations from the original plan and their justifications
- Test results

---

## Key Rules

- **Build agent owns the workflow.** This workflow starts and ends with the build agent.
- **Read the plan carefully and thoroughly.** Every action must trace to the plan.
- **Follow instructions thoroughly.** Do exactly what the plan specifies. Do not reinterpret or skip steps.
- **Delegate to developer-prime and developer-fast.** These are the two coder agents in this workflow.
- **Consult immediately when blocked.** principal-architect, solution-architect, database-architect, and security-expert are on call for Think → Advise → Review.
- **Parallel by default.** Never run independent tasks or consultations sequentially.
- **Track every task.** Use TodoWrite throughout. No task is done until marked completed.
- **Quality gates are mandatory.** Do not skip the parallel review step before testing.
- **All tests must pass.** Do not close the workflow with failing tests.

---

## Agent Roster

### Orchestrator

| Agent | Role |
|---|---|
| `build` | Workflow owner — reads plan, delegates, escalates, closes |

### Implementers (write code)

| Agent | Specialty |
|---|---|
| `developer-prime` | Complex, multi-file, long-context, and frontend tasks |
| `developer-fast` | Scoped, single-file, boilerplate, and high-volume tasks |

### Consultants (Think → Advise → Review — read-only, no code changes)

| Agent | Specialty |
|---|---|
| `principal-architect` | High-level system strategy, cross-service architecture, technical governance |
| `solution-architect` | Concrete service designs, cross-component interfaces |
| `database-architect` | Data modelling, schema, query optimisation, migrations |
| `security-expert` | Threat modelling, cryptography, auth, secure coding |

---

## Workflow at a Glance

```
Build agent starts
    │
    ▼
Read plan from .opencode/plans/<name>.md (carefully and thoroughly)
    │
    ▼
Decompose into atomic tasks (TodoWrite)
    │
    ▼
Parallel implementation
    ├── developer-prime  (complex / multi-file)
    └── developer-fast   (scoped / single-file)
    │
    ▼ (if blocked or uncertain at any point)
Consult immediately (in parallel as needed)
    ├── principal-architect  → Think, Advise, Review
    ├── solution-architect   → Think, Advise, Review
    ├── database-architect   → Think, Advise, Review
    └── security-expert      → Think, Advise, Review
    │
    ▼
Parallel quality gates
    ├── security-expert
    ├── principal-architect
    ├── solution-architect
    └── database-architect
    │
    ▼
Testing and validation (all tests must pass)
    │
    ▼
Final summary
```
