{   Copyright 2012 - Juan Luis Rozano (jlrozano@gmail.com)

    This file is part of DminiORM

    DminiORM is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as
    published by the Free Software Foundation, either version 3 of
    the License, or (at your option) any later version.

    DminiOrm is distributed WITHOUT ANY WARRANTY; without even the
    implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
    See the GNU Lesser General Public License for more details.
    <http://www.gnu.org/licenses/>.

}
unit DminiORM.VCLDataSetAdapter;

interface

Uses Data.DB, DminiORM.Core, System.Rtti, Variants, Dialogs, DBClient, SysUtils;

Type


  TDataSetAdapter = class(TInterfacedObject, IDataReader, IDataWriter)
  private
    FDataSet: TDataSet;
    FOwned: Boolean;
    FRecNo: integer;
    function LocateRec(KeyInfo: TORMFields): boolean;
    function SaveRec(ARec: TORMObjectStatus): TDataRow;
    procedure DeleteRec(ARec: TORMObjectStatus);
  public
    constructor Create(ADataSet: TDataSet; OwnedDataSet: Boolean = false);
    destructor Destroy; override;
    function GetEOF: Boolean;
    procedure Next;
    function GetDataRow: TDataRow;
    function GetRecNo: integer;
    function GetRowColumn(ColumnName: String; out Value: TValue): Boolean;
    function Save(Records: TArray<TORMObjectStatus>): TArray<TDataRow>;
    procedure Delete(RecKeys: TArray<TDataRow>);
    property EOF: Boolean read GetEOF;
    property RecNo: integer read GetRecNo;
    property DataRow: TDataRow read GetDataRow;
    property DataSet: TDataSet read FDataSet;
  end;


implementation

{ TDataSetAdapter }

constructor TDataSetAdapter.Create(ADataSet: TDataSet; OwnedDataSet: Boolean);
begin
  FDataSet := ADataSet;
  FOwned := OwnedDataSet;
  if not FDataSet.Active then FDataSet.Open;
  if FDataSet.EOF then
    FRecNo := 0
  else
    FRecNo := 1
end;

procedure TDataSetAdapter.Delete(RecKeys: TArray<TDataRow>);
begin
  FDataSet.Delete;
end;

procedure TDataSetAdapter.DeleteRec(ARec: TORMObjectStatus);
var
  LORMField: TORMField;
  LFilterText : String;
  LKeyValues: Variant;
  i:integer;
  LKeys: TORMFields;

begin
  LFilterText:='';
  i := 0;
  LKeys:= ARec.KeyFields;
  LKeyValues:= VarArrayCreate([0, Length(LKeys) - 1],varVariant);

  for LORMField in LKeys do
  begin
    LFilterText := LFilterText + LORMField.ColumnName +';';
    LKeyValues[i] := LORMField.OldValue.AsVariant;
  end;

  if Length(LKeys) = 1 then
    LKeyValues := LKeyValues[0];

  if FDataSet.Locate(Copy(LFilterText,1, Length(LFilterText)-1),LKeyvalues,[loCaseInsensitive]) then
    FDataSet.Delete;

end;

destructor TDataSetAdapter.destroy;
begin
  if FDataSet.State<>dsBrowse then
    FDataSet.Cancel;
  if FOwned then
    FDataSet.Free;
end;

function TDataSetAdapter.GetDataRow: TDataRow;
var
  Fld: TField;
begin
  SetLength(Result, FDataSet.FieldCount);
  for Fld in FDataSet.Fields do
    Result[Fld.Index].Create(Fld.FieldName, TValue.FromVariant(Fld.Value));
end;

function TDataSetAdapter.GetEOF: Boolean;
begin
  Result := FDataSet.EOF;
end;

function TDataSetAdapter.GetRecNo: integer;
begin
  Result := FRecNo;
end;

function TDataSetAdapter.GetRowColumn(ColumnName: String;
  out Value: TValue): Boolean;
