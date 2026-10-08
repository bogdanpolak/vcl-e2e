unit VclE2E.Scenarios;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  System.Generics.Collections,
  System.JSON,
  VclE2E.Client;

type
  TTestResult = record
    Name: string;
    Passed: Boolean;
    Details: string;
    ElapsedMs: Int64;
  end;

  TScenarioRunner = class
  private
    FClient: TVclE2EClient;
  public
    constructor Create(AClient: TVclE2EClient);

    function TestHealthCheck: TTestResult;
    function TestTreeInspection: TTestResult;
    function TestSpeedButtonToggle: TTestResult;
    function TestEditAndButton: TTestResult;
    function TestGridNavigation: TTestResult;
    function TestCoverageReport(out ACoverageSummary: string): TTestResult;

    function RunAll(out AAllPassed: Boolean): TArray<TTestResult>;
  end;

implementation

{ TScenarioRunner }

constructor TScenarioRunner.Create(AClient: TVclE2EClient);
begin
  inherited Create;
  FClient := AClient;
end;

function TScenarioRunner.TestHealthCheck: TTestResult;
var
  LSw: TStopwatch;
  LApp: string;
  LFormsCount: Integer;
begin
  Result.Name := 'HealthCheck';
  LSw := TStopwatch.StartNew;
  try
    if FClient.HealthCheck(LApp, LFormsCount) then
    begin
      Result.Passed := True;
      Result.Details := Format('App: "%s", Active forms: %d', [LApp, LFormsCount]);
    end
    else
    begin
      Result.Passed := False;
      Result.Details := 'Server responded but status was not OK';
    end;
  except
    on E: Exception do
    begin
      Result.Passed := False;
      Result.Details := 'Exception: ' + E.Message;
    end;
  end;
  LSw.Stop;
  Result.ElapsedMs := LSw.ElapsedMilliseconds;
end;

function TScenarioRunner.TestTreeInspection: TTestResult;
var
  LSw: TStopwatch;
  LTree: TJSONObject;
  LFormsArr: TJSONArray;
begin
  Result.Name := 'TreeInspection';
  LSw := TStopwatch.StartNew;
  try
    LTree := FClient.GetTree;
    try
      LFormsArr := LTree.Values['forms'] as TJSONArray;
      if (LFormsArr <> nil) and (LFormsArr.Count > 0) then
      begin
        Result.Passed := True;
        Result.Details := Format('Inspected %d form(s) successfully', [LFormsArr.Count]);
      end
      else
      begin
        Result.Passed := False;
        Result.Details := 'No forms found in inspection tree';
      end;
    finally
      LTree.Free;
    end;
  except
    on E: Exception do
    begin
      Result.Passed := False;
      Result.Details := 'Exception: ' + E.Message;
    end;
  end;
  LSw.Stop;
  Result.ElapsedMs := LSw.ElapsedMilliseconds;
end;

function TScenarioRunner.TestSpeedButtonToggle: TTestResult;
var
  LSw: TStopwatch;
  LText1, LText2: string;
  LState1, LState2: TJSONObject;
  LDown1, LDown2: Boolean;
begin
  Result.Name := 'SpeedButtonToggle (TGraphicControl)';
  LSw := TStopwatch.StartNew;
  try
    // Click sbToggleBold to turn it ON
    if not FClient.Click('sbToggleBold') then
    begin
      Result.Passed := False;
      Result.Details := 'Failed to click sbToggleBold';
      Exit;
    end;

    LState1 := FClient.GetControlInfo('sbToggleBold');
    try
      LDown1 := (LState1.Values['down'] <> nil) and SameText(LState1.Values['down'].Value, 'true');
    finally
      LState1.Free;
    end;

    LText1 := FClient.GetText('StatusBar1', 2);

    // Click sbToggleBold again to turn it OFF
    if not FClient.Click('sbToggleBold') then
    begin
      Result.Passed := False;
      Result.Details := 'Failed to click sbToggleBold second time';
      Exit;
    end;

    LState2 := FClient.GetControlInfo('sbToggleBold');
    try
      LDown2 := (LState2.Values['down'] <> nil) and SameText(LState2.Values['down'].Value, 'true');
    finally
      LState2.Free;
    end;

    LText2 := FClient.GetText('StatusBar1', 2);

    if LDown1 and (not LDown2) and (LText1 = 'Bold: ON') and (LText2 = 'Bold: OFF') then
    begin
      Result.Passed := True;
      Result.Details := Format('Toggled ON ("%s") and OFF ("%s") verified on StatusBar', [LText1, LText2]);
    end
    else
    begin
      Result.Passed := False;
      Result.Details := Format('Unexpected state: Down1=%s, Down2=%s, Text1="%s", Text2="%s"',
        [BoolToStr(LDown1, True), BoolToStr(LDown2, True), LText1, LText2]);
    end;
  except
    on E: Exception do
    begin
      Result.Passed := False;
      Result.Details := 'Exception: ' + E.Message;
    end;
  end;
  LSw.Stop;
  Result.ElapsedMs := LSw.ElapsedMilliseconds;
