unit uCPUAlert;

interface

uses
  System.Classes, System.SysUtils, Vcl.Forms, Vcl.StdCtrls, Vcl.Controls;

type
  TfrmCPUAlert = class(TForm)
    memoAlerts: TMemo;
    btnClose: TButton;
    procedure btnCloseClick(Sender: TObject);
  public
    procedure AddAlert(const AText: string);
  end;

implementation

{$R *.dfm}

procedure TfrmCPUAlert.btnCloseClick(Sender: TObject);
begin
  Hide;
end;

procedure TfrmCPUAlert.AddAlert(const AText: string);
begin
  while memoAlerts.Lines.Count > 190 do
    memoAlerts.Lines.Delete(0);
  memoAlerts.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + AText);
  memoAlerts.SelStart := Length(memoAlerts.Text);
  Show;
  BringToFront;
end;

end.
