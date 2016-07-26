unit ThreadConnectAgent;

interface

uses SysUtils, Classes
   , sgcWebSocket_Classes, sgcWebSocket_Client, sgcWebSocket
   ;

type TConnectAgentChange = procedure (const aID: Integer; const aResUser, aResProcess, aResTotal: String) of object;
type TConnectAgentStateChange = procedure (const aID, aState: Integer) of object;

type TAgentMode = (amUser, amProcess, amTotal, amSetDate, amReboot);
type TAgentModes = set of TAgentMode;

type TThreadConnectAgent = class(TThread)
  private
    FServerID: Integer;
    FServerIP: String;
    FServerPort: Integer;
    FServerName: String;
    FServerState: Integer;
    FServerStateOld: Integer;
  private
    FAgentMode: TAgentModes;
    FIsWork: Boolean;
    FIsUser: Boolean;
    FIsProcess: Boolean;
    FIsTotal: Boolean;
    FIsSetDate: Boolean;
    FIsReboot: Boolean;

    FSetDate: String;
    FProcessList: TStringList;
  private
    FResponseUser:    String;
    FResponseProcess: String;
    FResponseTotal:   String;
  private
    FAgent: TsgcWebSocketClient;
    FOnChange: TConnectAgentChange;
    FOnStateChange: TConnectAgentStateChange;
  private
    procedure Change(const aID: Integer; const aResUser, aResProcess, aResTotal: String);
    procedure StateChange(const aID, aState: Integer);
  private
    procedure onMessage(Connection: TsgcWSConnection; const Text: string);
    procedure onConnect(Connection: TsgcWSConnection);
    procedure onDisconnect(Connection: TsgcWSConnection; Code: Integer);
    procedure onError(Connection: TsgcWSConnection; const Error: string);
    procedure onException(Connection: TsgcWSConnection; E: Exception);
  private
    function isUsedCriticalProceses: Boolean;
    function isActiveUser: Boolean;
    function getProcessToString: String;
    procedure setServerState(const aState: Integer);
    procedure clearAgentData;
    procedure sendAgentProcess;
    procedure sendAgentReboot;
    procedure sendAgentTotal(const aOn: Boolean = True);
    procedure sendAgentUser(const aOn: Boolean = True);
    procedure setAgentMode(const aAgentMode: TAgentModes);
    procedure parseResponse(const aText: String; var aType: Integer; var aResponse: String);
  protected
    procedure Execute; override;
  public
    property OnChange: TConnectAgentChange read FOnChange write FOnChange;
    property OnStateChange: TConnectAgentStateChange read FOnStateChange write FOnStateChange;
  public
    property ServerID: Integer read FServerID;
    property ServerIP: String read FServerIP;
    property ServerName: String read FServerName;
    property ServerState: Integer read FServerState write FServerState;
    property ServerStateOld: Integer read FServerStateOld write FServerStateOld;
    property IsWork: Boolean read FIsWork write FIsWork;
    property AgentMode: TAgentModes read FAgentMode write setAgentMode default [amUser, amProcess, amTotal];
    property ProcessList: TStringList read FProcessList write FProcessList;
    property SetDate: String read FSetDate write FSetDate;
    property ResponseUser: String read FResponseUser;
    property ResponseProcess: String read FResponseProcess;
    property ResponseTotal: String read FResponseTotal;
  public
    constructor Create(const aId, aState, aPort: Integer; const aIP, aName: string);
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
end;

const
  cServer_NEW    = 1;
  cServer_ON     = 2;
  cServer_OFF    = 3;
  cServer_STOP   = 4;
  cServer_REBBOT = 5;

  cResponse_UNKNOWN = 0;
  cResponse_USER    = 1;
  cResponse_PROCESS = 2;
  cResponse_TOTAL   = 3;
  cResponse_REBOOT  = 4;
  cResponse_SETDATE = 5;

  cCommand_USER    = 'user';
  cCommand_PROCESS = 'process';
  cCommand_TOTAL   = 'total';
  cCommand_REBOOT  = 'reboot';
  cCommand_SETDATE = 'setdate';

  cState_ON  = 'on';
  cState_OFF = 'off';

  cProcess_CRITICAL = 1;
  cProcess_PLAIN    = 0;

  cTimeOutReboot_sec = 1;

