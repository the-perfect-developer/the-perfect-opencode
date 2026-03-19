---
name: perfectcode-zen-evaluation
description: This skill should be used when the user asks to "evaluate an implementation", "run the zen evaluation workflow", "check if the plan was properly implemented", "review implementation against a plan", or needs to assess implementation quality and surface improvement suggestions after a zen build cycle.
---

# PerfectCode Zen — Evaluate

A structured evaluation workflow that audits a completed implementation against its
written plan in `.opencode/plans/`, verifies correctness across all quality dimensions,
and produces a scored evaluation report with concrete improvement suggestions.

**Orchestrator**: `@evaluate` agent (or the current agent if `@evaluate` is unavailable)

**Prerequisite**: Both a plan file in `.opencode/plans/` and the implemented code must
exist. Read the plan in full before reviewing a single line of code.

---

## When to Run This Workflow

Trigger this workflow after any Zen build cycle completes — or whenever correctness,
coverage, or plan fidelity needs to be independently audited:

- After `perfectcode-zen-implement` closes its final summary
- When a PR is ready for review and a second opinion is needed
- When regressions or unexpected behaviour surface post-merge
- When the plan changed mid-implementation and alignment must be re-verified
- Periodically during long-running features to catch drift early

---

## Agent Roster

### Orchestrator

| Agent | Role |
|---|---|
| `@evaluate` | Workflow owner — reads plan, assigns evaluators, aggregates findings |

### Evaluators (read-only — no code changes during evaluation)

| Agent | Evaluation focus |
|---|---|
| `@code-analyst` | Plan fidelity, code structure, patterns, and surface coverage |
| `@test-engineer` | Test coverage, edge cases, test quality, and strategy adherence |
| `@security-expert` | Security controls, threat mitigations, unsafe patterns |
| `@performance-engineer` | Hot paths, latency, resource usage, and scalability |
| `@principal-architect` | System design correctness, architectural integrity |
| `@solution-architect` | Service boundaries, interfaces, and cross-component design |
| `@database-architect` | Schema, migrations, queries, data integrity |

Invoke only the evaluators relevant to what the plan covered. Always include
`@code-analyst` and `@test-engineer`. Add domain specialists based on plan scope.

---

## Step 1 — Load the Plan

Locate the plan file in `.opencode/plans/`. Read it in full. Extract and hold
in memory:

- Feature name and scope boundaries (in / out)
- Every architectural decision made and rationale given
- Every explicit "What NOT to do" prohibition
- Security, performance, and database requirements
- Testing strategy and acceptance criteria
- Migration and rollout steps

Do not begin evaluation until the plan is fully read and understood.

---

## Step 2 — Survey the Implementation

Before invoking evaluators, build a map of what was actually built:

- Run `git log --oneline` since the plan was written to enumerate commits
- Run `git diff --stat <base>..<head>` to list all changed files
- Use `@explore` to scan the relevant code surfaces for structure and patterns
- Note any files the plan expected that are absent, or files changed that the
  plan did not mention

This survey is the evaluators' shared ground truth — inject it into every
evaluator prompt so they reason about the real implementation.

---

## Step 3 — Parallel Evaluation

Invoke all relevant evaluators **in parallel**. Each evaluator produces a
structured report covering their domain. Provide every evaluator with:

1. The full plan content
2. The implementation survey from Step 2
3. Their domain-specific evaluation checklist (see `references/evaluation-criteria.md`)

### Evaluation Dimensions

**Plan Fidelity** (`@code-analyst`)
- Does the implementation cover every item listed in the plan's "What to do"?
- Are all explicit prohibitions ("What NOT to do") respected?
- Are scope boundaries honoured — nothing over-built or under-built?
- Do architecture, data flow, and integration points match the plan's design?

**Test Coverage** (`@test-engineer`)
- Are unit, integration, and e2e tests present as the plan required?
- Do tests cover the acceptance criteria and edge cases listed in the plan?
- Is test quality adequate — not just present but meaningful assertions?
- Are critical paths, error paths, and boundary conditions tested?

**Security** (`@security-expert`)
- Are all threat mitigations from the plan in place and correctly applied?
- Are any unsafe patterns or forbidden shortcuts present in the code?
- Are authentication, authorisation, and input validation correct?
- Are secrets, credentials, and sensitive data handled safely?

**Performance** (`@performance-engineer`)
- Are the optimisations specified in the plan applied?
- Are any approaches explicitly ruled out by the plan present anyway?
- Are there obvious hot paths, N+1 queries, or unbounded loops?
- Does the implementation stay within the latency budget or resource constraints?

**Architecture** (`@principal-architect` + `@solution-architect`)
- Does the component structure match the agreed design?
- Are service boundaries and interfaces correct?
- Is coupling appropriate — no unintended tight coupling introduced?
- Are cross-cutting concerns (logging, error handling, observability) consistent?

