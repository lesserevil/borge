# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

## Automation & Tooling

All common development tasks MUST be defined as `make` targets in the root `Makefile`. Agents MUST use these targets instead of running raw commands (e.g., `flutter build`, `rm -rf build`, etc.).

**REQUIRED TARGET CATEGORIES:**
1. **Cleaning**: `make clean` (must clean all temporary build artifacts)
2. **Building**: `make build` (must build all core components)
3. **Testing**: `make test` (must run all unit and integration tests)
4. **Packaging**: `make package` (must produce final distributable artifacts)

If a target is missing for a task you need to perform, you MUST add it to the `Makefile` first, then use it.

