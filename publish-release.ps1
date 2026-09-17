<#
.SYNOPSIS
  Publish a GitHub release for the Family Education Research Platform source bundle.

.DESCRIPTION
  Idempotent publisher. It:
    1. authenticates against the GitHub REST API;
    2. creates the repository if it does not exist;
    3. pushes the staged source tree (git, which honours .gitignore);
    4. creates the release tag;
    5. creates the release and uploads the source archives + checksums;
    6. prints the resulting release URL.

  The token is read from the GITHUB_TOKEN environment variable by default so it
  never appears in a command line.

.EXAMPLE
  $env:GITHUB_TOKEN = 'ghp_...'
  .\publish-release.ps1 -Repo 'myuser/family-edu-research-platform'
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [string]$Tag         = 'v1.0.0',
  [string]$Token       = $env:GITHUB_TOKEN,
  [string]$SourceDir   = "$PSScriptRoot\build\family-edu-research-platform",
  [string]$DistDir     = "$PSScriptRoot\dist",
  [string]$ReleaseName = 'v1.0.0 — PHASE 1-9 complete',
  [switch]$SkipPush
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Fail([string]$m) { Write-Host "FAIL  $m" -ForegroundColor Red; exit 1 }
function Ok([string]$m)   { Write-Host "OK    $m" -ForegroundColor Green }
function Info([string]$m) { Write-Host "..    $m" -ForegroundColor Gray }

if (-not $Token) { Fail 'No token. Set $env:GITHUB_TOKEN or pass -Token.' }
if ($Repo -notmatch '^[^/]+/[^/]+$') { Fail "-Repo must be owner/name (got '$Repo')." }
$owner, $name = $Repo.Split('/', 2)

$api     = 'https://api.github.com'
$headers = @{
  Authorization          = "Bearer $Token"
  Accept                 = 'application/vnd.github+json'
  'X-GitHub-Api-Version' = '2022-11-28'
  'User-Agent'           = 'ferp-release-script'
}

# ---------------------------------------------------------------- 1. auth
Info 'Authenticating'
try { $me = Invoke-RestMethod -Uri "$api/user" -Headers $headers -Method Get }
catch { Fail "Authentication failed: $($_.Exception.Message)" }
Ok "Authenticated as $($me.login)"

# ------------------------------------------------------- 2. ensure the repo
Info "Checking $Repo"
$exists = $true
try { $null = Invoke-RestMethod -Uri "$api/repos/$Repo" -Headers $headers -Method Get }
catch {
  if ($_.Exception.Response.StatusCode.value__ -eq 404) { $exists = $false }
  else { Fail "Repo lookup failed: $($_.Exception.Message)" }
}

if (-not $exists) {
  if ($owner -ne $me.login) { Fail "Repo $Repo does not exist and cannot be created under a different owner." }
  Info "Creating repository $name"
  $body = @{
    name        = $name
    description = 'Family Education Research Platform - AI-powered research operating system'
    private     = $false
    auto_init   = $true
  } | ConvertTo-Json
  try { $null = Invoke-RestMethod -Uri "$api/user/repos" -Headers $headers -Method Post -Body $body -ContentType 'application/json' }
  catch { Fail "Repo creation failed: $($_.Exception.Message)" }
  Ok "Created $Repo"
  Start-Sleep -Seconds 3
} else {
  Ok "Repository exists"
}

