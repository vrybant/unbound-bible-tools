unit UnitCommentary;

{$ifdef linux}
  {$define zeos}
{$endif}

interface

uses
  Classes, Fgl, SysUtils, Dialogs, Graphics, IniFiles, ClipBrd, LazUtf8, DB, SQLdb,
  {$ifdef zeos} ZConnection, ZDataset, ZDbcSqLite, {$else} SQLite3conn, {$endif}
  UnitLib, UnitType;

const
  BookMax = 86;

type
  TCommentary = class
    {$ifdef zeos}
      Connection : TZConnection;
      Query : TZReadOnlyQuery;
    {$else}
      Connection : TSQLite3Connection;
      Transaction : TSQLTransaction;
      Query : TSQLQuery;
    {$endif}
    {-}
    info         : string;
    filePath     : string;
    fileName     : string;
    fileFormat   : TFileFormat;
    z            : TStringAlias;
    {-}
    name         : string;
    native       : string;
    abbreviation : string;
    copyright    : string;
    language     : string;
    fileType     : string;
    note         : string;
    {-}
    FirstVerse   : TVerse;
    RightToLeft  : boolean;
    compare      : boolean;
    fontName     : TFontName;
    fontSize     : integer;
    {-}
    connected    : boolean;
    loaded       : boolean;
  private
    function EncodeID(id: integer): integer;
    function DecodeID(id: integer): integer;
    function SortingIndex(number: integer): integer;
  public
    constructor Create(filePath: string);
    procedure OpenDatabase;
    function GetChapter(Verse: TVerse): TStringArray;
    function GetRange(Verse: TVerse): TStringArray;
    function GoodLink(Verse: TVerse): boolean;
    function  Search(searchString: string; SearchOptions: TSearchOptions; Range: TRange): TContentArray;
    function GetAll: TContentArray;
    function  ChaptersCount(Verse: TVerse): integer;
    procedure SavePrivate(const IniFile: TIniFile);
    procedure ReadPrivate(const IniFile: TIniFile);
    destructor Destroy; override;
  end;

  TCommentaries = class(TFPGList<TCommentary>)
    Current : integer;
  private
    procedure AddCommentaries(path: string);
    procedure SavePrivates;
    procedure ReadPrivates;
  public
    constructor Create;
    procedure SetCurrent(FileName: string); overload;
    procedure SetCurrent(index: integer); overload;
    destructor Destroy; override;
  end;

var
  Commentaries : TCommentaries;
  ActiveVerse : TVerse;

function Commentary: TCommentary;

implementation

uses UnitSQLiteEx;

function Commentary: TCommentary;
begin
  Result := Commentaries[Commentaries.Current];
end;

//========================================================================================
//                                     TCommentary
//========================================================================================

constructor TCommentary.Create(filePath: string);
begin
  inherited Create;

  {$ifdef zeos}
    Connection := TZConnection.Create(nil);
    Query := TZReadOnlyQuery.Create(nil);
    Connection.Database := filePath;
    Connection.Protocol := 'sqlite-3';
    Query.Connection := Connection;
  {$else}
    Connection := TSQLite3Connection.Create(nil);
    Connection.CharSet := 'UTF8';
    Connection.DatabaseName := filePath;
    Transaction := TSQLTransaction.Create(Connection);
    Connection.Transaction := Transaction;
    Query := TSQLQuery.Create(nil);
    Query.DataBase := Connection;
  {$endif}

  self.filePath := filePath;
  self.fileName := ExtractFileName(filePath);

  fileFormat   := unbound;
  z            := unboundStringAlias;

  name         := fileName;                                       output(name);
  native       := '';
  abbreviation := '';
  copyright    := '';
  language     := 'english';
  filetype     := '';
  connected    := false;
  loaded       := false;
  RightToLeft  := false;

  OpenDatabase;
end;

procedure TCommentary.OpenDatabase;
var
  FieldNames : TStringList;
  key, value : string;
  dbhandle : Pointer;
begin
  try
    {$ifdef zeos}
      Connection.Connect;
      dbhandle := (Connection.DbcConnection as TZSQLiteConnection).GetConnectionHandle();
    {$else}
      Connection.Open;
      Transaction.Active := True;
      dbhandle := Connection.Handle;
    {$endif}

    if  not Connection.Connected then Exit;
    SQLite3CreateFunctions(dbhandle);
 // Connection.ExecuteDirect('PRAGMA case_sensitive_like = 1');
  except
    output('connection failed ' + self.fileName);
    Exit;
  end;

  try
    try
      Query.SQL.Text := 'SELECT * FROM Details';
      Query.Open;

      try info      := Query.FieldByName('Information').AsString; except end;
      try info      := Query.FieldByName('Description').AsString; except end;
      try name      := Query.FieldByName('Title'      ).AsString; except name := info; end;
      try copyright := Query.FieldByName('Copyright'  ).AsString; except end;
      try language  := Query.FieldByName('Language'   ).AsString; except end;

      connected := true;
    except
      //
    end;
  finally
    Query.Close;
  end;

  try
    try
      Query.SQL.Text := 'SELECT * FROM info';
      Query.Open;

      while not Query.Eof do
        begin
          try key   := Query.FieldByName('name' ).AsString; except end;
          try value := Query.FieldByName('value').AsString; except end;

          if key = 'description'   then name     := value;
          if key = 'detailed_info' then info     := value;
          if key = 'language'      then language := value;

          Query.Next;
        end;

      fileFormat := mybible;
      z := mybibleStringAlias;                                                    /////// alias
      connected := true;
    except
      //
    end;
  finally
    Query.Close;
  end;

  FieldNames := TStringList.Create;
  try Connection.GetTableNames({$ifdef zeos}'',{$endif}FieldNames) except end;
  if FieldNames.IndexOf('commentary') < 0 then connected := false;                /////// z.bible
  FieldNames.Free;

  language := LowerCase(language);
  RightToLeft := GetRightToLeft(language);
  RemoveTags(info);
