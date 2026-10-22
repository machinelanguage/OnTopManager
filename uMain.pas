unit uMain;

{
  OnTop Manager
  -------------
  Calisan uygulama pencerelerini listeler, secilen pencereyi "Her Zaman Ustte"
  (TOPMOST) yapmayi/kaldirmayi saglar. Ontop yapilan uygulamalar calistirilabilir
  dosya adina (exe adina) gore bir INI dosyasinda hatirlanir; program bir sonraki
  acilista veya ilgili uygulama sonradan baslatildiginda bu pencereleri otomatik
  olarak tekrar ontop yapar.

  Delphi 10.4 (Sydney) VCL Forms Application icin yazilmistir.
}

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.PsAPI, Winapi.ShellAPI,
  System.SysUtils, System.Variants, System.Classes, System.IniFiles,
  System.Generics.Collections, System.Generics.Defaults, System.DateUtils,
  System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus;

type
  TWindowInfo = record
    Handle: HWND;
    PID: DWORD;
    ExeName: string;   // orn: notepad.exe
    Title: string;
    IsTopMost: Boolean;
    StartTime: TDateTime; // ilgili sürecin baslangic tarihi/saati
  end;

  TfrmMain = class(TForm)
    PanelTop: TPanel;
    btnRefresh: TButton;
    btnToggleOnTop: TButton;
    ListViewApps: TListView;
    TimerRefresh: TTimer;
    StatusBar1: TStatusBar;
    TrayIcon1: TTrayIcon;
    PopupMenuTray: TPopupMenu;
    miShow: TMenuItem;
    miExit: TMenuItem;
    lblInfo: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnToggleOnTopClick(Sender: TObject);
    procedure TimerRefreshTimer(Sender: TObject);
    procedure ListViewAppsDblClick(Sender: TObject);
    procedure miShowClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure TrayIcon1DblClick(Sender: TObject);
    procedure ListViewAppsColumnClick(Sender: TObject; Column: TListColumn);
  private
    FWindows: TList<TWindowInfo>;
    FRemembered: TStringList;     // hatirlanan exe adlari (kucuk harf)
    FIniPath: string;
    FClosing: Boolean;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    procedure WMSysCommand(var Msg: TWMSysCommand); message WM_SYSCOMMAND;
    procedure EnumRunningWindows;
    procedure LoadSettings;
    procedure SaveSettings;
    procedure ApplyTopMost(AHandle: HWND; ATopMost: Boolean);
    procedure RefreshListView;
    procedure AutoApplyRemembered;
    procedure UpdateStatusBar;
    procedure SortWindowList;
    procedure UpdateColumnHeaders;
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

{ ---------------------------------------------------------------------------
  Yardimci fonksiyonlar
  --------------------------------------------------------------------------- }

const
  PROCESS_QUERY_LIMITED_INFORMATION = $1000; // Winapi.Windows'ta tanimli degil (10.4)

// Winapi.Windows (10.4) icinde deklare edilmemis; kernel32.dll'den dogrudan import
function QueryFullProcessImageName(hProcess: THandle; dwFlags: DWORD;
  lpExeName: PChar; var lpdwSize: DWORD): BOOL; stdcall;
  external kernel32 name 'QueryFullProcessImageNameW';

function GetExeNameFromPID(APID: DWORD): string;
var
  hProc: THandle;
  Buf: array[0..MAX_PATH] of Char;
  Size: DWORD;
begin
  Result := '';
  hProc := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, APID);
  if hProc = 0 then
    hProc := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, APID);
  if hProc = 0 then
    Exit;
  try
    Size := MAX_PATH;
    FillChar(Buf, SizeOf(Buf), 0);
    if QueryFullProcessImageName(hProc, 0, Buf, Size) then
      Result := ExtractFileName(string(Buf))
    else
    begin
      Size := GetModuleFileNameEx(hProc, 0, Buf, MAX_PATH);
      if Size > 0 then
        Result := ExtractFileName(string(Buf));
    end;
  finally
    CloseHandle(hProc);
  end;
end;

function GetProcessStartTime(APID: DWORD): TDateTime;
var
  hProc: THandle;
  CreationTime, ExitTime, KernelTime, UserTime, LocalFT: TFileTime;
  SysTime: TSystemTime;
