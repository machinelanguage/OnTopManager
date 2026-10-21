program OnTopManager;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {frmMain};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'OnTop Manager';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
