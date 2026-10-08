unit VclE2E.Client;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.NetEncoding,
  System.Net.HttpClient,
  System.Net.URLClient;

type
  EVclE2EClientError = class(Exception);

  TVclE2EClient = class
  private
    FBaseUrl: string;
    FHttp: THTTPClient;
    function HttpGet(const AEndpoint: string): string;
    function HttpPost(const AEndpoint, AJsonBody: string): string;
  public
    constructor Create(const AHost: string = '127.0.0.1'; APort: Integer = 8080);
    destructor Destroy; override;

    function HealthCheck(out AApp: string; out AFormsCount: Integer): Boolean;
    function GetTree: TJSONObject;
    function GetCoverage: TJSONObject;
    function GetControlInfo(const AName: string): TJSONObject;
    function Click(const AName: string): Boolean;
    function SetText(const AName, AText: string): Boolean;
    function GetText(const AName: string; APanelIndex: Integer = -1): string;
    function GridAction(const AGridName, AAction: string;
      out ARecNo, ARecCount: Integer; out ARecordFields: TJSONObject): Boolean;

    property BaseUrl: string read FBaseUrl;
  end;

implementation

{ TVclE2EClient }

constructor TVclE2EClient.Create(const AHost: string; APort: Integer);
begin
  inherited Create;
  FBaseUrl := Format('http://%s:%d', [AHost, APort]);
  FHttp := THTTPClient.Create;
  FHttp.ConnectionTimeout := 3000;
  FHttp.ResponseTimeout := 5000;
end;

destructor TVclE2EClient.Destroy;
begin
  FreeAndNil(FHttp);
  inherited;
end;

function TVclE2EClient.HttpGet(const AEndpoint: string): string;
var
  LUrl: string;
  LResp: IHTTPResponse;
begin
  LUrl := FBaseUrl + AEndpoint;
  try
    LResp := FHttp.Get(LUrl);
    if LResp.StatusCode = 200 then
      Result := LResp.ContentAsString(TEncoding.UTF8)
    else
      raise EVclE2EClientError.CreateFmt('HTTP GET %s returned code %d: %s',
        [AEndpoint, LResp.StatusCode, LResp.ContentAsString(TEncoding.UTF8)]);
  except
    on E: Exception do
      raise EVclE2EClientError.CreateFmt('Connection to %s failed: %s', [LUrl, E.Message]);
  end;
end;

function TVclE2EClient.HttpPost(const AEndpoint, AJsonBody: string): string;
var
  LUrl: string;
  LStream: TStringStream;
  LResp: IHTTPResponse;
  LHeaders: TNetHeaders;
begin
  LUrl := FBaseUrl + AEndpoint;
  LStream := TStringStream.Create(AJsonBody, TEncoding.UTF8);
  try
    SetLength(LHeaders, 1);
    LHeaders[0] := TNameValuePair.Create('Content-Type', 'application/json; charset=utf-8');
    try
      LResp := FHttp.Post(LUrl, LStream, nil, LHeaders);
      if (LResp.StatusCode >= 200) and (LResp.StatusCode < 300) then
        Result := LResp.ContentAsString(TEncoding.UTF8)
      else
        raise EVclE2EClientError.CreateFmt('HTTP POST %s returned code %d: %s',
          [AEndpoint, LResp.StatusCode, LResp.ContentAsString(TEncoding.UTF8)]);
    except
      on E: Exception do
        raise EVclE2EClientError.CreateFmt('HTTP POST %s failed: %s', [LUrl, E.Message]);
    end;
  finally
    LStream.Free;
  end;
end;

function TVclE2EClient.HealthCheck(out AApp: string; out AFormsCount: Integer): Boolean;
var
  LRespText: string;
  LJson: TJSONObject;
begin
  AApp := '';
  AFormsCount := 0;
  LRespText := HttpGet('/health');
  LJson := TJSONObject.ParseJSONValue(LRespText) as TJSONObject;
  if LJson = nil then
    Exit(False);
  try
    Result := (LJson.Values['status'] <> nil) and (LJson.Values['status'].Value = 'ok');
    if LJson.Values['app'] <> nil then
      AApp := LJson.Values['app'].Value;
    if LJson.Values['formsCount'] <> nil then
      AFormsCount := StrToIntDef(LJson.Values['formsCount'].Value, 0);
  finally
    LJson.Free;
  end;
end;

function TVclE2EClient.GetTree: TJSONObject;
var
  LRespText: string;
begin
  LRespText := HttpGet('/api/tree');
  Result := TJSONObject.ParseJSONValue(LRespText) as TJSONObject;
  if Result = nil then
    raise EVclE2EClientError.Create('Invalid JSON received for /api/tree');
