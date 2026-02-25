---
description: Stage all files, commit with conventional commit message, and push to remote
agent: build
model: github-copilot/claude-haiku-4.5
---

You are about to stage all changes, commit with a conventional commit message, and push to the git repository. Follow these steps carefully:

## Step 0: Initial Warning and Confirmation

**FIRST**, present this warning to the user:

```
⚠️  Important Reminder

This command will stage ALL changes in your working directory, including AI-generated code.

It's recommended to review changes before staging, especially:
- Code written by AI that you haven't verified
- Files that may contain sensitive information
- Large or binary files

Are you sure you want to proceed with staging all changes?
(Type 'yes' to continue or 'no' to cancel)
```

**Wait for user confirmation before proceeding.**

If the user responds with anything other than affirmative confirmation (yes, y, ok, proceed, etc.), stop immediately and inform them:

```
Operation cancelled. Consider using:
- git-commit-push (to commit already staged changes)
- Manual review with `git add <specific-files>` for selective staging
```

## Step 1: Analyze Current State

Check the current git state:
!`git status`

View the changes:
!`git diff`

View staged changes (if any):
!`git diff --staged`

View recent commit history for style reference:
!`git log -5 --oneline`

## Step 2: Present Summary to User

Before committing, you MUST present a summary to the user in this exact format:

```
## Summary
[1-2 sentence overall description of changes]

## Files Changed

**Added:**
- filename.ext
  Summary: [brief description]

**Modified:**
- filename.ext
  Summary: [brief description]

**Deleted:**
- filename.ext
  Summary: [brief description]

## Proposed Commit Message
[conventional commit message]

## Attention Required

Check for potential issues by running:
!`git diff --name-only && git ls-files --others --exclude-standard | xargs -I{} find {} -maxdepth 0 -size +1M 2>/dev/null`
!`git ls-files --others --exclude-standard | grep -E "\.env$|\.env\.|credentials|secrets|\.pem$|\.key$|\.p12$|\.pfx$|id_rsa|id_dsa|id_ecdsa" | head -10`

⚠️  **WARNINGS** (if any found):
- Large files (>1MB): [list files or "None"]
- Potential secrets/credentials: [list files or "None"]
- Other issues: [list or "None"]

If no issues: "None - safe to proceed"

---

Is it okay to proceed with staging, committing, and pushing these changes?
```

Then:
1. **Analyze all changes** (both staged and unstaged)
2. **Provide the formatted summary** to the user
3. **Ask for confirmation** before proceeding with the commit

## Step 3: Commit with Conventional Commits

**IMPORTANT**: You MUST follow the Conventional Commits 1.0.0 specification.

Reference the conventional commit skill:
@.opencode/skills/conventional-git-commit/SKILL.md

Create a commit message that:
- Uses the correct type (feat, fix, docs, style, refactor, perf, test, build, ci, chore)
- Includes scope if appropriate (e.g., `feat(auth):`, `fix(parser):`)
- Has a clear, imperative-mood description
- Includes a body if the changes need explanation
- Uses `BREAKING CHANGE:` footer or `!` if there are breaking changes

## Step 4: Stage All, Commit, and Push

Only after receiving user confirmation:

1. Stage all changes: `git add .`
2. Create the commit with the conventional message
3. If commit validation fails (from hooks):
    - Show the validation error logs to the user
    - Ask the user if they want to take over and fix the issues, or attempt to rerun the commit
    - Do not proceed with the push until validation passes
4. Push to the remote repository: `git push`
5. Verify the push was successful with `git status`

## Important Notes

- **DO NOT** commit files that likely contain secrets (.env, credentials.json, etc.)
- **DO NOT** push without user confirmation
- **DO** warn the user if they're about to commit sensitive files
- **DO** provide clear feedback on what was committed and pushed
- **DO** handle any errors gracefully and report them to the user

## Example Workflow

1. Show initial warning and get user confirmation ✓
2. Show changes summary ✓
3. Show proposed commit message ✓
4. Check for warnings (large files/secrets) ✓
5. Ask: "Is it okay to proceed with this commit?" ✓
6. Wait for user confirmation ✓
7. Stage all files: `git add .`
8. Commit: `git commit -m "feat(commands): add new-command for automated deployment"`
9. Push: `git push`
10. Confirm: "✓ Changes staged, committed and pushed successfully"
