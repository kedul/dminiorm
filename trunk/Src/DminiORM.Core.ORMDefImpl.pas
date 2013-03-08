unit DminiORM.Core.ORMDefImpl;

interface

Uses RTTI, DminiORM.Core, DminiORM.Core.Factory, Generics.Collections,
    Generics.Defaults, TypInfo, SysUtils, Variants, DminiORM.Core.ListIntf,
    DMiniORM.Core.RttiHelpers, DMiniORM.Core.SimpleCollIntf;

function IsORMObject(AObject: TObject): Boolean;
function GetObjectFromValue(const AValue: TValue): TObject;


implementation

Uses Emballo.SynteticClass;

function IsORMObject(AObject: TObject): Boolean;
begin
  result := Copy(AObject.ClassName, Length(AObject.ClassName)-3, 4) ='_ORM'
end;

function GetObjectFromValue(const AValue: TValue): TObject;
begin
  if AValue.TypeInfo.Kind = tkInterface then
    result := TObject(AValue.AsInterface)
  else
    result := AValue.AsObject;
end;

type

  TReaderEOF = reference to function(Data: IDataReader): Boolean;

//  RelationRec = record
//    {
//    LoadDelegate es necesario para que la lista con los objetos se libere de
//    forma automática cuando se pierda la referencia. De otra forma, sería
//    necesario que en el destructor de la clase, se liberara de forma explicita
//    este objeto.
//    }
//    Owner: TObject;
//    DetailColumns: TArray<TRelationShipInfo>;
//    DataReader: IDataReader;
//    Stack: TArray<TObject>;
//    RelationType: TRelationType;
//  end;
//
//  PRelationRec = ^RelationRec;

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
    function FMapManager: IMapManager;
    function FDataManager: IDataManager;
    function FObjectState: IObjectState;
    function GetEntityName(ATypeInfo: PTypeInfo): String;
    procedure ChangeObjectState(AObj: TObject; AState: TObjectState);
    function NewObject(ATypeInfo: PTypeInfo; AOwner: TObject): TObject;
    function InitializeRelation(AObject: TObject;
        ADetailInfo: TRelationDescription): ILoadDelegate;
  protected
    procedure FillObject(AObject: TObject; AMap: IMapDefinition;
      ItemType: TRttiType; Data: IDataReader); virtual;
    function InternalLoad(ATypeInfo: PTypeInfo; Data: IDataReader;
      EOFChecker: TReaderEOF = nil; OnLoad: TORMOnLoadValue = nil): TValue; virtual;
    property RttiContext: TRttiContext read FCtx;
    property DataManager: IDataManager read FDataManager;
    property MapManager: IMapManager read FMapManager;
    property CurrentReader: IDataReader read FCurrentReader;
    property CurrentWriter: IDataWriter read FCurrentWriter;
    constructor Create;
    destructor Destroy; override;
  public
    function Load(ATypeInfo: PTypeInfo; AProvider: String;
      Parameters: TArray<TParameter>; OnLoad: TORMOnLoadValue): TValue; overload;
    function Load(ATypeInfo: PTypeInfo; AKeyValues: Array of TValue;
      OnLoad: TORMOnLoadValue): TValue; overload;
    procedure CancelChanges(AValue: TValue);
    procedure Save(AValue: TValue);
    procedure Delete(AValue: TValue);
    function New(ATypeInfo: PTypeInfo): TValue; overload;
    function New(ATypeInfo: PTypeInfo; AOwner: TValue): TValue; overload;
  end;

  TLoadDelegate = class(TInterfacedObject, ILoadDelegate)
  private
    FObject: TValue;
    FOwnedObject: Boolean;
    FLoaded: Boolean;
    FTypeInfoT: PTypeInfo;
    //FOwner: PRelationRec;
    FOwner: TObject;
    FRelationInfo: TRelationDescription;
    FMasterDesc: TMasterDescription;
    FDataReader: IDataReader;
  public
    procedure SetReturnType(ATypeInfo: PTypeInfo);
    destructor Destroy; override;
    function Get: TValue;
    function GetOwner: TObject;
    procedure Put(const Value: TValue);
    property Owner: TObject read FOwner;
    property RelationInfo: TRelationDescription read FRelationInfo;
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

