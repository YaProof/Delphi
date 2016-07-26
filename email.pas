unit email;

interface

uses SysUtils
   , IdMessage, IdSMTP, IdCharsets
   ;

type TEmail = class(TObject)
  private
    fSMTP: TidSmtp;
    fMessage: TidMessage;
  private
    procedure CreateStartObject;
    function getHost: String;
    procedure setHost(const aValue: String);
    function getUserName: String;
    procedure setUserName(const aValue: String);
    function getPassword: String;
    procedure setPassword(const aValue: String);
    function getPort: Word;
    procedure setPort(const aValue: Word);
    function getSubject: String;
    procedure setSubject(const aValue: String);
    function getRecipient: String;
    procedure setRecipient(const aValue: String);
    function getAddress: String;
    procedure setAddress(const aValue: String);
    function getBody: String;
    procedure setBody(const aValue: String);
    function getName: String;
    procedure setName(const aValue: String);
    function getConnected: Boolean;
  public
    //SMTP сервер
    property Host: String read getHost write setHost;
    //Логин к серверу
    property UserName: String read getUserName write setUserName;
    //Пароль к серверу
    property Password: String read getPassword write setPassword;
    //Порт к серверу
    property Port: Word read getPort write setPort;
    //Тема письма
    property Subject: String read getSubject write setSubject;
    //Адрес получателей
    property Recipient: String read getRecipient write setRecipient;
    //Адрес отправителя
    property Address: String read getAddress write setAddress;
    //Тело письма
    property Body: String read getBody write setBody;
    //Электронная подпись
    property Name: String read getName write setName;
    property isConnected: Boolean read getConnected;
  public
    function SendMessage(aSubject, aRecipient, aMessage: String): Boolean; overload;
    function SendMessage: Boolean; overload;
  public
    constructor Create; overload;
    constructor Create(aHost, aUserName, aPassword: String; aPort: Integer); overload;
    destructor Destroy; override;
end;

implementation

{ TEmail }

constructor TEmail.Create;
begin
  CreateStartObject;
end;

constructor TEmail.Create(aHost, aUserName, aPassword: String; aPort: Integer);
begin
  CreateStartObject;

  fSMTP.Host     := aHost;
  fSMTP.Username := aUserName;
  fSMTP.Password := aPassword;
  fSMTP.Port     := aPort;
end;

destructor TEmail.Destroy;
begin
  FreeAndNil(fSMTP);
  FreeAndNil(fMessage);

  inherited;
end;

procedure TEmail.CreateStartObject;
begin
  fMessage := TidMessage.Create(nil);
  fSMTP := TidSmtp.Create(nil);

  //fMessage.CharSet := cUTF8;
  fMessage.Encoding := meMIME;
  fMessage.ContentType := 'text/plain';
  fMessage.CharSet := IdCharsetNames[idcs_UTF_8];
  fMessage.ContentTransferEncoding := 'base64';
end;

function TEmail.getAddress: String;
begin
  Result := fMessage.From.Address;
end;

function TEmail.getBody: String;
begin
  Result := fMessage.Body.Text;
end;

function TEmail.getConnected: Boolean;
begin
  fSMTP.Connect;
  Result := fSMTP.Connected;
  fSMTP.Disconnect;
end;

function TEmail.getHost: String;
begin
  Result := fSMTP.Host;
end;

function TEmail.getName: String;
begin
  Result := fMessage.From.Name;
end;

function TEmail.getPassword: String;
begin
  Result := fSMTP.Password;
end;

function TEmail.getPort: Word;
begin
  Result := fSMTP.Port;
end;

function TEmail.getRecipient: String;
begin
  Result := fMessage.Recipients.EMailAddresses;
end;

function TEmail.getSubject: String;
begin
  Result := fMessage.Subject;
end;

function TEmail.getUserName: String;
begin
  Result := fSMTP.Username;
end;

function TEmail.SendMessage(aSubject, aRecipient, aMessage: String): Boolean;
begin
  Subject   := aSubject;
  Recipient := aRecipient;
  Body      := aMessage;

  Result := SendMessage;
end;

function TEmail.SendMessage: Boolean;
begin
  Result := False;
  fSMTP.Connect;
  try
    if (not fSMTP.Connected) then
      Exit;

    fSMTP.Send(fMessage);
    Result := True;
  finally
    fSMTP.Disconnect;
  end;
end;

procedure TEmail.setAddress(const aValue: String);
var
  s, n: String;
begin
  s := fMessage.From.Address;
  n := fMessage.From.Name;

  if (SameText(s, n)) then
    fMessage.From.Name := aValue;

  if (SameText(n, EmptyStr)) then
    fMessage.From.Name := aValue;

  fMessage.From.Address := aValue;
end;

procedure TEmail.setBody(const aValue: String);
begin
  //fMessage.Body.Text := UTF8Encode(aValue);
  fMessage.Body.Text := AnsiToUtf8(aValue);
end;

procedure TEmail.setHost(const aValue: String);
begin
  fSMTP.Host := aValue;
end;

procedure TEmail.setName(const aValue: String);
begin
  fMessage.From.Name := aValue;
end;

procedure TEmail.setPassword(const aValue: String);
begin
  fSMTP.Password := aValue;
end;

procedure TEmail.setPort(const aValue: Word);
begin
  fSMTP.Port := aValue;
end;

procedure TEmail.setRecipient(const aValue: String);
begin
  fMessage.Recipients.EMailAddresses := aValue;
end;

procedure TEmail.setSubject(const aValue: String);
begin
  fMessage.Subject := UTF8Encode(aValue);
end;

procedure TEmail.setUserName(const aValue: String);
begin
  fSMTP.Username := aValue;
end;

end.
