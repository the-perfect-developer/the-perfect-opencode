# The Perfect OpenCode

```
  _____ _            ____            __           _   
 |_   _| |__   ___  |  _ \ ___ _ __ / _| ___  ___| |_ 
   | | | '_ \ / _ \ | |_) / _ \ '__| |_ / _ \/ __| __|
   | | | | | |  __/ |  __/  __/ |  |  _|  __/ (__| |_ 
   |_| |_| |_|\___| |_|   \___|_|  |_|  \___|\___|\__|
                                                       
   ___                   ___          _      
  / _ \ _ __   ___ _ __ / __\___   __| | ___ 
 | | | | '_ \ / _ \ '_ / /  / _ \ / _` |/ _ \
 | |_| | |_) |  __/ | | /__| (_) | (_| |  __/
  \___/| .__/ \___|_| \____/\___/ \__,_|\___|
       |_|                                    

By Dilan D Chandrajith - The Perfect Developer
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OpenCode](https://img.shields.io/badge/OpenCode-Skills-blue.svg)](https://opencode.ai)
[![Maintenance](https://img.shields.io/badge/Maintained-yes-brightgreen.svg)](https://github.com/the-perfect-developer/opencode-base-collection/commits/main)

A curated collection of agents, skills, and commands for [OpenCode](https://opencode.ai) — with a streamlined process to install, update, and extend your AI-powered development environment.

**[Complete Tools Reference](docs/tools-reference.md)**

---

## Installation

Install the core collection with a single command:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/the-perfect-developer/opencode-base-collection/main/scripts/install.sh)
```

This installs specialized agents, domain-specific skills, and workflow commands into your project's `.opencode/` directory.

> For LLMs assisting with setup, see [Installation Guide](docs/installation-guide.md).

---

## Tool Management

After the initial install, use these commands to manage your tools from within OpenCode:

**`/install-perfect-tools`** — Guides you through discovering and installing agents, skills, and commands tailored to your project's stack and workflow.

**`/update-perfect-tools`** — Compares your installed tools against the latest catalog and updates any that have changed.

**`/recommend-perfect-tool`** — Silently analyzes your project (languages, frameworks, CI config) and recommends tools you haven't installed yet — no questions asked.

---

## Development Workflow

### Explore & Ideate (Chat with Your Codebase)

Before writing a single line of code, use `/ideate` to think through ideas, understand your codebase, and stress-test decisions with a knowledgeable partner:

```
/ideate how does the authentication flow work in this codebase?
/ideate brainstorm approaches for adding real-time notifications
/ideate let's stress-test this database schema design
```

`/ideate` activates the **Ideation Expert** — a read-only conversational agent that never writes or edits code. It operates in two modes:

- **Explore** — Maps codebase structure, traces execution paths, surfaces patterns and trade-offs. Useful when you want to understand unfamiliar code before touching it.
- **Ideate** — Runs a structured 4-phase framework (Seed → Argue → Refine → Converge) to pressure-test ideas, surface weak assumptions, and converge on a well-reasoned direction.

The Ideation Expert orchestrates specialist agents behind the scenes — routing to `@code-analyst` for deep comprehension, `@architect` for design decisions, `@security-expert` for risk assessment, and `@performance-engineer` for scalability analysis — then synthesizes their findings into a coherent narrative.

When you're ready to act, it hands off context to the right implementation agent so nothing is lost in translation.

> **Ideation Expert vs. Plan Agent** — These are not the same tool. `/ideate` is conversational and exploratory: it never produces a plan, never writes code, and is designed for fuzzy problems where the direction isn't clear yet. `/plan` is structured and decisive: it analyzes requirements, consults specialists, and outputs an actionable task list ready for `/implement`. The intended flow is `/ideate` → `/plan` → `/implement`. Use `/ideate` when you're still figuring out *what* to build. Use `/plan` when you know *what* and need to figure out *how*.

---

### Quick Tasks (Plan + Implement in One Shot)

For tasks where you want planning and implementation to happen without interruption, use `/quickee`:

```
/quickee add a dark mode toggle to the settings page
```

`/quickee` runs on the `build` agent and combines planning and implementation into a single flow:

1. **Clarify** — asks focused questions if the task is ambiguous, then stops asking
2. **Plan** — consults @code-analyst, @architect, @security-expert, and @performance-engineer in parallel to produce a concise plan
3. **Implement** — immediately executes the plan using @backend-engineer, @frontend-engineer, and @junior-engineer in parallel

No manual handoff between `/plan` and `/implement` — ideal for well-scoped tasks where you want fast, structured output.

### Lightweight Tasks

For everyday features where you want to review the plan before implementation:

```
/plan    build a user authentication flow
/implement
```

`/plan` gathers requirements and produces an implementation plan. `/implement` executes it using the appropriate specialized agents.

### Complex Features

For larger features that require architectural input, security review, or performance analysis, use the extended workflow:

```
/extended-plan    build a real-time notification system
/extended-implement
```

`/extended-plan` runs a six-phase planning process: requirement gathering, codebase analysis, research, multi-agent consultation (@architect, @security-expert, @performance-engineer), plan generation, and user review.

`/extended-implement` runs a seven-phase orchestrated implementation: requirements analysis, task breakdown, parallel agent execution, quality assurance, testing, and final documentation. Agents are selected by task type — @frontend-engineer for UI, @backend-engineer for APIs, @junior-engineer for simple fixes — and independent tasks run in parallel.

---

## Customization Commands

Extend OpenCode with your own resources:

**`/create-rule`** — Adds a `MUST FOLLOW` rule to your project's `AGENTS.md`, keeping coding standards and conventions enforced across all agents.

**`/create-agent`** — Interactive agent builder. Configures model, temperature, tool permissions, and system prompt, then writes the agent file to `.opencode/agents/`.

**`/create-skill`** — Scaffolds a new skill with proper frontmatter, progressive disclosure structure, and validation guidance.

**`/create-command`** — Walks through requirements and generates a slash command in `.opencode/commands/` with the correct frontmatter, argument handling, and agent routing.

---

---

## Author

**Dilan D Chandrajith** — [The Perfect Developer](https://github.com/the-perfect-developer)

## License

MIT License — See [LICENSE](LICENSE) for details.
