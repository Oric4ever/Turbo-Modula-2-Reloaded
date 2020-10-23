IMPLEMENTATION MODULE EDITOR;
FROM SYSTEM  IMPORT ADR,MOVE,BADOVERLAY;
FROM STORAGE IMPORT ALLOCATE,FREEMEM,MARK,RELEASE;
IMPORT EDITDISK;
IMPORT EDIT2;
IMPORT Terminal;
IMPORT ComLine;

CONST CTRLC = 03C; TAB = 11C; LF = 12C; CR = 15C; DEL = 177C;

TYPE Data = RECORD
              dummy     : ARRAY [0..62] OF CARDINAL;
              highlight : ARRAY [0..7] OF CHAR;
              normal    : ARRAY [0..7] OF CHAR;
            END;

VAR
(*  2 *) global2 : CharPtr;
(*  3 *) global3 : CharPtr;
(*  4 *) editBuffer : ADDRESS;
(*  5 *) endBuffer : ADDRESS;
(*  6 *) global6 : ADDRESS;
(*  7 *) global7 : ADDRESS;
(*  8 *) currentCol : CARDINAL;
(*  9 *) currentRow : CARDINAL;
(* 10 *) global10: CARDINAL;
(* 11 *) numRows: CARDINAL;
(* 12 *) numCols: CARDINAL;
(* 13 *) global13: CARDINAL;
(* 14 *) nbSectors: CARDINAL;
(* 15 *) global15: CARDINAL;
(* 16 *) global16: CARDINAL;
(* 17 *) global17: BOOLEAN;
(* 18 *) global18: BOOLEAN;
(* 19 *) global19: BOOLEAN;
(* 20 *) global20: BOOLEAN;
(* 21 *) global21: BOOLEAN;
(* 22 *) global22: BOOLEAN;
(* 23 *) global23: BOOLEAN;
(* 24 *) global24: CARDINAL;
(* 25 *) global25: POINTER TO ARRAY [0..20] OF CHAR;
(* 26 *) global26: POINTER TO ARRAY [0..78] OF CHAR;
(* 27 *) rowsLengths: POINTER TO ARRAY [0..99] OF CARDINAL;
(* 28 *) insertMode: BOOLEAN;
(* 29 *) insertDelete: BOOLEAN;
(* 30 *) keyAvailable: BOOLEAN;
(* 31 *) breakKey : BOOLEAN;
(* 32 *) keyBuf   : ARRAY [0..15] OF CHAR;
(* 33 *) putIndx  : CARDINAL;
(* 34 *) getIndx  : CARDINAL;
(* 35 *) keyCount : CARDINAL;
(* 36 *) pendingDeleteChar: BOOLEAN;

         data [0348H]: Data;

(* proc 7 *)
PROCEDURE FindForward(ptr: CharPtr; size: CARDINAL; char: CHAR): ADDRESS;
BEGIN
  WHILE (size <> 0) AND (ptr^[0] <> char) DO
    DEC(size);
    ptr := ADDRESS(ptr) + 1;
  END;
  IF size <> 0 THEN RETURN ptr ELSE RETURN NIL END;
END FindForward;

(* proc 8 *)
PROCEDURE FindBackward(ptr: CharPtr; size: CARDINAL; char: CHAR): ADDRESS;
BEGIN
  WHILE (size <> 0) AND (ptr^[0] <> char) DO
    DEC(size);
    ptr := ADDRESS(ptr) - 1;
  END;
  IF size <> 0 THEN RETURN ptr ELSE RETURN NIL END;
END FindBackward;

(* proc 16 *)
PROCEDURE proc16(char: CHAR): CHAR;
BEGIN
  IF char < ' ' THEN RETURN CHR(ORD(char)+64) ELSE RETURN CAP(char) END;
END proc16;

(* proc 25 *)
PROCEDURE pollKeyboard;
VAR char: CHAR;
BEGIN
  IF keyCount < 16 THEN
    Terminal.BusyRead(char);
    IF char <> 0C THEN
      INC(keyCount);
      keyBuf[putIndx] := char;
      putIndx := (putIndx + 1) MOD 16;
      keyAvailable := TRUE;
      IF (char = CTRLC) OR (char = 14C) OR (char = 22C) THEN
        breakKey := TRUE
      END;
    END;
  END;
