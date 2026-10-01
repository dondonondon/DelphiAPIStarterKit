unit Role.Validator;

interface

uses Web.HTTPApp;

type
  TRoleValidator = class
  public
    class function PermissionCodes(ARequest: TWebRequest): TArray<string>; static;
  end;

implementation

uses System.SysUtils, System.JSON, System.RegularExpressions, BFA.Core.Request;

class function TRoleValidator.PermissionCodes(ARequest: TWebRequest): TArray<string>;
var LBody: TJSONObject; LArray: TJSONValue; I, J: Integer;
begin
  Result := nil;
  LBody := THelperRequest.JSONObject(ARequest, ['permissions']);
  try
    LArray := LBody.GetValue('permissions');
    if not (LArray is TJSONArray) or (TJSONArray(LArray).Count > 100) then
      raise ERequestInvalid.Create('permissions must be a bounded array.');
    SetLength(Result, TJSONArray(LArray).Count);
    for I := 0 to High(Result) do begin
      if not (TJSONArray(LArray).Items[I] is TJSONString) then
        raise ERequestInvalid.Create('Permission codes must be strings.');
      Result[I] := TJSONArray(LArray).Items[I].Value;
      if (THelperRequest.Codepoints(Result[I]) > 100) or not TRegEx.IsMatch(Result[I], '^[a-z_]+\.[a-z_]{1,40}$') then
        raise ERequestInvalid.Create('Invalid permission code.');
      for J := 0 to I - 1 do if Result[J] = Result[I] then raise ERequestInvalid.Create('Duplicate permission.');
    end;
  finally
    FreeAndNil(LBody);
  end;
end;

end.