end;

function TCommentary.EncodeID(id: integer): integer;
begin
  Result := id;
  if fileFormat = mybible then
    if id > 0 then
      if id <= Length(myBibleArray) then
        Result := myBibleArray[id];
end;

function TCommentary.DecodeID(id: integer): integer;
var i : integer;
begin
  Result := id;
  if fileFormat = mybible then
    if id > 0 then
      for i:=1 to Length(myBibleArray) do
        if id = myBibleArray[i] then
          begin
            Result := i;
            Exit;
          end;
end;

function TCommentary.SortingIndex(number: integer): integer;
var
  i : integer;
  l : boolean;
begin
  Result := 100;
  if number <= 0 then Exit;
  l := Orthodox(language);

  for i:=1 to Length(sortArrayEN) do
    if (not l and (number = sortArrayEN[i])) or
           (l and (number = sortArrayRU[i])) then
      begin
        Result := i;
        Exit;
      end;
end;

function TCommentary.GetChapter(Verse: TVerse): TStringArray;
var
  index, i : integer;
  id, chapter : string;
  line : string;
begin
  SetLength(Result,0);

  index := EncodeID(Verse.book);
  id := IntToStr(index);
  chapter := IntToStr(Verse.chapter);

  try
    try
      Query.SQL.Text := 'SELECT * FROM ' + z.bible + ' WHERE ' + z.book + '=' + id + ' AND ' + z.chapter + '=' + chapter;
      Query.Open;

      Query.Last;
      SetLength(Result, Query.RecordCount);
      Query.First;

      for i:=0 to Query.RecordCount-1 do
        begin
          try line := Query.FieldByName(z.text).AsString; except line := '' end;
      //  line = line.replace("\n", "") // ESWORD ?
          Result[i] := line;
          Query.Next;
        end;
    except
      //
    end;
  finally
    Query.Close;
  end;
end;

function TCommentary.GetRange(Verse: TVerse): TStringArray;
var
  index, i : integer;
  id, chapter : string;
  verseNumber, toVerse : string;
  line : string;
begin
  SetLength(Result,0);

  index := EncodeID(Verse.book);
  id := IntToStr(index);
  chapter := IntToStr(Verse.chapter);
  verseNumber := IntToStr(Verse.number);
  toVerse := IntToStr(verse.number + verse.count);

  try
    try
      Query.SQL.Text := 'SELECT * FROM ' + z.bible + ' WHERE ' + z.book + '=' + id +
                        ' AND ' + z.chapter + '=' + chapter +
                        ' AND ' + z.verse + ' >= ' + verseNumber +
                        ' AND ' + z.verse + ' < ' + toVerse;
      Query.Open;

      Query.Last;
      SetLength(Result, Query.RecordCount);
      Query.First;

      for i:=0 to Query.RecordCount-1 do
        begin
          try line := Query.FieldByName(z.text).AsString; except line := '' end;
          Result[i] := line;
          Query.Next;
        end;
    except
      //
    end;
  finally
    Query.Close;
  end;
end;

function TCommentary.GoodLink(Verse: TVerse): boolean;
begin
  Result := Length(GetRange(Verse)) > 0;
end;

function TCommentary.Search(searchString: string; SearchOptions: TSearchOptions; Range: TRange): TContentArray;
var
  Contents : TContentArray;
  queryRange, from, till : string;
  i : integer;
begin
  SetLength(Result,0);
  queryRange := '';

  SetSearchOptions(searchString, SearchOptions);

  if Range.from > 0 then
    begin
      from := IntToStr(EncodeID(Range.from));
      till := IntToStr(EncodeID(Range.till));
      queryRange := ' AND ' + z.book + ' >= ' + from + ' AND ' + z.book + ' <= ' + till;
    end;

  try
    try
      Query.SQL.Text := 'SELECT * FROM ' + z.bible + ' WHERE super(' + z.text + ')=''1''' + queryRange;
      Query.Open;

      Query.Last; // must be called before RecordCount
      SetLength(Contents,Query.RecordCount);
      Query.First;

      for i:=0 to Query.RecordCount-1 do
        begin
          Contents[i].verse := noneVerse;
          try Contents[i].verse.book    := Query.FieldByName(z.book   ).AsInteger; except end;
          try Contents[i].verse.chapter := Query.FieldByName(z.chapter).AsInteger; except end;
          try Contents[i].verse.number  := Query.FieldByName(z.verse  ).AsInteger; except end;
          try Contents[i].text          := Query.FieldByName(z.text   ).AsString;  except end;
          Contents[i].verse.book := DecodeID(Contents[i].verse.book);
          Query.Next;
        end;
    finally
      Query.Close;
    end;
  except
    Exit;
  end;

