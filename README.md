# OpenCode Secure Kit — Vibe Coding Hackathon

Turnkey security baseline for running **OpenCode + on-prem LLMaaS** on developer
workstations, with zero enterprise tooling. Designed to be deployed in < 1 week.

```
01-managed-config/   hardened opencode config (+ optional OpenCode 2 policy snippet)
02-launcher/         oc-safe.sh / oc-safe.ps1 : the only way participants start opencode
03-project-template/ AGENTS.md rules, read-only security-reviewer agent, /secure-review,
                     /checkpoint commands, .gitignore, .env.example, gitleaks hook
04-sandbox-devcontainer/  OPTIONAL stronger tier: container + default-deny egress firewall
05-verify/           check-setup.sh : PASS/FAIL on the merged config + 4 smoke tests
PARTICIPANT-CHEATSHEET.md  one page to hand out at kick-off
```

---

## 1. Threat model in 5 lines (what we actually defend against)

1. **Indirect prompt injection** — instructions hidden in a README, code comment,
   dependency, test output or tool result hijack the agent. This is the #1 threat
   for coding agents (NVIDIA AI Red Team).
2. **Exfiltration** of code / secrets via network commands, web fetch, session sharing,
   or third-party side services (web search providers, hosted "small model").
3. **Damage outside the project** — writes to dotfiles, `~/.ssh`, shell rc files,
   git config = persistence & lateral movement.
4. **Supply chain** — the agent installs hallucinated or malicious packages
   ("slopsquatting"), or a repo ships plugins/agent config that executes code.
5. **Data leakage into the hackathon itself** — real client data or secrets pasted into
   prompts / committed into demo repos.

**Key honesty point for your RSSI/CISO:** OpenCode's own `SECURITY.md` states it does
**not** sandbox the agent and that the permission system is a UX feature, not a
security boundary; for true isolation, run it in a container or VM. Bash allow/deny
patterns can be bypassed (e.g. interpreter indirection; a `--` parsing bypass was
reported on 2.0.x in Oct 2026). So the kit is **layered**, and tier 3 (container) is
what gives real isolation.

---

## 2. The layers

| # | Layer | What it gives | Effort |
|---|-------|---------------|--------|
| 0 | **Version pinning** | Everyone on the same, tested OpenCode build | 10 min |
| 1 | **Hardened config** (managed path) | Only internal LLM, no share, no web, approval for out-of-workspace access, secrets unreadable, config files immutable for the agent, deny-list of dangerous commands | 1 h |
| 2 | **oc-safe launcher** | Refuses to run from `$HOME`/non-git dirs, strips secrets from env, kills outbound side features, blocks `--auto`, flags repos shipping plugins | 30 min |
| 3 | **Project template** | AGENTS.md security rules, read-only reviewer agent, checkpoint workflow, secret scanning | 30 min |
| 4 | **Devcontainer sandbox** *(optional)* | OS-level isolation: only `/workspace` mounted, default-deny egress except LLM gateway + Artifactory | ½ day if Docker/Podman is allowed on workstations |
| 5 | **Process** | Synthetic data only, review diffs, `/secure-review` before demo, wipe after event | briefing |

Mapping to NVIDIA AI Red Team "mandatory" controls:

| NVIDIA mandatory control | Tier 1-3 (config + launcher) | Tier 4 (container) |
|---|---|---|
| Network egress only to known-good | Partial (deny-list + webfetch off; app-level) | **Yes** (iptables default-deny) |
| No writes outside workspace | Partial (`external_directory: ask`; bash can still bypass) | **Yes** (only workspace mounted) |
| No writes to agent config files | Partial (`edit` deny on AGENTS.md, opencode.json, .opencode/…) | **Yes** + config is root-owned |

---

## 3. Deployment checklist (for next week)

**D-5 — Decide & pin**
- [ ] Pick ONE OpenCode version and pin it (internal npm mirror / package repo). V1 and V2
      differ in defaults and plugin API (see §5). Test the kit on that exact version.
- [ ] Fill placeholders in `01-managed-config/opencode.jsonc`: `<LLMAAS_PROVIDER_ID>`,
      `<MAIN_MODEL_ID>`, `<SMALL_MODEL_ID>`. Merge in your existing `provider` block.
- [ ] Regenerate the comment-free `opencode.json` (strip `//` lines) or edit both.

**D-4 — Distribute config (pick the strongest you can get)**
- [ ] **Best:** ask workstation admins to drop the file at the managed path
      (`%ProgramData%\opencode\opencode.jsonc` on Windows, `/etc/opencode/` on Linux,
      `/Library/Application Support/opencode/` on macOS). Admin-only write, highest
      precedence, cannot be overridden by users or repos.
