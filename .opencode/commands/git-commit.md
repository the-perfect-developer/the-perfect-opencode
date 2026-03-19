---
description: Commit staged changes with a conventional commit message
agent: developer-fast
---

Commit staged changes using Conventional Commits 1.0.0.

## Step 1: Check for Staged Changes

!`git status --short`
!`git diff --staged --stat`

If no staged changes, respond:
```
Nothing is staged. Stage files first with `git add <files>` or `git add .`, then run /git-commit again.
```
Stop.

## Step 2: Scan for Anomalies

**Large files (>1 MB):**
!`git diff --staged --name-only | xargs -I{} find {} -maxdepth 0 -size +1M 2>/dev/null`

**Potential secrets / credentials:**
!`git diff --staged --name-only | grep -Ei "\.env$|\.env\.|credentials|secrets|\.pem$|\.key$|\.p12$|\.pfx$|id_rsa|id_dsa|id_ecdsa|\.password|api_key|token" | head -20`

**Secret-like patterns in content:**
!`git diff --staged | grep -Ei "(password|secret|api_key|access_token|private_key|client_secret)\s*[:=]\s*['\"]?[A-Za-z0-9+/]{8,}" | head -10`

Warn the user if any issues are found.

## Step 3: Review Staged Diff

!`git diff --staged`
!`git log --oneline -5`

## Step 4: Present Summary and Proposed Commit Message

Present:
```
## Staged Changes Summary
[1–2 sentence description]

## Files Staged

| File | Status | Description |
|------|--------|-------------|
| [file path] | Added / Modified / Deleted | [one-line description] |

## Anomaly Check
- Large files (>1 MB): [list or "None"]
- Potential secrets / credentials in filenames: [list or "None"]
- Secret-like patterns in content: [list or "None"]

## Proposed Commit Message
[Full conventional commit message]
```

Use the question tool for confirmation:
- **Proceed** — commit with message
- **Cancel** — abort
- **Edit message** — user provides revised message, then re-confirm

Wait for response. Cancel: inform user. Edit: collect revised message, re-confirm.

## Step 5: Commit

1. Check signing config:
   !`git config --get commit.gpgsign`
   !`git config --get gpg.format`
   !`git config --get user.signingkey`
   Never bypass signing — use the user's config as-is.

2. Run `git commit` with the approved message.

3. If hanging on passphrase/key entry: terminate, warn the user, do not retry:
   ```
   ⚠ Commit timed out waiting for passphrase/key entry. The commit was not created.
   Unlock your key agent (e.g. `gpg-agent`, `ssh-agent`) before retrying.
   ```

4. If a commit hook rejects: show full hook output, ask to fix/retry or abort, do not retry automatically.

5. On success:
   ```
   Committed: <commit hash> — <commit subject line>
   ```

## Commit Message Rules

Always use `conventional-git-commit` skill.

## Constraints

- Do not pass `--no-verify`, `--no-gpg-sign`, or any skip flags unless the user explicitly requests it.
- Do not stage additional files — only commit what is already staged.
- Do not push — commit-only.