#!/usr/bin/env bash
# =============================================================================
#  oc-safe - hardened launcher for OpenCode (Linux / macOS / WSL / Git-Bash)
#  Usage:  oc-safe [any opencode args]
#  Install: copy to ~/.local/bin/oc-safe, chmod +x, and alias opencode=oc-safe
# =============================================================================
set -euo pipefail

KIT_DIR="${OC_KIT_DIR:-$HOME/.config/hackathon-opencode}"
SECURE_CFG="$KIT_DIR/opencode.json"          # comment-free copy from 01-managed-config
LLM_KEY_VAR="${OC_LLM_KEY_VAR:-LLMAAS_API_KEY}"  # the ONE secret opencode needs

die() { echo "[oc-safe] ERROR: $*" >&2; exit 1; }
warn() { echo "[oc-safe] WARN:  $*" >&2; }

# 1. Never run from $HOME, / or a non-project folder (blast radius = cwd)
CWD="$(pwd -P)"
[[ "$CWD" == "$HOME" || "$CWD" == "/" ]] && die "do not start opencode from \$HOME or / - cd into your project."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repository. 'git init && git commit' first so every agent change is reviewable/revertable."

# 2. Warn on dirty tree (you want a clean checkpoint before letting an agent loose)
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  warn "uncommitted changes present - consider 'git add -A && git commit -m checkpoint' first."
fi

# 3. Refuse auto-approve mode outside the sandbox container
for a in "$@"; do
  if [[ "$a" == "--auto" && "${OC_SANDBOX:-0}" != "1" ]]; then
    die "--auto is only allowed inside the devcontainer sandbox (OC_SANDBOX=1)."
  fi
done

# 4. Flag repos that ship their own agent config (possible injection/persistence)
for f in opencode.json opencode.jsonc .opencode/plugins .opencode/plugin .opencode/tools; do
  [[ -e "$f" ]] && warn "repo contains '$f' - review it before trusting this repo (plugins/tools = code that runs on your machine)."
done

# 5. Strip secrets from the environment opencode (and every child process) inherits
while IFS='=' read -r name _; do
  [[ "$name" == "$LLM_KEY_VAR" ]] && continue
  if [[ "$name" =~ (TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL|API_KEY|APIKEY|PRIVATE_KEY|ACCESS_KEY|_PAT$|^AWS_|^AZURE_|^ARM_|^GOOGLE_|^GH_|^GITHUB_|^GITLAB_|^NPM_|^ARTIFACTORY_|^VAULT_|^KUBECONFIG$|^SSH_AUTH_SOCK$) ]]; then
    unset "$name"
  fi
done < <(env)

# 6. Disable non-essential outbound features (belt and braces with the config)
export OPENCODE_DISABLE_SHARE=1
export OPENCODE_DISABLE_AUTOUPDATE=1
export OPENCODE_DISABLE_MODELS_FETCH=1   # no calls to models.dev
export OPENCODE_DISABLE_LSP_DOWNLOAD=1   # no auto-download of language servers

# 7. Inject the hardened config at "inline" precedence (above global AND project
#    config). Not as strong as the managed/system path, but no admin needed.
MANAGED_FOUND=0
for d in /etc/opencode "/Library/Application Support/opencode"; do
  [[ -f "$d/opencode.json" || -f "$d/opencode.jsonc" ]] && MANAGED_FOUND=1
done
if [[ "$MANAGED_FOUND" == "1" ]]; then
  : # managed config present (Linux or macOS path) - it already has the highest precedence
elif [[ -f "$SECURE_CFG" ]]; then
  export OPENCODE_CONFIG_CONTENT="$(cat "$SECURE_CFG")"
else
  die "hardened config not found at $SECURE_CFG"
fi

echo "[oc-safe] workspace: $CWD | secrets stripped | share/web disabled"
exec opencode "$@"
