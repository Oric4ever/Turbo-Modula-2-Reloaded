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
(* 25 *) fileName   : POINTER TO ARRAY [0..20] OF CHAR;
(* 26 *) statusLine : POINTER TO ARRAY [0..78] OF CHAR;
(* 27 *) rowsLengths: POINTER TO ARRAY [0..99] OF CARDINAL;
(* 28 *) insertMode  : BOOLEAN;
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

(* proc 28 : redraw end of line, taking care to highlight current selection  *)
PROCEDURE proc28(charPtr: ADDRESS; column,limit : CARDINAL): CARDINAL;
VAR endOfLine: CARDINAL;
    local3: CARDINAL;
    local4: CARDINAL;
    local5: WORD;
BEGIN
  IF EDIT2.global2 THEN
    endOfLine := FindForward(charPtr, 65535, CR);
    IF (selectionStart < endOfLine) AND (selectionEnd > charPtr) THEN
      IF selectionStart > charPtr THEN
        local5          := selectionStart^;
        selectionStart^ := 0A0DH;
        endOfLine       := selectionStart;
        column          := EDITDISK.proc13(charPtr,column,limit,ADR(data.highlight),ADR(data.normal));
        selectionStart^ := local5;
        charPtr         := selectionStart;
      END;
      Terminal.Highlight;
      local3 := ADR(data.normal);
      local4 := ADR(data.highlight);
      IF selectionEnd < endOfLine THEN
        local5        := selectionEnd^;
        selectionEnd^ := 0A0DH;
        endOfLine     := selectionEnd;
        column        := EDITDISK.proc13(charPtr,column,limit,ADR(data.normal),ADR(data.highlight));
        selectionEnd^ := local5;
        charPtr       := selectionEnd;
        Terminal.Normal;
        local3        := ADR(data.highlight);
        local4        := ADR(data.normal);
      END;
      column := EDITDISK.proc13(charPtr,column,limit,local3,local4);
      Terminal.Normal;
      RETURN column;
    END;
  END;
  RETURN EDITDISK.proc13(charPtr,column,limit,ADR(data.highlight),ADR(data.normal))
END proc28;

(* proc 4 : redraw the end of the line *)
PROCEDURE RefreshEndOfLine(ptr: CharPtr; column, row: CARDINAL);
VAR finalColumn: CARDINAL;
BEGIN
  IF (rowsLengths^[row] <> 0) OR (ptr^[0] <> CR) THEN
    Terminal.GotoXY(column, row); (* is this needed ? it seems cursor is positionned twice *)
    finalColumn := proc28(ptr, column, lastColumn);
    IF finalColumn < rowsLengths^[row] THEN Terminal.ClearToEOL END;
    rowsLengths^[row] := finalColumn;
  ELSE
    rowsLengths^[row] := column
  END;
END RefreshEndOfLine;

(* proc 1 : PrintStatusLine *)
PROCEDURE PrintStatusLine(str: ARRAY OF CHAR; column: CARDINAL);
BEGIN
  Terminal.Highlight;
  rowsLengths^[0] := lastColumn + 1;
  str[HIGH(str)] := CR;
  RefreshEndOfLine(ADR(str), column, 0);
  Terminal.Normal;
END PrintStatusLine;

(* proc 14 : try to enlarge buffer *)
PROCEDURE Proc14;
BEGIN
  IF ADDRESS(beforeCursor) >= editBuffer + global15 * 5 DIV 4 THEN
    EDITDISK.proc3;
  ELSE
    EDITDISK.proc11("Buffer is full")
  END;
END Proc14;

(* proc 29 *)
PROCEDURE findPreviousLineFeed(param1: ADDRESS): ADDRESS;
BEGIN
  RETURN FindBackward(param1, 65535, LF) + 1
END findPreviousLineFeed;

(* proc 30 *)
PROCEDURE findReturn(param1: ADDRESS): ADDRESS;
BEGIN
  RETURN FindForward(param1, 65535, CR) + 2
END findReturn;

(* proc 31 *)
PROCEDURE charCount(param1: ADDRESS): CARDINAL;
BEGIN
  RETURN EDITDISK.global3 * global15 + param1 - editBuffer
END charCount;

