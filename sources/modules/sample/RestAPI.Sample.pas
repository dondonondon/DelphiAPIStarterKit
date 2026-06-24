unit RestAPI.Sample;

interface

uses
  System.SysUtils, System.Classes,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs, FireDAC.Phys.SQLiteWrapper.Stat,
  Data.DB, FireDAC.Comp.Client, FireDAC.Phys.MSSQL, FireDAC.Phys.MSSQLDef,
  System.JSON, System.NetEncoding,
  DBClient, System.StrUtils, System.DateUtils,

  System.SyncObjs, Web.HTTPApp, System.Math;

type
  ClassSample = class(TPersistent)
  published
//    function Verify(AConnection : TFDConnection; AData : TFDMemTable;
//      AWebAction : TWebActionItem; ARequest: TWebRequest; AResponse: TWebResponse; out AStatusCode : Integer) : String;
  end;

implementation

uses BFA.Helper.Dataset, BFA.Helper.Strings, BFA.Core.Config,
  BFA.Core.Response, BFA.Core.Request;

end.