implementation

{ TThreadConnectAgent }

procedure TThreadConnectAgent.AfterConstruction;
begin
  inherited;

  FResponseUser    := '';
  FResponseProcess := '';
  FResponseTotal   := '';

  //FProcessList := TStringList.Create;

  FAgent := TsgcWebSocketClient.Create(nil);
  try
    FAgent.Host := FServerIP;
    FAgent.Port := FServerPort;

    FAgent.OnMessage    := onMessage;
    FAgent.OnConnect    := OnConnect;
    FAgent.OnDisconnect := OnDisconnect;
    //FAgent.OnError      := OnError;
    //FAgent.OnException  := OnException;

    FAgent.WatchDog.Enabled := True;

    FAgent.Active := True;
  except
    setServerState(cServer_OFF);
  end;

  FSetDate := '01.06.2010';
end;

procedure TThreadConnectAgent.BeforeDestruction;
begin
  inherited;

  if (FAgent.Active) then
    FAgent.Active := False;

  FreeAndNil(FAgent);
  //FreeAndNil(FProcessList);
end;

procedure TThreadConnectAgent.Change(const aID: Integer; const aResUser,
  aResProcess, aResTotal: String);
begin
  if (Assigned(FOnChange)) then
    FOnChange(aID, aResUser, aResProcess, aResTotal);
end;

constructor TThreadConnectAgent.Create(const aId, aState, aPort: Integer;
  const aIP, aName: string);
begin
  inherited Create(True);

  FServerID       := aId;
  FServerIP       := aIP;
  FServerPort     := aPort;
  FServerName     := aName;
  FServerState    := aState;
  FServerStateOld := FServerState;

  FIsWork := True;

  FIsUser    := False;
  FIsProcess := False;
  FIsTotal   := False;
  FIsSetDate := False;
  FIsReboot  := False;
end;

procedure TThreadConnectAgent.Execute;
begin
  inherited;

  while (FIsWork) do
  begin
    if (FServerState = cServer_OFF) then
      continue;

    if (FIsUser) then
      sendAgentUser;

    if (FIsTotal) then
      sendAgentTotal;

    if (FIsProcess) then
      sendAgentProcess;

    if ((FIsReboot) and (FServerStateOld = cServer_REBBOT)) then
      sendAgentReboot;

    sleep(500);
  end;

end;

procedure TThreadConnectAgent.onConnect(Connection: TsgcWSConnection);
begin
  clearAgentData;

  if (FServerStateOld = cServer_REBBOT) then
    FIsReboot := True
  else
    StateChange(FServerID, cServer_ON);

  setServerState(cServer_ON);
  setAgentMode(FAgentMode);
end;

procedure TThreadConnectAgent.onDisconnect(Connection: TsgcWSConnection;
  Code: Integer);
begin
  clearAgentData;
  setServerState(cServer_OFF);
end;

procedure TThreadConnectAgent.onError(Connection: TsgcWSConnection;
  const Error: string);
begin
  clearAgentData;
  setServerState(cServer_OFF);
end;

procedure TThreadConnectAgent.onException(Connection: TsgcWSConnection;
  E: Exception);
begin
  clearAgentData;
  setServerState(cServer_OFF);
end;

procedure TThreadConnectAgent.onMessage(Connection: TsgcWSConnection;
  const Text: string);
var
  k: Integer;
  s: String;
begin
  parseResponse(Text, k, s);

  if (k = cResponse_UNKNOWN) then
    Exit;

  case k of
    cResponse_USER:
      begin
        FResponseUser := s;
        FIsUser := False;
      end;
    cResponse_PROCESS:
      begin
        FResponseProcess := s;
        FIsProcess := False;
      end;
    cResponse_TOTAL:
      begin
        FResponseTotal := s;
        FIsTotal := False;
      end;
    cResponse_SETDATE:
      FIsSetDate := False;
    cResponse_REBOOT:
    begin
      FIsReboot := False;
      FServerStateOld := cServer_OFF;
    end;
  end;

  if (k in [cResponse_USER, cResponse_PROCESS, cResponse_TOTAL, cResponse_REBOOT]) then
    Change(FServerID, FResponseUser, FResponseProcess, FResponseTotal);
