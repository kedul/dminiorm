unit DminiORM.Core;

interface

Uses RTTI, SysUtils, TypInfo, Variants, Generics.Collections;

type

  TColumn = record
    Name: String;
    Value: TValue;
    constructor Create(AName: String; AValue: TValue);
  end;

  TDataRow = TArray<TColumn>;

  IDataReader = Interface
    ['{15824310-0C9E-4482-9E97-7BAB8EF2ECC2}']
    function GetEOF: Boolean;
    procedure Next;
    function GetDataRow: TDataRow;
    function GetRecNo: Integer;
    function GetRowColumn(ColumnName: String; out Value: TValue): Boolean;
    property EOF: Boolean read GetEOF;
    property RecNo: Integer read GetRecNo;
    property DataRow: TDataRow read GetDataRow;
  end;

  TORMField = record
    ProperyName: String;
    ColumnName: String;
    IsKeyField: Boolean;
    OldValue: TValue;
    NewValue: TValue;
    function Modified: Boolean;
  end;

  TORMFields = TArray<TORMField>;

  TObjectState = (osNew, osModified, osDeleted, osUnknow);

  TORMObjectStatus = record
    State: TObjectState;
    Fields: TORMFields;
    function ModifiedFields: TORMFields;
    function IsModified: Boolean;
    function KeyFields: TORMFields;
  end;

  IDataWriter = interface
    ['{D10FA8DD-0838-4836-88E0-A9351739CA6C}']
    function Save(Records: TArray<TORMObjectStatus>): TArray<TDataRow>;
    procedure Delete(RecKeys: TArray<TORMFields>);
  end;

  TParameter = TColumn;

  IDataManager = interface
    ['{3C8B01FA-FD35-4B79-8466-1E3B8D660C91}']
    function GetReader(ClassName, ProviderName: String;
      Parameters: TArray<TParameter>): IDataReader;
    function GetWriter(ClassName: String): IDataWriter;
  end;

  TCustomMapPrototype = procedure(Data: IDataReader) of Object;

  TOnMapInitailizePrototype = procedure(Row: TDataRow) of Object;

  TOnMapFinalize = procedure of Object;

  TOnMapFieldPrototype = procedure(MemberName, ColumnName: String;
    var Value: TValue; var Accept: Boolean) of Object;

  TColumnClassRelation = record
    ClassMember: TRttiMember;
    ColumnName: String;
  end;

  TRelationLoadMode = (lmDelayed, lmInLoad, lmColumn, lmEmbebed);

  TRelationType = (rtOwner, rtChild);

  TRelationShipInfo = record
    MasterField: String;
    DetailField: String;
  end;

  TRelationDescription = record
    MasterProperty: TRttiProperty;
    LoadMode: TRelationLoadMode;
    RelationType: TRelationType;
    DateReaderColumn: String;
    MasterDetailRelationShip: TArray<TRelationShipInfo>;
  End;

  IMapDefinition = Interface
    ['{252A0310-9E5E-4C10-AA92-969421158AE4}']
    function GetEntityName: String;
    function GetColumnsMapInfo: TArray<TColumnClassRelation>;
    function GetDetailsInfo: TArray<TRelationDescription>;
    function GetKeyInfo: TArray<TColumnClassRelation>;
    function GetCustomMapMethod: TRttiMethod;
    function GetOnMapInitializeMethod: TRttiMethod;
    function GetOnMapFinalizeMethod: TRttiMethod;
    function GetOnMapFieldMethod: TRttiMethod;
    function GetFieldValues: TRttiMethod;
  End;

  IMapManager = Interface
    ['{5946082A-37E5-4E65-9BA3-0F31E2C88352}']
    function Get(AType: TRttiType): IMapDefinition; overload;
    function Get(AType: TRttiType; AProvider: String): IMapDefinition; overload;
  End;

  IObjectState = Interface
    ['{B57791BF-381F-4177-9FCF-580FB1F8E764}']
    function GetFieldValues(AObject: TObject; AMap: IMapDefinition)
      : TORMObjectStatus;
  end;


  // ICacheable = interface
  // ['{A566CFFF-E48D-4C4D-A717-A9ED8D0E7142}']
  // function getCacheKey: TValue;
  // end;
  //
  // ICacheManager = interface
  // ['{C0F274A3-135E-4580-BDC9-682F20C3EA2D}']
  // procedure Add(AObject: TObject; AExpiration: TDateTime);
  // procedure Replace(AObjet: TObject; AExpiration: TDateTime = 0);
  // function Get(AKey: TValue): TObject;
  // procedure Delete(AKey: TValue);
  // end;

  TORMBase = class;

  ILoadDelegate<T: class> = Interface
    ['{D9DB705C-DB5D-433A-901D-88E9EF631CEF}']
    procedure Put(const Value: T);
    function Get: T;
  End;

  Relation<T: class> = record
  private
    {
      LoadDelegate es necesario para que la lista con los objetos se libere de
      forma automática cuando se pierda la referencia. De otra forma, sería
      necesario que en el destructor de la clase, liberara de forma explicita
      este objeto.
    }
    LoadDelegate: ILoadDelegate<T>;
    Owner: TObject;
    Orm: TORMBase;
    DetailColumns: TArray<TRelationShipInfo>;
    DataReader: IDataReader;
    procedure Initialize;
  public
    function Get: T;
    class operator Implicit(const Lazy: Relation<T>): T;
    class operator Implicit(const Value: T): Relation<T>;
  end;

  RealtionRec = record
    Delegate: IInterface;
    Owner: TObject;
    Orm: TORMBase;
    DetailColumns: TArray<TRelationShipInfo>;
    DataReader: IDataReader;
  end;

  PRelationRec = ^RealtionRec;

  TLoadDelegate<T: class> = class(TInterfacedObject, ILoadDelegate<T>)
  private
    FObject: T;
    FOwnedObject: Boolean;
    FLoaded: Boolean;
    FOwner: PRelationRec;
  public
    constructor Create(AOwner: PRelationRec);
    destructor Destroy; override;
    function Get: T;
    procedure Put(const Value: T);
  end;

  TReaderEOF = reference to function(Data: IDataReader): Boolean;

  TORMBase = class
  private
    FCtx: TRttiContext;
    FMapManager: IMapManager;
    FDataManager: IDataManager;
    FObjectState: IObjectState;
    FCurrentReader: IDataReader;
    FCurrentWriter: IDataWriter;
    FStack: TList<TObject>;
    function GetAddMethod(AType: TRttiType): TRttiMethod;
  protected
    function GetCollectionItemType(ClassName: String): TRttiType; overload;
    function GetCollectionItemType(AtypeInfo: pointer): TRttiType; overload;
    procedure FillObject(AObject: TValue; AMap: IMapDefinition;
      ItemType: TRttiType; Data: IDataReader); virtual;
    function InternalLoad(AtypeInfo: PTypeInfo; Data: IDataReader;
      EOFChecker: TReaderEOF = nil): TValue; virtual;
    property RttiContext: TRttiContext read FCtx;
    property DataManager: IDataManager read FDataManager;
    property MapManager: IMapManager read FMapManager;
    property CurrentReader: IDataReader read FCurrentReader;
    property CurrentWriter: IDataWriter read FCurrentWriter;
  public
    constructor Create;
    destructor Destroy; override;
    function Load<T>(Data: IDataReader): T; overload;
    function Load<T>(KeyValues: TArray<TParameter>): T; overload;
    function Load<T>(ProviderName: String; Parameters: TArray<TParameter>) : T; overload;
    procedure Save(AObject: TObject; Dest: IDataWriter); overload;
    procedure Save(AObject: TObject); overload;
    procedure Delete(AObject: TObject; Dest: IDataWriter); overload;
    procedure Delete(AObject: TObject); overload;
  end;

  TFactoryBase = class
  protected
    function GetInstance(AtypeInfo: pointer): TValue; virtual; abstract;
  public
    procedure Register(const AGUID: TGUID; AClass: TClass); virtual; abstract;
    function Get(AtypeInfo: pointer): TValue; overload;
    function Get<T>: T; overload;
  end;

