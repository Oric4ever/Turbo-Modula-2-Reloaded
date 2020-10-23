IMPLEMENTATION MODULE KERNEL3;
FROM SYSTEM   IMPORT WORD, PROCESS, TRANSFER, NEWPROCESS, ADR, MOVE, BYTE,
                     ADDRESS, FILL, TSIZE;
FROM STORAGE  IMPORT ALLOCATE, MARK;
FROM Terminal IMPORT WriteChar, WriteString, WriteLn;
FROM Loader   IMPORT Call;
IMPORT InitMod;
IMPORT EXCEPTS;

PROCEDURE WriteCard(val: CARDINAL);
BEGIN
  IF val >= 10 THEN WriteCard(val DIV 10) END;
  WriteChar( CHR(val MOD 10 + ORD('0')) );
END WriteCard;

PROCEDURE WriteInt(i: CARDINAL; signed: BOOLEAN);
BEGIN
  IF signed AND (INTEGER(i) < 0)
  THEN WriteChar('-'); WriteCard(-INTEGER(i))
  ELSE WriteCard(i)
  END;
END WriteInt;

PROCEDURE WriteMod38(code: CARDINAL);
VAR i, mod38: CARDINAL;
BEGIN
  i := 1;
  REPEAT
    mod38 := code MOD 38;
    code  := code DIV 38;
    IF    mod38 < 26 THEN WriteChar( CHR(mod38 + ORD('A')) )
    ELSIF mod38 < 36 THEN WriteChar( CHR(mod38 + (ORD('0') - 26)))
    ELSE                  WriteChar(' ')
    END;
    INC(i)
  UNTIL i > 3
END WriteMod38;

PROCEDURE WriteModuleName(modbase: ADDRESS);
VAR name: POINTER TO ARRAY [0..7] OF CHAR;
    i : CARDINAL;
BEGIN
  i := 0;
  name := ADDRESS( CARDINAL(modbase - 78) + 32*2 ); (* TODO: not exactly the same*)
  REPEAT
    IF name^[i] = 0C THEN WriteChar(' ') ELSE WriteChar(name^[i]) END;
    INC(i)
  UNTIL i = 8
END WriteModuleName;

PROCEDURE Halt;
BEGIN
  WriteLn;
  WriteString('Halted.');
  LOOP END;
END Halt;

TYPE
     Context    = RECORD
                    HL,HL2 : CARDINAL;
                    GLOBAL : ADDRESS;
                    IntFlag: BOOLEAN;
                    StackLimit, FreeList: ADDRESS;
                    save1, save2: CARDINAL;
                    IY : CARDINAL;
                    LOCAL : ADDRESS;
                    DE2,BC2 : CARDINAL;
                    IP : CARDINAL;
                    BC, AF2, AF: CARDINAL;
                    ReturnAddr : CARDINAL;
                    MsgHigh : CARDINAL;
                    MsgStr : ADDRESS;
                    ExcNum : CARDINAL;
                    Param  : CARDINAL;
                  END;
     ContextPtr = POINTER TO Context;
     ContextSave= ARRAY [0..16] OF WORD;
     ContextSavePtr = POINTER TO ContextSave;
     FCB        = ARRAY [0..35] OF BYTE;
     FramePtr   = POINTER TO Frame;
     Frame      = RECORD
                    outerFrame   : FramePtr;
                    previousFrame: FramePtr;
                    returnAddr   : ADDRESS;
                  END;
     FLAGS      = (OVERLAY, Z80, INIT);
     ModulePtr  = POINTER TO Module;
     Module     = RECORD
                    flags  : SET OF FLAGS;
                    global1: CARDINAL;
                  END;
     ModDescPtr  = POINTER TO ModuleDesc;
     ModuleDesc = RECORD
                    procs: ARRAY [0..31] OF ADDRESS;
                    link : ModDescPtr;
                    name : ARRAY [0..7] OF CHAR;
                    loadAddr,checksum,endAddr: ADDRESS;
                    CASE : BOOLEAN OF
                    | TRUE : flags : SET OF FLAGS;
                    | FALSE: bytes : ARRAY [0..1] OF BYTE;
                    END;
                    global1 : CARDINAL;
                  END;
     ProcDesc = RECORD
                  CASE : BOOLEAN OF
                  | TRUE : modbase, procnum: ADDRESS;
                  | FALSE: proc : PROC;
                  END
                END;