end;

procedure TThreadConnectAgent.parseResponse(const aText: String; var aType: Integer;
  var aResponse: String);
const
  cTypeName: array[1..5] of string =
    (cCommand_USER, cCommand_PROCESS, cCommand_TOTAL, cCommand_REBOOT, cCommand_SETDATE);
var
  i, n: Integer;
  s: String;
begin
  aType := cResponse_UNKNOWN;

  n := AnsiPos(':', aText);
  if (n = -1) then
    Exit;

  s := Copy(aText, 1, n - 1);
  aResponse := Copy(aText, n + 1);

  for i := Low(cTypeName) to High(cTypeName) do
  begin
    if (SameText(cTypeName[i], s)) then
    begin

      case i of
        cResponse_USER:    aType := cResponse_USER;
        cResponse_PROCESS: aType := cResponse_PROCESS;
        cResponse_TOTAL:   aType := cResponse_TOTAL;
        cResponse_REBOOT:  aType := cResponse_REBOOT;
        cResponse_SETDATE: aType := cResponse_SETDATE;
      end;

      break;
    end;
  end;
end;

procedure TThreadConnectAgent.setAgentMode(const aAgentMode: TAgentModes);
begin
  FAgentMode := aAgentMode;

  FIsUser    := amUser    in FAgentMode;
  FIsProcess := amProcess in FAgentMode;
  FIsTotal   := amTotal   in FAgentMode;
  FIsSetDate := amSetDate in FAgentMode;
  FIsReboot  := amReboot  in FAgentMode;
end;

procedure TThreadConnectAgent.setServerState(const aState: Integer);
begin
  FServerState := aState;
  Change(FServerID, FResponseUser, FResponseProcess, FResponseTotal);
end;

procedure TThreadConnectAgent.StateChange(const aID, aState: Integer);
begin
  if (Assigned(FOnStateChange)) then
    FOnStateChange(aID, aState);
end;

procedure TThreadConnectAgent.clearAgentData;
begin
  FResponseUser    := '';
  FResponseProcess := '';
  FResponseTotal   := '';
end;

procedure TThreadConnectAgent.sendAgentProcess;
begin
  FAgent.WriteData(cCommand_PROCESS + '=' + getProcessToString);
end;

procedure TThreadConnectAgent.sendAgentReboot;
begin
  if (SameText(FResponseUser, EmptyStr)) then
    Exit;

  if ((isActiveUser) or (isUsedCriticalProceses)) then
    Exit;

  FAgent.WriteData(cCommand_SETDATE + '=' + FSetDate);
  FAgent.WriteData(cCommand_REBOOT  + '=' + IntToStr(cTimeOutReboot_sec));
end;

procedure TThreadConnectAgent.sendAgentTotal(const aOn: Boolean = True);
var
  s: String;
begin
  if (aOn) then
    s := cState_ON
  else
    s := cState_OFF;

  FAgent.WriteData(cCommand_TOTAL   + '=' + s);
end;

procedure TThreadConnectAgent.sendAgentUser(const aOn: Boolean = True);
var
  s: String;
begin
  if (aOn) then
    s := cState_ON
  else
    s := cState_OFF;

  FAgent.WriteData(cCommand_USER    + '=' + s);
end;

function TThreadConnectAgent.isActiveUser: Boolean;
begin
  Result := AnsiPos('ACTIVE', UpperCase(FResponseUser)) > 0;
end;

function TThreadConnectAgent.isUsedCriticalProceses: Boolean;
var
  i: integer;
  s: String;
begin
  Result := False;

  s := UpperCase(FResponseProcess);
  for i := 0 to FProcessList.Count - 1 do
  begin
    if (Integer(FProcessList.Objects[i]) = cProcess_PLAIN) then
      Continue;

    if (AnsiPos(UpperCase(FProcessList[i]), s) > 0) then
      Exit(True);
  end;

end;

function TThreadConnectAgent.getProcessToString: String;
var
  i: Integer;
  s: String;
begin
  s := '';
  for i := 0 to FProcessList.Count - 1 do
    s := s + ',' + FProcessList[i];

  if (FProcessList.Count > 0) then
    s := Copy(s, 2);

  s := '[' + s + ']';

  Result := s;
end;

end.
