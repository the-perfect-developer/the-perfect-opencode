---
description: Evaluate whether an implementation matches its plan
agent: plan
subtask: true
---

Evaluate whether the current implementation is acceptable by comparing it against the provided plan file.

**Plan file:** $1

Load and apply the `perfectcode-zen-evaluation` skill to guide the evaluation process.

> **Note:** The plan file argument (`$1`) is mandatory. If it was not provided, stop immediately and inform the user:
> "Usage: /evaluate <path-to-plan-file> — the plan file path is required."

Steps to follow:
1. Load the `perfectcode-zen-evaluation` skill for the evaluation framework and criteria
2. Read the plan file at `$1` to understand the intended design, goals, and acceptance criteria
3. Inspect the current implementation in the codebase that corresponds to the plan
4. Assess whether the implementation satisfies every requirement and acceptance criterion defined in the plan
5. Produce a structured evaluation report with:
   - **Verdict**: ACCEPTABLE or NOT ACCEPTABLE
   - **Criteria met**: list each plan requirement and whether it is fulfilled
   - **Gaps / issues**: specific deviations, missing pieces, or quality concerns
   - **Recommendations**: concrete next steps if the implementation is not acceptable
