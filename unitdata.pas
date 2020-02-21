unit UnitData;

interface

uses
  Classes, Fgl, SysUtils, Graphics, FileUtil, IniFiles, UmLib, UnitLang, UnitLib;

const
  ApplicationName = 'Unbound Bible';
  ApplicationVersion = '3.6';
  BibleDirectory = 'bibles';
  TitleDirectory = 'titles';
  LangDirectory = 'localization';
  Untitled = 'Untitled';
  RecentMax = 10;

var
  ApplicationUpdate : boolean = false;
  DefaultFont: TFont;

type
  TFileFormat = (unbound, mysword, mybible);

  TSearchOption = (caseSensitive, wholeWords);
  TSearchOptions = set of TSearchOption;

type
  TRange = record
    from, till : integer;
  end;

type
  TBibleAlias = record
    bible, book, chapter, verse, text, titles, number, name, abbr : string;
  end;

type
  TTitle = record
    name, abbr : string;
    number, sorting : integer;
  end;

  TTitles = array of TTitle;

  TCommentaryAlias = record
    commentary : string;
    id         : string;
    book       : string;
    chapter    : string;
    fromverse  : string;
    toverse    : string;
    data       : string;
  end;

  TDictionaryAlias = record
    dictionary, word, data : string;
  end;

  TVerse = record
    book, chapter, number, count : integer;
  end;

  TBook = class
  public
    title   : string;
    abbr    : string;
    number  : integer;
    id      : integer;
    sorting : integer;
  end;

  TBooks = TFPGList<TBook>;

  TContent = record
    verse : TVerse;
    text : string;
  end;

  TContentArray = array of TContent;

  TCopyOptions = record
    cvAbbreviate  : boolean;
    cvEnumerated  : boolean;
    cvGuillemets  : boolean;
    cvParentheses : boolean;
    cvEnd         : boolean;
  end;

  TLocalizableStrings = record
   Commentary, Confirm, lsFile, Footnote, Found, Language, MoreInfo,
   Narrow, NoModules, NoResults, Overwrite, Save, Strong : string;
 end;

const
  unboundStringAlias : TBibleAlias = (
    bible   : 'Bible';
    book    : 'Book';
    chapter : 'Chapter';
    verse   : 'Verse';
    text    : 'Scripture';
    titles  : 'Titles';
    number  : 'Number';
    name    : 'Name';
    abbr    : 'Abbreviation';
    );

  mybibleStringAlias : TBibleAlias = (
    bible   : 'verses';
    book    : 'book_number';
    chapter : 'chapter';
    verse   : 'verse';
    text    : 'text';
    titles  : 'books_all';
    number  : 'book_number';
    name    : 'long_name';
    abbr    : 'short_name';
    );

  unboundCommentaryAlias : TCommentaryAlias = (
    commentary : 'commentary';
    id         : 'id';
    book       : 'book';
    chapter    : 'chapter';
    fromverse  : 'fromverse';
    toverse    : 'toverse';
    data       : 'data';
    );

  mybibleCommentaryAlias : TCommentaryAlias = (
    commentary : 'commentaries';
    id         : 'id';
    book       : 'book_number';
    chapter    : 'chapter_number_from';
    fromverse  : 'verse_number_from';
//  chapter    : 'chapter_number_to';
    toverse    : 'verse_number_to';
//  marker     : 'marker';
    data       : 'text';
    );

  unboundDictionaryAlias : TDictionaryAlias = (
    dictionary : 'Dictionary';
    word       : 'Word';
    data       : 'Data';
    );

  mybibleDictionaryAlias : TDictionaryAlias = (
    dictionary : 'dictionary';
    word       : 'topic';
    data       : 'definition';
  );

  noneVerse : TVerse = (
    book    : 0;
    chapter : 0;
    number  : 0;
    count   : 0;
    );

  minVerse : TVerse = (
    book    : 1;
    chapter : 1;
    number  : 1;
    count   : 1;
    );

  noneTitle : TTitle = (
    name    : '';
    abbr    : '';
    number  : 0;
    sorting : 0;
    );

var
  ActiveVerse : TVerse;
  Options : TCopyOptions;
  ls : TLocalizableStrings;

  BibleHubArray : array [1..66] of string = (
    'genesis','exodus','leviticus','numbers','deuteronomy','joshua','judges','ruth','1_samuel','2_samuel',
    '1_kings','2_kings','1_chronicles','2_chronicles','ezra','nehemiah','esther','job','psalms','proverbs',
    'ecclesiastes','songs','isaiah','jeremiah','lamentations','ezekiel','daniel','hosea','joel','amos',
    'obadiah','jonah','micah','nahum','habakkuk','zephaniah','haggai','zechariah','malachi','matthew',
    'mark','luke','john','acts','romans','1_corinthians','2_corinthians','galatians','ephesians','philippians',
    'colossians','1_thessalonians','2_thessalonians','1_timothy','2_timothy','titus','philemon','hebrews',
    'james','1_peter','2_peter','1_john','2_john','3_john','jude','revelation'
    );

function unbound2mybible(id: integer): integer;
function mybible2unbound(id: integer): integer;
function IsNewTestament(n: integer): boolean;
procedure CreateDataDirectory;
function ConfigFile: string;
function DataPath: string;
function GetDatabaseList: TStringArray;
procedure LocalizeStrings;