Var
  Factory: TFactoryBase;

implementation

function TORMField.Modified: Boolean;
begin
  result := not VarSameValue(OldValue.AsVariant, NewValue.AsVariant);
end;

function TORMObjectStatus.IsModified: Boolean;
var
  LField: TORMField;
begin
  result := State = osNew;
  if not result then
    for LField in Fields do
      if LField.Modified then
        Exit(true);
end;

function TORMObjectStatus.ModifiedFields: TORMFields;
var
  i: Integer;
  LIndex: Integer;
begin
  SetLength(result, Length(Fields));
  LIndex := 0;

  for i := 0 to Length(Fields) - 1 do
    if Fields[i].Modified then
    begin
      result[LIndex] := Fields[i];
      inc(LIndex);
    end;

  SetLength(result, LIndex);
end;

function TORMObjectStatus.KeyFields: TORMFields;
var
  i: Integer;
  LIndex: Integer;
begin
  SetLength(result, Length(Fields));
  LIndex := 0;

  for i := 0 to Length(Fields) - 1 do
    if Fields[i].IsKeyField then
    begin
      result[LIndex] := Fields[i];
      inc(LIndex);
    end;

  SetLength(result, LIndex);
end;

{ TLazyLoadDelegated<T> }

constructor TLoadDelegate<T>.Create(AOwner: PRelationRec);
begin
  FObject := nil;
  FOwner := AOwner;