procedure TORMImpl.ChangeObjectState(AObj: TObject; AState: TObjectState);
var
  LStatusRec: PStateRec;
begin
  if IsORMObject(AObj) then
  begin
    LStatusRec := GetAditionalData(AObj);
    LStatusRec.State := AState;
  end
end;

function TORMImpl.GetEntityName(ATypeInfo: PTypeInfo): String;
var
  LMap: IMapDefinition;
  LCollection : TListInterface;
begin
  LCollection := TListInterface.Get(RttiContext.GetType(ATypeInfo));
  if LCollection = nil then
    LMap := FMapManager.Get(AtypeInfo)
  else
  begin
    LMap := FMapManager.Get(LCollection.ItemType);
    LCollection.List.Free;
    LCollection.Free;
  end;
  result := LMap.GetEntityName;
end;

function TORMImpl.Load(ATypeInfo: PTypeInfo; AProvider: String;
  Parameters: TArray<TParameter>; OnLoad: TORMOnLoadValue): TValue;
var
  LDataReader: IDataReader;
  LSavedCurrentProvider: String;

begin
  LSavedCurrentProvider := FCurrentProvider;
  try
    if AProvider='' then
      AProvider := GetEntityName(ATypeInfo);
    FCurrentProvider := AProvider;
    LDataReader := DataManager.GetReader(AProvider,
      Parameters);

    if LDataReader = nil then
      raise Exception.Create('Can''t find reader ' + AProvider +
        ' for class ' + ATypeInfo.Name);

    result := InternalLoad(ATypeInfo, LDataReader, NIL, OnLoad);
  finally
    FCurrentProvider := LSavedCurrentProvider;
  end;
end;

function TORMImpl.FDataManager: IDataManager;
begin
  result := Factory.Get<IDataManager>;
end;

type
  TRelationRec = Record
    Delegate: ILoadDelegate;
  End;

  PRelationRec = ^TRelationRec;

function TORMImpl.InitializeRelation(AObject: TObject;
      ADetailInfo: TRelationDescription ) : ILoadDelegate;
var
  LRelationValue: TValue;
  LDelegate: TLoadDelegate;
  LMap: IMapDefinition;
  LMasterDesc: TMasterDescription;

begin
  LRelationValue := ADetailInfo.MasterMember.GetValue(AObject);
  RttiContext.GetType(LRelationValue.TypeInfo).GetMethod('Initialize')
    .Invoke(LRelationValue,[]);
  ADetailInfo.MasterMember.SetValue(AObject, LRelationValue);

  Result := PRelationRec(LRelationValue.GetReferenceToRawData).Delegate;

  LDelegate := TLoadDelegate(Result);
  LDelegate.FOwner := AObject;
  LDelegate.FRelationInfo := ADetailInfo;
  LDelegate.FDataReader := NIL;

  if ADetailInfo.RelationType = rtOwner then
    LMap := FMapManager.Get(AObject.ClassInfo)
  else
    LMap := FMapManager.Get(ADetailInfo.DetailClassType);

  for LMasterDesc in LMap.GetMastersInfo do
    if ((LMasterDesc.MasterClassType.Handle = ADetailInfo.DetailClassType.Handle) and
        (ADetailInfo.RelationType = rtOwner)) or
       ((LMasterDesc.MasterClassType.Handle = AObject.ClassInfo) and
        (ADetailInfo.RelationType = rtChild)) then
       begin
         LDelegate.FMasterDesc := LMasterDesc;
         break;
       end;

end;

procedure TORMImpl.FillObject(AObject: TObject; AMap: IMapDefinition;
    ItemType: TRttiType; Data: IDataReader);
