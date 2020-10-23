IMPLEMENTATION MODULE Errors;

IMPORT Compiler, Scanner, Files;
(* ComLine *)
FROM Texts IMPORT WriteCard;
FROM Loader IMPORT Call;
FROM Terminal IMPORT WriteChar, WriteString, WriteLn, ReadChar, numCols;
IMPORT EditPos;
IMPORT SymTab, CodeGen;
FROM FATDIR  IMPORT SaveCurrentDir, EnterRootDir, BackToSavedDir;
FROM SYSTEM  IMPORT MOVE, ADR, BYTE;
FROM STORAGE IMPORT MARK, RELEASE;

CONST LF = 12C; CR = 15C; EOF = 32C; DEL = 177C;
TYPE
     FLAGS      = (OVERLAY, Z80, INIT);
     ModDescPtr  = POINTER TO ModuleDesc;
     ModuleDesc = RECORD
                    reqModules: ARRAY [0..31] OF ADDRESS;
                    link : ModDescPtr;
                    name : ARRAY [0..7] OF CHAR;
                    loadAddr,checksum,procsAddr: ADDRESS;
                    CASE : BOOLEAN OF
                    | TRUE : flags : SET OF FLAGS;
                    | FALSE: bytes : ARRAY [0..1] OF BYTE;
                    END;
                    global1 : CARDINAL;
                  END;
