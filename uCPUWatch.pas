unit uCPUWatch;

interface

uses
  Winapi.Windows, System.Classes, System.SysUtils, System.SyncObjs,
  System.Generics.Collections;

type
  TCPUAlert = record
    PID: DWORD;
    CreatedAt: UInt64;
    ExeName: string;
    CPUPercent: Double;
    AveragePercent: Double;
    DurationMS: UInt64;
  end;

  TCPUState = record
    CreatedAt, LastCPU, LastTick, HighMS, HighCPU, SeenCycle: UInt64;
    Alerted: Boolean;
  end;

  TCPUWatchThread = class(TThread)
  private
    FStop: TEvent;
    FLock: TCriticalSection;
    FStates: TDictionary<DWORD, TCPUState>;
    FAlerts: TList<TCPUAlert>;
    FThreshold: Double;
    FDurationMS: UInt64;
    FProcessorCount: DWORD;
    FCycle: UInt64;
    procedure Sample;
    procedure SampleProcess(PID: DWORD; const ExeName: string);
  protected
    procedure Execute; override;
  public
    constructor Create(AThreshold: Double; ADurationSeconds: Integer);
    destructor Destroy; override;
    procedure DrainAlerts(AList: TList<TCPUAlert>);
  end;

function CPUFileTimeValue(const Value: TFileTime): UInt64;
function AdvanceCPUState(var S: TCPUState; CreationValue, CPU, Tick: UInt64;
  ProcessorCount: DWORD; Threshold: Double; DurationMS: UInt64;
  out Percent: Double): Boolean;

implementation

uses
  Winapi.TlHelp32;

function AllProcessorCount(GroupNumber: Word): DWORD; stdcall;
  external 'kernel32.dll' name 'GetActiveProcessorCount';

function CPUFileTimeValue(const Value: TFileTime): UInt64;
begin
  Result := (UInt64(Value.dwHighDateTime) shl 32) or Value.dwLowDateTime;
end;

function AdvanceCPUState(var S: TCPUState; CreationValue, CPU, Tick: UInt64;
  ProcessorCount: DWORD; Threshold: Double; DurationMS: UInt64;
  out Percent: Double): Boolean;
var
  Elapsed, DeltaCPU: UInt64;
begin
  Result := False;
  Percent := 0;
  if ProcessorCount = 0 then
    ProcessorCount := 1;
  if (S.CreatedAt <> CreationValue) or (S.LastTick = 0) or
    (Tick <= S.LastTick) or (Tick - S.LastTick > 3000) or (CPU < S.LastCPU) then
  begin
    FillChar(S, SizeOf(S), 0);
    S.CreatedAt := CreationValue;
  end
  else
  begin
    Elapsed := Tick - S.LastTick;
    DeltaCPU := CPU - S.LastCPU;
    Percent := 100.0 * DeltaCPU / (Elapsed * 10000.0 * ProcessorCount);
    if Percent >= Threshold then
    begin
      S.HighMS := S.HighMS + Elapsed;
      S.HighCPU := S.HighCPU + DeltaCPU;
      if (S.HighMS >= DurationMS) and not S.Alerted then
      begin
        S.Alerted := True;
        Result := True;
      end;
    end
    else
    begin
      S.HighMS := 0;
      S.HighCPU := 0;
      S.Alerted := False;
    end;
  end;
  S.LastCPU := CPU;
  S.LastTick := Tick;
end;

constructor TCPUWatchThread.Create(AThreshold: Double; ADurationSeconds: Integer);
begin
  // Delphi starts Execute from AfterConstruction, after all fields are ready.
  inherited Create(False);
  FreeOnTerminate := False;
  FStop := TEvent.Create(nil, True, False, '');
  FLock := TCriticalSection.Create;
  FStates := TDictionary<DWORD, TCPUState>.Create;
  FAlerts := TList<TCPUAlert>.Create;
  FThreshold := AThreshold;
  FDurationMS := UInt64(ADurationSeconds) * 1000;
  FProcessorCount := AllProcessorCount($FFFF);
  if FProcessorCount = 0 then
    FProcessorCount := 1;
