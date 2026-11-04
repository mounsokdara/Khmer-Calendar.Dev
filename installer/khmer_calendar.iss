; Inno Setup script - Windows setup wizard for Khmer Calendar.
; Built in CI by scripts/build-installer.ps1:  iscc /DAppVersion=1.0.4 /DArch=x64|arm64|universal /DSourceDir=... [/DArm64Dir=...] /DOutDir=... khmer_calendar.iss
;   Arch=x64        installs the x64 build (also runs on Arm64 Windows 11 through emulation)
;   Arch=arm64      installs the native Arm64 build
;   Arch=universal  carries both builds (SourceDir = x64, Arm64Dir = arm64) and installs the one that matches the PC
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #error SourceDir is required (the signed Release folder)
#endif
#ifndef OutDir
  #define OutDir "Output"
#endif
#ifndef Arch
  #define Arch "x64"
#endif
#if Arch == "universal"
  #ifndef Arm64Dir
    #error Arm64Dir is required for the universal installer
  #endif
#endif

[Setup]
AppId={{6E1B7E55-2C0F-4B8D-9B7A-3D5F0A7C41E9}
AppName=Khmer Calendar
AppVersion={#AppVersion}
AppPublisher=Dara Sok Moun
AppPublisherURL=https://github.com/mounsokdara/Khmer-Calendar
AppSupportURL=https://github.com/mounsokdara/Khmer-Calendar/issues
AppUpdatesURL=https://github.com/mounsokdara/Khmer-Calendar/releases/latest
; Per-user by default (no admin prompt); the wizard offers "all users" as an option.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\Khmer Calendar
DefaultGroupName=Khmer Calendar
DisableProgramGroupPage=yes
LicenseFile={#SourcePath}\..\LICENSE
InfoBeforeFile={#SourcePath}\PRIVACY.txt
SetupIconFile={#SourcePath}\..\khmer_calendar\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\khmer_calendar.exe
OutputDir={#OutDir}
OutputBaseFilename=KhmerCalendar-windows-{#Arch}-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
#if Arch == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#elif Arch == "universal"
ArchitecturesAllowed=x64compatible or arm64
ArchitecturesInstallIn64BitMode=x64compatible or arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
#if Arch == "universal"
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: not IsArm64
Source: "{#Arm64Dir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: IsArm64
#else
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
#endif

[Icons]
Name: "{group}\Khmer Calendar"; Filename: "{app}\khmer_calendar.exe"
Name: "{group}\{cm:UninstallProgram,Khmer Calendar}"; Filename: "{uninstallexe}"
Name: "{group}\Privacy Policy"; Filename: "{app}\Privacy Policy.url"
Name: "{autodesktop}\Khmer Calendar"; Filename: "{app}\khmer_calendar.exe"; Tasks: desktopicon

[INI]
Filename: "{app}\Privacy Policy.url"; Section: "InternetShortcut"; Key: "URL"; String: "https://github.com/mounsokdara/Khmer-Calendar/blob/main/PRIVACY.md"

[UninstallDelete]
Type: files; Name: "{app}\Privacy Policy.url"

[Run]
Filename: "{app}\khmer_calendar.exe"; Description: "{cm:LaunchProgram,Khmer Calendar}"; Flags: nowait postinstall skipifsilent
