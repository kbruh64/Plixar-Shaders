# Plixar Shaders - build.ps1
# Validates the GLSL, zips the pack with forward-slash paths (Iris/OptiFine
# need that), and refreshes the copies the download site serves.
# Run from the repo root:  powershell -File tools/build.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "1/3  Validating shaders..." -ForegroundColor Cyan
py "tools/check_shaders.py"
if ($LASTEXITCODE -ne 0) { throw "Shader validation failed -- not packaging." }

Write-Host "2/3  Packaging Plixar-Shaders.zip..." -ForegroundColor Cyan
$dest = Join-Path $root "Plixar-Shaders.zip"
if (Test-Path $dest) { Remove-Item $dest -Force }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($dest, [System.IO.Compression.ZipArchiveMode]::Create)
foreach ($f in (Get-ChildItem -Path (Join-Path $root "shaders") -Recurse -File)) {
    $rel = $f.FullName.Substring($root.Length + 1) -replace '\\','/'
    $entry = $zip.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
    $in = [System.IO.File]::OpenRead($f.FullName); $out = $entry.Open()
    $in.CopyTo($out); $out.Dispose(); $in.Dispose()
}
$zip.Dispose()

Write-Host "3/3  Refreshing site assets..." -ForegroundColor Cyan
Copy-Item (Join-Path $root "shaders/pack.png") (Join-Path $root "site/pack.png") -Force
Copy-Item $dest (Join-Path $root "site/Plixar-Shaders.zip") -Force

$kb = [math]::Round((Get-Item $dest).Length / 1KB, 1)
Write-Host "Done. Plixar-Shaders.zip = $kb KB, site/ updated." -ForegroundColor Green