var
  LColumnRelation: TClassMemberMap;
  LAccept: Boolean;
  LColumnValue: TValue;
  LRelationValue: TValue;
  LOutParam: Array of TValue;
  LDetailInfo: TRelationDescription;
  LDelegate: TLoadDelegate;
  LInf: IInterface;
  //LStateRec: PStateRec;

  function IsKeyColumn(AClassMember: TRttiMember): boolean;
  var
    LFld: TClassMemberMap;
  begin
    result := false;
    for LFld in AMap.GetKeyInfo do
      if LFld.ClassMember =  AClassMember then
        Exit(True);
  end;

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

    //LStateRec := GetAditionalData(AObject);

    for LColumnRelation in AMap.GetColumnsMapInfo do
    begin
      if not Data.GetRowColumn(LColumnRelation.Column, LColumnValue) then
      begin
        // todo: notificar via log y elimnar del mapa esta relación
        continue;
      end;
      LAccept := false;

      if Assigned(AMap.GetOnMapFieldMethod) then
      begin
        SetLength(LOutParam, 4);
        LOutParam[0] := LColumnRelation.ClassMember.Name;
        LOutParam[1] := LColumnRelation.Column;
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
          raise Exception.CreateFmt('%s.%s column value (%s) is invalid value for %s.%s',
              [ FCurrentProvider,
                LColumnRelation.Column,
                VarToStr(LColumnValue.AsVariant),
                ItemType.Name,
                LColumnRelation.ClassMember.Name]);
        end;

//        if (AMap.GetFieldValues = nil) then //and ((AMap.GetStateMode = smAll) or
//            //((AMap.GetStateMode = smKey) And IsKeyColumn(LColumnRelation.ClassMember))) then
//        begin
//           LStateRec.Data.Put(LColumnRelation.Column, LColumnValue)
//        end;

    end;

   // LStateRec.State := osBrowse;

    for LDetailInfo in AMap.GetDetailsInfo do
    begin
      LDelegate := InitializeRelation(AObject, LDetailInfo) as TLoadDelegate;
      try
        if LDetailInfo.LoadMode in [lmInLoad, lmEmbebed, lmColumn] then
        begin
          if LDetailInfo.LoadMode = lmEmbebed then
            LDelegate.FDataReader := Data
          else
          if LDetailInfo.LoadMode = lmColumn then
          begin
            if not Data.GetRowColumn(LDetailInfo.DataReaderColumn, LRelationValue)
            then
              raise Exception.Create('Can''t find detail column ' +
                                      LDetailInfo.DataReaderColumn);
            LInf := LRelationValue.AsInterface;
            Supports(LInf, IDataReader, LDelegate.FDataReader);
          end;
          LDelegate.Get;
//          RttiContext.GetType(LColumnValue.TypeInfo).GetMethod('Get')
//            .Invoke(LColumnValue, []);
//          LDetailInfo.MasterProperty.SetValue(AObject, LColumnValue);
        end;
      finally
        LDelegate.FDataReader := nil;
      end;
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

//procedure log(text: String);
//var
//  F: TextFile ;
//begin
//  try
//  Assign(F, 'log.txt');
//  Append(F);
//  Writeln(F, DateTimetoStr(now)+': '+ text);
//  CloseFile(F);
//  except
//    raise Exception.Create('Error en log');
//  end;
//end;

function TORMImpl.InternalLoad(ATypeInfo: PTypeInfo; Data: IDataReader;
  EOFChecker: TReaderEOF; OnLoad: TORMOnLoadValue): TValue;
var
  LObj: TObject;
  LCollection: TListInterface;
  LType: TRttiType;
  LMap: IMapDefinition;
  LRecNo: Integer;
  LSavedReader: IDataReader;
  LItemClass: TClass;
  LItemTypeInfo: PTypeInfo;
  LInterface: IInterface;
  Lvalue: TValue;

