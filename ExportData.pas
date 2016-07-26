unit ExportData;

interface

uses Oracle, OracleData, Classes, ComObj;

type TExport = class
  private
    fFullPath: string;
    fDataSet: TOracleDataSet;

    function CorrectData: Boolean;
  public
    constructor Create(aFullPath: String; aOraSataSet: TOracleDataSet); overload;

    property FullPath: string read fFullPath write fFullPath;
    property OraDataSet: TOracleDataSet read fDataSet write fDataSet;

    function ExportOraToCSV: Boolean;
    function ExportOraToXLS(aShowTitle: Boolean): Boolean;
    //function ExportOraToXLSX: Boolean;
end;

implementation

constructor TExport.Create(aFullPath: String; aOraSataSet: TOracleDataSet);
begin
  fFullPath := aFullPath;
  fDataSet := aOraSataSet;
end;

function TExport.CorrectData: Boolean;
begin
  //
end;

function TExport.ExportOraToCSV: Boolean;
var
  f: TextFile;
  i: Integer;
begin
  try
    AssignFile(f, fFullPath);
    //Rewrite(f);
    Reset(f);
    fDataSet.First;
    while not fDataSet.Eof do
    begin
      for i := 0 to fDataSet.FieldCount - 1 do
      begin
        Writeln(f, fDataSet.Fields.FieldByNumber(i).Value + ';');
      end;
      fDataSet.Next;
    end;
  finally
    CloseFile(f);
  end;

end;

function TExport.ExportOraToXLS(aShowTitle: Boolean): Boolean;
var
  x: Variant;
  i, j: Integer;
begin
  x := CreateOleObject('Excel.Application');
  x.Workbooks.Add;

  j := 1;
  if aShowTitle then
  begin
    for i := 0 to fDataSet.FieldCount - 1 do
      x.ActiveWorkBook.WorkSheets[1].Cells[j, i + 1] :=
              fDataSet.Fields.Fields[i].DisplayLabel;
    j := 2;
  end;

  while not fDataSet.Eof do
  begin
    for i := 0 to fDataSet.FieldCount - 1 do
    begin
      x.ActiveWorkBook.WorkSheets[1].Cells[j, i + 1] :=
            fDataSet.Fields.Fields[i].AsString;
    end;
    fDataSet.Next;
    inc(j);
  end;
  x.Visible := true;
end;

end.
