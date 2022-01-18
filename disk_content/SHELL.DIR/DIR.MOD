MODULE Dir;
IMPORT Texts, Terminal, ComLine, FATDIR;
FROM SYSTEM IMPORT ADR;

CONST CTRLC = 03C; BackSpace = 10C; TAB = 11C; LF = 12C; CR = 15C;
      XOFF = 23C; CTRLX = 30C; EOT = 32C; ESC = 033C; DEL = 177C;

CONST USERNUM = 32; DMAOFFSET = 26; SEARCHFIRST = 17; SEARCHNEXT = 18;

TYPE Type    = (MODule, MCD, DEF, SYM, BAK, DOLLAR, AROBAS);
     Types   = SET OF Type;
     Name    = FATDIR.EntryNameAndType;
     NamePtr = POINTER TO Name;

VAR catalog: ARRAY [1..256] OF Name;
    nbFiles: CARDINAL;
    sorted : ARRAY [1..256] OF NamePtr;

PROCEDURE ReadDir(filename: ARRAY OF CHAR);
VAR entry  : FATDIR.Entry;
    dirMask: FATDIR.EntryNameAndType;
BEGIN
  FATDIR.Build83Name(filename,"EXT",FALSE,dirMask);
  FATDIR.InitFind(dirMask.fullName);
  nbFiles := 0;
  WHILE (nbFiles <= 255) AND FATDIR.FindNextMatch(entry) DO
    IF  (entry.desc.nameAndType.fullName # ".          ")
    AND (entry.desc.nameAndType.fullName # "..         ")
    THEN
      INC(nbFiles);
      catalog[nbFiles] := entry.desc.nameAndType;
    END;
  END;
END ReadDir;


PROCEDURE SortDir;

  PROCEDURE QuickSort(low, high: CARDINAL);
  VAR i,j : CARDINAL;
      pivot, tmp : NamePtr;
  BEGIN
    i := low;
    j := high;
    pivot := sorted[(low + high) DIV 2];
    REPEAT
      WHILE sorted[i]^.fullName < pivot^.fullName DO INC(i) END;
      WHILE sorted[j]^.fullName > pivot^.fullName DO DEC(j) END;
      IF i <= j THEN
        tmp := sorted[i]; sorted[i] := sorted[j]; sorted[j] := tmp;
        INC(i); DEC(j);
      END;
    UNTIL i > j;
    IF low < j  THEN QuickSort(low, j)  END;
  IF i < high THEN QuickSort(i, high) END;
  END QuickSort;

VAR i, j: CARDINAL;
BEGIN
  i := 1; j := nbFiles;
  WHILE i <= j DO sorted[i] := ADR(catalog[i]); INC(i) END;
  QuickSort(1, nbFiles);
END SortDir;


VAR dirMask  : ARRAY [0..15] OF CHAR;
    fileIndex, nbExts : CARDINAL;
    baseName : FATDIR.BaseName;
    extension: FATDIR.Extension;
    types    : Types;

PROCEDURE DisplayType(type: FATDIR.Extension);
BEGIN
  Texts.SetCol     (Texts.output, 9+nbExts*4);
  Texts.WriteString(Texts.output, type);
  INC(nbExts);
END DisplayType;

BEGIN
  Texts.ReadString(ComLine.commandLine, dirMask);
  IF dirMask = "" THEN dirMask := "*.*" END;
  ReadDir(dirMask);
  IF nbFiles <> 0 THEN
    SortDir;
    fileIndex := 1;
    REPEAT
      baseName := sorted[fileIndex]^.baseName;
      Texts.WriteString(Texts.output, baseName);
      (* Display unknown extensions first, and memorize known ones *)
      nbExts := 0; types := Types{};
      REPEAT
        extension := sorted[fileIndex]^.extension;
        IF    extension = "MOD" THEN INCL(types, MODule)
        ELSIF extension = "MCD" THEN INCL(types, MCD)
        ELSIF extension = "DEF" THEN INCL(types, DEF)
        ELSIF extension = "SYM" THEN INCL(types, SYM)
        ELSIF extension = "BAK" THEN INCL(types, BAK)
        ELSIF extension = "$$$" THEN INCL(types, DOLLAR)
        ELSIF extension = "@@@" THEN INCL(types, AROBAS)
        ELSE DisplayType(extension)
        END;
        INC(fileIndex);
      UNTIL (fileIndex > nbFiles) OR (sorted[fileIndex]^.baseName <> baseName);
      (* then display memorized extensions *)
      IF MODule IN types THEN DisplayType("MOD") END;
      IF MCD    IN types THEN DisplayType("MCD") END;
      IF DEF    IN types THEN DisplayType("DEF") END;
      IF SYM    IN types THEN DisplayType("SYM") END;
      IF BAK    IN types THEN DisplayType("BAK") END;
      IF DOLLAR IN types THEN DisplayType("$$$") END;
      IF AROBAS IN types THEN DisplayType("@@@") END;
      Texts.WriteLn(Texts.output);
    UNTIL (fileIndex > nbFiles);
    Texts.CloseText  (Texts.output);
  ELSE
    Terminal.WriteString("No matching files.");
    Terminal.WriteLn;
  END;
END Dir.
