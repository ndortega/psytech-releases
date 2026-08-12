# Requires PowerShell 5+
# Manual install: `irm <url> | iex` or `install.ps1 [version]` → installs the latest (or given)
# version to the default location ($USERPROFILE\Downloads).
# Self-update from the app: `install.ps1 <version> <install-dir> <app-pid>` → waits for the
# running app to exit, replaces it in place, then relaunches it.
if (-not $Version -and $args.Count -gt 0) {
    $Version = $args[0]
}
$InstallDir = $args[1]
$WaitForPid = $args[2]

$ErrorActionPreference = 'Stop'

$REPO = "ndortega/psytech-releases"
if (-not $InstallDir) { $InstallDir = "$env:USERPROFILE\Downloads" }
$BINARY_NAME = "PsyTech.exe"
$TMP_DIR = Join-Path $env:TEMP "psytech_tmp"
$DEST = Join-Path $InstallDir $BINARY_NAME

# Self-update: the app is still running, so wait for it to exit before touching its binary.
if ($WaitForPid) {
    Write-Host "Waiting for PsyTech (PID $WaitForPid) to exit..."
    Wait-Process -Id $WaitForPid -ErrorAction SilentlyContinue
}

if (Test-Path $TMP_DIR) { Remove-Item $TMP_DIR -Recurse -Force }
New-Item -ItemType Directory -Path $TMP_DIR | Out-Null

# Detect architecture
switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { $ARCH_SUFFIX = "x64" }
    "ARM64" { $ARCH_SUFFIX = "arm64" }
    default {
        throw "Unsupported architecture: $env:PROCESSOR_ARCHITECTURE"
    }
}

$ASSET_NAME = "PsyTech-win-$ARCH_SUFFIX.exe"

# Fetch latest release tag from GitHub API
if ($Version) {
    $VERSION = "v" + $Version.TrimStart('v')
    Write-Host "Installing version: $VERSION"
} else {
    Write-Host "Fetching latest release..."
    $VERSION = (Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases/latest").tag_name
}

# Verify the release version exists
try {
    Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases/tags/$VERSION" | Out-Null
} catch {
    throw "Error: version $VERSION not found. Check available releases at https://github.com/$REPO/releases"
}

$DOWNLOAD_URL = "https://github.com/$REPO/releases/download/$VERSION/$ASSET_NAME"

Write-Host "Downloading from $DOWNLOAD_URL"
try {
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile "$TMP_DIR\$ASSET_NAME"
} catch {
    throw "Error: failed to download $ASSET_NAME for version $VERSION. It may not exist for this release."
}

# Remove older executable before installing
if (Test-Path $DEST) {
    Remove-Item $DEST -Force
    Write-Host "Removed old executable: $DEST"
}

Copy-Item "$TMP_DIR\$ASSET_NAME" $DEST -Force

Write-Host "Installed successfully to: $DEST"

# Self-update: relaunch the freshly installed app.
if ($WaitForPid) {
    Start-Process $DEST
}
