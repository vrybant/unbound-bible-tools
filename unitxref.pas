unit UnitXref;

interface

uses
  Classes, Fgl, SysUtils, UnitModule, UnitData, UmLib;

type
  TXrefAlias = record
    xrefs, book, chapter, verse, xbook, xchapter, xfromverse, xtoverse, votes : string;
  end;

  TXref = class(TModule)
  private
    z : TXrefAlias;
    function GetData(Verse: TVerse): TVerseArray;
  public
    constructor Create(filePath: string);
  end;

  TXrefs = class(TFPGList<TXref>)
  private
    procedure Load;
  public
    constructor Create;
    function GetData(Verse: TVerse; language: string): TVerseArray;
    destructor Destroy; override;
  end;

var
  Xrefs : TXrefs;

implementation

const
  unboundAlias : TXrefAlias = (
    xrefs      : 'xrefs';
    book       : 'Book';
    chapter    : 'Chapter';
    verse      : 'Verse';
    xbook      : 'xbook';
    xchapter   : 'xchapter';
    xfromverse : 'xfromverse';
    xtoverse   : 'xtoverse';
    votes      : 'Votes';
   );

  mybibleAlias : TXrefAlias = (
    xrefs      : 'cross_references';
    book       : 'book';
    chapter    : 'chapter';
    verse      : 'verse';
//  toverse    : 'verse_end';
    xbook      : 'book_to';
    xchapter   : 'chapter_to';
    xfromverse : 'verse_to_start';
    xtoverse   : 'verse_to_end';
    votes      : 'votes';
   );

//========================================================================================
//                                     TXref
//========================================================================================

constructor TXref.Create(filePath: string);
begin
  inherited Create(filePath);
  z := unboundAlias;
  if format = mybible then z := mybibleAlias;
  if connected and not TableExists(z.xrefs) then connected := false;
end;

function TXref.GetData(Verse: TVerse): TVerseArray;
var
  V : TVerse;
  v_from, v_to : string;
  i, id, toverse, votes, count : integer;
begin
  SetLength(Result,0);

  id := EncodeID(Verse.book);
  v_from := ToStr(Verse.number);
  v_to   := ToStr(Verse.number + Verse.count - 1);

  try
    try
        Query.SQL.Text := 'SELECT * FROM ' + z.xrefs +
          ' WHERE '  + z.book    + ' = '  + ToStr(id) +
            ' AND '  + z.chapter + ' = '  + ToStr(Verse.chapter) +
            ' AND (' + z.verse + ' BETWEEN ' + v_from + ' AND ' + v_to + ') ';

        Query.Open;
        Query.Last;
        SetLength(Result, Query.RecordCount);
        Query.First;

        count := 0;
        for i:=0 to Query.RecordCount-1 do
          try
            v := noneVerse;
            try v.book    := Query.FieldByName(z.xbook     ).AsInteger; except end;
            try v.chapter := Query.FieldByName(z.xchapter  ).AsInteger; except end;
            try v.number  := Query.FieldByName(z.xfromverse).AsInteger; except end;
            try toverse   := Query.FieldByName(z.xtoverse  ).AsInteger; except end;
            try votes     := Query.FieldByName(z.votes     ).AsInteger; except end;

            if votes <= 1 then continue;

            v.book := DecodeID(v.book);
            if toverse = 0 then v.count := 1
               else v.count := toverse - v.number + 1;

            Result[count] := v;
            count += 1;
          finally
            Query.Next;
          end;
        SetLength(Result, count);
    except
      //
    end;
  finally
    Query.Close;
  end;
end;

//=================================================================================================
//                                         TXrefs
//=================================================================================================

constructor TXrefs.Create;
begin
  inherited;
  Load;
end;

procedure TXrefs.Load;
var
  Item : TXref;
  List : TStringArray;
  f : string;
begin
  List := GetDatabaseList;

  for f in List do
    begin
      if Pos('.xrefs.',f) = 0 then continue; // .crossreferences.
      Item := TXref.Create(f);
      if Item.connected then Add(Item) else Item.Free;
    end;
end;

function TXrefs.GetData(Verse: TVerse; language: string): TVerseArray;
var
  filename : string;
  i : integer;
begin
  SetLength(Result,0);
  if self.Count = 0 then Exit;
  filename := iif( Prefix('ru', language), 'obru.xrefs.unbound', 'ob.xrefs.unbound');

  for i:=0 to Count-1 do
    if Items[i].filename = filename then
        Result := Items[i].GetData(Verse);
end;

destructor TXrefs.Destroy;
var i : integer;
begin
  for i:=0 to Count-1 do Items[i].Free;
  inherited Destroy;
end;

initialization
  Xrefs := TXrefs.Create;

finalization
  Xrefs.Free;

end.