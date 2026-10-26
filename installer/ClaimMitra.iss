
#define MyAppName "ClaimMitra"
#define MyAppVersion "1.0.7"
#define MyAppPublisher "ClaimMitra"
#define MyAppExeName "ClaimMitra.exe"
#define VCRedistVersion GetFileVersion("..\dist\vc_redist.x64.exe")

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
; Embedded in Setup and extracted only if the x64 runtime needs installation.
Source: "..\dist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: dontcopy

[Icons]
Name: "{group}\ClaimMitra"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\ClaimMitra"; Filename: "{app}\{#MyAppExeName}"; \
    Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; \
    Description: "Launch ClaimMitra"; \
    Flags: postinstall nowait skipifsilent; Check: ShouldLaunchClaimMitra

[Code]
const
  VCRuntimeKey = 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64';
  VCRuntimeVersion = '{#VCRedistVersion}';

var
  RuntimeRestartRequired: Boolean;

function ShouldLaunchClaimMitra: Boolean;
begin
  Result := not RuntimeRestartRequired;
end;

function NextVersionPart(var VersionText: String): Integer;
var
  DotPosition: Integer;
  PartText: String;
begin
  DotPosition := Pos('.', VersionText);
  if DotPosition = 0 then
  begin
    PartText := VersionText;
    VersionText := '';
  end
  else
  begin
    PartText := Copy(VersionText, 1, DotPosition - 1);
    Delete(VersionText, 1, DotPosition);
  end;
  Result := StrToIntDef(PartText, 0);
end;

function IsVCRuntimeInstalled: Boolean;
var
  Installed: Cardinal;
  VersionText: String;
  RequiredVersionText: String;
  InstalledPart, RequiredPart: Integer;
  PartIndex: Integer;
begin
  Result := False;
  if not RegQueryDWordValue(HKLM64, VCRuntimeKey, 'Installed', Installed) or
     (Installed <> 1) or
     not RegQueryStringValue(HKLM64, VCRuntimeKey, 'Version', VersionText) then
    Exit;

  if (Length(VersionText) > 0) and (VersionText[1] = 'v') then
    Delete(VersionText, 1, 1);
  RequiredVersionText := VCRuntimeVersion;

  for PartIndex := 1 to 4 do
  begin
    InstalledPart := NextVersionPart(VersionText);
    RequiredPart := NextVersionPart(RequiredVersionText);
    if InstalledPart > RequiredPart then
    begin
      Result := True;
      Exit;
    end;
    if InstalledPart < RequiredPart then
      Exit;
  end;
  Result := True;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Result := '';
  if IsVCRuntimeInstalled then
    Exit;

  ExtractTemporaryFile('vc_redist.x64.exe');
  if not Exec(ExpandConstant('{tmp}\vc_redist.x64.exe'),
    '/install /quiet /norestart', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Result := 'The Microsoft Visual C++ Runtime installer could not be started. ' +
      'ClaimMitra cannot be installed without this required component.';
    Exit;
  end;

  case ResultCode of
    0:
      begin
        { Installed successfully. }
      end;
    3010, 1641:
    begin
      RuntimeRestartRequired := True;
      NeedsRestart := True;
    end;
    1638:
    begin
      { Another runtime product was present; accept only if the x64 runtime is now suitable. }
      if not IsVCRuntimeInstalled then
        Result := 'The installed Microsoft Visual C++ Runtime is not new enough. ' +
          'Please restart Windows and run the ClaimMitra installer again.';
    end;
  else
    Result := 'The Microsoft Visual C++ Runtime installation failed with exit code ' +
      IntToStr(ResultCode) + '. ClaimMitra cannot be installed without this component.';
  end;

  if (Result = '') and not IsVCRuntimeInstalled then
    Result := 'The Microsoft Visual C++ Runtime installer completed without installing ' +
      'the required x64 runtime version. ClaimMitra cannot be installed.';
end;