begin
  Result := 0;
  hProc := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, APID);
  if hProc = 0 then
    hProc := OpenProcess(PROCESS_QUERY_INFORMATION, False, APID);
  if hProc = 0 then
    Exit;
  try
    if GetProcessTimes(hProc, CreationTime, ExitTime, KernelTime, UserTime) then
    begin
      FileTimeToLocalFileTime(CreationTime, LocalFT);
      FileTimeToSystemTime(LocalFT, SysTime);
      Result := SystemTimeToDateTime(SysTime);
    end;
  finally
    CloseHandle(hProc);
  end;
end;

type
  PEnumContext = ^TEnumContext;
  TEnumContext = record
    List: TList<TWindowInfo>;
    SelfPID: DWORD;
  end;

function EnumWindowsProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Ctx: PEnumContext;
  Info: TWindowInfo;
  PID: DWORD;
  TitleBuf: array[0..255] of Char;
  ExStyle: NativeInt;
begin
  Result := True; // enum devam etsin

  if not IsWindowVisible(Wnd) then
    Exit;
  if GetWindowTextLength(Wnd) = 0 then
    Exit;
  // Sadece gercek ust seviye (owner'i olmayan) pencereleri al
  if GetWindow(Wnd, GW_OWNER) <> 0 then
    Exit;

  ExStyle := GetWindowLong(Wnd, GWL_EXSTYLE);
  if (ExStyle and WS_EX_TOOLWINDOW) <> 0 then
    Exit;

  Ctx := PEnumContext(Pointer(LParam));

  GetWindowThreadProcessId(Wnd, PID);
  if PID = Ctx^.SelfPID then
    Exit; // kendi uygulamamizi listeleme

  FillChar(TitleBuf, SizeOf(TitleBuf), 0);
  GetWindowText(Wnd, TitleBuf, Length(TitleBuf));

  Info.Handle := Wnd;
  Info.PID := PID;
  Info.Title := TitleBuf;
  Info.ExeName := GetExeNameFromPID(PID);
  Info.IsTopMost := (ExStyle and WS_EX_TOPMOST) <> 0;
  Info.StartTime := GetProcessStartTime(PID);

  if Info.ExeName = '' then
    Exit;

  Ctx^.List.Add(Info);
end;

{ ---------------------------------------------------------------------------
  TfrmMain
  --------------------------------------------------------------------------- }

procedure TfrmMain.FormCreate(Sender: TObject);
var
  AppDataDir: string;
begin
  FWindows := TList<TWindowInfo>.Create;
  FRemembered := TStringList.Create;
  FRemembered.Duplicates := dupIgnore;
  FRemembered.Sorted := True;
  FClosing := False;

  AppDataDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) + 'OnTopManager';
  ForceDirectories(AppDataDir);
  FIniPath := IncludeTrailingPathDelimiter(AppDataDir) + 'settings.ini';

  ListViewApps.ViewStyle := vsReport;
  ListViewApps.RowSelect := True;
  ListViewApps.ReadOnly := True;
  ListViewApps.Columns.Clear;
  with ListViewApps.Columns.Add do begin Caption := 'Ontop'; Width := 60; end;
  with ListViewApps.Columns.Add do begin Caption := 'Uygulama (EXE)'; Width := 160; end;
  with ListViewApps.Columns.Add do begin Caption := 'Pencere Basligi'; Width := 260; end;
  with ListViewApps.Columns.Add do begin Caption := 'PID'; Width := 70; end;
  with ListViewApps.Columns.Add do begin Caption := 'Baslangic Tarihi'; Width := 140; end;

  FSortColumn := -1;
  FSortAscending := True;

  // Sistem tepsisi (tray) simgesi: uygulamanin kendi ikonu kullanilir
  TrayIcon1.Icon.Assign(Application.Icon);
  if TrayIcon1.Icon.Empty then
    TrayIcon1.Icon.Handle := LoadIcon(0, IDI_APPLICATION);
  TrayIcon1.Hint := 'OnTop Manager';

  LoadSettings;
  RefreshListView;

  TimerRefresh.Enabled := False; // liste otomatik yenilenmesin, sadece manuel/F5
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FWindows.Free;
  FRemembered.Free;
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if FClosing then
    Action := caFree
  else
  begin
    // Kapat (X) butonuna basinca sistem tepsisine kucult, uygulama acik kalsin
    Action := caNone;
    Hide;
    TrayIcon1.Visible := True;
  end;
