unit uSysInfo;

{ What machine this is, for a bug report.

  A report that says "it is slow" is worth ten times more with the RAM, the
  processor, the graphics driver and the operating system beside it, and
  none of that needs asking for.  The rules: nothing about the person - no
  user name, no host name, no path, no serial number - nothing that needs
  elevated rights, and nothing that runs another program.  Files under /proc
  and /sys, a few registry values on Windows, and what the toolkit already
  knows.  Every probe is wrapped so that a machine that will not answer one
  question still answers the rest. }

{$mode objfpc}{$H+}

interface

{ the machine and the toolkit, one fact per line }
function SystemFacts: string;
{ what the program itself is using right now, one line }
function ProgramMemory: string;

implementation

uses
  Classes, SysUtils, StrUtils, Forms, InterfaceBase, LCLVersion, dynlibs
  {$IFDEF WINDOWS}, Windows, Registry{$ENDIF}
  {$IFDEF UNIX}, BaseUnix{$ENDIF};

function MB(Bytes: Int64): string;
begin
  if Bytes >= 10 * 1024 * 1024 * 1024 then
    Result := Format('%.0f GB', [Bytes / 1024 / 1024 / 1024])
  else if Bytes >= 1024 * 1024 * 1024 then
    Result := Format('%.1f GB', [Bytes / 1024 / 1024 / 1024])
  else
    Result := Format('%.0f MB', [Bytes / 1024 / 1024]);
end;

{ a small text file, or nothing }
function ReadSmall(const Path: string): string;
var
  L: TStringList;
begin
  Result := '';
  if not FileExists(Path) then Exit;
  L := TStringList.Create;
  try
    try
      L.LoadFromFile(Path);
      Result := L.Text;
    except
    end;
  finally
    L.Free;
  end;
end;

{ the value after "Key:" or "Key=" on its line, or nothing }
function FieldOf(const Text, Key: string): string;
var
  L: TStringList;
  I, P: Integer;
  S: string;
