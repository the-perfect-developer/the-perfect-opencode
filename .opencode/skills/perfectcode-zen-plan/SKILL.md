---
name: perfectcode-zen-plan
description: This skill should be used when the user asks to "plan a feature", "run the zen planning workflow", "consult all senior agents on a plan", "create a structured plan with agent consultation", or needs a thorough multi-agent planning phase before building anything.
---

# PerfectCode Zen — Plan

A structured planning workflow that routes any feature request through clarification,
mid-tier blueprint production, and senior arbitration when needed, before producing
a written plan stored in `.opencode/plans/`. Nothing gets built without a plan.

**Orchestrator**: `@plan` agent

---

## Agent Tiers

### Tier 1 — Mid-Senior Analysts (blueprint producers)

Mid-tier intelligence, slightly higher temperature. Invoked in parallel to explore
the solution space and produce concrete blueprints. They take the requirements and
return structured findings, trade-offs, and draft decisions.

| Agent | Focus |
|---|---|
| `@code-analyst` | Existing codebase patterns, entry points, affected surfaces |
| `@performance-engineer` | Hot paths, latency budgets, scalability limits |
| `@devops-engineer` | Infrastructure, deployment, CI/CD, observability |
| `@test-engineer` | Testability, coverage strategy, edge cases |
| `@explore` | Open-ended codebase exploration, unfamiliar surfaces |

> Call all relevant Tier 1 agents in parallel. They produce blueprints, not decisions.

### Tier 2 — Principal Consultants (decision makers)

High-cost, low-temperature, deep reasoning. Do **not** call them by default.
Call them only when:

- Tier 1 agents reach conflicting conclusions
- A topic requires expertise beyond Tier 1 capability
- A decision has irreversible or high-risk consequences

They **think, advise, and review**. They do not produce implementation output.

| Agent | Specialty |
|---|---|
| `@principal-architect` | High-level system strategy, cross-service architecture, long-horizon design |
| `@solution-architect` | Translates principal decisions into concrete, implementable designs |
| `@database-architect` | Data modelling, schema design, query optimisation, migration strategy |
| `@security-expert` | Threat modelling, cryptography, authentication, compliance |

> Call Tier 2 agents individually and sequentially, only for the specific domain in conflict.
> Summarise the conflict before invoking them. Do not route all decisions through Tier 2 by default.

---

## Step 1 — Clarify Requirements

Before touching architecture or code, ask focused clarifying questions. Ask as
many as needed to remove ambiguity — wrong assumptions cost more than extra
questions. Typical areas to probe:

- What is the exact scope? (what is explicitly in and out)
- Who are the users and what are their constraints?
- What quality attributes matter most? (security, performance, maintainability)
- Are there existing systems this must integrate with?
- What does "done" look like? (acceptance criteria)

Do not proceed to analysis until requirements are clear.

---

## Step 2 — Parallel Mid-Senior Consultation (Tier 1)

Invoke all relevant Tier 1 agents **in parallel** to analyse the problem from
every angle simultaneously. Select agents based on relevance to the request:

- Always include `@code-analyst` for any task touching existing code.
- Include `@performance-engineer` when load, latency, or throughput is a concern.
- Include `@devops-engineer` when deployment, infra, or pipelines are in scope.
- Include `@test-engineer` for anything that must be verified or tested.
- Include `@explore` when the codebase surface is unfamiliar or large.

Wait for all invoked Tier 1 agents to complete before proceeding. Their outputs
are blueprints — structured findings with trade-offs — not final decisions.

---

## Step 3 — Arbitration via Principal Consultants (Tier 2, conditional)

After collecting Tier 1 blueprints, assess for conflicts, gaps, or high-stakes
decisions. If any of the following are true, escalate to the relevant Tier 2 agent:

- Two or more Tier 1 agents propose incompatible approaches
- A Tier 1 agent signals it lacks the expertise to make a call
- The decision is irreversible, security-critical, or cross-service in scope
- Data modelling or schema changes carry significant migration risk

Escalation protocol:

1. Identify the specific conflict or gap.
2. Summarise it clearly before invoking the Tier 2 agent.
3. Invoke the single most relevant Tier 2 agent (not all four).
4. Incorporate their ruling into the plan as the authoritative decision.