end;

destructor TLoadDelegate<T>.Destroy;
begin
  if Assigned(FObject) And (FOwnedObject) then
    FObject.Free;
  inherited;
end;

function TLoadDelegate<T>.Get: T;
var
  LDetailParamValues: TArray<TParameter>;
  LProp: TRttiProperty;
  LField: TRttiField;
  i: Integer;
begin

  if not FLoaded then
  begin
    FLoaded := true;
    for i := 0 to FOwner.Orm.FStack.Count - 1 do
    begin
      if TypeInfo(T) = FOwner.Orm.FStack[i].ClassInfo then
      begin
        FObject := T(FOwner.Orm.FStack[i]);
        FOwnedObject := FALSE;
        break;
      end;
    end;
    if not Assigned(FObject) then
    begin
      FOwnedObject := true;
      FLoaded := true;
      SetLength(LDetailParamValues, Length(FOwner.DetailColumns));

      for i := 0 to Length(FOwner.DetailColumns) - 1 do
      begin
        LDetailParamValues[i].Name := FOwner.DetailColumns[i].DetailField;
        LProp := FOwner.Orm.RttiContext.GetType(FOwner.Owner.ClassInfo)
          .GetProperty(FOwner.DetailColumns[i].MasterField);
        if LProp <> nil then
        begin
          LDetailParamValues[i].Value := LProp.GetValue(FOwner.Owner);
        end
        else
        begin
          LField := FOwner.Orm.RttiContext.GetType(FOwner.Owner.ClassInfo)
            .GetField(FOwner.DetailColumns[i].MasterField);
          if LField = nil then
            raise Exception.Create('Can''t find master field ' +
              FOwner.DetailColumns[i].MasterField);
          LDetailParamValues[i].Value := LField.GetValue(FOwner.Owner);
        end
      end;

      if Assigned(FOwner.DataReader) then
        // modo lmEmbebed
        if (FOwner.DataReader = FOwner.Orm.FCurrentReader) then
        begin
          FObject := FOwner.Orm.InternalLoad(TypeInfo(T), FOwner.DataReader,
            function(Data: IDataReader): Boolean
            var
              LParam: TParameter;
              LColumnValue: TValue;
            begin
              result := FALSE;
              for LParam in LDetailParamValues do
              begin
                if not Data.GetRowColumn(LParam.Name, LColumnValue) then
                  Exit(true);
                if not VarSameValue(LColumnValue.AsVariant,
                  LParam.Value.AsVariant) then
                  Exit(true);
              end;
            end).AsType<T>;
        end
        else
          // modo lmColumn
        begin
          FObject := FOwner.Orm.InternalLoad(TypeInfo(T), FOwner.DataReader).AsType<T>;
        end
      else
        // modo lmDelayed, lmInLoad
        FObject := FOwner.Orm.InternalLoad(TypeInfo(T),
          FOwner.Orm.FDataManager.GetReader(PTypeInfo(TypeInfo(T)).Name,
          FOwner.Owner.ClassName + '.Detail', LDetailParamValues)).AsType<T>;

    end;
  end;
  result := FObject;
