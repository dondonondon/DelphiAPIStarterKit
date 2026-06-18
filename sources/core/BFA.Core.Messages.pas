unit BFA.Core.Messages;

interface

uses
  System.SysUtils, System.Classes,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs, FireDAC.Phys.SQLiteWrapper.Stat,
  Data.DB, FireDAC.Comp.Client, FireDAC.Phys.MSSQL, FireDAC.Phys.MSSQLDef,
  System.JSON, System.NetEncoding,
  DBClient, System.StrUtils, System.DateUtils;

type
  TRestMessage = class
    const
      // Informational responses;
      CONTINUE_MESSAGE = 'Continue';
      SWITCHING_PROTOCOLS_MESSAGE = 'Switching Protocols';
      PROCESSING_MESSAGE = 'Processing';
      EARLY_HINTS_MESSAGE = 'Early Hints';

      // Successful responses;
      OK_MESSAGE = 'OK';
      CREATED_MESSAGE = 'Created';
      ACCEPTED_MESSAGE = 'Accepted';
      NON_AUTHORITATIVE_INFORMATION_MESSAGE = 'Non-Authoritative Information';
      NO_CONTENT_MESSAGE = 'No Content';
      RESET_CONTENT_MESSAGE = 'Reset Content';
      PARTIAL_CONTENT_MESSAGE = 'Partial Content';
      MULTI_STATUS_MESSAGE = 'Multi-Status';
      ALREADY_REPORTED_MESSAGE = 'Already Reported';
      IM_USED_MESSAGE = 'IM Used';

      // Redirection messages;
      MULTIPLE_CHOICES_MESSAGE = 'Multiple Choices';
      MOVED_PERMANENTLY_MESSAGE = 'Moved Permanently';
      FOUND_MESSAGE = 'Found';
      SEE_OTHER_MESSAGE = 'See Other';
      NOT_MODIFIED_MESSAGE = 'Not Modified';
      USE_PROXY_MESSAGE = 'Use Proxy';
      SWITCH_PROXY_MESSAGE = 'Switch Proxy';
      TEMPORARY_REDIRECT_MESSAGE = 'Temporary Redirect';
      PERMANENT_REDIRECT_MESSAGE = 'Permanent Redirect';

      // Client error responses;
      BAD_REQUEST_MESSAGE = 'Bad Request';
      UNAUTHORIZED_MESSAGE = 'Unauthorized';
      PAYMENT_REQUIRED_MESSAGE = 'Payment Required';
      FORBIDDEN_MESSAGE = 'Forbidden';
      NOT_FOUND_MESSAGE = 'Not Found';
      METHOD_NOT_ALLOWED_MESSAGE = 'Method Not Allowed';
      NOT_ACCEPTABLE_MESSAGE = 'Not Acceptable';
      PROXY_AUTHENTICATION_REQUIRED_MESSAGE = 'Proxy Authentication Required';
      REQUEST_TIMEOUT_MESSAGE = 'Request Timeout';
      CONFLICT_MESSAGE = 'Conflict';
      GONE_MESSAGE = 'Gone';
      LENGTH_REQUIRED_MESSAGE = 'Length Required';
      PRECONDITION_FAILED_MESSAGE = 'Precondition Failed';
      PAYLOAD_TOO_LARGE_MESSAGE = 'Payload Too Large';
      URI_TOO_LONG_MESSAGE = 'URI Too Long';
      UNSUPPORTED_MEDIA_TYPE_MESSAGE = 'Unsupported Media Type';
      RANGE_NOT_SATISFIABLE_MESSAGE = 'Range Not Satisfiable';
      EXPECTATION_FAILED_MESSAGE = 'Expectation Failed';
      IM_A_TEAPOT_MESSAGE = 'I''m a teapot';
      MISDIRECTED_REQUEST_MESSAGE = 'Misdirected Request';
      UNPROCESSABLE_ENTITY_MESSAGE = 'Unprocessable Entity';
      LOCKED_MESSAGE = 'Locked';
      FAILED_DEPENDENCY_MESSAGE = 'Failed Dependency';
      TOO_EARLY_MESSAGE = 'Too Early';
      UPGRADE_REQUIRED_MESSAGE = 'Upgrade Required';
      PRECONDITION_REQUIRED_MESSAGE = 'Precondition Required';
      TOO_MANY_REQUESTS_MESSAGE = 'Too Many Requests';
      REQUEST_HEADER_FIELDS_TOO_LARGE_MESSAGE = 'Request Header Fields Too Large';
      UNAVAILABLE_FOR_LEGAL_REASONS_MESSAGE = 'Unavailable For Legal Reasons';

      // Server error responses;
      INTERNAL_SERVER_ERROR_MESSAGE = 'Internal Server Error';
      NOT_IMPLEMENTED_MESSAGE = 'Not Implemented';
      BAD_GATEWAY_MESSAGE = 'Bad Gateway';
      SERVICE_UNAVAILABLE_MESSAGE = 'Service Unavailable';
      GATEWAY_TIMEOUT_MESSAGE = 'Gateway Timeout';
      HTTP_VERSION_NOT_SUPPORTED_MESSAGE = 'HTTP Version Not Supported';
      VARIANT_ALSO_NEGOTIATES_MESSAGE = 'Variant Also Negotiates';
      INSUFFICIENT_STORAGE_MESSAGE = 'Insufficient Storage';
      LOOP_DETECTED_MESSAGE = 'Loop Detected';
      NOT_EXTENDED_MESSAGE = 'Not Extended';
      NETWORK_AUTHENTICATION_REQUIRED_MESSAGE = 'Network Authentication Required';

    class function GetMessage(AStatusCode: Integer): string;
  end;

  TRestStatus = class
    const
      // Informational responses;
