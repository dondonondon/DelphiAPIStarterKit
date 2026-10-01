unit DB.Helper.Query;

interface

uses
  System.Variants,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client;

type
  TQueryFunction = class
    class procedure SQLAdd(Query: TFDQuery; SQL: string; ClearPrior: Boolean = False); overload;
    class procedure SQLOpen(Query: TFDQuery; WriteLog: Boolean = True); overload;
    class procedure ExecSQL(Query: TFDQuery; WriteLog: Boolean = True); overload;
    class procedure SQLParamByName(Query: TFDQuery; ParamStr: string; Value: Variant); overload;
  end;

  THelperDatabase = class
  public
    class function CreateQuery(AConnection: TFDConnection): TFDQuery; static;
  end;

implementation

class function THelperDatabase.CreateQuery(AConnection: TFDConnection): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := AConnection;
  Result.FetchOptions.RowsetSize := 1000;
end;

class procedure TQueryFunction.ExecSQL(Query: TFDQuery; WriteLog: Boolean);
begin
  Query.Prepared;
  Query.ExecSQL;
end;

class procedure TQueryFunction.SQLAdd(Query: TFDQuery; SQL: string;
  ClearPrior: Boolean);
begin
  if ClearPrior then
    Query.SQL.Clear;

  Query.SQL.Add(SQL);
end;

class procedure TQueryFunction.SQLOpen(Query: TFDQuery; WriteLog: Boolean);
begin
  Query.Prepared;
  Query.Open;
end;

class procedure TQueryFunction.SQLParamByName(Query: TFDQuery;
  ParamStr: string; Value: Variant);
begin
  Query.ParamByName(ParamStr).Value := Value;
end;

end.
