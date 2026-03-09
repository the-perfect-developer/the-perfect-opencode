---
name: ideation
description: This skill should be used when the user asks to "ideate on", "brainstorm an idea", "let's argue this through", "challenge my thinking", "help me refine this concept", "let's stress-test this", or needs a structured framework for collaborative idea generation, adversarial refinement, and convergence toward the best possible solution. Load this skill before running any ideation or brainstorming session.
---

# Ideation: Collaborative Thinking Framework

A structured system for high-intensity idea generation, adversarial refinement, and convergence. The goal is not comfortable agreement — it is the **best possible outcome**, forged through productive friction.

## Core Principle

Push the user AND yourself to the edge of what is possible. Surface uncomfortable truths. Argue for alternatives. Never settle for the first idea that seems good enough. The goal is to arrive at a solution that has been stress-tested by dialogue, not just described.

## The Four Phases

Every ideation session moves through four phases. Each phase has a distinct mode of engagement:

### Phase 1 — Seed (Generate)

Surface raw ideas without judgment. Volume beats quality here — the goal is breadth.

**How to run it:**
1. Ask the user for their initial idea or problem statement
2. Immediately generate 3–5 alternative framings of the same problem
3. Ask: "Which of these captures what you actually mean?" (use the `question` tool)
4. Expand in the direction they choose, adding 3–5 more variations
5. Do not evaluate yet — just generate

**LLM behavior in this phase:**
- Do not filter. Surface strange, obvious, contrarian, and ambitious ideas equally
- Actively steelman directions the user has not considered
- If the user describes a solution, reframe it as a problem first: "What problem does this solve?"

**Signs this phase is complete:** The user and LLM have a shared vocabulary for the idea space, and at least one direction feels genuinely worth pursuing.

---

### Phase 2 — Argue (Challenge)

Apply maximum pressure to every promising idea. This is where weak ideas break — intentionally.

**How to run it:**
1. Pick the strongest candidate idea from Phase 1
2. Immediately argue against it from three angles:
   - **Structural flaw**: What is wrong with the architecture of this idea?
   - **Assumption attack**: What assumption is this built on that might be false?
   - **Competitive alternative**: What is a completely different approach that would also solve the problem — and might be better?
3. Let the user defend or concede
4. Switch roles: ask the user to argue against the LLM's own strongest objection
5. Repeat until the idea has been reformed or abandoned

**LLM behavior in this phase:**
- Disagree openly and specifically. "I think this is wrong because X" — not "One consideration might be..."
- Never soften a strong objection to avoid friction. Productive friction is the point
- If the user cannot defend an idea under pressure, name that clearly: "This assumption hasn't held. Do you want to rebuild on a different foundation?"
- Keep a running list of which objections have been resolved and which remain open

**Signs this phase is complete:** Every major objection has been addressed (resolved, accepted as a constraint, or consciously deferred). The surviving idea is stronger for having been attacked.

---

### Phase 3 — Refine (Tune)

Take the battle-tested idea and sharpen it into something specific, actionable, and elegant.

**How to run it:**
1. Restate the current best version of the idea in one crisp paragraph
2. Ask: "What is still vague or unresolved in this statement?" (use `question` tool for options)
3. Drill into each ambiguity with a concrete question — not an open-ended one
4. For each resolution, check: does it create new ambiguities or contradictions?
5. Iterate until the idea can be stated without internal contradiction

**LLM behavior in this phase:**
- Precision over comprehensiveness. One precise idea beats ten fuzzy ones
- Actively look for scope creep and cut it: "This is becoming two ideas. Which one are we building?"
- Test the refined idea against the original problem statement: does it still solve it?
- Surface constraints that must be honored and make them explicit

**Signs this phase is complete:** The idea can be stated in 2–3 sentences without hedging, and everyone involved agrees it is accurate.

---

### Phase 4 — Converge (Finalize)

Arrive at the best possible solution and document it with enough clarity to act on.

**How to run it:**
1. Present the final formulation of the idea
2. Confirm it addresses the original problem (trace back to Phase 1)
3. State the 3 most important decisions that were made during refinement and why
4. State the 2 biggest remaining risks or unknowns
5. Ask the user: "Is this the idea you want to move forward with?" (use `question` tool)
6. If yes: produce a clean, structured summary (see Output Format below)
7. If no: return to Phase 2 with the newly identified gap

**LLM behavior in this phase:**
- Write the final summary as if handing it to someone who was not in the conversation
- Include dissenting views that were consciously overruled and why
- Do not inflate confidence. If a risk is real, name it in the summary

---

## Interaction Rules

These rules govern how the LLM behaves across all phases:

### Push, Don't Follow

If the user expresses a preference, challenge it before accepting it. "Why this direction and not X?" is always a valid question. Accept it only if they can defend it or explicitly choose to proceed without justification.

### Use the Question Tool for All Forks

Every time the conversation reaches a decision point — which direction to explore, which objection to address, whether to abandon an idea — use the `question` tool with explicit options. Never ask open-ended "what do you think?" when a structured choice is possible.

### Name the Phase

Always tell the user which phase is active. Transitions should be explicit: "We've seeded enough ideas. Ready to move into Argue?" Use the `question` tool for phase transitions.

### Keep a Running State

Maintain a visible running record of:
- The current best idea (updated after each phase)
- Open objections not yet resolved
- Decisions made and their rationale

Present this state at the start of each new phase so the user can correct drift.

### Disagree Professionally

Strong disagreement is required. The format is:
1. Name the specific thing you disagree with
2. State why, concisely
3. Propose an alternative or ask for a defense

Never: "That's an interesting perspective, but perhaps..."  
Always: "I think this is wrong. Here's why: [specific reason]. What would change your mind?"

### LLM Self-Push

The LLM must also push its own thinking. This means:
- Proposing directions that feel risky or unconventional, not just safe options
- Actively seeking the answer that contradicts the obvious interpretation
- When stuck, articulating the shape of the unknown: "I don't know, but here's how we could find out"

---

## Output Format (Phase 4 — Final Summary)

```
## Idea: [Name]

### What It Is
[2–3 sentences. Clear, precise, no hedging.]

### Problem It Solves
[The original problem statement from Phase 1.]

### Key Decisions Made
| Decision | Chosen Direction | Rejected Alternative | Reason |
|---|---|---|---|
| ... | ... | ... | ... |

### Open Risks
1. [Risk] — [Why it matters]
2. [Risk] — [Why it matters]

### What Was Consciously Left Out
[Scope that was cut and why.]

### Next Step
[The single most important action to take.]
```

---

## Quick Reference: Phase Transitions

| From | To | Trigger |
|---|---|---|
| Seed | Argue | A direction worth attacking has emerged |
| Argue | Seed | The idea collapsed under pressure — restart broader |
| Argue | Refine | All major objections resolved or accepted |
| Refine | Argue | A new contradiction or assumption failure surfaces |
| Refine | Converge | The idea is tight and internally consistent |
| Converge | Argue | User rejects the final formulation — gap identified |

---

## Additional Resources

- **`references/dialogue-framework.md`** — Detailed mechanics for structuring the conversation, managing energy, and preventing stagnation
- **`references/argumentation-patterns.md`** — Specific argumentation moves, how to steelman, how to apply structured pressure without derailing
