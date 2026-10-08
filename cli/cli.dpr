program cli;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  VclE2E.Client in 'VclE2E.Client.pas',
  VclE2E.Scenarios in 'VclE2E.Scenarios.pas',
  TestVclE2EClient in 'tests\TestVclE2EClient.pas';

procedure PrintUsage;
begin
  Writeln('================================================================');
  Writeln(' VCL E2E Test Runner & Automation CLI');
  Writeln('================================================================');
  Writeln('Usage: cli [options]');
  Writeln('');
  Writeln('Options:');
  Writeln('  --run-all                  Run all built-in test scenarios (default)');
  Writeln('  --unit-tests               Run DUnitX unit tests for CLI');
  Writeln('  --scenario <name>          Run a specific scenario (health, tree, speedbutton, edit, grid)');
  Writeln('  --coverage                 Display current automation coverage report');
  Writeln('  --tree                     Inspect and dump component tree');
  Writeln('  --click <name>             Click on a control');
  Writeln('  --set-text <name> <text>   Set text on a control (TEdit, TLabel, etc.)');
  Writeln('  --get-text <name> [panel]  Get text from a control or StatusBar panel');
  Writeln('  --grid <action>            Navigate DBGrid1 (first, next, prior, last)');
  Writeln('  --host <ip>                Target host (default: 127.0.0.1)');
  Writeln('  --port <port>              Target port (default: 8080)');
  Writeln('  --help, -h                 Show this help screen');
  Writeln('');
end;

function RunUnitTests: Integer;
var
  LRunner: ITestRunner;
  LResults: IRunResults;
  LLogger: ITestLogger;
begin
  Writeln('Starting DUnitX Unit Tests...');
  LRunner := TDUnitX.CreateRunner;
  LRunner.UseRTTI := True;
  LLogger := TDUnitXConsoleLogger.Create(True);
  LRunner.AddLogger(LLogger);
  LResults := LRunner.Execute;
  if LResults.AllPassed then
    Result := 0
  else
    Result := 1;
end;

procedure PrintBanner;
begin
  Writeln('================================================================');
  Writeln('          VCL E2E Test Runner - Delphi Win32 Console            ');
  Writeln('================================================================');
end;

procedure DumpTree(AValue: TJSONValue; AIndent: string = '');
var
  LObj: TJSONObject;
  LArr: TJSONArray;
  I: Integer;
begin
  if AValue is TJSONObject then
  begin
    LObj := TJSONObject(AValue);
    if LObj.Values['name'] <> nil then
    begin
      var LName := LObj.Values['name'].Value;
      var LClass := '';
      var LText := '';
      var LVis := '';
      if LObj.Values['class'] <> nil then LClass := LObj.Values['class'].Value;
      if LObj.Values['text'] <> nil then LText := LObj.Values['text'].Value;
      if (LText = '') and (LObj.Values['caption'] <> nil) then LText := LObj.Values['caption'].Value;
      if LObj.Values['visible'] <> nil then LVis := LObj.Values['visible'].Value;

      Writeln(Format('%s* [%s] "%s" (Class: %s, Vis: %s)', [AIndent, LName, LText, LClass, LVis]));
    end;

    for I := 0 to LObj.Count - 1 do
    begin
      var LPair := LObj.Pairs[I];
      if (LPair.JsonValue is TJSONArray) or (LPair.JsonValue is TJSONObject) then
        DumpTree(LPair.JsonValue, AIndent + '  ');
    end;
  end
  else if AValue is TJSONArray then
  begin
    LArr := TJSONArray(AValue);
    for I := 0 to LArr.Count - 1 do
      DumpTree(LArr.Items[I], AIndent);
  end;
end;

var
  LHost: string;
  LPort: Integer;
  LMode: string;
  LParamVal1: string;
  LParamVal2: string;
  I: Integer;
  LArg: string;
  LClient: TVclE2EClient;
  LRunner: TScenarioRunner;
  LResults: TArray<TTestResult>;
  LAllPassed: Boolean;
  LCovSummary: string;
  LSingleRes: TTestResult;

