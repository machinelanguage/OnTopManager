program CPUThreadLifetimeTests;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils,
  uCPUWatch in '..\uCPUWatch.pas';

var
  Worker: TCPUWatchThread;
  I: Integer;
begin
  try
    // Exercise immediate destruction and rapid reconfiguration without Start calls.
    for I := 1 to 50 do
    begin
      Worker := TCPUWatchThread.Create(5, 30);
      Worker.Free;
    end;
    Worker := TCPUWatchThread.Create(5, 20);
    try
      Sleep(2500); // Exercise destruction after real sampling has begun.
    finally
      Worker.Free;
    end;
    Writeln('PASS: repeated, immediate and active worker cleanup');
  except
    on E: Exception do
    begin
      Writeln('FAIL: ' + E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
