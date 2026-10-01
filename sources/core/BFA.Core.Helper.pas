unit BFA.Core.Helper;

interface

uses
  System.SysUtils,
  System.Rtti,
  Web.HTTPApp;

type
  APIResourceAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const AName: string);
    property Name: string read FName;
  end;

  THelperCore = class
  public
    class function InspectRoute(const APath, AMethod: string; out AAction: string;
      out AStatus: Integer; out AAllow: string): Boolean; static;
    class function ExecuteStringMethod(AInstance: TObject;
      const AActionName: string; out AResult: string): Boolean; static;
    class function HTTPMethodToCrudAction(AMethodType: TMethodType;
      out AActionName: string): Boolean; static;
    class function IsActionNameInList(const AActionName: string;
      const AActionNames: array of string): Boolean; static;
    class function IsCrudAction(const AActionName: string): Boolean; static;
    class function ResolveClassMethodName(AClass: TClass;
      const AActionName: string; out AResolvedActionName: string): Boolean; static;
    class function ResolveRouteAction(const AParts: TArray<string>;
      AMethodType: TMethodType; AServiceClass: TClass; out AActionName: string;
      out AStatusCode: Integer): Boolean; static;
  end;

implementation

uses System.RegularExpressions, System.TypInfo;

class function THelperCore.InspectRoute(const APath, AMethod: string; out AAction: string;
  out AStatus: Integer; out AAllow: string): Boolean;
var LParts: TArray<string>; LResource, LAction: string; LUUID: Boolean;
begin
  Result := False;
  AAction := '';
  AAllow := '';
  AStatus := 404;
  if not APath.StartsWith('/') or APath.EndsWith('/') or APath.Contains('//') then Exit;
  LParts := Copy(APath, 2, MaxInt).Split(['/']);
  if (Length(LParts) < 3) or (Length(LParts) > 5) or not SameText(LParts[0], 'api') or
    not SameText(LParts[1], 'v1') then Exit;
  LResource := LowerCase(LParts[2]);
  LUUID := (Length(LParts) > 3) and TRegEx.IsMatch(LParts[3],
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
  if LResource = 'auth' then begin
    if Length(LParts) = 4 then begin
      LAction := LowerCase(LParts[3]);
      if IsActionNameInList(LAction, ['Login','Refresh','Logout','Reauthenticate','LogoutAll','CompletePasswordReset']) then begin
        AAction := LAction;
        AAllow := 'POST';
      end else if IsActionNameInList(LAction, ['Me','Sessions']) then begin
        AAction := LAction;
        AAllow := 'GET';
      end;
    end else if (Length(LParts) = 5) and SameText(LParts[3], 'Sessions') and
      TRegEx.IsMatch(LParts[4], '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then begin
      AAction := 'RevokeOwnSession';
      AAllow := 'DELETE';
    end;
  end else if LResource = 'role' then begin
    if Length(LParts) = 3 then begin
      AAction := 'Get';
      AAllow := 'GET';
    end else if (Length(LParts) = 5) and LUUID and SameText(LParts[4], 'Permissions') then begin
      AAction := 'Permissions';
      AAllow := 'PUT';
    end;
  end else if IsActionNameInList(LResource, ['User','Product','Customer','Category']) then begin
    if (LResource = 'user') and (Length(LParts) = 4) and SameText(LParts[3], 'ChangePassword') then begin
      AAction := 'ChangePassword';
      AAllow := 'POST';
    end else if (LResource = 'user') and (Length(LParts) = 5) and LUUID and SameText(LParts[4], 'ResetPassword') then begin
      AAction := 'ResetPassword';
      AAllow := 'POST';
    end else if Length(LParts) = 3 then begin
      AAllow := 'GET, POST';
      if SameText(AMethod, 'GET') then AAction := 'Get' else AAction := 'Insert';
    end else if (Length(LParts) = 4) and LUUID then begin
      AAllow := 'GET, PUT, DELETE';
      if SameText(AMethod, 'GET') then AAction := 'Get'
      else if SameText(AMethod, 'PUT') then AAction := 'Update' else AAction := 'Delete';
    end;
  end;
  if AAllow = '' then Exit;
  if not IsActionNameInList(AMethod, AAllow.Split([','], TStringSplitOptions.ExcludeEmpty)) then begin
    var LMethods := AAllow.Replace(' ', '').Split([',']);
    if not IsActionNameInList(AMethod, LMethods) then begin
      AStatus := 405;
      Exit;
    end;
  end;
  AStatus := 200;
  Result := True;
end;

type
  TExecStringMethod = function: string of object;

constructor APIResourceAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

class function THelperCore.ExecuteStringMethod(AInstance: TObject;
  const AActionName: string; out AResult: string): Boolean;
var
  Exec: TExecStringMethod;
  LActionName: string;
  Routine: TMethod;
begin
  Result := False;
  AResult := '';

  if not Assigned(AInstance) then
    Exit;

  if not ResolveClassMethodName(AInstance.ClassType, AActionName, LActionName) then
    Exit;

  Routine.Data := AInstance;
  Routine.Code := AInstance.MethodAddress(LActionName);
  if not Assigned(Routine.Code) then
    Exit;

  Exec := TExecStringMethod(Routine);
  AResult := Exec;
  Result := True;
end;

class function THelperCore.HTTPMethodToCrudAction(AMethodType: TMethodType;
  out AActionName: string): Boolean;
begin
  Result := True;
  AActionName := '';

  case AMethodType of
    mtGet: AActionName := 'Get';
    mtPost: AActionName := 'Insert';
    mtPut: AActionName := 'Update';
    mtDelete: AActionName := 'Delete';
  else
    Result := False;
  end;
end;

class function THelperCore.IsActionNameInList(const AActionName: string;
  const AActionNames: array of string): Boolean;
var
  LActionName: string;
begin
  Result := False;

  for LActionName in AActionNames do begin
    if SameText(AActionName, LActionName) then
      Exit(True);
  end;
end;

class function THelperCore.IsCrudAction(const AActionName: string): Boolean;
begin
  Result := IsActionNameInList(AActionName, ['Delete', 'Get', 'Insert', 'Update']);
end;

class function THelperCore.ResolveClassMethodName(AClass: TClass;
  const AActionName: string; out AResolvedActionName: string): Boolean;
var
  LContext: TRttiContext;
  LMethod: TRttiMethod;
  LType: TRttiType;
begin
  Result := False;
  AResolvedActionName := '';

  if (not Assigned(AClass)) or (Trim(AActionName) = '') then
    Exit;

  LContext := TRttiContext.Create;
  LType := LContext.GetType(AClass);
  if not Assigned(LType) then
    Exit;

  for LMethod in LType.GetMethods do begin
    if SameText(LMethod.Name, AActionName) and (Length(LMethod.GetParameters) = 0) and
      Assigned(LMethod.ReturnType) and (LMethod.ReturnType.TypeKind = tkUString) then begin
      AResolvedActionName := LMethod.Name;
      Exit(True);
    end;
  end;
end;

class function THelperCore.ResolveRouteAction(const AParts: TArray<string>;
  AMethodType: TMethodType; AServiceClass: TClass; out AActionName: string; out AStatusCode: Integer): Boolean;
var LMethod, LAllow: string;
begin
  case AMethodType of
    mtGet: LMethod := 'GET';
    mtPost: LMethod := 'POST';
    mtPut: LMethod := 'PUT';
    mtDelete: LMethod := 'DELETE';
  else LMethod := '';
  end;
  Result := InspectRoute('/' + string.Join('/', AParts), LMethod, AActionName, AStatusCode, LAllow);
end;

end.
