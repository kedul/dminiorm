unit DminiORM.Core.DefObjStateImpl;

interface

Uses DminiORM.Core, Rtti;

implementation

type

  TObjectState = Class(TInterfacedObject, IObjectState)
  public
    function GetFieldValues(AObject: TObject; AMap: IMapDefinition): TORMObjectStatus;
  End;

  { TObjectState }

function TObjectState.GetFieldValues(AObject: TObject; AMap: IMapDefinition)
  : TORMObjectStatus;
var
  LObjStatus: TORMObjectStatus;
  LColumns: TArray<TColumnClassRelation>;
  LKeyIndex, i: integer;
begin
  if AMap.GetFieldValues <> nil then
    Exit(AMap.GetFieldValues.Invoke(AObject, []).AsType<TORMObjectStatus>);

  LColumns := AMap.GetColumnsMapInfo;

  LObjStatus.State := osUnknow;
  SetLength(LObjStatus.Fields, Length(LColumns));
  LKeyIndex := 0;

  for i := 0 to Length(LColumns) - 1 do
  begin
    LObjStatus.Fields[i].ProperyName := LColumns[i].ClassMember.Name;
    LObjStatus.Fields[i].ColumnName := LColumns[i].ColumnName;

    if (LKeyIndex < Length(AMap.GetKeyInfo)) and
      (AMap.GetKeyInfo[LKeyIndex].ClassMember.Name = LColumns[i]
      .ClassMember.Name) then
    begin
      inc(LKeyIndex);
      LObjStatus.Fields[i].IsKeyField := TRUE;
    end
    else
      LObjStatus.Fields[i].IsKeyField := FALSE;

    if LColumns[i].ClassMember is TRttiField then
      LObjStatus.Fields[i].NewValue := TRttiField(LColumns[i].ClassMember)
        .GetValue(AObject)
    else
      LObjStatus.Fields[i].NewValue := TRttiProperty(LColumns[i].ClassMember)
        .GetValue(AObject);

    LObjStatus.Fields[i].OldValue := LObjStatus.Fields[i].NewValue;
  end;

  result := LObjStatus;
end;

initialization

Factory.Register(IObjectState, TObjectState);

end.