end;

destructor TCPUWatchThread.Destroy;
begin
  Terminate;
  if FStop <> nil then
    FStop.SetEvent;
  // TThread.Destroy terminates/joins the worker and handles partial construction.
  // Keep all worker-owned objects alive until that join has completed.
  inherited Destroy;
  FAlerts.Free;
  FStates.Free;
  FLock.Free;
  FStop.Free;
end;

procedure TCPUWatchThread.DrainAlerts(AList: TList<TCPUAlert>);
var
  Alert: TCPUAlert;
begin
  FLock.Acquire;
  try
    for Alert in FAlerts do
      AList.Add(Alert);
    FAlerts.Clear;
  finally
    FLock.Release;
  end;
end;

procedure TCPUWatchThread.SampleProcess(PID: DWORD; const ExeName: string);
const
  QueryLimitedInformation = $1000;
var
  Proc: THandle;
  Created, Exited, Kernel, UserTime: TFileTime;
  S: TCPUState;
  CreationValue, CPU, Tick: UInt64;
  Percent: Double;
  Alert: TCPUAlert;
begin
  // PID 0 is idle time; the manager itself must not cause an alert feedback loop.
  if (PID = 0) or (PID = GetCurrentProcessId) then
    Exit;
  Proc := OpenProcess(QueryLimitedInformation, False, PID);
  if Proc = 0 then
    Exit; // inaccessible processes are not measured as 0% or assumed high
  try
    if not GetProcessTimes(Proc, Created, Exited, Kernel, UserTime) then
      Exit;
  finally
    CloseHandle(Proc);
  end;
  Tick := GetTickCount64;
  CreationValue := CPUFileTimeValue(Created);
  CPU := CPUFileTimeValue(Kernel) + CPUFileTimeValue(UserTime);
  if not FStates.TryGetValue(PID, S) then
    FillChar(S, SizeOf(S), 0);
  if AdvanceCPUState(S, CreationValue, CPU, Tick, FProcessorCount,
    FThreshold, FDurationMS, Percent) then
  begin
    Alert.PID := PID;
    Alert.CreatedAt := CreationValue;
    Alert.ExeName := ExeName;
    Alert.CPUPercent := Percent;
    Alert.AveragePercent := 100.0 * S.HighCPU /
      (S.HighMS * 10000.0 * FProcessorCount);
    Alert.DurationMS := S.HighMS;
    FLock.Acquire;
    try
      if FAlerts.Count < 256 then
        FAlerts.Add(Alert);
    finally
      FLock.Release;
    end;
  end;
  S.SeenCycle := FCycle;
  FStates.AddOrSetValue(PID, S);
end;

procedure TCPUWatchThread.Sample;
var
  Snapshot: THandle;
  Entry: TProcessEntry32;
  Pair: TPair<DWORD, TCPUState>;
  Removed: TList<DWORD>;
  PID: DWORD;
begin
  Inc(FCycle);
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snapshot = INVALID_HANDLE_VALUE then
  begin
    FStates.Clear;
    Exit;
  end;
  try
    FillChar(Entry, SizeOf(Entry), 0);
    Entry.dwSize := SizeOf(Entry);
    if Process32First(Snapshot, Entry) then
      repeat
        if Terminated then
          Exit;
        SampleProcess(Entry.th32ProcessID, string(Entry.szExeFile));
      until not Process32Next(Snapshot, Entry);
  finally
    CloseHandle(Snapshot);
  end;
  Removed := TList<DWORD>.Create;
  try
    for Pair in FStates do
      if Pair.Value.SeenCycle <> FCycle then
        Removed.Add(Pair.Key);
    for PID in Removed do
      FStates.Remove(PID);
  finally
    Removed.Free;
  end;
end;

procedure TCPUWatchThread.Execute;
begin
  while not Terminated do
  begin
    try
      Sample;
    except
      // A failed/missing sample must never count as continuous high CPU.
      FStates.Clear;
    end;
    if FStop.WaitFor(1000) <> wrTimeout then
      Break;
  end;
end;

end.
