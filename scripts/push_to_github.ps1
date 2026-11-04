# push_to_github.ps1
# Publish this repository to GitHub through the REST API (no git/gh required).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\scripts\push_to_github.ps1 -Token "github_pat_xxx"
#
# The token is only kept in memory. It is never written to a file or committed.
# Required token permissions:
#   - classic PAT: repo
#   - fine-grained PAT: Administration (read/write) + Contents (read/write)
#
# The script:
#   1. verifies the token and the target account;
#   2. creates the public repository if it does not exist (or reuses it);
#   3. uploads every file as a Git blob, builds one tree and one commit;
#   4. creates or fast-forwards the target branch (default: main).
#
# It skips .git, __pycache__, .pytest_cache, td_project, vendor_ip and build products.

param(
    [Parameter(Mandatory = $true)][string]$Token,
    [string]$Repo = "low-latency-vision-fpga-v2",
    [string]$Branch = "main",
    [string]$Description = "Low-latency real-time vision on Anlogic PH1P35: HX1P35A + SC500CS + HDMI, edge/binary/color-block/oil/motion",
    [switch]$Private
)

$ErrorActionPreference = "Stop"
$api = "https://api.github.com"
$root = Split-Path -Parent $PSScriptRoot
$headers = @{
    Authorization          = "Bearer $Token"
    Accept                 = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent"           = "low-latency-vision-fpga-v2-publisher"
}

function Invoke-GitHub {
    param(
        [string]$Method,
        [string]$Path,
        $Body = $null,
        [switch]$AllowNotFound
    )
    $uri = "$api$Path"
    $request = @{
        Uri         = $uri
        Method      = $Method
        Headers     = $headers
        ErrorAction = "Stop"
    }
    if ($null -ne $Body) {
        $json = $Body | ConvertTo-Json -Depth 20 -Compress
        $request.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
        $request.ContentType = "application/json; charset=utf-8"
    }

    try {
        return Invoke-RestMethod @request
    } catch {
        $status = 0
        try { $status = [int]$_.Exception.Response.StatusCode } catch { }
        if ($AllowNotFound -and $status -eq 404) { return $null }

        $detail = $_.ErrorDetails.Message
        if (-not $detail) { $detail = $_.Exception.Message }
        throw "GitHub API $Method $Path -> HTTP $status : $detail"
    }
}

function Test-SkipFile {
    param([System.IO.FileInfo]$File)
    $relative = $File.FullName.Substring($root.Length + 1)
    if ($relative -match '^(\.git|__pycache__|\.pytest_cache|td_project|vendor_ip)\\') { return $true }
    if ($relative -match '\\__pycache__\\' -or $relative -match '\\\.pytest_cache\\') { return $true }
    if ($File.Extension -in @('.zip', '.pyc', '.bit', '.bid', '.db', '.qor', '.area', '.timing', '.ts')) { return $true }
    return $false
}

Write-Host "==> Verify token"
$me = Invoke-GitHub -Method Get -Path "/user"
$owner = $me.login
Write-Host "    account: $owner"

Write-Host "==> Check repository"
$repoInfo = Invoke-GitHub -Method Get -Path "/repos/$owner/$Repo" -AllowNotFound
if (-not $repoInfo) {
    $repoBody = @{
        name        = $Repo
        description = $Description
        private     = [bool]$Private
        auto_init   = $false
        has_issues  = $true
        has_wiki    = $false
        has_projects = $false
    }
    $repoInfo = Invoke-GitHub -Method Post -Path "/user/repos" -Body $repoBody
    Write-Host "    created: $($repoInfo.full_name)"
} else {
    Write-Host "    exists:  $($repoInfo.full_name)"
}

Write-Host "==> Read current branch"
$ref = Invoke-GitHub -Method Get -Path "/repos/$owner/$Repo/git/ref/heads/$Branch" -AllowNotFound
$baseTree = $null
$parents = @()
if ($ref) {
    $headSha = $ref.object.sha
    $headCommit = Invoke-GitHub -Method Get -Path "/repos/$owner/$Repo/git/commits/$headSha"
    $baseTree = $headCommit.tree.sha
    $parents = @($headSha)
    Write-Host "    head: $headSha"
} else {
    Write-Host "    empty repository, first commit will create refs/heads/$Branch"
}

Write-Host "==> Upload blobs"
$files = Get-ChildItem -Path $root -Recurse -File | Where-Object { -not (Test-SkipFile $_) } | Sort-Object FullName
$treeEntries = @()
$index = 0
foreach ($file in $files) {
    $index++
    $relative = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
    $base64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($file.FullName))
    $blob = Invoke-GitHub -Method Post -Path "/repos/$owner/$Repo/git/blobs" -Body @{
        content  = $base64
        encoding = "base64"
    }
    $treeEntries += @{
        path = $relative
        mode = "100644"
        type = "blob"
        sha  = $blob.sha
    }
    Write-Host ("    [{0,3}/{1,3}] {2}" -f $index, $files.Count, $relative)
}

if ($treeEntries.Count -eq 0) { throw "No files to upload under $root" }

Write-Host "==> Create tree and commit"
$treeBody = @{ tree = @($treeEntries) }
if ($baseTree) { $treeBody.base_tree = $baseTree }
$newTree = Invoke-GitHub -Method Post -Path "/repos/$owner/$Repo/git/trees" -Body $treeBody

$commitBody = @{
    message = "init: low-latency vision v2 on Anlogic PH1P35"
    tree    = $newTree.sha
    parents = @($parents)
}
$newCommit = Invoke-GitHub -Method Post -Path "/repos/$owner/$Repo/git/commits" -Body $commitBody

Write-Host "==> Update branch $Branch"
if ($ref) {
    Invoke-GitHub -Method Patch -Path "/repos/$owner/$Repo/git/refs/heads/$Branch" -Body @{
        sha   = $newCommit.sha
        force = $false
    } | Out-Null
} else {
    Invoke-GitHub -Method Post -Path "/repos/$owner/$Repo/git/refs" -Body @{
        ref = "refs/heads/$Branch"
        sha = $newCommit.sha
    } | Out-Null
}

# Best effort: make the pushed branch the default. Ignore failures caused by
# token permissions, because the branch can be changed in repository settings.
try {
    Invoke-GitHub -Method Patch -Path "/repos/$owner/$Repo" -Body @{ default_branch = $Branch } | Out-Null
} catch {
    Write-Warning "Could not set default branch automatically: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "Done: $($files.Count) files, commit $($newCommit.sha)"
Write-Host "Repository: https://github.com/$owner/$Repo"
Write-Host "Remember to revoke the token after publishing."
