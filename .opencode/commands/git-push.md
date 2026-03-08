---
description: Push committed changes to remote — never stages or commits anything
agent: build
---

Push the committed (but not yet pushed) changes to the remote repository.

**HARD CONSTRAINT**: This command only pushes. It MUST NOT stage files, create commits, amend commits, or modify the working tree or index in any way. If there is nothing to push, say so and stop.

## Step 1: Check Repository State

Gather the current state:
!`git status --short`
!`git branch -vv`
!`git log --oneline @{u}..HEAD 2>/dev/null || git log --oneline -10`

If the output of `git log --oneline @{u}..HEAD` is **empty** (no commits ahead of the upstream), stop immediately and respond:

```
Nothing to push. Your local branch is already up to date with the remote.

To create commits first, use:
  /git-commit       — commit already-staged changes
  /git-commit-push  — commit staged changes and push in one step
```

Do not proceed any further.

## Step 2: Scan Commits for Anomalies

Before presenting the summary, check the files in commits that are about to be pushed:

**Large files (>1 MB) in unpushed commits:**
!`git log @{u}..HEAD --name-only --pretty=format:"" 2>/dev/null | sort -u | grep -v "^$" | xargs -I{} find {} -maxdepth 0 -size +1M 2>/dev/null`

**Suspicious filenames in unpushed commits:**
!`git log @{u}..HEAD --name-only --pretty=format:"" 2>/dev/null | sort -u | grep -v "^$" | grep -Ei "\.env$|\.env\.|credentials|secrets|\.pem$|\.key$|\.p12$|\.pfx$|id_rsa|id_dsa|id_ecdsa|\.password|api_key|token" | head -20`

**Secret-like patterns inside the unpushed diff:**
!`git diff @{u}..HEAD 2>/dev/null | grep -Ei "(password|secret|api_key|access_token|private_key|client_secret)\s*[:=]\s*['\"]?[A-Za-z0-9+/]{8,}" | head -10`

If any anomalies are found, include prominent warnings in the summary below.

## Step 3: Present Summary and Ask for Confirmation

Present the following to the user:

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

If any anomalies were found, add a clear warning block before asking for confirmation.

Then ask:

```
Proceed with git push? (yes / no)
```

Wait for the user's response before continuing.
- If **yes** or affirmative: proceed to Step 4.
- If **no** or negative: stop and inform the user the push was cancelled.

## Step 4: Check if Remote Has Diverged

Before pushing, check whether the remote has commits the local branch does not have:
!`git fetch`
!`git log --oneline HEAD..@{u} 2>/dev/null`

If `git log HEAD..@{u}` shows commits (i.e., the remote is ahead), a rebase is required before pushing. Proceed to Step 5. Otherwise skip to Step 6.

## Step 5: Rebase onto Remote (if required)

The remote has new commits — rebase local commits on top of them:

1. Run `git rebase @{u}`.
2. If the rebase completes cleanly, confirm to the user:
   ```
   Rebase complete. Local commits replayed on top of [remote]/[branch].
   ```
   Then proceed to Step 6.
3. If the rebase hits **conflicts**:
   - Show the conflicting files: `git diff --name-only --diff-filter=U`
   - Present each conflict clearly to the user.
   - Resolve the conflicts in the affected files.
   - After resolving, stage only the conflict resolutions: `git add <resolved-files>`
   - Continue the rebase: `git rebase --continue`
   - Repeat until the rebase is complete.
   - If at any point the user wants to abort, run `git rebase --abort` and stop.
4. **DO NOT** use `git rebase -i` (interactive mode requires a TTY). Use plain `git rebase @{u}`.
5. **DO NOT** amend or squash commits during the rebase unless the user explicitly asks.

## Step 6: Push

1. Run `git push` — use the default remote and branch as configured.
2. If the push is still **rejected** after a successful rebase:
   - Show the full error output.
   - Explain the cause.
   - Ask the user what they want to do.
   - **NEVER force push** unless the user explicitly asks and the branch is not `main` or `master`. If they ask to force push to `main`/`master`, warn them clearly and ask for a second, explicit confirmation before proceeding.
3. If the push **succeeds**, confirm with:
   ```
   Pushed: [branch] -> [remote]/[branch]  ([N] commit(s))
   ```
4. If the push **fails** for any other reason (auth, network, hooks):
   - Show the full error output.
   - Suggest remediation steps.
   - Do not retry automatically.

## Important Notes

- **DO NOT** run `git add`, `git commit`, `git stash`, or any command that modifies staged or unstaged changes — except `git add <file>` strictly to stage conflict resolutions during an active rebase.
- **DO NOT** use `git rebase -i` — it requires interactive TTY input.
- **DO NOT** force push without explicit user instruction.
- **DO NOT** push to `main`/`master` with `--force` without a second explicit confirmation.
- **DO** run `git fetch` before deciding whether a rebase is needed — never assume the remote state.
- **DO** show the full error output when any step fails so the user can diagnose it.
- **DO** handle authentication errors gracefully (suggest checking SSH keys or personal access tokens).
