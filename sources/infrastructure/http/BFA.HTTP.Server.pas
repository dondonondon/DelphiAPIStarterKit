unit BFA.HTTP.Server;

interface

uses
  System.SyncObjs, IdHTTPWebBrokerBridge, IdContext, IdCustomHTTPServer;

type
  TBoundedHTTPWebBrokerBridge = class(TIdHTTPWebBrokerBridge)
  private
    FWorkers: TSemaphore;
    FAdmission: TSemaphore;
    procedure Busy(AResponse: TIdHTTPResponseInfo);
  protected
    procedure DoCommandGet(AThread: TIdContext; ARequest: TIdHTTPRequestInfo;
      AResponse: TIdHTTPResponseInfo); override;
  public
    destructor Destroy; override;
    procedure ConfigureRequestLimit(ALimit: Integer);
  end;

implementation

uses
  System.SysUtils, BFA.Core.Response;

procedure TBoundedHTTPWebBrokerBridge.ConfigureRequestLimit(ALimit: Integer);
begin
  if Active or Assigned(FWorkers) then
    raise EInvalidOpException.Create('Configure the request limit once before starting HTTP.');
  if (ALimit < 1) or (ALimit > MaxInt div 2) then
    raise EArgumentOutOfRangeException.Create('Invalid HTTP request limit.');
  FWorkers := TSemaphore.Create(nil, ALimit, ALimit, '');
  FAdmission := TSemaphore.Create(nil, ALimit * 2, ALimit * 2, '');
end;

destructor TBoundedHTTPWebBrokerBridge.Destroy;
begin
  inherited;
  FAdmission.Free;
  FWorkers.Free;
end;

procedure TBoundedHTTPWebBrokerBridge.Busy(AResponse: TIdHTTPResponseInfo);
begin
  AResponse.ResponseNo := 503;
  AResponse.ContentType := 'application/json; charset=utf-8';
  AResponse.CustomHeaders.Values['Retry-After'] := '1';
  AResponse.ContentText := THelperResponse.CreateResponse(503, 'Server busy. Please try again later.');
end;

procedure TBoundedHTTPWebBrokerBridge.DoCommandGet(AThread: TIdContext;
  ARequest: TIdHTTPRequestInfo; AResponse: TIdHTTPResponseInfo);
begin
  if not Assigned(FWorkers) then
    raise EInvalidOpException.Create('HTTP request limit is not configured.');
  if FAdmission.WaitFor(0) <> wrSignaled then begin
    Busy(AResponse);
    Exit;
  end;
  try
    if FWorkers.WaitFor(5000) <> wrSignaled then begin
      Busy(AResponse);
      Exit;
    end;
    try
      inherited DoCommandGet(AThread, ARequest, AResponse);
    finally
      FWorkers.Release;
    end;
  finally
    FAdmission.Release;
  end;
end;

end.
