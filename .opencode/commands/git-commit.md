---
description: Commit staged changes with a conventional commit message
agent: build
---

Commit the currently staged changes using the Conventional Commits 1.0.0 specification.

## Step 1: Check for Staged Changes

Run the following and inspect the output:
!`git status --short`
!`git diff --staged --stat`

If there are **no staged changes** (nothing listed under `git diff --staged --stat`), stop immediately and respond:

```
Nothing is staged. Stage files first with `git add <files>` or `git add .`, then run /git-commit again.
```

Do not proceed any further.

## Step 2: Scan for Anomalies

Before proposing a commit message, check for potential issues in the staged files:

**Large files (>1 MB):**
!`git diff --staged --name-only | xargs -I{} find {} -maxdepth 0 -size +1M 2>/dev/null`

**Potential secrets / credentials:**
!`git diff --staged --name-only | grep -Ei "\.env$|\.env\.|credentials|secrets|\.pem$|\.key$|\.p12$|\.pfx$|id_rsa|id_dsa|id_ecdsa|\.password|api_key|token" | head -20`

**Secret-like patterns inside staged content:**
!`git diff --staged | grep -Ei "(password|secret|api_key|access_token|private_key|client_secret)\s*[:=]\s*['\"]?[A-Za-z0-9+/]{8,}" | head -10`

Collect the results and present them in the summary below. If any issues are found, warn the user clearly before asking for confirmation.

## Step 3: Review Staged Diff

Read the full staged diff to understand what changed:
!`git diff --staged`

Also review recent commit history to match the project's commit style:
!`git log --oneline -5`

## Step 4: Present Summary and Proposed Commit Message

Present the following to the user before committing:

```
## Staged Changes Summary
[1–2 sentence description of what is being committed]

## Files Staged
[List each staged file with a one-line description of the change]

## Anomaly Check
- Large files (>1 MB): [list or "None"]
- Potential secrets / credentials in filenames: [list or "None"]
- Secret-like patterns in content: [list or "None"]

## Proposed Commit Message
[Full conventional commit message — see rules below]
```

Then ask:

```
Proceed with this commit? (yes / no / edit message)
```

Wait for the user's response before continuing.
- If **yes** or affirmative: proceed to Step 5.
- If **no** or negative: stop and inform the user the commit was cancelled.
- If the user provides an edited message or asks to change the message: use the provided message and re-confirm.

## Step 5: Commit

Once the user confirms:

1. Run `git commit` using the approved conventional commit message.
   - **CRITICAL**: Check if the user has commit signing configured before committing:
     !`git config --get commit.gpgsign`
     !`git config --get gpg.format`
     !`git config --get user.signingkey`
   - If `commit.gpgsign` is `true` or a signing key is configured, **never** pass `--no-gpg-sign` or any flag that bypasses signing. Let git use the user's signing configuration as-is.
2. If git is waiting for a passphrase or GPG/SSH key entry and the user does not respond within a reasonable time, or if the process appears to be hanging:
   - Terminate the commit process immediately.
   - Warn the user with:
     ```
     ⚠ Commit timed out waiting for passphrase/key entry. The commit was not created.
     If signing is required, unlock your key agent (e.g. `gpg-agent`, `ssh-agent`) before retrying.
     ```
   - Do **not** retry automatically — wait for the user's explicit instruction.
3. If the commit hook rejects the commit:
   - Show the full hook output to the user.
   - Ask whether they want to fix the issue and retry, or abort.
   - Do **not** retry automatically — wait for the user's decision.
4. After a successful commit, confirm with:
   ```
   Committed: <commit hash> — <commit subject line>
   ```

## Commit Message Rules

@.opencode/skills/conventional-git-commit/SKILL.md

Key rules (summary):
- Format: `<type>[optional scope]: <description>`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
- Description: imperative mood, under 72 chars, no trailing period, no capital first letter
- Body: optional, separated by one blank line, explains *why* not *what*
- Breaking change: append `!` after type/scope **and/or** add `BREAKING CHANGE: <desc>` footer
- Never produce a vague description like `fix: bug` — be specific

## Important Notes

- **DO NOT** pass `--no-verify`, `--no-gpg-sign`, or any flag that skips hooks or signing unless the user explicitly requests it and understands the consequences.
- **DO NOT** stage additional files — only commit what is already staged.
- **DO NOT** push — this command is commit-only.
- **DO** warn clearly if secrets or large files are detected.
- **DO** respect the user's existing git configuration for signing.
