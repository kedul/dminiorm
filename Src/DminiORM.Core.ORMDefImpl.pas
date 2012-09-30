unit DminiORM.Core.ORMDefImpl;

interface

Uses RTTI, DminiORM.Core, DminiORM.Core.Factory, Generics.Collections, TypInfo,
  SysUtils, Variants;

implementation

type

  TReaderEOF = reference to function(Data: IDataReader): Boolean;

  TORMImpl = class (TInterfacedObject, IORM)
  private
    FCtx: TRttiContext;
//    FMapManager: IMapManager;
//    FDataManager: IDataManager;
//    FObjectState: IObjectState;
    FCurrentReader: IDataReader;
    FCurrentWriter: IDataWriter;
    FCurrentProvider: String;
    FStack: TList<TObject>;
    function GetAddMethod(AType: TRttiType; out ItemType: TRttiType): TRttiMethod;
    function FMapManager: IMapManager;
    function FDataManager: IDataManager;
    function FObjectState: IObjectState;
  protected
//    function GetCollectionItemType(ClassName: String): TRttiType; overload;
//    function GetCollectionItemType(ATypeInfo: pointer): TRttiType; overload;
    procedure FillObject(AObject: TObject; AMap: IMapDefinition;
      ItemType: TRttiType; Data: IDataReader); virtual;
    function InternalLoad(ATypeInfo: PTypeInfo; Data: IDataReader;
      EOFChecker: TReaderEOF = nil): TValue; virtual;
    property RttiContext: TRttiContext read FCtx;
    property DataManager: IDataManager read FDataManager;
    property MapManager: IMapManager read FMapManager;
    property CurrentReader: IDataReader read FCurrentReader;
    property CurrentWriter: IDataWriter read FCurrentWriter;
    constructor Create;
    destructor Destroy; override;
  public
    function Load(ATypeInfo: PTypeInfo; AProvider: String;
      Parameters: TArray<TParameter>): TValue; overload;
    function Load(ATypeInfo: PTypeInfo; AKeyValues: Array of const): TValue; overload;
    procedure Save(AValue: TValue);
    procedure Delete(AValue: TValue);
    function AsObject: TInterfacedObject;
  end;

  TLoadDelegate = class(TInterfacedObject, ILoadDelegate)
  private
    FObject: TValue;
    FOwnedObject: Boolean;
    FLoaded: Boolean;
    FTypeInfoT: PTypeInfo;
    FOwner: PRelationRec;
  public
    procedure SetRelation(AOwner: Pointer; ATypeInfo: PTypeInfo);
    destructor Destroy; override;
    function Get: TValue;
    procedure Put(const Value: TValue);
    function AsObject: TInterfacedObject;
  end;

{ TORMImpl }

constructor TORMImpl.Create;
begin
  FCtx := TRttiContext.Create;
  FStack := TList<TObject>.Create;
end;

destructor TORMImpl.Destroy;
begin
  FCtx.Free;
  FStack.Free;
  inherited;
end;

function TORMImpl.GetAddMethod(AType: TRttiType; out ItemType: TRttiType): TRttiMethod;
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
        ItemType := LMtd.GetParameters[0].ParamType;
        Exit(LMtd);
      end;
    end;
  result := nil;
end;

//function TORMImpl.GetCollectionItemType(ATypeInfo: pointer): TRttiType;
//begin
//  result := GetCollectionItemType(RttiContext.GetType(ATypeInfo).Name);
//end;

function TORMImpl.AsObject: TInterfacedObject;
begin
  result := Self;
end;
//
//function TORMImpl.GetCollectionItemType(ClassName: String): TRttiType;
//var
//  LInx1, LInx2: Integer;
//begin
//  LInx1 := pos('<', ClassName) + 1;
//  LInx2 := pos('>', ClassName) - 1;
//  ClassName := Copy(ClassName, LInx1, LInx2 - LInx1 + 1);
//  result := RttiContext.FindType(ClassName);
//  if result = nil then
//    raise Exception.Create('Can''t find type ' + ClassName);
//end;