begin
  LType := RttiContext.GetType(ATypeInfo);

  if LType is TRttiInterfaceType then
    LCollection := TListInterface.Get(
      RttiContext.GetType(Factory.GetClassFor(TRttiInterfaceType(LType).GUID).ClassInfo))
  else
    LCollection := TListInterface.Get(LType);

  if (LCollection = nil) and Data.EOF then
    Exit(TValue.Empty);

  if Data.EOF then // es una colección que se crea y devuelve con 0 elementos
  begin
    result := LCollection.List;
    LCollection.Free;
    exit;
  end;

  LSavedReader := FCurrentReader;
  FCurrentReader := Data;
  try
    if LCollection <> nil then
      LType := LCollection.ItemType; //GetCollectionItemType(LType.Name);

    try
      if LType is TRttiInterfaceType then
      begin
        LItemClass := Factory.GetClassFor(TRttiInterfaceType(LType).GUID);
        if LItemClass = nil then
          raise Exception.Create('Unsupported type '+LType.QualifiedName);
        LItemTypeInfo := LType.Handle; //LItemClass.ClassInfo;
        LMap := FMapManager.Get(RttiContext.GetType(LItemClass.ClassInfo),FCurrentProvider);
      end
      else
        if LType is TRttiInstanceType  then
        begin
          LMap := FMapManager.Get(LType, FCurrentProvider);
          LItemTypeInfo := LType.AsInstance.MetaclassType.ClassInfo;
        end
        else
            raise Exception.Create('Unsupported type '+LType.QualifiedName);

      if Not Assigned(LMap) then
        raise Exception.Create('Can'' create a map info for class ' +
          LType.Name);
      while not Data.EOF and (not Assigned(EOFChecker) or
        (Assigned(EOFChecker) and not EOFChecker(Data))) do
      begin

        if FStack.Count > 0 then
          LObj := NewObject(LItemTypeInfo, FStack.Last)
        else
          LObj := NewObject(LItemTypeInfo, NIL); //Factory.Get(LItemTypeInfo).AsObject;

        LRecNo := Data.RecNo;
        FStack.Add(LObj);
        try

          FillObject(LObj, LMap, LType, Data);

          if Assigned(OnLoad) then
          begin

            if LType is TRttiInterfaceType  then
            begin
              if not LObj.GetInterface(TRttiInterfaceType(Ltype).GUID, LInterface)then
                raise Exception.Create('No interface')  ;

              TValue.MakeWithoutCopy(@Linterface, Ltype.Handle, LValue);
           end
           else
              LValue := LObj;
            try
              OnLoad(LValue);
              if LType is TRttiInterfaceType then
                  Lvalue := NIL;
            except

              if LType is TRttiInterfaceType then
                Lvalue := NIL;
              raise;
            end;
          end;
        finally
          FStack.Delete(FStack.Count - 1);
        end;
        if LCollection = nil then
          if LType is TRttiInterfaceType  then
            begin
              if not LObj.GetInterface(TRttiInterfaceType(Ltype).GUID, LInterface)then
                raise Exception.Create('No interface')  ;
              Tvalue.MakeWithoutCopy(@Linterface, Ltype.Handle, Result);
              LInterface:= NIL;
              Exit;
            end
          else Exit(LObj);

        LCollection.Add(LObj);

        if LRecNo = Data.RecNo then
          Data.Next;
      end;
      result := LCollection.List;
      LCollection.Free;
    except
     on e: exception do begin
      if LCollection <> nil then
      begin
        LCollection.List.Free;
        LCollection.Free;
      end;
      if not (LType is TRttiInterfaceType) then
        LObj.Free;
      raise Exception.Create('Redirigido.'+e.Message);
     end;
    end;
  finally
    FCurrentReader := LSavedReader;
  end;
end;

function TORMImpl.Load(ATypeInfo: PTypeInfo;
  AKeyValues: Array of TValue; OnLoad: TORMOnLoadValue): TValue;
