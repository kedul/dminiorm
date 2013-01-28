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
unit DminiORM.Core.DefMapImpl;

interface

uses DminiORM.Core, Rtti, Generics.Collections, TypInfo, SysUtils,
  DminiORM.Core.Factory, DminiORM.Core.RttiHelpers, DminiORM.Core.SimpleCollIntf;

type

  Column = class(TCustomAttribute)
  private
    FName: String;
    FProvider: String;
  public
    constructor Create(const AName: String); overload;
    constructor Create(const AProvider: String; AName: String); overload;
    property Name: String read FName;
    property Provider: String read FProvider;
  end;

  PrimaryKey = class(TCustomAttribute);

  ForeignKey = class(TCustomAttribute)
  private
    FMasterClassTypeInfo: PTypeInfo;
    FMasterProperty: String;
  public
    constructor Create(AMasterClass: PTypeInfo); overload;
    constructor Create(AMsterClass: TClass); overload;
    constructor Create(AMsterIntf: TGUID); overload;
    constructor Create(AMasterClass: Pointer; AMasterProperty: String); overload;
    property MasterClassTypeInfo: PTypeInfo read FMasterClassTypeInfo;
    property MasterProperty: String read FMasterProperty;
  end;

  Table = class(TCustomAttribute)
  private
    FName: String;
  public
    constructor Create(const AName: String);
    property Name: String read FName;
  end;

  Relation = class(TCustomAttribute)
  private
    FLoadMode: TRelationLoadMode;
    FRelationType: TRelationType;
    FProvider: String;
    FColumn: String;
  public
    constructor Create(ALoadMode: TRelationLoadMode; ARelationType: TRelationType = rtChild); overload;
    constructor Create(AProvider: String; ALoadMode: TRelationLoadMode; ARelationType: TRelationType =rtChild); overload;
    constructor Create(AReaderColumnName: String; ARelationType: TRelationType = rtChild); overload;
    constructor Create(AProvider, AReaderColumnName: String; ARelationType: TRelationType = rtChild); overload;
    property LoadMode: TRelationLoadMode read FLoadMode;
    property RelationType: TRelationType read FRelationType;
    property Provider: String read FProvider;
    property Column: String read FColumn;
  end;

  CustomMap = class(TCustomAttribute);

  MapInitialize = class(TCustomAttribute);

  MapFinalize = class(TCustomAttribute);

  MapField = class(TCustomAttribute);

  BeforeSave = class(TCustomAttribute);

  AfterSave = class(TCustomAttribute);

  BeforeDelete = class(TCustomAttribute);

  AfterDelete = class(TCustomAttribute);

  ObjectState = class(TCustomAttribute);

  State = class (TCustomAttribute)
  private
    FStateMode: TStateMode;
  public
    constructor Create(AMode: TStateMode);
    property Mode: TStateMode read FStateMode;
  end;


implementation

type

  TDefMapImpl = class;

  TDefMapDefinitionImpl = class(TInterfacedObject, IMapDefinition)
  private
    FEntityName: String;
    FColumnsMapInfo: TArray<TClassMemberMap>;
    FMasters: TArray<TMasterDescription>;
    FDetails: TArray<TRelationDescription>;
    FKeyInfo: TArray<TClassMemberMap>;
    FCustomMapMethod: TRttiMethod;
    FOnMapInitialize: TRttiMethod;
    FOnMapFinalize: TRttiMethod;
    FOnMapField: TRttiMethod;
    FBeforeSave: TRttiMethod;
    FAfterSave: TRttiMethod;
    FBeforeDelete: TRttiMethod;
    FAfterDelete: TRttiMethod;
    FGetFields: TRttiMethod;
    FProvider: String;
    FState: TStateMode;
    class procedure ParseProvider(AType: TRttiType; Provider: String;
      ADictionary: TDictionary<String, IMapDefinition>); static;
  public
    constructor Create;
    destructor Destroy; override;
    function GetEntityName: String;
    function GetColumnsMapInfo: TArray<TClassMemberMap>;
    function GetDetailsInfo: TArray<TRelationDescription>;
    function GetMastersInfo: TArray<TMasterDescription>;
    function GetKeyInfo: TArray<TClassMemberMap>;
    function GetCustomMapMethod: TRttiMethod;
    function GetOnMapInitializeMethod: TRttiMethod;
    function GetOnMapFinalizeMethod: TRttiMethod;
    function GetOnMapFieldMethod: TRttiMethod;
    function GetFieldValues: TRttiMethod;
    function GetBeforeSave: TRttiMethod;
    function GetAfterSave: TRttiMethod;
    function GetBeforeDelete: TRttiMethod;
    function GetAfterDelete: TRttiMethod;
    function GetStateMode: TStateMode;
    property Provider: String read FProvider;
    class procedure Parse(AType: TRttiType; ADictionary: TDictionary<String, IMapDefinition>);
  end;

  TDefMapImpl = class(TInterfacedObject, IMapManager)
  private
    FMaps: TDictionary<String, IMapDefinition>;
  public
    constructor Create;
    destructor Destroy; override;
    function Get(AType: TRttiType): IMapDefinition; overload;
    function Get(AType: PTypeInfo): IMapDefinition; overload;
    function Get(AType: TRttiType; AProvider: String): IMapDefinition; overload;
    function Get(AType: PTypeInfo; AProvider: String): IMapDefinition; overload;
  end;

  { Column }

