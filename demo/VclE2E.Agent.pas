unit VclE2E.Agent;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.Buttons,
  Vcl.ComCtrls,
  Vcl.DBGrids,
  Data.DB,
  IdHTTPServer,
  IdContext,
  IdCustomHTTPServer;

type
  TVclE2EAgent = class
  private
    FServer: TIdHTTPServer;
    FPort: Integer;
    FTouchedControls: TDictionary<string, Integer>;
    function FindComponentByName(const AName: string): TComponent;
    function FindControlByName(const AName: string): TControl;
    procedure RegisterTouch(const AName: string);
    function IsControlTouched(const AName: string): Boolean;
    
    // HTTP Handlers (called on Indy worker threads, synchronizing to UI thread)
    procedure ServerCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
      
    // UI-thread safe helpers
    procedure RunInUI(AProc: TThreadProcedure);
    function DoGetHealth: TJSONObject;
    function DoGetTree: TJSONObject;
    function DoGetCoverage: TJSONObject;
    function DoGetControlInfo(const AName: string): TJSONObject;
    function DoClickControl(const AName: string): TJSONObject;
    function DoSetText(const AName, AText: string): TJSONObject;
    function DoGetText(const AName: string; APanelIndex: Integer): TJSONObject;
    function DoGridAction(const AName, AAction, AField, AValue: string): TJSONObject;
  public
    constructor Create(APort: Integer = 8080);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    property Port: Integer read FPort write FPort;
  end;

var
  GlobalAgent: TVclE2EAgent = nil;

procedure StartE2EAgent(APort: Integer = 8080);
procedure StopE2EAgent;

implementation

type
  TControlAccess = class(TControl);

procedure StartE2EAgent(APort: Integer = 8080);
begin
  if GlobalAgent = nil then
  begin
    GlobalAgent := TVclE2EAgent.Create(APort);
    GlobalAgent.Start;
  end;
end;

procedure StopE2EAgent;
begin
  if GlobalAgent <> nil then
  begin
    GlobalAgent.Stop;
    FreeAndNil(GlobalAgent);
  end;
end;

{ TVclE2EAgent }

procedure TVclE2EAgent.RunInUI(AProc: TThreadProcedure);
begin
  TThread.Synchronize(TThread(nil), AProc);
end;

constructor TVclE2EAgent.Create(APort: Integer);
begin
  inherited Create;
  FPort := APort;
  FTouchedControls := TDictionary<string, Integer>.Create;
  FServer := TIdHTTPServer.Create(nil);
  FServer.DefaultPort := FPort;
  FServer.OnCommandGet := ServerCommandGet;
end;

destructor TVclE2EAgent.Destroy;
begin
  Stop;
  FreeAndNil(FServer);
  FreeAndNil(FTouchedControls);
  inherited;
end;

procedure TVclE2EAgent.Start;
begin
  if not FServer.Active then
  begin
    FServer.DefaultPort := FPort;
    FServer.Active := True;
  end;
end;

procedure TVclE2EAgent.Stop;
begin
  if (FServer <> nil) and FServer.Active then
    FServer.Active := False;
end;

procedure TVclE2EAgent.RegisterTouch(const AName: string);
var
  LCount: Integer;
begin
  if AName = '' then Exit;
  if FTouchedControls.TryGetValue(AName, LCount) then
    FTouchedControls[AName] := LCount + 1
  else
    FTouchedControls.Add(AName, 1);
end;

function TVclE2EAgent.IsControlTouched(const AName: string): Boolean;
begin
  Result := (AName <> '') and FTouchedControls.ContainsKey(AName);
end;

function TVclE2EAgent.FindComponentByName(const AName: string): TComponent;
var
  I, J: Integer;
  LForm: TCustomForm;