end;

procedure TLoadDelegate<T>.Put(const Value: T);
begin
  if TObject(Value) <> TObject(FObject) then
  begin
    FObject.Free;
    FObject := Value;
    FOwnedObject := FALSE;
    FLoaded := true;
  end;
end;

{ LazyLoad<T> }

class operator Relation<T>.Implicit(const Lazy: Relation<T>): T;
begin
  result := Lazy.Get;
end;

function Relation<T>.Get: T;
begin
  if LoadDelegate = nil then
    Initialize;
  result := LoadDelegate.Get;
end;

class operator Relation<T>.Implicit(const Value: T): Relation<T>;
begin
  result.Initialize;
  result.LoadDelegate.Put(T);
end;

procedure Relation<T>.Initialize;
begin
  LoadDelegate := TLoadDelegate<T>.Create(PRelationRec(@Self));
end;

{ TColumn }

constructor TColumn.Create(AName: String; AValue: TValue);
begin
  Name := AName;
  AValue := AValue;
end;

{ TORMBase }

constructor TORMBase.Create;
begin
  FCtx := TRttiContext.Create;
  FMapManager := Factory.Get<IMapManager>;
  FDataManager := Factory.Get<IDataManager>;
  FObjectState := Factory.Get<IObjectState>;
  FStack := TList<TObject>.Create;
end;

destructor TORMBase.Destroy;
begin
  FCtx.Free;
  FStack.Free;
  FMapManager := nil;
  FDataManager := nil;
  inherited;
end;


function TORMBase.GetAddMethod;
var
  LAddMths: TArray<TRttiMethod>;
  LMtd: TRttiMethod;
  LMtdParams: TArray<TRttiParameter>;
begin
  LAddMths := AType.GetMethods;
  if LAddMths = nil then
    Exit(nil);
  for LMtd in LAddMths do
    if SameText('ADD', LMtd.Name) then
    begin
      LMtdParams := LMtd.GetParameters;
      if (LMtdParams <> nil) And (Length(LMtdParams) = 1) then
      begin
        Exit(LMtd);
      end;
    end;
  result := nil;
end;

function TORMBase.GetCollectionItemType(AtypeInfo: pointer): TRttiType;
begin
  result := GetCollectionItemType(RttiContext.GetType(AtypeInfo).Name);
end;

function TORMBase.GetCollectionItemType(ClassName: String): TRttiType;
var
  LInx1, LInx2: Integer;
begin
  LInx1 := pos('<', ClassName) + 1;
  LInx2 := pos('>', ClassName) - 1;
  ClassName := Copy(ClassName, LInx1, LInx2 - LInx1 + 1);
  result := RttiContext.FindType(ClassName);
  if result = nil then
    raise Exception.Create('Can''t find type ' + ClassName);
end;

function TORMBase.Load<T>(ProviderName: String;
Parameters: TArray<TParameter>): T;
var
  DataReader: IDataReader;
