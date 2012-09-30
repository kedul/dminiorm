unit DminiORM.Core.Factory;

interface

uses Rtti, SysUtils, Generics.Collections;

type

  TAbstractFactory = class
  protected
    function GetInstance(AtypeInfo: pointer): TValue; virtual; abstract;
  public
    procedure Register(const AGUID: TGUID; AClass: TClass); overload; virtual; abstract;
    procedure Register(const AGUID: TGUID; AInstance: IInterface); overload; virtual; abstract;
    function GetClassFor(const AGUID: TGUID): TClass; virtual; abstract;
    function Get(AtypeInfo: pointer): TValue; overload;
    function Get<T>: T; overload;
  end;

Var
  Factory: TAbstractFactory;

implementation

{ TFactory }

function TAbstractFactory.Get(AtypeInfo: pointer): TValue;
begin
  result := GetInstance(AtypeInfo);
end;

function TAbstractFactory.Get<T>: T;
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
      Supports(LIntf, TRttiInterfaceType(LType).GUID, result);
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
    Instance: IInterface;
  end;

  TFactory = class(TAbstractFactory)
  private
    FRegisteredIntf: TDictionary<TGUID, TRegisteredRec>;
    function SearchImplementor(AContext: TRttiContext; AGUID: TGUID): TClass;
    function GetRegisteredRec(AContext: TRttiContext; AGUID: TGUID): TRegisteredRec;
  protected
    function GetInstance(AtypeInfo: pointer): TValue; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Register(const AGUID: TGUID; AClass: TClass); overload; override;
    procedure Register(const AGUID: TGUID; AInstance: IInterface); overload; override;
    function GetClassFor(const AGUID: TGUID): TClass; override;
  end;

constructor TFactory.Create;
begin
  FRegisteredIntf:= TDictionary<TGUID, TRegisteredRec>.Create;
end;

destructor TFactory.Destroy;
begin
  FRegisteredIntf.Free;
  inherited;
end;

function TFactory.GetRegisteredRec(AContext: TRttiContext; AGUID: TGUID): TRegisteredRec;
begin
  if not FRegisteredIntf.TryGetValue(AGUID, Result) then
  begin
    Result.AClass := SearchImplementor(AContext, AGUID);
    Result.Instance := NIL;
    if Result.AClass<>nil then
      FRegisteredIntf.Add(AGUID, Result);
  end;
end;

function TFactory.GetClassFor(const AGUID: TGUID): TClass;
var
  LRec: TRegisteredRec;
  LCtx: TRttiContext;
begin
  LCtx := TRttiContext.Create;
  try
    LRec := GetRegisteredRec(LCtx, AGUID);
    if LRec.AClass<>nil then
      Result := LRec.AClass
    else
      Result := (LRec.Instance as TInterfacedObject).ClassType;
  finally
    LCtx.Free;
  end;
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
      LRec := GetRegisteredRec(LCtx, TRttiInterfaceType(LType).GUID);
      if (LRec.AClass = nil) And (LRec.Instance = NIL) then
        raise Exception.Create('Can''t find a class or instance for interface ' +
              LType.Name);

      if Assigned(LRec.Instance) then
        Exit(TValue.From(LRec.Instance));

      LType := LCtx.GetType(LRec.AClass.ClassInfo);
      LClass := LRec.AClass;
    end
    else
      LClass := LType.AsInstance.MetaclassType;

    for LMethod in LType.GetMethods do
      if (LMethod.IsConstructor) and (Length(LMethod.GetParameters) = 0) then
      begin
        result := LMethod.Invoke(LClass, []);
        break;
      end;
  finally
    LCtx.Free;
  end;
end;

procedure TFactory.Register(const AGUID: TGUID; AInstance: IInterface);
var
  LRec: TRegisteredRec;
begin
  LRec.AClass := NIL;
  LRec.Instance := AInstance;
  FRegisteredIntf.AddOrSetValue(AGUID, LRec);
end;

function TFactory.SearchImplementor(AContext: TRttiContext; AGUID: TGUID): TClass;
var
  LType: TRttiType;
  i: integer;

begin
  result := nil;
  for Ltype in AContext.GetTypes do
    if LType.IsInstance AND (LType.AsInstance.MetaclassType.GetInterfaceTable<>nil) then
      for i:= 0 to LType.AsInstance.MetaclassType.GetInterfaceTable.EntryCount-1 do
        if LType.AsInstance.MetaclassType.GetInterfaceTable.Entries[i].IID = AGUID then
          Exit(LType.AsInstance.MetaclassType);
end;

procedure TFactory.Register(const AGUID: TGUID; AClass: TClass);
var
  LRec: TRegisteredRec;
begin
  LRec.AClass := AClass;
  LRec.Instance := NIL;
  FRegisteredIntf.AddOrSetValue(AGUID, LRec);
end;

initialization
  Factory := TFactory.Create;
finalization
  Factory.free;
end.