begin
  Result := nil;
  for I := 0 to Screen.CustomFormCount - 1 do
  begin
    LForm := Screen.CustomForms[I];
    if SameText(LForm.Name, AName) then
      Exit(LForm);

    Result := LForm.FindComponent(AName);
    if Result <> nil then
      Exit;

    // Search recursively in components
    for J := 0 to LForm.ComponentCount - 1 do
    begin
      if SameText(LForm.Components[J].Name, AName) then
        Exit(LForm.Components[J]);
    end;
  end;
end;

function TVclE2EAgent.FindControlByName(const AName: string): TControl;
var
  LComp: TComponent;
begin
  LComp := FindComponentByName(AName);
  if (LComp <> nil) and (LComp is TControl) then
    Result := TControl(LComp)
  else
    Result := nil;
end;

function TVclE2EAgent.DoGetHealth: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('status', 'ok');
  Result.AddPair('app', ExtractFileName(ParamStr(0)));
  Result.AddPair('formsCount', TJSONNumber.Create(Screen.CustomFormCount));
end;

function TVclE2EAgent.DoGetTree: TJSONObject;

  procedure ProcessControl(AControl: TControl; AArr: TJSONArray);
  var
    LObj: TJSONObject;
    LWinCtrl: TWinControl;
    I: Integer;
    LText: string;
    LRttiContext: TRttiContext;
    LRttiType: TRttiType;
    LProp: TRttiProperty;
  begin
    LObj := TJSONObject.Create;
    LObj.AddPair('name', AControl.Name);
    LObj.AddPair('class', AControl.ClassName);
    LObj.AddPair('visible', TJSONBool.Create(AControl.Visible));
    LObj.AddPair('enabled', TJSONBool.Create(AControl.Enabled));
    LObj.AddPair('isGraphicControl', TJSONBool.Create(not (AControl is TWinControl)));
    LObj.AddPair('touched', TJSONBool.Create(IsControlTouched(AControl.Name)));

    LObj.AddPair('left', TJSONNumber.Create(AControl.Left));
    LObj.AddPair('top', TJSONNumber.Create(AControl.Top));
    LObj.AddPair('width', TJSONNumber.Create(AControl.Width));
    LObj.AddPair('height', TJSONNumber.Create(AControl.Height));

    // Try reading Caption or Text via RTTI
    LText := '';
    LRttiContext := TRttiContext.Create;
    try
      LRttiType := LRttiContext.GetType(AControl.ClassType);
      if LRttiType <> nil then
      begin
        LProp := LRttiType.GetProperty('Caption');
        if (LProp <> nil) and (LProp.PropertyType.TypeKind in [tkString, tkUString, tkWChar, tkLString]) then
          LText := LProp.GetValue(AControl).AsString
        else
        begin
          LProp := LRttiType.GetProperty('Text');
          if (LProp <> nil) and (LProp.PropertyType.TypeKind in [tkString, tkUString, tkWChar, tkLString]) then
            LText := LProp.GetValue(AControl).AsString;
        end;
      end;
    finally
      LRttiContext.Free;
    end;
    LObj.AddPair('text', LText);

    AArr.AddElement(LObj);

    if AControl is TWinControl then
    begin
      LWinCtrl := TWinControl(AControl);
      for I := 0 to LWinCtrl.ControlCount - 1 do
        ProcessControl(LWinCtrl.Controls[I], AArr);
    end;
  end;

var
  LFormsArr: TJSONArray;
  LFormObj: TJSONObject;
  LControlsArr: TJSONArray;
  I: Integer;
  LForm: TCustomForm;
begin
  Result := TJSONObject.Create;
  LFormsArr := TJSONArray.Create;
  Result.AddPair('forms', LFormsArr);

  for I := 0 to Screen.CustomFormCount - 1 do
  begin
    LForm := Screen.CustomForms[I];
    LFormObj := TJSONObject.Create;
    LFormObj.AddPair('name', LForm.Name);
    LFormObj.AddPair('class', LForm.ClassName);
    LFormObj.AddPair('caption', LForm.Caption);
    LFormObj.AddPair('visible', TJSONBool.Create(LForm.Visible));

    LControlsArr := TJSONArray.Create;
    LFormObj.AddPair('controls', LControlsArr);

    for var J := 0 to LForm.ControlCount - 1 do
      ProcessControl(LForm.Controls[J], LControlsArr);

    LFormsArr.AddElement(LFormObj);
  end;
