# Flips a Windows exe from the console subsystem to the GUI subsystem so it
# starts with no console window (no cmd popup). `dart compile exe` always
# produces a console exe, so run this right after compiling khmer-calendar-bg.exe.
param([Parameter(Mandatory = $true)][string]$Exe)

$ErrorActionPreference = 'Stop'
$path = (Resolve-Path $Exe).Path
$fs = [System.IO.File]::Open($path, 'Open', 'ReadWrite')
try {
  $br = New-Object System.IO.BinaryReader($fs)
  $bw = New-Object System.IO.BinaryWriter($fs)

  $fs.Seek(0x3C, 'Begin') | Out-Null
  $peOffset = $br.ReadInt32()

  $fs.Seek($peOffset, 'Begin') | Out-Null
  if ($br.ReadUInt32() -ne 0x00004550) { throw "Not a PE file: $path" }

  # PE signature (4) + COFF header (20) + 68 bytes into the optional header.
  # The Subsystem field sits at the same offset for PE32 and PE32+.
  $subsystemPos = $peOffset + 4 + 20 + 68
  $fs.Seek($subsystemPos, 'Begin') | Out-Null
  $old = $br.ReadUInt16()

  if ($old -eq 2) {
    Write-Host "$path already uses the GUI subsystem"
  } elseif ($old -eq 3) {
    $fs.Seek($subsystemPos, 'Begin') | Out-Null
    $bw.Write([UInt16]2)
    $bw.Flush()
    Write-Host "$path switched from console (3) to GUI (2) subsystem"
  } else {
    throw "Unexpected subsystem value $old in $path"
  }
} finally {
  $fs.Close()
}