begin
  DataReader := DataManager.GetReader(FCtx.GetType(TypeInfo(T)).Name,
    ProviderName, Parameters);

  if DataReader = nil then
    raise Exception.Create('Can''t find default reader for class ' +
      FCtx.GetType(TypeInfo(T)).Name);

  result := Load<T>(DataReader);
end;

function TORMBase.Load<T>(KeyValues: TArray<TParameter>): T;
begin
  result := Load<T>('', KeyValues);
end;

function TORMBase.Load<T>(Data: IDataReader): T;
begin
  result := InternalLoad(TypeInfo(T), Data).AsType<T>;
end;

procedure TORMBase.FillObject(AObject: TValue; AMap: IMapDefinition;
ItemType: TRttiType; Data: IDataReader);
var
  LColumnRelation: TColumnClassRelation;
  LAccept: Boolean;
  LColumnValue: TValue;
  LRelationValue: TValue;
  LOutParam: Array of TValue;
  LDetailInfo: TRelationDescription;
  LDetailRec: PRelationRec;
  LInf : IInterface;
begin
  if Assigned(AMap.GetCustomMapMethod) then
  begin
    AMap.GetCustomMapMethod.Invoke(AObject, [TValue.From<IDataReader>(Data)]);
  end
  else
  begin
    if Assigned(AMap.GetOnMapInitializeMethod) then
      AMap.GetOnMapInitializeMethod.Invoke(AObject,
        [TValue.From<TDataRow>(Data.DataRow)]);

    for LColumnRelation in AMap.GetColumnsMapInfo do
    begin
      Data.GetRowColumn(LColumnRelation.ColumnName, LColumnValue);
      LAccept := FALSE;

      if Assigned(AMap.GetOnMapFieldMethod) then
      begin
        SetLength(LOutParam, 4);
        LOutParam[0] := LColumnRelation.ClassMember.Name;
        LOutParam[1] := LColumnRelation.ColumnName;
        LOutParam[2] := LColumnValue;
        LOutParam[3] := LAccept;
        ItemType.GetMethod(AMap.GetOnMapFieldMethod.Name)
          .Invoke(AObject, LOutParam);
        LAccept := LOutParam[3].AsBoolean;
      end;

      if NOT LAccept and not LColumnValue.IsEmpty then
        try
          if LColumnRelation.ClassMember is TRttiField then
            TRttiField(LColumnRelation.ClassMember).SetValue(AObject.AsObject,
              LColumnValue)
          else
            TRttiProperty(LColumnRelation.ClassMember)
              .SetValue(AObject.AsObject, LColumnValue);
        except
          raise Exception.Create(VarToStr(LColumnValue.AsVariant) +
            ' is not a valid value for ' + LColumnRelation.ClassMember.Name);
        end;
    end;

    for LDetailInfo in AMap.GetDetailsInfo do
    begin
      LColumnValue := LDetailInfo.MasterProperty.GetValue(AObject.AsObject);
      LDetailRec := PRelationRec(LColumnValue.GetReferenceToRawData);

      LDetailRec.Owner := AObject.AsObject;
      LDetailRec.Orm := Self;
      LDetailRec.DetailColumns := LDetailInfo.MasterDetailRelationShip;
      LDetailRec.DataReader := nil;

      if LDetailInfo.LoadMode in [lmInLoad, lmEmbebed, lmColumn] then
      begin
        if LDetailInfo.LoadMode = lmEmbebed then
          LDetailRec.DataReader := Data
        else
        if LDetailInfo.LoadMode = lmColumn then
        begin
          if not Data.GetRowColumn(LDetailInfo.DateReaderColumn,LRelationValue) then
            raise Exception.Create('Can''t find delail column ' +
              LDetailInfo.DateReaderColumn);
          LInf := LRelationValue.AsInterface;
          Supports(LInf, IDataReader,LDetailRec.DataReader);
          //Linf._Release;
        end;
        RttiContext.GetType(LColumnValue.TypeInfo).GetMethod('Get')
          .Invoke(LColumnValue, []);
        if LDetailInfo.LoadMode = lmColumn then
          LDetailRec.DataReader := nil;
      end;

      LDetailInfo.MasterProperty.SetValue(AObject.AsObject, LColumnValue);
    end;

    if Assigned(AMap.GetOnMapFinalizeMethod) then
      AMap.GetOnMapInitializeMethod.Invoke(AObject, []);
  end;
