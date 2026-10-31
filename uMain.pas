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
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.ImgList;

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
    PanelHK: TPanel;
    lblHK1: TLabel;
    hkSend: THotKey;
    lblHK2: TLabel;
    hkRestore: THotKey;
    btnApplyHK: TButton;
    chkOwnIcon: TCheckBox;
    PanelHKEnabled: TPanel;
    chkHKEnabled: TCheckBox;
    ListViewApps: TListView;
    TimerRefresh: TTimer;
    StatusBar1: TStatusBar;
    TrayIcon1: TTrayIcon;
    TrayIcon2: TTrayIcon;
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
    procedure btnApplyHKClick(Sender: TObject);
    procedure HKChange(Sender: TObject);
    procedure chkOwnIconClick(Sender: TObject);
    procedure chkHKEnabledClick(Sender: TObject);
    procedure TrayIcon2Click(Sender: TObject);
    procedure PopupMenuTrayPopup(Sender: TObject);
    procedure miHiddenClick(Sender: TObject);
  private
    FWindows: TList<TWindowInfo>;
    FRemembered: TStringList;     // hatirlanan exe adlari (kucuk harf)
    FCollapsedExes: TStringList;  // kapatilmis (collapsed) gruplarin exe adlari
    FHidden: TList<HWND>;         // kisayolla tray'a atilan pencereler (0 = en yeni)
    FMenuItems: TList<TMenuItem>; // gizli pencereler icin dinamik menu ogeleri
    FHiddenImages: TImageList;
    FIniPath: string;
    FClosing: Boolean;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    procedure WMSysCommand(var Msg: TWMSysCommand); message WM_SYSCOMMAND;
    procedure WMActivateInstance(var Msg: TMessage); message WM_USER + 1;
    procedure WMHotKey(var Msg: TMessage); message WM_HOTKEY;
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
    procedure BringWindowToFront(AHandle: HWND);
    procedure SendActiveToTray;
    procedure RestoreLastHidden;
    procedure RestoreHiddenIndex(AIndex: Integer);
    function ApplyHotkeySettings: string;
    procedure UpdateTrayState;
    procedure RebuildHiddenMenu;
    procedure UpdateHotkeyUI;
  public
  end;

var
  frmMain: TfrmMain;

