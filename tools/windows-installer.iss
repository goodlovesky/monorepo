#define MyAppName "Clash RS"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#ifndef MyOutputBase
  #define MyOutputBase "ClashRS-Setup-" + MyAppVersion + "-x64"
#endif
#ifndef SourceDir
  #define SourceDir "..\app\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist\windows"
#endif
[Setup]
AppId={{8D20EA4D-92E7-4D70-935F-F9F55FD52AE7}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\Clash RS
DefaultGroupName=Clash RS
OutputDir={#OutputDir}
OutputBaseFilename={#MyOutputBase}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\clash_rs.exe
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany=Clash RS
VersionInfoDescription=Clash RS Windows Installer
VersionInfoProductName=Clash RS
VersionInfoProductVersion={#MyAppVersion}
SetupMutex=ClashRS.Setup.Singleton
CloseApplications=yes
RestartApplications=no
CloseApplicationsFilter=clash_rs.exe,mihomo.exe
UsePreviousAppDir=yes
UsePreviousTasks=yes
DisableProgramGroupPage=yes
WizardStyle=modern
MinVersion=10.0.17763
ChangesEnvironment=no
[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[InstallDelete]
Type: files; Name: "{app}\clash_rs.exe"
Type: files; Name: "{app}\flutter_windows.dll"
Type: files; Name: "{app}\mihomo.exe"
Type: files; Name: "{app}\wintun.dll"
[Icons]
Name: "{autoprograms}\Clash RS"; Filename: "{app}\clash_rs.exe"
Name: "{autodesktop}\Clash RS"; Filename: "{app}\clash_rs.exe"; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked
[Run]
Filename: "{app}\clash_rs.exe"; Description: "Launch Clash RS"; Flags: nowait postinstall skipifsilent
[Code]
const
  WM_COMMAND = $0111;
  CLASH_RS_QUIT = 40002;

function FindWindow(lpClassName, lpWindowName: String): HWND;
  external 'FindWindowW@user32.dll stdcall';
function PostMessage(hWnd: HWND; Msg: LongWord; wParam: Longint; lParam: Longint): Boolean;
  external 'PostMessageW@user32.dll stdcall';

function RequestApplicationExit(): String;
var
  WindowHandle: HWND;
  Attempts: Integer;
begin
  Result := '';
  WindowHandle := FindWindow('FLUTTER_RUNNER_WIN32_WINDOW', 'Clash RS');
  if WindowHandle = 0 then Exit;
  PostMessage(WindowHandle, WM_COMMAND, CLASH_RS_QUIT, 0);
  for Attempts := 1 to 50 do
  begin
    Sleep(200);
    if FindWindow('FLUTTER_RUNNER_WIN32_WINDOW', 'Clash RS') = 0 then Exit;
  end;
  Result := 'Clash RS is still running. Exit the application and run setup again.';
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := RequestApplicationExit();
end;

function InitializeUninstall(): Boolean;
var
  ErrorMessage: String;
begin
  ErrorMessage := RequestApplicationExit();
  Result := ErrorMessage = '';
  if not Result then MsgBox(ErrorMessage, mbError, MB_OK);
end;
