object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'OnTop Manager'
  ClientHeight = 471
  ClientWidth = 921
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 15
  object lblInfo: TLabel
    Left = 0
    Top = 82
    Width = 921
    Height = 15
    Align = alTop
    Alignment = taCenter
    Caption = 
      'Birden fazla pencereyi (Ctrl/Ctrl+A) secip "Secilenleri Ontop Ya' +
      'p / Kaldir" butonuna basin. Pencereyi one getirmek icin satira c' +
      'ift tiklayin.'
    ExplicitWidth = 714
  end
  object PanelHK: TPanel
    Left = 0
    Top = 48
    Width = 921
    Height = 34
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 2
    ExplicitWidth = 660
    object lblHK1: TLabel
      Left = 8
      Top = 10
      Width = 48
      Height = 15
      Caption = 'Tray'#39'a At:'
    end
    object lblHK2: TLabel
      Left = 214
      Top = 10
      Width = 52
      Height = 15
      Caption = 'Geri Getir:'
    end
    object hkSend: THotKey
      Left = 74
      Top = 7
      Width = 130
      Height = 20
      HotKey = 24648
      Modifiers = [hkShift, hkCtrl]
      TabOrder = 0
      OnChange = HKChange
    end
    object hkRestore: THotKey
      Left = 278
      Top = 7
      Width = 130
      Height = 20
      HotKey = 24650
      Modifiers = [hkShift, hkCtrl]
      TabOrder = 1
      OnChange = HKChange
    end
    object btnApplyHK: TButton
      Left = 416
      Top = 5
      Width = 70
      Height = 25
      Caption = 'Uygula'
      TabOrder = 2
      OnClick = btnApplyHKClick
    end
    object chkOwnIcon: TCheckBox
      Left = 494
      Top = 9
      Width = 160
      Height = 17
      Caption = 'Gizliyi kendi ikonunda goster'
      TabOrder = 3
      OnClick = chkOwnIconClick
    end
  end
  object PanelHKEnabled: TPanel
    Left = 0
    Top = 97
    Width = 921
    Height = 84
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 4
    ExplicitWidth = 660
    object lblTrayPopup: TLabel
      Left = 250
      Top = 6
      Width = 70
      Height = 15
      Caption = 'Tray menusu:'
    end
    object lblOpenPID: TLabel
      Left = 315
      Top = 32
      Width = 21
      Height = 15
      Caption = 'PID:'
    end
    object chkHKEnabled: TCheckBox
      Left = 8
      Top = 5
      Width = 220
      Height = 17
      Caption = 'Kisayollar etkin'
      Checked = True
      State = cbChecked
      TabOrder = 0
      OnClick = chkHKEnabledClick
    end
    object cboTrayPopup: TComboBox
      Left = 380
      Top = 2
      Width = 190
      Height = 23
      Style = csDropDownList
      ItemIndex = 1
      TabOrder = 1
      Text = 'Sol tik'
      OnChange = cboTrayPopupChange
      Items.Strings = (
        'Sag tik'
        'Sol tik')
    end
    object chkStartWithWindows: TCheckBox
      Left = 8
      Top = 30
      Width = 300
      Height = 17
      Caption = 'Windows basladiginda calistir'
      TabOrder = 2
      OnClick = chkStartWithWindowsClick
    end
    object edtOpenPID: TEdit
      Left = 345
      Top = 27
      Width = 115
      Height = 23
      MaxLength = 10
      NumbersOnly = True
      TabOrder = 3
    end
    object btnOpenPID: TButton
      Left = 468
      Top = 27
      Width = 130
      Height = 23
      Caption = 'Pencereyi Ac'
      TabOrder = 4
      OnClick = btnOpenPIDClick
    end
    object chkCPUWatch: TCheckBox
      Left = 8
      Top = 60
      Width = 120
      Height = 17
      Caption = 'CPU izle'
      Checked = True
      State = cbChecked
      TabOrder = 5
    end
    object lblCPUThreshold: TLabel
      Left = 140
      Top = 60
      Width = 50
      Height = 15
      Caption = 'Esik (%):'
    end
    object edtCPUThreshold: TEdit
      Left = 195
      Top = 56
      Width = 55
      Height = 23
      MaxLength = 3
      NumbersOnly = True
      Text = '5'
      TabOrder = 6
    end
    object lblCPUDuration: TLabel
      Left = 270
      Top = 60
      Width = 60
      Height = 15
      Caption = 'Sure (sn):'
    end
    object edtCPUDuration: TEdit
      Left = 335
      Top = 56
      Width = 65
      Height = 23
      MaxLength = 4
      NumbersOnly = True
      Text = '30'
      TabOrder = 7
    end
    object btnCPUApply: TButton
      Left = 420
      Top = 55
      Width = 178
      Height = 25
      Caption = 'CPU Ayarlarini Uygula'
      TabOrder = 8
      OnClick = btnCPUApplyClick
    end
  end
  object ListViewApps: TListView
    Left = 0
    Top = 181
    Width = 921
    Height = 268
    Align = alClient
    Columns = <>
    GridLines = True
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnClick = ListViewAppsClick
    OnColumnClick = ListViewAppsColumnClick
    OnDblClick = ListViewAppsDblClick
    OnKeyDown = ListViewAppsKeyDown
    ExplicitWidth = 660
    ExplicitHeight = 249
  end
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 921
    Height = 48
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitWidth = 660
    object btnRefresh: TButton
      Left = 8
      Top = 8
      Width = 140
      Height = 32
      Caption = 'Listeyi Yenile'
      TabOrder = 0
      OnClick = btnRefreshClick
    end
    object btnToggleOnTop: TButton
      Left = 156
      Top = 8
      Width = 200
      Height = 32
      Caption = 'Secilenleri Ontop Yap / Kaldir'
      TabOrder = 1
      OnClick = btnToggleOnTopClick
    end
    object chkGroup: TCheckBox
      Left = 372
      Top = 13
      Width = 180
      Height = 20
      Caption = 'Uygulamalari Grupla'
      Checked = True
      State = cbChecked
      TabOrder = 2
      OnClick = chkGroupClick
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 449
    Width = 921
    Height = 22
    Panels = <>
    SimplePanel = True
    ExplicitTop = 398
    ExplicitWidth = 660
  end
  object TimerRefresh: TTimer
    Enabled = False
    Interval = 2000
    OnTimer = TimerRefreshTimer
    Left = 592
    Top = 16
  end
  object TimerCPU: TTimer
    Enabled = False
    Interval = 1000
    OnTimer = TimerCPUTimer
    Left = 480
    Top = 16
  end
  object TimerRemembered: TTimer
    Enabled = False
    Interval = 2000
    OnTimer = TimerRememberedTimer
    Left = 640
    Top = 16
  end
  object TrayIcon1: TTrayIcon
    Visible = True
    OnDblClick = TrayIcon1DblClick
    OnMouseUp = TrayIcon1MouseUp
    Left = 528
    Top = 16
  end
  object TrayIcon2: TTrayIcon
    OnClick = TrayIcon2Click
    Left = 448
    Top = 16
  end
  object PopupMenuTray: TPopupMenu
    OnPopup = PopupMenuTrayPopup
    Left = 592
    Top = 72
    object miShow: TMenuItem
      Caption = 'Goster'
      OnClick = miShowClick
    end
    object miExit: TMenuItem
      Caption = 'Cikis'
      OnClick = miExitClick
    end
  end
end