function TORMImpl.Load(ATypeInfo: PTypeInfo; AProvider: String;
  Parameters: TArray<TParameter>): TValue;
var
  LDataReader: IDataReader;
  LSavedCurrentProvider: String;
begin
  LSavedCurrentProvider := FCurrentProvider;
  try
    FCurrentProvider := AProvider;
    LDataReader := DataManager.GetReader(ATypeInfo.Name, AProvider,
      Parameters);

    if LDataReader = nil then
      raise Exception.Create('Can''t find reader ' + AProvider +
        ' for class ' + ATypeInfo.Name);

    result := InternalLoad(ATypeInfo, LDataReader);
  finally
    FCurrentProvider := LSavedCurrentProvider;
  end;
end;

function TORMImpl.FDataManager: IDataManager;
begin
  result := Factory.Get<IDataManager>;
end;

procedure TORMImpl.FillObject(AObject: TObject; AMap: IMapDefinition;
    ItemType: TRttiType; Data: IDataReader);
var
  LColumnRelation: TColumnClassRelation;
  LAccept: Boolean;
  LColumnValue: TValue;
  LRelationValue: TValue;
  LOutParam: Array of TValue;
  LDetailInfo: TRelationDescription;
  LDetailRec: PRelationRec;
  LInf: IInterface;
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
      LAccept := false;

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
            TRttiField(LColumnRelation.ClassMember).SetValue(Aobject,
              LColumnValue)
          else
            TRttiProperty(LColumnRelation.ClassMember)
              .SetValue(AObject, LColumnValue);
        except
          raise Exception.Create(VarToStr(LColumnValue.AsVariant) +
            ' is not a valid value for ' + LColumnRelation.ClassMember.Name);
        end;
    end;

    for LDetailInfo in AMap.GetDetailsInfo do
    begin
      LColumnValue := LDetailInfo.MasterProperty.GetValue(AObject);
      LDetailRec := PRelationRec(LColumnValue.GetReferenceToRawData);

      LDetailRec.Owner := AObject;
      //LDetailRec.Orm := self;
      LDetailRec.DetailColumns := LDetailInfo.MasterDetailRelationShip;
      LDetailRec.DataReader := nil;

      if LDetailInfo.LoadMode in [lmInLoad, lmEmbebed, lmColumn] then
      begin
        if LDetailInfo.LoadMode = lmEmbebed then
          LDetailRec.DataReader := Data
        else if LDetailInfo.LoadMode = lmColumn then
        begin
          if not Data.GetRowColumn(LDetailInfo.DateReaderColumn, LRelationValue)
          then
            raise Exception.Create('Can''t find delail column ' +
              LDetailInfo.DateReaderColumn);
          LInf := LRelationValue.AsInterface;
          Supports(LInf, IDataReader, LDetailRec.DataReader);
        end;
        RttiContext.GetType(LColumnValue.TypeInfo).GetMethod('Get')
          .Invoke(LColumnValue, []);
        if LDetailInfo.LoadMode = lmColumn then
          LDetailRec.DataReader := nil;
      end;

      LDetailInfo.MasterProperty.SetValue(AObject, LColumnValue);
    end;

    if Assigned(AMap.GetOnMapFinalizeMethod) then
      AMap.GetOnMapInitializeMethod.Invoke(AObject, []);
  end;
end;

function TORMImpl.FMapManager: IMapManager;
begin
  result:= Factory.Get<IMapManager>;
end;

function TORMImpl.FObjectState: IObjectState;
begin
  result := Factory.Get<IObjectState>;
end;

function TORMImpl.InternalLoad(ATypeInfo: PTypeInfo; Data: IDataReader;
EOFChecker: TReaderEOF): TValue;
var
  LObj: TObject;
  LCollection: TValue;
  LType, LItemType: TRttiType;
  LAddMthd: TRttiMethod;
  LMap: IMapDefinition;
  LRecNo: Integer;
  LSavedReader: IDataReader;
  LItemClass: TClass;