end;

function TVclE2EAgent.DoGetCoverage: TJSONObject;
var
  LTotalVisible: Integer;
  LCoveredVisible: Integer;
  LTotalControls: Integer;
  LCoveredList: TJSONArray;
  LUncoveredList: TJSONArray;

  procedure InspectControl(AControl: TControl);
  var
    LIsTouched: Boolean;
    LWinCtrl: TWinControl;
    I: Integer;
  begin
    if AControl.Name <> '' then
    begin
      Inc(LTotalControls);
      LIsTouched := IsControlTouched(AControl.Name);

      if AControl.Visible then
      begin
        Inc(LTotalVisible);
        if LIsTouched then
        begin
          Inc(LCoveredVisible);
          LCoveredList.Add(AControl.Name + ' (' + AControl.ClassName + ')');
        end
        else
          LUncoveredList.Add(AControl.Name + ' (' + AControl.ClassName + ')');
      end
      else
      begin
        if LIsTouched then
          LCoveredList.Add(AControl.Name + ' [Hidden] (' + AControl.ClassName + ')')
        else
          LUncoveredList.Add(AControl.Name + ' [Hidden] (' + AControl.ClassName + ')');
      end;
    end;

    if AControl is TWinControl then
    begin
      LWinCtrl := TWinControl(AControl);
      for I := 0 to LWinCtrl.ControlCount - 1 do
        InspectControl(LWinCtrl.Controls[I]);
    end;
  end;

var
  I, J: Integer;
  LForm: TCustomForm;
  LPercent: Double;
begin
  LTotalVisible := 0;
  LCoveredVisible := 0;
  LTotalControls := 0;
  LCoveredList := TJSONArray.Create;
  LUncoveredList := TJSONArray.Create;

  for I := 0 to Screen.CustomFormCount - 1 do
  begin
    LForm := Screen.CustomForms[I];
    for J := 0 to LForm.ControlCount - 1 do
      InspectControl(LForm.Controls[J]);
  end;

  if LTotalVisible > 0 then
    LPercent := (LCoveredVisible / LTotalVisible) * 100.0
  else
    LPercent := 100.0;

  Result := TJSONObject.Create;
  Result.AddPair('totalControls', TJSONNumber.Create(LTotalControls));
  Result.AddPair('totalVisibleControls', TJSONNumber.Create(LTotalVisible));
  Result.AddPair('coveredVisibleControls', TJSONNumber.Create(LCoveredVisible));
  Result.AddPair('coveragePercent', TJSONNumber.Create(Round(LPercent * 10) / 10.0));
  Result.AddPair('coveredControls', LCoveredList);
  Result.AddPair('uncoveredControls', LUncoveredList);
end;

function TVclE2EAgent.DoGetControlInfo(const AName: string): TJSONObject;
var
  LCtrl: TControl;
  LComp: TComponent;
  LRttiContext: TRttiContext;
  LRttiType: TRttiType;
  LProp: TRttiProperty;
