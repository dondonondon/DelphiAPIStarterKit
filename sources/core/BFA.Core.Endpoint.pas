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
  public
    class function ExecuteRoute(AData: TFDMemTable; ARequest: TWebRequest;
      AServiceClass: TClass; const APostOnlyActions: array of string;
      const AExecuteAction: TEndpointExecuteAction; out AStatusCode: Integer;
      const ALogSource: string = 'Endpoint route error'): string; static;
    class procedure WriteErrorLog(const ASource: string; AException: Exception); static;
  end;

implementation

uses
  System.IOUtils,
  BFA.Core.Helper,
  BFA.Core.Response;

class function THelperEndpoint.ExecuteRoute(AData: TFDMemTable; ARequest: TWebRequest;
  AServiceClass: TClass; const APostOnlyActions: array of string;
  const AExecuteAction: TEndpointExecuteAction; out AStatusCode: Integer;
  const ALogSource: string): string;
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
