---
description: Push committed changes to remote — never stages or commits anything
agent: developer-fast
---

Push the committed (but not yet pushed) changes to the remote repository.

**HARD CONSTRAINT**: This command only pushes. It MUST NOT stage files, create commits, amend commits, or modify the working tree or index in any way. If there is nothing to push, say so and stop.

## Step 1: Check Repository State

!`git status --short`
!`git branch -vv`
!`git log --oneline @{u}..HEAD 2>/dev/null || git log --oneline -10`

If empty, respond:

```
Nothing to push. Your local branch is already up to date with the remote.

To create commits first, use:
  /git-commit       — commit already-staged changes
  /git-commit-push  — commit staged changes and push in one step
```

## Step 2: Scan Commits for Anomalies

Check files in unpushed commits:

**Large files (>1 MB):**
!`git log @{u}..HEAD --name-only --pretty=format:"" 2>/dev/null | sort -u | grep -v "^$" | xargs -I{} find {} -maxdepth 0 -size +1M 2>/dev/null`

**Suspicious filenames:**
!`git log @{u}..HEAD --name-only --pretty=format:"" 2>/dev/null | sort -u | grep -v "^$" | grep -Ei "\.env$|\.env\.|credentials|secrets|\.pem$|\.key$|\.p12$|\.pfx$|id_rsa|id_dsa|id_ecdsa|\.password|api_key|token" | head -20`

**Secret-like patterns:**
!`git diff @{u}..HEAD 2>/dev/null | grep -Ei "(password|secret|api_key|access_token|private_key|client_secret)\s*[:=]\s*['\"]?[A-Za-z0-9+/]{8,}" | head -10`

If anomalies found, include warnings in summary.

## Step 3: Present Summary and Ask for Confirmation

```
## Push Summary

### Commits to Push
[List each unpushed commit: hash — subject line]

### Target
- Branch : [local branch name]
- Remote : [remote name, e.g. origin]
- URL    : [remote URL]

### Anomaly Check
- Large files (>1 MB) : [list or "None"]
- Suspicious filenames: [list or "None"]
- Secret-like content : [list or "None"]
```

If anomalies found, add warning block before asking.

Ask:

```
Proceed with git push? (yes / no)
```

Wait for response.
- If yes: proceed to Step 4.
- If no: stop and inform push cancelled.

## Step 4: Check if Remote Has Diverged

Check if remote has commits local does not:
!`git fetch`
!`git log --oneline HEAD..@{u} 2>/dev/null`

If shows commits, rebase required. Proceed to Step 5. Otherwise skip to Step 6.

## Step 5: Rebase onto Remote (if required)

Rebase local commits on top:

1. Run `git rebase @{u}`.
2. If clean, confirm:
   ```
   Rebase complete. Local commits replayed on top of [remote]/[branch].
   ```
   Proceed to Step 6.
3. If conflicts:
   - Show conflicting files: `git diff --name-only --diff-filter=U`
   - Present conflicts to user.
   - Resolve in affected files.
   - Stage resolutions: `git add <resolved-files>`
   - Continue: `git rebase --continue`
   - Repeat until complete.
   - Abort if user wants: `git rebase --abort`
4. Do not use `git rebase -i`. Use plain `git rebase @{u}`.
5. Do not amend or squash unless explicitly asked.

## Step 6: Push

1. Run `git push`.
2. If rejected after rebase:
   - Show error.
   - Explain cause.
   - Ask what to do.
   - Never force push unless explicitly asked and not main/master. If asked for main/master, warn and confirm twice.
3. If succeeds:
   ```
   Pushed: [branch] -> [remote]/[branch]  ([N] commit(s))
   ```
4. If fails otherwise:
   - Show error.
   - Suggest remediation.
   - Do not retry.