- [ ] **Fallback (no admin):** copy `opencode.json` to `~/.config/hackathon-opencode/`
      and make `oc-safe` the entry point. It injects the config at inline precedence
      (above global and project config).
- [ ] Never rely only on `~/.config/opencode/opencode.json`: a project `opencode.json`
      in any cloned repo overrides it.

**D-3 — Launcher & template**
- [ ] Ship `oc-safe.sh` / `oc-safe.ps1`; tell participants to alias `opencode` to it.
- [ ] Set `OC_LLM_KEY_VAR` if your LLMaaS key variable is not `LLMAAS_API_KEY`.
- [ ] Publish `03-project-template` as an internal Git template repo; teams start from it.

**D-2 — Dry run**
- [ ] On 2-3 real workstations (Windows + Linux/WSL): `05-verify/check-setup.sh` → all PASS.
- [ ] Do the 4 manual smoke tests printed by the script.
- [ ] Check proxy/CA: set `HTTPS_PROXY`, `NO_PROXY=localhost,127.0.0.1,::1`,
      `NODE_EXTRA_CA_CERTS` if your LLM gateway uses the internal PKI.

**D-day**
- [ ] 10-min security briefing with `PARTICIPANT-CHEATSHEET.md`.
- [ ] Every team runs `check-setup.sh` before coding.

**D+1**
- [ ] Wipe/archive hackathon repos and OpenCode local session data
      (`~/.local/share/opencode/`), rotate any LLMaaS keys issued for the event.

---

## 4. Design choices you may get challenged on

- **Edits inside the workspace are auto-allowed.** Asking for every edit kills vibe
  coding and causes approval fatigue (users click "always"). NVIDIA's tiering explicitly
  recommends free read-write in the workspace *except* configuration files. Git + OpenCode
  snapshots provide undo.
- **Dependency manifests and installs always ask.** Hallucinated package names are a
  documented, actively exploited supply-chain vector; the human must see every new dependency.
  Ideally the package managers point only at your internal Artifactory (no public fallback).
- **`webfetch` and `websearch` denied.** They are the main injection entry point and an
  exfiltration channel; web search also sends queries to external providers.
- **`small_model` pinned.** If unset, OpenCode can route side tasks (session titles) to a
  hosted default model — i.e. part of the conversation leaves the perimeter.
- **No MCP servers, no plugins.** OpenCode treats external MCP servers as outside its trust
  boundary; plugins are arbitrary code. Add only internally reviewed ones after the event.
- **"Always" approvals are session-scoped in OpenCode**, but still: tell participants to use
  "once" for anything that is not a test/build command.

---

## 5. OpenCode 1 vs 2 — gotchas

- V2 reads the V1 config format (this kit uses V1 syntax, so it works on both).
- **V2 allows `external_directory` by default** (V1 asked). The kit sets it to `ask`
  explicitly — do not remove that line.
- V2 adds `experimental.policies` (provider allow/deny that system config enforces over
  global/project). Merge `opencode-v2-policies.snippet.jsonc` into the managed config if on V2.
- V1 plugins do not run on V2. Irrelevant here (no plugins), but relevant if a team tries one.
- `--auto` mode auto-approves every "ask" (only explicit denies still hold). The launcher
  blocks it outside the container.

---

## 6. Known limitations (say them out loud)

- Command patterns are a deny-**list**: a determined injection can find an indirection we did
  not list (a script file the agent writes then runs via an allowed test runner, etc.).
  Only tier 4 contains that.
- `read` deny rules cover OpenCode's read tool; an allowed shell command could still read a
  file inside the workspace. Keep secrets **out of the workspace** (the launcher also strips
  them from env).
- Env-var flags (`OPENCODE_DISABLE_*`) evolve between versions: confirm them on your pinned
  build (`opencode --help`, release notes) during the dry run.
- On some Windows/WSL2 kernels iptables/ipset are missing → the container firewall can't
  start. The script self-tests and fails loudly; don't ignore it.

---

## 7. Sources

- OpenCode docs: Permissions, Config (precedence, managed settings), Policies, Enterprise,
  V2 migration guide, V2 Network, V2 Web search — opencode.ai/docs, opencode.ai/v2/docs
- OpenCode `SECURITY.md` threat model — github.com/anomalyco/opencode/security
- OpenCode issues: #21733 (bash bypasses edit permissions), #57359 (`--` bypass, 2.0.32),
  #8609 (small_model default + share), #18233/#5554 (non-essential outbound connections)
- NVIDIA AI Red Team — *Practical Security Guidance for Sandboxing Agentic Workflows* (Jan 2026)
  and *Mitigating Indirect AGENTS.md Injection Attacks* (Apr 2026)
- Cloud Security Alliance research note on slopsquatting (Apr/May 2026); USENIX Security 2025
  package-hallucination study
