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
  DminiORM.Core.Factory;

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

  PrimaryKey = class(TCustomAttribute)
  private
    FProvider: String;
  public
    constructor Create; overload;
    constructor Create(AProvider: String); overload;
    property Provider: String read FProvider;
  end;

  ForeignKey = class(TCustomAttribute)
  private
    FMasterClassTypeInfo: PTypeInfo;
    FMasterField: String;
  public
    constructor Create(AMasterClass: PTypeInfo); overload;
    constructor Create(AMasterClass: Pointer; AMasterField: String); overload;
    property MasterClassTypeInfo: PTypeInfo read FMasterClassTypeInfo;
    property MasterField: String read FMasterField;
  end;

  Table = class(Column);

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
  end;

  CustomMap = class(TCustomAttribute);

  MapInitialize = class(TCustomAttribute);

  MapFinalize = class(TCustomAttribute);

  MapField = class(TCustomAttribute);

  ObjectState = class (TCustomAttribute);

implementation

type

  TDefMapImpl = class;

  TDefMapDefinitionImpl = class(TInterfacedObject, IMapDefinition)
  private
    FEntityName: String;
    FRelationsInfo: TArray<TColumnClassRelation>;
    FDetails: TArray<TRelationDescription>;
    FKeyInfo: TArray<TColumnClassRelation>;
    FCustomMapMethod: TRttiMethod;
    FOnMapInitialize: TRttiMethod;
    FOnMapFinalize: TRttiMethod;
    FOnMapField: TRttiMethod;
    FGetFields: TRttiMethod;
    FProvider: String;
  public
    constructor Create;
    destructor Destroy; override;
    function GetEntityName: String;
    function GetColumnsMapInfo: TArray<TColumnClassRelation>;
    function GetDetailsInfo: TArray<TRelationDescription>;
    function GetKeyInfo: TArray<TColumnClassRelation>;
    function GetCustomMapMethod: TRttiMethod;
    function GetOnMapInitializeMethod: TRttiMethod;
    function GetOnMapFinalizeMethod: TRttiMethod;
    function GetOnMapFieldMethod: TRttiMethod;
    function GetFieldValues: TRttiMethod;
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
    function Get(AType: TRttiType; AProvider: String): IMapDefinition; overload;
  end;

  { Column }

constructor Column.Create(const AName: String);
begin
  FName := AName;
  FProvider := '';
end;

constructor Column.Create(const AProvider: String; AName: String);
begin
  FProvider := UpperCase(AProvider);
  FName := AName;
end;

{ ForeignKey }

constructor ForeignKey.Create(AMasterClass: PTypeInfo);
begin
  FMasterClassTypeInfo := AMasterClass;
end;

constructor ForeignKey.Create(AMasterClass: Pointer; AMasterField: String);
begin
  FMasterClassTypeInfo := PTypeInfo(AMasterClass^);
  FMasterField := AMasterField;
end;

{ TDefMapDefinitionImpl }

constructor TDefMapDefinitionImpl.Create;
begin
  SetLength(FRelationsInfo, 0);
  SetLength(FDetails, 0);
  SetLength(FKeyInfo, 0);
end;

destructor TDefMapDefinitionImpl.Destroy;
begin
  SetLength(FRelationsInfo, 0);
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

function TDefMapDefinitionImpl.GetKeyInfo: TArray<TColumnClassRelation>;
begin
  result := FKeyInfo;
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

function TDefMapDefinitionImpl.GetColumnsMapInfo: TArray<TColumnClassRelation>;
begin
  result := FRelationsInfo;
end;