(* proc 13 *)
PROCEDURE UpdateFirstModifiedPos(param1: ADDRESS);
BEGIN
  fileModified := TRUE;
  IF charCount(param1) < firstModifiedPos THEN firstModifiedPos := charCount(param1) END;
END UpdateFirstModifiedPos;

(* proc 3 *)
PROCEDURE Proc3;
VAR dummy : ADDRESS;
BEGIN
  beforeCursor^[0] := CR;
  Terminal.GotoXY(0,currentRow);
  dummy := proc28(findPreviousLineFeed(ADDRESS(beforeCursor)-1), 0, lastColumn);
  RefreshEndOfLine(afterCursor, currentCol, currentRow);
END Proc3;

(* proc 32 *)
PROCEDURE updateStatusLine;
  (* proc 33 *)
  PROCEDURE insertDecimalValue(value, index : CARDINAL);
  BEGIN
    REPEAT
      statusLine^[index] := CHR(value MOD 10 + ORD('0'));
      value := value DIV 10;
      DEC(index);
    UNTIL value = 0;
  END insertDecimalValue;
VAR emptyField   : ARRAY [0..5] OF CHAR;
    overwriteMsg : ARRAY [0..8] OF CHAR;
BEGIN
  statusLine^  := "                         Line        Col       Byte         Indent   Insert   ";
  emptyField   := "      ";
  overwriteMsg := "Overwrite";
  MOVE(fileName, ADR(statusLine^)+6, 16);
  insertDecimalValue(currentFileLine, 33);
  insertDecimalValue(currentCol+1, 43);
  insertDecimalValue(charCount(beforeCursor)+1, 57);
  IF NOT autoIndent THEN MOVE(ADR(emptyField),   ADR(statusLine^[60]), 6) END;
  IF NOT insertMode THEN MOVE(ADR(overwriteMsg), ADR(statusLine^[69]), 9) END;
  PrintStatusLine(statusLine^, 0);
END updateStatusLine;

(* proc 2 *)
PROCEDURE Proc2;
VAR local2 : ADDRESS;
    local3 : CARDINAL;
BEGIN
  global23 := TRUE;
  global22 := FALSE;
  Proc3;
  local2 := findPreviousLineFeed(ADDRESS(beforeCursor) - 1);
  local3 := currentRow;
  WHILE local3 > 1 DO
    local2 := findPreviousLineFeed(ADDRESS(local2) - 2);
    DEC(local3);
  END;
  pollKeyboard;
  WHILE (local3 <= lastRow) AND ((NOT breakKey) OR (NOT keyAvailable)) DO
    IF local3 = currentRow THEN
      local2 := afterCursor
    ELSE RefreshEndOfLine(local2, 0, local3)
    END;
    local2 := findReturn(local2);
    INC(local3);
    pollKeyboard;
  END;
  global22 := local3 > lastRow;
END Proc2;

(* proc 34 *)
PROCEDURE proc34;
VAR local2,local3: ADDRESS;
BEGIN
  IF NOT global22 THEN Proc2; RETURN END;
  local2 := afterCursor;
  global23 := FALSE;
  Proc3;
  local3 := currentRow;
  WHILE (local3 < lastRow) AND (NOT keyAvailable) DO
    INC(local3);
    local2 := findReturn(local2);
    RefreshEndOfLine(local2, 0, local3);
    pollKeyboard;
  END;
  global23 := local3 >= lastRow;
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

(* proc 35 unneeded now that TAB is converted into spaces
PROCEDURE nextColumn(charPtr: CharPtr);
BEGIN
  IF charPtr^[0] = TAB THEN currentCol := (currentCol DIV 4 + 1) * 4 ELSE INC(currentCol) END;
END nextColumn;
*)

(* FF: added for UTF8 *)
PROCEDURE charSize(ptr: CharPtr): CARDINAL;
VAR firstByte: CHAR;
BEGIN
  firstByte := ptr^[0];
  IF firstByte < CHR(0C0H) THEN RETURN 1 END;
  IF firstByte < CHR(0E0H) THEN RETURN 2 END;
  RETURN 3
END charSize;

(* proc 5 *)
PROCEDURE UpdateColumn;
VAR ptr: ADDRESS;
BEGIN
  currentCol := 0;
  ptr := findPreviousLineFeed(ADDRESS(beforeCursor) - 1);
  WHILE ptr <> beforeCursor DO
    INC(currentCol);
    INC(ptr, charSize(ptr));
  END;
