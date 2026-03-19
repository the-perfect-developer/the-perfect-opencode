#!/usr/bin/env bash

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Get the installation directory
# When piped from curl, BASH_SOURCE[0] is /dev/fd/XX or /proc/self/fd/XX
# In that case, or when run from any location, install to current directory
if [[ "${BASH_SOURCE[0]}" == "/dev/fd/"* ]] || [[ "${BASH_SOURCE[0]}" == "/proc/self/fd/"* ]]; then
    # Being piped from curl or process substitution
    REPO_ROOT="$(pwd)"
else
    # Running as a downloaded script file - still use current directory
    # This allows users to run the script from wherever they want to install
    REPO_ROOT="$(pwd)"
fi

REPO_URL="https://github.com/the-perfect-developer/the-perfect-opencode"
TEMP_DIR="/tmp/the-perfect-opencode-$$"

# Arrays to store selected items
declare -a SELECTED_AGENTS
declare -a SELECTED_SKILLS
declare -a SELECTED_COMMANDS

# Core items that are always installed (bare minimum requirements)
CORE_AGENTS=("architect" "backend-engineer" "code-analyst" "frontend-engineer" "ideation-expert" "junior-engineer" "performance-engineer" "security-expert")
CORE_SKILLS=("agent-configuration" "command-creation" "conventional-git-commit" "ideation" "interactive-questions" "skill-creation" "planning" "implementation")
CORE_COMMANDS=("create-agent" "create-command" "create-rule" "create-skill" "extended-implement" "extended-plan" "git-commit" "git-push" "ideate" "implement" "install-perfect-tools" "plan" "quickee" "sync-perfect-configs" "update-perfect-tools")

# Deprecated items that are removed on install if found in the current directory
DEPRECATED_AGENTS=()
DEPRECATED_SKILLS=()
DEPRECATED_COMMANDS=("git-stage-commit-push" "git-commit-push")

# Parse command line arguments
INSTALL_ALL=true
for arg in "$@"; do
    case "$arg" in
        agent:*)
            INSTALL_ALL=false
            SELECTED_AGENTS+=("${arg#agent:}")
            ;;
        skill:*)
            INSTALL_ALL=false
            SELECTED_SKILLS+=("${arg#skill:}")
            ;;
        command:*)
            INSTALL_ALL=false
            SELECTED_COMMANDS+=("${arg#command:}")
            ;;
        *)
            echo -e "${YELLOW}Warning:${NC} Unknown argument format: $arg"
            echo "Use: agent:<name>, skill:<name>, or command:<name>"
            ;;
    esac
done

print_header() {
    echo -e "${BLUE}"
    cat << "EOF"
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
EOF
    echo -e "${NC}"
}

cleanup() {
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
}

print_header
echo ""

# Show what will be installed
if [ "$INSTALL_ALL" = true ]; then
    echo -e "${BLUE}ℹ${NC} Installing all agents, skills, and commands"
