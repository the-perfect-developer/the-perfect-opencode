---
description: Execute implementation plan with specialized engineering agents
agent: build
agents:
  - general
  - explore
  - code-analyst
  - security-expert
  - performance-engineer
  - junior-engineer
  - backend-engineer
  - frontend-engineer
  - architect
---

Please implement this using @backend-engineer, @frontend-engineer, and @junior-engineer for coding tasks. Invoke these engineering subagents in parallel where possible. If any complex or unfamiliar code needs to be understood before implementation, consult @code-analyst first. If any consultation is needed during implementation, consult @architect for design decisions, @security-expert for security concerns, and @performance-engineer for performance optimizations — also in parallel where possible.

$1