**Database** (`@database-architect`)
- Does the schema match the plan's data model?
- Are migrations present, reversible, and correctly ordered?
- Are queries efficient and free of injection risk?
- Is data integrity enforced at the correct layer?

---

## Step 4 — Score Each Dimension

Each evaluator scores their domain on a 1–5 scale with a verdict:

| Score | Verdict | Meaning |
|---|---|---|
| 5 | Excellent | Fully implemented; exceeds or exactly matches plan; no issues |
| 4 | Good | Implemented correctly; minor gaps that do not affect function |
| 3 | Acceptable | Core implemented; non-trivial gaps; improvement needed |
| 2 | Needs Work | Significant gaps or deviations; risk to correctness or safety |
| 1 | Failing | Critical requirement missing or anti-pattern present; must fix |

A score of 1 or 2 in any dimension blocks the evaluation from passing.

---

## Step 5 — Aggregate Findings

After all evaluator reports are collected, aggregate into a single evaluation
report. Structure:

1. **Overall verdict** — Pass / Conditional Pass / Fail with one-line rationale
2. **Dimension scores** — table of each evaluator's score and one-line summary
3. **Plan fidelity summary** — what was built vs. what the plan specified;
   explicitly list any missing items or scope violations
4. **Findings** — all issues found, grouped by severity:
   - **Critical** (score 1): must fix before merge; blocks pass
   - **Major** (score 2): significant gap; strong recommendation to fix
   - **Minor** (score 3–4): non-blocking but worth addressing
5. **Improvement suggestions** — concrete, actionable recommendations beyond
   findings; ranked by impact; include code-level specifics where possible
6. **What was done well** — explicit recognition of areas the implementation
   handled correctly or exceeded expectations; not filler — be specific

---

## Step 6 — Save the Evaluation Report

Write the evaluation report to `.opencode/evaluations/<feature-name>.md`,
mirroring the feature name from the plan file. Writing the report is mandatory.

If the plan file is `.opencode/plans/oauth-authentication.md`, the report is
`.opencode/evaluations/oauth-authentication.md`.

---

## Step 7 — Present and Discuss

Present the aggregated report to the user. For each critical or major finding:

- State what was found and where (file, function, line if available)
- Explain why it matters in terms of the plan's intent
- Propose the specific fix or improvement

Ask the user how they want to proceed:
- Fix critical/major findings now (hand off to `perfectcode-zen-implement`)
- Accept minor findings as known technical debt (document them)
- Dispute a finding (re-evaluate with the relevant specialist)

Do not auto-trigger implementation. The evaluation workflow produces findings
and recommendations — acting on them is a separate decision.

---

## Key Rules

- **Read the plan before touching code.** Every finding must trace to a plan requirement or decision.
- **Evaluators are read-only.** No code changes happen during evaluation.
- **Parallel by default.** All evaluator agents run simultaneously.
- **Score every dimension.** A dimension without a score is not evaluated.
- **Critical findings block pass.** A score of 1 in any dimension means the evaluation fails.
- **Findings must be specific.** Vague findings ("code quality could be better") are not acceptable — cite file, function, and plan reference.
- **Suggestions are separate from findings.** A finding is a gap against the plan. A suggestion is an improvement beyond the plan.
- **Save the report.** An evaluation that exists only in chat is not an evaluation. Write it to `.opencode/evaluations/`.
- **Do not auto-implement.** Evaluation ends with a report and recommendations. Implementation is a separate workflow.
- **Acknowledge what was done well.** A report with only negatives is incomplete. Call out correct and excellent work explicitly.

---

## Workflow at a Glance

```
User request
    │
    ▼
Read plan from .opencode/plans/<feature-name>.md (in full)
    │
    ▼
Survey implementation (git log + git diff + @explore)
    │
    ▼
Parallel evaluation
    ├── @code-analyst        → Plan fidelity, patterns, structure
    ├── @test-engineer       → Coverage, quality, edge cases
    ├── @security-expert     → Controls, mitigations, unsafe patterns
    ├── @performance-engineer → Hot paths, latency, efficiency
    ├── @principal-architect → System design, architectural integrity
    ├── @solution-architect  → Service boundaries, interfaces
    └── @database-architect  → Schema, migrations, queries
    │
    ▼
Score each dimension (1–5) + collect findings
    │
    ▼
Aggregate report (verdict, scores, findings, suggestions, positives)
    │
    ▼
Save to .opencode/evaluations/<feature-name>.md
    │
    ▼
Present to user → discuss findings → decide next steps
```

---

## Additional Resources

- **`references/evaluation-criteria.md`** — Per-dimension evaluation checklists and scoring rubrics for each evaluator agent
