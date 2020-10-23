IMPLEMENTATION MODULE ShellRes;
IMPORT Texts, Loader, ComLine;
FROM Terminal IMPORT WriteString, WriteLn;
IMPORT KERNEL2, EditPos, Editor, Scanner;

VAR index : CARDINAL;
    buffer [0081H]: ARRAY [0..126] OF CHAR;

(*
PROCEDURE CallShell();
BEGIN
  Loader.Call("SHELL");
EXCEPTION
| Loader.LoadError :
    WriteLn;
    WriteString("SHELL.MCD not found, system halted.");
    HALT
END CallShell;
*)

PROCEDURE RunModule;
BEGIN
  Loader.Call(ComLine.progName)
EXCEPTION
| Loader.LoadError :
  WriteString(ComLine.progName);
  WriteString(" not found.");
  WriteLn;
END RunModule;

PROCEDURE textDriver(text: Texts.TEXT; VAR ch: CHAR);
CONST EOF = 032C;
BEGIN
  IF (ORD(buffer[index]) - ORD('<')) IN {0,2} THEN
    REPEAT INC(index) UNTIL buffer[index]<=' '
  END;
  ch := buffer[index];
  IF ch = 0C THEN ch := EOF ELSE INC(index) END;
END textDriver;

BEGIN
  LOOP
    (* Re-initialize the Texts module *)
    Texts.Init; Texts.haltOnControlC := FALSE;

    (* Load the big transient part of Shell *)
    Loader.Call("SHELL");

    (* once it has returned, we have more memory for the program to run *)
    index := 0;
    Texts.ConnectDriver(ComLine.commandLine, textDriver);
    Texts.haltOnControlC := TRUE;
    RunModule;
  END;
END ShellRes.