unit User.Service;

interface

uses
  System.Classes,
  FireDAC.Comp.Client,
  Web.HTTPApp,
  User.Repository;

type
  TUserService = class(TPersistent)
  private
    FConnection: TFDConnection;
    FData: TFDMemTable;
    FParts: TArray<string>;
    FRepository: TUserRepository;
    FStatusCode: Integer;
    FWebRequest: TWebRequest;

    function GetAuthenticatedUserID(out AUserID: string): Boolean;
    function GenerateTemporaryPassword: string;
    function InternalServerError: string;
  public
    constructor Create(AConnection: TFDConnection; AData: TFDMemTable;
      ARequest: TWebRequest; const AParts: TArray<string>);
    destructor Destroy; override;

    property StatusCode: Integer read FStatusCode;

  published
    function ChangePassword: string;
    function Delete: string;
    function Get: string;
    function Insert: string;
    function ResetPassword: string;
    function Update: string;
  end;

implementation

uses
  System.SysUtils,
  Data.DB,
  BFA.Core.Response,
  BFA.Helper.Strings,
  BFA.Helper.Transaction,
  BFA.Helper.Validator,
  BFA.Security.Token,
  User.DTO,
  User.Validator;

{ TUserService }

constructor TUserService.Create(AConnection: TFDConnection; AData: TFDMemTable;
  ARequest: TWebRequest; const AParts: TArray<string>);
begin
  inherited Create;
  FConnection := AConnection;
  FData := AData;
  FWebRequest := ARequest;
  FParts := AParts;
  FStatusCode := 500;
  FRepository := TUserRepository.Create(FConnection);
end;

destructor TUserService.Destroy;
begin
  FreeAndNil(FRepository);
  inherited;
end;

function TUserService.ChangePassword: string;
var
  LRequest: TUserChangePasswordRequest;
  LMessage: string;
  LUserID: string;
  LDataset: TFDQuery;
  LCurrentPassHash: string;
  LNewPassHash: string;
begin
  if not TUserValidator.ValidateChangePassword(FData, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  if not GetAuthenticatedUserID(LUserID) then begin
    FStatusCode := 401;
    Exit(THelperResponse.CreateResponse(FStatusCode, 'Session expired or invalid', FData));
  end;

  LDataset := FRepository.FindActiveUserByID(LUserID);
  try
    if LDataset.IsEmpty then begin
      FStatusCode := 404;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'User not found', FData));
    end;

    LCurrentPassHash := LDataset.FieldByName('password_hash').AsString;
  finally
    FreeAndNil(LDataset);
  end;

  if LCurrentPassHash <> TGlobalFunction.HashHMAC256(LRequest.OldPassword) then begin
    FStatusCode := 401;
    Exit(THelperResponse.CreateResponse(FStatusCode, 'Old password invalid', FData));
  end;

  LNewPassHash := TGlobalFunction.HashHMAC256(LRequest.NewPassword);
  if LNewPassHash = LCurrentPassHash then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, 'New password must be different', FData));
  end;

  try
    FConnection.StartTransaction;
    try
      FRepository.UpdatePassword(LUserID, LNewPassHash);
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError);
      end;
    end;

    FStatusCode := 200;
    Result := THelperResponse.CreateResponse(FStatusCode, 'Password updated', FData);
  except
    on E: Exception do
      Result := InternalServerError;
  end;
end;

function TUserService.Delete: string;
var
  LUserID: string;
  LMessage: string;
  LRowsAffected: Integer;
begin
  if not THelperValidator.ExtractRouteUserID(FParts, LUserID, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  try
    FConnection.StartTransaction;
    try
      LRowsAffected := FRepository.SoftDeleteUser(LUserID);
      if LRowsAffected = 0 then begin
        THelperTransaction.Rollback(FConnection);
        FStatusCode := 404;
        Exit(THelperResponse.CreateResponse(FStatusCode, 'User not found', FData));
      end;
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError);
      end;
    end;

    FStatusCode := 200;
    Result := THelperResponse.CreateResponse(FStatusCode, 'User deleted', FData);
  except
    on E: Exception do
      Result := InternalServerError;
  end;
end;

function TUserService.Get: string;
var
  LDataset: TFDQuery;
  LUserID: string;
begin
  LUserID := '';
  if Length(FParts) >= 4 then
    LUserID := Trim(FParts[3]);

  LDataset := FRepository.GetUsers(LUserID);
  try
    if LDataset.IsEmpty then begin
      FStatusCode := 404;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'User not found', FData));
    end;

    FStatusCode := 200;
    Result := THelperResponse.CreateResponse(FStatusCode, 'OK', LDataset, FData);
  finally
    FreeAndNil(LDataset);
  end;
end;

function TUserService.GetAuthenticatedUserID(out AUserID: string): Boolean;
var
  LAccessToken: string;
  LDataset: TFDQuery;
begin
  Result := False;
  AUserID := '';

  LAccessToken := TSecurityToken.ExtractAccessToken(FWebRequest);
  if LAccessToken = '' then
    Exit;

  LDataset := FRepository.FindAuthUserByTokenHash(
    TGlobalFunction.HashHMAC256(LAccessToken)
  );
  try
    if LDataset.IsEmpty then
      Exit;

    AUserID := LDataset.FieldByName('user_id').AsString;
    Result := AUserID <> '';
  finally
    FreeAndNil(LDataset);
  end;
end;