VAR
(*  2 *)    copyrightFlag : BOOLEAN;
(*  3 *)    errorMsg : ARRAY [0..59] OF CHAR;
(*  4 *)    msgSize : CARDINAL;
(*  5 *)    exceptNum : CARDINAL;
(*  6 *)    exceptMod : ModulePtr;
(*  7 *)    dbgGlobal : ModulePtr;
(*  8 *)    dbgLocal : FramePtr;
(*  9 *)    returnAddr : CARDINAL;
(* 10 *)    interruptedTask: ContextPtr;
(* 11 *)    debugTask: PROCESS;
(* 12 *)    firstModuleSave: PROCESS;
(* 13 *)    contextSave: ContextSave;
(* 14 *)    lastContextPtr: ContextSavePtr;
(* 15 *)    overlayNotLoaded: BOOLEAN;
(* 16 *)    toLoadFlag: BOOLEAN;
(* 17 *)    ErrorWorkspace: ARRAY [0..199] OF BYTE;
(* 18 *)    DebugWorkspace: ARRAY [0..399] OF BYTE;
(* 19 *)    nbFrames: CARDINAL;
(* 20 *)    versionError: BOOLEAN;
(* 21 *)    loadRetryCount: CARDINAL;
(* 22 *)    FCBs: POINTER TO ARRAY [0..3] OF FCB;
(* 23 *)    nbExtentsM2OVR: CARDINAL;
(* 24 *)    currentDrive: CARDINAL;
(* 25 *)    drive: CARDINAL;
(* 26 *)    allocAddr: ADDRESS;
(* 27 *)    allocAddr2: ADDRESS;
(* 28 *)    modulePtr: ModDescPtr;
(* 29 *)    varCount: CARDINAL;
(* 30 *)    varSize: CARDINAL;
(* 31 *)    globalVarsPtr: POINTER TO ARRAY [0..255] OF CARDINAL;
(* 32 *)    globalVarsAllocated: BOOLEAN;
(* 33 *)    proc: ProcDesc;
(* 34 *)    contextPtr: ContextPtr;

(* remove internal module, let the interrupt handlers serve interrupts during exceptions
MODULE Internal[1]; (* procedures with priority 1 *)
IMPORT ADDRESS, WORD, PROCESS, TRANSFER, NEWPROCESS, BDOS, TSIZE, BYTE, MOVE,
       ADR, ALLOCATE,
       WriteChar, WriteString, WriteLn, WriteInt, WriteCard,
       WriteModuleName, WriteMod38, Halt,
       FCB, FCBs, nbExtentsM2OVR, currentDrive, drive, toLoadFlag,
       dbgGlobal, interruptedTask, debugTask, firstModuleSave, loadRetryCount,
       contextSave, lastContextPtr, ContextSavePtr, overlayNotLoaded, versionError,
       FLAGS, DebugWorkspace, msgSize, exceptNum, exceptMod, errorMsg,
       dbgLocal, nbFrames, returnAddr, ContextPtr, FramePtr, ModDescPtr, ModulePtr,
       copyrightFlag, InitSystem;
EXPORT
       DebugProc,
       LoadProc,
       ErrorProc,
       ErrorTask, InterruptedTask, KernelTask0, KernelTask1;
*)

