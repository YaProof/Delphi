unit uExport2Excel;

interface

uses
  Variants, SysUtils,
  ComObj, ActiveX, DB
  , Graphics
  ;

function ToExcel(aDataSet: array of TDataSet; aTitle: Boolean = True; aPic: String = ''): Boolean;
function ToExcelSheetName(aDataSet: array of TDataSet; aSheetName: array of string; aTitle: Boolean = True; aPic: String  = ''): Boolean;

implementation

procedure BitMapSize(const aPic: String; aPercent: Integer; var w, h: Double);
var
  b: TBitMap;
  d: Double;
begin
  w := 0;
  h := 0;
  b := TBitMap.Create;
  try
    b.LoadFromFile(aPic);
    d := aPercent / 100;
    w := b.Width * d;
    h := b.Height * d;
  finally
    FreeAndNil(b);
  end;
end;

procedure GetVArray(aDataSet: TDataSet; aTitle: Boolean; var vArr: Variant; var vCol, vRow: Integer);
const
  b: Integer = 1;
  d: Integer = 1;
var
  i, j: Integer;
begin
  assert(aDataSet.Active, '{E1596405-09FE-4273-83D3-5A5158299949}');

  aDataSet.DisableControls;
  aDataSet.First;
  aDataSet.Last;
  vRow := aDataSet.RecordCount;
  vCol := aDataSet.FieldCount;
  vArr := VarArrayCreate([b, vRow + 1, d, vCol], varVariant);

  j := 1;
  if (aTitle) then
  begin
    for i := 0 to vCol - 1 do
    begin
      vArr[b, i + 1] := aDataSet.Fields.Fields[i].FieldName;
    end;
    j := 2;
  end;

  aDataSet.First;
  while not aDataSet.Eof do
  begin
    for i := 0 to vCol - 1 do
    begin
      vArr[j, i + 1] := aDataSet.Fields.Fields[i].AsVariant;
    end;
    inc(j);
    aDataSet.Next;
  end;
  aDataSet.EnableControls;
end;

function ToExcelSheetName(aDataSet: array of TDataSet;
                          aSheetName: array of string;
                          aTitle: Boolean = True;
                          aPic: String = ''
                         ): Boolean;
const
  b: Integer = 1;
  d: Integer = 1;
var
  ExcelApp, Workbook, Range, Cell1, Cell2, Arr: Variant;
  c, i, r: Integer;
  sn: Boolean;
  w, h: Double;
begin
  assert(High(aDataSet) >= 0, '{C58FAF8F-EE40-49A0-88D8-C52EB79EFCC4}');

  Result := False;

  sn := False;
  if (High(aDataSet) = High(aSheetName)) then
    sn := True;

  ExcelApp := CreateOleObject('Excel.Application');
  try
    ExcelApp.Application.EnableEvents := false;
    Workbook := ExcelApp.WorkBooks.Add;

    while (WorkBook.WorkSheets.Count < Length(aDataSet)) do
      WorkBook.WorkSheets.add;

    for i := Low(aDataSet) to High(aDataSet) do
    begin
      if (sn) then
        WorkBook.WorkSheets[i + 1].Name := Copy(aSheetName[i], 1, 30);

      GetVArray(aDataSet[i], aTitle, Arr, c, r);
      Cell1 := WorkBook.WorkSheets[i + 1].Cells[b, d];
      Cell2 := WorkBook.WorkSheets[i + 1].Cells[r + 1, c];
      Range := WorkBook.WorkSheets[i + 1].Range[Cell1, Cell2];
      Range.Value := Arr;
    end;

    if (FileExists(aPic)) then
    begin
      BitMapSize(aPic, 50, w, h);
      WorkBook.WorkSheets[1].Shapes.AddPicture(aPic, 1, 1, 40, 100, w, h);
    end;

    ExcelApp.Visible := true;
    Result := True;
  except
    FreeAndNil(ExcelApp);
  end;
end;

function ToExcel(aDataSet: array of TDataSet; aTitle: Boolean = True; aPic: String = ''): Boolean;
var
  s: array of string;
begin
  ToExcelSheetName(aDataSet, s, aTitle, aPic);
end;

end.
