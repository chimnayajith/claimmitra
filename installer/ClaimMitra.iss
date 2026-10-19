#define MyAppName "ClaimMitra"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "ClaimMitra"
#define MyAppExeName "claimmitra.exe"

[Setup]
AppId={{7E7A23B0-5B7D-4A45-AB25-CC4C5D3F06C1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\ClaimMitra
DefaultGroupName=ClaimMitra
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=ClaimMitra-Setup-1.0.0
SetupIconFile=claimmitra.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "claimmitra.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ClaimMitra"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\claimmitra.ico"
Name: "{autodesktop}\ClaimMitra"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch ClaimMitra"; Flags: postinstall nowait skipifsilent