begin
  LComp := FindComponentByName(AName);
  if LComp = nil then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('error', 'Component not found: ' + AName);
    Exit;
  end;

  Result := TJSONObject.Create;
  Result.AddPair('name', LComp.Name);
  Result.AddPair('class', LComp.ClassName);
  Result.AddPair('isControl', TJSONBool.Create(LComp is TControl));

  if LComp is TControl then
  begin
    LCtrl := TControl(LComp);
    Result.AddPair('visible', TJSONBool.Create(LCtrl.Visible));
    Result.AddPair('enabled', TJSONBool.Create(LCtrl.Enabled));
    Result.AddPair('left', TJSONNumber.Create(LCtrl.Left));
    Result.AddPair('top', TJSONNumber.Create(LCtrl.Top));
    Result.AddPair('width', TJSONNumber.Create(LCtrl.Width));
    Result.AddPair('height', TJSONNumber.Create(LCtrl.Height));
    Result.AddPair('isGraphicControl', TJSONBool.Create(not (LCtrl is TWinControl)));
  end;

  if LComp is TSpeedButton then
    Result.AddPair('down', TJSONBool.Create(TSpeedButton(LComp).Down));

  if LComp is TCheckBox then
    Result.AddPair('checked', TJSONBool.Create(TCheckBox(LComp).Checked));

  // RTTI read Caption/Text
  LRttiContext := TRttiContext.Create;
  try
    LRttiType := LRttiContext.GetType(LComp.ClassType);
    if LRttiType <> nil then
    begin
      LProp := LRttiType.GetProperty('Caption');
      if (LProp <> nil) and (LProp.PropertyType.TypeKind in [tkString, tkUString, tkWChar, tkLString]) then
        Result.AddPair('caption', LProp.GetValue(LComp).AsString);

      LProp := LRttiType.GetProperty('Text');
      if (LProp <> nil) and (LProp.PropertyType.TypeKind in [tkString, tkUString, tkWChar, tkLString]) then
        Result.AddPair('text', LProp.GetValue(LComp).AsString);
    end;
  finally
    LRttiContext.Free;
  end;
end;

function TVclE2EAgent.DoClickControl(const AName: string): TJSONObject;
var
  LCtrl: TControl;
  LButton: TButton;
  LSpeedBtn: TSpeedButton;
  LCheckBox: TCheckBox;
begin
  LCtrl := FindControlByName(AName);
  if LCtrl = nil then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('error', 'Control not found: ' + AName);
    Exit;
  end;

  if not LCtrl.Visible then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('error', 'Control is not visible: ' + AName);
    Exit;
  end;

  if not LCtrl.Enabled then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('error', 'Control is disabled: ' + AName);
    Exit;
  end;

  RegisterTouch(AName);

  if LCtrl is TSpeedButton then
  begin
    LSpeedBtn := TSpeedButton(LCtrl);
    if LSpeedBtn.GroupIndex > 0 then
      LSpeedBtn.Down := not LSpeedBtn.Down;
    LSpeedBtn.Click;
  end
  else if LCtrl is TButton then
  begin
    LButton := TButton(LCtrl);
    LButton.Click;
  end
  else if LCtrl is TCheckBox then
  begin
    LCheckBox := TCheckBox(LCtrl);
    LCheckBox.Checked := not LCheckBox.Checked;
    TControlAccess(LCheckBox).Click;
  end
  else
  begin
    // Generic TControl Click using protected method access
    TControlAccess(LCtrl).Click;
  end;

  Result := TJSONObject.Create;
  Result.AddPair('success', TJSONBool.Create(True));
  Result.AddPair('action', 'click');
  Result.AddPair('target', AName);
end;

function TVclE2EAgent.DoSetText(const AName, AText: string): TJSONObject;
var
  LComp: TComponent;
  LRttiContext: TRttiContext;
  LRttiType: TRttiType;
  LProp: TRttiProperty;
  LAssigned: Boolean;
begin
  LComp := FindComponentByName(AName);
  if LComp = nil then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('error', 'Component not found: ' + AName);
    Exit;
  end;

  RegisterTouch(AName);
  LAssigned := False;

  if LComp is TCustomEdit then
  begin
    TCustomEdit(LComp).Text := AText;
    LAssigned := True;
  end
  else
  begin
    LRttiContext := TRttiContext.Create;
    try
      LRttiType := LRttiContext.GetType(LComp.ClassType);
      if LRttiType <> nil then
      begin
        LProp := LRttiType.GetProperty('Text');
        if (LProp <> nil) and LProp.IsWritable then
        begin
          LProp.SetValue(LComp, AText);
          LAssigned := True;
        end
        else
        begin
          LProp := LRttiType.GetProperty('Caption');
          if (LProp <> nil) and LProp.IsWritable then
          begin
            LProp.SetValue(LComp, AText);
            LAssigned := True;
          end;
        end;
      end;
    finally
      LRttiContext.Free;
    end;
  end;

  Result := TJSONObject.Create;
  if LAssigned then
  begin
    Result.AddPair('success', TJSONBool.Create(True));
    Result.AddPair('target', AName);
    Result.AddPair('text', AText);
  end
  else
    Result.AddPair('error', 'Property Text/Caption is not writable on ' + AName);
