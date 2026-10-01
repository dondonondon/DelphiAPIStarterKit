unit BFA.Helper.Clock;

interface

uses System.SysUtils;

type
  THelperClock = class
  public
    class function UTCNow: TDateTime; static;
    class function UnixNow: Int64; static;
    class function UnixUTC(AValue: TDateTime): Int64; static;
    class function ISO8601UTC(AValue: TDateTime): string; static;
  end;

implementation

uses System.DateUtils;

class function THelperClock.UTCNow: TDateTime;
begin
  Result := TTimeZone.Local.ToUniversalTime(Now);
end;

class function THelperClock.UnixNow: Int64;
begin
  Result := UnixUTC(UTCNow);
end;

class function THelperClock.UnixUTC(AValue: TDateTime): Int64;
begin
  Result := DateTimeToUnix(AValue, True);
end;

class function THelperClock.ISO8601UTC(AValue: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', AValue, TFormatSettings.Invariant);
end;

end.