end;

function TScenarioRunner.TestEditAndButton: TTestResult;
var
  LSw: TStopwatch;
  LTestItemName: string;
  LStatusText: string;
  LLabelStatus: string;
begin
  Result.Name := 'EditAndButtonAction';
  LSw := TStopwatch.StartNew;
  try
    LTestItemName := 'AutoTest Item ' + FormatDateTime('hhnnss', Now);

    // 1. Set text into edtItemName
    if not FClient.SetText('edtItemName', LTestItemName) then
    begin
      Result.Passed := False;
      Result.Details := 'Failed to set text into edtItemName';
      Exit;
    end;

    // 2. Click chkActive
    FClient.Click('chkActive');

    // 3. Click btnAddItem
    if not FClient.Click('btnAddItem') then
    begin
      Result.Passed := False;
      Result.Details := 'Failed to click btnAddItem';
      Exit;
    end;

    // 4. Verify StatusBar panel 0
    LStatusText := FClient.GetText('StatusBar1', 0);
    LLabelStatus := FClient.GetText('lblStatus');

    if Pos(LTestItemName, LStatusText) > 0 then
    begin
      Result.Passed := True;
      Result.Details := Format('Added "%s", StatusBar: "%s", lblStatus: "%s"',
        [LTestItemName, LStatusText, LLabelStatus]);
    end
    else
    begin
      Result.Passed := False;
      Result.Details := Format('StatusBar panel 0 does not contain "%s". Actual: "%s"',
        [LTestItemName, LStatusText]);
    end;
  except
    on E: Exception do
    begin
      Result.Passed := False;
      Result.Details := 'Exception: ' + E.Message;
    end;
  end;
  LSw.Stop;
  Result.ElapsedMs := LSw.ElapsedMilliseconds;
end;

function TScenarioRunner.TestGridNavigation: TTestResult;
var
  LSw: TStopwatch;
  LRecNo1, LRecCount1: Integer;
  LRecNo2, LRecCount2: Integer;
  LFields1, LFields2: TJSONObject;
  LStatusPanel1: string;
begin
  Result.Name := 'DBGridNavigation (TFDMemTable)';
  LSw := TStopwatch.StartNew;
  try
    // First record
    if not FClient.GridAction('DBGrid1', 'first', LRecNo1, LRecCount1, LFields1) then
    begin
      Result.Passed := False;
      Result.Details := 'Failed to move to first record';
      Exit;
    end;
    LFields1.Free;

    // Next record
    if not FClient.GridAction('DBGrid1', 'next', LRecNo2, LRecCount2, LFields2) then
    begin
      Result.Passed := False;
      Result.Details := 'Failed to navigate next in DBGrid1';
      Exit;
    end;

    LStatusPanel1 := FClient.GetText('StatusBar1', 1);

    var LCurrentItemName := '';
    if (LFields2 <> nil) and (LFields2.Values['Name'] <> nil) then
      LCurrentItemName := LFields2.Values['Name'].Value;
    LFields2.Free;

    if (LRecNo2 = 2) and (Pos('Record 2 of', LStatusPanel1) > 0) then
    begin
      Result.Passed := True;
      Result.Details := Format('Navigated from Rec %d to Rec %d/%d (Item: "%s", Status: "%s")',
        [LRecNo1, LRecNo2, LRecCount2, LCurrentItemName, LStatusPanel1]);
    end
    else
    begin
      Result.Passed := False;
      Result.Details := Format('Navigation mismatch: RecNo=%d, StatusPanel="%s"',
        [LRecNo2, LStatusPanel1]);
    end;
  except
    on E: Exception do
    begin
      Result.Passed := False;
      Result.Details := 'Exception: ' + E.Message;
    end;
  end;
  LSw.Stop;
  Result.ElapsedMs := LSw.ElapsedMilliseconds;
