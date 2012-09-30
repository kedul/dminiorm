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
    IsDetailField: Boolean;
    OldValue: TValue;
    NewValue: TValue;
    function Modified: Boolean;
  end;

  TORMFields = TArray<TORMField>;

  TObjectState = (osNew, osModified, osDeleted, osUnknow);

  TORMObjectStatus = record
    State: TObjectState;
    EnitityName: String;
    Fields: TORMFields;
    function ModifiedFields: TORMFields;
    function IsModified: Boolean;
    function KeyFields: TORMFields;
  end;

  IDataWriter = interface
    ['{D10FA8DD-0838-4836-88E0-A9351739CA6C}']
    function Save(Records: TArray<TORMObjectStatus>): TArray<TDataRow>;
    procedure Delete(RecKeys: TArray<TORMObjectStatus>);
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

    ILoadDelegate = Interface
    ['{D9DB705C-DB5D-433A-901D-88E9EF631CEF}']
    procedure Put(const Value: TValue);
    function Get: TValue;
    procedure SetRelation(RelationAddr: pointer;
      RelationResultTypeInfo: PTypeInfo);
    function AsObject: TInterfacedObject;
  End;

  RelationRec = record
    Delegate: ILoadDelegate;
    Owner: TObject;
    DetailColumns: TArray<TRelationShipInfo>;
    DataReader: IDataReader;
  end;

  PRelationRec = ^RelationRec;

  Relation<T: class> = record
  private
    {
      LoadDelegate es necesario para que la lista con los objetos se libere de
      forma automática cuando se pierda la referencia. De otra forma, sería
      necesario que en el destructor de la clase, se liberara de forma explicita
      este objeto.
    }
    Rec: RelationRec;
    procedure Initialize;
  public
    function Get: T;
    class operator Implicit(const Lazy: Relation<T>): T;
    class operator Implicit(const Value: T): Relation<T>;
  end;

  IORM = Interface
    ['{6CC8D453-528B-407D-BE65-D1D8FD4A71ED}']
    function Load(ATypeInfo: PTypeInfo; AProvider: String;
      Parameters: TArray<TParameter>): TValue; overload;
    function Load(ATypeInfo: PTypeInfo; AKeyValues: Array of const): TValue; overload;
    procedure Save(AValue: TValue);
    procedure Delete(AValue: TValue);
    function AsObject: TInterfacedObject;
  End;

  TORM = class
    class function Load<T>(AProviderName: String; AParameters: TArray<TParameter>): T; overload;
    class function Load<T>(AParameters: TArray<TParameter>): T; overload;
    class function Load<T>(AKeyValues: Array of const): T; overload;
    class procedure Save<T>(AValue: T);
    class procedure Delete<T>(AValue: T);
  end;


implementation

uses DminiORM.Core.Factory;

function TORMField.Modified: Boolean;
var
  LDetails: TArray<TORMObjectStatus>;
  LObjStatus: TORMObjectStatus;

begin
  if not IsDetailField then
    result := not VarSameValue(OldValue.AsVariant, NewValue.AsVariant)
  else
  begin
    LDetails := NewValue.AsType<TArray<TORMObjectStatus>>;
    result := false;
    for LObjStatus in LDetails do
    begin
      result := LObjStatus.IsModified;
      if result then
        break;
    end;
  end;
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


{ Relation<T> }

class operator Relation<T>.Implicit(const Lazy: Relation<T>): T;
begin
  result := Lazy.Get;
end;

function Relation<T>.Get: T;
var LVal : TValue;

begin
  if Rec.Delegate = nil then
    Initialize;
  LVal := Rec.Delegate.Get;
  if LVal.IsObject then
    result := T(Lval.AsObject)

end;

class operator Relation<T>.Implicit(const Value: T): Relation<T>;
begin
  result.Initialize;
  result.Rec.Delegate.Put(T);
end;

procedure Relation<T>.Initialize;
begin
  Rec.Delegate := Factory.Get<ILoadDelegate>;
  Rec.Delegate.SetRelation(@self, TypeInfo(T));
end;

{ TColumn }

constructor TColumn.Create(AName: String; AValue: TValue);
begin
  Name := AName;
  AValue := AValue;
end;


{ TORM }

class procedure TORM.Delete<T>(AValue: T);
var
  LOrm: IORM;

begin
  LOrm := Factory.Get<IOrm>;
  LOrm.Save(TValue.From<T>(AValue));
end;

class function TORM.Load<T>(AProviderName: String;
  AParameters: TArray<TParameter>): T;
var
  LOrm: IORM;
begin
  LOrm := Factory.Get<IOrm>;
  result := LOrm.Load(TypeInfo(T),AProviderName,AParameters).AsType<T>;
end;

class function TORM.Load<T>(AKeyValues: array of const): T;
var
  LOrm: IORM;
begin
  LOrm := Factory.Get<IOrm>;
  result := LOrm.Load(TypeInfo(T),AKeyValues).AsType<T>;
end;

class function TORM.Load<T>(AParameters: TArray<TParameter>): T;
var
  LOrm: IORM;
begin
  LOrm := Factory.Get<IOrm>;
  result := LOrm.Load(TypeInfo(T),'',AParameters).AsType<T>;
end;

class procedure TORM.Save<T>(AValue: T);
var
  LOrm: IORM;

begin
  LOrm := Factory.Get<IOrm>;
  LOrm.Save(TValue.From<T>(AValue));
end;

end.
