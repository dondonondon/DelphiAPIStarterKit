unit User.Validator;

interface

uses
  FireDAC.Comp.Client,
  User.DTO;

type
  TUserValidator = class
  public
    class function ValidateChangePassword(AData: TFDMemTable;
      out ARequest: TUserChangePasswordRequest; out AMessage: string): Boolean;
    class function ValidateCreate(AData: TFDMemTable;
      out ARequest: TUserCreateRequest; out AMessage: string): Boolean;
    class function ValidateResetPassword(AData: TFDMemTable;
      const AParts: TArray<string>; out ARequest: TUserResetPasswordRequest;
      out AMessage: string): Boolean;
    class function ValidateUpdate(AData: TFDMemTable; const AParts: TArray<string>;
      out ARequest: TUserUpdateRequest; out AMessage: string): Boolean;
  end;

implementation

uses
  System.SysUtils,
  BFA.Helper.Validator;

{ TUserValidator }

class function TUserValidator.ValidateChangePassword(AData: TFDMemTable;
  out ARequest: TUserChangePasswordRequest; out AMessage: string): Boolean;
begin
  Result := False;
  ARequest.OldPassword := '';
  ARequest.NewPassword := '';

  if not THelperValidator.GetRequiredString(AData, 'old_password', 'Old password required',
    ARequest.OldPassword, AMessage) then
    Exit;

  if not THelperValidator.GetRequiredString(AData, 'new_password', 'New password required',
    ARequest.NewPassword, AMessage) then
    Exit;

  Result := True;
end;

class function TUserValidator.ValidateCreate(AData: TFDMemTable;
  out ARequest: TUserCreateRequest; out AMessage: string): Boolean;
begin
  Result := False;
  ARequest.Username := '';
  ARequest.Password := '';
  ARequest.Fullname := '';
  ARequest.IsActive := 1;
  ARequest.RoleID := 0;
  ARequest.HasRoleID := False;

  if not THelperValidator.GetRequiredString(AData, 'username', 'Username required',
    ARequest.Username, AMessage) then
    Exit;

  if not THelperValidator.GetRequiredString(AData, 'password', 'Password required',
    ARequest.Password, AMessage) then
    Exit;

  ARequest.Fullname := THelperValidator.GetOptionalString(AData, 'fullname');

  if Assigned(AData.FindField('is_active')) then begin
    if not THelperValidator.ParseIntegerField(AData, 'is_active', 'Invalid is_active value',
      ARequest.IsActive, AMessage) then
      Exit;

    if not (ARequest.IsActive in [0, 1]) then begin
      AMessage := 'Invalid is_active value';
      Exit;
    end;
  end;

  if Assigned(AData.FindField('role_id')) then begin
    if not THelperValidator.ParseIntegerField(AData, 'role_id', 'Invalid role_id value',
      ARequest.RoleID, AMessage) then
      Exit;
    ARequest.HasRoleID := True;
  end;

  Result := True;
end;

class function TUserValidator.ValidateResetPassword(AData: TFDMemTable;
  const AParts: TArray<string>; out ARequest: TUserResetPasswordRequest;
  out AMessage: string): Boolean;
var
  LConfirmText: string;
begin
  Result := False;
  ARequest.TargetUserID := '';
  ARequest.ConfirmReset := False;

  if not THelperValidator.ExtractRouteUserID(AParts, ARequest.TargetUserID, AMessage) then
    Exit;

  if not THelperValidator.GetRequiredString(AData, 'confirm_reset', 'confirm_reset required',
    LConfirmText, AMessage) then
    Exit;

  if not THelperValidator.ParseBoolText(LConfirmText, ARequest.ConfirmReset) then begin
    AMessage := 'confirm_reset must be true';
    Exit;
  end;

  if not ARequest.ConfirmReset then begin
    AMessage := 'confirm_reset must be true';
    Exit;
  end;

  Result := True;
end;

class function TUserValidator.ValidateUpdate(AData: TFDMemTable;
  const AParts: TArray<string>; out ARequest: TUserUpdateRequest;
  out AMessage: string): Boolean;
begin
  Result := False;
  ARequest.UserID := '';
  ARequest.Password := '';
  ARequest.Fullname := '';
  ARequest.IsActive := 0;
  ARequest.RoleID := 0;
  ARequest.HasPassword := False;
  ARequest.HasFullname := False;
  ARequest.HasIsActive := False;
  ARequest.HasRoleID := False;

  if not THelperValidator.ExtractRouteUserID(AParts, ARequest.UserID, AMessage) then
    Exit;

  if Assigned(AData.FindField('username')) then begin
    AMessage := 'Username cannot be changed';
    Exit;
  end;

  if Assigned(AData.FindField('password')) then begin
    ARequest.Password := Trim(AData.FieldByName('password').AsString);
    if ARequest.Password = '' then begin
      AMessage := 'Password required';
      Exit;
    end;
    ARequest.HasPassword := True;
  end;

  if Assigned(AData.FindField('fullname')) then begin
    ARequest.Fullname := Trim(AData.FieldByName('fullname').AsString);
    ARequest.HasFullname := True;
  end;

  if Assigned(AData.FindField('is_active')) then begin
    if not THelperValidator.ParseIntegerField(AData, 'is_active', 'Invalid is_active value',
      ARequest.IsActive, AMessage) then
      Exit;

    if not (ARequest.IsActive in [0, 1]) then begin
      AMessage := 'Invalid is_active value';
      Exit;
    end;
    ARequest.HasIsActive := True;
  end;

  if Assigned(AData.FindField('role_id')) then begin
    if not THelperValidator.ParseIntegerField(AData, 'role_id', 'Invalid role_id value',
      ARequest.RoleID, AMessage) then
      Exit;
    ARequest.HasRoleID := True;
  end;

  if not (ARequest.HasPassword or ARequest.HasFullname or
    ARequest.HasIsActive or ARequest.HasRoleID) then begin
    AMessage := 'No data to update';
    Exit;
  end;

  Result := True;
end;

end.
