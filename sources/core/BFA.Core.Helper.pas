unit BFA.Core.Helper;

interface

uses
  System.SysUtils,
  System.Rtti,
  Web.HTTPApp;

type
  THelperCore = class
  public
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

type
  TExecStringMethod = function: string of object;

{ THelperCore }

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
    if SameText(LMethod.Name, AActionName) then begin
      AResolvedActionName := LMethod.Name;
      Exit(True);
    end;
  end;
end;

class function THelperCore.ResolveRouteAction(const AParts: TArray<string>;
  AMethodType: TMethodType; AServiceClass: TClass; out AActionName: string;
  out AStatusCode: Integer): Boolean;
var
  LMethodName: string;
  LResolvedActionName: string;
begin
  Result := True;
  AActionName := '';
  AStatusCode := 200;

  if Length(AParts) = 5 then begin
    LMethodName := Trim(AParts[4]);
    if ResolveClassMethodName(AServiceClass, LMethodName, LResolvedActionName) and
      not IsCrudAction(LResolvedActionName) then begin
      AActionName := LResolvedActionName;
      Exit;
    end;

    AStatusCode := 405;
    Exit(False);
  end;

  if Length(AParts) = 4 then begin
    LMethodName := Trim(AParts[3]);
    if ResolveClassMethodName(AServiceClass, LMethodName, LResolvedActionName) and
      not IsCrudAction(LResolvedActionName) then begin
      AActionName := LResolvedActionName;
      Exit;
    end;
  end;

  Result := HTTPMethodToCrudAction(AMethodType, AActionName);
  if not Result then
    AStatusCode := 405;
end;

end.