end;

procedure TfrmMain.WMSysCommand(var Msg: TWMSysCommand);
begin
  // Baslik cubugundaki "Simge durumuna kucult" (asagi ok) tiklaninca
  // pencereyi gormez kil, sistem tepsisine yerlestir.
  if (Msg.CmdType and $FFF0) = SC_MINIMIZE then
  begin
    Hide;
    TrayIcon1.Visible := True;
  end
  else
    inherited;
end;

procedure TfrmMain.miShowClick(Sender: TObject);
begin
  Show;
  WindowState := wsNormal;
  Application.BringToFront;
end;

procedure TfrmMain.TrayIcon1DblClick(Sender: TObject);
begin
  miShowClick(Sender);
end;

procedure TfrmMain.miExitClick(Sender: TObject);
begin
  FClosing := True;
  TrayIcon1.Visible := False;
  Close;
end;

{ ---------------------------------------------------------------------------
  Ayarlarin (hatirlanan exe listesi) yuklenmesi / kaydedilmesi
  --------------------------------------------------------------------------- }

procedure TfrmMain.LoadSettings;
var
  Ini: TIniFile;
  Keys: TStringList;
  I: Integer;
begin
  FRemembered.Clear;
  if not FileExists(FIniPath) then
    Exit;
  Ini := TIniFile.Create(FIniPath);
  Keys := TStringList.Create;
  try
    Ini.ReadSection('OnTop', Keys);
    for I := 0 to Keys.Count - 1 do
      if Ini.ReadBool('OnTop', Keys[I], False) then
        FRemembered.Add(LowerCase(Keys[I]));
  finally
    Keys.Free;
    Ini.Free;
  end;
end;

procedure TfrmMain.SaveSettings;
var
  Ini: TIniFile;
  I: Integer;
begin
  Ini := TIniFile.Create(FIniPath);
  try
    Ini.EraseSection('OnTop');
    for I := 0 to FRemembered.Count - 1 do
      Ini.WriteBool('OnTop', FRemembered[I], True);
  finally
    Ini.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  Pencere listesi ve ontop islemleri
  --------------------------------------------------------------------------- }

procedure TfrmMain.EnumRunningWindows;
var
  Ctx: TEnumContext;
begin
  FWindows.Clear;
  Ctx.List := FWindows;
  Ctx.SelfPID := GetCurrentProcessId;
  EnumWindows(@EnumWindowsProc, LPARAM(@Ctx));
end;

procedure TfrmMain.ApplyTopMost(AHandle: HWND; ATopMost: Boolean);
const
  Flags = SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE;
var
  InsertAfter: HWND;
begin
  if ATopMost then
    InsertAfter := HWND_TOPMOST
  else
    InsertAfter := HWND_NOTOPMOST;
  SetWindowPos(AHandle, InsertAfter, 0, 0, 0, 0, Flags);
end;

procedure TfrmMain.AutoApplyRemembered;
var
  I: Integer;
  Info: TWindowInfo;
begin
  if FRemembered.Count = 0 then
    Exit;
  for I := 0 to FWindows.Count - 1 do
  begin
    Info := FWindows[I];
    if (not Info.IsTopMost) and (FRemembered.IndexOf(LowerCase(Info.ExeName)) >= 0) then
    begin
      ApplyTopMost(Info.Handle, True);
      Info.IsTopMost := True;
      FWindows[I] := Info;
    end;
  end;
end;

procedure TfrmMain.RefreshListView;
var
  I: Integer;
  Info: TWindowInfo;
  Item: TListItem;
  SelHandle: HWND;
