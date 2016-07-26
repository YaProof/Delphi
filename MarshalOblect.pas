unit MarshalOblect;

interface

uses
  SysUtils, DBXJSON, DBXJSONReflect;

function DeepCopy(aValue: TObject): TObject;
function ObjectTOJson(aObject: TObject): String; //TJSONValue;
function JsonTOObject(aJson: TJSONValue): TObject;

implementation

function DeepCopy(aValue: TObject): TObject;
var
  MarshalObj: TJSONMarshal;
  UnMarshalObj: TJSONUnMarshal;
  JSONValue: TJSONValue;
begin
  Result:= nil;
  MarshalObj := TJSONMarshal.Create;
  UnMarshalObj := TJSONUnMarshal.Create;
  try
    JSONValue := MarshalObj.Marshal(aValue);
    try
      if Assigned(JSONValue) then
        Result:= UnMarshalObj.Unmarshal(JSONValue);
    finally
      JSONValue.Free;
    end;
  finally
    MarshalObj.Free;
    UnMarshalObj.Free;
  end;
end;

function ObjectTOJson(aObject: TObject): String; //TJSONValue;
var
  MarshalObj: TJSONMarshal;
begin
  Assert(Assigned(aObject), '{9682C06D-717C-4E75-9F81-38D2B64DCB96}');

  MarshalObj := TJSONMarshal.Create;
  try
    Result := MarshalObj.Marshal(aObject).ToString;
  finally
    FreeAndNil(MarshalObj);
  end;
end;

function JsonTOObject(aJson: TJSONValue): TObject;
var
  UnMarshalObj: TJSONUnMarshal;
begin
  Assert(Assigned(aJson), '{A3A45FE9-7E30-4662-A279-00A917FD099F}');

  UnMarshalObj := TJSONUnMarshal.Create;
  try
    Result:= UnMarshalObj.Unmarshal(aJson);
  finally
    FreeAndNil(UnMarshalObj);
  end;
end;

end.
