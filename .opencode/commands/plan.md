---
description: Gather requirements, analyze code, and create implementation plan
agent: plan
agents:
  - general
  - explore
  - code-analyst
  - security-expert
  - performance-engineer
  - architect
---

$1

When planning, consult @code-analyst to understand complex or unfamiliar code before making design decisions. Also get consultations from @architect for system design and architectural decisions, @performance-engineer for performance considerations, and @security-expert for security implications. Invoke these consultant subagents in parallel where possible.

At the end of the plan, tell the user to use `/implement` for simple implementations or `/extended-implement` for complex ones.
