# The Perfect Developer's OpenCode Base Collection

```
The Perfect Developer's
   ___                   ___          _
  / _ \ _ __   ___ _ __ / __\___   __| | ___
 | | | | '_ \ / _ \ '_ / /  / _ \ / _` |/ _ \
 | |_| | |_) |  __/ | | /__| (_) | (_| |  __/
  \___/| .__/ \___|_| \____/\___/ \__,_|\___|
       |_|

Base Collection
By Dilan D Chandrajith - The Perfect Developer
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OpenCode](https://img.shields.io/badge/OpenCode-Skills-blue.svg)](https://opencode.ai)
[![Maintenance](https://img.shields.io/badge/Maintained-yes-brightgreen.svg)](https://github.com/the-perfect-developer/opencode-base-collection/commits/main)

Essential skill collection for OpenCode - the AI-powered coding assistant.

## Features

- **Command Creation** - Create custom slash commands
- **Rules Creation** - Configure custom instructions
- **Skill Creation** - Build new skills with proper structure

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/the-perfect-developer/opencode-base-collection/main/install.sh | bash
```

This installs skills to `.opencode/skills/` in your current directory.

## Available Skills

### skill-creation
Create reusable, discoverable skills that extend OpenCode's capabilities through on-demand loading.

**What you can do:**
- Build modular instruction sets with specialized workflows
- Bundle resources like scripts, references, and examples
- Implement progressive disclosure for efficient context usage
- Create both project-local and global skills

**Perfect for:** Complex multi-step procedures, domain-specific expertise, tool integrations, and custom automation workflows.

### command-creation
Create custom slash commands for repetitive tasks that execute specific prompts with dynamic arguments.

**What you can do:**
- Define reusable prompts triggered with `/command-name`
- Pass dynamic arguments to customize behavior
- Integrate shell command output into prompts
- Auto-include file contents and references
- Route commands to specific agents or models

**Perfect for:** Testing workflows, code reviews, deployment scripts, and any repetitive development tasks.

### rules-creation
Configure custom instructions to guide OpenCode's behavior for your projects and personal workflows.

**What you can do:**
- Define project conventions and code standards
- Document architecture patterns and project structure
- Specify build processes and deployment procedures
- Set personal coding preferences
- Create both project-wide and global rules

**Perfect for:** Team conventions, coding standards, project documentation, and personalizing OpenCode's behavior.

## Usage

Skills load automatically when you ask OpenCode:

```
> How do I create a new skill?
> Create a slash command for running tests
> Set up project rules
```

## Contributing

Interested in contributing? Check out our [Contributing Guide](CONTRIBUTING.md) for:
- Development setup instructions
- Git hooks and code quality tools
- Pull request guidelines
- CI/CD information

## Author

**Dilan D Chandrajith** - [The Perfect Developer](https://github.com/the-perfect-developer)

## License

MIT License - See [LICENSE](LICENSE) file for details.