Var
  LFld: TField;
  LCDS : TClientDataSet;
begin
  Result := false;
  LFld := FDataSet.FindField(ColumnName);
  if (LFld <> nil) then
    if LFld is TDataSetField then
    begin
      LCDS := TClientDataSet.Create(NIL);
      LCDS.DataSetField := TDataSetField(LFld);
      LCDS.Open;
      Value := TValue.From<IDataReader>(TDataSetAdapter.Create(LCDS, TRUE));
      Result := TRUE;
    end
    else
    begin
      Value := TValue.FromVariant(LFld.Value);
      Result := TRUE;
    end;
end;

function TDataSetAdapter.LocateRec(KeyInfo: TORMFields): boolean;
var
  LORMField: TORMField;
  LFilterText : String;
  LKeyValues: Variant;
  i:integer;

begin
  if Length(KeyInfo) = 1 then
  begin
    LFilterText := KeyInfo[0].ColumnName;
    if KeyInfo[0].HasOldValueInfo then
      LKeyValues := KeyInfo[0].OldValue.AsVariant
    else
      LKeyValues := KeyInfo[0].NewValue.AsVariant
  end
  else
  begin

    LFilterText:='';
    i := 0;
    LKeyValues:= VarArrayCreate([0, Length(KeyInfo) - 1],varVariant);

    for LORMField in KeyInfo do
    begin
      LFilterText := LFilterText + LORMField.ColumnName +';';
      if LORMField.HasOldValueInfo then
        LKeyValues[i] := LORMField.OldValue.AsVariant
      else
        LKeyValues[i] := LORMField.NewValue.AsVariant
    end;

    LFilterText:= Copy(LFilterText, Length(LFilterText), 1);

  end;

  result := FDataSet.Locate(LFilterText,LKeyvalues,[loCaseInsensitive]);

end;

procedure TDataSetAdapter.Next;
begin
  FDataSet.Next;
  if Not FDataSet.EOF then inc(FRecNo);
end;

function TDataSetAdapter.Save(Records: TArray<TORMObjectStatus>): TArray<TDataRow>;
var
  i : integer;
begin
  SetLength(Result, Length(Records));
  for i:= 0 to Length(Records) -1 do
    Result[i] := SaveRec(Records[i]);
end;

function TDataSetAdapter.SaveRec(ARec: TORMObjectStatus): TDataRow;
var
  LFound: Boolean;
  LOrmField: TORMField;
  LField: TField;
  i: integer;

begin
  if ARec.State = osNew then
    FDataSet.Append
  else
  begin
    LFound := LocateRec(ARec.KeyFields);
    if LFound then
      FDataSet.Edit
    else
      if ARec.State = osUnknow then
        FDataSet.Append
      else
        raise Exception.Create('Can''t modify a record. Not found.');
  end;
  try
    for LORMField in ARec.Fields do
      if LORMField.Modified then
      begin
        LField:= FDataSet.FindField(LORMField.ColumnName);
        if (LField<>nil) and not LField.ReadOnly then
          if LORMField.NewValue.TypeInfo = TypeInfo(Boolean) then
             LField.AsBoolean := LORMField.NewValue.AsType<Boolean>
           else LField.AsVariant := LORMField.NewValue.AsVariant;
      end;

    FDataSet.Post;

    SetLength(Result, FDataSet.FieldCount);
    i := 0;

//    for LORMField in ARec.Fields do
//    begin
//      LField:= FDataSet.FindField(LORMField.ColumnName);
//      if (LField<>nil) and not VarSameValue(LORMField.NewValue.AsVariant, LField.AsVariant) then
//      begin
//        Result[i].Create( LField.FieldName, TValue.FromVariant(LField.AsVariant));
//        inc(i);
//      end;
//    end;

    SetLength(Result, i);
  except
    FDataSet.Cancel;
    raise;
  end;
end;


end.
