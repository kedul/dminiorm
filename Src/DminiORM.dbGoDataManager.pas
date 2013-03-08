unit DminiORM.dbGoDataManager;

interface

Uses DminiORM.Core, Data.Win.ADODB, IniFiles, SysUtils, Classes, Rtti,
  DminiORM.VCLDataSetAdapter, StrUtils, DminiORM.Core.Factory, DB,
  Generics.Collections, Variants, DminiORM.Core.SimpleCollIntf;

type

  TOnLog = reference to procedure(const text: String);

  TdbGoDataManager = class (TInterfacedObject, IDataManager)
  private
    class var FCnPool: TList<TADOConnection>;
    class var FProviders: THashedStringList;
    class var FConnectionString: String;
    function TryGetProvider(const ProviderName: STring; out CommandText: String): boolean;
    class function GetConnectionString: String; static;
    class procedure SetConnectionString(const Value: String); static;
    class procedure Log(Text: String);
    class var FOnLog: TOnLog;

    // FTranCount : Integer;
  public
    class constructor create;
    class destructor destroy;
    class property ConnectionString: String read GetConnectionString write SetConnectionString;
    class procedure RegisterProvider(const AProviderName, AProviderCommandText: String); overload;
    class procedure RegisterProvider(const AProviderName, AProviderReader, AProviderInserter, AProviderUpdater, AProviderDeleter: String); overload;
    class procedure LoadProviderFromFile(const FileName: String);
    class property OnLog: TOnLog read FOnLog write FOnLog;
    class function AdquireConnection: TADOConnection;
    class procedure RealeaseConnection(cn: TADOConnection);
    function GetReader(ProviderName: string;
      Parameters: System.TArray<DminiORM.Core.TColumn>): IDataReader;
    function GetWriter(EntityName: string): IDataWriter;
    function GetColumnNames(EntityName: String): TArray<String>;
//    procedure BeginTran;
//    procedure Commit;
//    procedure RollBack;
//    function InTransaction: Boolean;
    function Execute(FuncName: string; Parameters: array of TColumn): TValue;
  end;


implementation

Type

  TdbGoWriter = class (TInterfacedObject, IDataWriter)
  private
    FEntityName : String;
    FUpdateComandText : String;
    FInsertCommandText : String;
    FDeleteCommandText : String;
  public
    constructor Create(const AEntityName: String); overload;
    constructor Create(const AInsertCommandText,
                             AUpdateCommandText,
                             ADeleteCommandText: String); overload;
    function Save(Records: TArray<TORMObjectStatus>): TArray<TDataRow>;
    procedure Delete(RecKeys: TArray<TDataRow>);
  end;

{ TdbGoWriter }

constructor TdbGoWriter.Create(const AEntityName: String);
begin
  FEntityName := AEntityName;
end;

constructor TdbGoWriter.Create(const AInsertCommandText,AUpdateCommandText,
    ADeleteCommandText: String);
begin
  FInsertCommandText := AInsertCommandText;
  FUpdateComandText := AUpdateCommandText;
  FDeleteCommandText := ADeleteCommandText;
end;

procedure TdbGoWriter.Delete(RecKeys: TArray<TDataRow>);
var
  LCmdText : TStringBuilder;
  LRow: TDataRow;
  i: integer;
  LCommand: TADOCommand;
  LSP: TADOStoredProc;