VAR
    ErrorTask      [0304H]: PROCESS;
    InterruptedTask[0306H]: PROCESS;
    KernelTask0    [0308H]: PROCESS;
    KernelTask1    [030AH]: PROCESS;
    firstModule    [030CH]: PROCESS;
    VMfetchAddr   [0FF0CH]: CARDINAL;

    ExceptionsModule[0320H]: ADDRESS;
    M2OVRFCB   [0324H]: FCB;
    M2OVRname  [0325H]: ARRAY [0..7] OF CHAR;
    M2OVRext   [032DH]: ARRAY [0..2] OF CHAR;
    RandomAccessRecordNumber [0345H]: CARDINAL;
    drives     [034AH]: BITSET; (* drives that are present *)

  PROCEDURE GetDependency(n: CARDINAL): ADDRESS;
  VAR dependency: POINTER TO ADDRESS;
  BEGIN
    IF n = 0 THEN RETURN ExceptionsModule END;
    IF n = 1 THEN RETURN dbgGlobal END;
    dependency := ADDRESS(dbgGlobal) - (n-2)*2 - 18;
    RETURN dependency^
  END GetDependency;

  PROCEDURE DebugProc;
    CONST SPACES5 = "     ";
    CONST TAB = 11C;
    TYPE ProcDesc = RECORD
                      name0, name1: CARDINAL;
                      excHandler: INTEGER;
                    END;
    VAR taskContext: ContextPtr;
        ptr    : POINTER TO CARDINAL;
        procPtr: POINTER TO ProcDesc;
        saveProcPtr : ADDRESS;
        codePtr: POINTER TO ARRAY [0..19] OF CHAR;
        n      : CARDINAL;
        signed : BOOLEAN;
        propagateException: BOOLEAN;
        answer : CHAR;

    PROCEDURE proc10(): BOOLEAN;
    VAR outerFrame   : ADDRESS;
        previousFrame: FramePtr;
        modulePtr    : ModDescPtr;
        ptr          : POINTER TO CARDINAL;
    BEGIN
      IF dbgLocal <> NIL THEN
        outerFrame    := dbgLocal^.outerFrame;
        previousFrame := dbgLocal^.previousFrame;
        IF (outerFrame <> ADDRESS(1)) AND (nbFrames < 5000) THEN
          INC(nbFrames);
          IF outerFrame <> NIL THEN
            IF  (outerFrame <> previousFrame)
            AND (previousFrame    <> NIL)
            AND (outerFrame <> previousFrame^.outerFrame)
            AND ( (previousFrame^.previousFrame = NIL)
               OR (outerFrame <> previousFrame^.previousFrame^.outerFrame) )
            THEN
              modulePtr := firstModule;
              WHILE (modulePtr <> NIL)
              AND   (ADDRESS(modulePtr)+80 <> outerFrame) DO
                modulePtr := modulePtr^.link
              END;
              IF modulePtr <> NIL THEN dbgGlobal := outerFrame END;
            END
          END;
          taskContext:= ADDRESS(dbgLocal) - 28;
          returnAddr := dbgLocal^.returnAddr;
          dbgLocal   := previousFrame;
          IF dbgGlobal <> NIL THEN
            ptr     := ADDRESS(dbgLocal) - 2;
            procPtr := ADDRESS(ptr^ - 2 * 4);
            RETURN TRUE;
          END
        END
      END;
      RETURN FALSE
    END proc10;

  BEGIN
    interruptedTask    := InterruptedTask;
    taskContext        := interruptedTask;
    dbgLocal           := interruptedTask^.LOCAL;
    dbgGlobal          := interruptedTask^.GLOBAL;
    returnAddr         := interruptedTask^.IP;
    ptr                := ADDRESS(dbgLocal) - 2;
    procPtr            := ADDRESS(ptr^ - 2 * 4);
    propagateException := TRUE;
    n                  := interruptedTask^.ExcNum;
    IF n <> 0 THEN
      exceptNum := n MOD 256;
      exceptMod := GetDependency(n DIV 256);
      propagateException   := n <> 10; (* EndOfCoroutine *)
      IF n = 6 THEN (* OutOfMemory *)
        propagateException := proc10();
        exceptNum := 5 (* OutOfMemory *)
      END;
      msgSize := interruptedTask^.MsgHigh + ORD(interruptedTask^.MsgStr <> NIL);
      IF msgSize > 60 THEN msgSize := 60 END;
      MOVE(interruptedTask^.MsgStr, ADR(errorMsg), msgSize);
    END;
    interruptedTask^.GLOBAL := dbgGlobal;
    interruptedTask^.LOCAL  := dbgLocal;
    interruptedTask^.IP     := returnAddr;
    saveProcPtr             := procPtr;
    IF propagateException THEN
      nbFrames := 0;
      REPEAT
        IF procPtr^.excHandler > 0 (* ie. exception handler is present *)
        THEN
          codePtr := ADDRESS( INTEGER(procPtr) + procPtr^.excHandler + 5 );
          n       := ORD(codePtr^[0]); (* number of exception handlers *)
          ptr     := ADDRESS(codePtr) + n * 4 - 1;  (* 4 bytes per exception handler *)
          IF CARDINAL(ptr) + ptr^ + 1 >= returnAddr THEN
            codePtr := ADDRESS(codePtr) + 1;
            (* search the correct exception handler *)
            WHILE n <> 0 DO
              IF (ORD(codePtr^[0]) = 0)     (* "All-exceptions" catch *)
              OR (ORD(codePtr^[0]) = exceptNum)   (* or correct exception number *)
              AND (GetDependency(ORD(codePtr^[1])) = exceptMod) (*and correct module*)
              THEN
                MOVE(interruptedTask, taskContext, 17*2);   (* copy context, then modify it *)
                taskContext^.GLOBAL     := dbgGlobal;