END UpdateColumn;

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
PROCEDURE MoveBytesAfterCursorToBefore(count: CARDINAL);
VAR local2: ADDRESS;
BEGIN
  local2 := afterCursor;
  MOVE(afterCursor, beforeCursor, count);
  beforeCursor := ADDRESS(beforeCursor) + count;
  afterCursor  := ADDRESS(afterCursor) + count;
  IF (selectionStart >= local2) AND (selectionStart < ADDRESS(afterCursor)) THEN
    selectionStart := selectionStart - (ADDRESS(afterCursor) - ADDRESS(beforeCursor));
  END;
  IF (selectionEnd > local2) AND (selectionEnd <= ADDRESS(afterCursor)) THEN
    selectionEnd := selectionEnd - (ADDRESS(afterCursor) - ADDRESS(beforeCursor));
  END;
END MoveBytesAfterCursorToBefore;

(* proc 10 *)
PROCEDURE MoveBytesBeforeCursorToAfter(count: CARDINAL);
VAR local2 : ADDRESS;
BEGIN
  local2  := beforeCursor;
  afterCursor  := ADDRESS(afterCursor) - count;
  beforeCursor := ADDRESS(beforeCursor) - count;
  MOVE(beforeCursor, afterCursor, count);
  IF (selectionStart >= ADDRESS(beforeCursor)) AND (selectionStart < local2) THEN
    selectionStart := selectionStart + (ADDRESS(afterCursor) - ADDRESS(beforeCursor))
  END;
  IF (selectionEnd > ADDRESS(beforeCursor)) AND (selectionEnd <= local2) THEN
    selectionEnd := selectionEnd + (ADDRESS(afterCursor) - ADDRESS(beforeCursor))
  END;
END MoveBytesBeforeCursorToAfter;

(* proc 37 *)
PROCEDURE proc37(line: CARDINAL);
BEGIN
  IF line < lastRow THEN 
    MOVE(ADR(rowsLengths^[line]), ADR(rowsLengths^[line+1]), (lastRow-line)*2);
  END;
  rowsLengths^[line] := 0;
END proc37;

(* proc 38 *)
PROCEDURE proc38(line: CARDINAL);
BEGIN
  IF line < lastRow THEN
    MOVE(ADR(rowsLengths^[line+1]),ADR(rowsLengths^[line]), (lastRow-line)*2)
  END;
  rowsLengths^[lastRow] := 0;
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
    Terminal.GotoXY(0,lastRow);
    Terminal.WriteLn;
    proc38(0);
  END;
  local2 := afterCursor;
  local3 := currentRow;
  WHILE local3 < lastRow DO
    local2 := findReturn(local2);
    INC(local3);
  END;
  RefreshEndOfLine(local2, 0, lastRow)
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
      local2 := findPreviousLineFeed(beforeCursor);
      REPEAT
        local2 := findPreviousLineFeed(local2 - 2);
        DEC(local3);
      UNTIL local3 = 1;
      RefreshEndOfLine(local2, 0, 1)
    END;
  ELSE
    Proc2
  END;
END scrollUp;

(* proc 41 *)
PROCEDURE insertChar(code: CARDINAL);(* FF: 16-bit Unicode instead of char *)
VAR ptr : CharPtr;
    char : CHAR;
    charLength : CARDINAL;