constructor Column.Create(const AName: String);
begin
  FName := UpperCase(AName);
  FProvider := '';
end;

constructor Column.Create(const AProvider: String; AName: String);
begin
  FProvider := UpperCase(AProvider);
  FName := UpperCase(AName);
end;

{ ForeignKey }


constructor ForeignKey.Create(AMasterClass: PTypeInfo);

  function GetPKProperty: String;
  var
    LPKAttributes: TArray<TAttrRecord<PrimaryKey>>;
    LCtx: TRttiContext;
  begin
    LPKAttributes := LCtx.GetType(AMasterClass).GetMemberAttributesOfType<PrimaryKey>;
    if Length(LPKAttributes) =  0 then
      raise Exception.CreateFmt('Class %s has not defined a primary key property.',
          [AMasterClass.Name]);

    if Length(LPKAttributes) >  1 then
      raise Exception.CreateFmt('Class %s has many primary key property defined.',
          [AMasterClass.Name]);

    result := LPKAttributes[0].Member.Name;
  end;

begin
  FMasterClassTypeInfo := AMasterClass;
  FMasterProperty := GetPKProperty;
end;

constructor ForeignKey.Create(AMasterClass: Pointer; AMasterProperty: String);
begin
  FMasterClassTypeInfo := PTypeInfo(AMasterClass^);
  FMasterProperty := AMasterProperty;
end;

constructor ForeignKey.Create(AMsterClass: TClass);
begin
  Create(AMsterClass.ClassInfo);
end;

constructor ForeignKey.Create(AMsterIntf: TGUID);
begin
  Create (Factory.GetClassFor(AMsterIntf).ClassInfo);
end;

{ TDefMapDefinitionImpl }

constructor TDefMapDefinitionImpl.Create;
begin
  SetLength(FColumnsMapInfo, 0);
  SetLength(FDetails, 0);
  SetLength(FKeyInfo, 0);
  FState := smKey;
end;

destructor TDefMapDefinitionImpl.Destroy;
begin
  SetLength(FColumnsMapInfo, 0);
  SetLength(FDetails, 0);
  SetLength(FKeyInfo, 0);
  inherited;
end;

function TDefMapDefinitionImpl.GetCustomMapMethod: TRttiMethod;
begin
  result := FCustomMapMethod;
end;

function TDefMapDefinitionImpl.GetDetailsInfo: TArray<TRelationDescription>;
begin
  result := FDetails;
end;

function TDefMapDefinitionImpl.GetEntityName: String;
begin
  result := FEntityName;
end;

function TDefMapDefinitionImpl.GetFieldValues: TRttiMethod;
begin
  result := FGetFields;
end;

function TDefMapDefinitionImpl.GetKeyInfo: TArray<TClassMemberMap>;
begin
  result := FKeyInfo;
end;

function TDefMapDefinitionImpl.GetMastersInfo: TArray<TMasterDescription>;
begin
  result := FMasters;
end;

