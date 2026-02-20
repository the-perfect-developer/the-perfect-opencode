#!/bin/bash

# Script to catalog all agents, skills, and commands from the .opencode folder
# Outputs a JSON file with names and descriptions

set -e

# Define paths
OPENCODE_DIR=".opencode"
OUTPUT_FILE="opencode-catalog.json"

# Initialize JSON structure
CATALOG='{
  "agents": [],
  "skills": [],
  "commands": [],
  "generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
}'

# Function to extract frontmatter value
# Usage: extract_frontmatter "key" "file_path"
extract_frontmatter() {
    local key="$1"
    local file="$2"
    
    # Extract the value between --- delimiters, looking for the key
    awk -v key="$key" '
        BEGIN { in_frontmatter = 0 }
        /^---$/ { in_frontmatter = !in_frontmatter; next }
        in_frontmatter && $0 ~ "^" key ":" {
            # Extract value after the key
            sub("^" key ":[[:space:]]*", "")
            # Remove quotes if present
            gsub("\"", "")
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            print
            exit
        }
    ' "$file"
}

echo "Scanning .opencode folder for agents, skills, and commands..."

# Process Agents
echo "Processing agents..."
for agent_file in "$OPENCODE_DIR"/agents/*.md; do
    if [ -f "$agent_file" ]; then
        name=$(basename "$agent_file" .md)
        description=$(extract_frontmatter "description" "$agent_file")
        
        CATALOG=$(echo "$CATALOG" | jq \
            --arg name "$name" \
            --arg desc "$description" \
            '.agents += [{"name": $name, "description": $desc}]')
    fi
done

# Process Skills
echo "Processing skills..."
for skill_dir in "$OPENCODE_DIR"/skills/*/; do
    if [ -d "$skill_dir" ]; then
        skill_file="$skill_dir/SKILL.md"
        if [ -f "$skill_file" ]; then
            name=$(basename "$skill_dir")
            description=$(extract_frontmatter "description" "$skill_file")
            
            CATALOG=$(echo "$CATALOG" | jq \
                --arg name "$name" \
                --arg desc "$description" \
                '.skills += [{"name": $name, "description": $desc}]')
        fi
    fi
done

# Process Commands
echo "Processing commands..."
for command_file in "$OPENCODE_DIR"/commands/*.md; do
    if [ -f "$command_file" ]; then
        name=$(basename "$command_file" .md)
        description=$(extract_frontmatter "description" "$command_file")
        
        CATALOG=$(echo "$CATALOG" | jq \
            --arg name "$name" \
            --arg desc "$description" \
            '.commands += [{"name": $name, "description": $desc}]')
    fi
done

# Write output to JSON file
echo "$CATALOG" | jq '.' > "$OUTPUT_FILE"

echo "✓ Catalog generated successfully!"
echo "Output file: $OUTPUT_FILE"
echo ""
echo "Summary:"
echo "  Agents: $(echo "$CATALOG" | jq '.agents | length')"
echo "  Skills: $(echo "$CATALOG" | jq '.skills | length')"
echo "  Commands: $(echo "$CATALOG" | jq '.commands | length')"