end;

function TVclE2EAgent.DoGetText(const AName: string; APanelIndex: Integer): TJSONObject;
var
  LComp: TComponent;
  LStatusBar: TStatusBar;
begin
  LComp := FindComponentByName(AName);
  if LComp = nil then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('error', 'Component not found: ' + AName);
    Exit;
  end;

  RegisterTouch(AName);
  Result := TJSONObject.Create;
  Result.AddPair('name', AName);

  if LComp is TStatusBar then
  begin
    LStatusBar := TStatusBar(LComp);
    if (APanelIndex >= 0) and (APanelIndex < LStatusBar.Panels.Count) then
    begin
      Result.AddPair('panelIndex', TJSONNumber.Create(APanelIndex));
      Result.AddPair('text', LStatusBar.Panels[APanelIndex].Text);
    end
    else
    begin
      Result.AddPair('simpleText', LStatusBar.SimpleText);
      var LPanelsArr := TJSONArray.Create;
      for var I := 0 to LStatusBar.Panels.Count - 1 do
        LPanelsArr.Add(LStatusBar.Panels[I].Text);
      Result.AddPair('panels', LPanelsArr);
    end;
    Exit;
  end;

  if LComp is TCustomEdit then
    Result.AddPair('text', TCustomEdit(LComp).Text)
  else
  begin
    var LRttiContext := TRttiContext.Create;
    try
      var LRttiType := LRttiContext.GetType(LComp.ClassType);
      if LRttiType <> nil then
      begin
        var LProp := LRttiType.GetProperty('Text');
        if (LProp <> nil) and (LProp.PropertyType.TypeKind in [tkString, tkUString, tkWChar, tkLString]) then
          Result.AddPair('text', LProp.GetValue(LComp).AsString)
        else
        begin
          LProp := LRttiType.GetProperty('Caption');
          if (LProp <> nil) and (LProp.PropertyType.TypeKind in [tkString, tkUString, tkWChar, tkLString]) then
            Result.AddPair('text', LProp.GetValue(LComp).AsString)
          else
            Result.AddPair('text', '');
        end;
      end;
    finally
      LRttiContext.Free;
    end;
  end;
end;

function TVclE2EAgent.DoGridAction(const AName, AAction, AField, AValue: string): TJSONObject;
var
  LComp: TComponent;
  LGrid: TDBGrid;
  LDS: TDataSet;
  LFieldsObj: TJSONObject;
  I: Integer;
begin
  LComp := FindComponentByName(AName);
  if (LComp = nil) or not (LComp is TDBGrid) then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('error', 'TDBGrid component not found: ' + AName);
    Exit;
  end;

  RegisterTouch(AName);
  LGrid := TDBGrid(LComp);
  if (LGrid.DataSource = nil) or (LGrid.DataSource.DataSet = nil) then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('error', 'DBGrid has no DataSource/DataSet attached');
    Exit;
  end;

  LDS := LGrid.DataSource.DataSet;

  if SameText(AAction, 'next') then
    LDS.Next
  else if SameText(AAction, 'prior') then
    LDS.Prior
  else if SameText(AAction, 'first') then
    LDS.First
  else if SameText(AAction, 'last') then
    LDS.Last
  else if SameText(AAction, 'locate') then
  begin
    if not LDS.Locate(AField, AValue, [loCaseInsensitive]) then
    begin
      Result := TJSONObject.Create;
      Result.AddPair('error', Format('Record not found with %s = %s', [AField, AValue]));
      Exit;
    end;
  end;

  // Return current record state
  Result := TJSONObject.Create;
  Result.AddPair('success', TJSONBool.Create(True));
  Result.AddPair('action', AAction);
  Result.AddPair('recNo', TJSONNumber.Create(LDS.RecNo));
  Result.AddPair('recordCount', TJSONNumber.Create(LDS.RecordCount));
  Result.AddPair('bof', TJSONBool.Create(LDS.Bof));
  Result.AddPair('eof', TJSONBool.Create(LDS.Eof));

  LFieldsObj := TJSONObject.Create;
  for I := 0 to LDS.FieldCount - 1 do
    LFieldsObj.AddPair(LDS.Fields[I].FieldName, LDS.Fields[I].AsString);
  Result.AddPair('record', LFieldsObj);
