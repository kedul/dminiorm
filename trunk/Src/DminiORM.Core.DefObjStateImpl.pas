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

Uses DminiORM.Core, Rtti, DminiORM.Core.Factory, Emballo.SynteticClass,
  TypInfo, SysUtils, DMiniORM.Core.RttiHelpers;

implementation


type

  TObjectState = Class(TInterfacedObject, IObjectState)
  public
    function GetFieldValues(AObject: TObject): TORMObjectStatus;
    function GetOwner(AObject: TObject): TObject;
  End;

  { TObjectState }

function TObjectState.GetFieldValues(AObject: TObject): TORMObjectStatus;
var
  LObjStatus: TORMObjectStatus;
  LColumns: TArray<TClassMemberMap>;
  LColumn: TClassMemberMap;
  LDetails: TArray<TRelationDescription>;
  LDetail: TRelationDescription;
  LDetailObject: TObject;
  LKeyIndex, LIndex: integer;
  LIsOrmClass: Boolean;
  LStatusRec: PStateRec;
  LMap: IMapDefinition;
  LMapManager: IMapManager;
  LEntityName: String;

  function GetOldValue(ColumnName: String; out Value: TValue): boolean;
  begin
    result := LStatusRec.Data.TryGet(ColumnName, Value);
  end;

  procedure SetMasterValues(AStatusRec: PStateRec; LMap: IMapDefinition);
  var
    LMasterDesc: TMasterDescription;
    LMasterDetailMember: TMasterDetailMembers;
  begin
    if Assigned(AStatusRec.Owner) then
    begin
      for LMasterDesc  in LMap.GetMastersInfo do
        if (LMasterDesc.MasterClassType.Handle = AStatusRec.Owner.ClassInfo) OR
            (LMasterDesc.MasterClassType.Handle = AStatusRec.Owner.ClassParent.ClassInfo) then
        begin
          for LMasterDetailMember in LMasterDesc.MasterDetailRelationShip do
          begin
            LMasterDetailMember.DetailField.SetValue(AObject,
              LMasterDetailMember.MasterField.GetValue(AStatusRec.Owner));
          end;
          break;
        end;
    end;
  end;

begin
  LMapManager := Factory.Get<IMapManager>;
  if (LMapManager=nil) then
    raise Exception.Create('Can''t find a IMapManager implementation.');

  LMap := LMapManager.Get(PTypeInfo(AObject.ClassInfo));
  if (LMap=nil) then
    raise Exception.Create('Can''t find a IMap implementation for '+
        PTypeInfo(AObject.ClassInfo).Name);

  if LMap.GetFieldValues <> nil then
    Exit(LMap.GetFieldValues.Invoke(AObject, []).AsType<TORMObjectStatus>);

  LColumns := LMap.GetColumnsMapInfo;
  LDetails := LMap.GetDetailsInfo;
  LIsOrmClass := Copy(AObject.ClassName, Length(AObject.ClassName)-3, 4) ='_ORM';


  if LIsOrmClass then begin
    LStatusRec := GetAditionalData(AObject);
    SetMasterValues(LStatusRec,LMap);
    LObjStatus.State := LStatusRec.State;

  end
  else
    LObjStatus.State := osUnknow;

  // LObjStatus.EnitityName := LMap.GetEntityName;
  SetLength(LObjStatus.Fields, Length(LColumns));// + Length(LDetails));
  LKeyIndex := 0;
  LIndex := 0;

  for LColumn in LColumns do
  begin
    LObjStatus.Fields[LIndex].ObjMember := LColumn.ClassMember;
    LObjStatus.Fields[LIndex].ColumnName := LColumn.Column;

    if (LKeyIndex < Length(LMap.GetKeyInfo)) and
      (LMap.GetKeyInfo[LKeyIndex].ClassMember.Name = LColumn
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

    if LIsOrmClass then
    begin
      if not GetOldValue(LColumn.Column, LObjStatus.Fields[LIndex].OldValue) then
        LObjStatus.Fields[LIndex].OldValue := LObjStatus.Fields[LIndex].NewValue
      else
        LObjStatus.Fields[LIndex].HasOldValueInfo := TRUE;
    end
    else
      LObjStatus.Fields[LIndex].OldValue := LObjStatus.Fields[LIndex].NewValue;
    inc(LIndex);
  end;

  if  (LObjStatus.State<>osNew) AND LIsORMClass and LObjStatus.IsModified then
  begin
    LObjStatus.State := osModified;
    LStatusRec.State := osModified;
  end;

  result := LObjStatus;
end;

function TObjectState.GetOwner(AObject: TObject): TObject;
begin
  if Copy(AObject.ClassName, Length(AObject.ClassName)-3, 4) ='_ORM' then
    result := PStateRec(GetAditionalData(AObject)).Owner
  else
    result := nil;
end;

initialization
  Factory.Register(IObjectState, TObjectState.Create);
end.