END pollKeyboard;

(* proc 15 *)
PROCEDURE GetKey(): CHAR;
VAR char: CHAR;
BEGIN
  IF keyAvailable THEN
    DEC(keyCount);
    char    := keyBuf[getIndx];
    getIndx := (getIndx + 1) MOD 16;
    keyAvailable := keyCount <> 0;
    IF NOT keyAvailable THEN breakKey := FALSE END;
  ELSE
    Terminal.ReadChar(char);
    breakKey := (char = CTRLC) OR (char = 14C) OR (char = 22C);
  END;
  RETURN char
END GetKey;

(* proc 26 *)
PROCEDURE initKeyBuffer;
BEGIN
  keyCount := 0;
  putIndx  := 0;
  getIndx  := 0;
  keyAvailable:= FALSE;
  breakKey := FALSE;
END initKeyBuffer;

(* proc 27 *)
PROCEDURE WriteSpaces(n: CARDINAL);
BEGIN
  WHILE n<>0 DO Terminal.WriteChar(' '); DEC(n) END;
END WriteSpaces;

(* proc 28 *)
PROCEDURE proc28(param3: ADDRESS; param2,param1 : CARDINAL): CARDINAL;
VAR local2: CARDINAL;
    local3: CARDINAL;
    local4: CARDINAL;
    local5: WORD;
BEGIN
  IF EDIT2.global2 THEN
    local2 := FindForward(param3, 65535, CR);
    IF (global6 < local2) AND (global7 > param3) THEN
      IF global6 > param3 THEN
        local5   := global6^;
        global6^ := 0A0DH;
        local2   := global6;
        param2   := EDITDISK.proc13(param3,param2,param1,ADR(data.highlight),ADR(data.normal));
        global6^ := local5;
        param3   := global6;
      END;
      Terminal.Highlight;
      local3 := ADR(data.normal);
      local4 := ADR(data.highlight);
      IF global7 < local2 THEN
        local5   := global7^;
        global7^ := 0A0DH;
        local2   := global7;
        param2   := EDITDISK.proc13(param3,param2,param1,ADR(data.normal),ADR(data.highlight));
        global7^ := local5;
        param3   := global7;
        Terminal.Normal;
        local3   := ADR(data.highlight);
        local4   := ADR(data.normal);
      END;
      param2 := EDITDISK.proc13(param3,param2,param1,local3,local4);
      Terminal.Normal;
      RETURN param2;
    END;
  END;
  RETURN EDITDISK.proc13(param3,param2,param1,ADR(data.highlight),ADR(data.normal))
END proc28;

(* proc 4 *)
PROCEDURE proc4(ptr: CharPtr; column, row: CARDINAL);
VAR local2: CARDINAL;
BEGIN
  IF (rowsLengths^[row] <> 0) OR (ptr^[0] <> CR) THEN
    Terminal.GotoXY(column, row);
    local2 := proc28(ptr, column, numCols);
    IF local2 < rowsLengths^[row] THEN
      IF Terminal.clearEol IN Terminal.available THEN
        Terminal.ClearToEOL
      ELSE WriteSpaces(rowsLengths^[row] - local2)
      END;
    END;
    rowsLengths^[row] := local2;
  ELSE
    rowsLengths^[row] := column
  END;
END proc4;

(* proc 1 *)
PROCEDURE Proc1(str: ARRAY OF CHAR; param1: CARDINAL);
BEGIN
  Terminal.Highlight;
  rowsLengths^[0] := numCols + 1;
  str[HIGH(str)] := CR;
  proc4(ADR(str), param1, 0);
  Terminal.Normal;
END Proc1;

(* proc 14 *)
PROCEDURE Proc14;
BEGIN
  IF ADDRESS(global2) >= editBuffer + global15 * 5 DIV 4 THEN
    EDITDISK.proc3;
  ELSE
    EDITDISK.proc11("Buffer is full")
  END;
END Proc14;