begin
  LCmdText := TStringBuilder.Create;
  LCommand := TADOCommand.Create(Nil);
  LSP := TADOStoredProc.Create(NIL);
  try
    //LSP.Connection := TdbGoDataManager.FConnection;
    //LSP.Parameters.Refresh;
    LCommand.ParamCheck := FALSE;
    if Length(RecKeys) > 1 then
      LCmdText.Append('SET XACT_ABORT ON; ').Append('BEGIN TRAN; ');
    for LRow in RecKeys do
    begin
      if FDeleteCommandText <> '' then
      begin
        LCmdText.Append('EXEC '+FDeleteCommandText);
        for i:=0 to Length(LRow)-2 do
        begin
          LCmdText.Append(' @'+LRow[i].Name+'=?,');
          LCommand.Parameters.AddParameter.Value := LRow[i].Value.AsVariant;
        end;
        i:= Length(LRow)-1;
        LCmdText.Append(' @'+LRow[i].Name+'=?;');
        LCommand.Parameters.AddParameter.Value := LRow[i].Value.AsVariant;
      end
      else
      begin
        LCmdText.Append('DELETE FROM "').Append(FEntityName).Append('" WHERE ');
        for i:= 0 to Length(LRow)-1  do
        begin
          LCmdText.Append('"').Append(LRow[i].Name).Append('" =?');
          if (i<Length(LRow)-1) then LCmdText.Append('AND ');
        end;
        if Length(RecKeys) > 1 then
          LCmdText.Append(';COMMIT;');
      end;
    end;

    LCommand.Connection := TdbGoDataManager.AdquireConnection;
    try
      LCommand.CommandText := LCmdText.ToString;

      for LRow in RecKeys do
        for i:=0 to Length(LRow)-1  do
          LCommand.Parameters.AddParameter.Value := LRow[i].Value.AsVariant;

      LCommand.Execute;
    finally
      TdbGoDataManager.RealeaseConnection(LCommand.Connection);
    end;
  finally
    LCommand.Free;
    LCmdText.Free;
    LSP.Free;
  end;
end;

function TdbGoWriter.Save(Records: TArray<TORMObjectStatus>): TArray<TDataRow>;
var
  LWhere: TStringList;
  LObjStatus: TORMObjectStatus;
  LFld: TORMField;
  LQuery : TADOQuery;
  i: integer;
  LWhereCmd: String;
  LAdapter: IDataWriter;
  LInsSp, LUpdSp, LDelSP, LSp: TADOStoredProc;
  LConnection : TADOCOnnection;

  procedure SetParamValue(SP: TADOStoredProc; Fld: TORMField);
  var
    i : integer;
  begin
    for i := 0 to Sp.Parameters.Count -1 do
      if SameText ('@'+Fld.ColumnName, Sp.Parameters[i].Name) then
      begin
        if Fld.IsKeyField then
        begin
              if LFld.HasOldValueInfo then
                sp.Parameters[i].Value := LFld.OldValue.AsVariant
              else
                sp.Parameters[i].Value := LFld.NewValue.AsVariant;
        end
        else
          sp.Parameters[i].Value := LFld.NewValue.AsVariant;
      end;
  end;

