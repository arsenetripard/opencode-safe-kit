# =============================================================================
#  oc-safe.ps1 - hardened launcher for OpenCode (Windows PowerShell 5+/7+)
#  Usage:   .\oc-safe.ps1 [opencode args]
#  Install: copy to a folder on PATH; optionally: Set-Alias opencode oc-safe.ps1
# =============================================================================
$ErrorActionPreference = 'Stop'

$KitDir    = if ($env:OC_KIT_DIR) { $env:OC_KIT_DIR } else { Join-Path $env:USERPROFILE '.config\hackathon-opencode' }
$SecureCfg = Join-Path $KitDir 'opencode.json'
$LlmKeyVar = if ($env:OC_LLM_KEY_VAR) { $env:OC_LLM_KEY_VAR } else { 'LLMAAS_API_KEY' }

function Die($m)  { Write-Host "[oc-safe] ERROR: $m" -ForegroundColor Red; exit 1 }
function Warn($m) { Write-Host "[oc-safe] WARN:  $m" -ForegroundColor Yellow }

# 1. Never from the user profile or a drive root
$cwd = (Get-Location).ProviderPath
if ($cwd -eq $env:USERPROFILE -or $cwd -match '^[A-Za-z]:\\?$') { Die 'do not start opencode from your profile or a drive root - cd into your project.' }
git rev-parse --is-inside-work-tree 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Die "not a git repository. 'git init' + first commit, so every agent change is reviewable." }

# 2. Dirty tree warning
if (git status --porcelain) { Warn 'uncommitted changes present - commit a checkpoint first.' }

# 3. No auto-approve outside the sandbox
if ($args -contains '--auto' -and $env:OC_SANDBOX -ne '1') { Die '--auto is only allowed inside the devcontainer sandbox.' }

# 4. Repo-shipped agent config
foreach ($f in 'opencode.json','opencode.jsonc','.opencode\plugins','.opencode\plugin','.opencode\tools') {
  if (Test-Path $f) { Warn "repo contains '$f' - review it before trusting this repo." }
}

# 5. Strip secrets from the inherited environment (process scope only)
$pattern = '(TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL|API_KEY|APIKEY|PRIVATE_KEY|ACCESS_KEY|_PAT$|^AWS_|^AZURE_|^ARM_|^GOOGLE_|^GH_|^GITHUB_|^GITLAB_|^NPM_|^ARTIFACTORY_|^VAULT_|^KUBECONFIG$)'
Get-ChildItem Env: | Where-Object { $_.Name -ne $LlmKeyVar -and $_.Name -match $pattern } |
  ForEach-Object { Remove-Item "Env:\$($_.Name)" }

# 6. Disable non-essential outbound features
$env:OPENCODE_DISABLE_SHARE        = '1'
$env:OPENCODE_DISABLE_AUTOUPDATE   = '1'
$env:OPENCODE_DISABLE_MODELS_FETCH = '1'
$env:OPENCODE_DISABLE_LSP_DOWNLOAD = '1'

# 7. Inject hardened config unless a managed config exists
$managed = Join-Path $env:ProgramData 'opencode'
if ((Test-Path (Join-Path $managed 'opencode.json')) -or (Test-Path (Join-Path $managed 'opencode.jsonc'))) {
  # managed config already wins
} elseif (Test-Path $SecureCfg) {
  $env:OPENCODE_CONFIG_CONTENT = Get-Content $SecureCfg -Raw
} else { Die "hardened config not found at $SecureCfg" }

Write-Host "[oc-safe] workspace: $cwd | secrets stripped | share/web disabled"
& opencode @args
exit $LASTEXITCODE
