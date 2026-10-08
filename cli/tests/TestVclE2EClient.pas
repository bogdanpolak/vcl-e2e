unit TestVclE2EClient;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.NetEncoding,
  VclE2E.Client;

type
  [TestFixture]
  TTestVclE2E = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestUrlEncoding;

    [Test]
    procedure TestTreeJsonParsing;

    [Test]
    procedure TestCoverageJsonParsing;

    [Test]
    procedure TestGridResponseParsing;

    [Test]
    procedure TestControlInfoParsing;
  end;

implementation

{ TTestVclE2E }

procedure TTestVclE2E.Setup;
begin
end;

procedure TTestVclE2E.TearDown;
begin
end;

procedure TTestVclE2E.TestUrlEncoding;
var
  LOriginal: string;
  LEncoded: string;
begin
  LOriginal := 'Test Button & Special / Chars';
  LEncoded := TNetEncoding.URL.Encode(LOriginal);
  Assert.AreNotEqual(LOriginal, LEncoded, 'Encoded string should differ from original with special characters');
  Assert.IsTrue((Pos('%20', LEncoded) > 0) or (Pos('+', LEncoded) > 0) or (Pos('%26', LEncoded) > 0),
    'Special characters or spaces should be URL encoded');
end;

procedure TTestVclE2E.TestTreeJsonParsing;
var
  LJsonStr: string;
  LJson: TJSONObject;
  LFormsArr: TJSONArray;
  LFormObj: TJSONObject;
  LControlsArr: TJSONArray;
begin
  LJsonStr := '{"forms":[{"name":"frmMain","class":"TfrmMain","caption":"Demo","visible":true,' +
              '"controls":[{"name":"sbToggleBold","class":"TSpeedButton","visible":true,"enabled":true,"isGraphicControl":true},' +
              '{"name":"StatusBar1","class":"TStatusBar","visible":true,"enabled":true,"isGraphicControl":false}]}]}';

  LJson := TJSONObject.ParseJSONValue(LJsonStr) as TJSONObject;
  Assert.IsNotNull(LJson, 'Parsed JSON must not be null');
  try
    LFormsArr := LJson.Values['forms'] as TJSONArray;
    Assert.IsNotNull(LFormsArr, 'Forms array must exist');
    Assert.AreEqual(1, LFormsArr.Count, 'Should have 1 form');

    LFormObj := LFormsArr.Items[0] as TJSONObject;
    Assert.AreEqual('frmMain', LFormObj.Values['name'].Value, 'Form name should match');

    LControlsArr := LFormObj.Values['controls'] as TJSONArray;
    Assert.IsNotNull(LControlsArr, 'Controls array should exist');
    Assert.AreEqual(2, LControlsArr.Count, 'Should have 2 controls');

    var LCtrl0 := LControlsArr.Items[0] as TJSONObject;
    Assert.AreEqual('sbToggleBold', LCtrl0.Values['name'].Value);
    Assert.AreEqual('TSpeedButton', LCtrl0.Values['class'].Value);
    Assert.AreEqual('true', LCtrl0.Values['isGraphicControl'].Value);
  finally
    LJson.Free;
  end;
end;

procedure TTestVclE2E.TestCoverageJsonParsing;
var
  LJsonStr: string;
  LJson: TJSONObject;
  LTotal, LTotalVis, LCoveredVis: Integer;
  LPercent: Double;
  LCoveredArr: TJSONArray;
begin
  LJsonStr := '{"totalControls":10,"totalVisibleControls":8,"coveredVisibleControls":4,' +
              '"coveragePercent":50.0,"coveredControls":["sbToggleBold","edtItemName","btnAddItem","StatusBar1"],' +
              '"uncoveredControls":["lblTitle","btnReset","DBGrid1","chkActive"]}';

  LJson := TJSONObject.ParseJSONValue(LJsonStr) as TJSONObject;
  Assert.IsNotNull(LJson);
  try
    LTotal := StrToInt(LJson.Values['totalControls'].Value);
    LTotalVis := StrToInt(LJson.Values['totalVisibleControls'].Value);
    LCoveredVis := StrToInt(LJson.Values['coveredVisibleControls'].Value);
    LPercent := StrToFloat(LJson.Values['coveragePercent'].Value, TFormatSettings.Invariant);

    Assert.AreEqual(10, LTotal);
    Assert.AreEqual(8, LTotalVis);
    Assert.AreEqual(4, LCoveredVis);
    Assert.AreEqual(50.0, LPercent, 0.01);

    LCoveredArr := LJson.Values['coveredControls'] as TJSONArray;
    Assert.IsNotNull(LCoveredArr);
    Assert.AreEqual(4, LCoveredArr.Count);
  finally
    LJson.Free;
  end;
end;

procedure TTestVclE2E.TestGridResponseParsing;
var
  LJsonStr: string;
  LJson: TJSONObject;
  LRecordObj: TJSONObject;
begin
  LJsonStr := '{"success":true,"action":"next","recNo":2,"recordCount":5,' +
              '"record":{"ID":"2","Name":"Gaming Mouse","Category":"Hardware","Price":"89.50"}}';

  LJson := TJSONObject.ParseJSONValue(LJsonStr) as TJSONObject;
  Assert.IsNotNull(LJson);
  try
    Assert.AreEqual('true', LJson.Values['success'].Value);
    Assert.AreEqual(2, StrToInt(LJson.Values['recNo'].Value));
    Assert.AreEqual(5, StrToInt(LJson.Values['recordCount'].Value));

    LRecordObj := LJson.Values['record'] as TJSONObject;
    Assert.IsNotNull(LRecordObj);
    Assert.AreEqual('Gaming Mouse', LRecordObj.Values['Name'].Value);
    Assert.AreEqual('89.50', LRecordObj.Values['Price'].Value);
  finally
    LJson.Free;
  end;
end;

procedure TTestVclE2E.TestControlInfoParsing;
var
  LJsonStr: string;
  LJson: TJSONObject;
begin
  LJsonStr := '{"name":"sbToggleBold","class":"TSpeedButton","isControl":true,' +
              '"visible":true,"enabled":true,"left":200,"top":10,"width":32,"height":28,' +
              '"isGraphicControl":true,"down":true,"caption":"B"}';

  LJson := TJSONObject.ParseJSONValue(LJsonStr) as TJSONObject;
  Assert.IsNotNull(LJson);
  try
    Assert.AreEqual('sbToggleBold', LJson.Values['name'].Value);
    Assert.AreEqual('true', LJson.Values['isGraphicControl'].Value);
    Assert.AreEqual('true', LJson.Values['down'].Value);
    Assert.AreEqual('B', LJson.Values['caption'].Value);
  finally
    LJson.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestVclE2E);

end.