begin
  LType := RttiContext.GetType(ATypeInfo);

  LAddMthd := GetAddMethod(LType, LItemType);
  if (LAddMthd = nil) and Data.EOF then
    Exit(TValue.Empty);

  if Data.EOF then // es una colección que se crea y devuelve con 0 elementos
    Exit(Factory.Get(ATypeInfo));

  LSavedReader := FCurrentReader;
  FCurrentReader := Data;
  try
    if LAddMthd <> nil then
    begin
      LType := LItemType; //GetCollectionItemType(LType.Name);
      LCollection := Factory.Get(ATypeInfo); //.AsObject;
    end
    else
      LCollection := nil;
    try
      LMap := FMapManager.Get(LType, FCurrentProvider);
      if Not Assigned(LMap) then
        raise Exception.Create('Can'' create a map info for class ' +
          LType.Name);

      while not Data.EOF and (not Assigned(EOFChecker) or
        (Assigned(EOFChecker) and not EOFChecker(Data))) do
      begin
        if LType is TRttiInterfaceType then
        begin
          LItemClass := Factory.GetClassFor(TRttiInterfaceType(LType).GUID);
          if LItemClass = nil then
             raise Exception.Create('Unsupported type '+LType.QualifiedName);
          LObj := Factory.Get(LItemClass.ClassInfo).AsObject;
        end
        else
          if LType is TRttiInstanceType  then
            LObj := Factory.Get(LType.AsInstance.MetaclassType.ClassInfo).AsObject
          else
            raise Exception.Create('Unsupported type '+LType.QualifiedName);
        // .AsObject;

        LRecNo := Data.RecNo;
        FStack.Add(LObj);
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
      if not LCollection.IsEmpty and LCollection.IsObject then
        LCollection.AsObject.Free;
      LObj.Free;
      raise;
    end;
  finally
    FCurrentReader := LSavedReader;
  end;
end;

function TORMImpl.Load(ATypeInfo: PTypeInfo;
  AKeyValues: array of const): TValue;
begin

end;

//procedure TORMImpl.Save(AObject: TObject; Dest: IDataWriter);
//var
//  LRecs: TArray<TORMObjectStatus>;
//  LRec: TORMObjectStatus;
//begin
//  FCurrentWriter := Dest;
//  try
//    LRec := FObjectState.GetFieldValues(AObject,
//      FMapManager.Get(RttiContext.GetType(AObject.ClassInfo)));
//
//    if not LRec.IsModified then
//      Exit;
//
//    SetLength(LRecs, 1);
//    LRecs[0] := LRec;
//    Dest.Save(LRecs);
//  finally
//    FCurrentWriter := nil;
//  end;
//  // Todo: grabar los datos detalle
//end;
//
//procedure TORMImpl.Save(AObject: TObject);
//var
//  DataWriter: IDataWriter;
//begin
//  DataWriter := DataManager.GetWriter(AObject.QualifiedClassName);
//  if DataWriter = nil then
//    raise Exception.Create('Can''t find a writer for class ' +
//      AObject.QualifiedClassName);
//  Save(AObject, DataWriter);
//end;

//procedure TORMImpl.Delete(AObject: TObject; Dest: IDataWriter);
//var
//  LRecs: TArray<TORMObjectStatus>;
//  LRec: TORMObjectStatus;
//
//begin
  // FCurrentWriter := Dest;
  // try
  // LRec := FObjectState.GetFieldValues(AObject, FMapManager.Get(
  // RttiContext.GetType(AObject.ClassInfo)));
  //
  // SetLength(LRecs, 1);
  // LRecs[0] := LRec.KeyFields;
  // Dest.Delete(LRecs);
  // finally
  // FCurrentWriter := nil;
  // end;
//end;
//
//procedure TORMImpl.Delete(AObject: TObject);
//var
//  LDataWriter: IDataWriter;
//begin
//  LDataWriter := DataManager.GetWriter(AObject.QualifiedClassName);
//  if LDataWriter = nil then
//    raise Exception.Create('Can''t find a writer for class ' +
//      AObject.QualifiedClassName);
//  Delete(AObject, LDataWriter);
//end;


