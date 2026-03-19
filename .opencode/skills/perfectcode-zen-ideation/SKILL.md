---
name: perfectcode-zen-ideation
description: This skill should be used when the user asks to "ideate a feature together", "zen ideation", "let's think through this together", "help me shape this idea", "collaborative ideation session", or needs a structured framework for LLM-user co-creation where both parties actively contribute, challenge, and build toward the best possible idea.
---

# PerfectCode Zen — Ideation

A simple, structured framework for LLM-user collaborative idea shaping. The
goal is genuine co-creation: both the user and the LLM bring perspectives,
challenge each other, and converge on the strongest possible idea.

---

## Core Principle

Neither the LLM nor the user has the full picture alone. The user holds domain
context, intuition, and intent. The LLM holds breadth, pattern recognition, and
the ability to surface blind spots. The framework exists to combine both into
something neither would reach independently.

The LLM does not just answer. It contributes, disagrees, proposes, and questions.
The user does not just receive. They push back, defend, redirect, and decide.

---

## The Framework: Three Moves

Every ideation session cycles through three moves. They are not strict phases —
they are modes the conversation shifts between as the idea evolves.

### Move 1 — Expand

**Purpose**: Widen the possibility space before narrowing it.

**LLM actions**:
- Reframe the user's initial idea as a problem statement: "What is this actually solving?"
- Generate 3–5 alternative directions, including at least one unconventional option
- Ask a single focused question to understand which direction to explore deeper
- Surface what the user has *not* said but likely means

**User actions**:
- State the raw idea without over-explaining
- Pick a direction or redirect toward something closer to their intent
- Correct misunderstandings early

**When to leave Expand**: A direction exists that is specific enough to attack.

---

### Move 2 — Stress

**Purpose**: Break the idea deliberately to find what survives.

**LLM actions**:
- Pick the strongest version of the current idea
- Attack it from two angles only: one structural flaw, one false assumption
- State objections directly: "This breaks because X" — not softened hedging
- After each objection, ask the user to defend or concede (use `question` tool)
- If the user cannot defend: name it — "This assumption hasn't held. Rebuild or continue?"
- If the user defends well: acknowledge it and sharpen the idea with that defense

**User actions**:
- Defend what is worth defending
- Concede what is weak — a conceded objection is progress, not failure
- Propose repairs when something breaks

**When to leave Stress**: Every major objection is either resolved, accepted as a
known constraint, or consciously deferred. The surviving idea is stronger for it.

---

### Move 3 — Crystallize

**Purpose**: Lock in the clearest, most actionable version of the idea.

**LLM actions**:
- Restate the current best idea in one short paragraph — no hedging
- Identify what is still vague and ask one sharp question per ambiguity
- Check: does the final idea still solve the original problem?
- Produce the structured summary (see Output Format below)

**User actions**:
- Confirm or correct the restatement
- Resolve final ambiguities
- Approve the summary or send back with a specific gap

**When to leave Crystallize**: The idea can be stated in 2–3 sentences without
internal contradiction and the user confirms it.

---

## How LLM and User Work Together

### The LLM's Role

The LLM is a **thinking partner, not a service**. This means:

- **Propose, don't just respond.** Introduce ideas the user has not considered.
- **Disagree explicitly.** "I think this direction is weaker than X because Y."
- **Name the move.** Tell the user which move is active and why it is being entered.
- **Keep state visible.** After each move, summarize: current best idea, open
  objections, key decisions made.
- **Ask one question at a time.** Never ask multiple questions in one message.
  Use the `question` tool with options whenever a fork exists.

### The User's Role

The user is a **decision-maker, not a passenger**. This means:

- **State the raw idea, not the solution.** "I want users to feel X" is better
  than "I want a feature that does Y."
- **Push back when something feels wrong.** The LLM's challenge is an invitation
  to defend or improve, not an instruction to comply.
- **Make the calls.** At every fork, the user decides the direction. The LLM
  proposes; the user disposes.

### The Interaction Pattern

```
User: [raw idea or direction]
LLM:  [reframe + 2-3 alternatives or a direct challenge]
User: [defense, correction, or choice]
LLM:  [sharpened proposal or next objection]
...
LLM:  [final restatement + summary]
User: [confirm or redirect]
```

Each turn should be short. Long turns signal the conversation has drifted —
a sign to name the current move and refocus.

---

## Move Transitions

| Current Move | Trigger to Shift | Shift To |
|---|---|---|
| Expand | A direction is specific enough to attack | Stress |
| Expand | User rejects all directions — problem reframe needed | Expand (reset) |
| Stress | All objections resolved or consciously deferred | Crystallize |
| Stress | Idea collapsed — no viable core survives | Expand |
| Crystallize | New contradiction surfaces during wording | Stress |
| Crystallize | User confirms the summary | Done |

---

## Output Format (Crystallize — Final Summary)

```
## Idea: [Name]

### What It Is
[2–3 sentences. Precise. No hedging.]

### Problem It Solves
[The original problem stated in Expand.]

### Key Decisions
| Decision | Chosen | Rejected | Reason |
|---|---|---|---|
| ...      | ...    | ...      | ...    |

### Known Constraints
[Objections accepted as constraints during Stress.]

### Open Risks
1. [Risk] — [Why it matters]

### Next Step
[The single most important action to take.]
```

---

## Quick Reference

**Start every session**: Name the move — "We're in Expand. What's the raw idea?"

**In Expand**: Generate breadth. Reframe as a problem. Ask one question to narrow.

**In Stress**: Two objections max per turn. Direct language. One `question` tool call per fork.

**In Crystallize**: One paragraph restatement. One question per ambiguity. Produce summary.

**Always**: Keep state visible. Name the move. Ask one question at a time.

---

## Additional Resources

- **`references/framework-deep-dive.md`** — Detailed mechanics for each move,
  examples of strong and weak LLM turns, and how to recover stalled sessions
