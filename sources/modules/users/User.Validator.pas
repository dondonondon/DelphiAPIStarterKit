unit User.Validator;

interface

uses System.JSON, Web.HTTPApp, User.DTO;

type
  TUserValidator = class
  public
    class function ValidateCreate(ARequest: TWebRequest): TUserCreateRequest; static;
    class function ValidateUpdate(ARequest: TWebRequest; const AUserID: string): TUserUpdateRequest; static;
    class procedure ValidateResetPassword(ARequest: TWebRequest); static;
  end;

implementation

uses System.SysUtils, BFA.Core.Request, Auth.Validator;

class function TUserValidator.ValidateCreate(ARequest: TWebRequest): TUserCreateRequest;
var LBody: TJSONObject;
begin
  Result := Default(TUserCreateRequest);
  LBody := THelperRequest.JSONObject(ARequest, ['username','password','fullname','is_active','role_id']);
  try
    Result.Username := THelperRequest.JSONString(LBody, 'username', True, 50);
    TAuthValidator.Username(Result.Username);
    Result.Password := THelperRequest.JSONString(LBody, 'password', False, 128);
    if Assigned(LBody.GetValue('password')) then TAuthValidator.Password(Result.Password, True);
    Result.Fullname := THelperRequest.JSONString(LBody, 'fullname', False, 100);
    Result.IsActive := THelperRequest.JSONInteger(LBody, 'is_active', 0, 1, 1);
    Result.HasRoleID := Assigned(LBody.GetValue('role_id'));
    if Result.HasRoleID and not (LBody.GetValue('role_id') is TJSONNull) then
      Result.RoleID := THelperRequest.JSONInteger(LBody, 'role_id', 1, MaxInt, 0);
  finally
    FreeAndNil(LBody);
  end;
end;

class function TUserValidator.ValidateUpdate(ARequest: TWebRequest; const AUserID: string): TUserUpdateRequest;
var LBody: TJSONObject;
begin
  Result := Default(TUserUpdateRequest);
  TAuthValidator.UUID(AUserID);
  Result.UserID := AUserID;
  LBody := THelperRequest.JSONObject(ARequest, ['fullname','is_active','role_id']);
  try
    Result.HasFullname := Assigned(LBody.GetValue('fullname'));
    if Result.HasFullname then Result.Fullname := THelperRequest.JSONString(LBody, 'fullname', False, 100);
    Result.HasIsActive := Assigned(LBody.GetValue('is_active'));
    Result.IsActive := THelperRequest.JSONInteger(LBody, 'is_active', 0, 1, 0);
    Result.HasRoleID := Assigned(LBody.GetValue('role_id'));
    if Result.HasRoleID and not (LBody.GetValue('role_id') is TJSONNull) then
      Result.RoleID := THelperRequest.JSONInteger(LBody, 'role_id', 1, MaxInt, 0);
    if LBody.Count = 0 then raise ERequestInvalid.Create('No data to update.');
  finally
    FreeAndNil(LBody);
  end;
end;

class procedure TUserValidator.ValidateResetPassword(ARequest: TWebRequest);
var LBody: TJSONObject; LConfirm: TJSONValue;
begin
  LBody := THelperRequest.JSONObject(ARequest, ['confirm_reset']);
  try
    LConfirm := LBody.GetValue('confirm_reset');
    if not (LConfirm is TJSONBool) or not TJSONBool(LConfirm).AsBoolean then
      raise ERequestInvalid.Create('confirm_reset must be true.');
  finally
    FreeAndNil(LBody);
  end;
end;

end.