begin
  LHost := '127.0.0.1';
  LPort := 8080;
  LMode := 'run-all';
  LParamVal1 := '';
  LParamVal2 := '';

  I := 1;
  while I <= ParamCount do
  begin
    LArg := ParamStr(I);
    if (LArg = '--help') or (LArg = '-h') then
    begin
      PrintUsage;
      ExitCode := 0;
      Exit;
    end
    else if LArg = '--run-all' then
      LMode := 'run-all'
    else if LArg = '--unit-tests' then
      LMode := 'unit-tests'
    else if LArg = '--coverage' then
      LMode := 'coverage'
    else if LArg = '--tree' then
      LMode := 'tree'
    else if LArg = '--scenario' then
    begin
      LMode := 'scenario';
      Inc(I);
      if I <= ParamCount then LParamVal1 := ParamStr(I);
    end
    else if LArg = '--click' then
    begin
      LMode := 'click';
      Inc(I);
      if I <= ParamCount then LParamVal1 := ParamStr(I);
    end
    else if LArg = '--set-text' then
    begin
      LMode := 'set-text';
      Inc(I);
      if I <= ParamCount then LParamVal1 := ParamStr(I);
      Inc(I);
      if I <= ParamCount then LParamVal2 := ParamStr(I);
    end
    else if LArg = '--get-text' then
    begin
      LMode := 'get-text';
      Inc(I);
      if I <= ParamCount then LParamVal1 := ParamStr(I);
      if (I + 1 <= ParamCount) and not ParamStr(I + 1).StartsWith('--') then
      begin
        Inc(I);
        LParamVal2 := ParamStr(I);
      end;
    end
    else if LArg = '--grid' then
    begin
      LMode := 'grid';
      Inc(I);
      if I <= ParamCount then LParamVal1 := ParamStr(I);
    end
    else if LArg = '--host' then
    begin
      Inc(I);
      if I <= ParamCount then LHost := ParamStr(I);
    end
    else if LArg = '--port' then
    begin
      Inc(I);
      if I <= ParamCount then LPort := StrToIntDef(ParamStr(I), 8080);
    end
    else if LArg.StartsWith('--port=') then
      LPort := StrToIntDef(LArg.Substring(7), 8080)
    else if LArg.StartsWith('--host=') then
      LHost := LArg.Substring(7);

    Inc(I);
  end;

  PrintBanner;

  if LMode = 'unit-tests' then
  begin
    ExitCode := RunUnitTests;
    Exit;
  end;

  Writeln(Format('Connecting to agent at %s:%d ...', [LHost, LPort]));
  Writeln('');

  LClient := TVclE2EClient.Create(LHost, LPort);
  try
    try
      if LMode = 'run-all' then
      begin
        Writeln('Starting execution of built-in test suite:');
        Writeln('----------------------------------------------------------------');

        LRunner := TScenarioRunner.Create(LClient);
        try
          LResults := LRunner.RunAll(LAllPassed);

          for var Res in LResults do
          begin
            if Res.Passed then
              Writeln(Format('  [PASS] %-32s (%4d ms) : %s', [Res.Name, Res.ElapsedMs, Res.Details]))
            else
              Writeln(Format('  [FAIL] %-32s (%4d ms) : %s', [Res.Name, Res.ElapsedMs, Res.Details]));
          end;

          Writeln('----------------------------------------------------------------');
          if LAllPassed then
          begin
            Writeln('RESULT: ALL TESTS PASSED SUCCESSFULLY! [OK]');
            ExitCode := 0;
          end
          else
          begin
            Writeln('RESULT: SOME TESTS FAILED! [FAILED]');
            ExitCode := 1;
          end;

          // Also print coverage
          if LRunner.TestCoverageReport(LCovSummary).Passed then
          begin
            Writeln('');
            Writeln(LCovSummary);
          end;
        finally
          LRunner.Free;
        end;
      end
      else if LMode = 'scenario' then
      begin
        LRunner := TScenarioRunner.Create(LClient);
        try
          var LScenName := LowerCase(LParamVal1);
          if (LScenName = 'health') then
            LSingleRes := LRunner.TestHealthCheck
          else if (LScenName = 'tree') then
            LSingleRes := LRunner.TestTreeInspection
          else if (LScenName = 'speedbutton') or (LScenName = 'btn') then
            LSingleRes := LRunner.TestSpeedButtonToggle
          else if (LScenName = 'edit') or (LScenName = 'button') then
            LSingleRes := LRunner.TestEditAndButton
          else if (LScenName = 'grid') then
            LSingleRes := LRunner.TestGridNavigation
          else
          begin
            Writeln('Unknown scenario: ' + LParamVal1);
            ExitCode := 1;
            Exit;
          end;

          if LSingleRes.Passed then
          begin
            Writeln(Format('[PASS] %s (%d ms): %s', [LSingleRes.Name, LSingleRes.ElapsedMs, LSingleRes.Details]));
            ExitCode := 0;
          end
          else
          begin
            Writeln(Format('[FAIL] %s (%d ms): %s', [LSingleRes.Name, LSingleRes.ElapsedMs, LSingleRes.Details]));
            ExitCode := 1;
          end;
        finally
          LRunner.Free;
        end;
      end
      else if LMode = 'coverage' then
      begin
        LRunner := TScenarioRunner.Create(LClient);
        try
          if LRunner.TestCoverageReport(LCovSummary).Passed then
          begin
            Writeln(LCovSummary);
            ExitCode := 0;
          end
          else
          begin
            Writeln('[ERROR] Failed to retrieve coverage report.');
            ExitCode := 1;
          end;
        finally
          LRunner.Free;
        end;
      end
      else if LMode = 'tree' then
      begin
        var LTree := LClient.GetTree;
        try
          Writeln('Component hierarchy tree:');
          DumpTree(LTree);
          ExitCode := 0;
        finally
          LTree.Free;
        end;
      end
      else if LMode = 'click' then
      begin
        if LParamVal1 = '' then
        begin
          Writeln('[ERROR] Control name required for --click');
          ExitCode := 1;
          Exit;
        end;

        if LClient.Click(LParamVal1) then
        begin
          Writeln(Format('[OK] Successfully clicked "%s"', [LParamVal1]));
          ExitCode := 0;
        end
        else
        begin
          Writeln(Format('[FAIL] Could not click "%s"', [LParamVal1]));
          ExitCode := 1;
        end;
      end
      else if LMode = 'set-text' then
      begin
        if (LParamVal1 = '') then
        begin
          Writeln('[ERROR] Control name and text required for --set-text');
          ExitCode := 1;
          Exit;
        end;

        if LClient.SetText(LParamVal1, LParamVal2) then
        begin
          Writeln(Format('[OK] Set text of "%s" to "%s"', [LParamVal1, LParamVal2]));
          ExitCode := 0;
        end
        else
        begin
          Writeln(Format('[FAIL] Failed to set text on "%s"', [LParamVal1]));
          ExitCode := 1;
        end;
      end
      else if LMode = 'get-text' then
      begin
        if LParamVal1 = '' then
        begin
          Writeln('[ERROR] Control name required for --get-text');
          ExitCode := 1;
          Exit;
        end;

        var LPanel := StrToIntDef(LParamVal2, -1);
        var LText := LClient.GetText(LParamVal1, LPanel);
        Writeln(Format('[OK] Text for "%s" = "%s"', [LParamVal1, LText]));
        ExitCode := 0;
      end
      else if LMode = 'grid' then
      begin
        var LAction := LParamVal1;
        if LAction = '' then LAction := 'next';
        var LRecNo, LRecCount: Integer;
        var LFields: TJSONObject;

        if LClient.GridAction('DBGrid1', LAction, LRecNo, LRecCount, LFields) then
        begin
          try
            Writeln(Format('[OK] Grid action "%s": Record %d of %d', [LAction, LRecNo, LRecCount]));
            if LFields <> nil then
              Writeln('  Row values: ' + LFields.ToJSON);
          finally
            LFields.Free;
          end;
          ExitCode := 0;
        end
        else
        begin
          Writeln(Format('[FAIL] Grid action "%s" failed', [LAction]));
          ExitCode := 1;
        end;
      end;
    except
      on E: Exception do
      begin
        Writeln(Format('[ERROR] %s: %s', [E.ClassName, E.Message]));
        ExitCode := 2;
      end;
    end;
  finally
    LClient.Free;
  end;
end.