// Ikinci kopya baslatildiginda: mevcut OnTop Manager penceresini bulup one getirir.
// (OnTopManager.dpr'dan cagrilir; WM_USER+1 mesaji gonderir, form uMain'de dinler.)
function ActivateExistingWindow(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;

implementation

{$R *.dfm}

// Ikinci kopya baslatildiginda: mevcut OnTop Manager penceresini bulup one getirir.
function ActivateExistingWindow(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Buf: array[0..63] of Char;
  ClassName: string;
begin
  Result := True; // enum devam etsin
  FillChar(Buf, SizeOf(Buf), 0);
  GetClassName(Wnd, Buf, Length(Buf));
  ClassName := Buf;
  if (ClassName = 'TfrmMain') then
  begin
    PostMessage(Wnd, WM_USER + 1, 0, 0);
    Result := False; // bulduk, dur
  end;
end;

// Gizli pencere basligini okur (tray menusunde gosterilir)
function GetWindowTitleText(H: HWND): string;
var
  Buf: array[0..255] of Char;
begin
  FillChar(Buf, SizeOf(Buf), 0);
  GetWindowText(H, Buf, Length(Buf));
  Result := Buf;
  if Result = '' then
    Result := '(basliksiz pencere)';
end;

const
  // Eski INI degerleri hatali olarak HKM/HOTKEYF kodlamasiyla yazilmisti
  // (commctrl.h: yuksek baytta 1=Shift, 2=Ctrl, 4=Alt). THotKey.HotKey ise
  // TShortCut tipidir (Vcl.Menus): dusuk bayt = Windows sanal tus kodu (VK_),
  // modifier bitleri 13-15'te (scShift=$2000, scCtrl=$4000, scAlt=$8000).
  // NormalizeHotKeyValue eski kodlamayi TShortCut'a cevirmek icin kullanilir.
  HOTKEYF_SHIFT   = $01;
  HOTKEYF_CONTROL = $02;
  HOTKEYF_ALT     = $04;

// Eski HOTKEYF kodlamali degeri TShortCut'a (Vcl.Menus kodlamasi) cevirir.
// Zaten gecerli bir TShortCut ise (modifier bitleri 13-15'te) oldugu gibi dondurur.
function NormalizeHotKeyValue(AValue: Integer): TShortCut;
var
  V, Mods, Sc: Integer;
begin
  V := AValue and $FFFF;
  if (V and (scShift or scCtrl or scAlt)) <> 0 then
    Exit(V); // zaten TShortCut kodlamasi
  Mods := (V shr 8) and $FF; // eski HOTKEYF bitleri (8-10)
  if Mods = 0 then
    Exit(V); // modifiersiz gecerli TShortCut (yalnizca VK)
  Sc := 0;
  if (Mods and HOTKEYF_SHIFT) <> 0 then Sc := Sc or scShift;
  if (Mods and HOTKEYF_CONTROL) <> 0 then Sc := Sc or scCtrl;
  if (Mods and HOTKEYF_ALT) <> 0 then Sc := Sc or scAlt;
  Result := Sc or (V and $FF);
end;

// THotKey.HotKey (TShortCut) degerindeki modifier bitlerini RegisterHotKey
// MOD_* bayraklarina cevirir. Dikkat: modifier bitleri yuksek baytta degil,
// 13-15. bitlerdedir (scShift=$2000, scCtrl=$4000, scAlt=$8000).
function HotKeyMods(AHotKey: Integer): UINT;
begin
  Result := 0;
  if (AHotKey and scShift) <> 0 then Result := Result or MOD_SHIFT;
  if (AHotKey and scCtrl) <> 0 then Result := Result or MOD_CONTROL;
  if (AHotKey and scAlt) <> 0 then Result := Result or MOD_ALT;
end;

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
  FHidden := TList<HWND>.Create;
  FMenuItems := TList<TMenuItem>.Create;
  FHiddenImages := TImageList.Create(Self);
  FHiddenImages.Width := GetSystemMetrics(SM_CXSMICON);
  FHiddenImages.Height := GetSystemMetrics(SM_CYSMICON);
  PopupMenuTray.Images := FHiddenImages;
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
  // Ikinci tray ikonu da programin kendi ikonunu kullanir (mod 2)
  TrayIcon2.Icon.Assign(TrayIcon1.Icon);

  LoadSettings;
  UpdateHotkeyUI;
  // Kisayollar acilista dogrudan devreye aliniyor. (Not: LoadSettings, HotKey
  // degerini degistirirse HKChange ile zaten kaydediliyor; ancak INI'deki deger
  // varsayilanla ayniysa OnChange tetiklenmedigi icin kayit yapilmiyordu ve
  // kisayol ilk "Uygula"ya dek oluyordu. Bu yuzden acilista acikca kaydediyoruz.)
  ApplyHotkeySettings;
  UpdateTrayState;
  RefreshListView;

  // Surum bilgisini form basliginda goster (dproj'taki version kaynagindan okunur)
  if GetAppVersion <> '' then
    Caption := Format('OnTop Manager v%s', [GetAppVersion])
  else
    Caption := 'OnTop Manager v1.8.0';

  TimerRefresh.Enabled := False; // liste otomatik yenilenmesin, sadece manuel/F5
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  UnregisterHotKey(Handle, 1);
  UnregisterHotKey(Handle, 2);
  FWindows.Free;
  FRemembered.Free;
  FCollapsedExes.Free;
  FHidden.Free;
  FMenuItems.Free;
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
  Ini := TIniFile.Create(FIniPath);
  Keys := TStringList.Create;
  try
    Ini.ReadSection('OnTop', Keys);
    for I := 0 to Keys.Count - 1 do
      if Ini.ReadBool('OnTop', Keys[I], False) then
        FRemembered.Add(LowerCase(Keys[I]));

    // Kisayollar ve tray gosterim modu (varsayilan: Ctrl+Shift+H / Ctrl+Shift+J;
    // TShortCut kodlamasi: scCtrl($4000) or scShift($2000) or VK = 24648 / 24650)
    chkHKEnabled.Checked := Ini.ReadBool('Hotkeys', 'Enabled', True);
    hkSend.HotKey := NormalizeHotKeyValue(Ini.ReadInteger('Hotkeys', 'SendHotKey', 24648));
    hkRestore.HotKey := NormalizeHotKeyValue(Ini.ReadInteger('Hotkeys', 'RestoreHotKey', 24650));
    chkOwnIcon.Checked := Ini.ReadBool('Options', 'OwnTrayIcon', False);
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

    Ini.WriteBool('Hotkeys', 'Enabled', chkHKEnabled.Checked);
    Ini.WriteInteger('Hotkeys', 'SendHotKey', hkSend.HotKey);
    Ini.WriteInteger('Hotkeys', 'RestoreHotKey', hkRestore.HotKey);
    Ini.WriteBool('Options', 'OwnTrayIcon', chkOwnIcon.Checked);
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
var
  Item: TListItem;
begin
  // Grup satirina cift tiklama: grubu ac/kapat
  Item := ListViewApps.Selected;
  if Assigned(Item) and (HWND(Item.Data) = HWND(-1)) then
  begin
    if chkGroup.Checked then
      ToggleGroupCollapse(LowerCase(Item.SubItems[0]));
    Exit;
  end;
  // Pencere satirina cift tiklama: ilgili pencereyi one getir
  if Assigned(Item) then
    BringWindowToFront(HWND(Item.Data));
end;

procedure TfrmMain.ListViewAppsClick(Sender: TObject);
var
  Pt: TPoint;
  Item: TListItem;
begin
  Pt := ListViewApps.ScreenToClient(Mouse.CursorPos);
  Item := ListViewApps.GetItemAt(Pt.X, Pt.Y);
  if Item = nil then
    Exit;

  // Pencere satirina tek tiklama: sadece secim (one getirmek icin cift tiklama gerekir)
  if HWND(Item.Data) <> HWND(-1) then
    Exit;

  // Grup satirina tek tiklama: grubu ac/kapat (dropdown)
  if chkGroup.Checked then
    ToggleGroupCollapse(LowerCase(Item.SubItems[0]));
end;

procedure TfrmMain.BringWindowToFront(AHandle: HWND);
begin
  if (AHandle <> HWND(-1)) and IsWindow(AHandle) then
  begin
    if IsIconic(AHandle) then
      ShowWindow(AHandle, SW_RESTORE);
    SetForegroundWindow(AHandle);
  end;
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

{ ---------------------------------------------------------------------------
  Kisayol ile tray'a atma / geri getirme
  --------------------------------------------------------------------------- }

procedure TfrmMain.WMHotKey(var Msg: TMessage);
begin
  case Msg.WParam of
    1: SendActiveToTray;    // "Tray'a At" kisayolu
    2: RestoreLastHidden;   // "Geri Getir" kisayolu
  end;
end;

// Explicit pointer-sized declaration for Win32 and Win64.
function WindowMessageTimeout(hWnd: HWND; Msg: UINT; wParam: WPARAM;
  lParam: LPARAM; Flags, Timeout: UINT; ResultValue: Pointer): LRESULT; stdcall;
  external 'user32.dll' name 'SendMessageTimeoutW';

// Copy the borrowed window/class icon: the image list owns its own copy.
function CopyWindowIcon(H: HWND): HICON;
var
  IconValue: DWORD_PTR;
  Source: HICON;
begin
  Source := 0;
  IconValue := 0;
  if WindowMessageTimeout(H, WM_GETICON, ICON_SMALL2, 0,
    SMTO_ABORTIFHUNG or SMTO_BLOCK, 100, @IconValue) <> 0 then
    Source := HICON(IconValue);
  if Source = 0 then
  begin
    IconValue := 0;
    if WindowMessageTimeout(H, WM_GETICON, ICON_SMALL, 0,
      SMTO_ABORTIFHUNG or SMTO_BLOCK, 100, @IconValue) <> 0 then
      Source := HICON(IconValue);
  end;
  if Source = 0 then
    Source := HICON(GetClassLongPtr(H, GCLP_HICONSM));
  if Source = 0 then
    Source := HICON(GetClassLongPtr(H, GCLP_HICON));
  if Source = 0 then
  begin
    IconValue := 0;
    if WindowMessageTimeout(H, WM_GETICON, ICON_BIG, 0,
      SMTO_ABORTIFHUNG or SMTO_BLOCK, 100, @IconValue) <> 0 then
      Source := HICON(IconValue);
  end;
  if Source = 0 then
    Source := LoadIcon(0, IDI_APPLICATION);
  Result := CopyIcon(Source);
end;

// Walk the current Z order before hiding the foreground window.
function NextApplicationWindow(Current: HWND): HWND;
var
  W: HWND;
  PID: DWORD;
begin
  Result := 0;
  W := GetWindow(Current, GW_HWNDNEXT);
  while W <> 0 do
  begin
    GetWindowThreadProcessId(W, PID);
    if IsWindowVisible(W) and IsWindowEnabled(W) and
      not IsIconic(W) and (GetWindow(W, GW_OWNER) = 0) and
      (GetWindowTextLength(W) > 0) and
      (GetWindowLong(W, GWL_EXSTYLE) and WS_EX_TOOLWINDOW = 0) and
      (PID <> GetCurrentProcessId) and
      (W <> GetShellWindow) and (W <> GetDesktopWindow) then
      Exit(W);
    W := GetWindow(W, GW_HWNDNEXT);
  end;
end;
procedure TfrmMain.SendActiveToTray;
var
  H, NextWindow: HWND;
  I: Integer;
begin
  H := GetForegroundWindow;
  if (H = 0) or (H = GetShellWindow) or (H = GetDesktopWindow) then
    Exit;
  NextWindow := NextApplicationWindow(H);
  // Kisayola basildiginda odakta olan pencere bizimkisiyse (ornegin "Uygula"'ya
  // basar basmaz kisayolu denemek icin), kendimizi tray'a atalim: boylece
  // kisayolun calistigi gorulur hale gelir.
  if (H = Handle) or (H = Application.Handle) then
  begin
    Hide;
    TrayIcon1.Visible := True;
    BringWindowToFront(NextWindow);
    Exit;
  end;
  // Zaten gizli listede varsa yeniden ekleme
  for I := 0 to FHidden.Count - 1 do
    if FHidden[I] = H then
      Exit;

  FHidden.Insert(0, H); // en yeni, listenin basina
  ShowWindow(H, SW_HIDE); // gorev cubugundan kalkar, tray'da bekler
  BringWindowToFront(NextWindow);
  UpdateTrayState;
  RefreshListView;
end;

procedure TfrmMain.RestoreLastHidden;
begin
  RestoreHiddenIndex(0);
end;

procedure TfrmMain.RestoreHiddenIndex(AIndex: Integer);
var
  H: HWND;
begin
  if (AIndex < 0) or (AIndex >= FHidden.Count) then
    Exit;
  H := FHidden[AIndex];
  FHidden.Delete(AIndex);
  if IsWindow(H) then
  begin
    ShowWindow(H, SW_SHOW);
    if IsIconic(H) then
      ShowWindow(H, SW_RESTORE);
    SetForegroundWindow(H);
  end;
  UpdateTrayState;
  RefreshListView;
end;

function TfrmMain.ApplyHotkeySettings: string;
var
  Ok1, Ok2: Boolean;
begin
  UnregisterHotKey(Handle, 1);
  UnregisterHotKey(Handle, 2);
  if not chkHKEnabled.Checked then
    Exit(''); // kisayollar kapali: kaydi temizle, uyari verme
  // MOD_NOREPEAT ($4000): one action per key press.
  Ok1 := RegisterHotKey(Handle, 1, HotKeyMods(hkSend.HotKey) or $4000, hkSend.HotKey and $FF);
  Ok2 := RegisterHotKey(Handle, 2, HotKeyMods(hkRestore.HotKey) or $4000, hkRestore.HotKey and $FF);
  // Bos donerse basari; dolu donerse kullaniciya gosterilecek uyari.
  if (not Ok1) and (not Ok2) then
    Result := 'Uyari: iki kisayol da kaydedilemedi (baska bir uygulama ayni kombinasyonu kullaniyor olabilir).'
  else if not Ok1 then
    Result := 'Uyari: "Tray''a At" kisayolu kaydedilemedi (baska bir uygulama ayni kombinasyonu kullaniyor olabilir).'
  else if not Ok2 then
    Result := 'Uyari: "Geri Getir" kisayolu kaydedilemedi (baska bir uygulama ayni kombinasyonu kullaniyor olabilir).'
  else
    Result := '';
end;

procedure TfrmMain.UpdateTrayState;
var
  I: Integer;
  S: string;
begin
  // Bu arada kapanmis gizli pencereleri listeden temizle
  for I := FHidden.Count - 1 downto 0 do
    if not IsWindow(FHidden[I]) then
      FHidden.Delete(I);

  // Mod 2: gizli pencere varken programin kendi ikonuyla ikinci tray ikonu gorunur
  TrayIcon2.Visible := chkOwnIcon.Checked and (FHidden.Count > 0);
  if TrayIcon2.Visible then
    TrayIcon2.Hint := Format('Gizli pencereler: %d (tikla: ac)', [FHidden.Count]);

  S := 'OnTop Manager';
  if FHidden.Count > 0 then
    S := Format('%s  (%d gizli pencere)', [S, FHidden.Count]);
  TrayIcon1.Hint := S;
end;

procedure TfrmMain.RebuildHiddenMenu;
var
  I: Integer;
  mi: TMenuItem;
  Icon: TIcon;
begin
  // Onceki dinamik ogeleri kaldir
  for I := 0 to FMenuItems.Count - 1 do
    FMenuItems[I].Free;
  FMenuItems.Clear;
  FHiddenImages.Clear;
  if FHidden.Count = 0 then
    Exit;

  // Ayirici
  mi := TMenuItem.Create(PopupMenuTray);
  mi.Caption := '-';
  PopupMenuTray.Items.Insert(PopupMenuTray.Items.IndexOf(miExit), mi);
  FMenuItems.Add(mi);

  // Gizli pencereleri, ana tray ikonu altinda kumelenmis olarak listele
  for I := 0 to FHidden.Count - 1 do
  begin
    mi := TMenuItem.Create(PopupMenuTray);
    mi.Caption := StringReplace(GetWindowTitleText(FHidden[I]), '&', '&&', [rfReplaceAll]);
    Icon := TIcon.Create;
    try
      Icon.Handle := CopyWindowIcon(FHidden[I]);
      mi.ImageIndex := FHiddenImages.AddIcon(Icon);
    finally
      Icon.Free;
    end;
    mi.Tag := FHidden[I];
    mi.OnClick := miHiddenClick;
    PopupMenuTray.Items.Insert(PopupMenuTray.Items.IndexOf(miExit), mi);
    FMenuItems.Add(mi);
  end;
end;

procedure TfrmMain.PopupMenuTrayPopup(Sender: TObject);
begin
  UpdateTrayState;
  RebuildHiddenMenu;
end;

procedure TfrmMain.miHiddenClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := FHidden.IndexOf(HWND((Sender as TMenuItem).Tag));
  if Idx >= 0 then
    RestoreHiddenIndex(Idx);
end;

procedure TfrmMain.TrayIcon2Click(Sender: TObject);
begin
  // Her durumda tiklandiginda en son gizlenen pencereyi ac
  RestoreLastHidden;
end;

procedure TfrmMain.chkOwnIconClick(Sender: TObject);
begin
  UpdateTrayState;
  SaveSettings;
end;

procedure TfrmMain.UpdateHotkeyUI;
var
  E: Boolean;
begin
  // Kisayollar kapaliyken ilgili kontroller de pasif gorunsun
  E := chkHKEnabled.Checked;
  hkSend.Enabled := E;
  hkRestore.Enabled := E;
  btnApplyHK.Enabled := E;
end;

procedure TfrmMain.chkHKEnabledClick(Sender: TObject);
begin
  UpdateHotkeyUI;
  // Acilip kapanma aninda uygula ve kalici hale getir
  ApplyHotkeySettings;
  SaveSettings;
  UpdateStatusBar;
  if chkHKEnabled.Checked then
    StatusBar1.SimpleText := StatusBar1.SimpleText + '  |  Kisayollar etkin'
  else
    StatusBar1.SimpleText := StatusBar1.SimpleText + '  |  Kisayollar devre disi';
end;

procedure TfrmMain.HKChange(Sender: TObject);
begin
  // THotKey'te yeni kombinasyon secildigi AN kaydi tazele: kullanicinin
  // ayrica "Uygula"ya basmasini beklemeden kisayol gecerli olsun.
  // (Kullanici raporu: tanimlanan yeni tuslar devreye girmiyordu.)
  ApplyHotkeySettings;
  SaveSettings;
end;

procedure TfrmMain.btnApplyHKClick(Sender: TObject);
var
  Msg: string;
begin
  Msg := ApplyHotkeySettings;
  SaveSettings;
  UpdateStatusBar;
  if Msg <> '' then
    MessageBeep(MB_ICONWARNING)
  else
    Msg := 'Kisayollar uygulandi';
  StatusBar1.SimpleText := StatusBar1.SimpleText + '  |  ' + Msg;
end;

procedure TfrmMain.TimerRefreshTimer(Sender: TObject);
begin
  RefreshListView;
end;

end.
