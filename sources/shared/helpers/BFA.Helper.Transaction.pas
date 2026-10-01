unit BFA.Helper.Transaction;

interface

uses
  FireDAC.Comp.Client;

type
  THelperTransaction = class
  public
    class procedure Rollback(AConnection: TFDConnection); static;
  end;

implementation

uses System.SysUtils, BFA.Logger;

class procedure THelperTransaction.Rollback(AConnection: TFDConnection);
var LOriginal: TObject;
begin
  LOriginal := ExceptObject;
  try
    if Assigned(AConnection) and AConnection.InTransaction then AConnection.Rollback;
  except
    on E: Exception do begin
      THelperLogger.RollbackFailed(E);
      if not Assigned(LOriginal) then raise;
    end;
  end;
end;

end.
