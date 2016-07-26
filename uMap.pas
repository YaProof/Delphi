unit uMap;

interface

uses
  Classes, SHDocVw, DB, SysUtils, Registry;

const
  cId:    String = 'id';
  cName:  String = 'name';
  cCount: String = 'cnt';
  cLon:   String = 'lon';
  cLat:   String = 'lat';
  cPart:  String = 'part';
  cSide:  String = 'side';

type TGeo = class(TObject)
  private
    fLon: Double;
    fLat: Double;
  public
    property Lon: Double read fLon write fLon;
    property Lat: Double read fLat write fLat;
  public
    function getString: String;
end;

type TDataCoord = class(TObject)
  private
    fId: Integer;
    fName: String;
    fCount: Integer;
    fGeo: array of array of TGeo;
  public
    property Id: Integer read fId write fId;
    property Name: String read fName write fName;
    property Count: Integer read fCount write fCount;
  public
    procedure setGeo(const aSide: Integer; const aLat, aLon: Double);
    function getString: String;
end;

type TMap = class(TObject)
  private
    fSrcHtmlFile: String;
    fSrcName: String;
    fHtmlName: String;
    fDataSet: TDataSet;
    fBrowser: TWebBrowser;
    fDataCoord: array of TDataCoord;
    fVersion: Integer;
  private
    function isAllParam: Boolean;
    function setHtmlName(const aName: String): String;
    function coordJSobjectGet: String;
    function createHTML: Boolean;
    procedure setRegistry;
    procedure RemoveOldHTML;
  public
    property Actived: Boolean read isAllParam;
  public
    constructor Create(aHtmlName: String; aDataSet: TDataSet;
                         aBrowser: TWebBrowser; aVersion: Integer);
    destructor Destroy; override;
    function ShowData: Boolean;
    function GetCode: TStringList;
end;

implementation

uses CustomerService;

{ TMap }

function DeleteFiles(const FileMask: string): Boolean;
var
  SearchRec: TSearchRec;
begin
  Result := FindFirst(ExpandFileName(FileMask), faAnyFile, SearchRec) = 0;
  try
    if Result then
      repeat
        if (SearchRec.Name[1] <> '.') and
          (SearchRec.Attr and faVolumeID <> faVolumeID) and
            (SearchRec.Attr and faDirectory <> faDirectory) then
        begin
          Result := DeleteFile(ExtractFilePath(FileMask) + SearchRec.Name);
          if not Result then Break;
        end;
      until FindNext(SearchRec) <> 0;
  finally
    FindClose(SearchRec);
  end;
end;

constructor TMap.Create(aHtmlName: String; aDataSet: TDataSet;
  aBrowser: TWebBrowser; aVersion: Integer);
begin
  Assert(aHtmlName > '', '{F1BB4F1E-BB4B-47B3-9C49-D9D1CDE63CAD}');
  Assert(Assigned(aDataSet), '{01BF71C9-8B39-4854-B631-35315EFFB8AE}');
  Assert(Assigned(aBrowser), '{01BF71C9-8B39-4854-B631-35315EFFB8AE}');

  fSrcHtmlFile := '04DDBE6B-66C7-4CB1-988E-44847B0C4DCD.h';

  fVersion  := aVersion;
  fHtmlName := setHtmlName(aHtmlName);
  fDataSet  := aDataSet;
  fBrowser  := aBrowser;
  setRegistry;
  FormatSettings.DecimalSeparator := '.';
end;

function TMap.createHTML: Boolean;
var
  p, fn, s: String;
  sl: TStrings;
begin
  Result := False;

  p := ExtractFilePath(ParamStr(0));
  fn := p + fSrcHtmlFile;
  if (not FileExists(fn)) then
    Exit;

  sl := TStringList.Create;
  try
    sl.LoadFromFile(p + fSrcHtmlFile);
    sl.Text := StringReplace(sl.Text, '%%CoordData%%', coordJSobjectGet, [rfReplaceAll, rfIgnoreCase]);
    sl.SaveToFile(p + fHtmlName, TEncoding.UTF8);
  finally
    FreeAndNil(sl);
  end;

  Result := True;
end;

destructor TMap.Destroy;
var
  f: String;
begin
  {
  f := ExtractFilePath(ParamStr(0)) + fHtmlName;
  if (FileExists(f)) then
    DeleteFile(f);
  }
  inherited;
end;

function TMap.GetCode: TStringList;
var
  lst: TStringList;
  tbl, row: OleVariant;
  i, j, r, c: Integer;
  s: String;
begin
  lst := TStringList.Create;

  tbl := fBrowser.OleObject.Document.GetElementById('export_table');
  r := tbl.rows.length;
  //2 - что бы не брать строку итого
  for i := 0 to r - 2 do
  begin
    row := tbl.rows.item(i).getElementsByTagName('TH');
    if (row.length = 0) then
      row := tbl.rows.item(i).getElementsByTagName('TD');
    c := row.length;

    s := '';
    for j := 0 to c - 1 do
      s := s + '~' + row.Item(j).innerText;
    s := Copy(s, 2);
    lst.Add(s);
  end;

  Result := lst;
end;

function TMap.coordJSobjectGet: String;
var
  f_id, f_name, f_cnt, f_lon, f_lat, f_part, f_side: TField;
  id, part, side: Integer;
  cd: TDataCoord;
  i, k: Integer;
