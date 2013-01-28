unit DminiORM.Core.RttiHelpers;

interface

Uses Rtti, SysUtils;

type

  TAttrRecord<T: TCustomAttribute> = record
    Attribute: T;
    Member: TRttiMember;
  end;

  TForEachAttributeOfType<T: TCustomAttribute> = reference to procedure
    (Attribute: T);

  TForEachTypeAttributeOfType<T: TCustomAttribute> = reference to procedure
    (Attribute: T; Member: TRttiMember);

  TAttributeFilter<T: TCustomAttribute> = reference to function
    (Attributte: T): boolean;

  TRttiMemberHelper = class helper for TRttiObject
  public
    function GetAttributesOfType<T: TCustomAttribute>: TArray<T>; overload;
    function GetAttributeOfType<T: TCustomAttribute>: T; overload;
    function GetAttributesOfType<T: TCustomAttribute>(Filter: TAttributeFilter<T>): TArray<T>; overload;
    function GetAttributeOfType<T: TCustomAttribute>(Filter: TAttributeFilter<T>): T; overload;
    procedure ForEachAttributeOfType<T: TCustomAttribute>
      (Proc: TForEachAttributeOfType<T>); overload;
    procedure ForEachAttributeOfType<T: TCustomAttribute>
      (Proc: TForEachAttributeOfType<T>; Filter: TAttributeFilter<T>); overload;

    function GetValue(Instance: Pointer): TValue;
    procedure SetValue(Instance: Pointer; const AValue: TValue);
  end;

  TRttiTypeHelper = class helper for TRttiType
  public
    function GetMemberAttributesOfType<T: TCustomAttribute>: TArray<TAttrRecord<T>>; overload;
    function GetMemberAttributesOfType<T: TCustomAttribute>(Filter: TAttributeFilter<T>): TArray<TAttrRecord<T>>; overload;
    procedure ForEachMemberAttributeOfType<T: TCustomAttribute>
      (Proc: TForEachTypeAttributeOfType<T>); overload;
    procedure ForEachMemberAttributeOfType<T: TCustomAttribute>
      (Proc: TForEachTypeAttributeOfType<T>; Filter: TAttributeFilter<T>); overload;
  end;

  TIIF = class
      class function Eval<T>(const Expression: Boolean;
        TrueValue: T; FalseValue: T): T;
    end;

function GetFieldOrProperty(ATypeInfo: Pointer; const Name: String): TRttiMember;
function GetMemberValue(AObject: TObject; const Name: String): TValue;
procedure SetMemberValue(AObject: TObject; const Name: String; const Value: TValue);

implementation

function GetFieldOrProperty(ATypeInfo: Pointer; const Name: String): TRttiMember;
var
  LCtx: TRttiContext;
  LType: TRttiType;
begin
  LType := LCtx.GetType(ATypeInfo);
  result := LType.GetField(Name);
  if not Assigned(Result) then
    result := LType.GetProperty(Name);
  if not Assigned(result) then
    raise Exception.CreateFmt('Can''t find a member with name %s into class %s ',
        [Name, LType.Name]);
end;

function GetMemberValue(AObject: TObject; const Name: String): TValue;
var
  LIndex: integer;
  c: char;
begin
  LIndex := 0;
  for c in Name do
    if c<>'.' then inc(LIndex)
    else break;
  if LIndex=0 then
    raise Exception.Create('Invalid member name');
  if LIndex= length(Name) then
    result := GetFieldOrProperty(AObject.ClassInfo, Name).GetValue(AObject)
  else
    result := GetMemberValue(GetFieldOrProperty(AObject.ClassInfo,
                                Copy(Name,1,LIndex)).GetValue(AObject).AsObject,
                Copy(Name, LIndex +2, Length(Name)));
end;

procedure SetMemberValue(AObject: TObject; const Name: String; const Value: TValue);
var
  LIndex: integer;
  c: char;
begin
  LIndex := 0;
  for c in Name do
    if c<>'.' then inc(LIndex)
    else break;
  if LIndex=0 then
    raise Exception.Create('Invalid member name');
  if LIndex= length(Name) then
    GetFieldOrProperty(AObject.ClassInfo, Name).SetValue(AObject, Value)
  else
    SetMemberValue(GetFieldOrProperty(AObject.ClassInfo,
                                Copy(Name,1,LIndex)).GetValue(AObject).AsObject,
                Copy(Name, LIndex +2, Length(Name)), Value);
end;

{ TRttiTypeHelper }

procedure TRttiTypeHelper.ForEachMemberAttributeOfType<T>(
  Proc: TForEachTypeAttributeOfType<T>; Filter :TAttributeFilter<T>);
var
  LMember: TRttiMember;
  LType: TRttiType;
  LProc: TForEachAttributeOfType<T>;
