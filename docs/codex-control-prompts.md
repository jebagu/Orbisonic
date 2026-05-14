# Codex Control Prompts

## First Prompt: Plan Audit

```text
Read AGENTS.md and all files in docs/.

Do not write code.

Audit the project plan for:

- Missing requirements
- UI-freeze risks
- Unclear module boundaries
- Missing module contracts
- Contradictory audio-path instructions
- Untestable tasks
- Bad task ordering
- Missing test strategy
- Missing stopping conditions
- Places where implementation would likely drift from the docs

Return:

1. Issues found
2. Recommended doc changes
3. Recommended task changes
4. Questions that block implementation
5. Questions that can be treated as assumptions
6. Orbisonic status: completed plan audit; ready for Task 001.
```

## Single Task Prompt

```text
Read AGENTS.md first.

Then read:

- docs/product-brief.md
- docs/ui-freeze.md
- docs/architecture.md
- docs/audio-path-invariants.md
- docs/contracts.md
- docs/system-flows.md
- docs/test-strategy.md
- docs/status.md
- .tasks/[TASK-FILE].md

Implement exactly this task and nothing outside its scope.

After implementation:

- Add or update relevant tests
- Run relevant verification commands
- Fix failures caused by this task
- Update docs/status.md
- Update docs/implementation-map.md if files changed
- Update docs/system-flows.md if flows changed
- Update docs/contracts.md only if the task explicitly allows contract changes

Stop if:

- UI freeze would be violated
- Audio invariants would be violated
- The task requires a product decision
- The task requires changing a public contract
- The task requires a major dependency
- The task conflicts with existing docs
- The task cannot be verified

Final response must include:

1. What changed
2. Files changed
3. Tests added or updated
4. Commands run and results
5. Documentation updated
6. Assumptions
7. Risks or blockers
8. Recommended next task
9. Orbisonic status line
```

## Resume Prompt

```text
Read AGENTS.md and docs/status.md.

Then inspect the .tasks directory.

Identify the next pending task whose dependencies appear complete.

Do not implement anything yet.

Return:

1. Current project state
2. Completed tasks
3. Pending tasks
4. Blocked tasks
5. Recommended next task
6. Any inconsistencies between docs and task files
7. Orbisonic status line
```
