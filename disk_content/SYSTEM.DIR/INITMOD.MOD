IMPLEMENTATION MODULE InitMod;
FROM SYSTEM   IMPORT WORD, ADR, NEWPROCESS, TRANSFER;
IMPORT Terminal;

TYPE Context = RECORD
                w0, w1, w2, w3 : WORD;
                StackLimit : ADDRESS;
                (* other context words omitted *)
               END;
     ContextPtr = POINTER TO Context;

VAR callerTask [0308H]: ContextPtr;
    calledTask [030AH]: ContextPtr;
    module1    [030CH]: ADDRESS;

(* initializes the modules that requires it.
   The called module will be the last one initialized, thus run...
*)
PROCEDURE InitModules(upToModule: ModDescPtr; wsp: ADDRESS);
VAR modulePtr: ModDescPtr;
    proc : RECORD
             CASE : CARDINAL OF
             | 1: proc : PROC;
             | 2: module,procAddr: CARDINAL;
             END
           END;
BEGIN
  modulePtr := module1;
  WHILE modulePtr <> upToModule DO
    IF TOINIT IN modulePtr^.flags THEN
      proc.module   := ADDRESS(modulePtr) + 80;
      proc.procAddr := 0; (* procnum of INIT is 0 *)
      (* create a process, giving it all memory from current alloc addr *)
      NEWPROCESS(proc.proc, wsp, ADR(proc)-80-ADDRESS(wsp), calledTask);
      TRANSFER(callerTask, calledTask);
      (* once the init is finished (opcode 50), get the new heap ptr by peeking it
         directly in the context of the finished process *)
      wsp := calledTask^.StackLimit - 60;
    END;
    modulePtr := modulePtr^.link;
  END;
END InitModules;

END InitMod.                                                       