BEGIN
  (* if hole is too small, try to enlarge buffer *)
  IF ADDRESS(beforeCursor) + 8 >= ADDRESS(afterCursor) THEN Proc14 END;
  UpdateFirstModifiedPos(beforeCursor);

  IF code < 0080H THEN 
    charLength := 1;
    beforeCursor^[0] := CHR(code);
    IF CHR(code) = CR THEN
      beforeCursor^[1] := LF;
      RefreshEndOfLine(beforeCursor, currentCol, currentRow);
      beforeCursor := ADDRESS(beforeCursor) + 2;
      INC(currentFileLine);
      currentCol := 0;
      INC(currentRow);
      Terminal.WriteLn;
      IF autoIndent THEN
        ptr := findPreviousLineFeed(ADDRESS(beforeCursor) - 2);
        LOOP
          char := ptr^[0];
          IF (char <> ' ') AND (char <> TAB) THEN EXIT END;
          IF ADDRESS(beforeCursor) + 1 >= ADDRESS(afterCursor) THEN Proc14 END;
          beforeCursor^[0] := char;
          beforeCursor := ADDRESS(beforeCursor)+1;
          INC(currentCol);
          ptr := ADDRESS(ptr)+1;
        END;
      END;
      IF (currentRow < lastRow) AND insertDelete THEN
        Terminal.InsertLine;
        proc37(currentRow);
        Proc3
      ELSE proc34 
      END;
      RETURN
    END;
  ELSIF code < 0800H THEN
    charLength := 2;
    beforeCursor^[0] := CHR(code DIV 64 + 0C0H); 
    beforeCursor^[1] := CHR(code MOD 64 + 080H);
  ELSE
    charLength := 3;
    beforeCursor^[0] := CHR(code DIV 4096 + 0E0H);
    beforeCursor^[1] := CHR(code DIV 64 MOD 64 + 080H);
    beforeCursor^[2] := CHR(code MOD 64 + 080H);
  END;

  (* overwrite mode eats the next char, except when at the end of a line... *)
  IF (NOT insertMode) AND (afterCursor^[0] <> CR) THEN
    afterCursor := ADDRESS(afterCursor) + charSize(afterCursor);
  END;

  (* store the char also just before afterCursor in order to display end of line *)
  ptr := ADDRESS(afterCursor)-charLength;
  MOVE(beforeCursor, ptr, charLength);
  beforeCursor := ADDRESS(beforeCursor) + charLength;
  RefreshEndOfLine(ptr, currentCol, currentRow);
  INC(currentCol);
END insertChar;

(* proc 19 *)
PROCEDURE cursorLeft;
VAR 
BEGIN
  IF ADDRESS(beforeCursor) <= editBuffer THEN EDITDISK.proc12; RETURN END;
  IF currentCol = 0 THEN
    MoveBytesBeforeCursorToAfter(2);
    DEC(currentFileLine);
    UpdateColumn;
    DEC(currentRow);
  ELSE
    REPEAT  (* FF: add UTF8 variable-sized chars *)
      MoveBytesBeforeCursorToAfter(1)
    UNTIL (ORD(afterCursor^[0]) < 080H) OR (ORD(afterCursor^[0]) >= 0C0H);
    IF beforeCursor^[0] = TAB THEN UpdateColumn ELSE DEC(currentCol) END;
  END;
END cursorLeft;

(* proc 20 *)
PROCEDURE cursorRight;
BEGIN
  IF afterCursor^[0] = CR THEN
    IF afterCursor <> endBuffer THEN
      MoveBytesAfterCursorToBefore(2);
      INC(currentFileLine);
      INC(currentRow);
      currentCol := 0;
    END;
  ELSE
    INC(currentCol);
    (* FF: add UTF8 variable-sized chars *)
    MoveBytesAfterCursorToBefore(charSize(afterCursor));
  END;
END cursorRight;

(* proc 18 *)
PROCEDURE deleteRightChar;
BEGIN
  UpdateFirstModifiedPos(beforeCursor);
  IF selectionStart = afterCursor THEN INC(selectionStart) END;
  afterCursor := ADDRESS(afterCursor) + charSize(afterCursor);
  IF selectionEnd = afterCursor THEN selectionEnd := beforeCursor END;
END deleteRightChar;

(* proc 42 *)
PROCEDURE proc42;
VAR local2 : ADDRESS;
    local3 : CARDINAL;
BEGIN
  IF afterCursor <> endBuffer THEN
    deleteRightChar;
    deleteRightChar;
    Terminal.WriteLn;
    IF (currentRow < lastRow - 1) AND insertDelete THEN
      Terminal.DeleteLine;
      proc38(currentRow + 1);
      RefreshEndOfLine(afterCursor, currentCol, currentRow);
      local2 := afterCursor;
      local3 := currentRow;
      REPEAT
        local2 := findReturn(local2);
        INC(local3)
      UNTIL local3 = lastRow;
      RefreshEndOfLine(local2, 0, lastRow);
    ELSE
      proc34
    END;
  END;
END proc42;

