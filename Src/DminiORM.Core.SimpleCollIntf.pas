unit DminiORM.Core.SimpleCollIntf;

interface

Uses Generics.Collections;

Type

  ISimpleDictionary<K,V> = Interface
    procedure Put(Key: K; const Value: V);
    function Get(Key: K): V;
    function TryGet(Key: K; out Value: V): boolean;
    function ContainsKey(Key: K): boolean;
    function Size: integer;
    property Items[Key:K]: V read Get write Put; default;
  End;

  TSimpleDictionary<K,V> = class (TInterfacedObject, ISimpleDictionary<K,V>)
  private
    FDictionary: TDictionary<K,V>;
  public
    constructor Create;
    destructor destroy; override;
    procedure Put(Key: K; const Value: V);
    function Get(Key: K): V;
    function TryGet(Key: K; out Value: V): boolean;
    function ContainsKey(Key: K): boolean;
    function Size: integer;
  end;

implementation


{ TSimpleDictionary<K, V> }

function TSimpleDictionary<K, V>.ContainsKey(Key: K): boolean;
begin
  result := FDictionary.ContainsKey(Key);
end;

constructor TSimpleDictionary<K, V>.Create;
begin
  FDictionary:= TDictionary<K,V>.Create;
end;

destructor TSimpleDictionary<K, V>.destroy;
begin
  FDictionary.Free;
  inherited;
end;

function TSimpleDictionary<K, V>.Get(Key: K): V;
begin
  result := FDictionary[Key]
end;

procedure TSimpleDictionary<K, V>.Put(Key: K; const Value: V);
begin
  FDictionary.AddOrSetValue(Key,Value);
end;

function TSimpleDictionary<K, V>.Size: integer;
begin
  result := FDictionary.Count;
end;

function TSimpleDictionary<K, V>.TryGet(Key: K; out Value: V): boolean;
begin
  result := FDictionary.TryGetValue(Key, Value);
end;

end.
