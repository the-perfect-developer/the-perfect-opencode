#!/usr/bin/env bash

set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Get the installation directory
# When piped from curl, BASH_SOURCE[0] is /dev/fd/XX or /proc/self/fd/XX
# In that case, or when run from any location, install to current directory
# Always install to the current working directory,
# whether invoked as a file or via process substitution (bash <(curl …)).
REPO_ROOT="$(pwd)"

REPO_URL="https://github.com/the-perfect-developer/the-perfect-opencode"
TEMP_DIR="/tmp/the-perfect-opencode-$$"

# Arrays to store selected items
declare -a SELECTED_AGENTS=()
declare -a SELECTED_SKILLS=()
declare -a SELECTED_COMMANDS=()

# Arrays to record items actually installed in this run
declare -a INSTALLED_AGENTS=()
declare -a INSTALLED_SKILLS=()
declare -a INSTALLED_COMMANDS=()

# Core items that are always installed (bare minimum requirements)
CORE_AGENTS=("code-analyst" "database-architect" "developer-fast" "developer-prime" "devops-engineer" "orchestrix" "performance-engineer" "principal-architect" "security-expert" "solution-architect" "test-engineer" "ui-ux-designer")
CORE_SKILLS=("agent-configuration" "command-creation" "conventional-git-commit" "interactive-questions" "perfectcode-zen-evaluation" "perfectcode-zen-ideation" "perfectcode-zen-implement" "perfectcode-zen-plan" "skill-creation")
CORE_COMMANDS=("create-agent" "create-command" "create-rule" "create-skill" "evaluate" "git-commit" "git-push" "ideate" "implement" "install-perfect-tools" "plan" "recommend-perfect-tool" "sync-perfect-configs" "update-perfect-tools")

# Deprecated items that are removed on install if found in the current directory
DEPRECATED_AGENTS=("architect" "backend-engineer" "frontend-engineer" "ideation-expert" "junior-engineer")
DEPRECATED_SKILLS=("planning" "implementation" "ideation")
DEPRECATED_COMMANDS=("git-stage-commit-push" "git-commit-push" "extended-implement" "extended-plan" "quickee")

