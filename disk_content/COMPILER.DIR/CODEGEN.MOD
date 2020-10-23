IMPLEMENTATION MODULE CodeGen;
IMPORT Scanner, Files, Compiler;
FROM ComLine IMPORT codepos, execute;
FROM SYSTEM IMPORT ADR, MOVE;

CONST
    OPINVALID =   0;
    OPRAISE   =   1;
    OPLDPROC  =   2;
    OPLDPARAM =   3;
    OPLLD     =   8;
    OPLGD     =   9;
    OPLSD     =  0AH;
    OPLED     =  0BH;
    OPLDEXT   =  0CH;
    OPLXB     =  0DH;
    OPLXW     =  0EH;
    OPLXD     =  0FH;

    OPLDIX    =  10H;
    OPLDIXN   =  11H;
    OPLONGREAL=  12H;
    OPSETPARM =  13H;
    OPSLD     =  18H;
    OPSGD     =  19H;
    OPSSD     =  1AH;
    OPSED     =  1BH;
    OPSTEXT   =  1CH;
    OPXSB     =  1DH;
    OPSXW     =  1EH;
    OPSXD     =  1FH;

    OPDUP     =  20H;
    OPSWAP    =  21H;
    OPLLW2    =  22H;
    OPLLWN    =  2CH;
    OPLGWN    =  2DH;
    OPLSWN    =  2EH;
    OPLEWN    =  2FH;
    
    OPMOVB    =  30H;
    OPMOVS    =  31H;
    OPSLW2    =  32H;
    OPSLWN    =  3CH;
    OPSGWN    =  3DH;
    OPSSWN    =  3EH;
    OPSEWN    =  3FH;

    OPEXTENDED=  40H;
    OPLSD0    =  41H;
    OPLGW2    =  42H;

    OPENDPROG =  50H;
    OPSSD0    =  51H;
    OPSGW2    =  52H;
 
    OPLSW0    =  60H;
    OPSSW0    =  70H;

    OPLLA     =  80H;
    OPLGA     =  81H;
    OPLSA     =  82H;
    OPLEA     =  83H;
    OPLEAVE   =  84H;
    OPFLEAVE  =  85H;
    OPLFLEAVE =  86H;
    OPASM     =  87H;
    OPLEAVE0  =  88H;
    OPCALLREL =  8CH;
    OPLIB     =  8DH;
    OPLIW     =  8EH;
    OPLID     =  8FH;

    OPLI0     =  90H;
    OPLI15    =  9FH;

    OPEQUAL   = 0A0H;
    OPNEQ     = 0A1H;
    OPLESS    = 0A2H;
    OPGREATER = 0A3H;
    OPLESSEQ  = 0A4H;
    OPGREATEQ = 0A5H;
    OPADD     = 0A6H;
    OPSUB     = 0A7H;
    OPMUL     = 0A8H;
    OPDIV     = 0A9H;
    OPMOD     = 0AAH;
    OPEQ0     = 0ABH;
    OPINC     = 0ACH;
    OPDEC     = 0ADH;
    OPADDN    = 0AEH;
    OPSUBN    = 0AFH;

    OPSHL     = 0B0H;
    OPSHR     = 0B1H;
    OPILESS   = 0B2H;
    OPIGREATER= 0B3H;
    OPILESSEQ = 0B4H;
    OPIGREATEQ= 0B5H;
    OPNOT     = 0B6H;
    OPCOMPL   = 0B7H;
    OPIMUL    = 0B8H;
    OPIDIV    = 0B9H;
    OPLG2CARD = 0BAH;
    OPLG2INT  = 0BBH;
    OPABS     = 0BCH;
    OPINT2LG  = 0BDH;
    OPLG2FLOAT= 0BEH;
    OPFLOAT2LG= 0BFH;

    OPADDOV   = 0C0H;
    OPSUBOV   = 0C1H;
    OPMULOV   = 0C2H;
    OPSYSTEM  = 0C3H;
    OPSTRCOMP = 0C4H;
    OPDCOMP   = 0C5H;
    OPDADD    = 0C6H;
    OPDSUB    = 0C7H;
    OPDDIV    = 0C8H;
    OPDMOD    = 0C9H;
    OPNEQ0    = 0CAH;
    OPDABS    = 0CBH;
    OPCASE    = 0CDH;
    OPRETURN  = 0CEH;
    OPPUSHREL = 0CFH;

    OPIADDOV  = 0D0H;
    OPISUBOV  = 0D1H;
    OPSTKRES  = 0D2H;
    OPSTRRES  = 0D3H;
    OPENTER   = 0D4H;
    OPREALCMP = 0D5H;
    OPREALADD = 0D6H;
    OPREALSUB = 0D7H;
    OPREALMUL = 0D8H;
    OPREALDIV = 0D9H;
    OPRANGE   = 0DAH;
    OPIRANGE  = 0DBH;
    OPLIMIT   = 0DCH;
    OPPOSITIV = 0DDH;
    OPANDJP   = 0DEH;
    OPORJP    = 0DFH;

    OPJP      = 0E0H;
    OPJPCOND  = 0E1H;
    OPJPF     = 0E2H;
    OPJPFCOND = 0E3H;
    OPJPB     = 0E4H;
    OPJPBCOND = 0E5H;
    OPBITOR   = 0E6H;
    OPBITIN   = 0E7H;
    OPBITAND  = 0E8H;
    OPBITXOR  = 0E9H;
    OPPOWER2  = 0EAH;
    OPEXTCALLS= 0EBH;
    OPINTCALL = 0ECH;
    OPCALL    = 0EDH;
    OPCALLFRM = 0EEH;
    OPEXTCALL2= 0EFH;

    OPEXTCALL1= 0F0H;
    OPCALL1   = 0F1H;

