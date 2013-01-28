{ Copyright 2012 - Juan Luis Rozano (jlrozano@gmail.com)

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
unit DminiORM.Core;

interface

Uses RTTI, SysUtils, TypInfo, Variants, DminiORM.Core.ListIntf,
      DminiORM.Core.SimpleCollIntf;

type

  TColumn = record
    Name: String;
    Value: TValue;
    constructor Create(AName: String; AValue: TValue);
  end;

  TParameter = TColumn;

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
    ObjMember: TRttiMember;
    ColumnName: String;
    IsKeyField: Boolean;
    HasOldValueInfo: Boolean;
    OldValue: TValue;
    NewValue: TValue;
    function Modified: Boolean;
    function Old: TColumn;
    function New: TColumn;
  end;

  TORMFields = TArray<TORMField>;

  TObjectState = (osNew, osBrowse, osModified, osDeleted, osUnknow);

  TStateRec = record
    State: TObjectState;
    Owner: TObject;
    Data: ISimpleDictionary<String, TValue>;
  end;

  PStateRec = ^TStateRec;

  TORMObjectStatus = record
    State: TObjectState;
    Fields: TORMFields;
    function ModifiedFields: TORMFields;
    function ModifiedColumns: TDataRow;
    function IsModified: Boolean;
    function KeyFields: TORMFields;
  end;

  IDataWriter = interface
    ['{D10FA8DD-0838-4836-88E0-A9351739CA6C}']
    function Save(Records: TArray<TORMObjectStatus>): TArray<TDataRow>;
    procedure Delete(KeyFields: TArray<TDataRow>);
  end;

  IDataManager = interface
    ['{3C8B01FA-FD35-4B79-8466-1E3B8D660C91}']
    function GetReader(ProviderName: String;
      Parameters: TArray<TParameter>): IDataReader;
    function GetWriter(EntityName: String): IDataWriter;
    function GetColumnNames(EntityName: String): TArray<String>;
    function Execute(FuncName: String; Parameters: Array of TParameter): TValue;
    procedure BeginTran;
    procedure Commit;
    procedure RollBack;
    function InTransaction: Boolean;
  end;

  TCustomMapPrototype = procedure(Data: IDataReader) of Object;

  TOnMapInitailizePrototype = procedure(Row: TDataRow) of Object;

  TOnMapFinalize = procedure of Object;

  TOnMapFieldPrototype = procedure(MemberName, ColumnName: String;
    var Value: TValue; var Accept: Boolean) of Object;

  TClassMemberMap = record
    ClassMember: TRttiMember;
    Column: String;
//    Columns: ISimpleDictionary<String, String>;
    function Value(AObj: TObject): TValue; overload;
//    function Value(DataReader: IDataReader): TValue; overload;
//    function Value(const Provider: String; DataReader: IDataReader): TValue; overload;
  end;

  TRelationLoadMode = (lmDelayed, lmInLoad, lmColumn, lmEmbebed);

  TRelationType = (rtOwner, rtChild);

  TMasterDetailMembers = record
    MasterField: TRttiMember;
    MasterColumn: String;
    DetailField: TRttiMember;
    DetailColumn: String;
  end;

  TMasterDescription = record
    MasterClassType: TRttiType;
    MasterDetailRelationShip: TArray<TMasterDetailMembers>;
  end;

//  TRelationTypeInfo = record
//    LoadMode: TRelationLoadMode;
//    RelationType: TRelationType;
//    DataReaderColumn: String;
//  end;

  TRelationDescription = record
    MasterMember: TRttiMember;
    //RelationTypeInfo: ISimpleDictionary<String, TRelationTypeInfo>;
    LoadMode: TRelationLoadMode;
    RelationType: TRelationType;
    DataReaderColumn: String;
    DetailClassType: TRttiType;
    //MasterDetailRelationShip: TRelationShipInfo;
    //DetailMember: TRttiMember;
  End;

  TStateMode = (smNone, smKey, smAll);

  IMapDefinition = Interface
    ['{252A0310-9E5E-4C10-AA92-969421158AE4}']
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
  End;

  IMapManager = Interface
    ['{5946082A-37E5-4E65-9BA3-0F31E2C88352}']
    function Get(AType: TRttiType): IMapDefinition; overload;
    function Get(AType: PTypeInfo): IMapDefinition; overload;
    function Get(AType: TRttiType; AProvider: String): IMapDefinition; overload;
    function Get(AType: PTypeInfo; AProvider: String): IMapDefinition; overload;
  End;

  IObjectState = Interface
    ['{B57791BF-381F-4177-9FCF-580FB1F8E764}']
    function GetFieldValues(AObject: TObject): TORMObjectStatus;
    function GetOwner(AObject: TObject): TObject;
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

  ILoadDelegate = Interface
    ['{D9DB705C-DB5D-433A-901D-88E9EF631CEF}']
    function GetOwner: TObject;
    procedure Put(const Value: TValue);
    function Get: TValue;
    procedure SetReturnType(AReturnTypeInfo: PTypeInfo);
  End;

  Relation<T> = record
  private
    //Rec: RelationRec;
    Delegate: ILoadDelegate;
  public
    procedure Initialize;
    function GetTypeInfo: PTypeInfo;
    function Get: T;
    procedure Put(const Value: T);
    function New<V>: V; overload;
    function New: T; overload;
    class operator Implicit(const Value: Relation<T>): T;
    //class operator Implicit(const Value: T): Relation<T>;
  end;

  TORMOnLoadValue = reference to procedure(const AValue: TValue);

  IORM = Interface
    ['{6CC8D453-528B-407D-BE65-D1D8FD4A71ED}']
    function Load(ATypeInfo: PTypeInfo; AProvider: String;
      Parameters: TArray<TParameter>; OnLoad: TORMOnLoadValue): TValue; overload;
    function Load(ATypeInfo: PTypeInfo; AKeyValues: Array of TValue;
      OnLoad: TORMOnLoadValue): TValue; overload;
    procedure Save(AValue: TValue);
    procedure CancelChanges(AValue: TValue);
    procedure Delete(AValue: TValue);
    function New(ATypeInfo: PTypeInfo): TValue; overload;
    function New(ATypeInfo: PTypeInfo; AOwner: TValue): TValue; overload;
  End;

  TORMProcessValue<T> = reference to procedure (const Value: T);

  TORM = class
    class function Load<T>(AProviderName: String; AParameters: Array of TParameter;
        ALoadProc: TORMOnLoadValue = nil): T; overload;
    class function Load<T>(AParameters: Array of TParameter;
        ALoadProc: TORMOnLoadValue = nil): T; overload;
    class function Load<T>(AKeyValues: Array of TValue;
        ALoadProc: TORMOnLoadValue = nil): T; overload;
    class procedure Save(Value: TObject); overload;
    class procedure Save(Value: IInterface); overload;
    class procedure Delete(Value: TObject); overload;
    class procedure Delete(Value: IInterface); overload;
    class function GetOwner<T>(Value: TObject): T;
    class function New<T>: T; overload;
    class function New<T>(AOwner: TObject): T; overload;
//    class function New<T>(AOwner: IInterface): T; overload;
    class function ObjectState(AObject: TObject; out ObjStatus: TORMObjectStatus): boolean;
    class procedure ForEach<T>(AProcessProc: TORMProcessValue<T>;
        AParameters: Array of TParameter; FreeObjects: Boolean = TRUE; AProviderName: String ='' );
    class function Exec(FuncName: String; Parameters: Array of TParameter): TValue;
    class procedure CancelChanges(Value: TObject); overload;
    class procedure CancelChanges(Value: IInterface); overload;
  end;

  TForEachList<T> = class
  public
    procedure Add(const AValue: T); virtual;
    function GetEnumerator: TObject;
  end;

  TForEachListFreeObject<T> = class (TForEachList<T>)
  public
    procedure Add(const AValue: T); override;
  end;



implementation

uses DminiORM.Core.Factory;


function TORMField.Modified: Boolean;

begin
  if not HasOldValueInfo then
    result := TRUE
  else
    result := not SameText(VarToStr(OldValue.AsVariant), VarToStr(NewValue.AsVariant))
end;

function TORMField.New: TColumn;
begin
  result.Name := ColumnName;
  result.Value := NewValue;
end;

function TORMField.Old: TColumn;
begin
  if not HasOldValueInfo then
  begin
    result.Name := '';
    result.Value := NIL;
  end
  else begin
    result.Name := ColumnName;
    result.Value := NewValue;
  end;
end;

function TClassMemberMap.Value(AObj: TObject): TValue;
begin
  if ClassMember is TRttiField then
    result := TRttiField(ClassMember).GetValue(AObj)
  else
    result := TRttiProperty(ClassMember).GetValue(AObj)
end;


//function TClassMemberMap.Value(DataReader: IDataReader): TValue;
//begin
//  result := Value('',DataReader);
//end;

//function TClassMemberMap.Value(const Provider: String;
//  DataReader: IDataReader): TValue;
//var
//  LColumnName: String;
//begin
//  LColumnName := Columns.Get(UpperCase(Provider));
//  if not DataReader.GetRowColumn(LColumnName, Result) then
//    raise Exception.CreateFmt('Can''t find column %s in provider %s',
//        [LColumnName, Provider]);
//end;


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

function TORMObjectStatus.ModifiedColumns: TDataRow;
var
  i: Integer;
  LIndex: Integer;
begin
  SetLength(result, Length(Fields));
  LIndex := 0;

  for i := 0 to Length(Fields) - 1 do
    if Fields[i].Modified then
    begin
      result[LIndex].Create(Fields[i].ColumnName, Fields[i].NewValue);
      inc(LIndex);
    end;

  SetLength(result, LIndex);
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


{ Relation<T> }

class operator Relation<T>.Implicit(const Value: Relation<T>): T;
begin
  result := Value.Get;
end;

function Relation<T>.New: T;
var
  LList: TListInterface;
  LCtx:TRttiContext;
begin
  LList := TListInterface.Get(LCtx.GetType(TypeInfo(T)));
  if Assigned(LLIst) then
  begin
    LList.List.Free;
    LList.Free;
    result := Get;
  end
  else
  begin
    if not Assigned(Delegate) then
       Initialize;
    result := TORM.New<T>(Delegate.GetOwner);
    Delegate.Put(TValue.From<T>(result));
  end;
end;

function Relation<T>.New<V>: V;
var
  LValue: TValue;
begin
  if TypeInfo(V)=TypeInfo(T) then
  begin
     LValue := TValue.From<T>(New);
     Exit (LValue.AsType<V>);
  end;
  if IsList(TypeInfo(T))then begin
    if not Assigned(Delegate) then
       Initialize;
    result := TORM.New<V>(Delegate.GetOwner)
  end
  else
    raise Exception.Create('Invalid typecast');
end;

procedure Relation<T>.Put(const Value: T);
begin
  Delegate.Put(TValue.From<T>(Value));
end;

function Relation<T>.Get: T;
var
  LVal : TValue;
  p:IInterface;
  Ctx: TRttiContext;
  LType: TRttiType;
begin
  if not Assigned(Delegate) then
    Initialize;
  LVal := Delegate.Get;
  LType := Ctx.GetType(TypeInfo(T));
  if LType is TRttiInterfaceType then
  begin
    p:= Lval.AsInterface;
    p.QueryInterface(TrttiInterfaceType(LType).GUID, result);
    p._AddRef;
  end
  else
    result := LVal.AsType<T>;
  //LVal.ExtractRawData(@result);
  //result := T(Lval.AsInterface);
//  if LVal.TypeInfo.Kind = tkInterface  then
//    result := T(LVal.AsInterface)
//  else
   // result := T(LVal.AsObject);
  //result := LVal.AsType<T>
  // Check result := LVal.AsType<T>
//  if LVal.IsObject then
//    result := T(Lval.AsObject)
end;

function Relation<T>.GetTypeInfo: PTypeInfo;
begin
  result := TypeInfo(T);
end;

//class operator Relation<T>.Implicit(const Value: T): Relation<T>;
//begin
//  result.Initialize;
//  result.Delegate.Put(T);
//end;

procedure Relation<T>.Initialize;
begin
  if not Assigned(Delegate) then
  begin
    Delegate := Factory.Get<ILoadDelegate>;
    Delegate.SetReturnType(TypeInfo(T));
  end;
end;

{ TColumn }

constructor TColumn.Create(AName: String; AValue: TValue);
begin
  Name := AName;
  Value := AValue;
end;

{ TORM }

class procedure TORM.Delete(Value: TObject);
var
  LOrm: IORM;

begin
  LOrm := Factory.Get<IOrm>;
  LOrm.Delete(Value);
end;

class procedure TORM.Delete(Value: IInterface);

begin
  TORM.Delete(Value As TObject);
end;


class function TORM.Exec(FuncName: String;
  Parameters: array of TParameter): TValue;
var
  LDataManager: IDataManager;
begin
  LDataManager := Factory.Get<IDataManager>;
  result := LDataManager.Execute(FuncName, Parameters);
end;

class function TORM.Load<T>(AProviderName: String;
  AParameters: Array Of TParameter; ALoadProc: TORMOnLoadValue): T;
var
  LOrm: IORM;
  V:TValue;
  LParams: TArray<TParameter>;
  i: integer;
begin
  LOrm := Factory.Get<IOrm>;
  SetLength(LParams,High(AParameters)+1);
  for i:= 0 to High(AParameters) do
    LParams[i] := AParameters[i];
  V:= LOrm.Load(TypeInfo(T),AProviderName,LParams,ALoadProc);
  result := V.AsType<T>; //.Load(TypeInfo(T),AProviderName,AParameters,ALoadProc).AsType<T>
end;


class function TORM.Load<T>(AKeyValues: Array of TValue;
  ALoadProc: TORMOnLoadValue): T;
var
  LOrm: IORM;
begin
  LOrm := Factory.Get<IOrm>;
  result := LOrm.Load(TypeInfo(T),AKeyValues, ALoadProc).AsType<T>
end;


class function TORM.Load<T>(AParameters: Array of TParameter;
  ALoadProc: TORMOnLoadValue): T;
var LParams: TArray<TParameter>;
    i: integer;
begin
  SetLength(LParams,High(AParameters)+1);
  for i:= 0 to High(AParameters) do
    LParams[i] := AParameters[i];

  result := TORM.Load<T>('',LParams, ALoadProc);
end;


class function TORM.New<T>(AOwner: TObject): T;
var
  LOrm : IORM;
  LCtx: TRttiContext;
  LObj: TValue;
  LType: TRttiType;
begin
  LOrm := Factory.Get<IOrm>;
  LObj := LOrm.New(TypeInfo(T), AOwner);
  result := Lobj.AsType<T>;
end;

class function TORM.New<T>: T;
begin
  result := New<T>(NIL);
end;


class function TORM.ObjectState(AObject: TObject; out ObjStatus: TORMObjectStatus): boolean;
var
  LIObjState: IObjectState;

begin
  LIObjState := Factory.Get<IObjectState>;
  if LIObjState = nil then exit(false);

  ObjStatus := LIobjState.GetFieldValues(AObject);
  result := TRUE;
end;


class procedure TORM.Save(Value: TObject);
var
  LOrm: IORM;
begin
  LOrm := Factory.Get<IOrm>;
  LOrm.Save(Value);
end;

class procedure TORM.Save(Value: IInterface);
begin
  TOrm.Save(Value as TObject);
end;

class procedure TORM.CancelChanges(Value: TObject);
var
  LOrm: IORM;
begin
  LOrm := Factory.Get<IOrm>;
  LOrm.CancelChanges(Value);
end;

class procedure TORM.CancelChanges(Value: IInterface);
begin
  TORM.CancelChanges(Value as TObject);
end;


class function TORM.GetOwner<T>(Value: TObject): T;
var
  LObjState: IObjectState;
  LOwnerVal : TValue;
begin
  LObjState := Factory.Get<IObjectState>;
  LOwnerVal := LObjState.GetOwner(Value);
  result := LOwnerVal.AsType<T>;
end;

class procedure TORM.ForEach<T>(AProcessProc: TORMProcessValue<T>;
        AParameters: Array of TParameter; FreeObjects: Boolean; AProviderName: String);
var
  LList: TForEachList<T>;
  LListFree: TForEachListFreeObject<T>;
  LParams: TArray<TParameter>;
  i: integer;
begin
  if Not Assigned(AProcessProc) then
    Exit;

  SetLength(LParams,High(AParameters)+1);
  for i:= 0 to High(AParameters) do
    LParams[i] := AParameters[i];
  if not FreeObjects then
  begin
    LList := TORM.Load<TForEachList<T>>(AProviderName, LParams,
        procedure (const AValue: TValue)
        begin
          AProcessProc(AValue.AsType<T>);
        end);
    LList.Free;
  end
  else
  begin
    LListFree := TORM.Load<TForEachListFreeObject<T>>(AProviderName, LParams,
        procedure (const AValue: TValue)
        begin
          AProcessProc(AValue.AsType<T>);
        end);
    LListFree.Free;
  end;
end;


{ TForEachList<T> }

procedure TForEachList<T>.Add(const AValue: T);
begin
end;


function TForEachList<T>.GetEnumerator: TObject;
begin
  result := nil;
end;

{ TForEachListFreeObject<T> }

procedure TForEachListFreeObject<T>.Add(const AValue: T);
begin
     if PTypeInfo(TypeInfo(T)).Kind = tkClass then
     TObject(Pointer(@AValue)^).Free;
end;


end.