(* proc 43 *)
PROCEDURE deleteRightCharCommand;
BEGIN
  IF afterCursor^[0] = CR THEN proc42; RETURN END;
  deleteRightChar;
  RefreshEndOfLine(afterCursor, currentCol, currentRow);
END deleteRightCharCommand;

(* proc 44 *)
PROCEDURE wordLeft;
VAR type, wordType : CharType;
BEGIN
  WHILE charType(ADDRESS(beforeCursor) - 1) = CONTROL DO cursorLeft END;
  wordType := charType(ADDRESS(beforeCursor) - 1);
  REPEAT
    cursorLeft;
    type := charType(ADDRESS(beforeCursor) - 1);
  UNTIL (type <> wordType) OR (type = CRLF);
END wordLeft;

(* proc 45 *)
PROCEDURE wordRight;
VAR type, wordType : CharType;
BEGIN
  wordType := charType(afterCursor);
  REPEAT
    cursorRight;
    type := charType(afterCursor);
  UNTIL (type <> wordType) OR (type = CRLF);
  WHILE charType(afterCursor) = CONTROL DO cursorRight END;
END wordRight;

(* proc 46 *)
PROCEDURE deleteRightWord;
VAR local2 : CharType;
BEGIN
  UpdateFirstModifiedPos(beforeCursor);
  local2 := charType(afterCursor);
  IF local2 = CRLF THEN proc42; RETURN END;
  REPEAT deleteRightChar UNTIL charType(afterCursor) <> local2;
  WHILE charType(afterCursor) = CONTROL DO deleteRightChar END;
  RefreshEndOfLine(afterCursor, currentCol, currentRow);
END deleteRightWord;


(* FF: added for UTF8 *)
PROCEDURE reachCurrentColumn(ptr: CharPtr): CharPtr;
VAR oldColumn : CARDINAL;
    column : CARDINAL;
BEGIN
  oldColumn := currentCol;
  currentCol:= 0;
  REPEAT
    ptr := ADDRESS(ptr) + charSize(ptr);
    column := currentCol;
    INC(currentCol);
  UNTIL (ptr^[0] = CR) OR (currentCol > oldColumn);
  currentCol := column;
  RETURN ptr
END reachCurrentColumn;

(* proc 21 *)
PROCEDURE lineUp;
VAR ptr : CharPtr;
    oldColumn : CARDINAL;
    column : CARDINAL;
BEGIN
  ptr := findPreviousLineFeed(ADDRESS(beforeCursor) - 1);
  IF ADDRESS(ptr) <= editBuffer THEN EDITDISK.proc12; RETURN END;
  ptr := reachCurrentColumn( findPreviousLineFeed(ADDRESS(ptr) - 2) - 1 );
  MoveBytesBeforeCursorToAfter(ADDRESS(beforeCursor) - ADDRESS(ptr));
  DEC(currentFileLine);
  DEC(currentRow);
END lineUp;

(* proc 22 *)
PROCEDURE lineDown;
VAR ptr: CharPtr;
    local3: CARDINAL;
    local4: CARDINAL;
BEGIN
  ptr := findReturn(afterCursor) - 1;
  IF ADDRESS(ptr) <= endBuffer THEN
    ptr := reachCurrentColumn(ptr);
    MoveBytesAfterCursorToBefore(ADDRESS(ptr) - ADDRESS(afterCursor));
    INC(currentFileLine);
    INC(currentRow);
  END;
END lineDown;

(* proc 47 *)
PROCEDURE deleteLine;
BEGIN
  WHILE currentCol <> 0 DO cursorLeft END;
  UpdateFirstModifiedPos(beforeCursor);
  WHILE afterCursor^[0] <> CR DO deleteRightChar END;
  RefreshEndOfLine(afterCursor, 0, currentRow);
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
  UNTIL local2 = lastRow - 6;
  IF currentFileLine < lastRow THEN currentRow := currentFileLine ELSE currentRow := local3 END;
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
  UNTIL local2 = lastRow - 6;
  IF (ADDRESS(beforeCursor) >= endBuffer) AND (currentFileLine >= lastRow) THEN
    currentRow := lastRow - 1
  ELSE currentRow := local3
  END;
  Proc2
END pageDown;

