IMPLEMENTATION MODULE FileName;


PROCEDURE CheckFileName(filename: ARRAY OF CHAR): FileNameType;
VAR i: CARDINAL;
    char : CHAR;
    extension, wildcard : BOOLEAN;
BEGIN
  i := 0;
  extension := FALSE;
  wildcard := FALSE;
  WHILE (i <= 19) AND (filename[i] <> 0C) DO
    char := filename[i];
    IF ((char = '.') AND extension)
    OR ((char = ':') AND (i <> 1))
    OR (char = '[') OR (char = ']') OR (char = ',')
    OR ((char >= ';') AND (char <= '>'))
    THEN RETURN INVALID END;

    wildcard  := wildcard OR (char = '*') OR (char = '?');
    extension := extension OR (char = '.');
    INC(i);
  END;
  IF filename[0] = 0C THEN RETURN NONAME END;
  IF wildcard THEN RETURN WILDCARD END;
  RETURN NORMAL
END CheckFileName;


PROCEDURE BuildStdFileName(VAR filename: ARRAY OF CHAR; defaultExt: ARRAY OF CHAR; forceDefaultExt: BOOLEAN);
VAR i, j, k: CARDINAL;
    name   : ARRAY [0..15] OF CHAR;
    char   : CHAR;
BEGIN
  i := 0; j := 0; k := 0;
  (* copy basename *)
  REPEAT
    char    := CAP(filename[i]);
    name[j] := char;
    INC(i); INC(j);
  UNTIL (char = 0C) OR (char = '.') OR (j = 9);
  name[j-1] := '.';
  (* skip chars if more than eight *)
  WHILE (char <> '.') AND (char <> 0C) AND (i <= HIGH(filename)) DO
    char := filename[i];
    INC(i);
  END;
  (* use default extension if none present *)
  IF (char <> '.') OR forceDefaultExt THEN
    filename := defaultExt;
    i := 0;
  END;
  (* copy extension *)
  WHILE (k <= 2) AND (i <= HIGH(filename)) DO
    name[j] := CAP(filename[i]);
    INC(i); INC(j); INC(k);
  END;
  name[j] := 0C;
  filename := name;
END BuildStdFileName;

END FileName.
                                                                                                        