(* proc 29 *)
PROCEDURE findLineFeed(param1: ADDRESS): ADDRESS;
BEGIN
  RETURN FindBackward(param1, 65535, LF) + 1
END findLineFeed;

(* proc 30 *)
PROCEDURE findReturn(param1: ADDRESS): ADDRESS;
BEGIN
  RETURN FindForward(param1, 65535, CR) + 2
END findReturn;

(* proc 31 *)
PROCEDURE proc31(param1: ADDRESS): CARDINAL;
BEGIN
  RETURN EDITDISK.global3 * global15 + param1 - editBuffer
END proc31;

(* proc 13 *)
PROCEDURE Proc13(param1: ADDRESS);
BEGIN
  global18 := TRUE;
  IF proc31(param1) < global24 THEN global24 := proc31(param1) END;
END Proc13;

(* proc 3 *)
PROCEDURE Proc3;
VAR local2 : ADDRESS;
BEGIN
  global2^[0] := CR;
  Terminal.GotoXY(0,currentRow);
  local2 := proc28(findLineFeed(ADDRESS(global2)-1), 0, numCols);
  proc4(global3, currentCol, currentRow);
END Proc3;

(* proc 32 *)
PROCEDURE proc32;
  (* proc 33 *)
  PROCEDURE proc33(param2, param1 : CARDINAL);
  BEGIN
    REPEAT
      global26^[param1] := CHR(param2 MOD 10 + ORD('0'));
      param2 := param2 DIV 10;
      DEC(param1);
    UNTIL param2 = 0;
  END proc33;
VAR local2 : ARRAY [0..5] OF CHAR;
    overwriteMsg : ARRAY [0..8] OF CHAR;
BEGIN
  global26^:= "                         Line        Col       Char         Indent   Insert   ";
  local2   := "      ";
  overwriteMsg   := "Overwrite";
  MOVE(global25, ADR(global26^)+6, 16);
  proc33(global10, 33);
  proc33(currentCol+1, 43);
  proc33(proc31(global2)+1, 57);
  IF NOT global20 THEN MOVE(ADR(local2), ADR(global26^[60]), 6) END;
  IF NOT insertMode THEN MOVE(ADR(overwriteMsg), ADR(global26^[69]), 9) END;
  Proc1(global26^, 0);
END proc32;

(* proc 2 *)
PROCEDURE Proc2;
VAR local2 : ADDRESS;
    local3 : CARDINAL;
BEGIN
  global23 := TRUE;
  global22 := FALSE;
  Proc3;
  local2 := findLineFeed(ADDRESS(global2) - 1);
  local3 := currentRow;
  WHILE local3 > 1 DO
    local2 := findLineFeed(ADDRESS(local2) - 2);
    DEC(local3);
  END;
  pollKeyboard;
  WHILE (local3 <= numRows) AND ((NOT breakKey) OR (NOT keyAvailable)) DO
    IF local3 = currentRow THEN
      local2 := global3
    ELSE proc4(local2, 0, local3)
    END;
    local2 := findReturn(local2);
    INC(local3);
    pollKeyboard;
  END;
  global22 := local3 > numRows;
END Proc2;

(* proc 34 *)
PROCEDURE proc34;
VAR local2,local3: ADDRESS;
BEGIN
  IF NOT global22 THEN Proc2; RETURN END;
  local2 := global3;
  global23 := FALSE;
  Proc3;
  local3 := currentRow;
  WHILE (local3 < numRows) AND (NOT keyAvailable) DO
    INC(local3);
    local2 := findReturn(local2);
    proc4(local2, 0, local3);
    pollKeyboard;
  END;
  global23 := local3 >= numRows;
END proc34;

(* proc 6 *)
PROCEDURE Proc6(param2, param1: ADDRESS): ADDRESS;
VAR local2: ADDRESS;
BEGIN
  local2 := 0;
  param2 := findReturn(param2);
  WHILE param2 <= param1 + 1 DO
    INC(local2);
    param2 := findReturn(param2);
  END;
  RETURN local2;
END Proc6;

(* proc 35 *)
PROCEDURE proc35(param1: CharPtr);
BEGIN
  IF param1^[0] = TAB THEN currentCol := (currentCol DIV 8 + 1) * 8 ELSE INC(currentCol) END;