begin
  LType := Self;
  LProc := procedure (Attribute: T)
  begin
    Proc(Attribute, LMember)
  end;

  while Assigned(LType) do
  begin
    for LMember in LType.GetFields do
      LMember.ForEachAttributeOfType<T>(LProc, Filter);

    for LMember in LType.GetProperties do
      LMember.ForEachAttributeOfType<T>(LProc, Filter);

    LType := LType.BaseType;
  end;
end;

procedure TRttiTypeHelper.ForEachMemberAttributeOfType<T>(
  Proc: TForEachTypeAttributeOfType<T>);
begin
  ForEachMemberAttributeOfType<T>(Proc, function (Attribute: T) : boolean
    begin
      result := TRUE;
    end);
end;


function TRttiTypeHelper.GetMemberAttributesOfType<T>(Filter: TAttributeFilter<T>): TArray<TAttrRecord<T>>;
var
  LMember: TRttiMember;
  LIndex: Integer;
  LProc: TForEachAttributeOfType<T>;
  LType: TRttiType;
  LOut: TArray<TAttrRecord<T>>;

begin
  LIndex := 0;
  SetLength(LOut, 10);

  LProc := procedure (Attribute: T)
      begin
        LOut[LIndex].Attribute := Attribute;
        LOut[LIndex].Member := LMember;
        inc(LIndex);
        if LIndex = Length(LOut) then
          SetLength(LOut, LIndex + 10);
      end;

  LType := Self;

  while Assigned(LType) do
  begin
    for LMember in LType.GetFields do
     LMember.ForEachAttributeOfType<T>(LProc, Filter);

    for LMember in Ltype.GetProperties do
      LMember.ForEachAttributeOfType<T>(LProc, Filter);

    LType := LType.BaseType;
  end;

  if LIndex < Length(LOut) then
    SetLength(LOut, LIndex);

  result := LOut;
end;

function TRttiTypeHelper.GetMemberAttributesOfType<T>: TArray<TAttrRecord<T>>;
begin
  result := GetMemberAttributesOfType<T>(function (Attribute: T): boolean
    begin
      result := TRUE;
    end);
end;

{ TRttiMemberHelper }

procedure TRttiMemberHelper.ForEachAttributeOfType<T>(
  Proc: TForEachAttributeOfType<T>; Filter : TAttributeFilter<T>);
var
  LAttr: TCustomAttribute;
begin
   for LAttr in GetAttributes do
    if LAttr is T And Filter(T(LAttr)) then
      Proc(T(LAttr));
end;

procedure TRttiMemberHelper.ForEachAttributeOfType<T>(
  Proc: TForEachAttributeOfType<T>);
begin
  ForEachAttributeOfType<T>(Proc, function (Attribute: T) : boolean
    begin
      result := TRUE;
    end);
end;

function TRttiMemberHelper.GetAttributesOfType<T> (Filter: TAttributeFilter<T>): TArray<T>;
var
  LAttr: TCustomAttribute;
  LIndex: Integer;
begin
  LIndex := 0;
  SetLength(Result, 0);
  for LAttr in GetAttributes do
    if LAttr is T  and (Filter(T(LAttr))) then
    begin
      SetLength(Result, LIndex + 1);
      Result[LIndex] := T(LAttr);
      inc(LIndex);
    end;
end;

function TRttiMemberHelper.GetAttributeOfType<T> (Filter: TAttributeFilter<T>): T;
var
  LAttr: TCustomAttribute;
begin

  for LAttr in GetAttributes do
    if LAttr is T  and (Filter(T(LAttr))) then
      Exit(T(LAttr));

  result := nil;
end;

function TRttiMemberHelper.GetValue(Instance: Pointer): TValue;
begin
  if (self is TRttiProperty) then
    Exit(TRttiProperty(Self).GetValue(Instance));
  if (self is TRttiField) then
    Exit(TRttiField(Self).GetValue(Instance));
  raise Exception.Create('Invalid member type in GetValue method.');
end;

procedure TRttiMemberHelper.SetValue(Instance: Pointer; const AValue: TValue);
begin
  if (self is TRttiProperty) then
    TRttiProperty(Self).SetValue(Instance, AValue)
  else
  if (self is TRttiField) then
    TRttiField(Self).SetValue(Instance, AValue)
  else
  raise Exception.Create('Invalid member type in SetValue method.');
end;

function TRttiMemberHelper.GetAttributesOfType<T>: TArray<T>;
begin
  result := GetAttributesOfType<T>(function (Attribute: T): boolean
    begin
      result := true
    end);
end;

function TRttiMemberHelper.GetAttributeOfType<T>: T;
begin
  result := GetAttributeOfType<T>(function (Attribute: T): boolean
    begin
      result := true
    end);
end;

{ TIIF }

class function TIIF.Eval<T>(const Expression: Boolean; TrueValue,
  FalseValue: T): T;
begin
  if Expression then
    result := TrueValue
  else
    result := FalseValue
end;

end.
