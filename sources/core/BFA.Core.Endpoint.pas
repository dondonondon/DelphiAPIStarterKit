unit BFA.Core.Endpoint;

interface

uses System.SysUtils, FireDAC.Comp.Client, Web.HTTPApp;

type
  TEndpointExecuteAction = reference to function(const AActionName: string;
    const AParts: TArray<string>; out AStatusCode: Integer): string;

  THelperEndpoint = class
  public
    class function ExecuteRoute(AData: TFDMemTable; ARequest: TWebRequest; AServiceClass: TClass;
      const APostOnlyActions: array of string; const AExecuteAction: TEndpointExecuteAction;
      out AStatusCode: Integer; const ALogSource: string = 'Endpoint route';
      AConnection: TFDConnection = nil; ARequireAuthentication: Boolean = False): string; static;
    class procedure WriteErrorLog(const ASource: string; AException: Exception); static;
  end;

implementation

uses BFA.Core.Helper, BFA.Core.Response, BFA.Core.Request, BFA.Security.Token, BFA.Logger,
  Auth.Repository, Auth.Policy, FireDAC.Stan.Error;

class function THelperEndpoint.ExecuteRoute(AData: TFDMemTable; ARequest: TWebRequest; AServiceClass: TClass;
  const APostOnlyActions: array of string; const AExecuteAction: TEndpointExecuteAction;
  out AStatusCode: Integer; const ALogSource: string; AConnection: TFDConnection; ARequireAuthentication: Boolean): string;
var LAction, LAllow, LResource, LPermission, LTarget, LRoleTarget: string; LParts: TArray<string>; LRepository: TAuthRepository; LActor: TAuthActor;
begin
  AStatusCode := 500;
  LActor := Default(TAuthActor);
  try
    if not Assigned(ARequest) then raise Exception.Create('Request unavailable.');
    if not THelperCore.InspectRoute(ARequest.PathInfo, ARequest.Method, LAction, AStatusCode, LAllow) then
      Exit(THelperResponse.CreateResponse(AStatusCode, 'Route or method not allowed.'));
    LParts := ARequest.PathInfo.Trim(['/']).Split(['/']);
    if ARequireAuthentication then begin
      LRepository := TAuthRepository.Create(AConnection);
      try
        LActor := LRepository.ResolveActor(TSecurityToken.ExtractAccessToken(ARequest));
        LResource := LowerCase(LParts[2]);
        if LActor.Restricted and not SameText(LAction, 'ChangePassword') then
          raise EAuthPolicy.Create(403, 'Password change required.');
        LPermission := '';
        if LResource = 'product' then LResource := 'products'
        else if LResource = 'customer' then LResource := 'customers'
        else if LResource = 'user' then LResource := 'users';
        if SameText(LAction, 'Get') then LPermission := 'read'
        else if SameText(LAction, 'Insert') then LPermission := 'create'
        else if SameText(LAction, 'Update') then LPermission := 'update'
        else if SameText(LAction, 'Delete') then LPermission := 'delete';
        if LPermission <> '' then begin
          if LResource = 'role' then LResource := 'roles';
          LActor.RequirePermission(LResource + '.' + LPermission);
        end;
      finally
        FreeAndNil(LRepository);
      end;
    end;
    Result := AExecuteAction(LAction, LParts, AStatusCode);
  except
    on E: EAuthPolicy do begin
      AStatusCode := E.Status;
      if LActor.UserInternalID <> 0 then begin
        try
          LRepository := TAuthRepository.Create(AConnection);
          try
            LTarget := '';
            LRoleTarget := '';
            if Length(LParts) >= 4 then begin
              if (LResource = 'users') and (Length(LParts[3]) = 36) then LTarget := LParts[3];
              if (LResource = 'roles') or (LResource = 'role') then LRoleTarget := LParts[3];
            end;
            LRepository.Audit('authorization_denied', 'denied', LActor, LTarget, ARequest.RemoteAddr, LRoleTarget);
          finally
            FreeAndNil(LRepository);
          end;
        except
          on LAuditError: Exception do THelperLogger.Error('Denied auth audit', LAuditError);
        end;
      end;
      Result := THelperResponse.CreateResponse(AStatusCode, E.Message);
    end;
    on E: ERequestInvalid do begin
      AStatusCode := E.Status;
      Result := THelperResponse.CreateResponse(AStatusCode, E.Message);
    end;
    on E: EFDDBEngineException do begin
      if E.Kind = ekUKViolated then begin
        AStatusCode := 409;
        Result := THelperResponse.CreateResponse(409, 'Resource conflict.');
      end else begin
        WriteErrorLog(ALogSource, E);
        AStatusCode := 500;
        Result := THelperResponse.CreateResponse(500, 'Internal server error.');
      end;
    end;
    on E: Exception do begin
      WriteErrorLog(ALogSource, E);
      AStatusCode := 500;
      Result := THelperResponse.CreateResponse(500, 'Internal server error.');
    end;
  end;
end;

class procedure THelperEndpoint.WriteErrorLog(const ASource: string; AException: Exception);
begin
  THelperLogger.Error(ASource, AException);
end;

end.
