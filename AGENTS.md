# Project Working Rules

These instructions apply to the entire repository unless a deeper `AGENTS.md` overrides them.

## Operating Mode

- Default to read-only analysis unless the user explicitly approves implementation.
- Start by inspecting the repository and summarizing the current state relevant to the request.
- Propose a plan before making changes when the task is non-trivial, architectural, or infrastructure-related.
- Wait for explicit approval before editing files, creating files, deleting files, or restructuring code.

## Approval Gates

Do not do any of the following without explicit user approval in the current thread:

- Modify any file.
- Run commands that change infrastructure state.
- Run commands that write to Git state.
- Run commands that require network access.
- Install dependencies, providers, plugins, or external tools.
- Run destructive commands or cleanup commands.

Examples that require approval include:

- `terraform init`
- `terraform plan`
- `terraform apply`
- `terraform destroy`
- `az`
- `kubectl apply`
- `helm install`
- `git checkout`
- `git commit`
- `git rebase`
- `rm`

## Plan-First Workflow

For implementation requests, follow this sequence:

1. Inspect the repo and explain the current state.
2. State assumptions, unknowns, and risks.
3. Propose a step-by-step plan.
4. List the files that would be changed.
5. Wait for approval.
6. After approval, make only the agreed changes.

## Change Scope

- Keep changes tightly scoped to the approved task.
- Do not make opportunistic refactors.
- Do not "improve" adjacent code unless the user approves it.
- If a better architecture is apparent, propose it first instead of implementing it directly.

## Ambiguity Handling

- If requirements are ambiguous, stop and ask.
- If there are multiple valid implementation paths, present options with tradeoffs before editing.
- If the repo state conflicts with the request, surface the conflict and wait for direction.

## Infrastructure-Specific Rules

- For Terraform and cloud work, prefer analysis, design, and staged planning before changes.
- Distinguish clearly between desired end state, current repo state, and migration steps.
- Do not assume provider, region, topology, naming, security rules, or cluster architecture without confirmation.
- Before any infrastructure edit, identify target resources, expected state transitions, and validation steps.

## Validation

- Do not run broad validation commands by default.
- Propose validation steps before running them when they may write state, download dependencies, or take significant time.
- If validation can be done safely in read-only mode, say so and ask before proceeding if it is non-trivial.

## Communication

- Be concise and direct.
- Tell the user what you are about to inspect before doing it.
- Before editing, summarize the intended changes and target files.
- If you made a wrong assumption, stop, acknowledge it plainly, and return to the approved workflow.
