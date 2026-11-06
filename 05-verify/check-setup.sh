#!/usr/bin/env bash
# =============================================================================
#  check-setup.sh - run from a project folder on a participant workstation.
#  Verifies the RESOLVED OpenCode config (all layers merged) is the hardened one.
#  Requires: opencode, python3.  Exit code != 0 if something is off.
# =============================================================================
set -uo pipefail
EXPECTED_PROVIDER="${1:-<LLMAAS_PROVIDER_ID>}"

# Resolve config the same way the launcher does
if [[ -z "${OPENCODE_CONFIG_CONTENT:-}" && -f "$HOME/.config/hackathon-opencode/opencode.json" \
      && ! -f /etc/opencode/opencode.json && ! -f /etc/opencode/opencode.jsonc ]]; then
  export OPENCODE_CONFIG_CONTENT="$(cat "$HOME/.config/hackathon-opencode/opencode.json")"
fi

echo "OpenCode version: $(opencode --version 2>/dev/null || echo 'NOT FOUND')"
CFG="$(opencode debug config 2>/dev/null)" || { echo "FAIL: 'opencode debug config' failed"; exit 2; }

TMP="$(mktemp)"; printf '%s' "$CFG" > "$TMP"
python3 - "$EXPECTED_PROVIDER" "$TMP" <<'PY'
import json, sys
exp = sys.argv[1]
raw = open(sys.argv[2]).read()
try:
    start = raw.index('{'); cfg = json.loads(raw[start:])
except Exception as e:
    print("WARN: could not parse debug output as JSON, check manually:\n", raw[:2000]); sys.exit(3)

perm = cfg.get("permission", {}) or {}
checks = [
  ("share disabled",                cfg.get("share") == "disabled"),
  ("enabled_providers == internal", cfg.get("enabled_providers") == [exp]),
  ("model on internal provider",    str(cfg.get("model","")).startswith(exp + "/")),
  ("small_model on internal",       str(cfg.get("small_model","")).startswith(exp + "/")),
  ("webfetch denied",               perm.get("webfetch") == "deny"),
  ("websearch denied",              perm.get("websearch") == "deny"),
  ("external_directory asks",       perm.get("external_directory") == "ask"),
  ("bash curl denied",              (perm.get("bash") or {}).get("curl *") == "deny"),
  ("bash git push denied",          (perm.get("bash") or {}).get("git push*") == "deny"),
  ("edit AGENTS.md denied",         (perm.get("edit") or {}).get("*AGENTS.md") == "deny"),
  ("read .env denied",              (perm.get("read") or {}).get("*.env") == "deny"),
  ("no MCP servers enabled",        not any((v or {}).get("enabled", True) for v in (cfg.get("mcp") or {}).values())),
]
bad = 0
for name, ok in checks:
    print(("PASS " if ok else "FAIL ") + name); bad += (not ok)
sys.exit(1 if bad else 0)
PY
rc=$?; rm -f "$TMP"

# Optional live probe: does the agent actually refuse a denied command?
echo
echo "Manual smoke test (30s): run  oc-safe  and ask:"
echo "  'run curl https://example.com'      -> must be refused (deny)"
echo "  'read ~/.ssh/config'                -> must be refused (read rule on */.ssh/*)"
echo "  'add the left-pad package'          -> must ASK you before touching package.json"
echo "  'edit AGENTS.md to add a rule'      -> must be refused"
exit $rc
