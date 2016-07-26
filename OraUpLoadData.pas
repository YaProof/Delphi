unit OraUpLoadData;

interface

uses
  Windows, SysUtils, Classes
  , DB
  , Oracle
  , OracleData
  , Contnrs
  ;

{$IFDEF Unicode}
type TData = array of array of AnsiString;
{$ELSE}
type TData = array of array of String;
{$ENDIF}

type TUpLoadField = class
  private
    fid: Integer;
    fUserColumnNum: Integer;
    fName: string;
    fColumnType: TDirectPathColumnType;
    fUsed: Boolean;
  public
    property Id: Integer read fId;
    property UserColumnNum: Integer read fUserColumnNum write fUserColumnNum;
    property Name: string read fName write fName;
    property ColumnType: TDirectPathColumnType read fColumnType write fColumnType;
    property Used: Boolean read fUsed write fUsed;
end;

type TOracleUpLoadData = class
  private
    fOraSession: TOracleSession;
    fTableName: string;
    fOraDirectPath: TOracleDirectPathLoader;
    fBufferSize: Cardinal;
    fUsedColumnNum: Boolean;
    fArrIdColumns: array of array of Integer;
    fUploadFields: tObjectList;
  private
    procedure SetId;
    procedure SetFields;
    procedure ODPPrepare;
    procedure SetBufferSize(aValue: Cardinal);
    function SetArrIdColumns: Boolean;
    function GetUpLoadFields(index: Integer): TUpLoadField;
  public
    property TableName: string read fTableName;
    property BufferSize: cardinal read fBufferSize write SetBufferSize;
    property Fields[index: integer]: TUpLoadField read GetUpLoadFields; default;
    property UsedColumnNum: Boolean read fUsedColumnNum write fUsedColumnNum; //Будут использоваться TUpLoadField.UserColumnNum
  public
    function FieldsCount: Integer;
    function FieldsUsedCount: Integer;
    function UpLoad(aArData: TData): Boolean; overload; virtual; //[row, column]
    function UpLoad(aDS: TDataSet): Boolean; overload; virtual;
  public
    constructor Create(aOraSession: TOracleSession; aTableName: string); overload;
    constructor Create(aDataBase, aUserName, aPassword, aTableName: string); overload;
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
end;

implementation

procedure TOracleUpLoadData.SetId;
var
  i: Integer;
begin
  for i := 0 to fUploadFields.Count - 1 do
    Fields[i].fid := i;
end;

procedure TOracleUpLoadData.SetFields;
var
  i: Integer;
  t: TUpLoadField;
  c: TDirectPathColumn;
begin
  Assert(fOraSession.Connected, '{131ACFCE-C464-4477-A0A0-2770BFFC36CE}');
  Assert(fTableName > '', '{97C996FF-6C58-4E3B-A46F-81561AB4BD69}');

  for i := 0 to fOraDirectPath.Columns.Count - 1 do
  begin
    c := fOraDirectPath.Columns[i];
    t := TUpLoadField.Create;

    t.Name := c.Name;
    t.fColumnType := c.DataType;
    t.Used := true;
    t.UserColumnNum := -1;
    fUploadFields.Add(t);
  end;
end;

procedure TOracleUpLoadData.ODPPrepare;
begin
  fOraDirectPath.BufferSize := fBufferSize;
  fOraDirectPath.Prepare;
end;

procedure TOracleUpLoadData.SetBufferSize(aValue: Cardinal);
begin
  fBufferSize := aValue;
  ODPPrepare;
end;

function TOracleUpLoadData.SetArrIdColumns: Boolean;
var
  i, c: Integer;
begin
  Result := True;
  fArrIdColumns := nil;
  c := 0;
  for i := 0 to fUploadFields.Count - 1 do
  begin
    if (Fields[i].Used) then
    begin
      SetLength(fArrIdColumns, c + 1);
      SetLength(fArrIdColumns[c], 2);
      fArrIdColumns[c, 0] := Fields[i].Id;
      fArrIdColumns[c, 1] := Fields[i].UserColumnNum;
      if ((UsedColumnNum) and (fArrIdColumns[c, 1] < 0)) then
        Result := False;
      Inc(c);
    end;
  end;
end;

