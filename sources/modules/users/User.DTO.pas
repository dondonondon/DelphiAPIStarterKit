unit User.DTO;

interface

uses
  System.Classes,
  System.SysUtils;

type
  TUserCreateRequest = record
    Username: string;
    Password: string;
    Fullname: string;
    IsActive: Integer;
    RoleID: Integer;
    HasRoleID: Boolean;
  end;

  TUserUpdateRequest = record
    UserID: string;
    Password: string;
    Fullname: string;
    IsActive: Integer;
    RoleID: Integer;
    HasPassword: Boolean;
    HasFullname: Boolean;
    HasIsActive: Boolean;
    HasRoleID: Boolean;
  end;

  TUserChangePasswordRequest = record
    OldPassword: string;
    NewPassword: string;
  end;

  TUserResetPasswordRequest = record
    TargetUserID: string;
    ForceDefault: Boolean;
  end;

  TUserDTO = class
    class function CreateUserResponse(const AUserID, AUsername,
      AFullname: string; AIsActive: Integer; AHasRoleID: Boolean;
      ARoleID: Integer): TStringList;
    class function CreateResetPasswordResponse(const ATargetUserID,
      ARequesterID: string): TStringList;
  end;

implementation

{ TUserDTO }

class function TUserDTO.CreateResetPasswordResponse(const ATargetUserID,
  ARequesterID: string): TStringList;
begin
  Result := TStringList.Create;
  try
    Result.AddPair('user_id', ATargetUserID);
    Result.AddPair('reset_by', ARequesterID);
    Result.AddPair('force_default', 'true');
  except
    Result.Free;
    raise;
  end;
end;

class function TUserDTO.CreateUserResponse(const AUserID, AUsername,
  AFullname: string; AIsActive: Integer; AHasRoleID: Boolean;
  ARoleID: Integer): TStringList;
begin
  Result := TStringList.Create;
  try
    Result.AddPair('user_id', AUserID);
    Result.AddPair('username', AUsername);
    Result.AddPair('fullname', AFullname);
    Result.AddPair('is_active', IntToStr(AIsActive));
    if AHasRoleID then
      Result.AddPair('role_id', IntToStr(ARoleID));
  except
    Result.Free;
    raise;
  end;
end;

end.
