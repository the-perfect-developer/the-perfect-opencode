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
[![Maintenance](https://img.shields.io/badge/Maintained-yes-brightgreen.svg)](https://github.com/the-perfect-developer/the-perfect-opencode/commits/main)

A curated collection of agents, skills, and commands for [OpenCode](https://opencode.ai) — with a streamlined process to install, update, and extend your AI-powered development environment.

**[Complete Tools Reference](docs/tools-reference.md)**

---

## Installation

Install the core collection with a single command:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/the-perfect-developer/the-perfect-opencode/main/scripts/install.sh)
```

The installer installs core tools by default. Use optional flags to customize your installation:

- `--all` — Install all agents, skills, and commands
- `agent:<name>` — Install specific agent(s)
- `skill:<name>` — Install specific skill(s)
- `command:<name>` — Install specific command(s)

The installer automatically removes deprecated tools from previous installations, writes a manifest of installed tools, and syncs `.opencode/.gitignore` to prevent tracking system-generated files.

---

## Tool Management

After the initial install, use these commands to manage your tools from within OpenCode:

**`/install-perfect-tools`** — Guides you through discovering and installing agents, skills, and commands tailored to your project's stack and workflow.

**`/update-perfect-tools`** — Compares your installed tools against the latest catalog and updates any that have changed.

**`/recommend-perfect-tool`** — Silently analyzes your project (languages, frameworks, CI config) and recommends tools you haven't installed yet — no questions asked.

**`/sync-perfect-configs`** — Syncs your local `opencode.json` with the canonical remote version.

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

The Ideation Expert orchestrates specialist agents behind the scenes — routing to `@code-analyst` for deep comprehension, `@solution-architect` for design decisions, `@security-expert` for risk assessment, and `@performance-engineer` for scalability analysis — then synthesizes their findings into a coherent narrative.

When you're ready to act, it hands off context to the right implementation agent so nothing is lost in translation.

> **Ideation Expert vs. Plan Agent** — These are not the same tool. `/ideate` is conversational and exploratory: it never produces a plan, never writes code, and is designed for fuzzy problems where the direction isn't clear yet. `/plan` is structured and decisive: it analyzes requirements, consults specialists, and outputs an actionable task list ready for `/implement`. The intended flow is `/ideate` → `/plan` → `/implement`. Use `/ideate` when you're still figuring out *what* to build. Use `/plan` when you know *what* and need to figure out *how*.

---

## Development Workflow

The canonical workflow for feature development:

**`/ideate`** (optional) — Explore and ideate before planning. Use when the direction isn't clear yet.

```
/ideate how should we approach this problem?
```

**`/plan`** — Build a structured implementation plan. Gathers requirements, analyzes your codebase, and produces a task list.

```
/plan build a user authentication flow
```

**`/implement`** — Execute the plan using specialized implementation agents (`@developer-prime` for complex tasks, `@developer-fast` for scoped work).

```
/implement
```

**`/evaluate`** — Review the implementation against the plan and surface improvement suggestions.

```
/evaluate .opencode/plans/<feature-name>.md
```

---

## Customization Commands

Extend OpenCode with your own resources:

**`/create-rule`** — Adds a `MUST FOLLOW` rule to your project's `AGENTS.md`, keeping coding standards and conventions enforced across all agents.

**`/create-agent`** — Interactive agent builder. Configures model, temperature, tool permissions, and system prompt, then writes the agent file to `.opencode/agents/`.

**`/create-skill`** — Scaffolds a new skill with proper frontmatter, progressive disclosure structure, and validation guidance.

**`/create-command`** — Walks through requirements and generates a slash command in `.opencode/commands/` with the correct frontmatter, argument handling, and agent routing.

---

## Development

First-time contributor setup:

```bash
./scripts/setup-hooks.sh
```

Then see [CONTRIBUTING.md](CONTRIBUTING.md) for validation commands and CI details.

---

## Author

**Dilan D Chandrajith** — [The Perfect Developer](https://github.com/the-perfect-developer)

## License

MIT License — See [LICENSE](LICENSE) for details.