(* $[+ remove procedure names *)

VAR global5: CARDINAL;
VAR global6: CARDINAL;
VAR global7: BOOLEAN;

VAR globalPtr [06EH]: CARDINAL;
VAR options[034CH]: BITSET;
VAR pipe   [034EH]: CHAR;

(* "proc" 18 *)
EXCEPTION usererror;

PROCEDURE proc4(msg: ARRAY OF CHAR);
BEGIN
  WriteString(msg)
END proc4;

PROCEDURE proc12(msg: ARRAY OF CHAR);
BEGIN
  WriteLn;
  proc4(msg);
  WriteLn;
  Files.Delete(Scanner.global4);
  HALT
END proc12;

PROCEDURE proc5(VAR file: FILE; VAR name: ARRAY OF CHAR; ext: Ext);
VAR local3: CARDINAL;
    local4: ARRAY [0..11] OF CHAR;
BEGIN
  local3 := HIGH(name); IF local3 > 11 THEN local3 := 11 END;
  MOVE(ADR(name), ADR(local4), local3); 
  Scanner.proc25(local4, ext, FALSE);
  SaveCurrentDir;
  EnterRootDir;
  IF NOT Files.Open(file, local4) THEN
    IF ext[0] = 'O' THEN
      proc8('E');
      proc4("ERRMSGS.OVR not found, No =");
      WriteCard(3, global5, 4);
      proc9;
    ELSE
      proc2(10, name);
    END;
  END;
  BackToSavedDir;
END proc5;

(* $[- retain procedure names *)
(* proc 17 *)
PROCEDURE DoError(param1: CHAR); (* param1: user choice E(dit)/Q(uit) *)
CONST FREEMARKER = 3AE3H;
VAR
    local2: ADDRESS;
    local3: CARDINAL;
    local4: CARDINAL;
    local5: CARDINAL;
    local6: CARDINAL;
    local7: CARDINAL;
    local8: CARDINAL;
    local9: CARDINAL;
    local10: ARRAY [0..12] OF CHAR;
    local11: FILE;
    size: LONGINT;
    saveMainModule: ModDescPtr;
    mainModule[030CH]: ModDescPtr;
    heap[0316H]: ADDRESS;
BEGIN
  IF param1 = 'E' THEN (* Edit *)
    size := Files.FileSize(Scanner.global16);
    IF size > LONG(38500) THEN size := LONG(38500) END;
    local5 := CARD(size) DIV 4 * 5 + 1500;
    IF local5 < 5500 THEN local5 := 5500 END;
    local7 := ADR(local10) - CARDINAL(Scanner.global4);
    IF local5 > local7 THEN local5 := local7 END;
    Files.Close(Scanner.global16);
    saveMainModule := mainModule;
    mainModule := saveMainModule^.link^.link^.link;
    Scanner.proc5(local2);
    local9 := local2 - (Scanner.global21 + 4096);
    local3 := local2 - (CodeGen.global4 - CodeGen.global2);
    MOVE(local2-local9, local3-local9, local9);
    Scanner.proc6(local3);
    local6 := ADR(local10) - local3;
    IF local5 > local6 THEN
      local8 := local5 - local6;
      local10 := "CBACKUP.$$$";
      Files.Create(local11, local10);
      Files.WriteBytes(local11, local3-local8, local8);
      Files.SetPos(local11, LONG(0));
      Scanner.proc6(local3 - local8);
    END; (* 018a *)
   
    EditPos.editPos := Scanner.global25;   (* FF: was Editor.editPosition := ... *)
    Call("EDITERR");                       (* FF: was Editor.Edit; *)
    global2 := EditPos.editPos;            (* FF: was global2 := Editor.editPosition *)

    IF local5 > local6 THEN
      Scanner.proc6(local3);
      IF Files.ReadBytes(local11, local3-local8, local8)<>local8 THEN
        EditPos.global17 := FALSE          (* FF: was Editor.global17 := FALSE *)
      END;
      Files.Delete(local11);
    END; (* 01B2 *)
    MOVE(local3-local9, local2-local9, local9);
    heap := local2 + 60;
    local2^ := FREEMARKER;
    mainModule := saveMainModule;
    IF EditPos.global17 THEN               (* FF: was IF Editor.global17 *)
      IF global4 THEN SymTab.proc7 END;
      RAISE usererror
    END;
  END; (* 01DD *)
  proc12("");

EXCEPTION Files.DiskFull:
    heap := local2 + 60;
    local2^ := FREEMARKER;
    Files.Delete(local11);
    proc12("ERROR: DISK FULL")
END DoError;

(* $[+ retain procedure names *)

PROCEDURE proc19(param1: ADDRESS);
VAR local2: SymTab.T1;
    local3: CARDINAL;
    local4: CARDINAL;
BEGIN
  local3 := 0;
  local4 := 16;
  WHILE local3 <= local4 DO
    local2 := SymTab.global8^[local3];
    WHILE (local2 <> NIL) AND (param1 <= ADDRESS(local2)) DO
      local2 := local2^.link0
    END;
    SymTab.global8^[local3] := local2;
    INC(local3);
  END;
END proc19;

PROCEDURE proc11;
VAR local2: SymTab.T1;
    local3: ADDRESS;
BEGIN
  Scanner.proc5(local3);
  local2 := SymTab.global9^.link1;
  WHILE local2 <> NIL DO
    IF (local2^.word4 = 3) AND (local2^.link2^.word4 = 6)
    AND (local2^.link2^.link2 <> NIL)
    AND (local3 <= ADDRESS(local2^.link2^.link2))
    THEN
      local2^.link2^.link2 := NIL;
    END;
    local2 := local2^.link0;
  END;
  proc19(local3);
  Scanner.proc29;
END proc11;

CONST BUT = "but ";
CONST EVALUATED = " evaluated";
CONST DIFFERENT = "Different ";
CONST EDITQUIT  = "E(dit, Q(uit ";

PROCEDURE proc24(VAR param2: INTEGER;  param1: BITSET): BOOLEAN;
BEGIN
  REPEAT
    INC(param2);
    IF CARDINAL(param2) IN param1 THEN RETURN TRUE END;
  UNTIL param2 >= 16;
  RETURN FALSE
END proc24;

PROCEDURE proc25(ptr: SymTab.T1): SymTab.T1;
BEGIN
  IF (ptr^.link0 = NIL) AND (ptr^.word4 = 1) THEN
    ptr := ptr^.link2
  END;
  RETURN ptr
END proc25;

PROCEDURE proc26(n: CARDINAL; str: ARRAY OF CHAR);
VAR i,j: CARDINAL;
BEGIN
  i := 0;
  j := 0;
  WHILE i < n DO
    WHILE (j <= HIGH(str)) AND (str[j] # '/') DO INC(j) END;
    INC(j); INC(i);
  END;
  WHILE (j <= HIGH(str)) AND (str[j] # '/') DO
    WriteChar(str[j]);
    INC(j)
  END;
END proc26;

PROCEDURE proc6(param1: CARDINAL);
BEGIN
  proc26(param1, "Undefined/Constant/Exception/Type/Variable/Procedure/Module/")
END proc6;

PROCEDURE proc27(n: CARDINAL);
BEGIN
  proc26(n,"Enumeration/Subrange///Set/Pointer/Opaque Type///Procedure/Record/Array/")
END proc27;

PROCEDURE proc28(ptr: SymTab.T1);
BEGIN
  IF ptr^.link0 # NIL THEN
    proc4(ptr^.link0^.link1^)
  ELSE
    proc27(ptr^.word4)
  END;
END proc28;

PROCEDURE proc29(param1: CHAR);
VAR ch: CHAR;
VAR local3: CARDINAL;
VAR local4: Scanner.Identifier;
BEGIN
  local3 := Scanner.procPtr27(local4, param1);
  IF local3 # 0 THEN proc4(local4)
  ELSE
    WriteChar('"');
    local3 := 0;
    WHILE (local3 <= 24) AND (global3^[local3+2] # param1) DO INC(local3, 3) END;
    IF (local3 <= 24) AND ((local3 DIV 3) IN options) THEN
      WriteChar(global3^[local3]);
      WriteChar(global3^[local3+1]);
    ELSE
      IF ORD(param1) = 8 THEN
        WriteChar(pipe);
      ELSE
        ch := '!';
        WHILE (ch < DEL) AND (Scanner.global24^[ORD(ch)] # param1) DO INC(ch) END;
        IF ch < DEL THEN WriteChar(ch) END;
      END; (* 0433 *)
    END; (* 0433 *)
    WriteChar('"');
  END; (* 0437 *)
END proc29;

PROCEDURE proc7;
BEGIN
  IF Scanner.global5 = 0C THEN
    IF Scanner.global6 THEN proc4('literal "') ELSE proc4('identifier "') END;
    proc4(Scanner.global11);
    WriteChar('"');
  ELSE
    proc29(Scanner.global5)
  END; (* 046E *)
  proc4(" found")
END proc7;

PROCEDURE proc8(param1: CHAR);
VAR local2: CARDINAL;
VAR local3: CARDINAL;
VAR local5: LONGINT;
VAR local6: CHAR;
BEGIN
  IF NOT( 0 IN Scanner.global2) THEN
    WriteLn;
    local5 := Files.NextPos(Scanner.global16);
    local3 := globalPtr;
    REPEAT
      DEC(local3);
      Files.SetPos(Scanner.global16, LONG(local3));
      Files.ReadByte(Scanner.global16, local6);
    UNTIL (local3 = 0) OR (local6 = LF);
    INC(local3, ORD(Scanner.global3 = LF));
    Scanner.global26 := Scanner.global25 - local3 - 6;
    Files.SetPos(Scanner.global16, LONG(local3));
    WHILE local3 # globalPtr DO
      Files.ReadByte(Scanner.global16, local6);
      IF local6 # EOF THEN WriteChar(local6) END;
      INC(local3);
    END;
    Files.SetPos(Scanner.global16, local5);
    INCL(Scanner.global2, 0);
  END; (* 04f6 *)
  IF param1 # 'X' THEN
    WHILE (Scanner.global3 # CR) AND (Scanner.global3 # CHR(255)) DO
      Scanner.proc2
    END;
  END; (*050D*)
  WriteLn;
  IF Scanner.global26 + 5 < numCols THEN
    local2 := 0;
    WHILE local2 < Scanner.global26 + 5 DO WriteChar(' '); INC(local2) END;
    proc4("^   ");
  END; (* 0535 *)
  IF param1 = 'X' THEN proc4("Warning") 
  ELSE
    proc4("Error");
    proc26(ORD(param1)-ORD('A'),
        " in Syntax/ in Identifier/ in Type/, Compiler Limit Exceeded//,illegal Constant/, Implementation Restriction/");
  END;
  WriteChar(':'); WriteLn;
END proc8;

PROCEDURE proc9;
VAR ch: CHAR;
BEGIN
  WriteLn;
  REPEAT
    proc4(EDITQUIT);
    WriteChar('>');
    ReadChar(ch);  ch := CAP(ch);
    WriteChar(ch);
    WriteLn;
  UNTIL (ch = 'E') OR (ch = 'Q');
 DoError(ch);
END proc9;

PROCEDURE proc3(param1: ADDRESS);
VAR ch: CHAR;
VAR local3: POINTER TO RECORD w0: WORD; w1: BufPtr END;
VAR local4: POINTER TO ARRAY [0..1] OF CHAR;
VAR local5: BITSET;
BEGIN
  local5 := Scanner.global2;
  IF CARDINAL(param1) <= 1 THEN
    proc10(param1+50, local4^)
  ELSIF CARDINAL(param1) = 2 THEN
    proc10(52, Scanner.global11)
  ELSE
    local3 := param1;
    proc10(52, local3^.w1^);
  END; (* 0628 *)
  Scanner.global2 := local5;
  WriteLn;
  REPEAT
    proc4(EDITQUIT);
    proc4("C(ontinue >");
    ReadChar(ch);
    ch := CAP(ch);
    WriteChar(ch); WriteLn;
  UNTIL ORD(ch) - ORD('C') IN {0,2,14};
  IF ch # 'C' THEN DoError(ch) END;
END proc3;

PROCEDURE proc10(param3: CARDINAL; VAR msg: ARRAY OF CHAR);
VAR errFile: Files.FILE;
VAR local3: CARDINAL;
VAR local4: CHAR;
VAR local5: ARRAY [0..7] OF CHAR;
VAR local6: ADDRESS;
BEGIN
  MARK(local6);
  IF param3 < 100 THEN
    global5 := param3;
    local5  := "ERRMSGS "; (* NB: one extra char *)
    proc5(errFile, local5, "OVR");
    Files.SetPos(errFile, LONG(param3 DIV 20 * 650));
    local3  := 0;
    WHILE local3 < param3 MOD 20 DO
      REPEAT
        Files.ReadByte(errFile, local4);
      UNTIL local4 = LF;
      INC(local3);
    END; (* 06b7 *)
    Files.ReadByte(errFile, local4);
    proc8(local4);
    REPEAT
      Files.ReadByte(errFile, local4);
      IF local4 = '&' THEN proc4(msg)
      ELSE WriteChar(local4)
      END; (* 06d1*)
    UNTIL (local4 = CR) OR (local4 = EOF);
  END; (* 06dc *)
  RELEASE(local6);
END proc10;

PROCEDURE proc1(param1: CARDINAL);
VAR dummy: POINTER TO ARRAY [0..1] OF CHAR;
BEGIN
  proc2(param1, dummy^);
END proc1;

PROCEDURE proc2(param3: CARDINAL; VAR msg: ARRAY OF CHAR);
BEGIN
  proc10(param3,msg);
  proc9;
END proc2;

PROCEDURE proc16(param2: BITSET; param1: INTEGER);
VAR local2, local3: INTEGER;
VAR local4: CARDINAL;
BEGIN
  proc8('A');
  local2 := -1;
  local4 := 0;
  IF proc24(local2, param2) THEN
    proc29(CHR(local2 + param1));
    INC(local4);
  END;
  IF proc24(local2, param2) THEN
    local3 := local2;
    INC(local4);
    WHILE proc24(local3, param2) DO
      WriteChar(',');
      proc29(CHR(local2 + param1));
      local2 := local3;
      INC(local4);
    END; (* 0730 *)
    proc4(" or ");
    proc29(CHR(local2 + param1));
  END; (* 073d *)
  proc4(" expected, ");
  IF local4 > 5 THEN WriteLn END;
  proc4(BUT);
  proc7;
  proc9;
END proc16;

PROCEDURE proc30(param1: ADDRESS);
VAR local2: POINTER TO RECORD w0: WORD; w1: BufPtr END;
BEGIN
  proc4(" required");
  IF param1 > 255 THEN
    local2 := param1;
    IF local2^.w1 # NIL THEN
      proc4(' for "');
      proc4(local2^.w1^);
      WriteChar('"');
    END; (* 078A *)
    RETURN
  END; (* 078B *)
  IF param1 # NIL THEN
    proc4(" for ");
    proc29(CHR(param1));
  END; (* 079b *)
END proc30;

PROCEDURE proc14(param3: BITSET; param2: ADDRESS; param1: CARDINAL);
VAR local2: INTEGER;
VAR local3: SymTab.T1;
BEGIN
  proc8('C');
  local3 := param2;
  IF    param3 = {0,1}  THEN proc4("Bounded Type")
  ELSIF param3 = {4,8}  THEN proc4("REAL or Set Type")
  ELSE
    IF 2 IN param3 THEN
      IF 0 IN param3    THEN proc4("Scalar")
                        ELSE proc4("Numeric") END;
      IF 5 IN param3    THEN proc4(",Pointer") END;
      IF 4 IN param3    THEN proc4(" or Set") END;
      proc4(" Type");
      IF NOT( {7,8} - param3 = {} ) THEN 
        proc4(",excluding");
        IF NOT( 7 IN param3 ) THEN proc4(" LONGINT and") END;
        proc4(" REAL,");
      END; (* 085b *)
    ELSE
      local2 := -1;
      IF proc24(local2, param3) THEN proc27(local2) END; (* 086b *)
    END; (* 086b *)
  END; (* 086B *)
  proc30(param1);
  WriteChar(',');
  WriteLn;
  proc4(BUT);
  IF (local3^.link0 # NIL) AND (6 IN local3^.link0^.word3) THEN
    proc28(local3)
  ELSE
    proc27(local3^.word4)
  END;
  proc4(EVALUATED);
  proc9;
END proc14;

PROCEDURE proc15(param4, param3: T1; param2: ARRAY OF CHAR);
VAR local2, local3: T1;
BEGIN
  proc8('C');
  local2 := proc25(param4);
  local3 := proc25(param3);
  IF  (local2^.link0 = NIL)
  AND (local3^.link0 = NIL)
  AND (local2^.word4 = local3^.word4) 
  THEN
    proc4(DIFFERENT);
    proc27(local2^.word4);
    proc4(" types");
  ELSE
    proc28(local2);
    proc4(" and ");
    proc28(local3);
  END; (* 08db *)
  proc4(" are");
  proc4(param2);
  proc4(" incompatible");
  proc9;
END proc15;

PROCEDURE proc13(param3, param2: T1; param1: ADDRESS);
VAR local2, local3: T1;
BEGIN
  proc8('C');
  local2 := param3;
  local3 := param2;
  IF local2^.link0 = NIL THEN local2 := proc25(local2) END;
  IF local3^.link0 = NIL THEN local3 := proc25(local3) END;
  IF (local2^.link0 # NIL) OR (local2^.word4 # local3^.word4) THEN
    proc28(local2);
    proc30(param1);
    proc4(", but ");
    IF (local3^.link0 = NIL) AND (local2^.word4 = local3^.word4) THEN
      proc4("other ")
    END;
    proc28(local3);
    proc4(EVALUATED);
  ELSE
    proc4(DIFFERENT);
    proc27(local2^.word4);
    proc30(param1);    
  END; (*095c *)
  proc9;
END proc13;

END Errors.