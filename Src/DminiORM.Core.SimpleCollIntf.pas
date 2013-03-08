unit DminiORM.Core.SimpleCollIntf;

interface

Uses Generics.Collections;

Type

  ISimpleDictionary<K,V> = Interface
    procedure Put(Key: K; const Value: V);
    function Get(Key: K): V;
    procedure Remove(const Key: K);
    function TryGet(Key: K; out Value: V): boolean;
    function ContainsKey(Key: K): boolean;
    function Size: integer;
    function Values: TArray<V>;
    function Keys: TArray<K>;
    function GetEnumerator: TEnumerator<TPair<K,V>>;
    procedure Clear;
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
    procedure Remove(const Key: K);
    function TryGet(Key: K; out Value: V): boolean;
    function ContainsKey(Key: K): boolean;
    function Values: TArray<V>;
    function Keys: TArray<K>;
    function Size: integer;
    function GetEnumerator: TEnumerator<TPair<K,V>>;
    procedure Clear;
  end;

implementation


{ TSimpleDictionary<K, V> }

procedure TSimpleDictionary<K, V>.Clear;
begin
  FDictionary.Clear;
end;

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

function TSimpleDictionary<K, V>.GetEnumerator: TEnumerator<TPair<K,V>>;
begin
  result := FDictionary.GetEnumerator;
end;

function TSimpleDictionary<K, V>.Keys: TArray<K>;
begin
  result := FDictionary.Keys.ToArray;
end;

procedure TSimpleDictionary<K, V>.Put(Key: K; const Value: V);
begin
  FDictionary.AddOrSetValue(Key,Value);
end;

procedure TSimpleDictionary<K, V>.Remove(const Key: K);
begin
  FDictionary.Remove(Key);
end;

function TSimpleDictionary<K, V>.Size: integer;
begin
  result := FDictionary.Count;
end;

function TSimpleDictionary<K, V>.TryGet(Key: K; out Value: V): boolean;
begin
  result := FDictionary.TryGetValue(Key, Value);
end;

function TSimpleDictionary<K, V>.Values: TArray<V>;
begin
  result := FDictionary.Values.ToArray;
end;

end.
