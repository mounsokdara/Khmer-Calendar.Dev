# Build the Windows setup wizard (Inno Setup) from the finished Release folder, then
# install and uninstall it silently as a smoke test.
#
# Usage: ./build-installer.ps1 -SourceDir <Release folder> -OutDir <dir> -Version 1.0.4 [-Arch x64|arm64|universal] [-Arm64Dir <arm64 Release folder>]
#   x64 / arm64: -SourceDir is that build.  universal: -SourceDir is the x64 build and -Arm64Dir the arm64 build;
#   the installer carries both and installs the one that matches the PC.
#
# Run AFTER the app files are signed and the Visual C++ runtime is bundled, so the
# installer carries exactly what the portable zip carries.
# Fails if the installer is not produced, or the silent install / uninstall test fails.
param(
  [Parameter(Mandatory = $true)][string]$SourceDir,
  [Parameter(Mandatory = $true)][string]$OutDir,
  [Parameter(Mandatory = $true)][string]$Version,
  [ValidateSet('x64', 'arm64', 'universal')][string]$Arch = 'x64',
  [string]$Arm64Dir = ''
)
$ErrorActionPreference = 'Stop'
$SourceDir = (Resolve-Path $SourceDir).Path
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
if (-not (Test-Path (Join-Path $SourceDir 'khmer_calendar.exe'))) { throw "khmer_calendar.exe not found in $SourceDir" }
if ($Arch -eq 'universal') {
  if (-not $Arm64Dir) { throw "-Arm64Dir is required for the universal installer" }
  $Arm64Dir = (Resolve-Path $Arm64Dir).Path
  if (-not (Test-Path (Join-Path $Arm64Dir 'khmer_calendar.exe'))) { throw "khmer_calendar.exe not found in $Arm64Dir" }
}

$iscc = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe") |
  Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
  Write-Host "Inno Setup not preinstalled - installing with Chocolatey"
  choco install innosetup -y --no-progress
  $iscc = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $iscc) { throw "ISCC.exe (Inno Setup) not found" }
Write-Host "Using $iscc"

$iss = Join-Path $PSScriptRoot '..\installer\khmer_calendar.iss'
$defs = @("/DAppVersion=$Version", "/DArch=$Arch", "/DSourceDir=$SourceDir", "/DOutDir=$OutDir")
if ($Arch -eq 'universal') { $defs += "/DArm64Dir=$Arm64Dir" }
& $iscc @defs $iss
if ($LASTEXITCODE -ne 0) { throw "iscc failed ($LASTEXITCODE)" }
$setup = Join-Path $OutDir "KhmerCalendar-windows-$Arch-setup.exe"
if (-not (Test-Path $setup)) { throw "installer not produced: $setup" }
Write-Host ("built {0} ({1:N1} MB)" -f (Split-Path $setup -Leaf), ((Get-Item $setup).Length / 1MB))
Write-Host "::notice title=Windows installer::built $(Split-Path $setup -Leaf), $([math]::Round((Get-Item $setup).Length/1MB,1)) MB"
