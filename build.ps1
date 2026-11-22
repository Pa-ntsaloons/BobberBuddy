# Builds releases\<AddonName>-<version>.zip for CurseForge.
# Usage: powershell -ExecutionPolicy Bypass -File .\build.ps1

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$addon = Split-Path -Leaf $PSScriptRoot
$tocPath = Join-Path $PSScriptRoot "$addon.toc"
if (-not (Test-Path -LiteralPath $tocPath)) {
    throw "No $addon.toc in $PSScriptRoot (the .toc name must match the folder)."
}

$tocLines = Get-Content -LiteralPath $tocPath -Encoding UTF8
$versionLine = $tocLines | Where-Object { $_ -match '^##\s*Version:\s*(\S+)' } | Select-Object -First 1
if (-not $versionLine) {
    throw "No '## Version:' line in $addon.toc."
}
$null = $versionLine -match '^##\s*Version:\s*(\S+)'
$version = $Matches[1]

# The .toc, everything it loads, and LICENSE. A loaded .xml can load more
# files; they're picked up from its <Script file=...> and <Include file=...>.
$files = New-Object System.Collections.Generic.List[string]
function Add-GameFile([string]$relative) {
    $relative = $relative.Trim() -replace '\\', '/'
    if ($relative -eq '' -or $files.Contains($relative)) { return }
    $full = Join-Path $PSScriptRoot $relative
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "$addon.toc loads '$relative', which doesn't exist."
    }
    $files.Add($relative)
    if ($relative -like '*.xml') {
        $folder = Split-Path -Parent $relative
        $xml = Get-Content -LiteralPath $full -Raw -Encoding UTF8
        foreach ($match in [regex]::Matches($xml, '<(?:Script|Include)\s+file\s*=\s*"([^"]+)"')) {
            $child = $match.Groups[1].Value
            if ($folder) { $child = "$folder/$child" }
            Add-GameFile $child
        }
    }
}

Add-GameFile "$addon.toc"
foreach ($line in $tocLines) {
    if ($line -match '^\s*#' -or $line.Trim() -eq '') { continue }
    Add-GameFile $line
}
Add-GameFile 'LICENSE'
# Bindings.xml isn't listed in the .toc - the game loads it by name - so add it explicitly.
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Bindings.xml')) { Add-GameFile 'Bindings.xml' }

# Write the zip with forward-slash entry paths (Compress-Archive on
# PowerShell 5.1 writes backslashes, which some unzip tools mishandle).
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$releases = Join-Path $PSScriptRoot 'releases'
New-Item -ItemType Directory -Force -Path $releases | Out-Null
$zipPath = Join-Path $releases "$addon-$version.zip"
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($relative in $files) {
        $source = Join-Path $PSScriptRoot $relative
        $entry = "$addon/$relative"
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $source, $entry, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally {
    $zip.Dispose()
}
Write-Host "Built releases\$addon-$version.zip ($($files.Count) files)" -ForegroundColor Green

# This version's changelog section: from "## <version>" to the next "## ".
$changelogPath = Join-Path $PSScriptRoot 'CHANGELOG.md'
$section = $null
if (Test-Path -LiteralPath $changelogPath) {
    $collected = New-Object System.Collections.Generic.List[string]
    $inside = $false
    foreach ($line in (Get-Content -LiteralPath $changelogPath -Encoding UTF8)) {
        if ($line -match '^##\s') {
            if ($inside) { break }
            $inside = $line -match ('^##\s+' + [regex]::Escape($version) + '(\s|$)')
            continue
        }
        if ($inside) { $collected.Add($line) }
    }
    if ($collected.Count -gt 0) {
        $section = ($collected -join "`r`n").Trim()
    }
}

if ($section) {
    Write-Host ''
    Write-Host "Changelog for $version (copied to the clipboard):" -ForegroundColor Cyan
    Write-Host $section
    Set-Clipboard -Value $section
} else {
    Write-Warning "CHANGELOG.md has no '## $version' section."
}
