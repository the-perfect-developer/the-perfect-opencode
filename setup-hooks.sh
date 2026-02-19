#!/bin/bash

# Setup script to install git hooks
# Run this after cloning the repository

set -e

echo "🔧 Setting up git hooks..."

# Get the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)

# Configure git to use .githooks directory
git config core.hooksPath .githooks

echo "✅ Git hooks configured successfully!"
echo ""
echo "The following hooks are now active:"
echo "  - pre-commit: Validates bash script syntax"
echo ""
echo "Hooks directory: .githooks/"