function TDefMapDefinitionImpl.GetOnMapFieldMethod: TRttiMethod;
begin
  result := FOnMapField;
end;

function TDefMapDefinitionImpl.GetOnMapFinalizeMethod: TRttiMethod;
begin
  result := FOnMapFinalize;
end;

function TDefMapDefinitionImpl.GetOnMapInitializeMethod: TRttiMethod;
begin
  result := FOnMapInitialize;
end;

function TDefMapDefinitionImpl.GetStateMode: TStateMode;
begin
  result := FState;
end;

function TDefMapDefinitionImpl.GetAfterDelete: TRttiMethod;
begin
  result := FAfterDelete;
end;

function TDefMapDefinitionImpl.GetAfterSave: TRttiMethod;
begin
  result := FAfterSave;
end;

function TDefMapDefinitionImpl.GetBeforeDelete: TRttiMethod;
begin
  result := FBeforeDelete;
end;

function TDefMapDefinitionImpl.GetBeforeSave: TRttiMethod;
begin
  result := FBeforeSave;
end;

function TDefMapDefinitionImpl.GetColumnsMapInfo: TArray<TClassMemberMap>;
begin
  result := FColumnsMapInfo;
end;

class procedure TDefMapDefinitionImpl.Parse(AType: TRttiType; ADictionary: TDictionary<String, IMapDefinition>);
var
  LProviders: TList<String>;
  LContext: TRttiContext;
  LProvider: String;
begin
  LProviders := TList<String>.Create;
  LContext := TRttiContext.Create;
  try
    Atype.ForEachMemberAttributeOfType<TCustomAttribute>(
      procedure (Attribute: TCustomAttribute; Member:TRttiMember)
      var
        LProvider: String;
        LProp: TRttiProperty;
      begin
        LProp := LContext.GetType(Attribute.ClassInfo).GetProperty('Provider');
        if LProp = nil then exit;

        LProvider := LProp.GetValue(Attribute).AsString;

        if (LProvider<>'') and not LProviders.Contains(LProvider) then
          LProviders.Add(LProvider);
      end);

    TDefMapDefinitionImpl.ParseProvider(AType, '', ADictionary);

    for LProvider in LProviders do
      TDefMapDefinitionImpl.ParseProvider(AType, LProvider, ADictionary);
  finally
    LProviders.Free;
    LContext.Free;
  end;
end;

class procedure TDefMapDefinitionImpl.ParseProvider(AType: TRttiType; Provider: String;
  ADictionary: TDictionary<String, IMapDefinition>);
