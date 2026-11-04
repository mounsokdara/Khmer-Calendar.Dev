# Silent install -> check files and shortcut -> silent uninstall -> check removal.
# Usage: ./test-installer.ps1 -Setup <KhmerCalendar-windows-x64-setup.exe | -universal-setup.exe>
param([Parameter(Mandatory = $true)][string]$Setup)
$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:RUNNER_TEMP 'kc-install-test'
if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
$log = Join-Path $env:RUNNER_TEMP 'kc-setup.log'

$p = Start-Process $Setup -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/CURRENTUSER", "/DIR=`"$dir`"", "/LOG=`"$log`"" -Wait -PassThru
if ($p.ExitCode -ne 0) { Get-Content $log -Tail 40; throw "setup exited with $($p.ExitCode)" }
$problems = @()
foreach ($f in 'khmer_calendar.exe', 'flutter_windows.dll', 'msvcp140.dll', 'vcruntime140_1.dll', 'data\app.so', 'unins000.exe') {
  if (-not (Test-Path (Join-Path $dir $f))) { $problems += "after install, missing: $f" }
}
$pol = Join-Path $dir 'Privacy Policy.url'
if (-not (Test-Path $pol)) { $problems += "Privacy Policy link missing after install" }
elseif ((Get-Content $pol -Raw) -notmatch 'PRIVACY\.md') { $problems += "Privacy Policy link has the wrong URL" }
$lnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Khmer Calendar\Khmer Calendar.lnk'
if (-not (Test-Path $lnk)) { $problems += "Start menu shortcut missing" }
Write-Host "installed files: $((Get-ChildItem $dir -Recurse -File).Count)"

$u = Start-Process (Join-Path $dir 'unins000.exe') -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" -Wait -PassThru
if ($u.ExitCode -ne 0) { $problems += "uninstaller exited with $($u.ExitCode)" }
Start-Sleep -Seconds 3
if (Test-Path (Join-Path $dir 'khmer_calendar.exe')) { $problems += "uninstall left khmer_calendar.exe behind" }
if (Test-Path $lnk) { $problems += "uninstall left the Start menu shortcut" }
if (Test-Path $pol) { $problems += "uninstall left the Privacy Policy link" }

$msg = if ($problems) { "FAILED: " + ($problems -join "; ") } else { "install, shortcut and uninstall all OK" }
Write-Host "::notice title=Installer test::$msg"
if ($problems) { throw ($problems -join "; ") }
Write-Host "OK: $msg"
