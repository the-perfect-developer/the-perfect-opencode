---
name: interactive-questions
description: This skill should be used when the user asks to "ask questions interactively", "use the question tool", "present choices to the user", "avoid yes/no prompts", "use interactive confirmations", or needs guidance on asking structured questions with selectable options instead of free-text prompts.
---

# Interactive Questions with the Question Tool

Use the `question` tool to ask users structured, interactive questions with selectable options instead of plain yes/no or free-text prompts. This produces a numbered option list the user navigates with arrow keys and confirms with Enter.

## Core Rule

**Never ask a yes/no question in plain text when the answer can be expressed as a set of options.** Always use the `question` tool with explicit choices.

Wrong:
> "Do you want to proceed? (yes/no)"

Right: use the `question` tool with options such as "Proceed" and "Cancel".

## When to Use the Question Tool

Use it whenever you need the user to make a decision:

- **Confirmation** — before destructive or irreversible actions (delete, overwrite, push, deploy)
- **Strategy selection** — when multiple valid approaches exist and user preference matters
- **Clarification** — when a request is ambiguous and each interpretation leads to meaningfully different work
- **Multi-step workflows** — to let the user steer direction between phases

Do not use it for simple informational acknowledgement where no decision is required.

## How to Call the Question Tool

The tool accepts an array of `questions`. Each question has:

| Field | Required | Notes |
|---|---|---|
| `question` | yes | The full question text shown to the user |
| `header` | yes | A very short label (max 30 chars) shown as the prompt title |
| `options` | yes | Array of `{ label, description }` objects |
| `multiple` | no | Set `true` to allow selecting more than one option |

The tool automatically appends a "Type your own answer" option — do **not** add an "Other" catch-all yourself.

## Option Design Rules

- **Label**: 1–5 words, concise action or noun phrase (e.g., "Proceed", "Cancel", "Edit message")
- **Description**: one sentence explaining what that choice does (e.g., "Commit with the proposed message", "Abort the operation")
- **Order**: put the recommended or most common option first; add `(Recommended)` at the end of its label when helpful
- **Coverage**: include all meaningful paths — at minimum a "do it" option and a "cancel" option
- **No duplicates**: each option must represent a distinct outcome

## Confirmation Pattern

For any action that cannot easily be undone, use a three-option confirmation:

```
Proceed with <action>?
  1. Proceed (Recommended) — <short description of what happens>
  2. Cancel                 — Abort the operation
  3. Edit / Adjust          — <relevant alternative, e.g., "Provide a revised message">
```

## Strategy Selection Pattern

When multiple valid approaches exist:

```
How should I handle <situation>?
  1. <Approach A> (Recommended) — <one sentence tradeoff>
  2. <Approach B>               — <one sentence tradeoff>
  3. <Approach C>               — <one sentence tradeoff>
```

Always explain the tradeoff in the description so the user can decide without needing additional context.

## Clarification Pattern

When a request is ambiguous, clarify before starting work rather than assuming:

```
What should <term / feature> include?
  1. <Interpretation A> — <what this means concretely>
  2. <Interpretation B> — <what this means concretely>
```

Limit clarification questions to genuine ambiguities. Do not ask about details you can decide using reasonable defaults.

## Multiple Selection

Set `multiple: true` only when the user genuinely needs to pick more than one item — for example, selecting which files to include, which environments to target, or which checks to run. Keep the option list short (2–7 items) to avoid overwhelming the user.

## Avoid These Anti-Patterns

| Anti-pattern | Problem | Fix |
|---|---|---|
| Asking yes/no in text | Requires typing; no structured response | Use `question` tool with Proceed / Cancel options |
| Too many options (8+) | Overwhelming; hard to scan | Group related options or split into sequential questions |
| Vague labels ("Option 1") | User cannot decide without reading description | Use action-oriented labels ("Deploy to staging") |
| Catch-all "Other" option | Redundant — tool adds "Type your own answer" automatically | Remove it |
| Asking every minor detail | Slows workflow; irritates user | Reserve questions for decisions that genuinely affect the outcome |
| Multiple questions at once | Harder to process | Ask one question per tool call unless questions are tightly coupled |

## Quick Reference

```
question tool fields:
  questions[].question     — full question text
  questions[].header       — short label (≤30 chars)
  questions[].options[]
    .label                 — 1–5 words
    .description           — one sentence
  questions[].multiple     — true | false (default false)

Do NOT add "Other" — tool appends "Type your own answer" automatically.
Put recommended option first, label it "(Recommended)".
```