end;

function TORMBase.InternalLoad(AtypeInfo: PTypeInfo; Data: IDataReader;
EOFChecker: TReaderEOF): TValue;
var
  LObj: TValue;
  LCollection: TObject;
  LType: TRttiType;
  LAddMthd: TRttiMethod;
  LMap: IMapDefinition;
  LRecNo: Integer;
  LSavedReader: IDataReader;

begin
  LType := RttiContext.GetType(AtypeInfo);

  LAddMthd := GetAddMethod(LType);
  if (LAddMthd = nil) and Data.EOF then
    Exit(TValue.Empty);

  if Data.EOF then // es una colección que se crea y devuelve con 0 elementos
    Exit(Factory.Get(AtypeInfo));

  LSavedReader := FCurrentReader;
  FCurrentReader := Data;
  try
    if LAddMthd <> nil then
    begin
      LType := GetCollectionItemType(LType.Name);
      LCollection := Factory.Get(AtypeInfo).AsObject;
    end
    else
      LCollection := nil;
    try
      LMap := FMapManager.Get(LType);
      if Not Assigned(LMap) then
        raise Exception.Create('Can'' create a map info for class ' +
          LType.Name);

      while not Data.EOF and (not Assigned(EOFChecker) or
        (Assigned(EOFChecker) and not EOFChecker(Data))) do
      begin
        LObj := Factory.Get(LType.AsInstance.MetaclassType.ClassInfo);
        // .AsObject;

        LRecNo := Data.RecNo;
        FStack.Add(LObj.AsObject);
        try
          FillObject(LObj, LMap, LType, Data);
        finally
          FStack.Delete(FStack.Count - 1);
        end;

        if LAddMthd = nil then
          Exit(LObj);

        if LRecNo = Data.RecNo then
          Data.Next;

        LAddMthd.Invoke(LCollection, [LObj]);
      end;
      result := LCollection;
    except
      if Assigned(LCollection) then
        LCollection.Free;
      if LObj.IsObject then
        LObj.AsObject.Free;
      raise;
    end;
  finally
    FCurrentReader := LSavedReader;
  end;
end;

procedure TORMBase.Save(AObject: TObject; Dest: IDataWriter);
var
  LRecs: TArray<TORMObjectStatus>;
  LRec: TORMObjectStatus;
begin
  FCurrentWriter := Dest;
  try
    LRec := FObjectState.GetFieldValues(AObject, FMapManager.Get(
      RttiContext.GetType(AObject.ClassInfo)));

    if not LRec.IsModified then
      Exit;

    SetLength(LRecs, 1);
    LRecs[0] := LRec;
    Dest.Save(LRecs);
  finally
    FCurrentWriter := nil;
  end;
  // Todo: grabar los datos detalle
end;

procedure TORMBase.Save(AObject: TObject);
var
  DataWriter: IDataWriter;
begin
  DataWriter := DataManager.GetWriter(AObject.QualifiedClassName);
  if DataWriter = nil then
    raise Exception.Create('Can''t find a writer for class ' +
      AObject.QualifiedClassName);
  Save(AObject, DataWriter);
end;

procedure TORMBase.Delete(AObject: TObject; Dest: IDataWriter);
var
  LRecs: TArray<TORMFields>;
  LRec: TORMObjectStatus;

