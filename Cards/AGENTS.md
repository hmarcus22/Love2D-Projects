Collaboration & Execution Policy

Scope: Applies to the entire repository.

Core Rule
- Always analyze and discuss before implementing code. No code changes until the user explicitly approves the plan.

Workflow
- Understand: Read the task, inspect relevant files, and identify constraints/assumptions.
- Propose: Share a concise analysis including:
  - Goal and current behavior
  - Planned approach and alternatives considered
  - Risks/unknowns and assumptions
  - Files likely to be touched and intended changes
  - Validation plan (how we’ll verify the change)
- Confirm: Wait for explicit user approval (e.g., “Proceed”) before making any changes.
- Implement: Make minimal, focused edits aligned with the approved plan.
- Report: Summarize changes, list files touched, and note any follow‑ups. Offer to run tests/build if desired.

Defaults
- Keep changes minimal and scoped; avoid broad refactors unless requested.
- Ask before destructive, long‑running, or networked operations.
- Prefer `apply_patch` diffs; do not commit or create branches unless asked.
- Maintain separation of concerns as outlined in DEV_NOTES.

Exceptions
- None. Even small code edits require pre‑implementation analysis and confirmation.

Formatting & Communication
- Use brief bullets and clear file path references (e.g., `src/file.lua:42`).
- Provide short preambles before grouped tool calls and progress updates on multi‑step tasks.

Testing Limitations
- The agent cannot run Love2D locally. The user performs all runtime testing and visual verification.
- The agent will provide concise, reproducible manual test steps (commands, where to click, expected results) for the user to execute.