//      CONTINUE = 100;
      SWITCHING_PROTOCOLS = 101;
      PROCESSING = 102;
      EARLY_HINTS = 103;

      // Successful responses;
      OK = 200;
      CREATED = 201;
      ACCEPTED = 202;
      NON_AUTHORITATIVE_INFORMATION = 203;
      NO_CONTENT = 204;
      RESET_CONTENT = 205;
      PARTIAL_CONTENT = 206;
      MULTI_STATUS = 207;
      ALREADY_REPORTED = 208;
      IM_USED = 226;

      // Redirection messages;
      MULTIPLE_CHOICES = 300;
      MOVED_PERMANENTLY = 301;
      FOUND = 302;
      SEE_OTHER = 303;
      NOT_MODIFIED = 304;
      USE_PROXY = 305;
      SWITCH_PROXY = 306;
      TEMPORARY_REDIRECT = 307;
      PERMANENT_REDIRECT = 308;

      // Client error responses;
      BAD_REQUEST = 400;
      UNAUTHORIZED = 401;
      PAYMENT_REQUIRED = 402;
      FORBIDDEN = 403;
      NOT_FOUND = 404;
      METHOD_NOT_ALLOWED = 405;
      NOT_ACCEPTABLE = 406;
      PROXY_AUTHENTICATION_REQUIRED = 407;
      REQUEST_TIMEOUT = 408;
      CONFLICT = 409;
      GONE = 410;
      LENGTH_REQUIRED = 411;
      PRECONDITION_FAILED = 412;
      PAYLOAD_TOO_LARGE = 413;
      URI_TOO_LONG = 414;
      UNSUPPORTED_MEDIA_TYPE = 415;
      RANGE_NOT_SATISFIABLE = 416;
      EXPECTATION_FAILED = 417;
      IM_A_TEAPOT = 418;
      MISDIRECTED_REQUEST = 421;
      UNPROCESSABLE_ENTITY = 422;
      LOCKED = 423;
      FAILED_DEPENDENCY = 424;
      TOO_EARLY = 425;
      UPGRADE_REQUIRED = 426;
      PRECONDITION_REQUIRED = 428;
      TOO_MANY_REQUESTS = 429;
      REQUEST_HEADER_FIELDS_TOO_LARGE = 431;
      UNAVAILABLE_FOR_LEGAL_REASONS = 451;

      // Server error responses;
      INTERNAL_SERVER_ERROR = 500;
      NOT_IMPLEMENTED = 501;
      BAD_GATEWAY = 502;
      SERVICE_UNAVAILABLE = 503;
      GATEWAY_TIMEOUT = 504;
      HTTP_VERSION_NOT_SUPPORTED = 505;
      VARIANT_ALSO_NEGOTIATES = 506;
      INSUFFICIENT_STORAGE = 507;
      LOOP_DETECTED = 508;
      NOT_EXTENDED = 510;
      NETWORK_AUTHENTICATION_REQUIRED = 511;
  end;

implementation

{ TRestMessage }