begin
  LConnection := TdbGoDataManager.AdquireConnection;
  try
    if FEntityName<>'' then
    begin
      LWhere := TStringList.Create;
      LQuery := TADOQuery.Create(nil);
      LQuery.Connection := LConnection;
      try
        for LObjStatus in Records do
        begin
          if (LobjStatus.State in [osModified, osUnknow]) then
          begin
            LWhere.Append('(');
            for LFld in LObjStatus.Fields do
            begin
              if LFld.IsKeyField then begin
                LWhere.Append('"'+LFld.ColumnName+'" = ? ');
                LWhere.Append('AND ');
              end;
            end;
            LWhere.Delete(LWhere.Count-1);
            LWhere.Append(') ');
            LWhere.Append('OR ');
          end;
        end;

        if LWhere.Count>0 then
          LWhere.Delete(LWhere.Count-1);
        LWhereCmd := LWhere.Text;

        if (LWhereCmd='') then
        begin
          LQuery.SQL.Text := 'SELECT * FROM "'+FEntityName+'"';
          LQuery.MaxRecords := 1;
        end
        else
          LQuery.SQL.Text := 'SELECT * FROM "'+FEntityName+'" WHERE '+
            Copy(LWhereCmd,1, Length(LWhereCmd)-3);

        i:=0;

        for LObjStatus in Records do
          if (LobjStatus.State in [osModified, osUnknow]) then
          begin
            for LFld in LObjStatus.Fields do
              if LFld.IsKeyField then
              begin
                if LFld.HasOldValueInfo then
                  LQuery.Parameters[i].Value := LFld.OldValue.AsVariant
                else
                  LQuery.Parameters[i].Value := LFld.NewValue.AsVariant;
                inc(i);
              end;
          end;
        LQuery.CursorLocation := clUseClient;
        LQuery.CursorType := ctStatic;
        LQuery.LockType := ltBatchOptimistic;
        LQuery.Open;

        LAdapter := TDataSetAdapter.Create(LQuery);
        result := LAdapter.Save(Records);
        LQuery.UpdateBatch;

      finally
        LWhere.Free;
        LQuery.Free;
      end;
    end
    else
    begin
      LInsSp := TADOStoredProc.Create(nil);
      LUpdSp := TADOStoredProc.Create(nil);
      LDelSp := TADOStoredProc.Create(nil);
      try
        LInsSp.Connection := LConnection;
        LDelSp.Connection := LConnection;
        LUpdSp.Connection := LConnection;
        LConnection.BeginTrans;
        try
          for LObjStatus in Records do
          begin
            case LobjStatus.State of
              osModified : begin
                if LUpdSp.ProcedureName = '' then
                begin
                  LUpdSp.ProcedureName := FUpdateComandText;
                  LUpdSp.Parameters.Refresh;
                  LUpdSp.Parameters.Delete(0);
                end;
                LSp := LUpdSp;
              end;
              osNew : begin
                if LInsSp.ProcedureName = '' then
                begin
                  LInsSp.ProcedureName := FUpdateComandText;
                  LInsSp.Parameters.Refresh;
                  LInsSp.Parameters.Delete(0);
                end;
                LSp := LInsSp;
              end;
              osDeleted: begin
                if LDelSp.ProcedureName = '' then
                begin
                  LDelSp.ProcedureName := FUpdateComandText;
                  LDelSp.Parameters.Refresh;
                  LDelSp.Parameters.Delete(0);
                end;
                LSp := LDelSp;
              end
              else
                raise exception.Create('Unsupported status mode: osUnknow');
            end;
            for LFld in LObjStatus.Fields do
              SetParamValue(Lsp, LFld);
            LSp.ExecProc;
            result := nil;
          end;
          LConnection.CommitTrans;
        except
          LConnection.RollbackTrans;
          raise;
        end;
      finally
        LInsSp.Free;
        LDelSp.Free;
        LUpdSp.Free;
      end;
    end;
  finally
    TdbGoDataManager.RealeaseConnection(LConnection);
  end;
end;

type
  TdbGoReader = class (TInterfacedObject, IDataReader)
  private
    Rs: _Recordset;
    DS: TADODataSet;
    FRecNo: integer;
    FFieldsMap: TDictionary<String, Integer>;
  public
    constructor Create(ADataSet: TADODataSet);
    destructor Destroy; override;
    function GetDataRow: System.TArray<DminiORM.Core.TColumn>;
    function GetEOF: Boolean; inline;
    function GetRecNo: Integer; inline;
    function GetRowColumn(ColumnName: string; out Value: TValue): Boolean; inline;
    procedure Next; inline;
  end;

{ TdbGoReader }

constructor TdbGoReader.Create(ADataSet: TADODataSet);
var
  LFld: TField;
begin
  inherited Create;
  Rs:= ADataSet.RecordSet;
  DS:= ADataSet;
  if RS.EOF then
    FRecNo := 0
  else
    FRecNo := 1;
  FFieldsMap := TDictionary<String, Integer>.Create;
  for LFld in Ds.FIelds do
    FFieldsMap.Add(UpperCase(LFld.FieldName), LFld.Index);
end;

destructor TdbGoReader.destroy;
begin
  TdbGoDataManager.RealeaseConnection(DS.Connection);
  DS.Free;
  FFieldsMap.Free;
  inherited;
end;

function TdbGoReader.GetDataRow: System.TArray<DminiORM.Core.TColumn>;
var
  i: integer;
begin
  SetLength(Result, Rs.Fields.Count);
  for i := 0 to Rs.Fields.Count -1  do
    Result[0] := DminiORM.Core.TColumn.Create(Rs.Fields[0].Name,
      TValue.FromVariant(Rs.Fields[0].Value));
end;