procedure TORMImpl.Save(AValue: TValue);
begin

end;

procedure TORMImpl.Delete(AValue: TValue);
begin

end;

{ TLoadDelegated }

function TLoadDelegate.AsObject: TInterfacedObject;
begin
  result := self;
end;


procedure TLoadDelegate.SetRelation(AOwner: Pointer; ATypeInfo: PTypeInfo);
begin
  FOwner := PRelationRec(AOwner);
  FTypeInfoT := ATypeInfo;
end;

destructor TLoadDelegate.Destroy;
begin
  if Not FObject.IsEmpty And (FOwnedObject) And (FObject.IsObject) then
    FObject.AsObject.Free;
  inherited;
end;

function TLoadDelegate.Get: TValue;
var
  LDetailParamValues: TArray<TParameter>;
  LProp: TRttiProperty;
  LField: TRttiField;
  i: Integer;
  LIOrm: IORM;
  LORM: TORMImpl;
begin

  if not FLoaded then
  begin
    FLoaded := true;
    LIOrm := Factory.Get<IORM>;
    LOrm := TORMImpl(LIOrm.AsObject);

    for i := 0 to LOrm.FStack.Count - 1 do
    begin
      if FTypeInfoT = LOrm.FStack[i].ClassInfo then
      begin
        FObject := LOrm.FStack[i];
        FOwnedObject := false;
        break;
      end;
    end;

    if FObject.IsEmpty then
    begin
      FOwnedObject := TRUE;
      FLoaded := TRUE;
      SetLength(LDetailParamValues, Length(FOwner.DetailColumns));

      for i := 0 to Length(FOwner.DetailColumns) - 1 do
      begin
        LDetailParamValues[i].Name := FOwner.DetailColumns[i].DetailField;
        LProp := LOrm.RttiContext.GetType(FOwner.Owner.ClassInfo)
          .GetProperty(FOwner.DetailColumns[i].MasterField);
        if LProp <> nil then
        begin
          LDetailParamValues[i].Value := LProp.GetValue(FOwner.Owner);
        end
        else
        begin
          LField := LOrm.RttiContext.GetType(FOwner.Owner.ClassInfo)
            .GetField(FOwner.DetailColumns[i].MasterField);
          if LField = nil then
            raise Exception.Create('Can''t find master field ' +
              FOwner.DetailColumns[i].MasterField);
          LDetailParamValues[i].Value := LField.GetValue(FOwner.Owner);
        end
      end;

      if Assigned(FOwner.DataReader) then
        // modo lmEmbebed
        if (FOwner.DataReader = LOrm.FCurrentReader) then
        begin
          FObject := LOrm.InternalLoad(FTypeInfoT, FOwner.DataReader,
            function(Data: IDataReader): Boolean
            var
              LParam: TParameter;
              LColumnValue: TValue;
            begin
              result := false;
              for LParam in LDetailParamValues do
              begin
                if not Data.GetRowColumn(LParam.Name, LColumnValue) then
                  Exit(true);
                if not VarSameValue(LColumnValue.AsVariant,
                  LParam.Value.AsVariant) then
                  Exit(true);
              end;
            end);
        end
        else
        // modo lmColumn
        begin
          FObject := LOrm.InternalLoad(FTypeInfoT, FOwner.DataReader);
        end
      else
        // modo lmDelayed, lmInLoad
        FObject := LOrm.Load(FTypeInfoT, '', LDetailParamValues);
    end;
  end;
  result := FObject;
end;

procedure TLoadDelegate.Put(const Value: TValue);
begin
  if Value.AsObject <> FObject.AsObject then
  begin
    if not FObject.IsEmpty And FOwnedObject then
      FObject.AsObject.Free;
    FObject := Value;
    FOwnedObject := false;
    FLoaded := true;
  end;
end;

initialization
  Factory.Register(IORM, TORMImpl.Create);
  Factory.Register(ILoadDelegate, TLoadDelegate);
end.
