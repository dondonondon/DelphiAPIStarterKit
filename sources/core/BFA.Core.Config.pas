unit BFA.Core.Config;

interface

type
  TExecFunctionRest = function: string of object;

  TServerConfig = class
  public
    const
      MAX_FILE_SIZE = 4 * 1024 * 1024;
  end;

var
  COUNTER_HIT_REQUEST: Int64;

implementation

end.