function TdbGoReader.GetEOF: Boolean;
begin
  result := rs.EOF;
end;

function TdbGoReader.GetRecNo: Integer;
begin
  result := FRecNo;
end;

function TdbGoReader.GetRowColumn(ColumnName: string;
  out Value: TValue): Boolean;
var
  LIndex: Integer;
begin
  result := FFieldsMap.TryGetValue(UpperCase(ColumnName), LIndex);
  if result then
    Value := TValue.FromVariant(Rs.Fields[LIndex].Value);
end;

procedure TdbGoReader.Next;
begin
  Rs.MoveNext;
  inc(FRecNo);
end;


{ TdbGoDataManager }

function TdbGoDataManager.GetReader(ProviderName: string;
  Parameters: System.TArray<DminiORM.Core.TColumn>): IDataReader;
var
  LCommandText: String;
  LCommand: TADODataSet;
  i: integer;

begin
  if not TryGetProvider(ProviderName, LCommandText) then
    //raise Exception.Create('dbGoDataManager: can''t find provider '+ProviderName);
    LCommandText := 'Select * from ['+ProviderName+']'
  else begin
    i := Pos('|', LCommandText);
    if i>0 then
     LCommandText := Copy(LCommandText,1, i-1);
  end;
  LCommand := TADODataSet.Create(NIL);
  try
    LCommand.Connection := TdbGoDataManager.AdquireConnection;
    LCommand.CommandText := LCommandText;
    if (Length(Parameters)>0) AND StartsText('SELECT', LCommandText) And
      (LCommand.Parameters.Count = 0) then begin
        LCommandText:= LCommandText+' WHERE ';
        for i:=0 to Length(Parameters)-2 do begin
          LCommandText:= LCommandText + '"'+Parameters[i].Name+'"= :p'+IntToStr(i)+' AND ';

        end;
        LCommandText:= LCommandText + '"'+Parameters[Length(Parameters)-1].Name+'"=:pf';
        LCommand.CommandText := LCommandText;
    end;
    if Not StartsText('SELECT', LCommandText) and (LCommand.Parameters.Count = 0) then begin
      LCommand.CommandType := cmdStoredProc;
      // todo: cache this for performance.
      LCommand.Parameters.Refresh;
      LCommand.Parameters.Delete(0); // Return value
    end;

    if (LCommand.Parameters.Count<>0) then
    begin
      if (LCommand.Parameters.Count<>Length(Parameters)) then
        raise Exception.CreateFmt('dbGoDataManager: Incorrent number of parameters. Expected %d supplied %d.',
           [LCommand.Parameters.Count, Length(Parameters)]);
      // todo: Check parameters names.
      for i := 0 to Length(Parameters) - 1 do
        LCommand.Parameters[i].Value := Parameters[i].Value.AsVariant;
    end;


    LCommand.CursorLocation := clUseServer;
    LCommand.CursorType := ctOpenForwardOnly;
    LCommand.LockType :=  ltReadOnly;

    LCommand.Open;
    Log(LCommandText);
    //result := TDataSetAdapter.Create(LCommand, TRUE);
    result := TdbGoReader.Create(LCommand);
  except
    on e: exception do begin
      TdbGoDataManager.RealeaseConnection(LCommand.Connection);
      LCommand.free;
      raise Exception.CreateFmt('dbGoDataManager: Can''t execute reader for provider %s.'#13#10'Command: %s.'#13#10'Error: %s',
        [ProviderName,LCommandText, e.Message]);
    end;
  end;
end;


function TdbGoDataManager.GetWriter(EntityName: string): IDataWriter;
var
  LCommandText: String;
  LCommand: TADODataSet;
  LStrList: TStringList;
begin
  if not TryGetProvider(EntityName, LCommandText) then
    result := TdbGoWriter.Create(EntityName)
  else begin
    if Pos('|',LCommandText)=0 then
      result := TdbGoWriter.Create(EntityName)
    else begin
       LStrList := TStringList.Create;
       LStrList.LineBreak := '|';
       LStrList.Text := LCommandText;
       result := TdbGoWriter.Create(LStrList[1], LStrList[2], LStrList[3]);
    end;
  end;
