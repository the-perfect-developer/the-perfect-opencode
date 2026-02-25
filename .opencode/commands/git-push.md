---
description: Push commits to remote repository
agent: build
model: github-copilot/claude-haiku-4.5
---

You are about to push commits to the remote git repository. Follow these steps carefully:

## Step 1: Analyze Current State

Check the current git state:
!`git status`

View commits to be pushed:
!`git log --oneline @{u}..HEAD`

View remote tracking information:
!`git branch -vv`

## Step 2: Check for Commits to Push

Before proceeding, check if there are any commits to push:

!`git log --oneline @{u}..HEAD`

If there are NO commits to push, inform the user:
```
No commits found to push. Your local branch is already up to date with the remote.

If you want to commit changes, please use:
- git-stage-commit-push (to stage, commit and push)
- git-commit-push (to commit staged changes and push)
```

Then stop the process.

## Step 3: Present Summary to User

```
## Summary
[1-2 sentence overall description of commits to push]

## Commits to Push

1. [commit message]
2. [commit message]
3. [commit message]

## Target
Branch: [branch name]
Remote: [remote name]
Status: [commits ahead/details]

## Attention Required

Check for potential issues by running:
!`git log @{u}..HEAD --name-only --pretty=format:"" | sort -u | grep -v "^$" | xargs -I{} find {} -maxdepth 0 -size +1M 2>/dev/null`
!`git log @{u}..HEAD --name-only --pretty=format:"" | sort -u | grep -v "^$" | grep -E "\.env$|\.env\.|credentials|secrets|\.pem$|\.key$|\.p12$|\.pfx$|id_rsa|id_dsa|id_ecdsa"`

⚠️  **WARNINGS** (if any found):
- Large files (>1MB): [list files or "None"]
- Potential secrets/credentials: [list files or "None"]
- Other issues: [list or "None"]

If no issues: "None - safe to proceed"

---

Is it okay to proceed with pushing these commits?
```

Then:
1. **Analyze commits to be pushed**
2. **Provide the formatted summary** to the user
3. **Ask for confirmation** before proceeding with the push

## Step 4: Push to Remote

Only after receiving user confirmation:

1. Push to the remote repository: `git push`
2. If push fails:
    - Show the error message to the user
    - Explain what went wrong (e.g., conflicts, rejected push, authentication issues)
    - Suggest solutions if applicable
    - Do not force push unless the user explicitly requests it
3. Verify the push was successful: `git status`

## Important Notes

- **DO NOT** push without user confirmation
- **NEVER** force push to main/master branch unless user explicitly requests it
- **DO** warn the user if they're about to force push
- **DO** provide clear feedback on what was pushed
- **DO** handle any errors gracefully and report them to the user
- **NOTE**: This command ONLY pushes existing commits (no staging or committing occurs)

## Example Workflow

1. Show commits to be pushed ✓
2. Show target branch and remote ✓
3. Check for warnings (large files/secrets) ✓
4. Ask: "Is it okay to proceed with pushing?" ✓
5. Wait for user confirmation ✓
6. Push: `git push`
7. Verify: `git status`
8. Confirm: "✓ Commits pushed successfully to origin/main"