begin
  Result := '';
  L := TStringList.Create;
  try
    L.Text := Text;
    for I := 0 to L.Count - 1 do
    begin
      S := L[I];
      if (Copy(S, 1, Length(Key)) = Key) and (Length(S) > Length(Key)) and
         (S[Length(Key) + 1] in [':', '=', ' ', #9]) then
      begin
        P := Length(Key) + 1;
        while (P <= Length(S)) and (S[P] in [':', '=', ' ', #9]) do Inc(P);
        Result := Trim(Copy(S, P, MaxInt));
        if (Length(Result) >= 2) and (Result[1] = '"') and (Result[Length(Result)] = '"') then
          Result := Copy(Result, 2, Length(Result) - 2);
        Exit;
      end;
    end;
  finally
    L.Free;
  end;
end;

{ "16384 kB" -> bytes }
function KBOf(const S: string): Int64;
var
  T: string;
begin
  T := Trim(S);
  if EndsText('kB', T) then T := Trim(Copy(T, 1, Length(T) - 2));
  Result := StrToInt64Def(T, 0) * 1024;
end;

{$IFDEF UNIX}
function OSLine: string;
var
  U: UtsName;
  Rel: string;
begin
  Result := FieldOf(ReadSmall('/etc/os-release'), 'PRETTY_NAME');
  if Result = '' then Result := 'Linux';
  FillChar(U, SizeOf(U), 0);
  if fpUname(U) = 0 then
  begin
    Rel := PChar(@U.Release[0]);
    if Rel <> '' then Result := Result + ', kernel ' + Rel;
  end;
end;

function MachineLine: string;
var
  V, P: string;
begin
  V := Trim(ReadSmall('/sys/class/dmi/id/sys_vendor'));
  P := Trim(ReadSmall('/sys/class/dmi/id/product_name'));
  Result := Trim(V + ' ' + P);
end;

function CPULine: string;
begin
  Result := FieldOf(ReadSmall('/proc/cpuinfo'), 'model name');
  if Result = '' then Result := FieldOf(ReadSmall('/proc/cpuinfo'), 'Hardware');
  if Result = '' then Result := 'unknown processor';
end;

function RAMLine: string;
var
  M: string;
  Total, Avail: Int64;
begin
  M := ReadSmall('/proc/meminfo');
  Total := KBOf(FieldOf(M, 'MemTotal'));
  Avail := KBOf(FieldOf(M, 'MemAvailable'));
  if Total = 0 then Exit('unknown');
  Result := MB(Total) + ', ' + MB(Avail) + ' free';
end;

function GraphicsLine: string;
var
  I: Integer;
  Card, Drv, Id, Seen: string;
  GL: TLibHandle;
begin
  Seen := '';
  for I := 0 to 7 do
  begin
    Card := Format('/sys/class/drm/card%d/device/uevent', [I]);
    if not FileExists(Card) then Continue;
    Drv := FieldOf(ReadSmall(Card), 'DRIVER');
    Id := FieldOf(ReadSmall(Card), 'PCI_ID');
    if Drv = '' then Continue;
    if Id <> '' then Drv := Drv + ' (' + Id + ')';
    if Pos(Drv, Seen) > 0 then Continue;
    if Seen <> '' then Seen := Seen + ', ';
    Seen := Seen + Drv;
  end;
  if Seen = '' then Seen := 'no graphics driver found under /sys';
  Result := Seen;
  { is there an OpenGL to be had at all, should the program ever want it }
  GL := LoadLibrary('libGL.so.1');
  if GL <> NilHandle then
  begin
    Result := Result + '; OpenGL library present';
    UnloadLibrary(GL);
  end
  else
    Result := Result + '; no OpenGL library';
  if SysUtils.GetEnvironmentVariable('WAYLAND_DISPLAY') <> '' then
    Result := Result + '; wayland session'
  else if SysUtils.GetEnvironmentVariable('DISPLAY') <> '' then
    Result := Result + '; x11 session';
end;

function ResidentLine: string;
var
  S: string;
begin
  S := ReadSmall('/proc/self/status');
  Result := MB(KBOf(FieldOf(S, 'VmRSS'))) + ' resident, peak ' + MB(KBOf(FieldOf(S, 'VmHWM')));
end;
{$ENDIF}

{$IFDEF WINDOWS}
type
  TOSVersionInfoExW = record
    dwOSVersionInfoSize, dwMajorVersion, dwMinorVersion, dwBuildNumber, dwPlatformId: DWORD;
    szCSDVersion: array[0..127] of WideChar;
    wServicePackMajor, wServicePackMinor, wSuiteMask: Word;
    wProductType, wReserved: Byte;
  end;
  TRtlGetVersion = function(var Info: TOSVersionInfoExW): LongInt; stdcall;
  TMemoryStatusEx = record
    dwLength, dwMemoryLoad: DWORD;
    ullTotalPhys, ullAvailPhys, ullTotalPageFile, ullAvailPageFile,
    ullTotalVirtual, ullAvailVirtual, ullAvailExtendedVirtual: QWord;
  end;
  TGlobalMemoryStatusEx = function(var M: TMemoryStatusEx): BOOL; stdcall;
  TProcessMemoryCounters = record
    cb, PageFaultCount: DWORD;
    PeakWorkingSetSize, WorkingSetSize, QuotaPeakPagedPoolUsage,
    QuotaPagedPoolUsage, QuotaPeakNonPagedPoolUsage, QuotaNonPagedPoolUsage,
    PagefileUsage, PeakPagefileUsage: SIZE_T;
  end;
  TGetProcessMemoryInfo = function(H: THandle; var C: TProcessMemoryCounters; cb: DWORD): BOOL; stdcall;
  TDisplayDeviceW = record
    cb: DWORD;
    DeviceName: array[0..31] of WideChar;
    DeviceString: array[0..127] of WideChar;
    StateFlags: DWORD;
    DeviceID: array[0..127] of WideChar;
    DeviceKey: array[0..127] of WideChar;
  end;
  TEnumDisplayDevicesW = function(Dev: PWideChar; Num: DWORD; var D: TDisplayDeviceW; Flags: DWORD): BOOL; stdcall;

function RegString(const Key, Name: string): string;
var
  R: TRegistry;
begin
  Result := '';
  R := TRegistry.Create(KEY_READ);
  try
    R.RootKey := HKEY_LOCAL_MACHINE;
    if R.OpenKeyReadOnly(Key) and R.ValueExists(Name) then
      Result := Trim(R.ReadString(Name));
  finally
    R.Free;
  end;
end;

function OSLine: string;
var
  H: TLibHandle;
  F: TRtlGetVersion;
  V: TOSVersionInfoExW;
begin
  Result := 'Windows';
  H := LoadLibrary('ntdll.dll');
  if H = NilHandle then Exit;
  try
    F := TRtlGetVersion(GetProcAddress(H, 'RtlGetVersion'));
    if not Assigned(F) then Exit;
    FillChar(V, SizeOf(V), 0);
    V.dwOSVersionInfoSize := SizeOf(V);
    if F(V) <> 0 then Exit;
    Result := Format('Windows %d.%d build %d', [V.dwMajorVersion, V.dwMinorVersion, V.dwBuildNumber]);
    if (V.dwMajorVersion = 10) and (V.dwBuildNumber >= 22000) then Result := Result + ' (Windows 11)';
    if V.wProductType <> 1 then Result := Result + ', server';
  finally
    UnloadLibrary(H);
  end;
end;

function MachineLine: string;
begin
  Result := Trim(RegString('HARDWARE\DESCRIPTION\System\BIOS', 'SystemManufacturer') + ' ' +
    RegString('HARDWARE\DESCRIPTION\System\BIOS', 'SystemProductName'));
end;

function CPULine: string;
begin
  Result := RegString('HARDWARE\DESCRIPTION\System\CentralProcessor\0', 'ProcessorNameString');
  if Result = '' then Result := 'unknown processor';
end;

function RAMLine: string;
var
  M: TMemoryStatusEx;
  H: TLibHandle;
  F: TGlobalMemoryStatusEx;
begin
  Result := 'unknown';
  H := LoadLibrary('kernel32.dll');
  if H = NilHandle then Exit;
  try
    F := TGlobalMemoryStatusEx(GetProcAddress(H, 'GlobalMemoryStatusEx'));
    if not Assigned(F) then Exit;
    FillChar(M, SizeOf(M), 0);
    M.dwLength := SizeOf(M);
    if F(M) then Result := MB(M.ullTotalPhys) + ', ' + MB(M.ullAvailPhys) + ' free';
  finally
    UnloadLibrary(H);
  end;
end;

function GraphicsLine: string;
var
  H: TLibHandle;
  F: TEnumDisplayDevicesW;
  D: TDisplayDeviceW;
  I: Integer;
  S: string;
begin
  Result := '';
  H := LoadLibrary('user32.dll');
  if H <> NilHandle then
  try
    F := TEnumDisplayDevicesW(GetProcAddress(H, 'EnumDisplayDevicesW'));
    if Assigned(F) then
      for I := 0 to 7 do
      begin
        FillChar(D, SizeOf(D), 0);
        D.cb := SizeOf(D);
        if not F(nil, I, D, 0) then Break;
        S := Trim(UTF8Encode(WideString(PWideChar(@D.DeviceString[0]))));
        if (S = '') or (Pos(S, Result) > 0) then Continue;
        if Result <> '' then Result := Result + ', ';
        Result := Result + S;
      end;
  finally
    UnloadLibrary(H);
  end;
  if Result = '' then Result := 'no display adapter reported';
end;

function ResidentLine: string;
var
  H: TLibHandle;
  F: TGetProcessMemoryInfo;
  C: TProcessMemoryCounters;
begin
  Result := 'unknown';
  H := LoadLibrary('psapi.dll');
  if H = NilHandle then Exit;
  try
    F := TGetProcessMemoryInfo(GetProcAddress(H, 'GetProcessMemoryInfo'));
    if not Assigned(F) then Exit;
    FillChar(C, SizeOf(C), 0);
    C.cb := SizeOf(C);
    if F(GetCurrentProcess, C, SizeOf(C)) then
      Result := MB(C.WorkingSetSize) + ' resident, peak ' + MB(C.PeakWorkingSetSize);
  finally
    UnloadLibrary(H);
  end;
end;
{$ENDIF}

{$IF NOT DEFINED(UNIX) AND NOT DEFINED(WINDOWS)}
function OSLine: string; begin Result := {$I %FPCTARGETOS%}; end;
function MachineLine: string; begin Result := ''; end;
function CPULine: string; begin Result := 'unknown processor'; end;
function RAMLine: string; begin Result := 'unknown'; end;
function GraphicsLine: string; begin Result := 'unknown'; end;
function ResidentLine: string; begin Result := 'unknown'; end;
{$ENDIF}

type
  TFact = function: string;

function Safely(F: TFact): string;
begin
  try
    Result := F();
  except
    on E: Exception do Result := 'could not tell (' + E.ClassName + ')';
  end;
end;

function DisplayLine: string;
begin
  Result := Format('%dx%d at %d dpi', [Screen.Width, Screen.Height, Screen.PixelsPerInch]);
  if Screen.MonitorCount > 1 then Result := Result + Format(', %d monitors', [Screen.MonitorCount]);
end;

function ToolkitLine: string;
begin
  Result := GetLCLWidgetTypeName + ', LCL ' + lcl_version +
    ', FPC ' + {$I %FPCVERSION%} + ', ' + {$I %FPCTARGETCPU%} + '-' + {$I %FPCTARGETOS%};
end;

function LocaleLine: string;
var
  Lang: string;
begin
  Result := 'decimal ''' + DefaultFormatSettings.DecimalSeparator + '''';
  Lang := SysUtils.GetEnvironmentVariable('LANG');
  if Lang <> '' then Result := Result + ', LANG ' + Lang;
end;

function SystemFacts: string;
var
  M: string;
begin
  Result := 'os: ' + Safely(@OSLine) + LineEnding;
  M := Safely(@MachineLine);
  if M <> '' then Result := Result + 'machine: ' + M + LineEnding;
  Result := Result +
    'cpu: ' + Safely(@CPULine) + Format(' (%d cores)', [TThread.ProcessorCount]) + LineEnding +
    'ram: ' + Safely(@RAMLine) + LineEnding +
    'graphics: ' + Safely(@GraphicsLine) + LineEnding +
    'display: ' + Safely(@DisplayLine) + LineEnding +
    'toolkit: ' + Safely(@ToolkitLine) + LineEnding +
    'locale: ' + Safely(@LocaleLine) + LineEnding;
end;

function ProgramMemory: string;
var
  H: TFPCHeapStatus;
begin
  H := GetFPCHeapStatus;
  Result := Safely(@ResidentLine) + '; heap ' + MB(H.CurrHeapUsed) + ' in use, peak ' + MB(H.MaxHeapUsed);
end;

end.
