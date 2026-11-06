# Vibe Coding Hackathon — Security rules for participants (1 page)

**The agent runs with YOUR rights on YOUR workstation.** Treat it like a brilliant
intern who believes everything it reads.

## Start right
1. Start from the hackathon template repo. `git init` + first commit before anything.
2. Always launch with **`oc-safe`** (never plain `opencode`), from **inside the project folder**.
3. Run `05-verify/check-setup.sh` once: everything must say PASS.

## Data
- **Synthetic data only.** No client data, no production extracts, no real IBAN/card numbers,
  no colleague/client names — not in prompts, not in fixtures, not in screenshots.
- **No secrets in prompts, code or commits.** Use `.env` (git-ignored) + `.env.example`.

## While coding
- Commit a checkpoint often (`/checkpoint <msg>`). It's your undo button.
- Read every **"ask"** prompt. Choose **once**, not *always*, unless it's a test/build command.
- **New dependency?** The agent must ask you. Check the name exists in our internal
  Artifactory and is the well-known one. AI models invent package names; attackers register them.
- Don't paste content from the internet into the agent "to give it context". Don't clone random
  public repos into your workspace.
- If the agent says it found instructions in a file / comment / output: stop and tell a coach.

## Never
- `--auto` / auto-approve mode on your workstation.
- Ask the agent to disable a rule, edit `AGENTS.md` / `opencode.json`, push, deploy or call external URLs.
- Run opencode from your home directory.

## Before the demo
- Run **`/secure-review`** and fix every Critical/High.
- `git diff` yourself: you are accountable for every line, the agent is not.

Questions / something weird happened → ping the coaches channel. Reporting is always the right call.