(* proc 11 *)
PROCEDURE proc11(param2, param1: CARDINAL);
BEGIN
  IF param2 <> 0 THEN
    IF param2 < ADDRESS(beforeCursor) THEN
      currentFileLine := currentFileLine - Proc6(param2, beforeCursor);
      MoveBytesBeforeCursorToAfter(ADDRESS(beforeCursor) - param2);
    ELSE
      IF param2 > ADDRESS(afterCursor) THEN
        currentFileLine := Proc6(afterCursor, param2) + currentFileLine;
        MoveBytesAfterCursorToBefore(param2 - ADDRESS(afterCursor));
      END;
    END;
    IF param1 <> 99 THEN
      IF param1 > currentFileLine THEN
        currentRow := currentFileLine
      ELSE
        currentRow := param1
      END;
    END;
    UpdateColumn;
    global22 := FALSE;
  END;
END proc11;

(* proc 12 *)
PROCEDURE proc12(param2, param1: CARDINAL);
BEGIN
  IF param2 < charCount(editBuffer) THEN
    proc11(editBuffer, 1);
    EDITDISK.proc12
  ELSE
    LOOP
      currentFileLine := Proc6(afterCursor, endBuffer) + currentFileLine;
      MoveBytesAfterCursorToBefore(endBuffer - ADDRESS(afterCursor));
      IF charCount(beforeCursor) >= param2 THEN EXIT END;
      IF EDITDISK.global2 THEN RETURN END;
      EDITDISK.proc2
    END;
    proc11( ADDRESS(beforeCursor) - (charCount(beforeCursor) - param2), param1);
  END;
END proc12;

(* proc 23 *)
PROCEDURE proc23;
VAR i: CARDINAL;
BEGIN
  initKeyBuffer;
  global22       := FALSE;
  fileModified   := FALSE;
  EDIT2.global2  := FALSE;
  selectionEnd   := 0;
  selectionStart := 0;
  beforeCursor   := editBuffer;
  afterCursor    := endBuffer;
  currentFileLine:= 1;
  currentRow     := 1;
  currentCol     := 0;
  global17       := FALSE;
  IF EDITDISK.proc1() THEN
    fileName^ := ComLine.inName;
    i := 0;
    REPEAT
      IF fileName^[i] = 0C THEN fileName^[i] := ' ' END;
      INC(i);
    UNTIL i > 15;
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
VAR key: CHAR;
    local3, local4, length : CARDINAL;
    ptr : CharPtr;
    code : CARDINAL;
