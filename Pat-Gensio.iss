; -- CodeDll.iss --
;
; This script shows how to call functions in external DLLs (like Windows API functions)
; at runtime and how to perform direct callbacks from these functions to functions
; in the script.

[Setup]
AppName=Pat-Gensio
AppVersion=0.12
WizardStyle=modern
DefaultDirName={autopf}\Pat-Gensio 
DisableProgramGroupPage=yes
DisableWelcomePage=no
Compression=lzma2
SolidCompression=yes
UninstallDisplayIcon={app}\Pat.exe
ChangesEnvironment=true

[Files]
Source: "Pat.exe"; DestDir: "{app}"
Source: ".build/gensio-2.8.0/tools/gsound.exe"; DestDir: "{app}"
; Install our DLL to {app} so we can access it at uninstall time.
; Use "Flags: dontcopy" if you don't need uninstall time access.
;
; Base files needed from mingw64
Source: "c:/msys64/mingw64/bin/libgcc_s_seh-1.dll"; DestDir: "{app}"
Source: "c:/msys64/mingw64/bin/libstdc++-6.dll"; DestDir: "{app}"
Source: "c:/msys64/mingw64/bin/libwinpthread-1.dll"; DestDir: "{app}"

[Code]
const EnvironmentKey = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';

procedure EnvAddPath(Path: string);
var
    Paths: string;
begin
    { Retrieve current path (use empty string if entry not exists) }
    if not RegQueryStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths)
    then Paths := '';

    { Skip if string already found in path }
    if Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';') > 0 then exit;

    { App string to the end of the path variable }
    Paths := Paths + ';'+ Path +';'

    { Overwrite (or create if missing) path environment variable }
    if RegWriteStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths)
    then Log(Format('The [%s] added to PATH: [%s]', [Path, Paths]))
    else Log(Format('Error while adding the [%s] to PATH: [%s]', [Path, Paths]));
end;

procedure EnvRemovePath(Path: string);
var
    Paths: string;
    P: Integer;
begin
    { Skip if registry entry not exists }
    if not RegQueryStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths) then
        exit;

    { Skip if string not found in path }
    P := Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';');
    if P = 0 then exit;

    { Update path variable }
    Delete(Paths, P - 1, Length(Path) + 1);

    { Overwrite path environment variable }
    if RegWriteStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths)
    then Log(Format('The [%s] removed from PATH: [%s]', [Path, Paths]))
    else Log(Format('Error while removing the [%s] from PATH: [%s]', [Path, Paths]));
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
    if CurStep = ssPostInstall 
     then EnvAddPath(ExpandConstant('{app}'));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
    if CurUninstallStep = usPostUninstall
    then EnvRemovePath(ExpandConstant('{app}'));
end;
