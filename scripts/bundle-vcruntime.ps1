# Copy the Visual C++ runtime DLLs next to the exe ("app-local" deployment) so the app
# starts on a clean Windows install that has no "Visual C++ Redistributable" yet.
# Without them Windows shows: "MSVCP140.dll / VCRUNTIME140_1.dll was not found".
#
# Usage: ./bundle-vcruntime.ps1 -Dir <Release folder> [-Exe khmer_calendar.exe] [-Arch x64|arm64]
#
# Run this AFTER Authenticode signing: these DLLs are already signed by Microsoft and
# must keep that signature (do not re-sign them with our own certificate).
# Fails if the runtime cannot be found, or if the exe / any of our DLLs depends on a
# Visual C++ runtime DLL that is not in the folder.
param(
  [Parameter(Mandatory = $true)][string]$Dir,
  [string]$Exe = 'khmer_calendar.exe',
  [ValidateSet('x64', 'arm64')][string]$Arch = 'x64'
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path (Join-Path $Dir $Exe))) { throw "$Exe not found in $Dir" }

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) { throw "vswhere.exe not found" }
$vs = & $vswhere -latest -products * -property installationPath
if (-not $vs) { throw "Visual Studio installation not found" }

# ...\VC\Redist\MSVC\<version>\<arch>\Microsoft.VC14x.CRT   (release runtime, redistributable)
$crt = Get-ChildItem (Join-Path $vs 'VC\Redist\MSVC') -Directory |
  Where-Object { $_.Name -match '^\d' } | Sort-Object { [version]$_.Name } -Descending |
  ForEach-Object { Get-ChildItem (Join-Path $_.FullName $Arch) -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue } |
  Select-Object -First 1
if (-not $crt) { throw "$Arch Microsoft.VC*.CRT folder not found under $vs" }
Write-Host "Using runtime from $($crt.FullName)"

$dlls = Get-ChildItem $crt.FullName -Filter *.dll
foreach ($d in $dlls) { Copy-Item $d.FullName $Dir -Force; Write-Host "bundled $($d.Name)" }
foreach ($need in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  if (-not (Test-Path (Join-Path $Dir $need))) { throw "required runtime missing after copy: $need" }
}

# Check what the app really imports. dumpbin ships with the same Visual Studio.
$dumpbins = @(Get-ChildItem (Join-Path $vs 'VC\Tools\MSVC') -Recurse -Filter dumpbin.exe -ErrorAction SilentlyContinue)
# Any host works for reading imports; prefer the x64 one (runs natively on x64 and emulated on arm64).
$dumpbin = ($dumpbins | Where-Object { $_.FullName -match 'Hostx64\\x64' } | Select-Object -First 1)
if (-not $dumpbin) { $dumpbin = $dumpbins | Select-Object -First 1 }
if (-not $dumpbin) {
  Write-Warning "dumpbin.exe not found - dependency check skipped"
} else {
  $rt = '^(msvcp|vcruntime|concrt|vcomp|vccorlib)\d+.*\.dll$'
  $missing = @()
  foreach ($f in Get-ChildItem $Dir -Recurse -Include *.exe, *.dll | Where-Object { $_.Name -notmatch $rt }) {
    $deps = & $dumpbin.FullName /dependents $f.FullName 2>$null |
      ForEach-Object { $_.Trim() } | Where-Object { $_ -match $rt }
    foreach ($dep in $deps) {
      if (-not (Test-Path (Join-Path $Dir $dep))) { $missing += "$($f.Name) -> $dep" }
    }
  }
  if ($missing) { throw "missing runtime DLLs:`n$($missing -join "`n")" }
  Write-Host "OK: every Visual C++ runtime import is present in the folder"
}
Write-Host "OK: runtime bundled ($($dlls.Count) files)"
