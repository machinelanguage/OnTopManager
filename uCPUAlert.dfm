object frmCPUAlert: TfrmCPUAlert
  Caption = 'Uzun sureli yuksek CPU kullanimi'
  ClientHeight = 190
  ClientWidth = 600
  Position = poScreenCenter
  BorderStyle = bsSizeToolWin
  FormStyle = fsStayOnTop
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  object memoAlerts: TMemo
    Left = 0
    Top = 0
    Width = 600
    Height = 160
    Align = alClient
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object btnClose: TButton
    Left = 0
    Top = 160
    Width = 600
    Height = 30
    Align = alBottom
    Caption = 'Kapat'
    TabOrder = 1
    OnClick = btnCloseClick
  end
end