# Parse command line arguments
# Default: core-only. Pass --all to install everything.
INSTALL_ALL=false
for arg in "$@"; do
    case "$arg" in
        --all)
            INSTALL_ALL=true
            ;;
        agent:*)
            SELECTED_AGENTS+=("${arg#agent:}")
            ;;
        skill:*)
            SELECTED_SKILLS+=("${arg#skill:}")
            ;;
        command:*)
            SELECTED_COMMANDS+=("${arg#command:}")
            ;;
        *)
            echo -e "${YELLOW}Warning:${NC} Unknown argument format: $arg"
            echo "Use: --all, agent:<name>, skill:<name>, or command:<name>"
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
elif [ ${#SELECTED_AGENTS[@]} -eq 0 ] && [ ${#SELECTED_SKILLS[@]} -eq 0 ] && [ ${#SELECTED_COMMANDS[@]} -eq 0 ]; then
    echo -e "${BLUE}ℹ${NC} Installing core items only (pass ${GREEN}--all${NC} to install everything)"
    echo ""
    echo -e "  ${GREEN}Core agents${NC} (${#CORE_AGENTS[@]}):"
    for item in "${CORE_AGENTS[@]}"; do
        echo -e "    • ${item}"
    done
    echo -e "  ${GREEN}Core skills${NC} (${#CORE_SKILLS[@]}):"
    for item in "${CORE_SKILLS[@]}"; do
        echo -e "    • ${item}"
    done
    echo -e "  ${GREEN}Core commands${NC} (${#CORE_COMMANDS[@]}):"
    for item in "${CORE_COMMANDS[@]}"; do
        echo -e "    • ${item}"
    done
else
    echo -e "${BLUE}ℹ${NC} Selective installation:"
    if [ ${#SELECTED_AGENTS[@]} -gt 0 ]; then
        echo -e "  Agents: ${SELECTED_AGENTS[*]+"${SELECTED_AGENTS[*]}"}"
    fi
    if [ ${#SELECTED_SKILLS[@]} -gt 0 ]; then
        echo -e "  Skills: ${SELECTED_SKILLS[*]+"${SELECTED_SKILLS[*]}"}"
    fi
    if [ ${#SELECTED_COMMANDS[@]} -gt 0 ]; then
        echo -e "  Commands: ${SELECTED_COMMANDS[*]+"${SELECTED_COMMANDS[*]}"}"
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
                INSTALLED_AGENTS+=("$agent_name")
            # Install all non-core agents when INSTALL_ALL, or check selected list
            elif [ "$INSTALL_ALL" = true ]; then
                cp "$agent" "${AGENTS_DIR}/"
                INSTALLED_AGENTS+=("$agent_name")
            else
                for selected in "${SELECTED_AGENTS[@]+"${SELECTED_AGENTS[@]}"}"; do
                    if [ "$agent_name" = "$selected" ]; then
                        cp "$agent" "${AGENTS_DIR}/"
                        INSTALLED_AGENTS+=("$agent_name")
                        break
                    fi
                done
            fi
        fi
    done
fi


# Install to .opencode/skills
SKILLS_DIR="${REPO_ROOT}/.opencode/skills"
mkdir -p "$SKILLS_DIR"

SOURCE_DIR="${TEMP_DIR}/the-perfect-opencode-main/.opencode/skills"
if [ -d "$SOURCE_DIR" ]; then
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
                INSTALLED_SKILLS+=("$skill_name")
            # Install all non-core skills when INSTALL_ALL, or check selected list
            elif [ "$INSTALL_ALL" = true ]; then
                rm -rf "${SKILLS_DIR}/${skill_name}"
                cp -r "$skill" "${SKILLS_DIR}/"
                INSTALLED_SKILLS+=("$skill_name")
            else
                for selected in "${SELECTED_SKILLS[@]+"${SELECTED_SKILLS[@]}"}"; do
                    if [ "$skill_name" = "$selected" ]; then
                        rm -rf "${SKILLS_DIR}/${skill_name}"
                        cp -r "$skill" "${SKILLS_DIR}/"
                        INSTALLED_SKILLS+=("$skill_name")
                        break
                    fi
                done
            fi
        fi
    done
fi


# Install to .opencode/commands
COMMANDS_DIR="${REPO_ROOT}/.opencode/commands"
mkdir -p "$COMMANDS_DIR"

COMMANDS_SOURCE_DIR="${TEMP_DIR}/the-perfect-opencode-main/.opencode/commands"
if [ -d "$COMMANDS_SOURCE_DIR" ]; then
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
                INSTALLED_COMMANDS+=("$cmd_name")
            # Install all non-core commands when INSTALL_ALL, or check selected list
            elif [ "$INSTALL_ALL" = true ]; then
                cp "$cmd" "${COMMANDS_DIR}/"
                INSTALLED_COMMANDS+=("$cmd_name")
            else
                for selected in "${SELECTED_COMMANDS[@]+"${SELECTED_COMMANDS[@]}"}"; do
                    if [ "$cmd_name" = "$selected" ]; then
                        cp "$cmd" "${COMMANDS_DIR}/"
                        INSTALLED_COMMANDS+=("$cmd_name")
                        break
                    fi
                done
            fi
        fi
    done
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


# ─── Manifest Generation ─────────────────────────────────────────────────────
# Builds .opencode/the-perfect-opencode.json listing every tool installed in
# this run. Reflects only the current run — overwritten on every install.
# Writes atomically via /tmp to avoid partially-written files.

_write_manifest() {
    local manifest_dest="${REPO_ROOT}/.opencode/the-perfect-opencode.json"
    local manifest_tmp="/tmp/tpo-manifest-$$.json"
    local install_mode
    local installed_at
    installed_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    mkdir -p "${REPO_ROOT}/.opencode"

    if [ "$INSTALL_ALL" = true ]; then
        install_mode="all"
    elif [ ${#SELECTED_AGENTS[@]} -eq 0 ] && [ ${#SELECTED_SKILLS[@]} -eq 0 ] && [ ${#SELECTED_COMMANDS[@]} -eq 0 ]; then
        install_mode="core"
    else
        install_mode="selective"
    fi

    # Build JSON arrays from tracking arrays
    local agents_json=""
    for item in "${INSTALLED_AGENTS[@]+"${INSTALLED_AGENTS[@]}"}"; do
        agents_json="${agents_json:+${agents_json}, }\"${item}\""
    done

    local skills_json=""
    for item in "${INSTALLED_SKILLS[@]+"${INSTALLED_SKILLS[@]}"}"; do
        skills_json="${skills_json:+${skills_json}, }\"${item}\""
    done

    local commands_json=""
    for item in "${INSTALLED_COMMANDS[@]+"${INSTALLED_COMMANDS[@]}"}"; do
        commands_json="${commands_json:+${commands_json}, }\"${item}\""
    done

    printf '{\n' > "$manifest_tmp"
    printf '  "schema_version": "1",\n' >> "$manifest_tmp"
    printf '  "installed_at": "%s",\n' "$installed_at" >> "$manifest_tmp"
    printf '  "mode": "%s",\n' "$install_mode" >> "$manifest_tmp"
    printf '  "agents": [%s],\n' "$agents_json" >> "$manifest_tmp"
    printf '  "skills": [%s],\n' "$skills_json" >> "$manifest_tmp"
    printf '  "commands": [%s]\n' "$commands_json" >> "$manifest_tmp"
    printf '}\n' >> "$manifest_tmp"

    mv "$manifest_tmp" "$manifest_dest"
    echo -e "  ${GREEN}✓${NC} Manifest written to: ${manifest_dest}"
}

# Prints a human-readable installed-tools summary grouped by category.
_print_installed_report() {
    local agent_count="${#INSTALLED_AGENTS[@]}"
    local skill_count="${#INSTALLED_SKILLS[@]}"
    local command_count="${#INSTALLED_COMMANDS[@]}"

    echo ""
    echo -e "${BLUE}ℹ${NC} Installed tools:"

    echo -e "  ${GREEN}Agents${NC} (${agent_count}):"
    for item in "${INSTALLED_AGENTS[@]+"${INSTALLED_AGENTS[@]}"}"; do
        echo -e "    • ${item}"
    done

    echo -e "  ${GREEN}Skills${NC} (${skill_count}):"
    for item in "${INSTALLED_SKILLS[@]+"${INSTALLED_SKILLS[@]}"}"; do
        echo -e "    • ${item}"
    done

    echo -e "  ${GREEN}Commands${NC} (${command_count}):"
    for item in "${INSTALLED_COMMANDS[@]+"${INSTALLED_COMMANDS[@]}"}"; do
        echo -e "    • ${item}"
    done
}


_write_manifest
_print_installed_report

echo ""
echo -e "${BLUE}ℹ${NC} Installation complete!"
echo -e "  ${GREEN}✓${NC} Agents installed to: ${AGENTS_DIR}"
echo -e "  ${GREEN}✓${NC} Skills installed to: ${SKILLS_DIR}"
echo -e "  ${GREEN}✓${NC} Commands installed to: ${COMMANDS_DIR}"


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
        if [ ! -t 0 ]; then
            echo -e "  ${BLUE}ℹ${NC} Non-interactive mode — skipping opencode.json prompt (keeping existing file)"
        else
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
        fi
    else
        cp "$OPENCODE_JSON_SOURCE" "$OPENCODE_JSON_DEST"
        echo -e "  ${GREEN}✓${NC} Copied opencode.json to: ${REPO_ROOT}"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} opencode.json not found in repository, skipping"
fi