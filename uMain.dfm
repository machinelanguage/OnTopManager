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
    Top = 48
    Width = 660
    Height = 20
    Align = alTop
    Alignment = taCenter
    Caption = 
      'Listeden bir uygulama secip "Ontop Yap / Kaldir" butonuna veya' +
      ' cift tiklamaya basin.'
    ExplicitWidth = 540
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
    OnDblClick = ListViewAppsDblClick
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
      Width = 180
      Height = 32
      Caption = 'Ontop Yap / Kaldir'
      TabOrder = 1
      OnClick = btnToggleOnTopClick
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
  object PopupMenuTray: TPopupMenu
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