TYPE Record = RECORD 
                word0: CARDINAL;
                CASE : CARDINAL OF
                | 0: word1,word2: CARDINAL; 
                | 1: ptr1: POINTER TO ARRAY [0..255] OF CHAR;
                | 2: long1: LONGINT;
                END;
              END;
     RecordPtr = POINTER TO Record;

VAR 
(*  6 *) global6 : POINTER TO ARRAY [0..2047] OF BYTE;
(*  7 *) global7 : [0..9];
(*  8 *) global8 : [0..5];
(*  9 *) global9 : CARDINAL;
(* 10 *) global10: CARDINAL;
(* 11 *) global11: ARRAY [0..15] OF Record;
(* 12 *) global12: [0..16];
(* 13 *) global13: WORD;
(* 14 *) global14: BOOLEAN;
(* 15 *) global15: BOOLEAN;
(* 16 *) unused1: ARRAY [0..11] OF BYTE;
(* 17 *) unused2: WORD;

EXCEPTION errorfound;

(* $[+ remove procedure names *)

PROCEDURE proc26(param1: BOOLEAN);
EXCEPTION CE;
BEGIN
  IF NOT param1 THEN RAISE CE END;
END proc26;

PROCEDURE proc23;
BEGIN 
  Files.SetPos(Scanner.global4, LONG(global3));
  Files.WriteBytes(Scanner.global4, ADDRESS(global6), 2048);
  INC(global3, 2048);
  INC(global4, 2048);
  MOVE(ADDRESS(global6) + 2048, ADDRESS(global6), global2 - global3);
END proc23;

PROCEDURE proc28;
VAR
    local2 : CARDINAL;
    local3 : CARDINAL;
    local4 : CARDINAL;
BEGIN
  local2 := global2 DIV 512;
  local3 := (local2 - ORD(local2 <> 0)) * 512;
  IF local3 < global3 THEN
    local4 := global3 - local3;
    IF global2 > global3 THEN
      MOVE(ADDRESS(global6), ADDRESS(global6)+local4, global2-global3);
    END;
    Files.SetPos(Scanner.global4, LONG(local3));
    proc26(Files.ReadBytes(Scanner.global4, ADDRESS(global6), local4) = local4);
    global3 := local3;
    global4 := global3 + 4096;
  END;
END proc28;

PROCEDURE proc19(param1: CARDINAL): CARDINAL;
VAR byte: BYTE;
BEGIN
  IF param1 >= global3 THEN RETURN CARDINAL(global6^[param1-global3]) END;
  Files.SetPos(Scanner.global4, LONG(param1));
  Files.ReadByte(Scanner.global4, byte);
  RETURN CARDINAL(byte)
END proc19;

PROCEDURE proc20(param2: BYTE; param1: CARDINAL);
BEGIN
  IF param1 >= global3 THEN
    global6^[param1-global3] := param2;
    RETURN
  END;
  Files.SetPos(Scanner.global4, LONG(param1));
  Files.WriteByte(Scanner.global4, param2);
END proc20;

PROCEDURE proc29;
BEGIN
  IF global2 >= codepos THEN RAISE errorfound END;
END proc29;

PROCEDURE Emit1(param1: BYTE); 
BEGIN 
  IF global2 >= global4 THEN proc23 END;
  global6^[global2-global3] := param1;
  INC(global2);
  IF global15 THEN proc29 END;
END Emit1;

PROCEDURE Emit2(param2, param1: BYTE);
BEGIN 
  IF global2 + 1 >= global4 THEN proc23 END;
  global6^[global2 - global3] := param2;
  global6^[global2 + 1 - global3] := param1;
  INC(global2, 2);
  IF global15 THEN proc29 END;
END Emit2;

PROCEDURE EmitWord(param1: WORD);
VAR ptr: ADDRESS;
BEGIN
  IF global2 + 1 >= global4 THEN proc23 END;
  ptr := ADDRESS(global6) + (global2 - global3);
  ptr^ := param1;
  INC(global2, 2);
  IF global15 THEN proc29 END;
END EmitWord;

PROCEDURE EmitString(param1: ADDRESS);
VAR ptr : POINTER TO ARRAY [0..1] OF BYTE;
BEGIN 
  ptr := param1;
  REPEAT
    Emit1(ptr^[0]);
    ptr := ADDRESS(ptr) + 1;
  UNTIL ORD(ptr^[0]) = 0;
  IF global15 THEN proc29 END;
END EmitString;

PROCEDURE proc30;
VAR local2: CARDINAL;
  PROCEDURE proc31(param1: CARDINAL): CARDINAL;
  BEGIN
    CASE param1 OF
    | 8    : RETURN  60H
    | 9    : RETURN 0ECH
    | 1, 5 : RETURN  2CH
    | 2, 6 : RETURN  08H
    | 3, 7 : RETURN 0
    END;
  END proc31;
BEGIN
  global14 := FALSE;
  local2 := 0;
  IF global7 <> 9 THEN
    global10 := global10 DIV 2;
    local2 := global7 DIV 4 * (ORD((global7 MOD 4) <> 3) * 12 + 4);
  END;
  IF global8 = 4 THEN
    IF global9 = 1 
    THEN Emit1(OPLDIX) 
    ELSE Emit2(OPLDIXN, global9) 
    END;
    IF global10 >= 128 THEN (* $T+ *)
      Emit2(OPSUBN, (256 - global10) * 2);
      global10 := 0; (* $T- *)
    END;
    global8 := 2;
  END;
  IF global7 IN {3,7} THEN Emit1(OPLONGREAL) END;
  IF global8 = 5 THEN
    IF global7 IN {3,7} 
    THEN Emit2(global7 DIV 4 + 8, 0)
    ELSE Emit1(global7 MOD 4 + local2 + 13)
    END;
  ELSE
    IF global7 IN {0,4} THEN INC(global7) END;
    IF global8 = 3 THEN
      IF (global10 <= 15) AND (global9 <= 15) AND (global7 IN {1,5,9})
      THEN 
        IF global7 = 9 THEN local2 := 0E4H END;
        Emit2(local2 + 12, global9 * 16 + global10);
        RETURN
      END;
      Emit2(proc31(global7)+local2+3, global9);
      Emit1(global10);
    ELSE
      CASE global7 OF
      | 9:
          IF (global8 = 1) AND (global10 IN {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15})
          THEN Emit1(global10 + OPEXTCALL1); RETURN
          END;
      | 8:
          IF (global8 = 2) AND (global10 = 0) THEN RETURN END;
      | 1, 5:
          IF (global8 <> 2) OR NOT Compiler.global2 THEN
            IF global8 = 0 THEN
              IF global10 <= 7 THEN
                Emit1(global10 + local2);
                RETURN
              ELSIF global10 >= 245 THEN
                Emit1(local2 + 288 - global10);
                RETURN
              END;
            ELSE
              IF (global10 >= (4 - global8 * 2)) AND (global10 <= 15) THEN
                Emit1((global8 + 1) * 32 + global10 + local2);
                RETURN
              END;
            END;
          END;
      | 2, 6:
          IF (global8 = 2) AND (global10 = 0) THEN
            Emit1(local2 + (OPLGW2 - 1));
            RETURN
          END;
      END;
      Emit2(proc31(global7) + global8 + local2, global10);
      IF Compiler.global2 AND (global7 = 8) AND (global8 <= 1) THEN
        Emit1(global9)
      END;
    END;
  END;
END proc30;

PROCEDURE proc32;
VAR
    local2 : CARDINAL;
    local3 : CARDINAL;
    local4 : CARDINAL;
    local5 : POINTER TO Record;
BEGIN
  IF global14 THEN proc30
  ELSE
    IF global12 <> 0 THEN
      local2 := 0;
      WHILE local2 < global12 DO
        local5 := ADR(global11[local2]);
        CASE local5^.word0 OF
        | 0: (* 02EE *)
            IF local5^.word2 <> 0 THEN Emit2(2, local5^.word2)
            ELSE Emit2(OPCALLREL, Scanner.proc24(local5^.word1, 128));
                 EmitString(local5^.word1);
            END;
        | 1: (* 0308 *)
            IF local5^.word1 <= 255 THEN
              IF local5^.word1 <= 15
              THEN Emit1(local5^.word1 + OPLI0)
              ELSE Emit2(OPLIB, local5^.word1)
              END;
            ELSE (* 0323 *)
              Emit1(OPLIW);
              EmitWord(local5^.word1)
            END; (* 0329 *)
        | 2: (* 032A *)
            Emit1(OPLID);
            EmitWord(local5^.word1);
            EmitWord(local5^.word2);
        | 3: (* 0334 *)
            local4 := 8;
            REPEAT (* 0336 *)
              DEC(local4, 4);
              Emit1(OPLID);
              local3 := 0;
              REPEAT (* 033F *)
                Emit1(local5^.ptr1^[local4 + local3]);
                INC(local3);
              UNTIL local3 > 3;
            UNTIL local4 = 0;
            IF Compiler.global2 THEN Emit2(0, 22) END;
        | 4: (* 035B *)
            IF CARDINAL(ABS(INTEGER(local5^.word1))) <= 255 THEN
              IF local5^.word1 <> NIL THEN
                IF ABS(INTEGER(local5^.word1)) = 1 THEN
                  Emit1(ORD(INTEGER(local5^.word1) < 0) + OPINC)
                ELSE (* 0378 *)
                  Emit2(ORD(INTEGER(local5^.word1) < 0) + OPADDN,
                        ABS(INTEGER(local5^.word1)));
                END;
              END; (* 0382 *)
            ELSE (* 0384 *)
              Emit1(OPLIW);
              EmitWord(local5^.word1);
              Emit1(OPADD);
            END; (* 038d *)
(* $T+ generates ELSE RAISE CaseSelectError *)
        END; (* CASE *)
        INC(local2);
      END; (* 03A8 *)
      global12 := 0;
    END (* 03AA *)
  END (* 03aa *);
END proc32;

PROCEDURE proc33(param1: WORD);
BEGIN
  (* commented contents ? *)
END proc33;

PROCEDURE proc34(param2, param1: WORD);
VAR unused: WORD;
BEGIN
  (* commented contents ? *)
END proc34;

PROCEDURE proc4;
VAR unused: WORD;
BEGIN 
  IF global5 THEN
    global12 := global12 + ORD(global14) - 1;
    global14 := FALSE;
  END;
END proc4;

PROCEDURE proc5(param4, param3, param2, param1: CARDINAL);
BEGIN 
  IF global5 THEN
    proc32;
    global7  := param4;
    global8  := param3;
    global9  := param2;
    global10 := param1;
    global14 := TRUE;
    IF param4 IN {4,5,6,7,9} THEN proc30 END;
  END;
END proc5;

(* $T- *)

PROCEDURE proc8(param1: CARDINAL);
VAR ptr : POINTER TO Record;
BEGIN 
  IF global5 THEN
    IF global14 THEN proc30 END;
    IF global12 >= 16 THEN Scanner.proc26(90) END;
    ptr := ADR(global11[global12]);
    ptr^.word0 := 1;
    ptr^.word1 := param1;
    INC(global12);
  END;
END proc8;

PROCEDURE proc9(param3: CARDINAL; param1: LONGINT);
VAR ptr : POINTER TO Record;
BEGIN 
  IF global5 THEN
    IF global14 THEN proc30 END;
    IF global12 >= 16 THEN Scanner.proc26(90) END;
    ptr := ADR(global11[global12]);
    ptr^.word0 := param3;
    ptr^.long1 := param1;
    INC(global12);
  END;
END proc9;

PROCEDURE proc6(param2, param1 : CARDINAL);
VAR ptr: POINTER TO Record;
    local3 : CARDINAL;
    ptr2: POINTER TO Record;  

  PROCEDURE proc35(param1: CARDINAL): BOOLEAN;
  VAR
    i: CARDINAL;
    j: CARDINAL;
  BEGIN
    j := 1;
    i := 0;
    REPEAT
      IF j = param1 THEN ptr := ADDRESS(i); RETURN TRUE END;
      j := j * 2;
      INC(i);
    UNTIL i > 14;
    RETURN FALSE  
  END proc35;

  PROCEDURE proc36(): CARDINAL;
  BEGIN
    (* commented contents ? *)
  END proc36;

BEGIN
  IF global5 THEN
    IF global12 <> 0 THEN
      ptr2 := ADR(global11[global12 - 1]);
      IF ptr2^.word0 = 1 THEN
        IF (param2 IN {6,7}) AND (param1 <= 1) THEN
          IF param2 = 7 THEN ptr2^.word1 := -INTEGER(ptr2^.word1) END;
          IF global12 > 1 THEN
            IF global11[global12 - 2].word0 IN {1,4} THEN
              INC(global11[global12 - 2].word1, ptr2^.word1);
              DEC(global12); 
            END; (* 04A9 *)
          END; (* 04A9 *)
          ptr2^.word0 := 4;
          RETURN;
        ELSE (* 04AF *)
          IF (param2 IN {8,9}) AND (param1 = 0) AND proc35(ptr2^.word1) THEN
            DEC(global12);
            proc32;
            IF ptr <> NIL THEN Emit2(param2 + OPMUL, ptr) END; (* 04CE *)
            RETURN
          ELSE (* 04D1 *)
            IF (param2 = 10) AND (param1 <= 1) AND proc35(ptr2^.word1) THEN
              DEC(ptr2^.word1);
              proc32;
              Emit1(OPBITAND);
              RETURN
            ELSE (* 04EE *)
              IF (NOT Compiler.global2) AND (ptr2^.word1 = 0) 
              AND (param2 IN {0,1,3}) AND (param1 <= ORD(param2 <> 3)) THEN
                DEC(global12);
                proc32;
                Emit1(OPEQ0 + ORD(param2 <> 0) * 32);
                RETURN
              END; (* 0512 *)
            END; (* 0512 *)
          END;
        END;
      END; (* 0512 *)
    END; (* 0512 *)
    proc32;
    IF (param1 = 5) OR (param2 = 18) THEN
      local3 := Scanner.proc27("DOUBLES", 9567H) * 16;
    END; (* 0532 *)
    CASE param1 OF
    | 0: (* 0536 *)
        IF param2 >= 15 THEN
          IF Compiler.global2 THEN Emit1(125) ELSE Emit2(144,33) END;
          param1 := 2;
        END; (* 054b *)
    | 1: (* 054c *)
        IF param2 >= 15 THEN
          Emit1(189);
          param1 := 2;
        ELSE
          IF param2 IN {0,1,6,7,10} THEN param1 := 0
          ELSIF param2 = 11 THEN Emit2(OPCOMPL, OPINC); RETURN
          END; (* 056E *)
        END; (* 056E *)
    | 2: (* 056f *)
        IF param2 <= 5 THEN Emit1(OPDCOMP); proc17(23); param1 := 0
        ELSIF param2 = 11 THEN
          Emit2(OPEXTENDED,3); RETURN
        END; (* 0589 *)
    | 3: (* 058a *)
        IF param2 <= 5 THEN
          Emit1(OPREALCMP); proc17(23); param1 := 0
        ELSIF param2 IN {11,12} THEN
          IF Compiler.global2 THEN Emit1(param2 + OPSSW0)
          ELSE
            Emit1(OPSWAP);
            IF param2 = 11 THEN
              Emit2(OPLI15, OPPOWER2); Emit1(OPBITXOR);
            ELSE (* 05BD *)
              Emit1(OPLIW); EmitWord(7FFFH); Emit1(OPBITAND); 
            END; (* 05c7 *)
            Emit1(OPSWAP);
          END; (* 05ca *)
          RETURN
        ELSIF param2 IN {13,14,15} THEN
          Emit1(OPFLOAT2LG);
          param1 := 2;
        END; (* 05d9 *)
    | 4: (* 05da *)
        IF param2 <= 5 THEN
          IF param2 = 5 THEN
            Emit1(OPSWAP);
            param2 := 4;
          END; (* 05E9 *)
          IF param2 = 4 THEN Emit2(OPCOMPL, OPBITAND); Emit1(OPLI0); param2 := 0 END; (* 05F8 *)
          param1 := 0
        ELSIF param2 = 7 THEN
          Emit1(OPCOMPL); param2 := 8
        END; (* 0606 *)
    | 5: (* 0607 *)
        IF param2 <> 18 THEN
          Emit1(OPEXTCALL1);
          IF param2 <= 5 THEN Emit1(local3+5); param1 := 0
          ELSIF param2 >= 13 THEN
            param1 := ORD(param2 = 16) + 2;
            Emit1(local3 + param1 - 1);
          ELSE Emit1(local3 + param2)
          END; (* 0634*)
          IF Compiler.global2 THEN
            Emit2(ORD(param2 <= 9)+1, (ORD(param2 IN {6,7,8,9,10,11,12})+1)*4);
            IF param2 <= 5 THEN proc17(23) END;
          END; (* 064E *)
          IF param1 = 5 THEN RETURN END;
        END; (* 0654 *)
(* $T+ generate CaseSelectError exception *)
    END; (* 066c *)
(* $T- *)
    IF param2 <= 12 THEN
      Emit1(param2 + param1 * 16 + 160);
    ELSIF param2 - 13 <> param1 THEN
      IF param2 <= 14 THEN
        IF param1 <= 1 THEN Emit1(221) ELSE Emit1(param2 + 173) END;
      ELSIF param2 <= 16 THEN Emit1(param1 + 188)
      ELSE (* 06A3 *) 
        Emit2(OPEXTCALL1, local3 + param1 + 1);
        IF Compiler.global2 THEN Emit2(OPRAISE, 8) END;
      END; (* 06B1 *)
    END; (* 06B1 *)
  END; (* 06b1 *)
END proc6;

PROCEDURE proc7(param2, param1: CARDINAL);
BEGIN 
  IF global5 THEN proc32; Emit1(param1 * 16 + param2 + 186) END;
END proc7;


PROCEDURE proc10(param1: CARDINAL);
VAR ptr: RecordPtr;
BEGIN 
  IF global5 THEN
    IF (param1 = 0) AND (global12 <> 0) THEN
      ptr := ADR(global11[global12-1]);
      IF (ptr^.word0 = 1) AND (ptr^.word1 = 0) THEN
        DEC(global12);
        proc32;
        Emit1(OPLIMIT);
        RETURN
      END; (* 06EC *)
    END; (* 06EC *)
    proc32;
    IF param1 >= 23 THEN
      Emit1(OPEXTENDED);
    END; (* 06F7 *)
(* $T+ *)
    Emit1( Compiler.global5[param1][0] );
(* $T- *)
  END; (* 0701 *)
END proc10;

PROCEDURE proc11(param2, param1: CARDINAL);
BEGIN 
  IF global5 THEN
    proc32;
    IF param2 = 5 THEN
      IF param1 >= 10 THEN
        Emit2(OPEXTENDED, param1 - 5)
      ELSIF param1 = 6 THEN
        IF Compiler.global2 THEN Emit1(102)
        ELSE
            (* generates the bad CAP sequence *)
          Emit2(OPDUP, OPLIB); Emit2(040H, OPBITAND);
          Emit2(OPSHR, 1);  Emit2(OPCOMPL, OPBITAND);
        END; (* 073D *)
      ELSE (* 073F *)
(* $T+ *)
        Emit1(Compiler.global5[param1+27][0]);
(* $T- *)
      END; (* 074B *)
    ELSE (* 074D *)
      IF param2 = 4 THEN
        Emit2(OPLONGREAL, 10);
        Emit1(param1);
      ELSIF (param2 = 0) AND (param1 - 128 <= 3) AND (NOT Compiler.global2) THEN
        Emit1(param1 + 8)
      ELSE
        Emit2(param2 + 132, param1)
      END; (* 0775 *)
    END; (* 0775 *)
  END; (* 0775 *)
END proc11;

PROCEDURE proc17(param1: CARDINAL);
BEGIN 
  IF global5 THEN
    proc32;
    IF Compiler.global2 AND (param1 <> 20) THEN Emit2(0,param1) END;
  END;
END proc17;

PROCEDURE proc18(param3, param2, param1: CARDINAL); 
BEGIN 
  IF global5 THEN
    proc32;
    IF Compiler.global2 THEN
      IF param3 <> 19 THEN Emit2(0, param3) END;
      Emit1(param2);
      IF param3 >= 3 THEN Emit1(param1) END;
    END; (* 07aa *)
  END;
END proc18;

PROCEDURE proc12(VAR param2: CARDINAL; param1: BOOLEAN);
VAR local2: CARDINAL;
BEGIN 
  IF global5 THEN
    param2 := global2;
    IF param1 THEN
      local2 := proc19(global2 - 1);
      IF local2 - 224 <= 1 THEN
        proc20(local2 + 2, global2 - 1);
      END;
      Emit1(0)
    ELSE EmitWord(0)
    END;
  END;
END proc12;

PROCEDURE proc13(param2: CARDINAL; param1: BOOLEAN); 
BEGIN 
  IF global5 THEN
    IF param1 AND (global2 < param2 + 254) THEN
      proc20(proc19(global2 - 1) + 4, global2 - 1);
      Emit1(global2 + 1 - param2);
    ELSE
      EmitWord(param2 - (global2 + 1))
    END;
  END;
END proc13;


PROCEDURE proc14(param2: CARDINAL; param1: BOOLEAN): BOOLEAN;
VAR 
    local2: BYTE;
    local3: BYTE;
    local4: CARDINAL;
    local5: ADDRESS;
BEGIN 
  IF global5 THEN
    proc32;
    local4 := param2 + 1;
    IF param1 THEN
      IF global2 > local4 + 254 THEN
        IF local4 < global3 THEN
          Files.SetPos(Scanner.global4, LONG(local4));
          Files.ReadByte(Scanner.global4, local2);
          INC(local4);
          WHILE local4 < global3 DO
            local3 := local2;
            Files.ReadByte(Scanner.global4, local2);
            Files.SetPos(Scanner.global4, LONG(local4));
            Files.WriteByte(Scanner.global4, local3);
            INC(local4)
          END; (* 0842 *)
          MOVE(global6, ADDRESS(global6) + 1, global2 - global3);
          global6^[0] := local2;
        ELSE (* 0850 *)
          local5 := ADDRESS(global6) + local4 - global3;
          MOVE(local5, local5 + 1, global2 - local4);
        END; (* 085e *)
        INC(global2);
        proc20( proc19(param2 - 1) - 2, param2 - 1);
        proc20( (global2 - local4) MOD 256, param2);
        proc20( (global2 - local4) DIV 256, local4);
        RETURN FALSE
      END; (* 087f *)
      proc20(global2 - local4, param2);
    ELSE (* 0887 *)
      proc20( (global2 - local4) MOD 256, param2);
      proc20( (global2 - local4) DIV 256, local4);
    END; (* 0898 *)
  END; (* 0898 *)
  RETURN TRUE
END proc14;


PROCEDURE proc15(param1: CARDINAL);
VAR local2: CARDINAL;
BEGIN 
  IF global5 THEN
    IF proc19(param1 - 1) <= 225 THEN
      local2 := proc19(param1) + proc19(param1 + 1) * 256;
      IF INTEGER(local2) > 0 THEN INC(local2) ELSE DEC(local2) END;
      proc20( local2 MOD 256, param1);
      proc20( local2 DIV 256, param1 + 1);
    ELSE (* 08D2 *)
      proc20( proc19(param1) + 1, param1);
    END; (* 08D9 *)
  END; (* 08D9 *)
END proc15;


PROCEDURE proc16(param1: CARDINAL): CARDINAL;
BEGIN 
  proc17(param1);
  RETURN global2
END proc16;

PROCEDURE proc22;
BEGIN 
  global5  := TRUE;
  global14 := FALSE;
  global12 := 0;
  proc28;
END proc22;


PROCEDURE proc24;
BEGIN 
  global15 := (execute = 4);
  global6  := ADDRESS(Scanner.global21);
  global3  := 0;
  global4  := 4096;
  global2  := 16;
  proc22;
END proc24;

END CodeGen.