(* TODO: Set Interrupt Enable flag instead *)
                taskContext^.IntFlag    := FALSE;
                taskContext^.LOCAL      := dbgLocal;
                ptr                     := ADDRESS(codePtr) + 2; (* point to handler relative addr*)
                taskContext^.IP         := CARDINAL(ptr) + ptr^ + 1; (* calculate absolute addr *)
                taskContext^.ReturnAddr := VMfetchAddr;
                InterruptedTask         := taskContext;
                TRANSFER(debugTask, InterruptedTask);
              END;
              codePtr := ADDRESS(codePtr) + 4; (* else point to next except handler *)
              DEC(n);
            END; (* WHILE *)
          END;
        END;
      UNTIL NOT proc10();
    END; (* IF propagateException *)
    WriteLn;
    IF (exceptMod <> ExceptionsModule) AND (OVERLAY IN exceptMod^.flags) THEN
      WriteChar('?')
    ELSE
      ptr := ADDRESS(exceptMod) - 2;
      ptr := ADDRESS(ptr^) - exceptNum * 2;
      codePtr := ADDRESS(ptr) + ptr^ + 1;
      n := 1;
      WHILE n <= ORD(codePtr^[0]) DO
        WriteChar(codePtr^[n]);
        INC(n)
      END;
    END;
    WriteString(" in module ");
    WriteModuleName(interruptedTask^.GLOBAL);
    WriteLn;
    IF exceptMod = ExceptionsModule THEN
      IF exceptNum = 1 THEN
        WriteString("Missing module: ");
        WriteModuleName(interruptedTask^.HL);
      END;
      IF exceptNum IN {2,3,4} THEN (* BoundsError *)
        signed := exceptNum = 3;
        IF exceptNum = 4 THEN
          interruptedTask^.BC := 0;
          interruptedTask^.HL := 07FFFH;
        END;
        WriteInt(interruptedTask^.BC, signed);
        WriteString(" to ");
        WriteInt(interruptedTask^.HL, signed);
        WriteString(" is legal range, but ");
        WriteInt(interruptedTask^.Param, signed);
        IF exceptNum = 4 THEN
          WriteString(" or ");
          WriteInt(interruptedTask^.Param, TRUE);
        END;
        WriteString(" was evaluated");
      END;
      IF exceptNum = 5 THEN (* OutOfMemory *)
        WriteString("Stack=");  WriteCard(CARDINAL(interruptedTask));
        WriteString(", heap="); WriteCard(interruptedTask^.StackLimit);
      END;
    ELSE (* exceptMod <> ExceptionsModule *)
      n := 0;
      WHILE n < msgSize DO
        WriteChar(errorMsg[n]);
        INC(n)
      END;
    END;
    IF propagateException THEN
      dbgGlobal := interruptedTask^.GLOBAL;
      dbgLocal  := interruptedTask^.LOCAL;
      returnAddr:= interruptedTask^.IP;
      procPtr   := saveProcPtr;
      n := 0;
      WriteLn;
      WriteString("Module   Proc   Offset  PC");
      WriteLn;
      LOOP
        IF n = 25 THEN EXIT END; (* limit to the last 25 calls *)
        IF (OVERLAY IN dbgGlobal^.flags)
        OR (procPtr^.excHandler >= 0)   (* ie. procedure name is present *)
        THEN
          WriteModuleName(dbgGlobal); WriteChar(' ');
          IF OVERLAY IN dbgGlobal^.flags
          THEN WriteChar('?')
          ELSE
            WriteMod38(procPtr^.name0);
            WriteMod38(procPtr^.name1);
            WriteChar(TAB);
            WriteInt(INTEGER(returnAddr) - INTEGER(procPtr) - 6, TRUE);
            WriteChar(TAB);
            ptr := ADDRESS(dbgGlobal) - 6;
            WriteCard(returnAddr - ptr^ + 16);
          END;
          WriteLn;
        END;
        INC(n);
        IF NOT proc10() THEN EXIT END;
      END; (* LOOP *)
    END;
    WriteLn;
    lastContextPtr^ := contextSave;
    firstModule  := firstModuleSave;
    InterruptedTask := lastContextPtr;
    TRANSFER(debugTask, InterruptedTask);
  END DebugProc;

  PROCEDURE ErrorProc;
  BEGIN
    lastContextPtr  := ContextSavePtr(InterruptedTask);
    contextSave := lastContextPtr^;
    firstModuleSave := firstModule;
    TRANSFER(ErrorTask, InterruptedTask);
    LOOP
      IF InterruptedTask = debugTask THEN Halt END;
      NEWPROCESS(DebugProc, ADR(DebugWorkspace), SIZE(DebugWorkspace), debugTask);
      TRANSFER(ErrorTask, debugTask);
    END
  END ErrorProc;

