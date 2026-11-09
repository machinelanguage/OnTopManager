program CPUWatchTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  uCPUWatch in '..\uCPUWatch.pas';

var
  S: TCPUState;
  CPU, Tick: UInt64;
  Percent: Double;
  I: Integer;

procedure Check(OK: Boolean; const Description: string);
begin
  if not OK then
    raise Exception.Create(Description);
end;

procedure Reset;
begin
  FillChar(S, SizeOf(S), 0);
  CPU := 0;
  Tick := 1000;
  Check(not AdvanceCPUState(S, 1, CPU, Tick, 8, 5, 30000, Percent),
    'Baseline must not alert');
end;

function Step(Usage: Integer; Elapsed: Integer = 1000;
  Creation: UInt64 = 1): Boolean;
begin
  Tick := Tick + UInt64(Elapsed);
  // Synthetic 8-processor sample, in Windows 100 ns CPU-time units.
  CPU := CPU + UInt64(Usage) * UInt64(Elapsed) * 800;
  Result := AdvanceCPUState(S, Creation, CPU, Tick, 8, 5, 30000, Percent);
end;

begin
  try
    Reset;
    for I := 1 to 29 do
      Check(not Step(5), 'Exact threshold must wait for full duration');
    Check(S.HighMS = 29000, '29 seconds are not 30 seconds');
    Check(Step(5), '30 continuous seconds at exactly 5% must alert');
    for I := 1 to 60 do
      Check(not Step(80), 'One alert per continuous high episode');
    Check(not Step(4), 'Low sample rearms without alerting');
    for I := 1 to 29 do
      Check(not Step(6), 'Rearmed episode must wait again');
    Check(Step(6), 'New full episode must alert');

    Reset;
    for I := 1 to 60 do
    begin
      Check(not Step(100), 'One-second spike must not alert');
      Check(not Step(0), 'Spike followed by idle must reset');
    end;

    Reset;
    for I := 1 to 29 do
      Check(not Step(50), 'Pre-gap duration must not alert');
    Check(not Step(50, 10000), 'Sleep/missing samples must break continuity');
    Check(S.HighMS = 0, 'Sampling gap must reset duration');

    Reset;
    for I := 1 to 29 do
      Check(not Step(50), 'Pre-reuse duration must not alert');
    Check(not Step(50, 1000, 2), 'Reused PID must receive a new baseline');
    Check(S.HighMS = 0, 'PID reuse must reset duration');

    Reset;
    CPU := 10000000; // One full CPU-second on eight logical processors.
    Tick := 2000;
    Check(not AdvanceCPUState(S, 1, CPU, Tick, 8, 5, 30000, Percent),
      'One sample must not alert');
    Check(Abs(Percent - 12.5) < 0.0001, 'CPU must use whole-machine capacity');
    CPU := 1;
    Tick := 3000;
    Check(not AdvanceCPUState(S, 1, CPU, Tick, 8, 5, 30000, Percent),
      'Counter rollback must not alert');
    Check(S.HighMS = 0, 'Counter rollback must reset duration');

    Reset;
    for I := 1 to 19 do
    begin
      Tick := Tick + 1000;
      CPU := CPU + 8000000;
      Check(not AdvanceCPUState(S, 1, CPU, Tick, 8, 5, 20000, Percent),
        '20 second configuration must wait for duration');
    end;
    Tick := Tick + 1000;
    CPU := CPU + 8000000;
    Check(AdvanceCPUState(S, 1, CPU, Tick, 8, 5, 20000, Percent),
      '20 second configuration must alert at its own boundary');
    Writeln('PASS: sustained CPU regression scenarios');
  except
    on E: Exception do
    begin
      Writeln('FAIL: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
