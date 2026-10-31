unit BFA.HTTP.Compression;

interface

uses
  System.SysUtils, System.Classes, Web.HTTPApp;

type
  THTTPCompression = class
  private
    class function AcceptsGzip(const AHeader: string): Boolean; static;
    class function Compress(const ABytes: TBytes; ALevel: Integer): TMemoryStream; static;
    class procedure AddVary(AResponse: TWebResponse); static;
  public
    class procedure Apply(ARequest: TWebRequest; AResponse: TWebResponse); static;
  end;

implementation

uses
  System.ZLib, BFA.Core.Config;

function ParseQuality(const AValue: string; out AQuality: Integer): Boolean;
var
  I: Integer;
  LValue: string;
  LFraction: string;
begin
  AQuality := 0;
  LValue := Trim(AValue);
  Result := (LValue = '0') or (LValue = '1');
  if Result then begin
    if LValue = '1' then AQuality := 1000;
    Exit;
  end;

  Result := False;
  if (Length(LValue) < 2) or (Length(LValue) > 5) then Exit;
  if not CharInSet(LValue[1], ['0', '1']) or (LValue[2] <> '.') then Exit;
  LFraction := Copy(LValue, 3, MaxInt);
  for I := 1 to Length(LFraction) do begin
    if not CharInSet(LFraction[I], ['0'..'9']) then Exit;
    if (LValue[1] = '1') and (LFraction[I] <> '0') then Exit;
  end;
  while Length(LFraction) < 3 do LFraction := LFraction + '0';
  AQuality := StrToInt(LFraction);
  if LValue[1] = '1' then AQuality := 1000;
  Result := True;
end;

class function THTTPCompression.AcceptsGzip(const AHeader: string): Boolean;
var
  LItem, LParameter, LName: string;
  LParts: TArray<string>;
  I, LEquals, LQuality, LGzipQuality, LWildcardQuality: Integer;
  LHasQuality: Boolean;
begin
  // Explicit gzip (including q=0) takes precedence over a wildcard.
  LGzipQuality := -1;
  LWildcardQuality := -1;
  for LItem in AHeader.Split([',']) do begin
    LParts := LItem.Split([';']);
    if Length(LParts) = 0 then Continue;
    LName := Trim(LParts[0]);
    if not (SameText(LName, 'gzip') or SameText(LName, 'x-gzip') or (LName = '*')) then
      Continue;
    LQuality := 1000;
    LHasQuality := False;
    for I := 1 to High(LParts) do begin
      LParameter := Trim(LParts[I]);
      LEquals := Pos('=', LParameter);
      if (LEquals = 0) or not SameText(Trim(Copy(LParameter, 1, LEquals - 1)), 'q') or
        LHasQuality then begin
        LQuality := 0;
        Break;
      end;
      LHasQuality := True;
      if not ParseQuality(Copy(LParameter, LEquals + 1, MaxInt), LQuality) then begin
        LQuality := 0;
        Break;
      end;
    end;
    if LName = '*' then begin
      if (LWildcardQuality < 0) or (LQuality < LWildcardQuality) then
        LWildcardQuality := LQuality;
    end else if (LGzipQuality < 0) or (LQuality < LGzipQuality) then
      LGzipQuality := LQuality;
  end;
  if LGzipQuality >= 0 then
    Result := LGzipQuality > 0
  else
    Result := LWildcardQuality > 0;
end;

class function THTTPCompression.Compress(const ABytes: TBytes;
  ALevel: Integer): TMemoryStream;
var
  LState: z_stream;
  LBuffer: array[0..16383] of Byte;
  LCode, LWritten: Integer;
begin
  Result := TMemoryStream.Create;
  try
    FillChar(LState, SizeOf(LState), 0);
    // 15 + 16 requests the gzip wrapper (header and CRC trailer), not zlib/raw deflate.
    LCode := deflateInit2(LState, ALevel, Z_DEFLATED, 31, 8, Z_DEFAULT_STRATEGY);
    if LCode <> Z_OK then
      raise Exception.CreateFmt('Gzip initialization failed (%d).', [LCode]);
    try
      LState.next_in := @ABytes[0];
      LState.avail_in := Length(ABytes);
      repeat
        LState.next_out := @LBuffer[0];
        LState.avail_out := SizeOf(LBuffer);
        LCode := deflate(LState, Z_FINISH);
        if (LCode <> Z_OK) and (LCode <> Z_STREAM_END) then
          raise Exception.CreateFmt('Gzip compression failed (%d).', [LCode]);
        LWritten := SizeOf(LBuffer) - Integer(LState.avail_out);
        if LWritten > 0 then Result.WriteBuffer(LBuffer[0], LWritten);
      until LCode = Z_STREAM_END;
    finally
      deflateEnd(LState);
    end;
    Result.Position := 0;
  except
    Result.Free;
    raise;
  end;