class function TRestMessage.GetMessage(AStatusCode: Integer): string;
begin
  case AStatusCode of
    // Informational
    100: Result := CONTINUE_MESSAGE;
    101: Result := SWITCHING_PROTOCOLS_MESSAGE;
    102: Result := PROCESSING_MESSAGE;
    103: Result := EARLY_HINTS_MESSAGE;

    // Successful
    200: Result := OK_MESSAGE;
    201: Result := CREATED_MESSAGE;
    202: Result := ACCEPTED_MESSAGE;
    203: Result := NON_AUTHORITATIVE_INFORMATION_MESSAGE;
    204: Result := NO_CONTENT_MESSAGE;
    205: Result := RESET_CONTENT_MESSAGE;
    206: Result := PARTIAL_CONTENT_MESSAGE;
    207: Result := MULTI_STATUS_MESSAGE;
    208: Result := ALREADY_REPORTED_MESSAGE;
    226: Result := IM_USED_MESSAGE;

    // Redirection
    300: Result := MULTIPLE_CHOICES_MESSAGE;
    301: Result := MOVED_PERMANENTLY_MESSAGE;
    302: Result := FOUND_MESSAGE;
    303: Result := SEE_OTHER_MESSAGE;
    304: Result := NOT_MODIFIED_MESSAGE;
    305: Result := USE_PROXY_MESSAGE;
    306: Result := SWITCH_PROXY_MESSAGE;
    307: Result := TEMPORARY_REDIRECT_MESSAGE;
    308: Result := PERMANENT_REDIRECT_MESSAGE;

    // Client error
    400: Result := BAD_REQUEST_MESSAGE;
    401: Result := UNAUTHORIZED_MESSAGE;
    402: Result := PAYMENT_REQUIRED_MESSAGE;
    403: Result := FORBIDDEN_MESSAGE;
    404: Result := NOT_FOUND_MESSAGE;
    405: Result := METHOD_NOT_ALLOWED_MESSAGE;
    406: Result := NOT_ACCEPTABLE_MESSAGE;
    407: Result := PROXY_AUTHENTICATION_REQUIRED_MESSAGE;
    408: Result := REQUEST_TIMEOUT_MESSAGE;
    409: Result := CONFLICT_MESSAGE;
    410: Result := GONE_MESSAGE;
    411: Result := LENGTH_REQUIRED_MESSAGE;
    412: Result := PRECONDITION_FAILED_MESSAGE;
    413: Result := PAYLOAD_TOO_LARGE_MESSAGE;
    414: Result := URI_TOO_LONG_MESSAGE;
    415: Result := UNSUPPORTED_MEDIA_TYPE_MESSAGE;
    416: Result := RANGE_NOT_SATISFIABLE_MESSAGE;
    417: Result := EXPECTATION_FAILED_MESSAGE;
    418: Result := IM_A_TEAPOT_MESSAGE;
    421: Result := MISDIRECTED_REQUEST_MESSAGE;
    422: Result := UNPROCESSABLE_ENTITY_MESSAGE;
    423: Result := LOCKED_MESSAGE;
    424: Result := FAILED_DEPENDENCY_MESSAGE;
    425: Result := TOO_EARLY_MESSAGE;
    426: Result := UPGRADE_REQUIRED_MESSAGE;
    428: Result := PRECONDITION_REQUIRED_MESSAGE;
    429: Result := TOO_MANY_REQUESTS_MESSAGE;
    431: Result := REQUEST_HEADER_FIELDS_TOO_LARGE_MESSAGE;
    451: Result := UNAVAILABLE_FOR_LEGAL_REASONS_MESSAGE;

    // Server error
    500: Result := INTERNAL_SERVER_ERROR_MESSAGE;
    501: Result := NOT_IMPLEMENTED_MESSAGE;
    502: Result := BAD_GATEWAY_MESSAGE;
    503: Result := SERVICE_UNAVAILABLE_MESSAGE;
    504: Result := GATEWAY_TIMEOUT_MESSAGE;
    505: Result := HTTP_VERSION_NOT_SUPPORTED_MESSAGE;
    506: Result := VARIANT_ALSO_NEGOTIATES_MESSAGE;
    507: Result := INSUFFICIENT_STORAGE_MESSAGE;
    508: Result := LOOP_DETECTED_MESSAGE;
    510: Result := NOT_EXTENDED_MESSAGE;
    511: Result := NETWORK_AUTHENTICATION_REQUIRED_MESSAGE;
  else
    Result := Format('Status %d', [AStatusCode]);
  end;
end;

end.
