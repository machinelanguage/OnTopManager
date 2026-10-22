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
    chkGroup: TCheckBox;
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
    procedure chkGroupClick(Sender: TObject);
    procedure ListViewAppsClick(Sender: TObject);
    procedure ListViewAppsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FWindows: TList<TWindowInfo>;
    FRemembered: TStringList;     // hatirlanan exe adlari (kucuk harf)
    FCollapsedExes: TStringList;  // kapatilmis (collapsed) gruplarin exe adlari
    FIniPath: string;
    FClosing: Boolean;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    procedure WMSysCommand(var Msg: TWMSysCommand); message WM_SYSCOMMAND;
    procedure WMActivateInstance(var Msg: TMessage); message WM_USER + 1;
    procedure EnumRunningWindows;
    procedure LoadSettings;
    procedure SaveSettings;
    procedure ApplyTopMost(AHandle: HWND; ATopMost: Boolean);
    procedure RefreshListView;
    procedure AutoApplyRemembered;
    procedure UpdateStatusBar;
    procedure SortWindowList(AGrouped: Boolean);
    function CompareWindowInfos(const A, B: TWindowInfo): Integer;
    procedure UpdateColumnHeaders;
    function WindowIndexByHandle(AHandle: HWND): Integer;
    procedure AddWindowItem(AIndex: Integer; ASelHandles: TList<HWND>);
    procedure ToggleGroupCollapse(const AExe: string);
  public
  end;

var
  frmMain: TfrmMain;

