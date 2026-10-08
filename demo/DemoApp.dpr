program DemoApp;

uses
  Vcl.Forms,
  System.SysUtils,
  System.Classes,
  MainForm in 'MainForm.pas' {frmMain},
  VclE2E.Agent in 'VclE2E.Agent.pas';

{$R *.res}

var
  LPort: Integer;
  I: Integer;
  LParam: string;
begin
  try
    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    Application.Title := 'VCL E2E Demo App';

    LPort := 8080;
    for I := 1 to ParamCount do
    begin
      LParam := ParamStr(I);
      if LParam.StartsWith('--e2e-port=', True) then
        LPort := StrToIntDef(LParam.Substring(11), 8080)
      else if LParam.StartsWith('--port=', True) then
        LPort := StrToIntDef(LParam.Substring(7), 8080);
    end;

    StartE2EAgent(LPort);
    try
      Application.CreateForm(TfrmMain, frmMain);
      Application.Run;
    finally
      StopE2EAgent;
    end;
  except
    on E: Exception do
    begin
      var LLog := TStringList.Create;
      try
        LLog.Add(Format('[%s] %s: %s', [DateTimeToStr(Now), E.ClassName, E.Message]));
        LLog.SaveToFile(ChangeFileExt(ParamStr(0), '.log'));
      finally
        LLog.Free;
      end;
    end;
  end;
end.