var
  LColumnsMapInfo: TDictionary<String, TClassMemberMap>;
  LKeys: TList<TClassMemberMap>;
  LDetails: TList<TRelationDescription>;

  LEntityColumns: TList<String>;

  LAttr: TCustomAttribute;
  LMember: TRttiMember;
  LContext: TRttiContext;

  LDefMap: TDefMapDefinitionImpl;

  LMasters: TDictionary<PTypeInfo, TMasterDescription>;

  i: integer;

  {$REGION 'Funciones auxiliares'}

  function GetProviderColumns(EntityName: String): TList <String>;
  var
    LDataManager: IDataManager;
    LStr: String;
  begin
    LDataManager := Factory.Get<IDataManager>;
    result := TList<String>.Create;
    for LStr in LDataManager.GetColumnNames(EntityName) do
      result.Add(UpperCase(LStr));
  end;

  function GetDetailItemType(const DetailClassName: String): TRttiType;
  var
    LInx: integer;
    LItemClassName: String;
    LType: TRttiType;
  begin
    LInx := Pos('<', DetailClassName);

    LItemClassName := Copy(DetailClassName, LInx + 1,
      Length(DetailClassName) - LInx-1);

    if Pos('<', LItemClassName) > 0 then
    begin
      LInx := Pos('<', LItemClassName);
      LItemClassName := Copy(LItemClassName, LInx + 1,
        Length(LItemClassName) - LInx-1);
    end;

    LType := LContext.FindType(LItemClassName);
    if LType = nil then
      raise Exception.Create('Can''t find type ' + LItemClassName);

    if LType is  TRttiInterfaceType  then
       result := LContext.GetType(factory.GetClassFor(TRttiInterfaceType(LType).GUID).ClassInfo)
    else
      result := LType;

  end;

  function IsProviderColumn(ColumnName: String): Boolean;
  begin
    result := LEntityColumns.Contains(ColumnName);
  end;

  function CheckRelation(Member: TRttiMember): boolean;
  var
    LEntityName: String;
    LType: TRttiType;
    LDetailRec: TRelationDescription;
    LRelationDesc: TArray<Relation>;

  begin
    result := FALSE;
    if (Member is TRttiField) then
      LType := TRttiField(Member).FieldType
    else
      LType := TRttiProperty(Member).PropertyType;

    if LType.IsRecord And (Pos('Relation<', LType.QualifiedName) <> 0) then
    begin

      LEntityName :=  UpperCase(LDefMap.GetEntityName);
      LDetailRec.MasterMember := Member;
      LDetailRec.DetailClassType := GetDetailItemType(LType.QualifiedName);

      LRelationDesc := Member.GetAttributesOfType<Relation>(
        function (Attribute:Relation): boolean
        begin
          result := (Attribute.Provider = Provider) Or
                    ((Provider = LEntityName) And (Attribute.Provider=''));
        end);

      if (Length(LRelationDesc) = 0) then
      begin
        LDetailRec.LoadMode := lmDelayed;
        LDetailRec.RelationType := rtChild;
        LDetailRec.DataReaderColumn := '';
      end
      else begin
        LDetailRec.LoadMode := LRelationDesc[0].LoadMode;
        LDetailRec.RelationType := LRelationDesc[0].RelationType;
        LDetailRec.DataReaderColumn := LRelationDesc[0].Column;
      end;

      LDetails.Add(LDetailRec);
      result := TRUE;
    end;
  end;


  procedure CheckMember(Member: TRttiMember);
  var
    LMemberMap: TClassMemberMap;
    LEntityName: String;
    LEntityColumnName: String;
    LIsKeyAttr: Boolean;
    LIsFKAttr: Boolean;

  begin
    LMemberMap.ClassMember := Member;
    LMemberMap.Column := '';
    LEntityName := UpperCase(LDefMap.GetEntityName);
    LEntityColumnName := '';

    LIsKeyAttr := FALSE;
    LIsFKAttr := FALSE;

    Member.ForEachAttributeOfType<TCustomAttribute>(procedure (Attribute: TCustomAttribute)
      var
        LProvider: String;
      begin
        if Attribute is Column then
        begin
          LProvider := Column(Attribute).Provider;
          if (LProvider = LEntityName) Or
             (LProvider = '') then
              LEntityColumnName := Column(Attribute).Name;
          if (LProvider = Provider) then
           LMemberMap.Column := Column(Attribute).Name;
        end
        else
        if Attribute is PrimaryKey then
          LIsKeyAttr := TRUE
        else
        if Attribute is ForeignKey then
          LIsFKAttr := TRUE;
      end);

    if (LEntityColumnName = '') and ( Member.Visibility in [mvPublic, mvPublished]) and
       IsProviderColumn(UpperCase(Member.Name)) then
      LEntityColumnName := UpperCase(Member.Name);

    if LEntityColumnName = '' then
      Exit;

    if LMemberMap.Column = '' then
      LMemberMap.Column := LEntityColumnName;

    LColumnsMapInfo.Add(Member.Name, LMemberMap);

    if LIsKeyAttr then
      LKeys.Add(LMemberMap);

    if LIsFKAttr then
      Member.ForEachAttributeOfType<ForeignKey>(procedure (LAttr: ForeignKey)
        var
          LMasterDesc: TMasterDescription;
          LIndex: Integer;
          LMasterColumnAttr: Column;
          LMasterEntityName: String;
          LTableAttr: Table;
        begin
          if not LMasters.TryGetValue(ForeignKey(LAttr).FMasterClassTypeInfo,
            LMasterDesc) then
          begin
            LMasterDesc.MasterClassType := LContext.GetType(
               ForeignKey(LAttr).FMasterClassTypeInfo);
            SetLength(LMasterDesc.MasterDetailRelationShip,1);
            LIndex := 0;
            LMasters.Add(ForeignKey(LAttr).FMasterClassTypeInfo, LMasterDesc);
          end
          else
          begin
            LIndex := Length(LMasterDesc.MasterDetailRelationShip);
            SetLength(LMasterDesc.MasterDetailRelationShip,LIndex + 1);
          end;

          LMasterDesc.MasterDetailRelationShip[LIndex].MasterField :=
             GetFieldOrProperty(ForeignKey(LAttr).FMasterClassTypeInfo,
                                  ForeignKey(LAttr).MasterProperty);
          LTableAttr := LMasterDesc.MasterClassType.GetAttributeOfType<Table>;

          if Assigned(LTableAttr) then
            LMasterEntityName := LTableAttr.Name
          else
            LMasterEntityName := UpperCase(Copy(ForeignKey(LAttr)
              .FMasterClassTypeInfo.Name,2,
              Length(ForeignKey(LAttr).FMasterClassTypeInfo.Name)-1));

          LMasterColumnAttr := LMasterDesc.MasterDetailRelationShip[LIndex]
              .MasterField.GetAttributeOfType<Column>(function (Attr: Column): boolean
                begin
                  result := (Attr.Provider = '') Or
                            (Attr.Provider = LMasterEntityName)
                end);

          if Assigned(LMasterColumnAttr) then
            LMasterDesc.MasterDetailRelationShip[LIndex].MasterColumn :=
              LMasterColumnAttr.Name
          else
            LMasterDesc.MasterDetailRelationShip[LIndex].MasterColumn :=
             UpperCase(LMasterDesc.MasterDetailRelationShip[LIndex]
                        .MasterField.Name);


          LMasterDesc.MasterDetailRelationShip[LIndex].DetailField :=
            Member;
          LMasterDesc.MasterDetailRelationShip[LIndex].DetailColumn :=
            LEntityColumnName;

          LMasters[ForeignKey(LAttr).FMasterClassTypeInfo] := LMasterDesc;
        end
      );

  end;

  {$ENDREGION}

