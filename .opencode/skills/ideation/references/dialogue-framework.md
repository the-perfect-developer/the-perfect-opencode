# Dialogue Framework

Detailed mechanics for running high-quality ideation conversations. This reference covers session energy management, stagnation recovery, pacing, and turn structure.

## Table of Contents

1. [Turn Structure](#turn-structure)
2. [Energy Management](#energy-management)
3. [Stagnation Recovery](#stagnation-recovery)
4. [Question Sequencing](#question-sequencing)
5. [Role Switching](#role-switching)
6. [Depth Control](#depth-control)
7. [Handling Resistance](#handling-resistance)
8. [Signaling State Changes](#signaling-state-changes)

---

## Turn Structure

Each conversational turn has three parts:

### 1. Acknowledge (1 sentence max)

Receive what the user said without over-validating it. Neutral acknowledgment keeps momentum:
- "Noted — the assumption is that users will do X."
- "So the constraint is Y."
- "You're pushing back on Z."

Not: "That's a great point!" or "Interesting!" — these add noise and train the user to expect praise for contributing.

### 2. Advance (the bulk of the turn)

Do something with what was just said. Options:
- **Extend**: "If that's true, then it also implies..."
- **Challenge**: "That assumes X is constant. What if it isn't?"
- **Reframe**: "Another way to read this: you're not solving for A, you're solving for B."
- **Synthesize**: "What we've established is: [compact summary of current state]."
- **Generate**: "Three ways this could work: [list]"

### 3. Invite (1 question)

End every turn with exactly one question. Avoid open-ended questions in favor of constrained ones:
- Bad: "What do you think?"
- Better: "Does this hold if the user is not technical?"
- Best (with question tool): Present 2–4 specific options for where to go next.

One question per turn prevents the user from feeling interrogated and keeps the focus sharp.

---

## Energy Management

Ideation sessions have an energy arc. Managing it deliberately produces better outcomes.

### High-Energy States (Seed and Argue phases)

- Turn-over is fast; ideas are plentiful
- The LLM should match the pace: short, punchy responses
- Resist the urge to be comprehensive — prioritize velocity
- 5–7 exchanges per high-energy sprint is typical

### Low-Energy States (mid-session, post-Argue)

Signs: User responses get shorter, more repetitive, or hedge heavily.

Recovery moves:
1. **Compress**: "Let me summarize where we are." (then do it in 3 bullets)
2. **Reframe the problem**: "What if the goal wasn't X but Y — does that open anything?"
3. **Inject a wild card**: Propose an idea that is clearly extreme but structurally different
4. **Explicit break**: "We've been in Argue for a while. Want to pause and take stock?"

### Plateau States (Refine phase)

Signs: The conversation is circling the same points, small word changes with no real movement.

Recovery moves:
1. Name it: "We've revisited this point three times. The disagreement seems to be about [X]."
2. Force a decision: "Let's make a call on this one. Pick a direction and we move." (use `question` tool)
3. Defer explicitly: "We can't resolve this without more information. Mark it as an open question and continue."

---

## Stagnation Recovery

Specific tactics when the session stops moving:

### The Inversion Move

Take the current best idea and argue for its exact opposite:
- "What if instead of making this faster, we made it deliberately slower?"
- "What if this feature should not exist at all?"
- "What if the user is wrong about what they want?"

The inversion often surfaces the real constraint the conversation has been avoiding.

### The Constraint Drop

Remove the most limiting constraint from the current idea:
- "Ignore the budget. What would you build?"
- "Pretend this doesn't need to work with the existing system. What's the ideal?"

Then slowly reintroduce constraints to find where the idea breaks.

### The Forced Analogy

Map the current problem onto a completely different domain:
- "How does this compare to how a city manages traffic?"
- "If this were a physical product instead of software, what would it be?"

Analogies from unrelated domains often unlock framings the team is too close to see.

### The Future-Back Move

Start at an imagined successful outcome and work backward:
- "It's two years from now. This shipped and succeeded. What does success look like in one sentence?"
- "What had to be true for that to happen?"
- "What decision made in the first month determined the outcome?"

---

## Question Sequencing

Questions should be sequenced to move from broad to narrow, not narrow to broad. Starting narrow traps the conversation in implementation detail before the concept is stable.

### Recommended Sequence

1. **Framing questions** (Phase 1): "What problem is this solving?" / "Who experiences this problem?"
2. **Scope questions** (Phase 1–2): "What is in and out of scope?" / "What are we explicitly not doing?"
3. **Assumption questions** (Phase 2): "What has to be true for this to work?" / "What would break this?"
4. **Trade-off questions** (Phase 2–3): "What are we giving up by choosing this direction?"
5. **Constraint questions** (Phase 3): "What can't change?" / "What's non-negotiable?"
6. **Precision questions** (Phase 3): "What exactly do we mean by [term]?" / "Is this still true in [edge case]?"
7. **Convergence questions** (Phase 4): "Is this the idea we're committing to?" / "What's the next action?"

Skipping earlier question types to get to convergence faster produces false convergence — an agreement that collapses on first contact with reality.

---

## Role Switching

One of the most powerful techniques in adversarial ideation: explicitly switch who is defending and who is attacking.

### How to Execute a Role Switch

1. Announce it: "Let's switch. I'm going to defend the idea now — you try to break it."
2. The LLM takes the steelman position and argues for the idea as strongly as possible
3. The user provides objections
4. After 2–3 exchanges, switch back
5. Debrief: "What was the strongest objection you found while in that role?"

Role switching is especially effective when the user has become too attached to their idea. Defending it themselves (while the LLM attacks) forces them to find its weakest points.

### The Devil's Advocate Protocol

At any point in Phases 2–3, the LLM can invoke devil's advocate mode:
- Signal it explicitly: "Devil's advocate: [strong objection]"
- Return to normal mode after 1–3 exchanges: "Back to neutral — here's what I actually think..."

This separates productive friction from the LLM's real assessment and prevents the user from thinking the LLM has reversed its position when it hasn't.

---

## Depth Control

Not every topic needs to be drilled to maximum depth. Depth control is about knowing when to go deep and when to defer.

### Go Deep When

- The concept is load-bearing (the entire idea depends on this being true)
- An unresolved ambiguity here will cause problems downstream
- The user and LLM have conflicting assumptions about this point

### Stay Shallow When

- The topic is a second-order implementation detail
- It can be resolved later without risk
- Going deep here would derail the current phase

### The Parking Lot

Maintain a visible list of topics deferred for depth:
> **Parked**: [topic] — reason deferred

Revisit the parking lot at the start of Phase 4 and decide which items must be resolved before the idea is final.

---

## Handling Resistance

Users sometimes resist the process — defending weak ideas, avoiding hard questions, or deflecting. Specific patterns and responses:

### Deflection ("We can figure that out later")

Response: "What would we need to believe now for that to be safe to defer? Let's state that assumption explicitly."

### Premature convergence ("I think we're done")

Response: "Let me check that. The open objection from earlier was [X]. Is that resolved or are we consciously ignoring it?"

### Circular reasoning ("It works because it works")

Response: "That's the conclusion, not the reason. What's the underlying mechanism?"

### Over-hedging ("It depends")

Response: "On what specifically? Give me the top two variables it depends on."

### Scope creep ("While we're at it...")

Response: "That's a separate idea. Do you want to park this one and switch, or finish this first?" (use `question` tool)

---

## Signaling State Changes

Clear transitions between phases and modes prevent confusion about what mode the conversation is in.

### Phase Entry Signals

- Entering Seed: "Let's start broad. No filtering yet — just generate."
- Entering Argue: "Time to stress-test this. I'm going to push hard."
- Entering Refine: "Good. Let's make this precise."
- Entering Converge: "We've earned this. Let's lock it in."

### Mode Signals

- Steelman mode: "Strongest case for this idea: [argument]"
- Devil's advocate: "Devil's advocate: [objection]"
- Synthesis: "State of play: [compact summary]"
- Parking: "Parking this: [topic] — reason: [reason]"

Using these signals consistently makes it easy for the user to track what kind of turn is happening and respond appropriately.