If no conflicts or gaps exist, skip Step 3 entirely.

---

## Step 4 — Synthesise and Write the Plan

Combine the user requirements, Tier 1 blueprints, and any Tier 2 rulings into a
single structured plan document. The plan **must be comprehensive** — it is the
single source of truth for every agent that will implement it. Every perspective
consulted during planning must be represented. Implementers must be able to act
on the plan without asking follow-up questions.

The plan must contain:

1. **Summary** — one-paragraph TL;DR of the feature and its purpose
2. **Scope** — explicit in/out boundaries; list what is included AND what is
   explicitly excluded so implementers do not gold-plate or over-build
3. **Architecture** — component diagram or structured description of the design,
   including data flow, interfaces, and integration points
4. **What to do** — a precise list of actions, patterns, and approaches that
   must be followed, drawn from every Tier 1 and Tier 2 perspective
5. **What NOT to do** — explicit prohibitions, anti-patterns, shortcuts, and
   approaches that were considered and rejected, with a brief rationale for each;
   this prevents implementers from re-introducing discarded ideas
6. **Security considerations** — threats identified and mitigations chosen;
   include both what must be done (controls) and what must not be done
   (unsafe patterns, forbidden shortcuts)
7. **Performance considerations** — expected load, latency budgets, chosen
   optimisations, and approaches explicitly ruled out
8. **DevOps and observability** — deployment approach, environment requirements,
   CI/CD changes, logging, metrics, and alerting expectations
9. **Implementation tasks** — ordered list of concrete coding tasks with assigned
   agent type; each task must be specific enough to act on without clarification
10. **Testing strategy** — unit, integration, and e2e coverage plan; include what
    must be tested, what edge cases must be covered, and what test approaches
    are out of scope
11. **Open questions** — anything unresolved that needs a decision before or
    during implementation; never leave implicit ambiguity in the plan body

The plan is considered comprehensive when a developer reading it for the first
time knows exactly what to build, how to build it, what to avoid, and why every
key decision was made.

---

## Step 5 — Name and Save the Plan

Suggest 3–5 filename options in kebab-case derived from the requirement. Write
the complete plan to `.opencode/plans/<confirmed-name>.md`. Writing the plan
file is mandatory — never skip this step.

---

## Key Rules

- **Ask questions first, always.** Wrong assumptions cost more than extra questions.
- **Tier 1 runs in parallel.** Never run mid-senior agents sequentially when they can overlap.
- **Tier 2 is conditional.** Only escalate on conflict, incapability, or high-stakes decisions.
- **Tier 2 decides, not produces.** They think, advise, and review. They do not write blueprints.
- **Plan file is mandatory.** A plan that exists only in chat is not a plan. Write it to `.opencode/plans/`.
- **The plan must be comprehensive.** It is the single source of truth. Every perspective (architecture, security, performance, DevOps, testing) must be represented with full detail. An implementer must be able to act on it without asking follow-up questions.
- **Explicitly document what NOT to do.** Every rejected approach, anti-pattern, or shortcut must be listed with a rationale. This prevents implementers from re-introducing discarded ideas.
- **No implicit decisions.** Every key decision in the plan must state what was chosen and why. Ambiguity in the plan becomes bugs in implementation.
- **Revise until satisfied.** Keep refining based on user feedback until the plan is confirmed correct.
- **Never implement.** You are only responsible for planning. Do not write any code or implementation output other than the plan file.

---

## Workflow at a Glance

```
User request
    │
    ▼
Clarify requirements (ask questions until clear)
    │
    ▼
Parallel Tier 1 consultation
    ├── @code-analyst
    ├── @performance-engineer
    ├── @devops-engineer
    ├── @test-engineer
    └── @explore
    │
    ▼
Conflicts or gaps? ──yes──► Tier 2 arbitration
    │                           ├── @principal-architect
    │                           ├── @solution-architect
    │                           ├── @database-architect
    │                           └── @security-expert
    │ no                        │
    └───────────────────────────┘
    │
    ▼
Synthesise plan
    │
    ▼
Name and save to .opencode/plans/<name>.md
    │
    ▼
Review with user → revise until confirmed correct
```
