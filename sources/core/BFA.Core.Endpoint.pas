unit BFA.Core.Endpoint;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  Web.HTTPApp;

type
  TEndpointExecuteAction = reference to function(const AActionName: string;
    const AParts: TArray<string>; out AStatusCode: Integer): string;

  THelperEndpoint = class
  private
    class function IsAuthenticated(AConnection: TFDConnection; ARequest: TWebRequest): Boolean; static;
  public
    class function ExecuteRoute(AData: TFDMemTable; ARequest: TWebRequest;
      AServiceClass: TClass; const APostOnlyActions: array of string;
      const AExecuteAction: TEndpointExecuteAction; out AStatusCode: Integer;
      const ALogSource: string = 'Endpoint route error';
      AConnection: TFDConnection = nil; ARequireAuthentication: Boolean = False): string; static;
    class procedure WriteErrorLog(const ASource: string; AException: Exception); static;
  end;

implementation

uses
  System.IOUtils,
  Data.DB,
  BFA.Core.Helper,
  BFA.Core.Response,
  BFA.Helper.Strings,
  BFA.Security.Token,
  DB.Helper.Query;

class function THelperEndpoint.ExecuteRoute(AData: TFDMemTable; ARequest: TWebRequest;
  AServiceClass: TClass; const APostOnlyActions: array of string;
  const AExecuteAction: TEndpointExecuteAction; out AStatusCode: Integer;
  const ALogSource: string; AConnection: TFDConnection;
  ARequireAuthentication: Boolean): string;
var
  LActionName: string;
  LParts: TArray<string>;
  LRouteAccept: Boolean;
  LStatusCode: Integer;
begin
  Result := '';
  LStatusCode := AStatusCode;

  try
    try
      if not Assigned(ARequest) then begin
        LStatusCode := 500;
        Exit(THelperResponse.CreateResponse(LStatusCode, 'Internal server error.', AData));
      end;

      if ARequireAuthentication and not IsAuthenticated(AConnection, ARequest) then begin
        LStatusCode := 401;
        Exit(THelperResponse.CreateResponse(LStatusCode, 'Session expired or invalid', AData));
      end;

      LParts := ARequest.PathInfo.Trim(['/']).Split(['/']);
      LRouteAccept := THelperCore.ResolveRouteAction(
        LParts,
        ARequest.MethodType,
        AServiceClass,
        LActionName,
        LStatusCode
      );

      if not LRouteAccept then begin
        Result := THelperResponse.CreateResponse(LStatusCode, 'Method Not Allowed', AData);
        Exit;
      end;

      if THelperCore.IsActionNameInList(LActionName, APostOnlyActions) and
        (ARequest.MethodType <> mtPost) then begin
        LStatusCode := 405;
        Result := THelperResponse.CreateResponse(LStatusCode, 'Method Not Allowed', AData);
        Exit;
      end;

      Result := AExecuteAction(LActionName, LParts, LStatusCode);
    except
      on E: Exception do begin
        WriteErrorLog(ALogSource, E);
        LStatusCode := 500;
        Result := THelperResponse.CreateResponse(LStatusCode, 'Internal server error.', AData);
      end;
    end;
  finally
    AStatusCode := LStatusCode;
  end;
end;

class function THelperEndpoint.IsAuthenticated(AConnection: TFDConnection;
  ARequest: TWebRequest): Boolean;
var
  LAccessToken: string;
  LDataset: TFDQuery;
begin
  Result := False;
  if (not Assigned(AConnection)) or (not Assigned(ARequest)) then
    Exit;

  LAccessToken := TSecurityToken.ExtractAccessToken(ARequest);
  if LAccessToken = '' then
    Exit;

  LDataset := THelperDatabase.CreateQuery(AConnection);
  try
    TQueryFunction.SQLAdd(
      LDataset,
      'SELECT u.user_id ' +
      'FROM access_token at ' +
      'INNER JOIN user_session us ON us.id = at.session_internal_id ' +
      'INNER JOIN users u ON u.id = us.user_internal_id ' +
      'WHERE at.token_hash = :hash ' +
      'AND at.revoked = 0 ' +
      'AND at.expires_at > NOW() ' +
      'AND at.deleted_at IS NULL ' +
      'AND us.revoked = 0 ' +
      'AND us.expires_at > NOW() ' +
      'AND us.deleted_at IS NULL ' +
      'AND u.is_active = 1 ' +
      'AND u.deleted_at IS NULL ' +
      'ORDER BY at.id DESC LIMIT 1',
      True
    );
    TQueryFunction.SQLParamByName(LDataset, 'hash', TGlobalFunction.HashHMAC256(LAccessToken));
    TQueryFunction.SQLOpen(LDataset);
    Result := not LDataset.IsEmpty;
  finally
    FreeAndNil(LDataset);
  end;
end;

class procedure THelperEndpoint.WriteErrorLog(const ASource: string; AException: Exception);
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

end.