//  if not TryGetProvider(EntityName, LCommandText) then
//  begin
//    // todo: Get field definition from class map and use merge command
//    {
//      merge tablename WITH(HOLDLOCK) as target
//      using (values ('new value', 'different value'))
//     as source (field1, field2)
//     on target.idfield = 7
//      when matched then
//     update
//      set field1 = source.field1,
//        field2 = source.field2,
//        ...
//    when not matched then
//    insert ( idfield, field1, field2, ... )
//    values ( 7,  source.field1, source.field2, ... )
//    output ....
//    }
//    LCommandText:='SELECT * from "'+EntityName+'"';
//    TdbGoDataManager.RegisterProvider(EntityName, LCommandText);
//  end;
//  LCommand := TADODataSet.Create(NIL);
//  try
//    LCommand.ConnectionString := TdbGoDataManager.FConnectionString;
//    LCommand.CommandText := LCommandText;
//    if Not StartsText('SELECT', LCommandText) then begin
//      LCommand.CommandType := cmdStoredProc;
//      // todo: cache this for performance.
//      LCommand.Parameters.Refresh;
//    end;
//    result := TDataSetAdapter.Create(LCommand, TRUE);
//  except
//    LCommand.free;
//  end;
end;

class procedure TdbGoDataManager.LoadProviderFromFile(const FileName: String);
var
  LTextFile: TStringList;
  i: integer;
begin
  LTextFile := TStringList.Create;
  try
    LTextFile.LoadFromFile(FileName);
    for i := 0 to LTextFile.Count - 1 do
      TdbGoDataManager.RegisterProvider(LTextFile.Names[i],
          LTextFile.ValueFromIndex[i]);
  finally
    LTextFile.Free;
  end;
end;

class procedure TdbGoDataManager.Log(Text: String);
begin
  if Assigned(OnLog) then
     OnLog(DateTimeToStr(Now)+': '+Text);
end;

class procedure TdbGoDataManager.RegisterProvider(const AProviderName,
  AProviderCommandText: String);
begin
  TdbGoDataManager.FProviders.Values[AProviderName] := AProviderCommandText;
end;

class procedure TdbGoDataManager.RealeaseConnection(cn: TADOConnection);
begin
  if (cn=NIL) then Exit;
  
  MonitorEnter(FCnPool);
  try
  if TdbGODataManager.FCnPool.Count > 5 then
    cn.Free
  else
  begin
    if cn.InTransaction then
      cn.RollbackTrans;
    FCnPool.Add(cn);
  end;
  finally
    MonitorExit(FcnPool);
  end;
end;

class procedure TdbGoDataManager.RegisterProvider(const AProviderName,
  AProviderReader, AProviderInserter, AProviderUpdater,
  AProviderDeleter: String);
begin
  TdbGoDataManager.FProviders.Values[AProviderName] := AProviderReader+'|'+
    AProviderInserter+'|'+AProviderUpdater+'|'+AProviderDeleter;
end;

function TdbGoDataManager.TryGetProvider(const ProviderName: String;
  out CommandText: String): boolean;
var
  LIndex: integer;
begin
  LIndex := TdbGoDataManager.FProviders.IndexOfName(ProviderName);
  if LIndex = -1  then
    Exit(FALSE);
  CommandText:= TdbGoDataManager.FProviders.ValueFromIndex[Lindex];
  result := TRUE;
end;

function TdbGoDataManager.GetColumnNames(EntityName: String): TArray<String>;
var
  LDataSet: TADODataSet;
  LCommandText: String;
  i: integer;
