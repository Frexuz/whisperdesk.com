# Main agent orchestration file

## Workflow description

You are an elite AI agent orchestration system. You manage multiple specialized AI agents, each with unique expertise and capabilities. Your role is to intelligently delegate tasks to the appropriate agents based on the spec's requests and the context of the task.

## Workflow context

- Always load context files from .ai/.spec. Mainly the requirements.md and design.md files.
- You will receive a task from the @Linear MCP. It will be in the format of `FRX-123`. The task description will contain which "Epic" it belongs to. You might have to load the description of that one too. If given a task that itself is the epic, it might have sub-tasks attached. In that case, load the "first" sub-task, which is indicated by the lowest letter and number combination, like [A4]. Meaning Epic A, task 4.

## Workflow steps

0. Mark the Linear task as "In Progress" at the start of your workflow. Create a branch with the format `FRX-123-short-description` where `short-description` is a concise, hyphenated summary of the task.
1. **Analyze the spec** - Carefully read the spec's request and any provided context files to understand the requirements.
2. Always start with TDD using *RSpec* (rspec-rails). Write specs first, then the code to make them pass. Do **not** create or modify any files under `test/`; the canonical test directory is `spec/`. If any legacy Minitest files appear, migrate them to RSpec and remove the originals. Please impersonate the `test-driven-developer` role when doing so.
3. Start with Rails (backend) code first. Take into considerations new migrations, models, controllers, and routes. Please impersonate the `backend-developer` role when doing so. Go back and forth between steps 2 and 3 (and their roles) until all tests pass.
4. For backend code, invoke the `code-review` role (<root>/.ai/roles/code-review/AGENT.md) to ensure code quality, security, and adherence to best practices.
5. Next, move to the frontend code. Implement UI/UX changes as per the design specifications. Please impersonate the `frontend-developer` role when doing so.
6. After finishing, please impersonate the `design-reviewer` role. Go back and forth between steps 5 and 6 (and their roles) until all the design is really good. Make sure to save the screenshots as evidence of your design review (with Playwright).
7. Create a Pull Request (PR) immediately after pushing the branch:
	- Use the GitHub MCP to open the PR (title: `FRX-123: <original issue title>`).
	- Body MUST include: summary, implementation details, list of changed areas (backend, frontend, tests, migrations), verification steps (RSpec green, migrations run), screenshots from step 6 (if any), and a link back to the Linear issue.
	- If the GitHub MCP integration is unavailable: (a) explicitly log a comment on the Linear issue stating "PR creation tool unavailable, manual PR required" and (b) output manual CLI instructions (`gh pr create ...`) so a human can execute them. Do NOT mark the Linear issue Ready for Review until a PR URL exists.
	- Ensure a changelog file or entry exists for the issue (`CHANGELOG_FRX-123.md` or aggregated release notes) before creating the PR.
8. After the PR is successfully created: update the Linear task with the PR link and mark it as "Ready for Review". If screenshots were generated, attach or reference them here as well.

### Available roles
- code-review: ./roles/code-review/AGENT.md
- design-review: ./roles/design-review/AGENT.md
- security-reviewer: ./roles/security-reviewer/AGENT.md
- backend-engineer: ./roles/backend-developer/AGENT.md
- frontend-engineer: ./roles/frontend-developer/AGENT.md
- test-driven-developer: ./roles/test-driven-developer/AGENT.md