begin
  Result := '';

  f_id   := fDataSet.FindField(cId);
  f_name := fDataSet.FindField(cName);
  f_cnt  := fDataSet.FindField(cCount);
  f_lon  := fDataSet.FindField(cLon);
  f_lat  := fDataSet.FindField(cLat);
  f_part := fDataSet.FindField(cPart);
  f_side := fDataSet.FindField(cSide);

  id   := -1000000;
  part := -1000000;
  side := -1000000;

  if (fDataSet.Active = False) then
    fDataSet.Open;

  fDataSet.DisableControls;
  try
    fDataSet.First;
    while not fDataSet.Eof do
    begin
      if ((id <> f_id.AsInteger) or (part <> f_part.AsInteger)) then
      begin
        id   := f_id.AsInteger;
        part := f_part.AsInteger;

        cd := TDataCoord.Create;
        cd.Id := id;
        cd.Name := f_name.AsString;
        cd.Count := f_cnt.AsInteger;

        k := Length(fDataCoord);
        SetLength(fDataCoord, k + 1);
        fDataCoord[k] := cd;
      end;
      cd.setGeo(f_side.AsInteger, f_lat.AsFloat, f_lon.AsFloat);

      fDataSet.Next;
    end;
  finally
    fDataSet.EnableControls;
  end;

  Result := '';
  for i := Low(fDataCoord) to High(fDataCoord) do
    Result := Result + fDataCoord[i].getString + ',' + #13;

  Result := 'var coord = [' + Result + '];';
end;

function TMap.isAllParam: Boolean;
var
  f: String;

  function isAssigned(const aFieldName: String): Boolean;
  begin
    Result := Assigned(fDataSet.FieldByName(aFieldName));
  end;
begin
  Result := False;

  f := ExtractFilePath(ParamStr(0)) + fSrcHtmlFile;
  if (not FileExists(f)) then
    Exit;

  if (not fDataSet.Active) then
    fDataSet.Open;

  if (not isAssigned(cId)) then
    Exit;
  if (not isAssigned(cName)) then
    Exit;
  if (not isAssigned(cCount)) then
    Exit;
  if (not isAssigned(cLat)) then
    Exit;
  if (not isAssigned(cLon)) then
    Exit;
  if (not isAssigned(cPart)) then
    Exit;
  if (not isAssigned(cSide)) then
    Exit;

  Result := True;
end;

procedure TMap.RemoveOldHTML;
var
  m: String;
begin
  m := ExtractFilePath(Paramstr(0)) + fSrcName + '*.html';
  DeleteFiles(m);
end;

function TMap.setHtmlName(const aName: String): String;
const
  cExt: String = '.html';
var
  fn: String;
begin
  fSrcName := aName;
  fn := aName + '_' + IntToStr(fVersion);
  Result := ChangeFileExt(fn, cExt);
end;

procedure TMap.setRegistry;
var
  r: TRegistry;
  key: String;
  fn: String;
begin
  //HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Internet Explorer\MAIN\FeatureControl\FEATURE_BROWSER_EMULATION
  //HKEY_CURRENT_USER\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION

  //key := '\SOFTWARE\Microsoft\Internet Explorer\MAIN\FeatureControl\FEATURE_BROWSER_EMULATION\';
  key := '\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION\';
  fn := ExtractFileName(ParamStr(0));

  r := TRegistry.Create;
  try
    //r.RootKey := $80000002; //HKEY_LOCAL_MACHINE;
    r.RootKey := $80000001; //HKEY_CURRENT_USER;
    if (r.KeyExists(key + fn)) then
      Exit;

    r.OpenKey(key, true);
    r.WriteInteger(fn, 10001);
  finally
    FreeAndNil(r);
  end;
end;

function TMap.ShowData: Boolean;
var
  p: String;
begin
  Result := False;

  p := ExtractFilePath(ParamStr(0)) + fHtmlName;

  if (not FileExists(p)) then
  begin
    RemoveOldHTML;

    if (not Actived) then
      Exit;

    if (not createHTML) then
      Exit;
  end;

  fBrowser.Navigate(p);

  Result := True;
end;

{ TCoord }

function TGeo.getString: String;
begin
  Result := '[' + FloatToStr(fLat) + ',' + FloatToStr(fLon) + ']';
end;

{ TDataCoord }

function TDataCoord.getString: String;
var
  s, z: String;
  i, j: Integer;
begin
  Result := '';
  z := '';


  Result := 'id:' + IntToStr(fId) + ',';
  Result := Result + 'name:''' + fName + ''',';
  Result := Result + 'count:' + IntToStr(fCount) + ',';

  //—обираем координаты
  for i := Low(fGeo) to High(fGeo) do
  begin
    s := '';
    for j := Low(fGeo[i]) to High(fGeo[i]) do
    begin
      s := s + fGeo[i][j].getString + ',';
    end;
    z := z + '[' + s + '],';
  end;
  Result := Result + 'geo:[' + z + '],';

  Result := Result + 'state:0';

  Result := '{' + Result + '}';
end;

procedure TDataCoord.setGeo(const aSide: Integer; const aLat, aLon: Double);
var
  c, d: Integer;
  g: TGeo;
begin
  g := TGeo.Create;
  g.Lat := aLat;
  g.Lon := aLon;

  SetLength(fGeo, aSide);

  d := aSide - 1;
  c := Length(fGeo[d]);
  SetLength(fGeo[d], c + 1);

  fGeo[d][c] := g;
end;

end.
