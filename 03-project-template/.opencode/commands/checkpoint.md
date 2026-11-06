---
description: Run tests, then commit a local checkpoint (never pushes)
---
1. Run the project's test command as documented in AGENTS.md and show the result.
2. If tests pass, run `git add -A` and `git commit -m "checkpoint: $ARGUMENTS"`.
3. If tests fail, do not commit; summarise the failures instead.
Never push.
