unit uFoxProDBF;

interface

uses
  Classes, SysUtils, ADODB, DB
  ;

const
  cNonError:      Integer = 0;
  cBadArgument:   Integer = 1;
  cNonConnection: Integer = 2;
  cUnknown:       Integer = 10;

type TVFP = class
  private
    fFullFilePath: String;
    fConnected: Boolean;
    fFieldsList: TStrings;

    ADODBFConnection: TADOConnection;
    qADODBF: TADOQuery;

    //Получить список полей в таблице
    procedure GetFieldList;
    //Поиск по имени поля
    function SearchField(aFieldName: String): Boolean;
    //Подключаемся к DBF файлу
    function DBFConnection(const aFullPath: String): Boolean;
    //Получить имя файла
    function GetFileName: String;
    function GetFileNameNoExt: string;
    function GetFileNameNo: string;
    //Получаем написание типа для FoXPro
    function GetDBFType(aType: TFieldType; aSize: Integer): String;
    function CorrectName(aName: string): string;
  public
    tADODBF: TADOTable;
    queryADODBF: TADOQuery;
    property FullFilePath: String read fFullFilePath write fFullFilePath;
    property FileName: String read GetFileName;
    property FileNameNoExt: String read GetFileNameNoExt;
    property FileNameNo: String read GetFileNameNo;
    property Connected: Boolean read fConnected write fConnected;
    property FieldsList: TStrings read fFieldsList;

    procedure Connect(aFullFilePath: String);
    procedure Disconnect;
    //Пока работа происходит только с типами: строкой, целым типом и датой
    function AddFileld(aFieldName: String; aType: TFieldType; aSize: Integer): Integer;
    function RemoveField(aFieldName: String): Integer;
    function RemoveUniqueKey(aKeyName: String): Integer;
    function CreateUniqKey(aFieldName: string): Integer;
    function FillUniqValue(aFieldName: string): Integer;
    function UpdateField(aFieldKey: string; aKeyValue: integer; aUpdateField, aUpdateValue: string): integer;
    procedure Commit;

    constructor Create();
    destructor Destroy;
end;

implementation

procedure TVFP.Commit;
begin
  ADODBFConnection.Close;
  ADODBFConnection.Open;
  //tADODBF.Active := True;
  GetFieldList;
end;

function TVFP.GetFileNameNoExt: string;
begin
  Result := '[' + StringReplace(ExtractFileName(fFullFilePath), ExtractFileExt(fFullFilePath), '', []) + ']';
end;

function TVFP.GetFileNameNo: string;
begin
  Result := StringReplace(ExtractFileName(fFullFilePath), ExtractFileExt(fFullFilePath), '', []);
end;

function TVFP.CorrectName(aName: string): string;
const
  scInvalidChars = '-!@#$%^&()=+[]{}';
var
  i: Integer;
begin
  Result := aName;

  for I := 1 to length(scInvalidChars) do
    Result := StringReplace(Result, scInvalidChars[i], '_', [rfReplaceAll, rfIgnoreCase]);
end;

function TVFP.GetDBFType(aType: TFieldType; aSize: Integer): String;
var
  s: String;
begin
  case (Integer(aType)) of
    Integer(ftString): s := 'C(' + IntToStr(aSize) + ')';
    Integer(ftSmallint), Integer(ftInteger), Integer(ftWord), Integer(ftFloat): s := 'N(' + IntToStr(aSize) + ')';
    Integer(ftDate), Integer(ftDateTime): s:= 'D'
    else
      s := 'C(10)'; // Значение по умолчанию, для не описанных типов
  end;
  Result := s;
end;

function TVFP.GetFileName: String;
begin
  Result := ExtractFileName(fFullFilePath);
end;

procedure TVFP.GetFieldList;
var
  i: Integer;
begin
  Assert(Assigned(fFieldsList), '{64E3ED23-7DC7-4CD4-9F2A-1C0DABC83B6C}');
  //Assert(tADODBF.Active, '{3E5F6377-40C6-432E-83C0-23BBCD13635C}');

  fFieldsList.Clear;
  qADODBF.SQL.Text := 'select * from ' + FileNameNoExt + ' where 1 = 2';
  qADODBF.Open;
  for i := 0 to qADODBF.FieldCount - 1 do
    fFieldsList.Add(qADODBF.Fields[i].DisplayName);
end;

function TVFP.SearchField(aFieldName: String): Boolean;
begin
  Assert(Assigned(fFieldsList), '{F7B80790-D1BB-4F9A-9A47-95C533D40A9B}');

  Result := False;

  if (fFieldsList.Count = 0) then Exit;
  if (fFieldsList.IndexOf(aFieldName) = -1) then Exit;

  Result := True;
end;

function TVFP.DBFConnection(const aFullPath: String): Boolean;
Var
  cs: String;
begin
  //Нужно добавить проверку наличия драйвера
  //DELETED=False - указавывает, что с запися помеченными на удаление, работаем как с обычными
  cs := Format(
    'Provider=VFPOLEDB.1;Data Source=%s;DELETED=False'
    , [aFullPath]
   ) ;

  Result := False;