END proc35;

(* proc 5 *)
PROCEDURE Proc5;
VAR local2: ADDRESS;
BEGIN
  currentCol := 0;
  local2 := findLineFeed(ADDRESS(global2) - 1);
  WHILE local2 <> global2 DO
    proc35(local2);
    INC(local2);
  END;
END Proc5;

(* proc 36 *)
PROCEDURE charType(ptr: CharPtr): CharType;
VAR char: CHAR;
BEGIN
  char := CAP(ptr^[0]);
  IF (ORD(char) - ORD('A') <= 25) OR (ORD(char) - ORD('0') <= 9) THEN
    RETURN ALPHANUM
  END;
  IF char > ' ' THEN RETURN OTHER END;
  IF ORD(char) IN {10,13} THEN RETURN CRLF END;
  RETURN CONTROL;
END charType;

(*  proc 9 *)
PROCEDURE Proc9(size: CARDINAL);
VAR local2: ADDRESS;
BEGIN
  local2 := global3;
  MOVE(global3, global2, size);
  global2 := ADDRESS(global2) + size;
  global3 := ADDRESS(global3) + size;
  IF (global6 >= local2) AND (global6 < ADDRESS(global3)) THEN
    global6 := global6 - (ADDRESS(global3) - ADDRESS(global2));
  END;
  IF (global7 > local2) AND (global7 <= ADDRESS(global3)) THEN
    global7 := global7 - (ADDRESS(global3) - ADDRESS(global2));
  END;
END Proc9;

(* proc 10 *)
PROCEDURE Proc10(param1: CARDINAL);
VAR local2 : ADDRESS;
BEGIN
  local2  := global2;
  global3 := ADDRESS(global3) - param1;
  global2 := ADDRESS(global2) - param1;
  MOVE(global2, global3, param1);
  IF (global6 >= ADDRESS(global2)) AND (global6 < local2) THEN
    global6 := global6 + (ADDRESS(global3) - ADDRESS(global2))
  END;
  IF (global7 > ADDRESS(global2)) AND (global7 <= local2) THEN
    global7 := global7 + (ADDRESS(global3) - ADDRESS(global2))
  END;
END Proc10;

(* proc 37 *)
PROCEDURE proc37(line: CARDINAL);
BEGIN
  IF line < numRows THEN 
    MOVE(ADR(rowsLengths^[line]), ADR(rowsLengths^[line+1]), (numRows-line)*2);
  END;
  rowsLengths^[line] := 0;
END proc37;

(* proc 38 *)
PROCEDURE proc38(line: CARDINAL);
BEGIN
  IF line < numRows THEN
    MOVE(ADR(rowsLengths^[line+1]),ADR(rowsLengths^[line]), (numRows-line)*2)
  END;
  rowsLengths^[numRows] := 0;
END proc38;

(* proc 39 *)
PROCEDURE scrollDown;
VAR local2 : ADDRESS;
    local3 : CARDINAL;
BEGIN
  IF insertDelete THEN
    Terminal.GotoXY(0,1);
    Terminal.DeleteLine;
    proc38(1);
  ELSE
    Terminal.GotoXY(0,numRows);
    Terminal.WriteLn;
    proc38(0);
  END;
  local2 := global3;
  local3 := currentRow;
  WHILE local3 < numRows DO
    local2 := findReturn(local2);
    INC(local3);
  END;
  proc4(local2, 0, numRows)
END scrollDown;

(* proc 40 *)
PROCEDURE scrollUp;
VAR local2 : ADDRESS;
    local3 : CARDINAL;
BEGIN
  IF insertDelete THEN
    Terminal.GotoXY(0,1);
    Terminal.InsertLine;
    proc37(1);
    IF currentRow = 1 THEN Proc3
    ELSE
      local3 := currentRow;
      local2 := findLineFeed(global2);
      REPEAT
        local2 := findLineFeed(local2 - 2);
        DEC(local3);
      UNTIL local3 = 1;
      proc4(local2, 0, 1)
    END;
  ELSE
    Proc2
  END;
END scrollUp;