end;

class procedure THTTPCompression.AddVary(AResponse: TWebResponse);
var
  LValue, LToken: string;
begin
  LValue := AResponse.GetCustomHeader('Vary');
  for LToken in LValue.Split([',']) do
    if (Trim(LToken) = '*') or SameText(Trim(LToken), 'Accept-Encoding') then Exit;
  if Trim(LValue) <> '' then LValue := LValue + ', ';
  AResponse.SetCustomHeader('Vary', LValue + 'Accept-Encoding');
end;

class procedure THTTPCompression.Apply(ARequest: TWebRequest; AResponse: TWebResponse);
var
  LBytes: TBytes;
  LCompressed: TMemoryStream;
  LMediaType, LDirective, LOriginalContent: string;
  LOriginalLength: Int64;
  LSeparator: Integer;
  LOriginalOwnership: Boolean;
begin
  if not Assigned(ARequest) or not Assigned(AResponse) then Exit;
  if not TServerConfig.GzipEnabled or AResponse.Sent then Exit;
  if SameText(ARequest.Method, 'HEAD') or SameText(ARequest.Method, 'CONNECT') then Exit;
  if (AResponse.StatusCode < 200) or (AResponse.StatusCode = 204) or
    (AResponse.StatusCode = 205) or (AResponse.StatusCode = 206) or
    (AResponse.StatusCode = 304) then Exit;
  if Assigned(AResponse.ContentStream) or (Trim(AResponse.ContentEncoding) <> '') then Exit;
  if (ARequest.GetFieldByName('Range') <> '') or
    (AResponse.GetCustomHeader('Content-Range') <> '') then Exit;
  // Preserve existing validators/digests that describe the uncompressed bytes.
  if (AResponse.GetCustomHeader('ETag') <> '') or
    (AResponse.GetCustomHeader('Content-MD5') <> '') or
    (AResponse.GetCustomHeader('Content-Digest') <> '') or
    (AResponse.GetCustomHeader('Digest') <> '') then Exit;
  for LDirective in AResponse.GetCustomHeader('Cache-Control').Split([',']) do
    if SameText(Trim(LDirective), 'no-transform') then Exit;
  LMediaType := Trim(AResponse.ContentType);
  LSeparator := Pos(';', LMediaType);
  if LSeparator > 0 then LMediaType := Trim(Copy(LMediaType, 1, LSeparator - 1));
  if not SameText(LMediaType, 'application/json') then Exit;

  AddVary(AResponse);
  if not AcceptsGzip(ARequest.GetFieldByName('Accept-Encoding')) then Exit;
  if AResponse.Content = '' then Exit;
  LBytes := TEncoding.UTF8.GetBytes(AResponse.Content);
  if Length(LBytes) < TServerConfig.GzipMinimumBytes then Exit;

  LCompressed := Compress(LBytes, TServerConfig.GzipLevel);
  try
    if LCompressed.Size >= Length(LBytes) then Exit;
    LOriginalContent := AResponse.Content;
    LOriginalLength := AResponse.ContentLength;
    LOriginalOwnership := AResponse.FreeContentStream;
    try
      // Indy sends ContentText before ContentStream, so clear text only after compression succeeds.
      AResponse.Content := '';
      AResponse.ContentEncoding := 'gzip';
      AResponse.FreeContentStream := True;
      AResponse.ContentStream := LCompressed;
      LCompressed := nil;
    except
      if AResponse.ContentStream = LCompressed then begin
        LCompressed := nil;
        AResponse.ContentStream := nil;
      end;
      AResponse.ContentEncoding := '';
      AResponse.Content := LOriginalContent;
      AResponse.ContentLength := LOriginalLength;
      AResponse.FreeContentStream := LOriginalOwnership;
      raise;
    end;
  finally
    LCompressed.Free;
  end;
end;

end.