var
  LMap: IMapDefinition;
  LParameters: TArray<TParameter>;
  LKeys: TArray<TClassMemberMap>;
  i: integer;
  LCollection: TListInterface;

begin
  LCollection := TListInterface.Get(RttiContext.GetType(AtypeInfo));
  if LCollection = nil then
    LMap:= FMapManager.Get(ATypeInfo)
  else
    LMap:= FMapManager.Get(LCollection.ItemType);

  if LCollection <> nil then
  begin
    LCollection.List.Free;
    LCollection.Free;
  end;

  LKeys := LMap.GetKeyInfo;
  if Length(LKeys)<> High(AKeyValues)+1 then
    raise Exception.Create('Invalid number of key values.');

  SetLength(LParameters, High(AKeyValues)+1);
  for i := 0 to Length(LKeys)-1 do
  begin
    LParameters[i].Name := LKeys[i].Column;
    LParameters[i].Value := AKeyValues[i];
  end;

  result := Load(ATypeInfo, LMap.GetEntityName, LParameters, OnLoad);
end;

function TORMImpl.NewObject(ATypeInfo: PTypeInfo; AOwner: TObject): TObject;
var
  LType: TRttiType;
  LClass: TClass;
  LSyncteticClass: TSynteticClass;
  LStateRec: PStateRec;
  LMap: IMapDefinition;
  LDetailInfo: TRelationDescription;
  LInterface : IInterface;
  LIsInterfaceType: Boolean;
begin
  result := Factory.Get(ATypeInfo).AsObject;
  exit;
  LType := RttiContext.GetType(ATypeInfo);
  LIsInterfaceType := LType is TRttiInterfaceType ;
  if LIsInterfaceType then
  begin
    LClass := Factory.GetClassFor(TRttiInterfaceType(LType).GUID);
    if LClass = nil then
      raise Exception.Create('Can''t find a implementation for '+LType.QualifiedName);
  end
  else
    if LType is TRttiInstanceType then
      LClass := LType.AsInstance.MetaclassType
    else
      raise Exception.Create('Can''t create a object for type '+LType.QualifiedName);

  LSyncteticClass := TSynteticClass.Create(PTypeInfo(LClass.ClassInfo).Name+'_ORM',
      LClass, SizeOf(TStateRec), NIL, TRUE);

  LSyncteticClass.Finalizer := procedure(const Instance: TObject)
  begin
    TStateRec(GetAditionalData(Instance)^).Data := NIL;
  end;

  result := LSyncteticClass.Metaclass.Create;

  if LIsInterfaceType then
  begin
    Linterface := TInterfacedObject(result);
    LInterface._AddRef;
  end;

  LMap := FMapManager.Get(RttiContext.GetType(LClass.ClassInfo));
  for LDetailInfo in LMap.GetDetailsInfo do
    InitializeRelation(Result, LDetailInfo);

  LStateRec := GetAditionalData(Result);

  LStateRec.State := osNew;
  LStateRec.Owner := AOwner;
  LStateRec.Data :=  TSimpleDictionary<String, TValue>.Create;
end;

function TORMImpl.New(ATypeInfo: PTypeInfo; AOwner: TValue): TValue;
var
  LObj: TObject;
  LType: TRttiType;
  LMap: IMapDefinition;
  LDetailInfo: TRelationDescription;
  LRelation: TValue;
  LDetailRec: PRelationRec;
  LList: TListInterface;
  LOwnerObj: TObject;
  LRelationObj: TObject;

