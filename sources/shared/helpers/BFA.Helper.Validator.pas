unit BFA.Helper.Validator;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client;

type
  THelperValidator = class
  public
    class function GetRequiredString(AData: TFDMemTable; const AFieldName,
      ARequiredMessage: string; out AValue: string; out AMessage: string): Boolean;
    class function GetOptionalString(AData: TFDMemTable;
      const AFieldName: string): string;
    class function ParseBoolText(const AValue: string;
      out AResult: Boolean): Boolean;
    class function ParseIntegerField(AData: TFDMemTable; const AFieldName,
      AInvalidMessage: string; out AValue: Integer;
      out AMessage: string): Boolean;
    class function ExtractRouteUserID(const AParts: TArray<string>;
      out AUserID: string; out AMessage: string): Boolean;
  end;

implementation

{ THelperValidator }

class function THelperValidator.ExtractRouteUserID(const AParts: TArray<string>;
  out AUserID: string; out AMessage: string): Boolean;
begin
  Result := False;
  AUserID := '';

  if Length(AParts) >= 4 then
    AUserID := Trim(AParts[3]);

  if AUserID = '' then begin
    AMessage := 'User ID required';
    Exit;
  end;

  if Length(AUserID) > 36 then begin
    AMessage := 'Invalid user ID';
    Exit;
  end;

  Result := True;
end;

class function THelperValidator.GetOptionalString(AData: TFDMemTable;
  const AFieldName: string): string;
begin
  Result := '';
  if not Assigned(AData) then
    Exit;

  if Assigned(AData.FindField(AFieldName)) then
    Result := Trim(AData.FieldByName(AFieldName).AsString);
end;

class function THelperValidator.GetRequiredString(AData: TFDMemTable;
  const AFieldName, ARequiredMessage: string; out AValue: string;
  out AMessage: string): Boolean;
begin
  Result := False;
  AValue := '';

  if not Assigned(AData) then begin
    AMessage := 'Request data required';
    Exit;
  end;

  if not Assigned(AData.FindField(AFieldName)) then begin
    AMessage := ARequiredMessage;
    Exit;
  end;

  AValue := Trim(AData.FieldByName(AFieldName).AsString);
  if AValue = '' then begin
    AMessage := ARequiredMessage;
    Exit;
  end;

  Result := True;
end;

class function THelperValidator.ParseBoolText(const AValue: string;
  out AResult: Boolean): Boolean;
var
  LValue: string;
begin
  LValue := LowerCase(Trim(AValue));
  Result := True;

  if (LValue = '1') or (LValue = 'true') then
    AResult := True
  else if (LValue = '0') or (LValue = 'false') then
    AResult := False
  else
    Result := False;
end;

class function THelperValidator.ParseIntegerField(AData: TFDMemTable;
  const AFieldName, AInvalidMessage: string; out AValue: Integer;
  out AMessage: string): Boolean;
begin
  Result := False;
  AValue := 0;

  if not Assigned(AData.FindField(AFieldName)) then
    Exit(True);

  if not TryStrToInt(Trim(AData.FieldByName(AFieldName).AsString), AValue) then begin
    AMessage := AInvalidMessage;
    Exit;
  end;

  Result := True;
end;

end.