end;

procedure TVclE2EAgent.ServerCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  LDoc: string;
  LBodyText: string;
  LJsonBody: TJSONObject;
  LResponseJson: TJSONObject;
  LTargetName: string;
  LTextVal: string;
  LActionVal: string;
  LFieldVal: string;
  LValueVal: string;
  LPanelIdx: Integer;
begin
  AResponseInfo.ContentType := 'application/json; charset=utf-8';
  AResponseInfo.CustomHeaders.Values['Access-Control-Allow-Origin'] := '*';

  if ARequestInfo.CommandType = hcOPTION then
  begin
    AResponseInfo.CustomHeaders.Values['Access-Control-Allow-Methods'] := 'GET, POST, OPTIONS';
    AResponseInfo.CustomHeaders.Values['Access-Control-Allow-Headers'] := 'Content-Type';
    AResponseInfo.ResponseNo := 200;
    Exit;
  end;

  LDoc := LowerCase(ARequestInfo.Document);
  LResponseJson := nil;

  // Extract POST body if present
  LJsonBody := nil;
  if (ARequestInfo.PostStream <> nil) and (ARequestInfo.PostStream.Size > 0) then
  begin
    var LStrStream := TStringStream.Create('', TEncoding.UTF8);
    try
      ARequestInfo.PostStream.Position := 0;
      LStrStream.CopyFrom(ARequestInfo.PostStream, ARequestInfo.PostStream.Size);
      LBodyText := LStrStream.DataString;
      if LBodyText <> '' then
      begin
        var LVal := TJSONObject.ParseJSONValue(LBodyText);
        if LVal is TJSONObject then
          LJsonBody := TJSONObject(LVal)
        else if LVal <> nil then
          LVal.Free;
      end;
    finally
      LStrStream.Free;
    end;
  end;

  try
    try
      // /health or /api/health
      if (LDoc = '/health') or (LDoc = '/api/health') then
      begin
        RunInUI(procedure
        begin
          LResponseJson := DoGetHealth;
        end);
      end
      // /api/tree or /api/inspect
      else if (LDoc = '/api/tree') or (LDoc = '/api/inspect') then
      begin
        RunInUI(procedure
        begin
          LResponseJson := DoGetTree;
        end);
      end
      // /api/coverage
      else if LDoc = '/api/coverage' then
      begin
        RunInUI(procedure
        begin
          LResponseJson := DoGetCoverage;
        end);
      end
      // /api/control (GET or POST)
      else if LDoc = '/api/control' then
      begin
        LTargetName := ARequestInfo.Params.Values['name'];
        if (LTargetName = '') and (LJsonBody <> nil) and (LJsonBody.Values['name'] <> nil) then
          LTargetName := LJsonBody.Values['name'].Value;

        RunInUI(procedure
        begin
          LResponseJson := DoGetControlInfo(LTargetName);
        end);
      end
      // /api/click (POST)
      else if LDoc = '/api/click' then
      begin
        LTargetName := '';
        if LJsonBody <> nil then
        begin
          if LJsonBody.Values['name'] <> nil then
            LTargetName := LJsonBody.Values['name'].Value;
        end;
        if LTargetName = '' then
          LTargetName := ARequestInfo.Params.Values['name'];

        RunInUI(procedure
        begin
          LResponseJson := DoClickControl(LTargetName);
        end);
      end
      // /api/set-text (POST)
      else if LDoc = '/api/set-text' then
      begin
        LTargetName := '';
        LTextVal := '';
        if LJsonBody <> nil then
        begin
          if LJsonBody.Values['name'] <> nil then
            LTargetName := LJsonBody.Values['name'].Value;
          if LJsonBody.Values['text'] <> nil then
            LTextVal := LJsonBody.Values['text'].Value;
        end;
        if LTargetName = '' then
          LTargetName := ARequestInfo.Params.Values['name'];
        if LTextVal = '' then
          LTextVal := ARequestInfo.Params.Values['text'];

        RunInUI(procedure
        begin
          LResponseJson := DoSetText(LTargetName, LTextVal);
        end);
      end
      // /api/get-text (GET or POST)
      else if LDoc = '/api/get-text' then
      begin
        LTargetName := ARequestInfo.Params.Values['name'];
        LPanelIdx := StrToIntDef(ARequestInfo.Params.Values['panel'], -1);
        if (LTargetName = '') and (LJsonBody <> nil) and (LJsonBody.Values['name'] <> nil) then
          LTargetName := LJsonBody.Values['name'].Value;
        if (LPanelIdx = -1) and (LJsonBody <> nil) and (LJsonBody.Values['panel'] <> nil) then
          LPanelIdx := StrToIntDef(LJsonBody.Values['panel'].Value, -1);

        RunInUI(procedure
        begin
          LResponseJson := DoGetText(LTargetName, LPanelIdx);
        end);
      end
      // /api/grid (GET or POST)
      else if LDoc = '/api/grid' then
      begin
        LTargetName := 'DBGrid1';
        LActionVal := 'current';
        LFieldVal := '';
        LValueVal := '';

        if LJsonBody <> nil then
        begin
          if LJsonBody.Values['name'] <> nil then
            LTargetName := LJsonBody.Values['name'].Value;
          if LJsonBody.Values['action'] <> nil then
            LActionVal := LJsonBody.Values['action'].Value;
          if LJsonBody.Values['field'] <> nil then
            LFieldVal := LJsonBody.Values['field'].Value;
          if LJsonBody.Values['value'] <> nil then
            LValueVal := LJsonBody.Values['value'].Value;
        end
        else
        begin
          if ARequestInfo.Params.Values['name'] <> '' then
            LTargetName := ARequestInfo.Params.Values['name'];
          if ARequestInfo.Params.Values['action'] <> '' then
            LActionVal := ARequestInfo.Params.Values['action'];
          if ARequestInfo.Params.Values['field'] <> '' then
            LFieldVal := ARequestInfo.Params.Values['field'];
          if ARequestInfo.Params.Values['value'] <> '' then
            LValueVal := ARequestInfo.Params.Values['value'];
        end;

        RunInUI(procedure
        begin
          LResponseJson := DoGridAction(LTargetName, LActionVal, LFieldVal, LValueVal);
        end);
      end
      else
      begin
        AResponseInfo.ResponseNo := 404;
        LResponseJson := TJSONObject.Create;
        LResponseJson.AddPair('error', 'Endpoint not found: ' + ARequestInfo.Document);
      end;

      if LResponseJson <> nil then
      begin
        if LResponseJson.Values['error'] <> nil then
          AResponseInfo.ResponseNo := 400
        else if AResponseInfo.ResponseNo = 0 then
          AResponseInfo.ResponseNo := 200;

        AResponseInfo.ContentText := LResponseJson.ToJSON;
      end;
    except
      on E: Exception do
      begin
        AResponseInfo.ResponseNo := 500;
        var LErrObj := TJSONObject.Create;
        try
          LErrObj.AddPair('error', E.ClassName + ': ' + E.Message);
          AResponseInfo.ContentText := LErrObj.ToJSON;
        finally
          LErrObj.Free;
        end;
      end;
    end;
  finally
    LJsonBody.Free;
    LResponseJson.Free;
  end;
end;

end.