begin
  if AOwner.IsEmpty then
    LObj := NewObject(AtypeInfo, NIL)
  else
  begin
    LOwnerObj := GetObjectFromValue(AOwner);
    LObj := NewObject(ATypeInfo, LOwnerObj);
    LMap := FMapManager.Get(LOwnerObj.ClassInfo);
    if Assigned(LMap) then
      for LDetailInfo in LMap.GetDetailsInfo do
      if (LDetailInfo.DetailClassType.Handle = ATypeInfo) then
      begin
        LRelation := LDetailInfo.MasterMember.GetValue(LOwnerObj);
        LDetailRec := PRelationRec(LRelation.GetReferenceToRawData);

        if TLoadDelegate(LDetailRec.Delegate).FObject.IsEmpty then
        begin
          LDetailRec.Delegate.Put(Result);
        end
        else
        begin
          LRelationObj := GetObjectFromValue(TLoadDelegate(LDetailRec.Delegate).FObject);
  //        LRelationObj := GetObjectFromValue(
  //                          RttiContext.GetType(LRelation.TypeInfo)
  //                            .GetMethod('Get').Invoke(LRelation, []));

          LDetailInfo.MasterMember.SetValue(LOwnerObj, LRelation);
          LList := TListInterface.Get(RttiContext.GetType(LRelationObj.ClassInfo),LRelationObj);
          if LList=nil then
          begin
             LDetailRec.Delegate.Put(Result)
          end
          else
          begin
            LList.Add(LObj);
            LList.Free;
          end;
        end;
      end;
  end;
  result := LObj;
end;

function TORMImpl.New(ATypeInfo: PTypeInfo): TValue;
begin
  result := New(AtypeInfo, NIL);
end;

procedure TORMImpl.CancelChanges(AValue: TValue);
var
  LObj: TObject;
  LStateRec: PStateRec;
  LMap: IMapDefinition;
  LObjStatus: TORMObjectStatus;
  LOrmField: TORMField;
begin
  LObj := GetObjectFromValue(AValue);
  LStateRec := GetAditionalData(LObj);
  if (LStateRec.State = osModified) then
  begin

    LMap := FMapManager.Get(LObj.ClassInfo);
    if LMap = nil then
    raise Exception.CreateFmt('Can''t find a map defintion for %s',
              [LObj.ClassName]);

    LObjStatus := FObjectState.GetFieldValues(LObj);

    for LORMField in LObjStatus.ModifiedFields do
    begin
      LORMField.ObjMember.SetValue(LObj, LORMField.OldValue);
    end;

    LStateRec.State := osBrowse;

  end;
end;

procedure TORMImpl.Save(AValue: TValue);
var
  LMap: IMapDefinition;
  LObj: TObject;
  LWriter: IDataWriter;
  LSaveResult: TArray<TDataRow>;
  LList: TListInterface;
  LRecordList: TList<TORMObjectStatus>;
  LObjList: TList<TObject>;
  LItemType: TRttiType;
  LTranStarter: boolean;
  LIsNew: Boolean;
  i: integer;

//  function GetParamKeys: TArray<TParameter>;
//  var
//    LOrmKeys: TORMFields;
//    i: integer;
//  begin
//    LOrmKeys := LObjStatus.KeyFields;
//    SetLength(Result, Length(LORMKeys));
//    for i:=0 to Length(LORMKeys)-1 do
//      if LORMKeys[i].HasOldValueInfo then
//        Result[i] := LORMKeys[i].Old
//      else
//        Result[i] := LORMKeys[i].New;
//  end;

  procedure SetNewValues(Aobj: TObject; AObjStatus: TORMObjectStatus; NewValues: TDataRow);
  var
    LColumn: TColumn;
    LOrmField: TORMField;
    LStateRec: PStateRec;
  begin
    LStateRec := GetAditionalData(AObj);
    LStateRec.State := osBrowse;
    for LColumn in NewValues do
    begin
      if LStateRec.Data.ContainsKey(LColumn.Name) then
        LStateRec.Data[LColumn.Name] := LColumn.Value;
      for LORMField  in AObjStatus.Fields do
        if SameText(LColumn.Name, LOrmField.ColumnName) then
        begin
          LORMField.ObjMember.SetValue(AObj, LColumn.Value);
          break;
        end;
    end;
  end;

  procedure AppendStatus(AObj: TObject);
  var
    LObjStatus: TORMObjectStatus;
  begin
    LObjStatus := FObjectState.GetFieldValues(AObj);
    if not (LObjStatus.State in [osBrowse, osDeleted]) then
    begin
      if Assigned(LMap.GetBeforeSave) then
        LMap.GetBeforeSave.Invoke(AObj,[LObjStatus.State = osNew]);
      LRecordList.Add(LObjStatus);
      LObjList.Add(AObj);
    end;
  end;

  function GetItemMapDefinition(ItemType: TRttiType): IMapDefinition;
  begin
    result := FMapManager.Get(ItemType);
    if result = nil then
      raise Exception.CreateFmt('Can''t find a map defintion for %s',
                [ItemType.Name]);
  end;