BEGIN
 (*  InitSystem; (* be sure to initialize before using BDOS opcode *) *)

  (* required here: places a heap marker that will be checked on return of TRANSFER *)
  MARK(allocAddr);
  (* create a process for all error handling *)
  NEWPROCESS(ErrorProc, ADR(ErrorWorkspace), SIZE(ErrorWorkspace), ErrorTask);
  TRANSFER(InterruptedTask, ErrorTask); (* ErrorTask initializes and transfers control back *)

  allocAddr2 := allocAddr + 4;(* get the current allocation address *)
  InitMod.InitModules(NIL, allocAddr2);
  
(*
  (* init the modules that requires it. *)
  modulePtr  := firstModule;
  WHILE modulePtr <> NIL DO
    IF INIT IN modulePtr^.flags THEN (* init module with a new process *)
      toLoadFlag   := OVERLAY IN modulePtr^.flags;
      proc.modbase := ADR(modulePtr^.flags); (* procnum is 0 *)
      (* create a process, giving it all memory from current alloc addr *)
      NEWPROCESS(proc.proc, allocAddr2, ADDRESS(lastContextPtr)-10-allocAddr2, KernelTask1);
      TRANSFER(KernelTask0, KernelTask1);
      (* once a module's INIT ends (opcode 50), get the new heap ptr by looking
         directly in the context of the finished process *)
      contextPtr := ADDRESS(KernelTask1);
      allocAddr2 := contextPtr^.StackLimit - 60;
    END;
    modulePtr := modulePtr^.link;
  END; (* normally, the main module's INIT is an endless loop (eg. SHELLRES) *)
*)
  Halt;
END KERNEL3.