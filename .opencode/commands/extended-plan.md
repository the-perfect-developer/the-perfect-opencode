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

# Extended Planning Workflow

You are tasked with creating a comprehensive implementation plan.

**IMPORTANT**: Load the `planning` skill for detailed workflow instructions:

```
Use the Skill tool to load: planning
```

The planning skill provides:
- Six-phase planning workflow
- Requirement gathering questions
- Codebase analysis strategies
- Agent coordination patterns
- Plan structure templates
- Plan status tracking

## Quick Overview

Follow this high-level workflow (see planning skill for details):

1. **Phase 1: Requirement Gathering** - Ask for feature name and gather requirements
2. **Phase 2: Context Analysis** - Analyze project structure and codebase; consult @code-analyst for complex or unfamiliar code
3. **Phase 3: Research and Verification** - Verify approaches and best practices
4. **Phase 4: Planning with Subagents** - Coordinate specialized agents in parallel
5. **Phase 5: Create Implementation Plan** - Generate detailed implementation plan
5. **Phase 6: Finalize and Communicate** - Summarize the plan to the user

## Available Agents

You can invoke the following specialized agents:
- **@general** - General-purpose agent for research and multi-step tasks
- **@explore** - Fast codebase exploration and pattern searching
- **@code-analyst** - Deep code comprehension: architecture, control flow, data flow, design patterns
- **@security-expert** - Security audits, threat modeling, cryptography
- **@performance-engineer** - Performance optimization and profiling
- **@architect** - System design, architectural patterns, design decisions

## Essential Rules

1. **Start by asking for feature name** (kebab-case: "oauth-authentication", "user-profile")
2. **Load the planning skill** for complete instructions
3. **Use agents in parallel** when tasks are independent

## *MUST FOLLOW* — Plan File

**Writing the plan to a markdown file is mandatory. No exceptions.**

- Before writing the plan, suggest 3–5 filename options based on the feature name (e.g., `oauth-authentication-plan.md`, `auth-oauth-plan.md`, `oauth-plan.md`) and ask the user to pick their preferred filename.
- Wait for the user to confirm or provide their own name.
- Once confirmed, write the complete plan to that exact file. Do not skip this step.

## After Creating Plan

Present the complete plan to the user and ask for their feedback. Wait for user confirmation or requested changes before proceeding. Then tell the user to use `/implement` for simple implementations or `/extended-implement` for complex ones.

---

**For complete instructions, load the planning skill.**