begin
  LColumnsMapInfo := TDictionary<String, TClassMemberMap>.Create;
  LKeys := TList<TClassMemberMap>.Create;
  LDetails := TList<TRelationDescription>.Create;
  LMasters := TDictionary<PTypeInfo, TMasterDescription>.Create;

  LContext := TRttiContext.Create;

  LDefMap := TDefMapDefinitionImpl.Create;

  try

    for LAttr in AType.GetAttributes do
      if LAttr is Table then
        LDefMap.FEntityName := Table(LAttr).Name
      else
        if LAttr is State then
          LDefMap.FState := State(LAttr).Mode;

    if LDefMap.FEntityName = '' then
      LDefMap.FEntityName := UpperCase(Copy(AType.Name,2, Length(AType.Name)-1));

    LEntityColumns := GetProviderColumns(LDefMap.FEntityName);

    for LMember in AType.GetFields do
      if LMember.Visibility = mvPublic then
      begin
        if not CheckRelation(LMember) then
          CheckMember(LMember);
      end
      else
        CheckMember(LMember);

    for LMember in AType.GetProperties do
      if TRttiProperty(LMember).IsWritable then
        if not CheckRelation(LMember) then
          CheckMember(LMember);

    {$REGION 'Verificar métodos de inicialización propia'}
    for LMember in AType.GetMethods do
    begin
      // todo: verificar los prototipos de los métodos
      for LAttr in LMember.GetAttributes do
      begin
        if LAttr is CustomMap then
        begin
          LDefMap.FCustomMapMethod := TRttiMethod(LMember);
        end
        else if LAttr is MapInitialize then
        begin
          LDefMap.FOnMapInitialize := TRttiMethod(LMember);
        end
        else if LAttr is MapFinalize then
        begin
          LDefMap.FOnMapFinalize := TRttiMethod(LMember);
        end
        else if LAttr is MapField then
        begin
          LDefMap.FOnMapField := TRttiMethod(LMember);
        end
        else if LAttr is ObjectState then
        begin
          LDefMap.FGetFields := TRttiMethod(LMember);
        end
        else if LAttr is BeforeSave then
        begin
          LDefMap.FBeforeSave := TRttiMethod(LMember);
        end
        else if LAttr is AfterSave then
        begin
          LDefMap.FAfterSave := TRttiMethod(LMember);
        end
        else if LAttr is BeforeDelete then
        begin
          LDefMap.FBeforeDelete := TRttiMethod(LMember);
        end
        else if LAttr is AfterDelete then
        begin
          LDefMap.FAfterDelete := TRttiMethod(LMember);
        end;
      end;
    end;
{$ENDREGION}

    LDefMap.FColumnsMapInfo := LColumnsMapInfo.Values.ToArray;
    LDefMap.FKeyInfo := LKeys.ToArray;
    LDefMap.FMasters := LMasters.Values.ToArray;
    LDefMap.FDetails := LDetails.ToArray;
    LDefMap.FProvider := AType.Name;

    if Provider<>'' then
      ADictionary.Add(UpperCase(AType.Name+'.'+Provider), LDefMap)
    else
      ADictionary.Add(UpperCase(AType.Name), LDefMap)
  finally
    LMasters.Free;
    LColumnsMapInfo.Free;
    LKeys.Free;
    LDetails.Free;
    if LEntityColumns<>nil then
      LEntityColumns.Free;
    LContext.Free;
  end;