end;

function TScenarioRunner.TestCoverageReport(out ACoverageSummary: string): TTestResult;
var
  LSw: TStopwatch;
  LCovJson: TJSONObject;
  LTotal, LTotalVis, LCoveredVis: Integer;
  LPercent: Double;
  LCoveredArr, LUncoveredArr: TJSONArray;
  LSb: TStringBuilder;
  I: Integer;
begin
  Result.Name := 'AutomationCoverage';
  ACoverageSummary := '';
  LSw := TStopwatch.StartNew;
  try
    LCovJson := FClient.GetCoverage;
    try
      LTotal := StrToIntDef(LCovJson.Values['totalControls'].Value, 0);
      LTotalVis := StrToIntDef(LCovJson.Values['totalVisibleControls'].Value, 0);
      LCoveredVis := StrToIntDef(LCovJson.Values['coveredVisibleControls'].Value, 0);
      LPercent := StrToFloatDef(LCovJson.Values['coveragePercent'].Value, 0.0, TFormatSettings.Invariant);

      LCoveredArr := LCovJson.Values['coveredControls'] as TJSONArray;
      LUncoveredArr := LCovJson.Values['uncoveredControls'] as TJSONArray;

      LSb := TStringBuilder.Create;
      try
        LSb.AppendLine('----------------------------------------------------');
        LSb.AppendLine('             VCL E2E COVERAGE REPORT                ');
        LSb.AppendLine('----------------------------------------------------');
        LSb.AppendLine(Format('Total controls found:       %d', [LTotal]));
        LSb.AppendLine(Format('Visible controls:           %d', [LTotalVis]));
        LSb.AppendLine(Format('Automated (Touched):        %d', [LCoveredVis]));
        LSb.AppendLine(Format('Coverage:                   %.1f%%', [LPercent]));
        LSb.AppendLine('');
        LSb.AppendLine('Covered controls:');
        if LCoveredArr <> nil then
        begin
          for I := 0 to LCoveredArr.Count - 1 do
            LSb.AppendLine('  [+] ' + LCoveredArr.Items[I].Value);
        end;

        LSb.AppendLine('');
        LSb.AppendLine('Uncovered (Visible but not touched):');
        if LUncoveredArr <> nil then
        begin
          for I := 0 to LUncoveredArr.Count - 1 do
            LSb.AppendLine('  [-] ' + LUncoveredArr.Items[I].Value);
        end;
        LSb.AppendLine('----------------------------------------------------');

        ACoverageSummary := LSb.ToString;
      finally
        LSb.Free;
      end;

      Result.Passed := True;
      Result.Details := Format('Coverage: %.1f%% (%d/%d visible controls touched)',
        [LPercent, LCoveredVis, LTotalVis]);
    finally
      LCovJson.Free;
    end;
  except
    on E: Exception do
    begin
      Result.Passed := False;
      Result.Details := 'Exception: ' + E.Message;
    end;
  end;
  LSw.Stop;
  Result.ElapsedMs := LSw.ElapsedMilliseconds;
end;

function TScenarioRunner.RunAll(out AAllPassed: Boolean): TArray<TTestResult>;
var
  LCovSummary: string;
begin
  SetLength(Result, 6);
  AAllPassed := True;

  Result[0] := TestHealthCheck;
  if not Result[0].Passed then AAllPassed := False;

  Result[1] := TestTreeInspection;
  if not Result[1].Passed then AAllPassed := False;

  Result[2] := TestSpeedButtonToggle;
  if not Result[2].Passed then AAllPassed := False;

  Result[3] := TestEditAndButton;
  if not Result[3].Passed then AAllPassed := False;

  Result[4] := TestGridNavigation;
  if not Result[4].Passed then AAllPassed := False;

  Result[5] := TestCoverageReport(LCovSummary);
  if not Result[5].Passed then AAllPassed := False;
end;

end.
