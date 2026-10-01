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

{ THelperTransaction }

class procedure THelperTransaction.Rollback(AConnection: TFDConnection);
begin
  if Assigned(AConnection) and AConnection.InTransaction then
    AConnection.Rollback;
end;

end.