begin
  SelHandle := 0;
  if Assigned(ListViewApps.Selected) then
    SelHandle := HWND(ListViewApps.Selected.Data);

  EnumRunningWindows;
  AutoApplyRemembered;
  SortWindowList;

  ListViewApps.Items.BeginUpdate;
  try
    ListViewApps.Items.Clear;
    for I := 0 to FWindows.Count - 1 do
    begin
      Info := FWindows[I];
      Item := ListViewApps.Items.Add;
      if Info.IsTopMost then
        Item.Caption := 'Evet'
      else
        Item.Caption := 'Hayir';
      Item.SubItems.Add(Info.ExeName);
      Item.SubItems.Add(Info.Title);
      Item.SubItems.Add(IntToStr(Info.PID));
      if Info.StartTime > 0 then
        Item.SubItems.Add(DateTimeToStr(Info.StartTime))
      else
        Item.SubItems.Add('-');
      Item.Data := Pointer(Info.Handle);
      if Info.Handle = SelHandle then
        Item.Selected := True;
    end;
  finally
    ListViewApps.Items.EndUpdate;
  end;

  UpdateColumnHeaders;
  UpdateStatusBar;
end;

procedure TfrmMain.SortWindowList;
var
  Col: Integer;
  Asc: Boolean;
begin
  if FSortColumn < 0 then
    Exit;
  Col := FSortColumn;
  Asc := FSortAscending;
  FWindows.Sort(TComparer<TWindowInfo>.Construct(
    function(const A, B: TWindowInfo): Integer
    begin
      case Col of
        0: Result := CompareText(BoolToStr(A.IsTopMost), BoolToStr(B.IsTopMost));
        1: Result := CompareText(A.ExeName, B.ExeName);
        2: Result := CompareText(A.Title, B.Title);
        3: Result := CompareValue(A.PID, B.PID);
        4: Result := CompareDateTime(A.StartTime, B.StartTime);
      else
        Result := 0;
      end;
      if not Asc then
        Result := -Result;
    end));
end;

procedure TfrmMain.UpdateColumnHeaders;
const
  BaseCaptions: array[0..4] of string = ('Ontop', 'Uygulama (EXE)',
    'Pencere Basligi', 'PID', 'Baslangic Tarihi');
var
  I: Integer;
  Caption: string;
begin
  for I := 0 to ListViewApps.Columns.Count - 1 do
  begin
    Caption := BaseCaptions[I];
    if I = FSortColumn then
    begin
      if FSortAscending then
        Caption := Caption + ' ^'
      else
        Caption := Caption + ' v';
    end;
    ListViewApps.Columns[I].Caption := Caption;
  end;
end;

procedure TfrmMain.ListViewAppsColumnClick(Sender: TObject; Column: TListColumn);
begin
  if FSortColumn = Column.Index then
    FSortAscending := not FSortAscending
  else
  begin
    FSortColumn := Column.Index;
    FSortAscending := True;
  end;
  RefreshListView;
end;

procedure TfrmMain.UpdateStatusBar;
begin
  StatusBar1.SimpleText := Format('%d pencere listelendi  |  %d uygulama hatirlaniyor  |  Son guncelleme: %s',
    [FWindows.Count, FRemembered.Count, TimeToStr(Now)]);
end;

procedure TfrmMain.btnRefreshClick(Sender: TObject);
begin
  RefreshListView;
end;

procedure TfrmMain.btnToggleOnTopClick(Sender: TObject);
var
  Idx: Integer;
  Info: TWindowInfo;
  NewState: Boolean;
  ExeLower: string;
begin
  if not Assigned(ListViewApps.Selected) then
  begin
    ShowMessage('Lutfen listeden bir uygulama secin.');
    Exit;
  end;

  Idx := ListViewApps.Selected.Index;
  if (Idx < 0) or (Idx >= FWindows.Count) then
    Exit;

  Info := FWindows[Idx];
  NewState := not Info.IsTopMost;

  ApplyTopMost(Info.Handle, NewState);
  Info.IsTopMost := NewState;
  FWindows[Idx] := Info;

  ExeLower := LowerCase(Info.ExeName);
  if NewState then
  begin
    if FRemembered.IndexOf(ExeLower) < 0 then
      FRemembered.Add(ExeLower);
  end
  else if FRemembered.IndexOf(ExeLower) >= 0 then
    FRemembered.Delete(FRemembered.IndexOf(ExeLower));

  SaveSettings;
  RefreshListView;
end;

procedure TfrmMain.ListViewAppsDblClick(Sender: TObject);
begin
  btnToggleOnTopClick(Sender);
end;

procedure TfrmMain.TimerRefreshTimer(Sender: TObject);
begin
  RefreshListView;
end;

end.