(* proc 41 *)
PROCEDURE proc41(char: CHAR);
VAR local2 : CharPtr;
    local3 : CHAR;
BEGIN
  IF ADDRESS(global2) + 8 >= ADDRESS(global3) THEN Proc14 END;
  Proc13(global2);
  global2^[0] := char;
  global2 := ADDRESS(global2)+1;
  IF char = CR THEN
    global2^[0] := LF;
    proc4(ADDRESS(global2)-1, currentCol, currentRow);
    global2 := ADDRESS(global2) + 1;
    INC(global10);
    currentCol := 0;
    INC(currentRow);
    Terminal.WriteLn;
    IF global20 THEN
      local2 := findLineFeed(ADDRESS(global2) - 2);
      LOOP
        local3 := local2^[0];
        IF (local3 <> ' ') AND (local3 <> TAB) THEN EXIT END;
        IF ADDRESS(global2) + 1 >= ADDRESS(global3) THEN Proc14 END;
        global2^[0] := local3;
        global2 := ADDRESS(global2)+1;
        proc35(local2);
        local2 := ADDRESS(local2)+1;
      END;
    END;
    IF (currentRow < numRows) AND insertDelete THEN
      Terminal.InsertLine;
      proc37(currentRow);
      Proc3
    ELSE proc34 
    END;
  ELSE
    global3 := ADDRESS(global3) + ORD((NOT insertMode) AND (global3^[0] <> CR));
    local2  := ADDRESS(global3) - 1;
    local2^[0] := char;
    proc4(local2, currentCol, currentRow);
    proc35(local2);
  END;
END proc41;

(* proc 19 *)
PROCEDURE cursorLeft;
BEGIN
  IF ADDRESS(global2) <= editBuffer THEN EDITDISK.proc12; RETURN END;
  IF currentCol = 0 THEN
    Proc10(2);
    DEC(global10);
    Proc5;
    DEC(currentRow);
  ELSE
    Proc10(1);
    IF global2^[0] = TAB THEN Proc5 ELSE DEC(currentCol) END;
  END;
END cursorLeft;

(* proc 20 *)
PROCEDURE cursorRight;
BEGIN
  IF global3^[0] = CR THEN
    IF global3 <> endBuffer THEN
      Proc9(2);
      INC(global10);
      INC(currentRow);
      currentCol := 0;
    END;
  ELSE proc35(global3); Proc9(1)
  END;
END cursorRight;

(* proc 18 *)
PROCEDURE Proc18;
BEGIN
  Proc13(global2);
  IF global6 = global3 THEN INC(global6) END;
  global3 := ADDRESS(global3) + 1;
  IF global7 = global3 THEN global7 := global2 END;
END Proc18;

(* proc 42 *)
PROCEDURE proc42;
VAR local2 : ADDRESS;
    local3 : CARDINAL;
BEGIN
  IF global3 <> endBuffer THEN
    Proc18;
    Proc18;
    Terminal.WriteLn;
    IF (currentRow < numRows - 1) AND insertDelete THEN
      Terminal.DeleteLine;
      proc38(currentRow + 1);
      proc4(global3, currentCol, currentRow);
      local2 := global3;
      local3 := currentRow;
      REPEAT
        local2 := findReturn(local2);
        INC(local3)
      UNTIL local3 = numRows;
      proc4(local2, 0, numRows);
    ELSE
      proc34
    END;
  END;
END proc42;

(* proc 43 *)
PROCEDURE deleteRightChar;
BEGIN
  IF global3^[0] = CR THEN proc42; RETURN END;
  Proc18;
  proc4(global3, currentCol, currentRow);
END deleteRightChar;

(* proc 44 *)
PROCEDURE wordLeft;
VAR type, wordType : CharType;
BEGIN
  WHILE charType(ADDRESS(global2) - 1) = CONTROL DO cursorLeft END;
  wordType := charType(ADDRESS(global2) - 1);
  REPEAT
    cursorLeft;
    type := charType(ADDRESS(global2) - 1);
  UNTIL (type <> wordType) OR (type = CRLF);
END wordLeft;