begin
  LObj := GetObjectFromValue(AValue);
  LList := TListInterface.Get(RttiContext.GetType(LObj.ClassInfo), LObj);
  LRecordList := TList<TORMObjectStatus>.Create;
  LObjList := TList<TObject>.Create;
  LTranStarter := FALSE;
  try
    if LList <> nil then begin
      LItemType := LList.ItemType;
      LMap := GetItemMapDefinition(LItemType);
      for LObj in LList do
        AppendStatus(LObj);
    end
    else
    begin
      LItemType := RttiContext.GetType(LObj.ClassInfo);
      LMap := GetItemMapDefinition(LItemType);
      AppendStatus(LObj);
    end;

    try
      if LRecordList.Count > 0 then
      begin

        LWriter := FDataManager.GetWriter(LMap.GetEntityName);
        if LWriter = nil then
          raise Exception.CreateFmt('Can''t find writer for object of class %s',
                    [LItemType.Name]);

//        if not FDataManager.InTransaction then
//        begin
//          FDataManager.BeginTran;
//          LTranStarter := TRUE;
//        end;

        LSaveResult := LWriter.Save(LRecordList.ToArray);
        for i := 0 to LRecordList.Count-1 do
        begin
          if LSaveResult<>nil then
            SetNewValues(LObjList[i], LRecordList[i],LSaveResult[i]);
          LIsNew := LRecordList[i].State = osNew;
          if LRecordList[i].State<>osUnknow then
            ChangeObjectState(LObjList[i], osBrowse);
          if Assigned( LMap.GetAfterSave) then
            LMap.GetAfterSave.Invoke(LObjList[i],[LIsNew])
        end;

//        if LTranStarter And FDataManager.InTransaction then
//          FDataManager.Commit;

      end;
    except
//      if LTranStarter And FDataManager.InTransaction then
//        FDataManager.RollBack;
      raise;
    end;
  finally
    LRecordList.Free;
    LObjList.Free;
    if LList<>nil then begin
      LList.Free;
    end;
  end;
end;

procedure TORMImpl.Delete(AValue: TValue);
var
  LMap: IMapDefinition;
  LObj: TObject;
  LWriter: IDataWriter;
  LDeleteRecs: TArray<TDataRow>;


  function GetParamKeys: TDataRow;
  var
    LKeys: TArray<TClassMemberMap>;
    i: integer;
  begin
    LKeys := LMap.GetKeyInfo;
    SetLength(Result, Length(LKeys));
    for i:=0 to Length(LKeys)-1 do
       Result[i] := TColumn.Create(LKeys[i].Column,LKeys[i].Value(LObj));
  end;

begin
  LObj := GetObjectFromValue(AValue);
  LMap := FMapManager.Get(LObj.ClassInfo);
  LWriter := FDataManager.GetWriter(LMap.GetEntityName);

  if LWriter = nil then
    raise Exception.Create('Can''t find writer for object of class '+
      AValue.TypeInfo.Name);

  SetLength(LDeleteRecs,1);
  LDeleteRecs[0] := GetParamKeys;

  if Assigned(LMap.GetBeforeDelete) then
    LMap.GetBeforeDelete.Invoke(LObj,[]);
  LWriter.Delete(LDeleteRecs);
  ChangeObjectState(LObj, osDeleted);
  if Assigned(LMap.GetAfterDelete) then
    LMap.GetAfterDelete.Invoke(LObj,[]);
