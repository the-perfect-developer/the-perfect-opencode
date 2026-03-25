# Installation Guide for LLMs

This guide explains how to discover and install agents, skills, and commands for OpenCode.

## Discovering Available Resources

All available agents, skills, and commands are cataloged in a centralized JSON file. You can access the complete catalog at:

```
https://raw.githubusercontent.com/the-perfect-developer/the-perfect-opencode/refs/heads/main/opencode-catalog.json
```

This catalog contains:
- **Agents**: Specialized AI assistants configured for specific development tasks (12 agents, e.g., principal-architect, developer-prime, security-expert)
- **Skills**: Domain-specific instruction sets and workflows (53+ skills, e.g., alpinejs, python, conventional-git-commit)
- **Commands**: Custom slash commands for common operations (14 commands, e.g., git-commit, plan, implement)

Each entry in the catalog includes metadata such as:
- Name and description
- Category/type (agent, skill, or command)
- Installation identifier
- Source repository information
- Dependencies (if any)

## Installing Resources

Once you've identified the agents, skills, or commands you need from the catalog, you can install them using a single command.

### Installation Pattern

Use this one-liner to install any combination of agents, skills, and commands:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/the-perfect-developer/the-perfect-opencode/main/scripts/install.sh) agent:principal-architect skill:alpinejs command:git-commit
```

### Installation Modes

```bash
# Install everything
bash <(curl -fsSL https://raw.githubusercontent.com/the-perfect-developer/the-perfect-opencode/main/scripts/install.sh) --all

# Install core items only (default)
bash <(curl -fsSL https://raw.githubusercontent.com/the-perfect-developer/the-perfect-opencode/main/scripts/install.sh)

# Install specific items
bash <(curl -fsSL https://raw.githubusercontent.com/the-perfect-developer/the-perfect-opencode/main/scripts/install.sh) agent:principal-architect skill:python command:git-commit
```

The installer automatically removes deprecated tools, writes a manifest of installed items, and syncs `.opencode/.gitignore`.

### How It Works

The installation script:
1. Downloads and executes the installation script from the base collection repository
2. Parses the space-separated list of resources to install
3. Each resource follows the pattern `<type>:<name>` where:
   - `type` is one of: `agent`, `skill`, or `command`
   - `name` is the identifier from the catalog
4. Fetches the specified resources from their source repositories
5. Installs them in the appropriate OpenCode configuration directories

### Installation Examples

**Install a single agent:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/the-perfect-developer/the-perfect-opencode/main/scripts/install.sh) agent:developer-prime
```

**Install multiple skills:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/the-perfect-developer/the-perfect-opencode/main/scripts/install.sh) skill:python skill:typescript-style skill:markdown
```

**Install a command:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/the-perfect-developer/the-perfect-opencode/main/scripts/install.sh) command:git-commit
```

**Install multiple resources of different types:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/the-perfect-developer/the-perfect-opencode/main/scripts/install.sh) agent:principal-architect agent:security-expert skill:alpinejs skill:htmx command:git-commit
```

## Installation Locations

After installation, resources are placed in:
- **Agents**: `.opencode/agents/` directory
- **Skills**: `.opencode/skills/` directory  
- **Commands**: `.opencode/commands/` directory

These directories are automatically created if they don't exist.

## Workflow for LLMs

When assisting users with OpenCode setup, follow this workflow:

1. **Understand requirements**: Determine what type of development work the user needs (e.g., frontend, backend, specific frameworks)
2. **Fetch catalog**: Retrieve and parse the catalog JSON to see available options
3. **Recommend resources**: Suggest appropriate agents, skills, and commands based on the user's needs
4. **Generate install command**: Construct the one-liner with the selected resources
5. **Execute installation**: Run the command to install the resources
6. **Verify installation**: Confirm the resources are available in the appropriate directories

## Notes

- The installation script requires an active internet connection
- Resources are installed at the project level (in `.opencode/` directory)
- You can reinstall or update resources by running the install command again
- Check the catalog regularly as new agents, skills, and commands are added frequently
