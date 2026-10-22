object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'OnTop Manager'
  ClientHeight = 420
  ClientWidth = 660
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
    Width = 660
    Height = 20
    Align = alTop
    Alignment = taCenter
    Caption = 
      'Birden fazla pencereyi (Ctrl/Ctrl+A) secip "Secilenleri Ontop Yap / Kaldir"' +
      ' butonuna basin. Pencereyi one getirmek icin satira cift tiklayin.'
    ExplicitWidth = 540
  end
  object PanelHK: TPanel
    Left = 0
    Top = 48
    Width = 660
    Height = 34
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 3
    object lblHK1: TLabel
      Left = 8
      Top = 10
      Width = 55
      Height = 15
      Caption = 'Tray'#39'a At:'
    end
    object hkSend: THotKey
      Left = 74
      Top = 7
      Width = 130
      Height = 20
      HotKey = 1608
      TabOrder = 0
    end
    object lblHK2: TLabel
      Left = 214
      Top = 10
      Width = 56
      Height = 15
      Caption = 'Geri Getir:'
    end
    object hkRestore: THotKey
      Left = 278
      Top = 7
      Width = 130
      Height = 20
      HotKey = 1610
      TabOrder = 1
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
  object ListViewApps: TListView
    Left = 0
    Top = 68
    Width = 660
    Height = 330
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
  end
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 660
    Height = 48
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
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
    Top = 398
    Width = 660
    Height = 22
    Panels = <>
    SimplePanel = True
  end
  object TimerRefresh: TTimer
    Enabled = False
    Interval = 2000
    OnTimer = TimerRefreshTimer
    Left = 592
    Top = 16
  end
  object TrayIcon1: TTrayIcon
    PopupMenu = PopupMenuTray
    Visible = True
    OnDblClick = TrayIcon1DblClick
    Left = 528
    Top = 16
  end
  object TrayIcon2: TTrayIcon
    Visible = False
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