begin
  if not TryGetProvider(EntityName, LCommandText) then
    LCommandText := 'SELECT * FROM "'+EntityName+'"'
  else begin
    i := Pos('|', LCommandText);
    if i>0 then
     LCommandText := Copy(LCommandText,1, i-1);
  end;

  LDataSet := TADODataSet.Create(NIL);
  try
    LDataSet.Connection := TdbGoDataManager.AdquireConnection;
    LDataSet.CommandText := LCommandText;
    LDataSet.MaxRecords := 1;
    if not StartsText('SELECT ',LCommandText) then
    begin
      LDataSet.CommandType := cmdStoredProc;
      LDataSet.Parameters.Refresh;
      LDataSet.MaxRecords := 0;
    end;

    for i := 0 to LDataSet.Parameters.Count -1 do
      if LDataSet.Parameters[i].Direction <> pdReturnValue then
        LDataSet.Parameters[i].Value := Null;

    LDataSet.Open;

    SetLength(Result, LDataSet.Fields.Count);
    for i:=0 to LDataSet.Fields.Count-1 do
      Result[i]:=  LDataSet.Fields[i].FieldName;

  finally
    TdbGoDataManager.RealeaseConnection(LDataSet.Connection);
    LDataSet.Free;
  end;
end;

class function TdbGoDataManager.GetConnectionString;
begin
  result := FConnectionString;
end;

class procedure TdbGoDataManager.SetConnectionString(const Value: string);
begin
  if not SameText(value, FConnectionString) then
  begin
    MonitorEnter(FCnPool);
    try
      FCnPool.Clear;
    finally
      MonitorExit(FCnPool);
    end;
    FConnectionString := Value;
  end;
end;

class function TdbGoDataManager.AdquireConnection: TADOConnection;
begin
  MonitorEnter(FCnPool);
  try
    if FCnPool.Count>0 then
    begin
      result := FCnPool.First;
      FCnPool.Delete(0);
      Exit;
    end
  finally
    MonitorExit(FCnPool);
  end;
  result := TADOConnection.Create(NIL);
  result.ConnectionString := ConnectionString;
  result.KeepConnection := TRUE;
  result.LoginPrompt := FALSE;
  result.Open;
end;

//procedure TdbGoDataManager.BeginTran;
//begin
//  if FTranCount = 0 then FConnection.BeginTrans;
//  inc(FTranCount);
//end;
//
//procedure TdbGoDataManager.Commit;
//begin
//  if (FTranCount>0) then
//  begin
//    Dec(FTranCount);
//    if FTranCount= 0 then FConnection.CommitTrans;
//  end;
//end;


function TdbGoDataManager.Execute(FuncName: String;
  Parameters: array of TColumn): TValue;
var
  LSp: TADOStoredProc;
  LParam: TColumn;
  i: integer;
begin
  LSp := TADOStoredProc.Create(nil);
  try
    LSp.Connection := TdbGoDataManager.AdquireConnection;
    LSp.ProcedureName := FuncName;
   // LSP.Parameters.Refresh;
    with LSP.Parameters.AddParameter do
    begin
      Name := '@RETURN_VALUE';
      Direction := pdReturnValue;
      DataType := ftInteger;
    end;

    for LParam in Parameters do
      with LSP.Parameters.AddParameter do
      begin
        Name := LParam.Name;
        Direction := pdInput;

        Value := LParam.Value.AsVariant;
      end;

    LSp.ExecProc;
    result := TValue.FromVariant(LSP.Parameters[0].Value);
  finally
    TdbGoDataManager.RealeaseConnection(LSp.Connection);
    LSP.Free;
  end;
end;

//procedure TdbGoDataManager.RollBack;
//begin
//  if FTranCount > 0 then
//      FConnection.RollbackTrans;
//  FTranCount := 0;
//end;
//
//function TdbGoDataManager.InTransaction;
//begin
//  result := FTranCount > 0;//FConnection.InTransaction;
//end;

class constructor TdbGoDataManager.create;
begin
  TdbGoDataManager.FProviders := THashedStringList.Create;
  TdbGoDataManager.FProviders.CaseSensitive := FALSE;
  TdbGoDataManager.FCnPool := TList<TADOConnection>.Create;
  Factory.Register(IDataManager, TdbGoDataManager);
end;

class destructor TdbGoDataManager.destroy;
var
  i: integer;
begin
  TdbGoDataManager.FProviders.Free;
  for i := 0 to FCnPool.Count -1  do
    FCnPool[i].Free;
  TdbGoDataManager.FCnPool.Free;
end;


end.
