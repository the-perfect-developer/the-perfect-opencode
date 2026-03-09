# Argumentation Patterns

Specific moves for applying structured pressure during ideation. Use these in Phase 2 (Argue) and Phase 3 (Refine) to stress-test ideas, surface hidden assumptions, and arrive at more durable solutions.

## Table of Contents

1. [Attack Patterns](#attack-patterns)
2. [Defense Patterns](#defense-patterns)
3. [Steelmanning](#steelmanning)
4. [Assumption Mapping](#assumption-mapping)
5. [The Five Whys Variant](#the-five-whys-variant)
6. [Reframing Moves](#reframing-moves)
7. [Convergence Pressure](#convergence-pressure)

---

## Attack Patterns

These are moves to challenge an idea. Apply them in sequence — structural attacks first, assumption attacks second, alternative attacks third.

### Structural Attack

Challenge the architecture of the idea itself — how its parts fit together.

Template:
> "The structure here assumes [component A] and [component B] can coexist without conflict. But [A] requires X and [B] requires not-X. Where does that tension resolve?"

Examples:
- "You're building for speed and reliability simultaneously. At scale, those are in tension. Which wins when they conflict?"
- "This design requires centralized state and distributed execution. That's hard. What's the coordination mechanism?"

When to use: When an idea has two components that seem compatible on the surface but may pull in opposite directions under load or edge cases.

### Assumption Attack

Surface the belief the idea depends on — then challenge whether it is true.

Template:
> "This only works if [assumption]. Is that actually true? What evidence do we have?"

Examples:
- "This assumes users will notice the feature exists. What if they don't?"
- "This assumes the latency budget is 200ms. Where does that number come from?"
- "This assumes competitors won't respond. What if they copy it in 60 days?"

When to use: After an idea has been stated with confidence. Assumptions are often invisible until named.

### Competitive Alternative Attack

Propose a completely different approach that also solves the same problem — and might be better.

Template:
> "Here is a different approach: [alternative]. It would also solve [original problem]. Why is the current direction better than this?"

Examples:
- "Instead of building a custom notification system, what if you used webhooks + a third-party service? Same outcome, 80% less surface area."
- "Instead of making the onboarding faster, what if you eliminated the onboarding entirely by defaulting to a working state?"

When to use: When the team is committed to a direction that may be a local maximum. Forces explicit comparison against alternatives.

### Boundary Attack

Push the idea to its edges — extreme scale, extreme users, edge cases — and observe what breaks.

Template:
> "What happens when [extreme condition]? Does the idea still hold?"

Examples:
- "What happens when 10,000 users do this simultaneously?"
- "What happens when a user has no internet connection mid-flow?"
- "What does a 5-year-old user experience? A blind user? A user under stress?"

When to use: After an idea feels solid under normal conditions. Boundaries reveal hidden fragility.

### Reversal Attack

Argue that the opposite direction is correct.

Template:
> "What if [opposite of the idea] is actually right? Here's the case: [argument for opposite]."

Examples:
- "What if the UI should have more steps, not fewer? More steps can mean more intentionality."
- "What if the API should be more opinionated, not more flexible? Flexibility creates maintenance burden."

When to use: When the team is too aligned. Productive friction requires someone to take the opposite position seriously.

---

## Defense Patterns

These are moves to respond to attacks without capitulating or stonewalling.

### Direct Rebuttal

Name the attack, then defeat it with evidence or reasoning.

Template:
> "The objection is [restate it precisely]. Here's why it doesn't hold: [specific argument]."

Important: restate the attack precisely before rebutting. Restating it imprecisely weakens the defense and frustrates the attacker.

### Concede and Advance

Accept the objection and show it doesn't change the conclusion — or change the conclusion.

Template:
> "That's correct — [objection] is true. And it means [implication]. So we need to [adjustment]. The core idea survives because [reason]."

When to use: When the objection is valid but limited in scope. Conceding a valid point strengthens credibility and advances the conversation.

### Reframe the Attack

Show that the attack is addressing a different problem than the one being solved.

Template:
> "That's a real issue, but it's an issue for [different problem]. We're solving [original problem]. In that scope, here's why [objection] doesn't apply: [reason]."

When to use: When the attacker has shifted scope without acknowledging it.

### Conditional Defense

Accept the attack under certain conditions, reject it under others.

Template:
> "If [condition A], then yes, this breaks. If [condition B], it doesn't. Which condition are we designing for?"

When to use: When the attack depends on unstated assumptions about context or scale.

---

## Steelmanning

Steelmanning is presenting the strongest possible version of an argument — including arguments against the current idea. This is the inverse of a straw man and is required for productive argumentation.

### How to Steelman

1. Identify the argument being made (or the one the opponent should be making)
2. Present its best version — stronger than how it was originally stated
3. Only then respond to that version

Example:
- Weak version of objection: "This is too complicated."
- Steelmanned version: "The complexity here is not incidental — it is structural. Every additional component adds failure modes and cognitive load for operators. A simpler system that does 80% of the job would ship faster, fail less, and be easier to reason about. The 20% gap may not be worth the complexity cost."

### When to Steelman Proactively

If the user makes a weak objection, the LLM should steelman it before responding. This models rigorous thinking and prevents the conversation from resolving shallow versions of hard problems.

Signal: "Let me steelman that before we respond to it: [stronger version of the objection]."

---

## Assumption Mapping

Before entering Phase 2 (Argue), map the assumptions the idea depends on. This makes attacks easier to target.

### How to Build an Assumption Map

Ask of the current idea:
1. **User assumptions**: What must be true about how users behave?
2. **Technical assumptions**: What must be true about the technology or system?
3. **Market assumptions**: What must be true about the environment or competition?
4. **Resource assumptions**: What must be true about time, budget, or team capability?
5. **Reversibility assumptions**: What must be true about what can be changed later?

For each assumption, rate it:
- **Confident**: We have evidence for this
- **Uncertain**: We believe this but haven't verified
- **Unknown**: We don't know

Attack uncertain and unknown assumptions first. Confident assumptions can be challenged but are lower priority.

### Assumption Map Format

```
## Assumption Map: [Idea Name]

| Assumption | Category | Confidence | Evidence |
|---|---|---|---|
| Users will return within 7 days | User | Uncertain | Benchmark data from similar product |
| API latency < 50ms at P99 | Technical | Unknown | Not yet benchmarked |
| No competing feature in next quarter | Market | Unknown | No visibility |
```

Build this table explicitly before entering Argue phase. Revisit it when attacks reveal new assumptions.

---

## The Five Whys Variant

The standard Five Whys asks "why" repeatedly to find root cause. In ideation, the variant asks "why is this the right solution" to distinguish between solutions and problems.

### Protocol

1. State the proposed solution
2. Ask: "Why is this the right solution?"
3. Take the answer and ask: "But why does that approach work better than [alternative]?"
4. Continue until: the reasoning becomes circular, or a genuine root principle is reached
5. Assess: is the solution addressing the root, or is it treating a symptom?

### Example

- Solution: "Add a caching layer."
- Why right? "Because the database is slow."
- Why caching vs. query optimization? "Because we don't control the schema."
- Why not move to a different database? "Migration cost."
- Why is migration cost the constraint? "It would take 3 months."
- Is there a faster path? (new question opens here)

Often reveals that the stated solution addresses a constraint (migration cost) rather than the root problem (slow data access). The constraint may itself be worth challenging.

---

## Reframing Moves

When an idea is stuck or the conversation is circular, reframing the problem often unlocks it.

### Problem-Solution Swap

Restate the solution as a problem: "What problem is [proposed solution] actually solving?"

Use when: A solution has been proposed before the problem has been clearly defined.

### Constraint Inversion

Identify the most limiting constraint and ask: "What would we build if this constraint did not exist?"

Then: "What would it take to eliminate or reduce this constraint?"

### Level Shift (Zoom Out)

Move up one level of abstraction: "At a higher level, what are we really trying to accomplish?"

Use when: The conversation is stuck in implementation detail before the concept is stable.

### Level Shift (Zoom In)

Move down one level: "Concretely, what does a user do in the first 30 seconds with this?"

Use when: The conversation is stuck at an abstract level that produces no actionable clarity.

### The Unexpected User

Introduce a user who breaks the assumption: "What does this look like for a user who [unusual but plausible behavior]?"

Examples: "Who is skeptical of the product but required to use it." / "Who uses it every day for two years." / "Who onboards during a crisis."

---

## Convergence Pressure

In Phase 4, the goal is to commit. These moves counteract the tendency to keep refining indefinitely.

### The Forcing Question

"If you had to decide right now — no more information, no more time — what would you choose?"

Reveals: what the user actually believes vs. what they are willing to say publicly.

### The Cost of Delay

"What is the cost of not deciding today? What do we lose for every week we wait?"

Use when: The team is deferring a decision that is blocking downstream work.

### The Minimum Viable Decision

"What is the smallest decision we could make that would unlock the most progress?"

Use when: The team is trying to resolve everything at once. Often a subset of decisions must be made now; others can wait.

### The Reversibility Test

"If we make this decision and it turns out to be wrong, how hard is it to undo?"

Easy to undo: decide now and iterate.
Hard to undo: spend more time here.

This prevents over-analyzing easily reversible decisions and under-analyzing irreversible ones.
