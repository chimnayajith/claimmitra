
#define MyAppName "ClaimMitra"
#define MyAppVersion "1.0.5"
#define MyAppPublisher "ClaimMitra"
#define MyAppExeName "ClaimMitra.exe"

[Setup]
AppId={{A7D52F60-7C13-4C87-A239-7CDB9A2F10B1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\ClaimMitra
DefaultGroupName=ClaimMitra
OutputDir=..\dist
OutputBaseFilename=ClaimMitra-Setup-{#MyAppVersion}
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}

; Never install the database inside {app}.
; Keep user data in a persistent application-data directory.

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; \
    GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; \
    DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ClaimMitra"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\ClaimMitra"; Filename: "{app}\{#MyAppExeName}"; \
    Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; \
    Description: "Launch ClaimMitra"; \
    Flags: postinstall nowait skipifsilent