(* proc 45 *)
PROCEDURE wordRight;
VAR type, wordType : CharType;
BEGIN
  wordType := charType(global3);
  REPEAT
    cursorRight;
    type := charType(global3);
  UNTIL (type <> wordType) OR (type = CRLF);
  WHILE charType(global3) = CONTROL DO cursorRight END;
END wordRight;

(* proc 46 *)
PROCEDURE deleteRightWord;
VAR local2 : CharType;
BEGIN
  Proc13(global2);
  local2 := charType(global3);
  IF local2 = CRLF THEN proc42; RETURN END;
  REPEAT Proc18 UNTIL charType(global3) <> local2;
  WHILE charType(global3) = CONTROL DO Proc18 END;
  proc4(global3, currentCol, currentRow);
END deleteRightWord;

(* proc 21 *)
PROCEDURE lineUp;
VAR local2 : CharPtr;
    local3 : CARDINAL;
    local4 : CARDINAL;
BEGIN
  local2 := findLineFeed(ADDRESS(global2) - 1);
  IF ADDRESS(local2) <= editBuffer THEN EDITDISK.proc12; RETURN END;
  local2 := findLineFeed(ADDRESS(local2) - 2) - 1;
  local3 := currentCol;
  currentCol:= 0;
  REPEAT
    local2 := ADDRESS(local2) + 1;
    local4 := currentCol;
    proc35(local2);
  UNTIL (local2^[0] = CR) OR (currentCol > local3);
  currentCol := local4;
  Proc10(ADDRESS(global2) - ADDRESS(local2));
  DEC(global10);
  DEC(currentRow);
END lineUp;

(* proc 22 *)
PROCEDURE lineDown;
VAR local2: CharPtr;
    local3: CARDINAL;
    local4: CARDINAL;
BEGIN
  local2 := findReturn(global3) - 1;
  IF ADDRESS(local2) <= endBuffer THEN
    local3 := currentCol;
    currentCol:= 0;
    REPEAT
      local2 := ADDRESS(local2) + 1;
      local4 := currentCol;
      proc35(local2);
    UNTIL (local2^[0] = CR) OR (currentCol > local3);
    currentCol := local4;
    Proc9(ADDRESS(local2) - ADDRESS(global3));
    INC(global10);
    INC(currentRow);
  END;
END lineDown;

(* proc 47 *)
PROCEDURE deleteLine;
BEGIN
  WHILE currentCol <> 0 DO cursorLeft END;
  Proc13(global2);
  WHILE global3^[0] <> CR DO Proc18 END;
  proc4(global3, 0, currentRow);
  currentCol := 0;
  proc42;
END deleteLine;

(* proc 48 *)
PROCEDURE pageUp;
VAR local2,local3: CARDINAL;
BEGIN
  local3 := currentRow;
  local2 := 0;
  REPEAT
    lineUp;
    INC(local2);
  UNTIL local2 = numRows - 6;
  IF global10 < numRows THEN currentRow := global10 ELSE currentRow := local3 END;
  Proc2
END pageUp;

(* proc 49 *)
PROCEDURE pageDown;
VAR local2,local3 : CARDINAL;
BEGIN
  local3 := currentRow;
  local2 := 0;
  REPEAT
    lineDown;
    INC(local2);
  UNTIL local2 = numRows - 6;
  IF (ADDRESS(global2) >= endBuffer) AND (global10 >= numRows) THEN
    currentRow := numRows - 1
  ELSE currentRow := local3
  END;
  Proc2
END pageDown;

(* proc 11 *)
PROCEDURE proc11(param2, param1: CARDINAL);
BEGIN
  IF param2 <> 0 THEN
    IF param2 < ADDRESS(global2) THEN
      global10 := global10 - Proc6(param2, global2);
      Proc10(ADDRESS(global2) - param2);
    ELSE
      IF param2 > ADDRESS(global3) THEN
        global10 := Proc6(global3, param2) + global10;
        Proc9(param2 - ADDRESS(global3));
      END;
    END;
    IF param1 <> 99 THEN
      IF param1 > global10 THEN
        currentRow := global10
      ELSE
        currentRow := param1
      END;
    END;
    Proc5;
    global22 := FALSE;
  END;