function TUserService.GenerateTemporaryPassword: string;
begin
  Result := Copy(TGlobalFunction.NewUUIDCompact + TGlobalFunction.NewUUIDCompact, 1, 24);
end;

function TUserService.Insert: string;
var
  LRequest: TUserCreateRequest;
  LMessage: string;
  LDataset: TFDQuery;
  LPasswordHash: string;
  LResponseData: TStringList;
  LUserID: string;
begin
  if not TUserValidator.ValidateCreate(FData, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  LDataset := FRepository.FindUserByUsername(LRequest.Username);
  try
    if not LDataset.IsEmpty then begin
      FStatusCode := 409;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'Username already exists', FData));
    end;
  finally
    FreeAndNil(LDataset);
  end;

  LUserID := TGlobalFunction.NewDatabaseUUID;
  LPasswordHash := TGlobalFunction.HashHMAC256(LRequest.Password);

  try
    FConnection.StartTransaction;
    try
      FRepository.CreateUser(LUserID, LRequest, LPasswordHash);
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError);
      end;
    end;

    LResponseData := TUserDTO.CreateUserResponse(
      LUserID,
      LRequest.Username,
      LRequest.Fullname,
      LRequest.IsActive,
      LRequest.HasRoleID,
      LRequest.RoleID
    );
    try
      FStatusCode := 201;
      Result := THelperResponse.CreateResponse(FStatusCode, 'User created', LResponseData);
    finally
      FreeAndNil(LResponseData);
    end;
  except
    on E: Exception do
      Result := InternalServerError;
  end;
end;

function TUserService.InternalServerError: string;
begin
  FStatusCode := 500;
  Result := THelperResponse.CreateResponse(FStatusCode, 'Internal server error.', FData);
end;

function TUserService.ResetPassword: string;
var
  LRequest: TUserResetPasswordRequest;
  LMessage: string;
  LRequesterID: string;
  LDataset: TFDQuery;
  LResponseData: TStringList;
  LTemporaryPassword: string;
begin
  if not TUserValidator.ValidateResetPassword(FData, FParts, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  if not GetAuthenticatedUserID(LRequesterID) then begin
    FStatusCode := 401;
    Exit(THelperResponse.CreateResponse(FStatusCode, 'Session expired or invalid', FData));
  end;

  LDataset := FRepository.FindUserByID(LRequest.TargetUserID);
  try
    if LDataset.IsEmpty then begin
      FStatusCode := 404;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'User not found', FData));
    end;
  finally
    FreeAndNil(LDataset);
  end;

  LTemporaryPassword := GenerateTemporaryPassword;

  try
    FConnection.StartTransaction;
    try
      FRepository.UpdatePassword(
        LRequest.TargetUserID,
        TGlobalFunction.HashHMAC256(LTemporaryPassword)
      );
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError);
      end;
    end;

    LResponseData := TUserDTO.CreateResetPasswordResponse(
      LRequest.TargetUserID,
      LRequesterID,
      LTemporaryPassword
    );
    try
      FStatusCode := 200;
      Result := THelperResponse.CreateResponse(FStatusCode, 'Password reset',
        LResponseData);
    finally
      FreeAndNil(LResponseData);
    end;
  except
    on E: Exception do
      Result := InternalServerError;
  end;
end;


function TUserService.Update: string;
var
  LRequest: TUserUpdateRequest;
  LMessage: string;
  LDataset: TFDQuery;
  LPasswordHash: string;
  LResponseData: TStringList;
  LUsername: string;
  LFullname: string;
  LIsActive: Integer;
  LHasRoleID: Boolean;
  LRoleID: Integer;
begin
  if not TUserValidator.ValidateUpdate(FData, FParts, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  LDataset := FRepository.FindUserByID(LRequest.UserID);
  try
    if LDataset.IsEmpty then begin
      FStatusCode := 404;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'User not found', FData));
    end;

    LUsername := LDataset.FieldByName('username').AsString;
    LFullname := LDataset.FieldByName('fullname').AsString;
    LIsActive := LDataset.FieldByName('is_active').AsInteger;
    LHasRoleID := not LDataset.FieldByName('role_internal_id').IsNull;
    if LHasRoleID then
      LRoleID := LDataset.FieldByName('role_internal_id').AsInteger
    else
      LRoleID := 0;
  finally
    FreeAndNil(LDataset);
  end;

  LPasswordHash := '';
  if LRequest.HasPassword then
    LPasswordHash := TGlobalFunction.HashHMAC256(LRequest.Password);

  try
    FConnection.StartTransaction;
    try
      FRepository.UpdateUser(LRequest, LPasswordHash);
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError);
      end;
    end;

    if LRequest.HasFullname then
      LFullname := LRequest.Fullname;
    if LRequest.HasIsActive then
      LIsActive := LRequest.IsActive;
    if LRequest.HasRoleID then begin
      LRoleID := LRequest.RoleID;
      LHasRoleID := True;
    end;

    LResponseData := TUserDTO.CreateUserResponse(
      LRequest.UserID,
      LUsername,
      LFullname,
      LIsActive,
      LHasRoleID,
      LRoleID
    );
    try
      FStatusCode := 200;
      Result := THelperResponse.CreateResponse(FStatusCode, 'User updated', LResponseData);
    finally
      FreeAndNil(LResponseData);
    end;
  except
    on E: Exception do
      Result := InternalServerError;
  end;
end;

end.