class procedure TDefMapDefinitionImpl.Parse(AType: TRttiType; ADictionary: TDictionary<String, IMapDefinition>);
var
  LRelations: TDictionary<String, TColumnClassRelation>;
  LKeys: TList<String>;
  LDetails: TDictionary<String,TRelationDescription>;

  LRelationsMap: TObjectDictionary<String,TDictionary<String, TColumnClassRelation>>;
  LKeysMap: TObjectDictionary<String, TList<String>>;
  LDetailsMap: TObjectDictionary<String, TDictionary<String, TRelationDescription>>;

  LProviders : TList<String>;

  LAttr: TCustomAttribute;
  LMember: TRttiMember;
  LAddedKey, LAddedColumn: Boolean;
  LContext: TRttiContext;
  LRelation: TColumnClassRelation;

  LDefMap: TDefMapDefinitionImpl;

  i: integer;

  {$REGION 'Funciones auxiliares'}
  function GetFKColumns(MasterTypeInfo, DetailTypeInfo: TRttiType;
      ChildRelationShip: boolean = True): TArray<TRelationShipInfo>;
  var
    LList: TList<TRelationShipInfo>;
    LProp: TRttiProperty;
    LAttr: TCustomAttribute;
    LDetailColumn: String;
    LMasterColumn: String;
    LSw: Boolean;
    LDetailDescription: TRelationShipInfo;

  begin
    LList := TList<TRelationShipInfo>.Create;
    try
      for LProp in DetailTypeInfo.GetProperties do
      begin
        LDetailColumn := '';
        LSw := FALSE;
        for LAttr in LProp.GetAttributes do
        begin
          if (LAttr is Column) then
            LDetailColumn := Column(LAttr).Name
          else
            if (LAttr is ForeignKey) and
              (LContext.GetType(ForeignKey(LAttr).MasterClassTypeInfo)
              .QualifiedName = MasterTypeInfo.QualifiedName)  then
            begin
              LSw := TRUE;
              LMasterColumn := ForeignKey(LAttr).FMasterField;
            end;

          if LSw and (LDetailColumn <> '') then
            break;
        end;

        if LSw then
        begin
          if LDetailColumn = '' then
            LDetailColumn := LProp.Name;

          LDetailDescription.DetailField :=  LDetailColumn;
          LDetailDescription.MasterField := LMasterColumn;

          LList.Add(LDetailDescription);
        end;
      end;
      result := LList.ToArray;
    finally
      LList.Free;
    end;
  end;

  function GetDeatilItemInfo(const DetailClassName: String): TRttiType;
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

    result := LType;

  end;

  procedure CheckMember;
  var
    LAttr: TCustomAttribute;
    LProvKeys: TList<String>;
    LProvRelations: TDictionary<String, TColumnClassRelation>;
    LRelation: TColumnClassRelation;

  begin
    LAddedKey := FALSE;
    LAddedColumn := FALSE;

    for LAttr in LMember.GetAttributes do
    begin
      if LAttr is Column then
      begin
        LRelation.ColumnName := Column(LAttr).Name;
        LRelation.ClassMember := LMember;
        if Column(LAttr).Name<>'' then
        begin
          if not LRelationsMap.TryGetValue(Column(LAttr).Provider, LProvRelations) then
          begin
            LProvRelations := TDictionary<String, TColumnClassRelation>.Create;
            LRelationsMap.Add(Column(LAttr).Provider, LProvRelations);
            if not LProviders.Contains(Column(LAttr).Provider) then
              LProviders.Add(Column(LAttr).Provider);
          end;
          LProvRelations.Add(LMember.Name, LRelation);
        end
        else
        begin
          LRelations.Add(LMember.Name, LRelation);
          LAddedColumn := TRUE;
        end;
      end
      else
      if LAttr is PrimaryKey then
        if PrimaryKey(LAttr).Provider<>'' then
        begin
          if not LKeysMap.TryGetValue(PrimaryKey(LAttr).Provider, LProvKeys) then
          begin
            LProvKeys := TList<String>.Create;
            LKeysMap.Add(PrimaryKey(LAttr).Provider, LProvKeys);
            if not LProviders.Contains(PrimaryKey(LAttr).Provider) then
              LProviders.Add(PrimaryKey(LAttr).Provider);
          end;
          LProvKeys.Add(LMember.Name)
        end
        else
        begin
          LKeys.Add(LMember.Name);
          LAddedKey := TRUE;
        end;
    end;
  end;

  function CheckRelation: boolean;
  var
    LProvDetails: TDictionary<String, TRelationDescription>;
    LDetailRec: TRelationDescription;
    LRelation: TColumnClassRelation;
    LProvider: String;
    LAttr: TCustomAttribute;

  begin
    result := FALSE;
    if TRttiProperty(LMember).PropertyType.IsRecord And
        (Pos('Relation<', TRttiProperty(LMember).PropertyType.QualifiedName)
        <> 0) then
      begin
        result := TRUE;
        LDetailRec.MasterProperty := TRttiProperty(LMember);
        LDetailRec.LoadMode := lmDelayed;
        LDetailRec.RelationType := rtChild;
        LProvider := '';
        for LAttr in LMember.GetAttributes do
          if LAttr is Relation then begin
            LDetailRec.LoadMode := Relation(LAttr).FLoadMode;
            LDetailRec.RelationType := Relation(LAttr).FRelationType;
            LDetailRec.DateReaderColumn := Relation(LAttr).FColumn;
            LProvider := Relation(LAttr).Provider;
            break;
          end;

        if LDetailRec.RelationType = rtChild then
          LDetailRec.MasterDetailRelationShip :=
            GetFKColumns(AType, GetDeatilItemInfo(LDetailRec.MasterProperty.PropertyType.Name))
        else
          LDetailRec.MasterDetailRelationShip :=
            GetFKColumns(GetDeatilItemInfo(LDetailRec.MasterProperty.PropertyType.Name), AType, FALSE);
        if (LProvider<>'') then
        begin
          if not LDetailsMap.TryGetValue(LProvider, LProvDetails) then
          begin
            LProvDetails := TDictionary<String, TRelationDescription>.Create;
            LDetailsMap.Add(LProvider, LProvDetails);
            if not LProviders.Contains(LProvider) then
              LProviders.Add(LProvider);
          end;
          LProvDetails.Add(LMember.Name,LDetailRec);
        end
        else
          LDetails.Add(LMember.Name, LDetailRec);
      end
  end;

  procedure CreateMaps;
  var
    i, j: Integer;
    LMapObj: TDefMapDefinitionImpl;
    LProvRelations: TDictionary<String, TColumnClassRelation>;
    LProvKeys: TList<String>;
    LProvDetails: TDictionary<String, TRelationDescription>;
    LRelation: TColumnClassRelation;
    LKey: String;
    LDetail: TRelationDescription;

  begin
    ADictionary.Add(AType.Name, LDefMap);
    for i := 1 to LProviders.Count-1 do
    begin
      LMapObj := TDefMapDefinitionImpl.Create;

      LMapObj.FEntityName := LDefMap.FEntityName;
      LMapObj.FCustomMapMethod := LDefMap.FCustomMapMethod;
      LMapObj.FOnMapInitialize := LDefMap.FOnMapInitialize;
      LMapObj.FOnMapFinalize := LDefMap.FOnMapFinalize;
      LMapObj.FOnMapField := LDefMap.FOnMapField;
      LMapObj.FGetFields := LDefMap.FGetFields;
      LMapObj.FProvider := LDefMap.FProvider+'.'+LProviders[i];

      if LRelationsMap.TryGetValue(LProviders[i], LProvRelations) then
      begin
        for LRelation in LDefMap.FRelationsInfo do
          if not LProvRelations.ContainsKey(LRelation.ClassMember.Name) then
            LProvRelations.Add(LRelation.ClassMember.Name, LRelation);
        LMapObj.FRelationsInfo := LProvRelations.Values.ToArray;
      end
      else
      begin
        LMapObj.FRelationsInfo := LDefMap.FRelationsInfo;
        LProvRelations := LRelations;
      end;

      if not LKeysMap.TryGetValue(LProviders[i], LProvKeys) then
        LProvKeys := LKeys;
      SetLength(LMapObj.FKeyInfo, LProvKeys.Count);
      for j := 0 to LProvKeys.Count - 1 do
        LMapObj.FKeyInfo[j] := LProvRelations[LProvKeys[j]];

      if LDetailsMap.TryGetValue(LProviders[i],LProvDetails) then
      begin
        for LDetail in LDefMap.FDetails do
          if not LProvDetails.ContainsKey(LDetail.MasterProperty.Name) then
            LProvDetails.Add(LDetail.MasterProperty.Name, LDetail);
        LMapObj.FDetails := LProvDetails.Values.ToArray;
      end
      else
        LMapObj.FDEtails:= LDefMap.FDetails;

      ADictionary.Add(LProviders[i],LMapObj);
    end;
  end;

  {$ENDREGION}

