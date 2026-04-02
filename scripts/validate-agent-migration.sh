#!/usr/bin/env bash

# Validate that agent .md files have been fully migrated:
# - No tools: block
# - No permission: block
# - Frontmatter contains only description: and mode:
#
# Usage:
#   ./scripts/validate-agent-migration.sh           # validate all agents
#   ./scripts/validate-agent-migration.sh path/to/agent.md  # validate one file

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

AGENTS_DIR=".opencode/agents"
FAILED=0
CHECKED=0

validate_agent() {
    local file="$1"
    local name
    name=$(basename "$file")

    # Extract frontmatter block (between first and second ---)
    local frontmatter
    frontmatter=$(awk '/^---/{count++; if(count==2) exit} count==1{print}' "$file")

    local file_failed=0

    # Check for forbidden blocks
    if echo "$frontmatter" | grep -qE '^tools:'; then
        echo -e "  ${RED}FAIL${NC}  $name — frontmatter contains 'tools:' block (must be removed)"
        file_failed=1
    fi

    if echo "$frontmatter" | grep -qE '^permission:'; then
        echo -e "  ${RED}FAIL${NC}  $name — frontmatter contains 'permission:' block (must be in opencode.json)"
        file_failed=1
    fi

    # Check that required fields exist
    if ! echo "$frontmatter" | grep -qE '^description:'; then
        echo -e "  ${RED}FAIL${NC}  $name — frontmatter missing 'description:' field"
        file_failed=1
    fi

    if ! echo "$frontmatter" | grep -qE '^mode:'; then
        echo -e "  ${RED}FAIL${NC}  $name — frontmatter missing 'mode:' field"
        file_failed=1
    fi

    if [ "$file_failed" -eq 0 ]; then
        echo -e "  ${GREEN}OK${NC}    $name"
    else
        FAILED=$((FAILED + 1))
    fi

    CHECKED=$((CHECKED + 1))
}

echo "Validating agent frontmatter migration..."
echo ""

if [ "$#" -gt 0 ]; then
    # Validate specific files passed as arguments
    for f in "$@"; do
        if [ ! -f "$f" ]; then
            echo -e "  ${YELLOW}WARN${NC}  $f — file not found, skipping"
            continue
        fi
        validate_agent "$f"
    done
else
    # Validate all .md files in the agents directory
    if [ ! -d "$AGENTS_DIR" ]; then
        echo -e "${RED}ERROR${NC}: Agents directory not found: $AGENTS_DIR"
        exit 1
    fi

    for f in "$AGENTS_DIR"/*.md; do
        [ -f "$f" ] || continue
        validate_agent "$f"
    done
fi

echo ""
echo "========================================="
if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}FAILED${NC}: $FAILED / $CHECKED agent file(s) have migration issues"
    echo "  - Remove 'tools:' and 'permission:' blocks from agent .md frontmatter"
    echo "  - Ensure permissions are defined in opencode.json under agent.<name>.permission"
    exit 1
else
    echo -e "${GREEN}PASSED${NC}: All $CHECKED agent file(s) are correctly migrated"
    exit 0
fi
