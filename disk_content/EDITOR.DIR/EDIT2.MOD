IMPLEMENTATION MODULE EDIT2;
IMPORT Editor, EditDisk, Files, Terminal;
FROM ComLine IMPORT inName;
FROM SYSTEM IMPORT ADR, CODE, MOVE;

VAR global11: CARDINAL;
VAR global12: CARDINAL;
VAR global13: BITSET;
VAR selectionStart: CARDINAL;
VAR selectionEnd: CARDINAL;
VAR selectionSize: CARDINAL;
VAR global17: BOOLEAN;
VAR global18: CHAR;

CONST DISKFULL = "DISK FULL"; ERROR = "*** Error: "; NOTFOUND = "*** Not found: ";
      BACKSP = 10C; CR = 15C; SPACE = 40C; DEL = 177C;
      CTRLA = 01C; CTRLD = 04C; CTRLF = 06C; CTRLL = 14C; CTRLP = 20C; CTRLS = 23C;
      CTRLU = 25C; CTRLX = 30C; CTRLZ = 32C;

(* $T+ $[+ *)

PROCEDURE proc10(ch: CHAR);
BEGIN
  IF ch = CTRLU THEN EditDisk.proc10("*** Interrupted ", ""); RAISE QuitCommand END;
END proc10;


PROCEDURE proc11(VAR param5: ARRAY OF CHAR; param3: ARRAY OF CHAR; param1: CARDINAL);
VAR i: CARDINAL;
    ch: CHAR;

  PROCEDURE proc12;
  BEGIN
    DEC(i);
    Terminal.WriteChar(BACKSP);
    Terminal.WriteChar(SPACE);
    Terminal.WriteChar(BACKSP);
  END proc12;

  PROCEDURE proc13;
  BEGIN
    IF i <= param1 THEN param5[i] := param3[i]; Terminal.WriteChar(param5[i]) END;
  END proc13;
     
BEGIN
  i := 0;
  Terminal.Highlight;
  REPEAT
    ch := Editor.GetKey();
    proc10(ch);
    IF (ch >= SPACE) AND (ch < DEL) THEN
      IF i <= HIGH(param5) THEN
        param5[i] := ch;
        INC(i);
        Terminal.WriteChar(ch)
      END; (* 00cb *)
    ELSIF (ch = CTRLS) OR (ch = BACKSP) OR (ch = DEL) THEN
      IF i <> 0 THEN proc12 END;
    ELSIF ch = CTRLD THEN
      IF i < param1 THEN proc13; INC(i) END;
    ELSIF ch = CTRLA THEN
      WHILE i <> 0 DO proc12 END;
    ELSIF ch = CTRLF THEN
      WHILE i < param1 DO proc13; INC(i) END;
    ELSIF ch = CTRLP THEN
      IF i <= HIGH(param5) THEN
        Terminal.ReadChar(ch);
        param5[i] := ch;
        INC(i);
        IF ch < SPACE THEN
          Terminal.Normal;
          Terminal.WriteChar(CHR(ORD(ch) + 64));
          Terminal.Highlight;
          ch := 0C;
        END;
      END; (* 0143 *)
    END; (* 0143 *)
  UNTIL ch = CR;
  IF i <= HIGH(param5) THEN param5[i] := 0C ELSE param5[HIGH(param5)] := 0C END;
  Terminal.Normal;
END proc11;

PROCEDURE proc14(str: ARRAY OF CHAR): CARDINAL;
VAR i: CARDINAL;
BEGIN
  i := 0;
  WHILE (i <= HIGH(str)) AND (str[i] # 0C) DO INC(i) END;
  RETURN i
END proc14;

PROCEDURE proc15(ch: CHAR; VAR ptr: StringPtr);
BEGIN
  CASE ch OF
  | 'C':     ptr := ADR(global7)
  | 'F':     ptr := ADR(global6)
  | 'O':     ptr := ADR(global8)
  | 'R','W': ptr := ADR(global9)
  ELSE       ptr := ADR(global10)
  END;
END proc15;

PROCEDURE proc5(msg: ARRAY OF CHAR; column: CARDINAL; VAR filename: ARRAY OF CHAR): CARDINAL;
VAR i: CARDINAL;
VAR local3: CARDINAL;
VAR local4: StringPtr;
BEGIN
  Editor.PrintStatusLine(msg, column);
  Terminal.GotoXY(column + HIGH(msg) + 1, 0);
  proc15(msg[0], local4);
  proc11(filename, local4^, proc14(local4^));
  filename[HIGH(filename)] := 0C;
  Terminal.Normal;
  local4^ := filename;
  i := 0;
  WHILE filename[i] # 0C DO INC(i) END;
  RETURN i
END proc5;

PROCEDURE proc4(msg: ARRAY OF CHAR): BOOLEAN;
VAR ch: CHAR;
BEGIN
  Editor.PrintStatusLine(msg, 6);
  Terminal.GotoXY(6 + HIGH(msg), 0);
  Terminal.Highlight;
  Terminal.WriteString("? (Y/N) ");
  proc10(ch);
  ch := Editor.GetKey();
  ch := Editor.proc16(ch);
  Terminal.WriteChar(ch);
  Terminal.Normal;
  RETURN ch = 'Y'
END proc4;

PROCEDURE proc16;
BEGIN
  DEC(Editor.currentFileLine, Editor.Proc6(Editor.editBuffer, Editor.beforeCursor));
  Editor.MoveBytesBeforeCursorToAfter(ADDRESS(Editor.beforeCursor) - Editor.editBuffer);
  EditDisk.proc12;
  Editor.UpdateColumn;
  Editor.currentRow := 1;
  Editor.Proc2;
END proc16;

PROCEDURE proc17;
BEGIN
  LOOP
    Editor.currentFileLine := Editor.Proc6(Editor.afterCursor, Editor.endBuffer)
                            + Editor.currentFileLine;
    Editor.MoveBytesAfterCursorToBefore(Editor.endBuffer - ADDRESS(Editor.afterCursor));
    Terminal.BusyRead(global18);
    IF (global18 # CTRLU) AND (global18 # 0C) THEN Terminal.ReadAgain END;
    IF EditDisk.global2 OR (global18 = CTRLU) THEN
      IF Editor.lastRow > Editor.currentFileLine 
      THEN Editor.currentRow := Editor.currentFileLine
      ELSE Editor.currentRow := Editor.lastRow - 1
      END;
      Editor.UpdateColumn;
      Editor.Proc2;
      RETURN
    END;
    EditDisk.proc2
  END; (* 02c8 *)
END proc17;

PROCEDURE proc1;
  PROCEDURE proc18(addr: ADDRESS): BOOLEAN;
  VAR s: StringPtr;
    PROCEDURE proc19(ch: CHAR): BOOLEAN;
    BEGIN
      RETURN (ch < '0')
          OR (ch > '9') AND (ch < 'A')
          OR (ch > 'Z') AND (ch < 'a')
          OR (ch > 'z');
    END proc19;
  BEGIN
    s := addr;
    RETURN proc19(s^[0]) OR proc19(s^[1])
  END proc18;

  PROCEDURE proc20(p1, p2: StringPtr; noCase: BOOLEAN): BOOLEAN;
(* Original version in Z80:   CODE("PROC20")  *)
(* Z80 code :
0000  e1        pop     hl              ; pop return addr
0001  c1        pop     bc              ; pop case insensitive flag
0002  79        ld      a,c             ; multiply by 32
0003  87        add     a,a
0004  87        add     a,a
0005  87        add     a,a
0006  87        add     a,a
0007  87        add     a,a
0008  47        ld      b,a             ; and save in B
0009  2f        cpl                     ; build the complementary mask
000a  4f        ld      c,a             ; and save in C
000b  d1        pop     de              ; pop second param
000c  e3        ex      (sp),hl         ; get first param in HL and push back return addr
000d  1a        ld      a,(de)          ; get character pointed by DE
000e  b0        or      b               ; convert to uppercase if insensitive comparison
000f  96        sub     (hl)            ; compare with character pointed by HL
0010  a1        and     c               ; and keep only case sensitive bits
0011  200a      jr      nz,#001d        ; return 0 if different
0013  13        inc     de              ; advance both params
0014  23        inc     hl
0015  be        cp      (hl)            ; return 1 if NUL char reached
0016  20f5      jr      nz,#000d        ;
0018  210100    ld      hl,#0001
001b  e3        ex      (sp),hl
001c  e9        jp      (hl)
001d  210000    ld      hl,#0000
0020  e3        ex      (sp),hl
0021  e9        jp      (hl)
0022  00        nop
0023  00        nop
*)

(* $T-  new version in Modula-2, exactly the same size !! *)
  VAR mask: BITSET;
      index: CARDINAL;
      char : CHAR;
  BEGIN
    index := 65535;
    mask  := BITSET( index - ORD(noCase) * 32);
    REPEAT
      INC(index);
      char := p1^[index];
    UNTIL (char = 0C) OR ( BITSET(char) / BITSET(p2^[index]) * mask # {} );
    RETURN char = 0C;
  END proc20;
(* $T+ *)

VAR local2: ADDRESS;
VAR local3: ADDRESS;
VAR local4: ADDRESS;
VAR local5: ADDRESS;
VAR local6: CARDINAL;
VAR local7: BOOLEAN;
VAR local8: BOOLEAN;
VAR local9: BOOLEAN;
VAR local10: BOOLEAN;
VAR local11: CHAR;
VAR local12: CHAR;
VAR local13: BOOLEAN;
VAR local14: CARDINAL;
BEGIN
  IF global3 # 0 THEN
    Terminal.GotoXY(0,0);
    local12 := global4^[0];
    local9  := (ORD('U') - ORD('G')) IN global13;
    local10 := (ORD(CAP('R')) - ORD('G')) IN global13;
    IF local9 AND (ORD(local12) - ORD('A') <= 25) THEN
      local12 := CHR(ORD(local12) + 32);
    END;
    local14 := 1;
    local7  := TRUE;
    WHILE (local14 <= global12) AND local7 DO
      INC(local14);
      local13 := TRUE;
      REPEAT
        local7  := FALSE;
        local6  := Editor.currentFileLine;
        LOOP
          local2 := Editor.beforeCursor;
          local3 := Editor.beforeCursor;
          Editor.MoveBytesAfterCursorToBefore(Editor.endBuffer - ADDRESS(Editor.afterCursor));
          REPEAT
            local5 := local3;
            IF NOT local10 THEN
              local3 := Editor.FindForward(local5, ADDRESS(Editor.beforeCursor)-local5, local12);
              IF local9 THEN
                local4 := Editor.FindForward(local5, ADDRESS(Editor.beforeCursor) - local5, CAP(local12));
                IF (local4 # NIL) AND ((local3 = NIL) OR (local4 < local3)) THEN
                  local3 := local4
                END; (* 03C8 *)
              END; (* 03c8 *)
            ELSE (* 03CA *)
              local3 := Editor.FindBackward(local5-1, local5 - Editor.editBuffer, local12);
              IF local9 THEN
                local4 := Editor.FindBackward(local5-1, local5 - Editor.editBuffer, CAP(local12));
                IF (local4 # NIL) AND ((local3 = NIL) OR (local4 > local3)) THEN
                  local3 := local4
                END;
              END; (* 03fa *)
            END; (* 03FA *)
            IF local3 # NIL THEN
              IF proc20(global4, local3, local9)
              AND (NOT (15 IN global13) OR proc18(local3-1) AND proc18(local3 + global3 - 1))
              THEN
                IF NOT local10 THEN
                  Editor.MoveBytesBeforeCursorToAfter(ADDRESS(Editor.beforeCursor) - local3 - global3);
                ELSE (* 0427 *)
                  DEC(Editor.currentFileLine, Editor.Proc6(local3, local2));
                  Editor.MoveBytesBeforeCursorToAfter(ADDRESS(Editor.beforeCursor) - local3);
                END; (* 0436 *)
                local7 := TRUE;
              ELSE (* 043A *)
                IF NOT local10 THEN INC(local3) ELSE DEC(local3) END;
              END; (* 0446 *)
            END; (* 0446 *)
            Terminal.BusyRead(global18);
            IF (global18 <> CTRLU) AND (global18 <> 0C) THEN Terminal.ReadAgain END;
          UNTIL local7 OR (local3 = NIL) OR (global18 = CTRLU);
          IF NOT local10 THEN
            Editor.currentFileLine := Editor.Proc6(local2, Editor.beforeCursor) + Editor.currentFileLine;
          ELSE (* 0476 *)
            IF NOT local7 THEN
              DEC(Editor.currentFileLine, Editor.Proc6(Editor.editBuffer, local2));
              Editor.MoveBytesBeforeCursorToAfter(ADDRESS(Editor.beforeCursor) - Editor.editBuffer);
            END; (* 048B *)
          END; (* 048B *)
          IF local7 OR EditDisk.global2 OR (global18 = CTRLU) THEN EXIT END;
          IF NOT local10 THEN EditDisk.proc2 END;
        END; (* 04a3 *)
        
        Editor.UpdateColumn;
        IF local7 THEN
          local13 := FALSE;
          IF NOT EditDisk.global2 AND (ADDRESS(Editor.afterCursor) > Editor.endBuffer - Editor.global15) THEN
            EditDisk.proc2
          END;
          IF NOT local10 THEN
            Editor.currentRow := Editor.currentRow + (Editor.currentFileLine - local6)
          ELSE (* 04cb *)
            Editor.currentRow := Editor.currentRow - (local6 - Editor.currentFileLine)
          END; (* 04D4 *)
          IF (Editor.currentRow >= Editor.lastRow) AND (global17 OR (local14 > global12)) THEN
            Editor.currentRow := Editor.lastRow DIV 2 + 1;
            Editor.Proc2;
          END; (* 04EE *)
          IF global17 THEN
            local8 := TRUE;
            IF NOT (7 IN global13) THEN
              Editor.PrintStatusLine("  REPLACE? (Y/N) ", Editor.lastColumn-16);
              IF Editor.currentCol < Editor.lastColumn THEN
                Terminal.GotoXY(Editor.currentCol, Editor.currentRow);
              ELSE (* 0524 *)
                Terminal.GotoXY(Editor.lastColumn, Editor.currentRow);
              END; (* 052A *)
              local11 := Editor.GetKey();
              proc10(local11);
              local8 := (Editor.proc16(local11) = 'Y');
            END; (* 0537 *)
            IF local8 THEN
              IF ADDRESS(Editor.afterCursor) <= ADDRESS(Editor.beforeCursor) + global11 THEN
                Editor.Proc14
              END; (* 0545 *)
              IF local10 THEN Editor.MoveBytesAfterCursorToBefore(global3) END;
              local2 := ADDRESS(Editor.beforeCursor) - global3;
              Editor.UpdateFirstModifiedPos(local2);
              MOVE(global5, local2, global11);
              IF (Editor.selectionEnd > local2) AND (Editor.selectionEnd <= ADDRESS(Editor.beforeCursor)) THEN
                Editor.selectionEnd := local2 + global11
              END; (* 056a *)
              IF (Editor.selectionStart > local2) AND (Editor.selectionStart < ADDRESS(Editor.beforeCursor)) THEN
                Editor.selectionStart := local2
              END;
              Editor.beforeCursor := local2 + global11;
              IF local10 THEN Editor.MoveBytesBeforeCursorToAfter(global11) END;
              Editor.UpdateColumn;
              Editor.Proc3;
            END; (* 0589 *)
          END; (* 0589 *)
        ELSE (* 058B *)
          IF NOT local10 
          THEN Editor.currentRow := Editor.lastRow - 1
          ELSE Editor.currentRow := 1; EditDisk.proc12 
          END; (* 059B *)
          Editor.Proc2;
          IF local13 THEN EditDisk.proc10(NOTFOUND, global4^) END; (* 05a9 *)
        END; (* 05A9 *)
      UNTIL NOT (local7 AND global17 AND ((0 IN global13) OR (local11 = CTRLL)));
    END; (* 05BF *)
  END; (* 05BF *)
END proc1;

PROCEDURE SelectionSize(): CARDINAL;
BEGIN
  IF NOT selectionOk THEN EditDisk.proc11("No block is marked") END;
  IF (Editor.selectionStart < ADDRESS(Editor.beforeCursor)) 
  AND  (Editor.selectionEnd > ADDRESS(Editor.afterCursor)) THEN
    Editor.currentFileLine := Editor.Proc6(Editor.afterCursor, Editor.selectionEnd) + Editor.currentFileLine;
    Editor.MoveBytesAfterCursorToBefore(Editor.selectionEnd - ADDRESS(Editor.afterCursor));
  END; 
  RETURN Editor.selectionEnd - Editor.selectionStart
END SelectionSize;

PROCEDURE CopyBlock;
BEGIN
  selectionSize := SelectionSize();
  IF ADDRESS(Editor.afterCursor) - ADDRESS(Editor.beforeCursor) <= selectionSize + 1 THEN
    REPEAT
      Editor.Proc14;
    UNTIL ADDRESS(Editor.afterCursor) - ADDRESS(Editor.beforeCursor) > selectionSize + 1;
    selectionSize := SelectionSize();
  END; (* 062B *)
  selectionStart := Editor.selectionStart;
  selectionEnd := Editor.selectionEnd;
  Editor.selectionStart := Editor.beforeCursor;
  MOVE(selectionStart, Editor.selectionStart, selectionSize);
  Editor.beforeCursor := ADDRESS(Editor.beforeCursor) + selectionSize;
  Editor.currentFileLine := Editor.Proc6(Editor.selectionStart, Editor.beforeCursor) + Editor.currentFileLine;
  Editor.selectionEnd := Editor.beforeCursor;
  Editor.UpdateFirstModifiedPos(Editor.selectionStart);
  Editor.UpdateColumn;
END CopyBlock;

(* Delete a section of text from selectionStart to selectionEnd *)
PROCEDURE DeleteBlock;
BEGIN
  IF selectionStart >= ADDRESS(Editor.afterCursor ) THEN
    Editor.UpdateFirstModifiedPos(Editor.beforeCursor);
    MOVE(Editor.afterCursor, ADDRESS(Editor.afterCursor)+selectionSize, selectionStart - ADDRESS(Editor.afterCursor));
    Editor.afterCursor := ADDRESS(Editor.afterCursor)+selectionSize;
  ELSE (* 067c *)
    Editor.UpdateFirstModifiedPos(selectionStart);
    DEC(Editor.currentFileLine,Editor.Proc6(selectionStart, selectionEnd));
    MOVE(selectionEnd, selectionStart, ADDRESS(Editor.beforeCursor) - selectionEnd);
    Editor.beforeCursor := ADDRESS(Editor.beforeCursor) - selectionSize;
    DEC(Editor.selectionStart, selectionSize);
    DEC(Editor.selectionEnd, selectionSize);
  END; (* 06a5 *)
  Editor.UpdateColumn;
END DeleteBlock;

PROCEDURE proc23(param1: BOOLEAN);
VAR local2: ARRAY [0..5] OF CHAR;
VAR local3: CARDINAL;
VAR local4: CARDINAL;
VAR local5: CARDINAL;
VAR local6: CARDINAL;
BEGIN
  global17 := param1;
  global3  := proc5("FIND: ", 6, global4^);
  local6   := global3 + 15;
  IF global3 # 0 THEN
    IF param1 THEN
      IF local6 + 41 > Editor.lastColumn THEN local6 := 6 END;
      global11 := proc5("CHANGE TO: ", local6, global5^);
      INC(local6, global11 + 14);
    END; (* 06EF *)
    IF local6+14 > Editor.lastColumn THEN local6 := 6 END;
    global13 := {};
    local3 := proc5("OPTIONS: ", local6, local2);
    local5 := 0;
    global12 := 1;
    WHILE local5 < local3 DO
      IF (local2[local5] >= '0') AND (local2[local5] <= '9') THEN
        global12 := 0;
        WHILE (local5 < local3) AND (local2[local5] >= '0') AND (local2[local5] <= '9') DO
          global12 := global12 * 10 + (ORD(local2[local5]) - ORD('0'));
          INC(local5);
        END; (* 0755 *)
      ELSE (* 0757 *)
        IF CAP(local2[local5]) = 'B' 
        THEN local4 := ORD(CAP('R')) - ORD('G');
        ELSE local4 := ORD(CAP(local2[local5])) - ORD('G');
        END; (* 0788 *)
        IF local4 = 16 THEN local4 := 15 END;
        IF local4 <= 15 THEN INCL(global13, local4) END;
        INC(local5);
      END; (* 079F *)
    END; (* 07A1 *)
    proc1;
  END; (* 07A2 *)
END proc23;


PROCEDURE proc2(command: CARDINAL);
VAR row: CARDINAL;
VAR oldSelectionOk: BOOLEAN;
VAR targetRow: CARDINAL;
BEGIN
  CASE command - 32 OF
  | 1 : (* To left on line *)
        WHILE Editor.currentCol # 0 DO Editor.cursorLeft END;

  | 2 : (* To right on line *)
        WHILE Editor.afterCursor^[0] # CR DO Editor.cursorRight END;

  | 3 : (* To top of page *)
        row := 2;
        targetRow := Editor.currentRow; 
        WHILE row <= targetRow DO Editor.lineUp; INC(row) END;

  | 4 : (* To bottom of page *)
        row := Editor.currentRow;
        targetRow := Editor.lastRow - 2;
        WHILE row <= targetRow DO
          Editor.lineDown;
          INC(row);
        END;  

  | 5 : (* To top of file          *) proc16

  | 6 : (* To end of file          *) proc17

  | 7 : (* To beginning of block   *) Editor.proc11(Editor.selectionStart, 99)

  | 8 : (* To end of block         *) Editor.proc11(Editor.selectionEnd, 99)

  | 9 : (* To last cursor position *) Editor.proc12(Editor.global13, Editor.currentRow)

  |10 : (* Delete to end of line   *)
        WHILE Editor.afterCursor^[0] # CR DO Editor.deleteRightChar END;
        Editor.RefreshEndOfLine(Editor.afterCursor, Editor.currentCol, Editor.currentRow)

  |11 : (* Indent on/off           *) Editor.autoIndent := NOT Editor.autoIndent;

  |12 : (* Find                    *) proc23(FALSE)

  |13 : (* Find and replace        *) proc23(TRUE)

  |15 : (* Mark block begin        *)
        Editor.selectionStart := Editor.afterCursor; 
        oldSelectionOk  := selectionOk;
        selectionOk := (Editor.selectionEnd > Editor.selectionStart);
        IF selectionOk OR oldSelectionOk THEN Editor.Proc2 END;

  |16 : (* Mark block end          *)
        Editor.selectionEnd := Editor.beforeCursor;
        oldSelectionOk  := selectionOk;
        selectionOk := (Editor.selectionStart # NIL) AND (Editor.selectionEnd > Editor.selectionStart);
        IF selectionOk OR oldSelectionOk THEN Editor.Proc2 END;

  |18 : (* Cancel selection       *)
        selectionOk := FALSE;
        Editor.selectionEnd := NIL;
        Editor.selectionStart := NIL;
        Editor.Proc2

  |19 : (* Copy block             *)
        CopyBlock;
        IF Editor.currentRow = 1 THEN Editor.currentRow := 2 END;
        Editor.Proc2;

  |20 : (* Move block             *)
        CopyBlock;
        DeleteBlock;
        IF Editor.currentRow = 1 THEN Editor.currentRow := 2 END;
        Editor.Proc2;

  |21 : (* Delete block           *)
        selectionSize  := SelectionSize();
        selectionEnd   := Editor.selectionEnd;
        selectionStart := Editor.selectionStart;
        DeleteBlock;
        selectionOk := FALSE;
        Editor.selectionEnd := NIL;
        Editor.selectionStart := NIL;
        Editor.Proc2;
        
  |22 : (* Read block from disk   *)
        IF EditDisk.ReadFile() THEN Editor.currentRow := Editor.lastRow - 2; Editor.Proc2 END;

  |23 : (* Write block to disk    *)
        EditDisk.WriteFile

  |24 : (* Save and continue edit *)
        EditDisk.proc4;
        Editor.proc23

  |25 : (* Abandon edit           *)
        IF NOT Editor.fileModified OR proc4("ABANDON EDITED FILE ") THEN
          EditDisk.proc5;
          Editor.global19 := TRUE;
          Editor.global17 := FALSE;
        END;

  |26 : (* Delete file            *)
        EditDisk.proc9

  END;
END proc2;


END EDIT2.