end;

function TVclE2EClient.GetCoverage: TJSONObject;
var
  LRespText: string;
begin
  LRespText := HttpGet('/api/coverage');
  Result := TJSONObject.ParseJSONValue(LRespText) as TJSONObject;
  if Result = nil then
    raise EVclE2EClientError.Create('Invalid JSON received for /api/coverage');
end;

function TVclE2EClient.GetControlInfo(const AName: string): TJSONObject;
var
  LRespText: string;
begin
  LRespText := HttpGet('/api/control?name=' + TNetEncoding.URL.Encode(AName));
  Result := TJSONObject.ParseJSONValue(LRespText) as TJSONObject;
  if Result = nil then
    raise EVclE2EClientError.Create('Invalid JSON received for /api/control');
end;

function TVclE2EClient.Click(const AName: string): Boolean;
var
  LBody: TJSONObject;
  LRespText: string;
  LRespJson: TJSONObject;
begin
  LBody := TJSONObject.Create;
  try
    LBody.AddPair('name', AName);
    LRespText := HttpPost('/api/click', LBody.ToJSON);
  finally
    LBody.Free;
  end;

  LRespJson := TJSONObject.ParseJSONValue(LRespText) as TJSONObject;
  if LRespJson = nil then
    Exit(False);
  try
    Result := (LRespJson.Values['success'] <> nil) and
      SameText(LRespJson.Values['success'].Value, 'true');
  finally
    LRespJson.Free;
  end;
end;

function TVclE2EClient.SetText(const AName, AText: string): Boolean;
var
  LBody: TJSONObject;
  LRespText: string;
  LRespJson: TJSONObject;
begin
  LBody := TJSONObject.Create;
  try
    LBody.AddPair('name', AName);
    LBody.AddPair('text', AText);
    LRespText := HttpPost('/api/set-text', LBody.ToJSON);
  finally
    LBody.Free;
  end;

  LRespJson := TJSONObject.ParseJSONValue(LRespText) as TJSONObject;
  if LRespJson = nil then
    Exit(False);
  try
    Result := (LRespJson.Values['success'] <> nil) and
      SameText(LRespJson.Values['success'].Value, 'true');
  finally
    LRespJson.Free;
  end;
end;

function TVclE2EClient.GetText(const AName: string; APanelIndex: Integer): string;
var
  LUrl: string;
  LRespText: string;
  LRespJson: TJSONObject;
begin
  LUrl := '/api/get-text?name=' + TNetEncoding.URL.Encode(AName);
  if APanelIndex >= 0 then
    LUrl := LUrl + '&panel=' + IntToStr(APanelIndex);

  LRespText := HttpGet(LUrl);
  LRespJson := TJSONObject.ParseJSONValue(LRespText) as TJSONObject;
  if LRespJson = nil then
    Exit('');
  try
    if LRespJson.Values['text'] <> nil then
      Result := LRespJson.Values['text'].Value
    else if LRespJson.Values['simpleText'] <> nil then
      Result := LRespJson.Values['simpleText'].Value
    else
      Result := '';
  finally
    LRespJson.Free;
  end;
end;

function TVclE2EClient.GridAction(const AGridName, AAction: string;
  out ARecNo, ARecCount: Integer; out ARecordFields: TJSONObject): Boolean;
var
  LBody: TJSONObject;
  LRespText: string;
  LRespJson: TJSONObject;
  LRecordVal: TJSONValue;
begin
  ARecNo := 0;
  ARecCount := 0;
  ARecordFields := nil;

  LBody := TJSONObject.Create;
  try
    LBody.AddPair('name', AGridName);
    LBody.AddPair('action', AAction);
    LRespText := HttpPost('/api/grid', LBody.ToJSON);
  finally
    LBody.Free;
  end;

  LRespJson := TJSONObject.ParseJSONValue(LRespText) as TJSONObject;
  if LRespJson = nil then
    Exit(False);
  try
    Result := (LRespJson.Values['success'] <> nil) and
      SameText(LRespJson.Values['success'].Value, 'true');

    if LRespJson.Values['recNo'] <> nil then
      ARecNo := StrToIntDef(LRespJson.Values['recNo'].Value, 0);
    if LRespJson.Values['recordCount'] <> nil then
      ARecCount := StrToIntDef(LRespJson.Values['recordCount'].Value, 0);

    LRecordVal := LRespJson.Values['record'];
    if LRecordVal is TJSONObject then
      ARecordFields := LRecordVal.Clone as TJSONObject;
  finally
    LRespJson.Free;
  end;
end;

end.