//  if (ADODBFConnection.Connected) then
  ADODBFConnection.Close;
  ADODBFConnection.ConnectionString := cs;
  tADODBF.TableName := FileNameNoExt;
  try
    ADODBFConnection.Open;
    //tADODBF.Open;
  except
    fFullFilePath := '';
    Exit;
  end;
  Result := True;//tADODBF.Active;
end;

constructor TVFP.Create;
begin
  Inherited;
  fFullFilePath := '';
  fConnected := False;
  fFieldsList := TStringList.Create;
  ADODBFConnection := TADOConnection.Create(nil);
  ADODBFConnection.Mode := cmShareExclusive;
  qADODBF := TADOQuery.Create(nil);
  queryADODBF := TADOQuery.Create(nil);
  tADODBF := TADOTable.Create(nil);
  tADODBF.LockType := ltBatchOptimistic;
  qADODBF.Connection := ADODBFConnection;
  queryADODBF.Connection := ADODBFConnection;
  tADODBF.Connection := ADODBFConnection;
end;

destructor TVFP.Destroy;
begin
  fFieldsList.Free;
  ADODBFConnection.Free;
  qADODBF.Free;
  tADODBF.Free;
  queryADODBF.Free;

  inherited;
end;

procedure TVFP.Connect(aFullFilePath: String);
begin
  if (not FileExists(aFullFilePath)) then Exit;

  fFullFilePath := aFullFilePath;
  if (not DBFConnection(aFullFilePath)) then Exit;

  GetFieldList;
  fConnected := True;
end;

procedure TVFP.Disconnect;
begin
  ADODBFConnection.Close;
  fFullFilePath := '';
  fConnected := False;
  fFieldsList.Clear;
end;

function TVFP.AddFileld(aFieldName: String; aType: TFieldType; aSize: Integer): Integer;
begin
  Assert(ADODBFConnection.Connected, '{F7F75ACF-AA1C-432F-914B-981597F7F6F5}');

  //Плохие условия
  if (not fConnected) then
  begin
    Result := cNonConnection;
    Exit;
  end;
  if (aFieldName = '') then
  begin
    Result := cBadArgument;
    Exit;
  end;

  //Поле уже добавлено
  if (SearchField(aFieldName)) then
  begin
    Result := cNonError;
    Exit;
  end;

  qADODBF.SQL.Text := 'alter table ' + FileNameNoExt
                           + ' ADD ' + aFieldName + ' ' + GetDBFType(aType, aSize);
  try
    qADODBF.ExecSQL;
  except
    Result := cUnknown;
  end;
  Result := cNonError;
end;

function TVFP.RemoveField(aFieldName: String): Integer;
begin
  Assert(ADODBFConnection.Connected, '{2B019729-D2A5-4A0A-9130-33C14ECF91DF}');

  //Плохие условия
  if (not fConnected) then
  begin
    Result := cNonConnection;
    Exit;
  end;
  if (not SearchField(aFieldName)) then
  begin
    Result := cBadArgument;
    Exit;
  end;

  qADODBF.SQL.Text := 'alter table ' + FileNameNoExt
                   + ' DROP COLUMN ' + aFieldName;
  try
    qADODBF.ExecSQL;
    //Commit;
  except
    Result := cUnknown;
  end;
  Result := cNonError;
end;

function TVFP.RemoveUniqueKey(aKeyName: String): Integer;
begin
  Assert(ADODBFConnection.Connected, '{0EB06581-C83C-4EDF-8AB3-3E362A78D8E4}');

  //Плохие условия
  if (not fConnected) then
  begin
    Result := cNonConnection;
    Exit;
  end;

  qADODBF.SQL.Text := 'alter table '     + FileNameNoExt
                   + ' DROP UNIQUE TAG ' + aKeyName;
  try
    qADODBF.ExecSQL;
  except
    Result := cUnknown;
  end;
  Result := cNonError;
end;

function TVFP.FillUniqValue(aFieldName: string): Integer;
begin
  //Пока работает только с числовым типом
  if (not SearchField(aFieldName)) then
  begin
    Result := cBadArgument;
    Exit;
  end;

  qADODBF.SQL.Text := 'update ' + FileNameNoExt + ' set ' + aFieldName + ' = recno()';
  try
    qADODBF.ExecSQL;
  except
    Result := cUnknown;
    Exit;
  end;
  Result := cNonError;
end;

function TVFP.CreateUniqKey(aFieldName: string): Integer;
begin
  //Пока работает только с числовым типом
  if (not SearchField(aFieldName)) then
  begin
    Result := cBadArgument;
    Exit;
  end;

  try
    qADODBF.SQL.Text := 'ALTER TABLE ' + FileNameNoExt + ' ADD unique ' + aFieldName;
    qADODBF.ExecSQL;
  Except
    Result := cUnknown;
    Exit;
  end;
  Result := cNonError;
end;

function TVFP.UpdateField(aFieldKey: string; aKeyValue: integer; aUpdateField, aUpdateValue: string): integer;
begin
  qADODBF.SQL.Text := 'update ' + FileNameNoExt +
                            ' set '   + aUpdateField + ' = ' + aUpdateValue +
                            ' where ' + aFieldKey    + ' = ' + IntToStr(aKeyValue);
  try
    qADODBF.ExecSQL;
  except
    Result := cUnknown;
    Exit;
  end;
  Result := cNonError;
end;

end.