END proc11;

(* proc 12 *)
PROCEDURE proc12(param2, param1: CARDINAL);
BEGIN
  IF param2 < proc31(editBuffer) THEN
    proc11(editBuffer, 1);
    EDITDISK.proc12
  ELSE
    LOOP
      global10 := Proc6(global3, endBuffer) + global10;
      Proc9(endBuffer - ADDRESS(global3));
      IF proc31(global2) >= param2 THEN EXIT END;
      IF EDITDISK.global2 THEN RETURN END;
      EDITDISK.proc2
    END;
    proc11( ADDRESS(global2) - (proc31(global2) - param2), param1);
  END;
END proc12;

(* proc 23 *)
PROCEDURE proc23;
VAR local2 : CARDINAL;
BEGIN
  initKeyBuffer;
  global22 := FALSE;
  global18 := FALSE;
  EDIT2.global2 := FALSE;
  global7  := 0;
  global6  := 0;
  global2  := editBuffer;
  global3  := endBuffer;
  global10 := 1;
  currentRow  := 1;
  currentCol  := 0;
  global17 := FALSE;
  IF EDITDISK.proc1() THEN
    global25^ := ComLine.inName;
    local2    := 0;
    REPEAT
      IF global25^[local2] = 0C THEN
        global25^[local2] := ' '
      END;
      INC(local2);
    UNTIL local2 > 15;
    global17 := TRUE;
  END;
END proc23;

(* proc 17 *)
PROCEDURE proc17(): CARDINAL; (* empty function *)
BEGIN
END proc17;

(* proc 50 *)
PROCEDURE showControlChar(char: CHAR);
BEGIN
  Terminal.Highlight;
  Terminal.GotoXY(0,0);
  Terminal.WriteChar('^');
  Terminal.WriteChar(char);
  Terminal.Normal;
END showControlChar;

(* proc 51 *)
PROCEDURE editMenu;
VAR local2: CHAR;
    local3, local4 : CARDINAL;
BEGIN
  IF pendingDeleteChar THEN deleteRightChar; pendingDeleteChar := FALSE; RETURN END;
  local3 := proc31(global2);
  local2 := GetKey();
  IF (local2 >= ' ') AND (local2 < DEL) OR (local2 = CR) THEN proc41(local2)
  ELSE
    local4 := EDITDISK.proc14(local2);
    IF local4 > 32 THEN EDIT2.proc2(local4)
    ELSE
      CASE local4 OF
      |  0 : IF local2 > DEL THEN proc41(local2) END
      |  1 : cursorLeft (* Left *)
      |  2 : cursorRight (* Right *)
      |  3 : wordLeft (* word left *)
      |  4 : wordRight (* word right *)
      |  5 : lineUp (* line up *)
      |  6 : lineDown (* line down *)
      |  7 : (* scroll down *)
             IF currentRow <= 1 THEN lineDown END;
             DEC(currentRow);
             scrollDown;
      |  8 : (* scroll up *)
             IF currentRow >= numRows - 1 THEN lineUp END;
             INC(currentRow);
             scrollUp;
      |  9 : (* page up *) showControlChar('R'); pageUp
      | 10 : (* page dn *) showControlChar('C'); pageDown
      | 11 : (* insert on/off *) insertMode := NOT insertMode
      | 12 : (* insert line *) proc41(CR); wordLeft
      | 13 : (* delete line *) deleteLine
      | 14 : (* delete right word *) deleteRightWord
      | 15 : (* delete char under cursor *) deleteRightChar
      | 16 : (* delete left char *)
             IF global2 <> editBuffer THEN cursorLeft; pendingDeleteChar := TRUE END
      | 17 : (* tab *) proc41(TAB)
      | 18 : (* control char prefix *) showControlChar('P'); proc41(GetKey())
      | 19 : (* end edit *) EDITDISK.proc4; global19 := TRUE
      | 20 : (* repeat last find *) showControlChar('L'); EDIT2.proc1
      END;
    END;
  END;
  global13 := local3;
EXCEPTION
| EDIT2.QuitCommand : 
| EDITDISK.DiskIsFull : EDITDISK.proc15
| BADOVERLAY : EDITDISK.proc10("*** M2.OVR not found, use ^KD to save ","")
END editMenu;