end;

{ TLoadDelegated }

procedure TLoadDelegate.SetReturnType(ATypeInfo: PTypeInfo);
begin
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
  i: Integer;
  LIOrm: IORM;
  LORM: TORMImpl;
  LList: TListInterface;
begin

  if not FLoaded then
  begin
    FLoaded := true;
    LIOrm := Factory.Get<IORM>;
    LOrm := TORMImpl(LIOrm);

    FOwnedObject := TRUE;

    if (PStateRec(GetAditionalData(FOwner)).State = osNew) and
      (FRelationInfo.RelationType = rtChild) then
    begin
      LList := TListInterface.Get(LORM.RttiContext.GetType(FTypeInfoT));
      if LList <> nil then
      begin
        FObject := LList.List;
        LList.Free
      end
      else
        FObject := LORM.NewObject(FTypeInfoT, FOwner);
    end
    else
    begin

      for i := LOrm.FStack.Count -1 downto 0 do // LOrm.FStack.Count - 1 do
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
        FLoaded := TRUE;

        SetLength(LDetailParamValues, Length(FMasterDesc.MasterDetailRelationShip));

        for i := 0 to Length(FMasterDesc.MasterDetailRelationShip) - 1 do
        begin
          if FRelationInfo.RelationType = rtChild then
          begin
            LDetailParamValues[i].Name := FMasterDesc.MasterDetailRelationShip[i].DetailColumn;
            LDetailParamValues[i].Value := FMasterDesc
              .MasterDetailRelationShip[i].MasterField.GetValue(FOwner);
          end
          else
          begin
            LDetailParamValues[i].Name := FMasterDesc.MasterDetailRelationShip[i].MasterColumn;
            LDetailParamValues[i].Value := FMasterDesc
              .MasterDetailRelationShip[i].DetailField.GetValue(FOwner);
          end;
        end;

        if Assigned(FDataReader) then
          // modo lmEmbebed
          if (FDataReader = LOrm.FCurrentReader) then
          begin
            FObject := LOrm.InternalLoad(FTypeInfoT, FDataReader,
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
            FObject := LOrm.InternalLoad(FTypeInfoT, FDataReader);
          end
        else
          // modo lmDelayed, lmInLoad
          FObject := LOrm.Load(FTypeInfoT, '', LDetailParamValues, NIL);
      end;
    end;
  end;
  result := FObject;
end;

function TLoadDelegate.GetOwner: TObject;
begin
  result := FOwner;
end;

procedure TLoadDelegate.Put(const Value: TValue);
var
  LStateRec: PStateRec;
  LValueObj: TObject;
  LObject: TObject;
begin
  if (Value.IsEmpty) then
    raise Exception.Create('Can''t assign a empty value to a relation.');
  LValueObj := GetObjectFromValue(Value);
  if IsList(LValueObj) then
      raise Exception.Create('Can''t change a relation list.');

  if FObject.IsEmpty then
  begin
    FObject := Value;
    FOwnedObject := FALSE;//TRUE;
    FLoaded := TRUE;
  end
  else
  begin
    LObject := GetObjectFromValue(FObject);
    if LValueObj = LObject then
      Exit;
    if FOwnedObject then
      if FObject.IsObject then
        LObject.Free
      else FObject := nil;

    FObject := Value;
    FOwnedObject := FALSE; //true;
    FLoaded := true;
  end;
    if IsORMObject(LValueObj) then
      if FRelationInfo.RelationType = rtChild then
      begin
        LStateRec := GetAditionalData(LValueObj);
        LStateRec.Owner :=  FOwner;
      end
      else
      begin
        LStateRec := GetAditionalData(FOwner);
        LStateRec.Owner :=  LValueObj;
      end;
  //end;
end;

initialization
  Factory.Register(IORM, TORMImpl.Create);
  Factory.Register(ILoadDelegate, TLoadDelegate);
end.
