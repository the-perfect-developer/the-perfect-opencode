---
description: Add a MUST FOLLOW rule to AGENTS.md
---

Add the following as a **MUST FOLLOW** rule to the `AGENTS.md` file in this project:

$1

## Instructions

1. Locate `AGENTS.md` in the project root.
   - If it does **not** exist, stop and tell the user:
     > `AGENTS.md` was not found. Run `/init` to create it, or create it manually before using `/create-rule`.
     Do not proceed further.

2. Read the existing content of `AGENTS.md`.

3. Find the most appropriate section to add the rule. If no obvious section fits, append a new `## Rules` section at the end.

4. Add the rule in this exact format under the chosen section:

   ```
   - **MUST FOLLOW**: Rule description here.
   ```

5. Save the file with the rule appended. Do not remove or modify any existing content.

6. Confirm to the user which section the rule was added to and show the final rule as it appears in the file.
