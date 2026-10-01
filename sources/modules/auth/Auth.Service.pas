unit Auth.Service;

interface

uses
  System.Classes,
  System.SysUtils,
  FireDAC.Comp.Client,
  Web.HTTPApp,
  Auth.Repository;

type
  TAuthService = class(TPersistent)
  private
    FConnection: TFDConnection;
    FData: TFDMemTable;
    FWebRequest: TWebRequest;
    FRepository: TAuthRepository;
    FStatusCode: Integer;

    function InternalServerError(AException: Exception = nil): string;
  public
    constructor Create(AConnection: TFDConnection; AData: TFDMemTable;
      AWebRequest: TWebRequest);
    destructor Destroy; override;

    property StatusCode: Integer read FStatusCode;

  published
    function Login: string;
    function Refresh: string;
    function Logout: string;
  end;

implementation

uses
  System.IOUtils,
  Data.DB,
  BFA.Core.Response,
  BFA.Helper.Strings,
  BFA.Helper.Transaction,
  Auth.DTO,
  Auth.Validator;

{ TAuthService }

procedure WriteAuthErrorLog(const ASource: string; AException: Exception);
var
  LFileName: string;
  LMessage: string;
begin
  if not Assigned(AException) then
    Exit;

  LFileName := TPath.Combine(ExtractFilePath(ParamStr(0)), 'server-error.log');
  LMessage := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' +
    ASource + ': ' + AException.ClassName + ': ' + AException.Message + sLineBreak;
  TFile.AppendAllText(LFileName, LMessage, TEncoding.UTF8);
end;

constructor TAuthService.Create(AConnection: TFDConnection; AData: TFDMemTable;
  AWebRequest: TWebRequest);
begin
  inherited Create;
  FConnection := AConnection;
  FData := AData;
  FWebRequest := AWebRequest;
  FStatusCode := 500;
  FRepository := TAuthRepository.Create(FConnection);
end;

destructor TAuthService.Destroy;
begin
  FreeAndNil(FRepository);
  inherited;
end;

function TAuthService.InternalServerError(AException: Exception): string;
begin
  if Assigned(AException) then
    WriteAuthErrorLog('Auth service error', AException);

  FStatusCode := 500;
  Result := THelperResponse.CreateResponse(FStatusCode, 'Internal server error.', FData);
end;

function TAuthService.Login: string;
var
  LRequest: TAuthLoginRequest;
  LMessage: string;
  LDataset: TFDQuery;
  LSessionID: string;
  LAccessToken: string;
  LTokenHash: string;
  LUserID: string;
  LUserInternalID: UInt64;
  LSessionInternalID: UInt64;
  LResponseData: TStringList;
begin
  if not TAuthValidator.ValidateLogin(FData, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  LDataset := FRepository.FindUserForLogin(LRequest.Username);
  try
    if LDataset.IsEmpty then begin
      FStatusCode := 401;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'Invalid username or password', FData));
    end;

    if not LDataset.FieldByName('is_active').AsBoolean then begin
      FStatusCode := 403;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'User inactive', FData));
    end;

    if LDataset.FieldByName('password_hash').AsString <> TGlobalFunction.HashHMAC256(LRequest.Password) then begin
      FStatusCode := 401;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'Invalid username or password', FData));
    end;

    LUserInternalID := LDataset.FieldByName('id').AsLargeInt;
    LUserID := LDataset.FieldByName('user_id').AsString;
  finally
    FreeAndNil(LDataset);
  end;

  if (LRequest.UserAgent = '') and Assigned(FWebRequest) then
    LRequest.UserAgent := FWebRequest.GetFieldByName('User-Agent');

  if (LRequest.IPAddress = '') and Assigned(FWebRequest) then
    LRequest.IPAddress := FWebRequest.RemoteAddr;

  LSessionID := TGlobalFunction.NewDatabaseUUID;
  LAccessToken := TGlobalFunction.NewUUIDCompact;
  LTokenHash := TGlobalFunction.HashHMAC256(LAccessToken);

  try
    FConnection.StartTransaction;
    try
      FRepository.RevokeActiveSessions(LUserInternalID, LRequest.DeviceID);
      LSessionInternalID := FRepository.CreateSession(
        LUserInternalID,
        LSessionID,
        LRequest.DeviceID,
        LRequest.DeviceName,
        LRequest.UserAgent,
        LRequest.IPAddress
      );
      FRepository.CreateAccessToken(LTokenHash, LSessionInternalID);
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError(E));
      end;
    end;

    LResponseData := TAuthTokenDTO.CreateTokenResponse(LAccessToken, 1800, LSessionID);
    try
      FStatusCode := 200;
      Result := THelperResponse.CreateResponse(FStatusCode, 'OK', LResponseData);
    finally
      FreeAndNil(LResponseData);
    end;
  except
    on E: Exception do
      Result := InternalServerError(E);
  end;
end;

function TAuthService.Logout: string;
var
  LRequest: TAuthSessionRequest;
  LMessage: string;
begin
  if not TAuthValidator.ValidateSession(FData, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  try
    FConnection.StartTransaction;
    try
      FRepository.RevokeSession(LRequest.SessionID, LRequest.DeviceID);
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError(E));
      end;
    end;

    FStatusCode := 200;
    Result := THelperResponse.CreateResponse(FStatusCode, 'Logged out', FData);
  except
    on E: Exception do
      Result := InternalServerError(E);
  end;
end;

function TAuthService.Refresh: string;
var
  LRequest: TAuthSessionRequest;
  LMessage: string;
  LAccessToken: string;
  LTokenHash: string;
  LSessionInternalID: UInt64;
  LResponseData: TStringList;
begin
  if not TAuthValidator.ValidateSession(FData, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  if not FRepository.SessionExists(LRequest.SessionID, LRequest.DeviceID, LSessionInternalID) then begin
    FStatusCode := 401;
    Exit(THelperResponse.CreateResponse(FStatusCode, 'Session expired or invalid', FData));
  end;

  LAccessToken := TGlobalFunction.NewUUIDCompact;
  LTokenHash := TGlobalFunction.HashHMAC256(LAccessToken);

  try
    FConnection.StartTransaction;
    try
      FRepository.CreateAccessToken(LTokenHash, LSessionInternalID);
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError(E));
      end;
    end;

    LResponseData := TAuthTokenDTO.CreateTokenResponse(LAccessToken, 1800);
    try
      FStatusCode := 200;
      Result := THelperResponse.CreateResponse(FStatusCode, 'OK', LResponseData);
    finally
      FreeAndNil(LResponseData);
    end;
  except
    on E: Exception do
      Result := InternalServerError(E);
  end;
end;

end.
