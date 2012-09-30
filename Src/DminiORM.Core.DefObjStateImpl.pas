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

unit DminiORM.Core.DefObjStateImpl;

interface

Uses DminiORM.Core, Rtti, DminiORM.Core.Factory;

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
  LColumn: TColumnClassRelation;
  LDetails: TArray<TRelationDescription>;
  LDetail: TRelationDescription;
  LDetailRec: PRelationRec;
  LDetailObject: TObject;
  LKeyIndex, LIndex: integer;

begin
  if AMap.GetFieldValues <> nil then
    Exit(AMap.GetFieldValues.Invoke(AObject, []).AsType<TORMObjectStatus>);

  LColumns := AMap.GetColumnsMapInfo;
  LDetails := AMap.GetDetailsInfo;

  LObjStatus.State := osUnknow;
  LObjStatus.EnitityName := AMap.GetEntityName;
  SetLength(LObjStatus.Fields, Length(LColumns) + Length(LDetails));
  LKeyIndex := 0;
  LIndex := 0;

  for LColumn in LColumns do
  begin
    LObjStatus.Fields[LIndex].ProperyName := LColumn.ClassMember.Name;
    LObjStatus.Fields[LIndex].ColumnName := LColumn.ColumnName;
    LObjStatus.Fields[LIndex].IsDetailField := FALSE;

    if (LKeyIndex < Length(AMap.GetKeyInfo)) and
      (AMap.GetKeyInfo[LKeyIndex].ClassMember.Name = LColumn
      .ClassMember.Name) then
    begin
      inc(LKeyIndex);
      LObjStatus.Fields[LIndex].IsKeyField := TRUE;
    end
    else
      LObjStatus.Fields[LIndex].IsKeyField := FALSE;

    if LColumn.ClassMember is TRttiField then
      LObjStatus.Fields[LIndex].NewValue := TRttiField(LColumn.ClassMember)
        .GetValue(AObject)
    else
      LObjStatus.Fields[LIndex].NewValue := TRttiProperty(LColumn.ClassMember)
        .GetValue(AObject);

    LObjStatus.Fields[LIndex].OldValue := LObjStatus.Fields[LIndex].NewValue;
    inc(LIndex);
  end;

  for LDetail in LDetails do
  begin
    LDetailRec := PRelationRec(LDetail.MasterProperty.GetValue(AObject).GetReferenceToRawData);
    LObjStatus.Fields[LIndex].ProperyName := LDetail.MasterProperty.Name;
    LObjStatus.Fields[LIndex].IsDetailField := TRUE;
    LObjStatus.Fields[Lindex].IsKeyField := FALSE;
//    LObjStatus.Fields[LIndex].NewValue := TValue.From<TORMObjectStatus>(
//      GetFieldValues(LDetailRec.Delegate.AsObject,
//        LDetailRec.Orm.));
  end;

  result := LObjStatus;
end;

initialization

Factory.Register(IObjectState, TObjectState);

end.