end;

{ TDefMapImpl }

constructor TDefMapImpl.Create;
begin
  FMaps := TDictionary<String, IMapDefinition>.Create;
end;

destructor TDefMapImpl.Destroy;
begin
  FMaps.Free;
  inherited;
end;


function TDefMapImpl.Get(AType: PTypeInfo): IMapDefinition;
begin
  result := Get(AType,'');
end;

function TDefMapImpl.Get(AType: PTypeInfo; AProvider: String): IMapDefinition;
var
  LCtx: TRttiContext;
begin
  LCtx:= TRttiContext.Create;
  try
    result := Get(LCtx.GetType(Atype), AProvider);
  finally
    LCtx.Free;
  end;
end;

function TDefMapImpl.Get(AType: TRttiType; AProvider: String): IMapDefinition;
var
  LMapDef: IMapDefinition;
  LOk: boolean;
  LCtx: TRttiContext;
begin
  if AType is TRttiInterfaceType then
  begin
    AType := LCtx.GetType(Factory.GetClassFor(TRttiInterfaceType(AType).GUID).ClassInfo);
  end;

  if AProvider = '' then
    LOk := FMaps.TryGetValue(UpperCase(AType.Name), result)
  else begin
    LOk := FMaps.TryGetValue(UpperCase(AType.Name+'.'+AProvider), result);
    if not LOK then
      LOk := FMaps.TryGetValue(UpperCase(AType.Name), result);
  end;
  if not LOk then
  begin
    TDefMapDefinitionImpl.Parse(AType, FMaps);
    result := Get(AType, AProvider);
  end;
end;

function TDefMapImpl.Get(AType: TRttiType)
  : IMapDefinition;
begin
  result := Get(AType, '');
end;

{ Relation }

constructor Relation.Create(ALoadMode: TRelationLoadMode; ARelationType: TRelationType);
begin
  FLoadMode := ALoadMode;
  FRelationType := ARelationType;
  FProvider := '';
  FColumn := '';
end;

constructor Relation.Create(AProvider: String; ALoadMode: TRelationLoadMode;
  ARelationType: TRelationType);
begin
  FLoadMode := ALoadMode;
  FRelationType := ARelationType;
  FProvider := UpperCase(AProvider);
  FColumn := '';
end;

constructor Relation.Create(AReaderColumnName: String;
  ARelationType: TRelationType);
begin
  FLoadMode := lmColumn;
  FRelationType := ARelationType;
  FProvider := '';
  FColumn := AReaderColumnName;
end;

constructor Relation.Create(AProvider, AReaderColumnName: String;
  ARelationType: TRelationType);
begin
  FLoadMode := lmColumn;
  FRelationType := ARelationType;
  FProvider := UpperCase(AProvider);
  FColumn := AReaderColumnName;
end;



{ State }

constructor State.Create(AMode: TStateMode);
begin
  FStateMode := AMode;
end;

{ Table }

constructor Table.Create(const AName: String);
begin
  FName := UpperCase(AName);
end;

initialization

Factory.Register(IMapManager, TDefMapImpl.Create);

end.