(* proc 52 *)
PROCEDURE proc52;
VAR local2: CharPtr;
    local3 : CARDINAL;
BEGIN
  REPEAT
    IF NOT EDITDISK.global2 AND (ADDRESS(global3) > endBuffer - global15) THEN EDITDISK.proc2 END;
    IF NOT pendingDeleteChar THEN
      local2 := findReturn(global3) - 3;
      WHILE (ADDRESS(local2) >= ADDRESS(global3)) AND ((local2^[0] = ' ') OR (local2^[0] = TAB)) DO
        MOVE(global3, ADDRESS(global3)+1, ADDRESS(local2) - ADDRESS(global3));
        IF proc31(global2) < global24 THEN global24 := proc31(global2) END;
        IF global6 = global3 THEN INC(global6) END;
        global3 := ADDRESS(global3)+1;
        IF global7 = global3 THEN global7 := global2 END;
      END;
    END;
    IF INTEGER(currentRow) < 1 THEN
      IF currentRow = 0 THEN currentRow := 1; scrollUp ELSE currentRow := 1; Proc2 END;
    ELSE
      IF currentRow >= numRows THEN
        IF currentRow = numRows
        THEN currentRow := numRows - 1; scrollDown;
        ELSE currentRow := numRows - 1; Proc2;
        END;
      END;
    END;
    IF    NOT global22 THEN Proc2
    ELSIF NOT global23 THEN proc34
    END;
    local3 := 1; REPEAT pollKeyboard(); INC(local3); UNTIL local3 > 10;
    IF NOT (global21 OR keyAvailable) THEN proc32 END;
    global21 := FALSE;
    IF currentCol > numCols
    THEN Terminal.GotoXY(numCols, currentRow)
    ELSE Terminal.GotoXY(currentCol, currentRow)
    END;
    editMenu;
  UNTIL global19
END proc52;

(* proc 26 *)
PROCEDURE Edit;
VAR heapStart: ADDRESS;
    line, memSize: CARDINAL;
BEGIN
  numRows := Terminal.numRows - 1;
  numCols := Terminal.numCols - 1;
  insertDelete := Terminal.insertDelete IN Terminal.available;
  MARK(heapStart);
  ALLOCATE(rowsLengths, Terminal.numRows * SIZE(CARDINAL));
  memSize   := FREEMEM() - 1300;
  ALLOCATE(editBuffer, memSize);
  endBuffer  := editBuffer + memSize;
  line   := 0;
  REPEAT
    editBuffer^ := 0A0DH;
    INC(editBuffer,2);
    DEC(endBuffer,2);
    endBuffer^ := 0A0DH;
    INC(line);
  UNTIL line > numRows;
  EDITDISK.proc6;
  ALLOCATE(global25, 21);
  ALLOCATE(global26, 79);
  ALLOCATE(EDIT2.global4, 31);
  ALLOCATE(EDIT2.global5, 31);
  line := 0;
  REPEAT
    rowsLengths^[line] := 0;
    INC(line);
  UNTIL line >= numRows;
  nbSectors := (endBuffer - editBuffer) DIV 2048 * 4;
  global15 := nbSectors * 128;
  global19 := FALSE;
  global24 := 65535;
  pendingDeleteChar := FALSE;
  EDIT2.global3 := FALSE;
  proc23;
  IF global17 THEN
    IF global16 <> 0 THEN proc12(global16, numRows - 2) END;
(*    Terminal.InitScreen; (* removed *) *)
    Terminal.ClearScreen;
    proc32;
    proc52;
    global16 := global24;
    Terminal.GotoXY(0, numRows);
    Terminal.WriteLn;
    Terminal.WriteLn;
    Terminal.ExitScreen;
  END;
  RELEASE(heapStart);

EXCEPTION EDITDISK.DiskIsFull :
  EDITDISK.proc15;
  Terminal.ExitScreen;
  RELEASE(heapStart)
END Edit;

BEGIN
  global20 := TRUE;
  insertMode := TRUE;
END EDITOR.
                                                                                                                  