end;

function TCommentary.GetAll: TContentArray;
var
  Contents : TContentArray;
  i : integer;
begin
  SetLength(Result,0);

  try
    try
      Query.SQL.Text := 'SELECT * FROM ' + z.bible;
      Query.Open;

      Query.Last; // must be called before RecordCount
      SetLength(Contents,Query.RecordCount);
      Query.First;

      for i:=0 to Query.RecordCount-1 do
        begin
          Contents[i].verse := noneVerse;
          try Contents[i].verse.book    := Query.FieldByName(z.book   ).AsInteger; except end;
          try Contents[i].verse.chapter := Query.FieldByName(z.chapter).AsInteger; except end;
          try Contents[i].verse.number  := Query.FieldByName(z.verse  ).AsInteger; except end;
          try Contents[i].text          := Query.FieldByName(z.text   ).AsString;  except end;
          Contents[i].verse.book := DecodeID(Contents[i].verse.book);
          Query.Next;
        end;
    except
      //
    end;
  finally
    Query.Close;
  end;
end;

function TCommentary.ChaptersCount(Verse: TVerse): integer;
var
  index : integer;
  id : string;
begin
  Result := 1;

  index := EncodeID(Verse.book);
  id := IntToStr(index);

  try
    try
      Query.SQL.Text := 'SELECT MAX(' + z.chapter + ') AS Count FROM ' + z.bible + ' WHERE ' + z.book + '=' + id;
      Query.Open;

      try Result := Query.FieldByName('Count').AsInteger; except end;
    except
      //
    end;
  finally
    Query.Close;
  end;
end;

procedure TCommentary.SavePrivate(const IniFile : TIniFile);
begin
  IniFile.WriteBool(FileName, 'Compare', Compare);
end;

procedure TCommentary.ReadPrivate(const IniFile : TIniFile);
begin
  Compare := IniFile.ReadBool(FileName, 'Compare', True);
end;

destructor TCommentary.Destroy;
var
  i : integer;
begin
  Query.Free;
  {$ifndef zeos} Transaction.Free; {$endif}
  Connection.Free;

  inherited Destroy;
end;

//=================================================================================================
//                                         TCommentaries
//=================================================================================================

function Comparison(const Item1: TCommentary; const Item2: TCommentary): integer;
begin
  Result := CompareText(Item1.Name, Item2.Name);
end;

constructor TCommentaries.Create;
begin
  inherited;

  AddCommentaries(GetUserDir + AppName);

  {$ifdef windows} if Self.Count = 0 then {$endif} AddCommentaries(SharePath + 'bibles');
  Sort(Comparison);

  //ReadPrivates;
end;

procedure TCommentaries.AddCommentaries(path: string);
var
  Item : TCommentary;
  List : TStringArray;
  f : string;
begin
  List := GetFileList(path, '*.*');

  for f in List do
    begin
      if Pos('.cmt.',f) = 0 then continue; // '.commentaries.'
      Item := TCommentary.Create(f);
      if Item.connected then Add(Item) else Item.Free;
    end;
end;

procedure TCommentaries.SetCurrent(index: integer);
begin
  Current := index;
  if not Self[Current].GoodLink(ActiveVerse) then ActiveVerse := Self[Current].FirstVerse;
end;

procedure TCommentaries.SetCurrent(FileName: string);
var i : integer;
begin
  Current := 0;
  if Count = 0 then Exit;
  for i:= Count-1 downto 0 do
    if Items[i].FileName = FileName then Current := i;
  SetCurrent(Current);
end;

procedure TCommentaries.SavePrivates;
var
  IniFile : TIniFile;
  i : integer;
begin
  IniFile := TIniFile.Create(ConfigFile);
  for i:=0 to Count-1 do Items[i].SavePrivate(IniFile);
  IniFile.Free;
end;

procedure TCommentaries.ReadPrivates;
var
  IniFile : TIniFile;
  i : integer;
begin
  IniFile := TIniFile.Create(ConfigFile);
  for i:=0 to Count-1 do Items[i].ReadPrivate(IniFile);
  IniFile.Free;
end;

destructor TCommentaries.Destroy;
var i : integer;
begin
  //SavePrivates;
  for i:=0 to Count-1 do Items[i].Free;
  inherited Destroy;
end;

initialization
  Commentaries := TCommentaries.Create;

finalization
  Commentaries.Free;

end.