begin
  LRelations := TDictionary<String, TColumnClassRelation>.Create;
  LKeys := TList<String>.Create;
  LDetails := TDictionary<String, TRelationDescription>.Create;

  LRelationsMap := TObjectDictionary<String, TDictionary<String, TColumnClassRelation>>
          .Create([doOwnsValues]);
  LKeysMap := TObjectDictionary<String, TList<String>>.Create([doOwnsValues]);
  LDetailsMap := TObjectDictionary<String, TDictionary<String, TRelationDescription>>.Create([doOwnsValues]);

  LDefMap := TDefMapDefinitionImpl.Create;

  LProviders:= TList<String>.Create;

//  LRelationsMap.Add(AType.Name, LRelations);
//  LKeysMap.Add(AType.Name, LKeys);
//  LDetails.Add(AType.Name, LDetails);

  LContext := TRttiContext.Create;

  try

    for LAttr in AType.GetAttributes do
      if LAttr is Table then
      begin
        LDefMap.FEntityName := Table(LAttr).Name;
        break;
      end;
    if LDefMap.FEntityName = '' then
      LDefMap.FEntityName := AType.Name;

    for LMember in AType.GetFields do
    begin
      CheckMember;
      if (LAddedKey) And not(LAddedColumn) then
      begin
        LRelation.ColumnName := LMember.Name;
        LRelation.ClassMember := LMember;
        LRelations.Add(LMember.Name, LRelation);
      end;
    end;

    for LMember in AType.GetDeclaredProperties do
    if not CheckRelation then
    begin
      LAddedColumn := FALSE;
      CheckMember;
      if not LAddedColumn then
      begin
        LRelation.ColumnName := LMember.Name;
        LRelation.ClassMember := LMember;
        LRelations.Add(LMember.Name, LRelation);
      end;
    end;

    {$REGION 'Verificar métodos de inicialización propia'}
    for LMember in AType.GetMethods do
    begin
      // todo: verificar los prototipos de los métodos
      for LAttr in LMember.GetAttributes do
      begin
        if LAttr is CustomMap then
        begin
          LDefMap.FCustomMapMethod := TRttiMethod(LMember);
          break;
        end
        else if LAttr is MapInitialize then
        begin
          LDefMap.FOnMapInitialize := TRttiMethod(LMember);
          break;
        end
        else if LAttr is MapFinalize then
        begin
          LDefMap.FOnMapFinalize := TRttiMethod(LMember);
          break;
        end
        else if LAttr is MapField then
        begin
          LDefMap.FOnMapField := TRttiMethod(LMember);
          break;
        end
        else if LAttr is ObjectState then
        begin
          LDefMap.FGetFields := TRttiMethod(LMember);
          break;
        end;
      end;
    end;
{$ENDREGION}

    LDefMap.FRelationsInfo := LRelations.Values.ToArray;
    LDefMap.FProvider := AType.Name;

    SetLength(LDefMap.FKeyInfo, LKeys.Count);
    for i := 0 to LKeys.Count - 1 do
      LDefMap.FKeyInfo[i] := LRelations[LKeys[i]];
    LDefMap.FDetails := LDetails.Values.ToArray;

    CreateMaps;
  finally
    LRelations.Free;
    LKeys.Free;
    LDetails.Free;
    LRelationsMap.Free;
    LKeysMap.Free;
    LDetailsMap.Free;
    LProviders.Free;
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


function TDefMapImpl.Get(AType: TRttiType; AProvider: String): IMapDefinition;
var
  LMapDef: IMapDefinition;
  LOk: boolean;
begin
  if AProvider = '' then
    LOk := FMaps.TryGetValue(AType.Name, result)
  else begin
    LOk := FMaps.TryGetValue(AType.Name+'.'+AProvider, result);
    if not LOK then
      LOk := FMaps.TryGetValue(AType.Name, result);
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

{ PrimaryKey }

constructor PrimaryKey.Create;
begin
  FProvider:='';
end;

constructor PrimaryKey.Create(AProvider: String);
begin
  FProvider:= AProvider;
end;

initialization

Factory.Register(IMapManager, TDefMapImpl);

end.