begin
  FCurrentWriter := Dest;
  try
    LRec := FObjectState.GetFieldValues(AObject, FMapManager.Get(
      RttiContext.GetType(AObject.ClassInfo)));

    SetLength(LRecs, 1);
    LRecs[0] := LRec.KeyFields;
    Dest.Delete(LRecs);
  finally
    FCurrentWriter := nil;
  end;
end;

procedure TORMBase.Delete(AObject: TObject);
var
  LDataWriter: IDataWriter;
begin
  LDataWriter := DataManager.GetWriter(AObject.QualifiedClassName);
  if LDataWriter = nil then
    raise Exception.Create('Can''t find a writer for class ' +
      AObject.QualifiedClassName);
  Delete(AObject, LDataWriter);
end;

{ TFactory }

function TFactoryBase.Get(AtypeInfo: pointer): TValue;
begin
  result := GetInstance(AtypeInfo);
end;

function TFactoryBase.Get<T>: T;
var
  LInstance: TValue;
  LCtx: TRttiContext;
  LIntf: IInterface;
  LType: TRttiType;
begin
  LCtx := TRttiContext.Create;
  try
    LInstance := GetInstance(TypeInfo(T));
    LType := LCtx.GetType(TypeInfo(T));
    if LType is TRttiInterfaceType then
    begin
      LIntf := LInstance.AsInterface;
      Supports(LInstance.AsObject, TRttiInterfaceType(LType).GUID, result);
    end
    else
      result := LInstance.AsType<T>;
  finally
    LCtx.Free;
  end;
end;

type

  TRegisteredRec = record
    AClass: TClass;
    AGUID: TGUID;
  end;

  TFactory = class(TFactoryBase)
  private
    FRegisteredIntf: TArray<TRegisteredRec>;
  protected
    function GetInstance(AtypeInfo: pointer): TValue; override;
  public
    constructor Create;
    procedure Register(const AGUID: TGUID; AClass: TClass); override;
  end;

constructor TFactory.Create;
begin
  SetLength(FRegisteredIntf, 0);
end;

function TFactory.GetInstance(AtypeInfo: pointer): TValue;
var
  LCtx: TRttiContext;
  LRec: TRegisteredRec;
  LClass: TClass;
  LType: TRttiType;
  LMethod: TRttiMethod;
begin
  LCtx := TRttiContext.Create;
  try
    LClass := nil;
    result := nil;
    LType := LCtx.GetType(AtypeInfo);

    if (LType is TRttiInterfaceType) then
    begin
      for LRec in FRegisteredIntf do
      begin
        if LRec.AGUID = TRttiInterfaceType(LType).GUID then
        begin
          LClass := LRec.AClass;
          break;
        end;
      end;

      if LClass = nil then
        raise Exception.Create('Can''t find a factory for interface ' +
          LType.Name);

      LType := LCtx.GetType(LClass.ClassInfo);
    end
    else
      LClass := LType.AsInstance.MetaclassType;

    for LMethod in LType.GetMethods do
      if (LMethod.IsConstructor) and (Length(LMethod.GetParameters) = 0) then
      begin
        result := LMethod.Invoke(LClass, []).AsObject;
        break;
      end;
  finally
    LCtx.Free;
  end;
end;

procedure TFactory.Register(const AGUID: TGUID; AClass: TClass);
var
  LRec: TRegisteredRec;
  LCtx: TRttiContext;
  i: Integer;
begin
  LCtx := TRttiContext.Create;
  try
    for i := 0 to Length(FRegisteredIntf) - 1 do
      if FRegisteredIntf[i].AGUID = AGUID then
      begin
        FRegisteredIntf[i].AClass := AClass;
        Exit;
      end;

    LRec.AGUID := AGUID;
    LRec.AClass := AClass;

    SetLength(FRegisteredIntf, Length(FRegisteredIntf) + 1);
    FRegisteredIntf[Length(FRegisteredIntf) - 1] := LRec;
  finally
    LCtx.Free;
  end;
end;

{ TORMField }

initialization

Factory := TFactory.Create;

finalization

Factory.Free;

end.
