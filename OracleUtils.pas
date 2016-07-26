unit OracleUtils;

interface

uses
{$ifdef debug}
  Windows,
{$endif}
  SysUtils, Classes, OracleData, Oracle, ComCtrls, DB
  ;

// Заполняем список из OracleQuery
procedure FillListFromQuery(aList: TStrings; aQuery: TOracleQuery;
                              const aIdField: string = 'ID'; const aCaptionField: string = 'NAME');

procedure FillListFromDataSet(aList: TStrings; aDS: TOracleDataSet;
                              const aIdField: string = 'ID'; const aCaptionField: string = 'NAME');
//Получение ID из списка
function GetIdFromList(const aList: TStrings; const aPosition: Integer): Integer;

//Заполнение ListView из OracleDataSet
procedure FillListViewFromOraDataSet(aListView: TListView;
                                     aOraDataSet: TOracleDataSet);

//Обновить OracleDataSet
procedure UpdateOraDataSet(aOraDS: TOracleDataSet);

//Обновить OracleDataSet сохранив указатель на строку
function UpdateOraDataSetSaveMark(aOraDS: TOracleDataSet): Boolean;

implementation

procedure FillListFromQuery(aList: TStrings; aQuery: TOracleQuery;
                              const aIdField: string = 'ID'; const aCaptionField: string = 'NAME');
var
  vIdField, vCaptionField: Integer;
begin
  Assert(Assigned(aList),          '{FEFDEDDA-E9B9-4093-BB2E-E91F7ADB660F}');
  Assert(Assigned(aQuery),         '{2B5305A3-F914-45E6-A14B-F4B68EB46902}');
  Assert(Assigned(aQuery.Session), '{FCE87B95-BC03-48C5-97A0-394753390716}');
  Assert(aQuery.Session.Connected, '{F74063D7-324E-4467-8E64-C88E1AD81BE7}');

  aQuery.Execute;

  vIdField      := aQuery.FieldIndex(aIdField);
  vCaptionField := aQuery.FieldIndex(aCaptionField);
  Assert(vIdField      >= 0, '{E7FA8B79-951E-440C-9A8F-E231597CE310}');
  Assert(vCaptionField >= 0, '{38BBC5CA-FB87-461D-94DE-6AF7F6185593}');

  aList.Clear;

  aQuery.First;
  while not aQuery.Eof do
  begin
    aList.AddObject(aQuery.FieldAsString(vCaptionField),
                      tObject(aQuery.FieldAsInteger(vIdField)));
    aQuery.Next;
  end;
end;

procedure FillListFromDataSet(aList: TStrings; aDS: TOracleDataSet;
                              const aIdField: string = 'ID'; const aCaptionField: string = 'NAME');
var
  vIdField, vCaptionField: Integer;
begin
  Assert(Assigned(aList),       '{789ABCD9-476D-4FF4-B1E4-B5AAD847AD3E}');
  Assert(Assigned(aDS),         '{66F48CDB-4E30-458B-99F8-5BD14417FE27}');
  Assert(Assigned(aDS.Session), '{D7687D2F-9B9D-48F4-907B-3A698E48511F}');
  Assert(aDS.Session.Connected, '{316EB358-1118-45C6-ACBA-F3F4B131D610}');

  aDS.Close;
  aDS.Open;

  aDS.First;
  while (not aDS.Eof) do
  begin
    aList.AddObject(aDS.FieldByName(aCaptionField).AsString,
                      tObject(aDS.FieldByName(aIdField).AsInteger));
    aDS.Next;
  end;

end;

function GetIdFromList(const aList: TStrings; const aPosition: Integer): Integer;
begin
  Assert(Assigned(aList),  '{6F33ED90-1CE1-48B7-AEDA-E44BA1FE26A5}');
  Assert(aPosition >= 0,   '{0F2E0211-9636-4B9C-BBD9-99188A9B39DE}');

  Result := Integer(aList.Objects[aPosition]);
end;

procedure FillListViewFromOraDataSet(aListView: TListView;
                                     aOraDataSet: TOracleDataSet);
var
  vItem: TListItem;
  i: Integer;
begin
  Assert(Assigned(aListView),   '{8A257790-D8C3-4135-8F4C-33AF0C1173EC}');
  Assert(Assigned(aOraDataSet), '{6D762514-055F-43B2-AEC5-741555257F85}');
  Assert(aOraDataSet.Active,    '{EB5A1185-5600-4F43-A7BE-D970BCBD6F03}');

  aListView.Clear;
  aListView.Columns.Clear;

  aListView.Items.BeginUpdate;
  try
    //Заполнить имена столбцов
    for i := 0 to aOraDataSet.FieldCount - 1 do
    begin
      with aListView.Columns.Add do
      begin
        Caption := aOraDataSet.Fields[i].DisplayLabel;
        Width   := aOraDataSet.Fields[i].DisplayWidth;
      end;
    end;

    //Заполняем данными
    aOraDataSet.First;
    while not aOraDataSet.Eof do
    begin
      vItem := aListView.Items.Add;
{$ifdef debug}
      OutputDebugString(PChar(IntToStr(vItem.Index)));
      OutputDebugString(PChar(aOraDataSet.Fields[0].AsString));
{$endif}
      vItem.Caption := aOraDataSet.Fields[0].AsString;

      for i := 1 to aOraDataSet.FieldCount - 1 do
        vItem.SubItems.Add(aOraDataSet.Fields[i].AsString);

      aOraDataSet.Next;
    end;

  finally
    aListView.Items.EndUpdate;
  end;
end;

procedure UpdateOraDataSet(aOraDS: TOracleDataSet);
begin
  aOraDS.Close;
  aOraDS.Open;
end;

function UpdateOraDataSetSaveMark(aOraDS: TOracleDataSet): Boolean;
var
  vBM: TBookmark;
begin
  try
    vBM := aOraDS.GetBookmark;
    UpdateOraDataSet(aOraDS);
    if (aOraDS.RecordCount > 0) then
      aOraDS.GotoBookmark(vBM);
    Result := True;
  Except
    Result := False;
  end;
end;

end.