BEGIN
  IF pendingDeleteChar THEN deleteRightCharCommand; pendingDeleteChar := FALSE; RETURN END;
  local3 := charCount(beforeCursor);
  key := GetKey();
  IF ORD(key) >= 0C0H THEN (* FF: UTF8 encoded char *)
    code := ORD(key) MOD 32 * 64 + ORD(GetKey()) MOD 64;
    IF ORD(key) >= 0E0H THEN insertChar(code * 64 + ORD(GetKey()) MOD 64)
    ELSE insertChar(code)
    END;
  ELSIF (key >= ' ') AND (key < DEL) OR (key = CR) THEN insertChar(ORD(key))
  ELSE
    local4 := EDITDISK.proc14(key);
    IF local4 > 32 THEN EDIT2.proc2(local4)
    ELSE
      CASE local4 OF
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
             IF currentRow >= lastRow - 1 THEN lineUp END;
             INC(currentRow);
             scrollUp;
      |  9 : (* page up *) showControlChar('R'); pageUp
      | 10 : (* page dn *) showControlChar('C'); pageDown
      | 11 : (* insert on/off *) insertMode := NOT insertMode
      | 12 : (* insert line *) insertChar(ORD(CR)); wordLeft
      | 13 : (* delete line *) deleteLine
      | 14 : (* delete right word *) deleteRightWord
      | 15 : (* delete char under cursor *) deleteRightCharCommand
      | 16 : (* delete left char *)
             IF beforeCursor <> editBuffer THEN cursorLeft; pendingDeleteChar := TRUE END
      | 17 : (* tab *) REPEAT insertChar(32) UNTIL currentCol MOD 4 = 0
      | 18 : (* FF: unicode entry *) showControlChar('U');
             code := 0;
             FOR length:=1 TO 4 DO 
               key := CAP(GetKey());
               IF (key>='0') AND (key<='9') THEN 
                 code := code * 16 + (ORD(key)-ORD('0'))
               ELSIF (key >= 'A') AND (key <= 'Z') THEN 
                 code := code * 16 + (ORD(key)-ORD('A'))+10
               END;
             END;
             insertChar(code);
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
    IF NOT EDITDISK.global2 AND (ADDRESS(afterCursor) > endBuffer - global15) THEN EDITDISK.proc2 END;
    IF NOT pendingDeleteChar THEN
      local2 := findReturn(afterCursor) - 3;
      WHILE (ADDRESS(local2) >= ADDRESS(afterCursor)) AND ((local2^[0] = ' ') OR (local2^[0] = TAB)) DO
        MOVE(afterCursor, ADDRESS(afterCursor)+1, ADDRESS(local2) - ADDRESS(afterCursor));
        IF charCount(beforeCursor) < firstModifiedPos THEN firstModifiedPos := charCount(beforeCursor) END;
        IF selectionStart = afterCursor THEN INC(selectionStart) END;
        afterCursor := ADDRESS(afterCursor)+1;
        IF selectionEnd = afterCursor THEN selectionEnd := beforeCursor END;
      END;
    END;
    IF INTEGER(currentRow) < 1 THEN
      IF currentRow = 0 THEN currentRow := 1; scrollUp ELSE currentRow := 1; Proc2 END;
    ELSE
      IF currentRow >= lastRow THEN
        IF currentRow = lastRow
        THEN currentRow := lastRow - 1; scrollDown;
        ELSE currentRow := lastRow - 1; Proc2;
        END;
      END;
    END;
    IF    NOT global22 THEN Proc2
    ELSIF NOT global23 THEN proc34
    END;
    local3 := 1; REPEAT pollKeyboard(); INC(local3); UNTIL local3 > 10;
    IF NOT (global21 OR keyAvailable) THEN updateStatusLine END;
    global21 := FALSE;
    IF currentCol > lastColumn
    THEN Terminal.GotoXY(lastColumn, currentRow)
    ELSE Terminal.GotoXY(currentCol, currentRow)
    END;
    editMenu;
  UNTIL global19
END proc52;

PROCEDURE WriteCard(i: CARDINAL);
BEGIN
  IF i>9 THEN WriteCard(i DIV 10) END;
  Terminal.WriteChar(CHR(ORD('0')+ i MOD 10))
END WriteCard;

(* proc 24 *)
PROCEDURE Edit;
VAR heapStart: ADDRESS;
    line, memSize: CARDINAL;
BEGIN
  lastRow := Terminal.numRows - 1;
  lastColumn := Terminal.numCols - 1;
  insertDelete := Terminal.insertDelete IN Terminal.available;
  autoIndent := TRUE;
  insertMode := TRUE;
  MARK(heapStart);
  ALLOCATE(rowsLengths, Terminal.numRows * SIZE(CARDINAL));
  memSize   := FREEMEM() - 5000;
  ALLOCATE(editBuffer, memSize);
  endBuffer  := editBuffer + memSize;
  line   := 0;
  REPEAT
    editBuffer^ := 0A0DH;
    INC(editBuffer,2);
    DEC(endBuffer,2);
    endBuffer^ := 0A0DH;
    INC(line);
  UNTIL line > lastRow;
  EDITDISK.proc6;
  ALLOCATE(fileName, 21);
  ALLOCATE(statusLine, 79);
  ALLOCATE(EDIT2.global4, 31);
  ALLOCATE(EDIT2.global5, 31);
  line := 0;
  REPEAT
    rowsLengths^[line] := 0;
    INC(line);
  UNTIL line >= lastRow;
  nbSectors := (endBuffer - editBuffer) DIV 2048 * 4;
  global15 := nbSectors * 128;
  global19 := FALSE;
  firstModifiedPos := 65535;
  pendingDeleteChar := FALSE;
  EDIT2.global3 := FALSE;
  proc23;
  IF global17 THEN
    IF editPosition <> 0 THEN proc12(editPosition, lastRow - 2) END;
(*    Terminal.InitScreen; (* removed *) *)
    Terminal.ClearScreen;
    updateStatusLine;
    proc52;
    editPosition := firstModifiedPos;
    Terminal.GotoXY(0, lastRow);
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

END EDITOR.