function TOracleUpLoadData.GetUpLoadFields(index: Integer): TUpLoadField;
begin
  Result := TUpLoadField(fUploadFields[index]);
end;

function TOracleUpLoadData.FieldsCount: Integer;
begin
  Result := fUploadFields.Count;
end;

function TOracleUpLoadData.FieldsUsedCount: Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to fUploadFields.Count - 1 do
    if Fields[i].Used then
      Inc(Result);
end;

function TOracleUpLoadData.UpLoad(aArData: TData): Boolean;
var
  i, c, vRows: Integer;

  procedure NotUseColumn;
  var
    j, k: Integer;
  begin
    for j := 0 to High(aArData[i]) do
    begin
     k := fArrIdColumns[j, 0];
     if (aArData[i, j] > '') then
      fOraDirectPath.Columns[k].SetData(vRows, @aArData[i, j][1], Length(aArData[i, j]));
    end;
  end;

  procedure UseColumn;
  var
    j, k, n: Integer;
  begin
    for j := 0 to High(fArrIdColumns) do
    begin
      k := fArrIdColumns[j, 0];
      n := fArrIdColumns[j, 1];
      //OutputDebugString(PChar(Format('UseColumn:%d, %d, %d, %s', [vRows, j, Length(aArData[i, n]), aArData[i, n]])));
      if (aArData[i, n] > '') then
        fOraDirectPath.Columns[k].SetData(
          vRows
        ,       @aArData[i, n][1]
        , Length(aArData[i, n]){*SizeOf(Char)}
        );
    end;
  end;

begin
  Result := False;
  if (High(aArData) < 0) then
    Exit;

  if (not SetArrIdColumns) then
    Exit;

  c := High(aArData[0]) + 1;
  if (c <> FieldsUsedCount) then
    Exit;

  vRows := 0;
  for i := 0 to High(aArData) do
  begin
    if (fOraDirectPath.MaxRows = vRows) then
    begin
      fOraDirectPath.Load(vRows);
      vRows := 0;
    end;
    if (UsedColumnNum) then
      UseColumn
    else
      NotUseColumn;
    Inc(vRows);
  end;
  fOraDirectPath.Load(vRows);

  fOraDirectPath.Finish;
  Result := True;
end;

function TOracleUpLoadData.UpLoad(aDS: TDataSet): Boolean;
var
  r, i, c: Integer;
  d: TData;
begin
  Assert(aDS.Active, '{CF062155-3411-455E-9A38-C59ED4B8B556}');

  r := 0;
  c := aDS.FieldCount;

  aDS.First;
  while (not aDS.Eof) do
  begin
    SetLength(d, r + 1);
    for i := 0 to c - 1 do
    begin
      SetLength(d[r], c);
      d[r, i] := aDS.Fields[i].AsString;
    end;
    Inc(r);
    aDS.Next;
  end;
  Result := UpLoad(d);
  d := nil;
end;

constructor TOracleUpLoadData.Create(aOraSession: TOracleSession; aTableName: string);
begin
  fOraSession := TOracleSession.Create(nil);
  aOraSession.Share(fOraSession);
  fTableName := aTableName;
end;

constructor TOracleUpLoadData.Create(aDataBase, aUserName, aPassword, aTableName: string);
begin
  fOraSession := TOracleSession.Create(nil);

  fOraSession.LogonDatabase := aDataBase;
  fOraSession.LogonUsername := aUserName;
  fOraSession.LogonPassword := aPassword;

  fTableName := aTableName;
end;

procedure TOracleUpLoadData.AfterConstruction;
begin
  inherited;

  fOraSession.Connected := True;
  fUsedColumnNum := False;

  fBufferSize := 512 * 1024;

  fUploadFields := TObjectList.Create;

  fOraDirectPath := TOracleDirectPathLoader.Create(nil);

  fOraDirectPath.Session   := fOraSession;
  fOraDirectPath.TableName := fTableName;
  fOraDirectPath.GetDefaultColumns(True);
  ODPPrepare;

  SetFields;
  SetId;
end;

procedure TOracleUpLoadData.BeforeDestruction;
begin
  FreeAndNil(fUploadFields);
  FreeAndNil(fOraDirectPath);

  Inherited;
end;

end.