implementation

const
  MaxBooks = 88;

var
  myBibleArray : array [1..MaxBooks] of integer = (
    010,020,030,040,050,060,070,080,090,100,110,120,130,140,150,160,190,220,230,240,
    250,260,290,300,310,330,340,350,360,370,380,390,400,410,420,430,440,450,460,470,
    480,490,500,510,520,530,540,550,560,570,580,590,600,610,620,630,640,650,660,670,
    680,690,700,710,720,730,000,000,000,000,000,000,000,000,000,000,165,468,170,180,
    462,464,466,467,270,280,315,320
    );

function unbound2mybible(id: integer): integer;
begin
  Result := id;
  if (id > 0) and (id <= Length(myBibleArray)) then Result := myBibleArray[id];
end;

function mybible2unbound(id: integer): integer;
var i : integer;
begin
  Result := id;
  if id = 0 then Exit;
  for i:=1 to Length(myBibleArray) do
    if id = myBibleArray[i] then
      begin
        Result := i;
        Exit;
      end;
end;

function IsNewTestament(n: integer): boolean;
begin
  Result := (n >= 40) and (n < 77);
end;

function DataPath: string;
begin
  Result := GetUserDir + ApplicationName;
end;

procedure CreateDataDirectory;
begin
  if not DirectoryExists(DataPath) then ForceDirectories(DataPath);
end;

function GetDatabaseList: TStringArray;
const
  ext : array [1..4] of string = ('.unbound','.bbli','.mybible','.SQLite3');
var
  List : TStringArray;
  s, item : string;
  index : integer = 0;
begin
  List := GetFileList(DataPath, '*.*');
  SetLength(Result, Length(List));

  for item in List do
    for s in ext do
      if Suffix(s, item) then
        begin
          Result[index] := item;
          index += 1;
        end;

  SetLength(Result, index);
end;

procedure CopyDefaultsFiles;
var
  SourcePath : string;
begin
  if not DirectoryExists(DataPath) then ForceDirectories(DataPath);
  SourcePath := SharePath + BibleDirectory;
  if not ApplicationUpdate and (Length(GetDatabaseList) > 0) then Exit;
  CopyDirTree(SourcePath, DataPath, [cffOverwriteFile]);
end;

function ConfigFile: string;
begin
  {$ifdef windows} Result := LocalAppDataPath + ApplicationName + Slash; {$endif}
  {$ifdef unix} Result := GetAppConfigDir(False); {$endif}
  Result += 'config.ini';
end;

procedure SaveConfig;
var IniFile: TIniFile;
begin
  IniFile := TIniFile.Create(ConfigFile);

  IniFile.WriteString('Application', 'Version', ApplicationVersion);
  IniFile.WriteString('Application', 'FontName', DefaultFont.Name);
  IniFile.WriteInteger('Application', 'FontSize', DefaultFont.Size);
  IniFile.WriteInteger('Verse', 'Book', ActiveVerse.book);
  IniFile.WriteInteger('Verse', 'Chapter', ActiveVerse.chapter);
  IniFile.WriteInteger('Verse', 'Number', ActiveVerse.number);
  IniFile.WriteInteger('Verse', 'Count', ActiveVerse.count);

  IniFile.Free;
end;

procedure ReadConfig;
var
  IniFile: TIniFile;
  Version: string;
const
  DefaultFontName = {$ifdef windows} 'Tahoma' {$else} 'default' {$endif};
  DefaultFontSize = 12;
begin
  IniFile := TIniFile.Create(ConfigFile);

  Version := IniFile.ReadString('Application', 'Version', '');
  ApplicationUpdate := ApplicationVersion <> Version;
  DefaultFont.Name := IniFile.ReadString('Application', 'FontName', DefaultFontName);
  DefaultFont.Size := IniFile.ReadInteger('Application', 'FontSize', DefaultFontSize);
  ActiveVerse.book := IniFile.ReadInteger('Verse', 'Book', 0);
  ActiveVerse.chapter := IniFile.ReadInteger('Verse', 'Chapter', 0);
  ActiveVerse.number := IniFile.ReadInteger('Verse', 'Number', 0);
  ActiveVerse.count := IniFile.ReadInteger('Verse', 'Count', 0);

  IniFile.Free;
end;

procedure LocalizeStrings;
begin
  ls.Commentary := T('Commentaries');
  ls.Confirm := T('Confirmation');
  ls.lsFile := T('File');
  ls.Footnote := T('Footnote');
  ls.Found := T('verses found');
  ls.Language := T('Language');
  ls.MoreInfo := T('For more information, choose Menu > Help, then click «Module downloads».');
  ls.NoModules := T('You don''t have any commentary modules.');
  ls.NoResults := T('You search for % produced no results.');
  ls.Overwrite := T('OK to overwrite %s?');
  ls.Save := T('Save changes?');
  ls.Strong := T('Strong''s Dictionary');
  ls.Narrow := T('This search returned too many results.') + ' ' +
               T('Please narrow your search.');
end;

initialization
  DefaultFont := TFont.Create;
  ReadConfig;
  CopyDefaultsFiles;

finalization
  SaveConfig;
  DefaultFont.Free;

end.

