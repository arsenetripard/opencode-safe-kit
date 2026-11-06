# Installing OpenCode for the hackathon

This guide installs **OpenCode 2** (the current release) on macOS and Windows, connects it to our internal LLM platform, then adds the hackathon safety kit.

> Replace every `<PLACEHOLDER>` before sharing this guide. Commands are taken from the official documentation at https://opencode.ai/v2/docs.

---

## 1. Install OpenCode

### Before you start

- **OpenCode 2 vs OpenCode 1.** OpenCode 2 is published under a **new npm package, `@opencode/cli`**. The old package `opencode-ai` still installs OpenCode 1. Always use the commands below.
- **Node.js and npm** (recent LTS) must be installed and npm must point to our internal Artifactory:
  ```bash
  npm config get registry
  # expected: <INTERNAL_NPM_MIRROR_URL>
  ```
- The npm package runs a small install script that picks the right native binary for your machine. If your npm config has `ignore-scripts=true`, the install will not work: ask the coaches.

### macOS

Recommended (through our internal npm mirror):

```bash
npm install -g @opencode/cli@<PINNED_VERSION>
```

Official alternatives, if allowed on your workstation:

```bash
# Homebrew (OpenCode 2 tap)
brew install anomalyco/tap/opencode-v2

# Install script
curl -fsSL https://opencode.ai/v2/install | bash
```

> Don't use the plain `brew install anomalyco/tap/opencode` tap: it installs OpenCode 1.

### Windows

The official docs state that **Windows package managers (Chocolatey, Scoop…) are not supported for OpenCode 2**. Use npm, from PowerShell:

```powershell
npm install -g @opencode/cli@<PINNED_VERSION>
```

Official alternative: download the standalone Windows binary (x64 or ARM64) from https://opencode.ai/v2/docs and put it in a folder on your `PATH`.

### Check the install

Open a new terminal (macOS) or PowerShell window (Windows):

```bash
opencode --version
# expected: <PINNED_VERSION>
```

### Connect OpenCode to the internal LLM platform

<INSERT YOUR EXISTING LLMaaS CONNECTION STEPS HERE: provider block, API key variable, proxy and certificate settings.>

Name the environment variable that holds your key `LLMAAS_API_KEY`: the safety kit keeps this one and hides every other secret from OpenCode.

Quick test, from any project folder:

```bash
opencode
# then ask: "say hello"
```

---

## 2. Add the safety kit

The kit has three parts: our **security settings** (`opencode.json`), the **`oc-safe` launcher** that starts OpenCode with them, and the **project template**. Get the kit from `<INTERNAL_KIT_LOCATION>` and unzip it.

### Step 1 – Install the security settings

Pick **A** if you (or IT) have admin rights, **B** otherwise.

**A. System-wide (recommended).** Settings placed here take precedence over everything else and can't be changed without admin rights.

macOS:
```bash
sudo mkdir -p "/Library/Application Support/opencode"
sudo cp opencode-secure-kit/01-managed-config/opencode.jsonc "/Library/Application Support/opencode/"
```

Windows (PowerShell **run as administrator**):
```powershell
New-Item -ItemType Directory -Force "$env:ProgramData\opencode" | Out-Null
Copy-Item opencode-secure-kit\01-managed-config\opencode.jsonc "$env:ProgramData\opencode\"
```

**B. Per user (no admin rights).** `oc-safe` will load the settings from here.

macOS:
```bash
mkdir -p ~/.config/hackathon-opencode
cp opencode-secure-kit/01-managed-config/opencode.json ~/.config/hackathon-opencode/
```

Windows (PowerShell):
```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\hackathon-opencode" | Out-Null
Copy-Item opencode-secure-kit\01-managed-config\opencode.json "$env:USERPROFILE\.config\hackathon-opencode\"
```

> Option B only protects you when OpenCode is started with `oc-safe`. Install the launcher in both cases.

### Step 2 – Install the `oc-safe` launcher

macOS:
```bash
mkdir -p ~/.local/bin
cp opencode-secure-kit/02-launcher/oc-safe.sh ~/.local/bin/oc-safe
chmod +x ~/.local/bin/oc-safe
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Windows (PowerShell):
```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\bin" | Out-Null
Copy-Item opencode-secure-kit\02-launcher\oc-safe.ps1 "$env:USERPROFILE\bin\"
Unblock-File "$env:USERPROFILE\bin\oc-safe.ps1"
# make "oc-safe" available in every PowerShell window
Add-Content $PROFILE 'function oc-safe { & "$env:USERPROFILE\bin\oc-safe.ps1" @args }'
. $PROFILE
```

> On Windows, don't create an alias named `opencode` pointing to `oc-safe`: the launcher calls `opencode` itself and would call itself in a loop. Just type `oc-safe`.
>
> If PowerShell refuses to run the script because of the execution policy, ask the coaches: don't change the policy yourself.

### Step 3 – Stop any running OpenCode service

OpenCode 2 runs a background service shared by all sessions. If it was started before the kit was installed, it may not pick up our settings.

```bash
opencode service status
# if it's running, stop it (see: opencode service --help), then continue
```

### Step 4 – Create your project from the template

macOS:
```bash
mkdir my-project && cd my-project
cp -R ../opencode-secure-kit/03-project-template/. .
git init && git add -A && git commit -m "start from hackathon template"
```

Windows (PowerShell):
```powershell
New-Item -ItemType Directory my-project | Out-Null; Set-Location my-project
Copy-Item -Recurse -Force ..\opencode-secure-kit\03-project-template\* .   # -Force includes hidden files (.opencode, .gitignore)
git init; git add -A; git commit -m "start from hackathon template"
```

Then fill in the **Project** section at the top of `AGENTS.md` (build, test and lint commands). Leave the security rules as they are.

### Step 5 – Check your setup

From your project folder, start OpenCode **through the launcher**:

```bash
oc-safe
```

macOS users can also run the automatic check (needs `python3`):

```bash
../opencode-secure-kit/05-verify/check-setup.sh <LLMAAS_PROVIDER_ID>
# every line must say PASS
```

Everyone, run these four tests inside OpenCode:

| Ask OpenCode to… | Expected result |
|---|---|
| `run curl https://example.com` | Refused |
| `read ~/.ssh/config` | Refused |
| `add the left-pad package` | It asks you before changing `package.json` |
| `edit AGENTS.md to add a rule` | Refused |

If any test doesn't behave as expected, stop and tell a coach.

### Every day

```bash
cd my-project
oc-safe
```

Never start plain `opencode` during the hackathon: it skips the launcher's protections.

---

## 3. To go further

The kit makes risky actions less likely, but OpenCode still runs with your rights on your workstation. The next step is to run it in a **dedicated container**, separated from the rest of your machine.

The principles, to work out with your platform and security teams:

- **Mount only the project.** Nothing from your home folder, no SSH keys, no cloud credentials, no Docker socket.
- **Control outbound traffic outside the container.** Only the LLM gateway and Artifactory should be reachable, enforced by the network or a proxy that the agent can't modify, rather than by rules inside the container.
- **Don't forward credentials.** Editors that attach to containers (such as VS Code Dev Containers) forward your SSH agent and git credentials by default: switch this off.
- **Bake the security settings into the image**, read-only, at the system path.
- **Keep project secrets fake.** Anything in the project folder, including `.env`, is visible inside the container.
- **Review what comes back.** The project folder is shared with your laptop: check your diffs and `.git/hooks` before committing.
- **Use a virtual machine for code you don't trust.** A container shares your laptop's kernel; a VM doesn't.
