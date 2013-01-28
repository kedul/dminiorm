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

unit DminiORM.Core.ListIntf;

interface

Uses RTTI, SysUtils, DminiORM.Core.Factory, TypInfo, System.Generics.Collections;

type

  TListInterface = class
  private
    FListObj: TObject;
    FItemType: TRttiType;
    FGetEnumeratorMethod: TRttiMethod;
    FAddMethod: TRttiMethod;
    constructor Create;
  public
    class function Get(AType: TRttiType; AObject: TObject = nil):TListInterface;
    property ItemType: TRttiType read FItemType;
    property List: TObject read FListObj;
    procedure Add(AValue: TValue);
    type
      TEnumerator = class(TEnumerator<TObject>)
      private
        FEnumeratorObj: TObject;
        FRttiContext: TRttiContext;
        FMoveNextMethod: TRttiMethod;
        FCurrentProperty: TRttiProperty;
      protected
        function DoGetCurrent: TObject; override;
        function DoMoveNext: Boolean; override;
      public
        constructor create(AList: TListInterface);
        destructor destroy; override;
      end;
    function GetEnumerator: TEnumerator;
  end;

function IsList(AObj: TObject): Boolean; overload;
function IsList(AValue: TValue): Boolean; overload;
function IsList(ATypeInfo: PTypeInfo): Boolean; overload;
function IsList(AType: TRttiType): Boolean; overload;

implementation

function IsList(AObj: TObject): Boolean;
begin
  result := IsList(AObj.ClassInfo);
end;

function IsList(AValue: TValue): Boolean;
begin
  if AValue.TypeInfo.Kind = tkInterface then
    result := IsList(TObject(AValue.AsInterface))
  else
    result := IsList(AValue.AsObject);
end;

function IsList(ATypeInfo: PTypeInfo): Boolean;
var
  LCtx: TRttiContext;
begin
  result := IsList(LCtx.GetType(AtypeInfo));
end;

function IsList(AType: TRttiType): Boolean;
var LList: TListInterface;
begin
  LList:= TListInterface.Get(AType);
  result := Assigned(LLIst);
  if result then
  begin
    LList.List.Free;
    LList.Free;
  end;
end;


{ TListInterface }

procedure TListInterface.Add(AValue: TValue);
begin
  FAddMethod.Invoke(FListObj, [AValue])
end;

constructor TListInterface.Create;
begin
  inherited;
end;

function TListInterface.GetEnumerator: TEnumerator;
begin
  result := TEnumerator.Create(Self);
end;

class function TListInterface.Get(AType: TRttiType; AObject: TObject): TListInterface;
var
  LMethods: TArray<TRttiMethod>;
  LAddMethod: TRttiMethod;
  LMethod: TRttiMethod;
  LGetEnumeratorMethod: TRttiMethod;
  LMtdParams: TArray<TRttiParameter>;
  LList: TObject;
  LItemType: TRttiType;
  LOwnsObjectsProp: TRttiProperty;

begin
  result := nil;

  LMethods :=  AType.GetMethods;
  if LMethods = nil then
    Exit;

  LAddMethod := nil;
  LGetEnumeratorMethod := nil;

  for LMethod in LMethods do
  begin
    if (LAddMethod= nil) and SameText('ADD', LMethod.Name) then
    begin
      LMtdParams := LMethod.GetParameters;
      if (LMtdParams <> nil) and (Length(LMtdParams) = 1) then
      begin
        LAddMethod := LMethod;
        LItemType := LMtdParams[0].ParamType;
      end;
    end;
    if (LGetEnumeratorMethod= nil) and SameText('GetEnumerator', LMethod.Name) then
    begin
      LMtdParams := LMethod.GetParameters;
      if (LMtdParams = nil) Or ((LMtdParams<> nil) and (Length(LMtdParams) = 0)) then
        LGetEnumeratorMethod := LMethod;
    end;
    if Assigned(LGetEnumeratorMethod)  and Assigned(LAddMethod) then
      break;
  end;
  if not Assigned(LGetEnumeratorMethod) or not Assigned(LAddMethod) then
    Exit;

  if (AObject<>nil) And (AObject.ClassType = AType.AsInstance.MetaclassType) then
    LList := AObject
  else
  begin
    LList := Factory.Get(AType.Handle).AsObject;
    LOwnsObjectsProp := AType.GetProperty('OwnsObjects');
    if (LOwnsObjectsProp<>nil) And
      (LOwnsObjectsProp.PropertyType.Handle = TypeInfo(System.Boolean)) then
      LOwnsObjectsProp.SetValue(LList, TRUE);
  end;

  result := TListInterface.Create;
  result.FListObj := LList;
  result.FItemType := LItemType;
  result.FAddMethod := LAddMethod;
  result.FGetEnumeratorMethod := LGetEnumeratorMethod;
end;


constructor TListInterface.TEnumerator.Create(AList: TListInterface);
begin
  inherited create;
  FRttiContext := TRttiContext.Create;
  FEnumeratorObj := AList.FGetEnumeratorMethod.Invoke(Alist.FListObj,[]).AsObject;
  FMoveNextMethod := FRttiContext.GetType(FEnumeratorObj.ClassInfo).GetMethod('MoveNext');
  FCurrentProperty := FRttiContext.GetType(FEnumeratorObj.ClassInfo).GetProperty('Current');
end;

destructor TListInterface.TEnumerator.Destroy;
begin
  inherited;
  FEnumeratorObj.Free;
  FRttiContext.Free;
end;

function TListInterface.TEnumerator.DoGetCurrent: TObject;
begin
  Result := FCurrentProperty.GetValue(FEnumeratorObj).AsObject;
end;

function TListInterface.TEnumerator.DoMoveNext: Boolean;
begin
  Result := FMoveNextMethod.Invoke(FEnumeratorObj,[]).AsBoolean;
end;

end.
