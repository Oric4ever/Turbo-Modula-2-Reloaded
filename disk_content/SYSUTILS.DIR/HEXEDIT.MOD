MODULE HexEdit;
FROM SYSTEM IMPORT BYTE, ADR;
FROM Terminal IMPORT WriteChar, ReadChar, WriteLn, GotoXY, numRows, numCols, ClearScreen;
FROM Files IMPORT FILE, Open, Close, FileSize, ReadBytes, WriteBytes, SetPos;
FROM ComLine IMPORT PromptFor;

CONST ESC = 033C;
TYPE PrevNext = (NEXT, PREVIOUS);

VAR mem : ARRAY [0..7FFFH] OF CHAR;
    bufSize: CARDINAL;
    sectStart, offset: CARDINAL;
    fileSize, bufPos: LONGINT;
    file : FILE;
    dirty: BOOLEAN;
    filename: ARRAY [0..20] OF CHAR;
    char, char2: CHAR;

PROCEDURE ReadFile(filename: ARRAY OF CHAR);
BEGIN
  IF NOT Open(file, filename) THEN
    WRITE('Cannot open file ',filename);
    HALT
  END;
  fileSize:= FileSize(file);
  bufPos  := 0L;
  bufSize := ReadBytes(file, ADR(mem), SIZE(mem));
END ReadFile;

PROCEDURE CloseFile;
BEGIN
  IF dirty THEN
    SetPos(file, bufPos);
    WriteBytes(file, ADR(mem), bufSize);
  END;
  Close(file)
END CloseFile;

PROCEDURE HexByte(val: CARDINAL);
  PROCEDURE HexDigit(val: CARDINAL);
  BEGIN
    IF val < 10
    THEN WriteChar(CHR(val    + ORD('0')))
    ELSE WriteChar(CHR(val-10 + ORD('A')))
    END
  END HexDigit;
BEGIN
  HexDigit(val DIV 16); HexDigit(val MOD 16)
END HexByte;

PROCEDURE HexWord(val: CARDINAL);
BEGIN
  HexByte(val DIV 256); HexByte(val MOD 256)
END HexWord;

PROCEDURE ViewChar(char: CHAR);
BEGIN
  IF (char < ' ') OR (char >= 177C) THEN char := '.' END;
  WriteChar(char)
END ViewChar;

PROCEDURE View(startOffset: CARDINAL);
VAR row, col,i : CARDINAL;
    rowOffset  : CARDINAL;
    char       : CHAR;
BEGIN
  ClearScreen;
  FOR row := 0 TO 31 DO
    GotoXY(0, row);
    rowOffset := startOffset + row * 16;
    HexWord(rowOffset);
    FOR i:=0 TO 15 DO
      IF i MOD 4 = 0 THEN WriteChar(' ') END;
      WriteChar(' '); HexByte(ORD(mem[rowOffset+i]));
    END;
    WriteChar(' '); WriteChar(' ');
    FOR i:=0 TO 15 DO ViewChar(mem[rowOffset+i]) END;
  END
END View;

PROCEDURE hexVal(char: CHAR): CARDINAL;
BEGIN
  IF (char >= '0') AND (char <= '9')
  THEN RETURN ORD(char) - ORD('0')
  ELSE RETURN ORD(char) - ORD('A') + 10
  END;
END hexVal;

PROCEDURE SetXY(offset: CARDINAL);
VAR x,y : CARDINAL;
BEGIN
  x := 6 + (offset MOD 16) * 3 + (offset MOD 16) DIV 4;
  y := offset DIV 16;
  GotoXY(x,y);
END SetXY;

PROCEDURE ChangeSector(prevOrNext: PrevNext);
BEGIN
  ReadChar(char); IF char <> '~' THEN RETURN END;
  IF prevOrNext = NEXT THEN
    IF sectStart + 512 < bufSize THEN INC(sectStart,512) END
  ELSE
    IF sectStart > 511 THEN DEC(sectStart,512) END
  END;
  View(sectStart)
END ChangeSector;

PROCEDURE ReadCommand;
BEGIN
  ReadChar(char);
  IF char <> '[' THEN RETURN END;
  ReadChar(char);
  CASE char OF
  | 'A' : IF offset    > 15  THEN DEC(offset,16) END
  | 'B' : IF offset+16 < 512 THEN INC(offset,16) END
  | 'C' : IF offset+1  < 512 THEN INC(offset)    END
  | 'D' : IF offset    > 0   THEN DEC(offset)    END
  | '5' : ChangeSector(PREVIOUS)
  | '6' : ChangeSector(NEXT)
  END;
  SetXY(offset);
END ReadCommand;

PROCEDURE ChangeByte;
VAR char2: CHAR;
BEGIN
  WriteChar(CAP(char));
  REPEAT
    ReadChar(char2);
    char2 := CAP(char2);
  UNTIL (char2>='0') AND (char2<='9')
     OR (char2>='A') AND (char2<='F') OR (char2 = ESC);
  IF char2 = ESC THEN View(sectStart); SetXY(offset); RETURN END;
  WriteChar(char2);
  mem[sectStart+offset] := CHR(hexVal(char) * 16 + hexVal(char2));
  dirty := TRUE;
  GotoXY(58 + offset MOD 16, offset DIV 16); ViewChar(mem[sectStart+offset]);
  INC(offset); IF offset = 512 THEN offset := 0 END;
  SetXY(offset)
END ChangeByte;

BEGIN
  PromptFor("File to edit: ", filename);
  ReadFile(filename);
  sectStart := 0;
  offset    := 0;
  View(sectStart);
  SetXY(offset);
  LOOP
    ReadChar(char);
    CASE char OF
    | ESC     : ReadCommand
    | '0'..'9',
      'A'..'F',
      'a'..'f': ChangeByte
    | 'X','x' : ClearScreen; CloseFile; EXIT
    | 'Q','q' : ClearScreen;
               IF dirty THEN
                 WRITE('Buffer has been modified, abandon changes ? (Y/N) ');
                 ReadChar(char);
                 IF CAP(char)='N' THEN CloseFile END
               END;
               EXIT
    END
  END
END HexEdit.                                                          