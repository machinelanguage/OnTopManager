program OnTopManager;

uses
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Forms,
  uMain in 'uMain.pas' {frmMain};

{$R *.res}

var
  Mutex: THandle;

begin
  // Uygulamanin ayni anda birden fazla kopyasinin calismasini engelle:
  // isimli mutex zaten varsa, mevcut pencereye odaklanip cik.
  Mutex := CreateMutex(nil, True, 'OnTopManager_SingleInstance_Mutex');
  if (Mutex = 0) or (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    if Mutex <> 0 then
      CloseHandle(Mutex);
    if MessageBox(0,
       'OnTop Manager zaten calisiyor.'#13#10'Mevcut pencere one getirilecek.',
       'OnTop Manager', MB_OK or MB_ICONINFORMATION) = IDOK then
    begin
      // Calisan kopyanin ana penceresini bulup one getir
      EnumWindows(@uMain.ActivateExistingWindow, 0);
    end;
    Halt;
  end;

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'OnTop Manager';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;

  if Mutex <> 0 then
    CloseHandle(Mutex);
end.