else
    echo -e "${BLUE}ℹ${NC} Selective installation:"
    if [ ${#SELECTED_AGENTS[@]} -gt 0 ]; then
        echo -e "  Agents: ${SELECTED_AGENTS[*]}"
    fi
    if [ ${#SELECTED_SKILLS[@]} -gt 0 ]; then
        echo -e "  Skills: ${SELECTED_SKILLS[*]}"
    fi
    if [ ${#SELECTED_COMMANDS[@]} -gt 0 ]; then
        echo -e "  Commands: ${SELECTED_COMMANDS[*]}"
    fi
fi
echo ""

# Check requirements
if ! command -v curl &> /dev/null || ! command -v tar &> /dev/null; then
    echo -e "${RED}✗${NC} curl and tar are required"
    exit 1
fi

# Download and extract
mkdir -p "$TEMP_DIR"
trap cleanup EXIT

if ! curl -fsSL "${REPO_URL}/archive/refs/heads/main.tar.gz" | tar -xz -C "$TEMP_DIR"; then
    echo -e "${RED}✗${NC} Download failed"
    exit 1
fi


# ─── Install Agents, Skills, and Commands ──────────────────────────────────────────────────────

# Install to .opencode/agents
AGENTS_DIR="${REPO_ROOT}/.opencode/agents"
mkdir -p "$AGENTS_DIR"

AGENTS_SOURCE_DIR="${TEMP_DIR}/the-perfect-opencode-main/.opencode/agents"
if [ -d "$AGENTS_SOURCE_DIR" ]; then
    if [ "$INSTALL_ALL" = true ] || [ ${#SELECTED_AGENTS[@]} -gt 0 ]; then
        echo -e "${BLUE}ℹ${NC} Installing agents to ${AGENTS_DIR}..."
        for agent in "${AGENTS_SOURCE_DIR}"/*; do
            if [ -f "$agent" ]; then
                agent_name=$(basename "$agent" .md)

                # Check if this is a core agent (always installed regardless of selection)
                is_core=false
                for core_agent in "${CORE_AGENTS[@]}"; do
                    if [ "$agent_name" = "$core_agent" ]; then
                        is_core=true
                        break
                    fi
                done

                # Always install core agents
                if [ "$is_core" = true ]; then
                    cp "$agent" "${AGENTS_DIR}/"
                    echo -e "  ${GREEN}✓${NC} Installed core agent: ${agent_name}"
                # Install all non-core agents when INSTALL_ALL, or check selected list
                elif [ "$INSTALL_ALL" = true ]; then
                    cp "$agent" "${AGENTS_DIR}/"
                    echo -e "  ${GREEN}✓${NC} Installed agent: ${agent_name}"
                else
                    for selected in "${SELECTED_AGENTS[@]}"; do
                        if [ "$agent_name" = "$selected" ]; then
                            cp "$agent" "${AGENTS_DIR}/"
                            echo -e "  ${GREEN}✓${NC} Installed agent: ${agent_name}"
                            break
                        fi
                    done
                fi
            fi
        done
    fi
fi

# Install to .opencode/skills
SKILLS_DIR="${REPO_ROOT}/.opencode/skills"
mkdir -p "$SKILLS_DIR"

SOURCE_DIR="${TEMP_DIR}/the-perfect-opencode-main/.opencode/skills"
if [ -d "$SOURCE_DIR" ]; then
    if [ "$INSTALL_ALL" = true ] || [ ${#SELECTED_SKILLS[@]} -gt 0 ]; then
        echo -e "${BLUE}ℹ${NC} Installing skills to ${SKILLS_DIR}..."
        for skill in "${SOURCE_DIR}"/*; do
            if [ -d "$skill" ]; then
                skill_name=$(basename "$skill")

                # Check if this is a core skill (always installed regardless of selection)
                is_core=false
                for core_skill in "${CORE_SKILLS[@]}"; do
                    if [ "$skill_name" = "$core_skill" ]; then
                        is_core=true
                        break
                    fi
                done

                # Always install core skills
                if [ "$is_core" = true ]; then
                    rm -rf "${SKILLS_DIR}/${skill_name}"
                    cp -r "$skill" "${SKILLS_DIR}/"
                    echo -e "  ${GREEN}✓${NC} Installed core skill: ${skill_name}"
                # Install all non-core skills when INSTALL_ALL, or check selected list
                elif [ "$INSTALL_ALL" = true ]; then
                    rm -rf "${SKILLS_DIR}/${skill_name}"
                    cp -r "$skill" "${SKILLS_DIR}/"
                    echo -e "  ${GREEN}✓${NC} Installed skill: ${skill_name}"
                else
                    for selected in "${SELECTED_SKILLS[@]}"; do
                        if [ "$skill_name" = "$selected" ]; then
                            rm -rf "${SKILLS_DIR}/${skill_name}"
                            cp -r "$skill" "${SKILLS_DIR}/"
                            echo -e "  ${GREEN}✓${NC} Installed skill: ${skill_name}"
                            break
                        fi
                    done
                fi
            fi
        done
    fi
fi

# Install to .opencode/commands
COMMANDS_DIR="${REPO_ROOT}/.opencode/commands"
mkdir -p "$COMMANDS_DIR"

COMMANDS_SOURCE_DIR="${TEMP_DIR}/the-perfect-opencode-main/.opencode/commands"
if [ -d "$COMMANDS_SOURCE_DIR" ]; then
    if [ "$INSTALL_ALL" = true ] || [ ${#SELECTED_COMMANDS[@]} -gt 0 ]; then
        echo -e "${BLUE}ℹ${NC} Installing commands to ${COMMANDS_DIR}..."
        for cmd in "${COMMANDS_SOURCE_DIR}"/*; do
            if [ -f "$cmd" ]; then
                cmd_name=$(basename "$cmd" .md)

                # Check if this is a core command (always installed regardless of selection)
                is_core=false
                for core_cmd in "${CORE_COMMANDS[@]}"; do
                    if [ "$cmd_name" = "$core_cmd" ]; then
                        is_core=true
                        break
                    fi
                done

                # Always install core commands
                if [ "$is_core" = true ]; then
                    cp "$cmd" "${COMMANDS_DIR}/"
                    echo -e "  ${GREEN}✓${NC} Installed core command: ${cmd_name}"
                # Install all non-core commands when INSTALL_ALL, or check selected list
                elif [ "$INSTALL_ALL" = true ]; then
                    cp "$cmd" "${COMMANDS_DIR}/"
                    echo -e "  ${GREEN}✓${NC} Installed command: ${cmd_name}"
                else
                    for selected in "${SELECTED_COMMANDS[@]}"; do
                        if [ "$cmd_name" = "$selected" ]; then
                            cp "$cmd" "${COMMANDS_DIR}/"
                            echo -e "  ${GREEN}✓${NC} Installed command: ${cmd_name}"
                            break
                        fi
                    done
                fi
            fi
        done
    fi
fi

echo ""
echo -e "${BLUE}ℹ${NC} Installation complete!"
if [ "$INSTALL_ALL" = true ] || [ ${#SELECTED_AGENTS[@]} -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Agents installed to: ${AGENTS_DIR}"
fi
if [ "$INSTALL_ALL" = true ] || [ ${#SELECTED_SKILLS[@]} -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Skills installed to: ${SKILLS_DIR}"
fi
if [ "$INSTALL_ALL" = true ] || [ ${#SELECTED_COMMANDS[@]} -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Commands installed to: ${COMMANDS_DIR}"
fi



# ─── Deprecation Cleanup ──────────────────────────────────────────────────────
# Always runs on every install. Removes deprecated items from the current
# directory so users are not left with stale/renamed tools.
_remove_deprecated() {
    local label="$1"   # e.g. "agent", "skill", "command"
    local dir="$2"     # target directory to check
    local ext="$3"     # file extension with dot, or empty string for directories
    shift 3
    local items=("$@")

    for item in "${items[@]}"; do
        if [ -n "$ext" ]; then
            local path="${dir}/${item}${ext}"
            if [ -f "$path" ]; then
                rm -f "$path"
                echo -e "  ${YELLOW}⚠${NC} Removed deprecated ${label}: ${item}"
            fi
        else
            local path="${dir}/${item}"
            if [ -d "$path" ]; then
                rm -rf "$path"
                echo -e "  ${YELLOW}⚠${NC} Removed deprecated ${label}: ${item}"
            fi
        fi
    done
}

deprecated_found=false

if [ ${#DEPRECATED_AGENTS[@]} -gt 0 ]; then
    for item in "${DEPRECATED_AGENTS[@]}"; do
        if [ -f "${REPO_ROOT}/.opencode/agents/${item}.md" ]; then
            deprecated_found=true
            break
        fi
    done
fi

if [ "$deprecated_found" = false ] && [ ${#DEPRECATED_SKILLS[@]} -gt 0 ]; then
    for item in "${DEPRECATED_SKILLS[@]}"; do
        if [ -d "${REPO_ROOT}/.opencode/skills/${item}" ]; then
            deprecated_found=true
            break
        fi
    done
fi

if [ "$deprecated_found" = false ] && [ ${#DEPRECATED_COMMANDS[@]} -gt 0 ]; then
    for item in "${DEPRECATED_COMMANDS[@]}"; do
        if [ -f "${REPO_ROOT}/.opencode/commands/${item}.md" ]; then
            deprecated_found=true
            break
        fi
    done
fi

if [ "$deprecated_found" = true ]; then
    echo -e "${YELLOW}⚠${NC} Removing deprecated items..."
    _remove_deprecated "agent"   "${REPO_ROOT}/.opencode/agents"   ".md"  "${DEPRECATED_AGENTS[@]+"${DEPRECATED_AGENTS[@]}"}"
    _remove_deprecated "skill"   "${REPO_ROOT}/.opencode/skills"   ""     "${DEPRECATED_SKILLS[@]+"${DEPRECATED_SKILLS[@]}"}"
    _remove_deprecated "command" "${REPO_ROOT}/.opencode/commands" ".md"  "${DEPRECATED_COMMANDS[@]+"${DEPRECATED_COMMANDS[@]}"}"
    echo ""
fi


# ─── Custom Post-Install ──────────────────────────────────────────────────────
# Custom actions that always run, regardless of install arguments.
echo ""
echo -e "${BLUE}ℹ${NC} Running custom post-install steps..."


# Copy opencode.json to the installation directory
OPENCODE_JSON_SOURCE="${TEMP_DIR}/the-perfect-opencode-main/opencode.json"
OPENCODE_JSON_DEST="${REPO_ROOT}/opencode.json"
if [ -f "$OPENCODE_JSON_SOURCE" ]; then
    if [ -f "$OPENCODE_JSON_DEST" ]; then
        echo -e "  ${YELLOW}⚠${NC} opencode.json already exists at: ${OPENCODE_JSON_DEST}"
        echo -e "  ${BLUE}💡 Tip:${NC} To avoid conflicts, open OpenCode and run ${GREEN}/sync-perfect-configs${NC}"
        echo -e "     This will compare your config with the remote and apply only the necessary changes."
        echo ""
        read -r -p "  Overwrite anyway? [y/N] " response
        case "$response" in
            [yY][eE][sS]|[yY])
                cp "$OPENCODE_JSON_SOURCE" "$OPENCODE_JSON_DEST"
                echo -e "  ${GREEN}✓${NC} Overwritten: ${OPENCODE_JSON_DEST}"
                ;;
            *)
                echo -e "  ${BLUE}ℹ${NC} Skipped opencode.json"
                ;;
        esac
    else
        cp "$OPENCODE_JSON_SOURCE" "$OPENCODE_JSON_DEST"
        echo -e "  ${GREEN}✓${NC} Copied opencode.json to: ${REPO_ROOT}"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} opencode.json not found in repository, skipping"
fi