#!/bin/bash

# Pre-commit hook: Validate agent .md frontmatter migration
# Ensures no agent file contains tools: or permission: blocks in frontmatter

set -e

echo "Validating agent frontmatter migration..."

# Get all staged agent .md files
STAGED_AGENTS=$(git diff --cached --name-only --diff-filter=ACM | grep '\.opencode/agents/.*\.md$' || true)

if [ -z "$STAGED_AGENTS" ]; then
    echo "No agent .md files to validate"
    exit 0
fi

VALIDATOR="./scripts/validate-agent-migration.sh"

if [ ! -f "$VALIDATOR" ]; then
    echo "Warning: Validation script not found at: $VALIDATOR"
    echo "Skipping agent migration validation"
    exit 0
fi

# Pass staged files directly to the validator
# shellcheck disable=SC2086
if ! "$VALIDATOR" $STAGED_AGENTS; then
    echo ""
    echo "Agent frontmatter validation failed"
    echo "  Remove tools: and permission: blocks from agent .md files"
    echo "  Define permissions in opencode.json under agent.<name>.permission"
    exit 1
fi

echo "All staged agent files validated successfully"
exit 0