// Ikinci kopya baslatildiginda: mevcut OnTop Manager penceresini bulup one getirir.
// (OnTopManager.dpr'dan cagrilir; WM_USER+1 mesaji gonderir, FormCreate dinler.)
function ActivateExistingWindow(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Buf: array[0..63] of Char;
  ClassName: string;
begin
  Result := True; // enum devam etsin
  FillChar(Buf, SizeOf(Buf), 0);
  GetClassName(Wnd, Buf, Length(Buf));
  ClassName := Buf;
  if (ClassName = 'TfrmMain') and IsWindowVisible(Wnd) then
  begin
    PostMessage(Wnd, WM_USER + 1, 0, 0);
    Result := False; // bulduk, dur
  end;
end;

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

// Calisan exe'nin (dproj > Proje Secenekleri > Surum Bilgisi) version kaynagini okur
function GetAppVersion: string;
var
  ExePath: string;
  Size: DWORD;
  Hnd: DWORD;
  Buffer: Pointer;
  FixedInfo: PVSFixedFileInfo;
  Len: UINT;
begin
  Result := '';
  ExePath := ParamStr(0);
  Size := GetFileVersionInfoSize(PChar(ExePath), Hnd);
  if Size = 0 then
    Exit;
  Buffer := AllocMem(Size);
  try
    if GetFileVersionInfo(PChar(ExePath), 0, Size, Buffer) and
       VerQueryValue(Buffer, '\', Pointer(FixedInfo), Len) then
    begin
      Result := Format('%d.%d.%d',
        [HiWord(FixedInfo.dwFileVersionMS), LoWord(FixedInfo.dwFileVersionMS),
         HiWord(FixedInfo.dwFileVersionLS)]);
    end;
  finally
    FreeMem(Buffer);
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
  FCollapsedExes := TStringList.Create;
  FCollapsedExes.Sorted := True;
  FCollapsedExes.Duplicates := dupIgnore;
  FClosing := False;

  AppDataDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) + 'OnTopManager';
  ForceDirectories(AppDataDir);
  FIniPath := IncludeTrailingPathDelimiter(AppDataDir) + 'settings.ini';

  ListViewApps.ViewStyle := vsReport;
  ListViewApps.RowSelect := True;
  ListViewApps.ReadOnly := True;
  ListViewApps.MultiSelect := True; // birden fazla pencere secilebilsin
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

  // Surum bilgisini form basliginda goster (dproj'taki version kaynagindan okunur)
  if GetAppVersion <> '' then
    Caption := Format('OnTop Manager v%s', [GetAppVersion])
  else
    Caption := 'OnTop Manager v1.1';

  LoadSettings;
  RefreshListView;

  TimerRefresh.Enabled := False; // liste otomatik yenilenmesin, sadece manuel/F5
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FWindows.Free;
  FRemembered.Free;
  FCollapsedExes.Free;
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

procedure TfrmMain.WMActivateInstance(var Msg: TMessage);
begin
  // Ikinci kopya baslatildiginda (dpr'daki EnumWindows bu mesaji gonderir):
  // gizli/tepside olsun da olmasin da mevcut pencereyi one getir.
  Msg.Result := 0;
  Show;
  WindowState := wsNormal;
  Application.Restore;
  Application.BringToFront;
  SetForegroundWindow(Handle);
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
  I, J: Integer;
  Item: TListItem;
  SelHandles: TList<HWND>;
  CurExe: string;
  GroupStart, GroupCount, GroupTopMost: Integer;
  GroupingOn: Boolean;
begin
  // Mevcut secili pencereleri (grup satirlari haric) hatirlayalim
  SelHandles := TList<HWND>.Create;
  try
    for I := 0 to ListViewApps.Items.Count - 1 do
      if ListViewApps.Items[I].Selected and (HWND(ListViewApps.Items[I].Data) <> HWND(-1)) then
        SelHandles.Add(HWND(ListViewApps.Items[I].Data));

    EnumRunningWindows;
    AutoApplyRemembered;
    GroupingOn := chkGroup.Checked;
    SortWindowList(GroupingOn);

    ListViewApps.Items.BeginUpdate;
    try
      ListViewApps.Items.Clear;
      I := 0;
      while I < FWindows.Count do
      begin
        if GroupingOn then
        begin
          // Ayni exe'ye ait ard isik pencereleri tek grup satiri altinda topla
          CurExe := LowerCase(FWindows[I].ExeName);
          GroupStart := I;
          GroupCount := 0;
          GroupTopMost := 0;
          while (I < FWindows.Count) and (LowerCase(FWindows[I].ExeName) = CurExe) do
          begin
            Inc(GroupCount);
            if FWindows[I].IsTopMost then
              Inc(GroupTopMost);
            Inc(I);
          end;

          // Grup (task) satiri: tiklaninca alt ogullar acilir/kapanir
          Item := ListViewApps.Items.Add;
          if FCollapsedExes.IndexOf(CurExe) >= 0 then
            Item.Caption := '[+]'
          else
            Item.Caption := '[-]';
          Item.SubItems.Add(FWindows[GroupStart].ExeName);
          Item.SubItems.Add(Format('%d kopya / %d ontop', [GroupCount, GroupTopMost]));
          Item.SubItems.Add('');
          Item.SubItems.Add('');
          Item.Data := Pointer(HWND(-1)); // grup satiri isareti

          if FCollapsedExes.IndexOf(CurExe) < 0 then
            for J := GroupStart to I - 1 do
              AddWindowItem(J, SelHandles);
        end
        else
        begin
          AddWindowItem(I, SelHandles);
          Inc(I);
        end;
      end;
    finally
      ListViewApps.Items.EndUpdate;
    end;
  finally
    SelHandles.Free;
  end;

  UpdateColumnHeaders;
  UpdateStatusBar;
end;

procedure TfrmMain.AddWindowItem(AIndex: Integer; ASelHandles: TList<HWND>);
var
  Info: TWindowInfo;
  Item: TListItem;
begin
  Info := FWindows[AIndex];
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
  if ASelHandles.IndexOf(Info.Handle) >= 0 then
    Item.Selected := True;
end;

function TfrmMain.WindowIndexByHandle(AHandle: HWND): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FWindows.Count - 1 do
    if FWindows[I].Handle = AHandle then
    begin
      Result := I;
      Break;
    end;
end;

procedure TfrmMain.ToggleGroupCollapse(const AExe: string);
var
  Idx: Integer;
begin
  Idx := FCollapsedExes.IndexOf(AExe);
  if Idx >= 0 then
    FCollapsedExes.Delete(Idx)
  else
    FCollapsedExes.Add(AExe);
  RefreshListView;
end;

procedure TfrmMain.SortWindowList(AGrouped: Boolean);
begin
  if FSortColumn < 0 then
    Exit;
  FWindows.Sort(TComparer<TWindowInfo>.Construct(
    function(const A, B: TWindowInfo): Integer
    begin
      if AGrouped then
      begin
        // Gruplama acikken once exe adina gore grupla, grup icinde secili alana gore
        Result := CompareText(A.ExeName, B.ExeName);
        if Result = 0 then
          Result := CompareWindowInfos(A, B);
      end
      else
        Result := CompareWindowInfos(A, B);
    end));
end;

function TfrmMain.CompareWindowInfos(const A, B: TWindowInfo): Integer;
begin
  case FSortColumn of
    0: Result := CompareText(BoolToStr(A.IsTopMost), BoolToStr(B.IsTopMost));
    1: Result := CompareText(A.ExeName, B.ExeName);
    2: Result := CompareText(A.Title, B.Title);
    3: Result := CompareValue(A.PID, B.PID);
    4: Result := CompareDateTime(A.StartTime, B.StartTime);
  else
    Result := 0;
  end;
  if not FSortAscending then
    Result := -Result;
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
  I, Idx: Integer;
  Item: TListItem;
  Info: TWindowInfo;
  NewState, AllTopMost: Boolean;
  ExeLower: string;
  Exes: TStringList;
begin
  Exes := TStringList.Create;
  try
    Exes.Sorted := True;
    Exes.Duplicates := dupIgnore;

    // Secili (grup satiri olmayan) tum satirlari topla
    AllTopMost := True;
    for I := 0 to ListViewApps.Items.Count - 1 do
    begin
      Item := ListViewApps.Items[I];
      if not Item.Selected then
        Continue;
      if HWND(Item.Data) = HWND(-1) then
        Continue; // grup satiri atlanir
      Idx := WindowIndexByHandle(HWND(Item.Data));
      if Idx < 0 then
        Continue;
      if not FWindows[Idx].IsTopMost then
        AllTopMost := False;
      ExeLower := LowerCase(FWindows[Idx].ExeName);
      if Exes.IndexOf(ExeLower) < 0 then
        Exes.Add(ExeLower);
    end;

    if Exes.Count = 0 then
    begin
      ShowMessage('Lutfen listeden en az bir uygulama penceresi secin.');
      Exit;
    end;

    // Secilenlerin tamami ontop ise kapat, degilse hepsini ontop yap
    NewState := not AllTopMost;

    for I := 0 to ListViewApps.Items.Count - 1 do
    begin
      Item := ListViewApps.Items[I];
      if (not Item.Selected) or (HWND(Item.Data) = HWND(-1)) then
        Continue;
      Idx := WindowIndexByHandle(HWND(Item.Data));
      if Idx < 0 then
        Continue;
      Info := FWindows[Idx];
      ApplyTopMost(Info.Handle, NewState);
      Info.IsTopMost := NewState;
      FWindows[Idx] := Info;
    end;

    // Hatirlanan listeyi guncelle (exe bazli)
    if NewState then
    begin
      for I := 0 to Exes.Count - 1 do
        if FRemembered.IndexOf(Exes[I]) < 0 then
          FRemembered.Add(Exes[I]);
    end
    else
    begin
      for I := 0 to Exes.Count - 1 do
        if FRemembered.IndexOf(Exes[I]) >= 0 then
          FRemembered.Delete(FRemembered.IndexOf(Exes[I]));
    end;

    SaveSettings;
    RefreshListView;
  finally
    Exes.Free;
  end;
end;

procedure TfrmMain.ListViewAppsDblClick(Sender: TObject);
begin
  // Grup satirina cift tiklama: grubu ac/kapat
  if chkGroup.Checked and Assigned(ListViewApps.Selected) and
     (HWND(ListViewApps.Selected.Data) = HWND(-1)) then
  begin
    ToggleGroupCollapse(LowerCase(ListViewApps.Selected.SubItems[0]));
    Exit;
  end;
  btnToggleOnTopClick(Sender);
end;

procedure TfrmMain.ListViewAppsClick(Sender: TObject);
var
  Pt: TPoint;
  Item: TListItem;
  H: HWND;
  Idx: Integer;
begin
  Pt := ListViewApps.ScreenToClient(Mouse.CursorPos);
  Item := ListViewApps.GetItemAt(Pt.X, Pt.Y);
  if Item = nil then
    Exit;

  // Pencere satirina tek tiklama: ilgili pencereyi one getir (bring to front)
  if HWND(Item.Data) <> HWND(-1) then
  begin
    H := HWND(Item.Data);
    Idx := WindowIndexByHandle(H);
    if (Idx >= 0) and IsWindow(H) then
    begin
      if IsIconic(H) then
        ShowWindow(H, SW_RESTORE);
      SetForegroundWindow(H);
    end;
    Exit;
  end;

  // Grup satirina tek tiklama: grubu ac/kapat (dropdown)
  if chkGroup.Checked then
    ToggleGroupCollapse(LowerCase(Item.SubItems[0]));
end;

procedure TfrmMain.ListViewAppsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  I: Integer;
begin
  // Ctrl+A: tum pencere satirlarini sec (grup satirlari haric)
  if (Key = Ord('A')) and (ssCtrl in Shift) then
  begin
    for I := 0 to ListViewApps.Items.Count - 1 do
      if HWND(ListViewApps.Items[I].Data) <> HWND(-1) then
        ListViewApps.Items[I].Selected := True;
    Key := 0;
  end;
end;

procedure TfrmMain.chkGroupClick(Sender: TObject);
begin
  RefreshListView;
end;

procedure TfrmMain.TimerRefreshTimer(Sender: TObject);
begin
  RefreshListView;
end;

end.