# --------------------------------------------------------- 3. push the source
if ($SkipPush) {
  Info 'Skipping push (-SkipPush)'
} else {
  if (-not (Test-Path -LiteralPath $SourceDir)) { Fail "Source dir not found: $SourceDir" }
  Push-Location $SourceDir
  try {
    if (-not (Test-Path '.git')) { git init --quiet | Out-Null }
    git -c user.name='ferp-release' -c user.email='ferp-release@users.noreply.github.com' add -A | Out-Null
    $staged = (git diff --cached --name-only | Measure-Object -Line).Lines
    if ($staged -gt 0) {
      git -c user.name='ferp-release' -c user.email='ferp-release@users.noreply.github.com' commit --quiet -m "Release $Tag" | Out-Null
      Ok "Committed $staged files"
    } else { Info 'Nothing new to commit' }
    git branch -M main 2>$null | Out-Null

    $remote = "https://x-access-token:$Token@github.com/$Repo.git"
    git remote remove origin 2>$null | Out-Null
    git remote add origin $remote | Out-Null
    Info 'Pushing main'
    git push --quiet --force origin main 2>&1 | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
    if ($LASTEXITCODE -ne 0) { Fail 'git push failed.' }
    Ok 'Pushed main'
  } finally {
    # never leave the token in .git/config
    git remote set-url origin "https://github.com/$Repo.git" 2>$null | Out-Null
    Pop-Location
  }
}

# ------------------------------------------------------------ 4. create the tag
$sha = $null
try {
  $ref  = Invoke-RestMethod -Uri "$api/repos/$Repo/git/ref/heads/main" -Headers $headers -Method Get
  $sha  = $ref.object.sha
  Info "main is at $sha"
} catch { Fail "Could not read main: $($_.Exception.Message)" }

try {
  $null = Invoke-RestMethod -Uri "$api/repos/$Repo/git/refs" -Headers $headers -Method Post -ContentType 'application/json' `
    -Body (@{ ref = "refs/tags/$Tag"; sha = $sha } | ConvertTo-Json)
  Ok "Created tag $Tag"
} catch {
  if ($_.Exception.Message -match 'already exists|422') { Info "Tag $Tag already exists" }
  else { Fail "Tag creation failed: $($_.Exception.Message)" }
}

# -------------------------------------------------------- 5. create the release
$notesPath = Join-Path $DistDir 'RELEASE_NOTES.md'
$notes = if (Test-Path -LiteralPath $notesPath) { Get-Content -LiteralPath $notesPath -Raw } else { "Release $Tag" }

$rel = $null
try {
  $rel = Invoke-RestMethod -Uri "$api/repos/$Repo/releases/tags/$Tag" -Headers $headers -Method Get
  Info "Release $Tag already exists (id $($rel.id)) - reusing"
} catch {
  Info "Creating release $Tag"
  $body = @{
    tag_name         = $Tag
    target_commitish = 'main'
    name             = $ReleaseName
    body             = $notes
    draft            = $false
    prerelease       = $false
  } | ConvertTo-Json -Depth 3
  try { $rel = Invoke-RestMethod -Uri "$api/repos/$Repo/releases" -Headers $headers -Method Post -Body $body -ContentType 'application/json' }
  catch { Fail "Release creation failed: $($_.Exception.Message)" }
  Ok "Release created"
}

# ------------------------------------------------------------- 6. upload assets
$assets = Get-ChildItem -LiteralPath $DistDir -File | Where-Object { $_.Name -ne 'RELEASE_NOTES.md' }
foreach ($a in $assets) {
  $existing = $rel.assets | Where-Object { $_.name -eq $a.Name }
  if ($existing) {
    Info "Replacing existing asset $($a.Name)"
    $null = Invoke-RestMethod -Uri "$api/repos/$Repo/releases/assets/$($existing.id)" -Headers $headers -Method Delete
  }
  Info "Uploading $($a.Name) ($([math]::Round($a.Length/1KB)) KB)"
  $up = @{
    Authorization          = "Bearer $Token"
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent'           = 'ferp-release-script'
  }
  try {
    $null = Invoke-RestMethod -Uri "https://uploads.github.com/repos/$Repo/releases/$($rel.id)/assets?name=$([uri]::EscapeDataString($a.Name))" `
      -Headers $up -Method Post -InFile $a.FullName -ContentType 'application/octet-stream'
    Ok "Uploaded $($a.Name)"
  } catch { Fail "Upload of $($a.Name) failed: $($_.Exception.Message)" }
}

Write-Host ''
Ok "Release published: $($rel.html_url)"
