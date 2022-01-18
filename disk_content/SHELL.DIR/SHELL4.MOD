MODULE SHELL;
IMPORT FATDIR, Texts, Files, Terminal, ComLine, Loader;
FROM Files IMPORT FILE;
FROM ComLine IMPORT commandBuffer, cmdlineLength;
FROM SYSTEM IMPORT MOVE, ADR, ADDRESS, WORD, BYTE, BDOS, IORESULT, HLRESULT;
FROM STORAGE IMPORT FREEMEM, ALLOCATE, MARK, RELEASE;

CONST CTRLC = 03C; BackSpace = 10C; TAB = 11C; LF = 12C; CR = 15C;
      XOFF = 23C; CTRLX = 30C; EOT = 32C; ESC = 033C; DEL = 177C;

CONST USERNUM = 32; DMAOFFSET = 26; SEARCHFIRST = 17; SEARCHNEXT = 18;

TYPE FileName = ARRAY [0..19] OF CHAR;
TYPE FullName = ARRAY [0..16] OF CHAR;
     Name =  RECORD
               CASE : BOOLEAN OF
               | FALSE: fullname: FullName;
               | TRUE : driveUser: ARRAY [0..3] OF CHAR;
                        filename : ARRAY [0..11] OF CHAR;
                        word8 : CARDINAL;
                        flag : BOOLEAN;
               END;
            END;
     NamePtr = POINTER TO Name;

VAR
(*  2 *) global2 : Texts.TEXT;
(*  3 *) global3 : CARDINAL;
(*  4 *) global4 : CARDINAL;
(*  5 *) exit    : BOOLEAN;
(*  6 *) global6 : BOOLEAN;
(*  7 *) global7 : BOOLEAN;
(*  8 *) index   : CARDINAL;
(*  9 *) global9 : CARDINAL;
(* 10 *) global10: CARDINAL;
(* 11 *) global11: ARRAY [1..256] OF Name; (* 5120 bytes *)
(* 12 *) global12: CARDINAL;
(* 13 *) global13: CARDINAL;
(* 14 *) global14: ARRAY [1..256] OF NamePtr; (* 512 bytes *)
(* 15 *) global15: BOOLEAN;
(* 16 *) global16: CARDINAL;
(* 17 *) global17: FileName;
(* 18 *) command: CARDINAL;
(* 19 *) showMenu: BOOLEAN;

(* $[+ suppress procedure names *)

(* proc 13 *)
PROCEDURE ReadCmdLine(VAR buffer: ARRAY OF CHAR; message: ARRAY OF CHAR);
VAR i : CARDINAL;
    char: CHAR;
BEGIN
  Terminal.WriteString(message);
  buffer := message;
  i  := 0; WHILE (i <= HIGH(message)) AND (message[i] <> 0C) DO INC(i) END;
  REPEAT
    Terminal.ReadChar(char);
    IF char = TAB THEN char := ' ' END;
    IF (char >= ' ') AND (char < DEL) THEN
      IF i < HIGH(buffer) THEN
        buffer[i] := CAP(char);
        Terminal.WriteChar(char);
        INC(i);
      END;
    ELSIF (char = BackSpace) OR (char = DEL) THEN
      IF i <> 0 THEN
        buffer[i] := 0C;
        Terminal.WriteChar(BackSpace);
        Terminal.WriteChar(' ');
        Terminal.WriteChar(BackSpace);
        DEC(i);
      END;
    ELSIF (char = CTRLX) OR (char = ESC) THEN
      WHILE i <> 0 DO
        buffer[i] := 0C;
        Terminal.WriteChar(BackSpace);
        Terminal.WriteChar(' ');
        Terminal.WriteChar(BackSpace);
        DEC(i);
      END;
      IF char = ESC THEN Terminal.ReadAgain END;
    END;
  UNTIL (char = CR) OR (char = ESC) OR (i = HIGH(buffer));
  buffer[i] := 0C;
  Terminal.WriteLn;
END ReadCmdLine;

(* proc 14 *)
PROCEDURE CmdLineDriver(text: Texts.TEXT; VAR char: CHAR);
BEGIN
  IF ORD(commandBuffer[index]) - ORD('<') IN {0,2} THEN (* ie. '<' or '>' *)
    REPEAT INC(index) UNTIL commandBuffer[index] <= ' ';
  END;
  char := commandBuffer[index];
  IF char = 0C THEN char := EOT END;
  INC(index);
END CmdLineDriver;

PROCEDURE HandleRedirection; (* handle redirection *)
VAR ch: CHAR;
BEGIN
  index := 0;
  Texts.CloseText(global2);
  Texts.ConnectDriver(global2, CmdLineDriver);
  ComLine.inName[0]  := 0C;
  ComLine.outName[0] := 0C;
  REPEAT
    ch := commandBuffer[index];
    INC(index);
    IF ORD(ch) - ORD('<') IN {0,2} THEN
      IF commandBuffer[index] > ' ' THEN
        IF ch = '<'
        THEN Texts.ReadString(global2, ComLine.inName)
        ELSE Texts.ReadString(global2, ComLine.outName)
        END;
        Texts.ReadAgain(global2);
        Texts.ReadChar(global2, ch);
      END;
    END;
  UNTIL (ch = 0C) OR (ch = EOT);
  index := 0;
  global6 := TRUE;
END HandleRedirection;

PROCEDURE proc1(prompt: ARRAY OF CHAR; default: ARRAY OF CHAR);
VAR unused1, unused2: CARDINAL;
BEGIN
  IF (NOT global7) OR (commandBuffer[1] = 0C) THEN
    Terminal.WriteLn; Terminal.WriteString(prompt); Terminal.WriteChar(' ');
    ReadCmdLine(commandBuffer, default);
  END;
  HandleRedirection;
END proc1;

PROCEDURE proc16;
VAR local2: ARRAY [0..19] OF CHAR;
    i: CARDINAL;
BEGIN
  index := 0;
  Texts.ReadString(global2, local2);
  MOVE(ADR(commandBuffer[index]), ADR(commandBuffer[0]), HIGH(commandBuffer)-index);
  i := 0;
  WHILE (i < 126) AND (commandBuffer[i] <> 0C) DO INC(i) END;
  cmdlineLength := i;
END proc16;

PROCEDURE proc2(prompt: CHAR; commands : ARRAY OF CHAR): CARDINAL;
VAR i : CARDINAL;
    ch : CHAR;
BEGIN
  Terminal.WriteChar(prompt);
  Terminal.WriteChar(' ');
  ReadCmdLine(commandBuffer, "");
  Terminal.BusyRead(ch);
  IF ch = ESC THEN
    Terminal.ReadChar(ch);
    ch := CAP(ch);
    i := 0;
    REPEAT
      IF ch = commands[i] THEN RETURN i + 1 END;
      INC(i);
    UNTIL i > HIGH(commands);
  END;
  RETURN 0
END proc2;

(* proc 11 *)
PROCEDURE WriteCommandItem(string: ARRAY OF CHAR);
VAR i: CARDINAL;
BEGIN
  Terminal.Highlight;
  Terminal.WriteChar(string[0]);
  Terminal.Normal;
  i := 0; REPEAT INC(i); Terminal.WriteChar(string[i]) UNTIL i = HIGH(string);
END WriteCommandItem;

(* proc 12 *)
PROCEDURE EndScreen; 
BEGIN 
  Terminal.ClearScreen 
END EndScreen;

(* proc 18 *)
PROCEDURE proc18(param3: ARRAY OF CHAR; VAR param1: FileName): BOOLEAN;
VAR i: CARDINAL;
BEGIN 
  IF NOT Texts.EOT(global2) THEN
    Texts.ReadString(global2, param1);
    IF param1[0] <> 0C THEN RETURN TRUE END;
  END;
  Terminal.WriteString(param3);
  Texts.ReadString(Texts.input, param1);
  Texts.ReadLn(Texts.input);
  i := 0; REPEAT param1[i] := CAP(param1[i]); INC(i) UNTIL i > HIGH(param1);
  RETURN param1[0] <> 0C
END proc18;

PROCEDURE proc4(VAR codepos: CARDINAL): BOOLEAN;
VAR local2 : ARRAY [0..10] OF CHAR;
    i      : CARDINAL;
    local4 : CARDINAL;
    local5 : CARDINAL;
    local6 : BOOLEAN;
BEGIN
  IF NOT global6 AND (global9 < global10) THEN
    INC(global9);
    codepos := global9;
    RETURN TRUE
  END;
  IF Texts.EOT(global2) THEN RETURN FALSE END;
  Texts.ReadString(global2, local2);
  i      := 0;
  local5 := 0;
  local6 := FALSE;
  global6:= FALSE;
  REPEAT
    local4 := ORD(local2[i]) - ORD('0');
    INC(i);
    IF local4 > 9 THEN RETURN FALSE END;
    local5 := local5 * 10 + local4;
    IF NOT local6 THEN
      local6 := (local2[i] = '-');
      IF local6 THEN
        global9  := local5;
        global10 := local5;
        local5   := 0;
        INC(i);
      END;
    END;
  UNTIL (i > HIGH(local2)) OR (local2[i] = 0C);
  IF local6 THEN
    IF local5 < global9 THEN RETURN FALSE END;
    global10 := local5;
    local5   := global9;
  END;
  codepos := local5;
  RETURN TRUE;
END proc4;

PROCEDURE proc19(VAR filename: FileName);
BEGIN
  Terminal.WriteString(filename);
  Terminal.WriteString(" is illegal file name.");
  Terminal.WriteLn;
END proc19;

PROCEDURE FileNotFound(filename: ARRAY OF CHAR); 
BEGIN 
  Terminal.WriteString(filename);
  Terminal.WriteString(" not found.");
  Terminal.WriteLn;
END FileNotFound;

PROCEDURE proc9(string: ARRAY OF CHAR); 
BEGIN 
  Terminal.WriteString("Use Dir command before ");
  Terminal.WriteString(string);
  Terminal.WriteString(" by numbers.");
  Terminal.WriteLn;
END proc9;

PROCEDURE proc10;
BEGIN 
  Terminal.WriteString("WRITE ERROR: DISK FULL"); Terminal.WriteLn
END proc10;

(* proc 3 *)

PROCEDURE Confirm(message: ARRAY OF CHAR): BOOLEAN; 
VAR confirm: BOOLEAN;
    ch: CHAR;
BEGIN 
  Terminal.WriteString(message);
  Terminal.WriteString(" (Y/N)? ");
  Terminal.ReadChar(ch);
  confirm := CAP(ch) = 'Y';
  IF confirm THEN Terminal.WriteChar('Y') ELSE Terminal.WriteChar('N') END;
  Terminal.WriteLn;
  RETURN confirm
END Confirm;

PROCEDURE proc21(filename: FileName): CARDINAL;
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
    THEN RETURN 3 END;

    wildcard  := wildcard OR (char = '*') OR (char = '?');
    extension := extension OR (char = '.');
    INC(i);
  END;
  IF filename[0] = 0C THEN RETURN 2 END;
  IF wildcard THEN RETURN 1 END;
  RETURN 0
END proc21;

PROCEDURE BuildStdFileName(VAR filename: FileName; defaultExt: ARRAY OF CHAR; forceDefaultExt: BOOLEAN);
VAR i, j, k: CARDINAL;
    name   : FileName;
    char   : CHAR;
BEGIN
  i := 0; j := 0; k := 0;
  (* copy basename *)
  REPEAT
    char    := filename[i];
    name[j] := char;
    INC(i); INC(j);
  UNTIL (char = 0C) OR (char = '.') OR (j = 13);
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
    name[j] := filename[i];
    INC(i); INC(j); INC(k);
  END;
  name[j] := 0C;
  filename := name;
END BuildStdFileName;

(* $[- retain procedure header because of exception handler *)

PROCEDURE DoCreate(VAR file: FILE; VAR filename: FileName);
BEGIN 
  Files.Create(file, filename);
EXCEPTION Files.UseError:
  Files.ResetSys;
  Files.Create(file, filename);
END DoCreate;

(* $[+ suppress procedure names *)

PROCEDURE DoOpen(VAR file: FILE; filename: ARRAY OF CHAR): BOOLEAN;
BEGIN 
  RETURN Files.Open(file, filename);
END DoOpen;

PROCEDURE proc29(number: CARDINAL ): BOOLEAN;
BEGIN
  IF (number - 1 < global12) AND global14[number]^.flag THEN
    RETURN TRUE
  END;
  Terminal.WriteString("No file with number ");
  Texts.WriteCard(Texts.console, number, 0);
  Terminal.WriteLn;
  RETURN FALSE
END proc29;

PROCEDURE FileSelect; (* Workfile command *)
BEGIN
  proc1("Workfile name:", "");
  Texts.ReadString(global2, global17);
  global17[HIGH(global17)] := 0C;
  IF proc21(global17) IN {1,3} THEN
    proc19(global17);
    global17[0] := 0C
  END;
  IF global17[0] <> 0C THEN BuildStdFileName(global17, "MOD", FALSE) END;
  ComLine.tabNames[ComLine.currentTab] := global17;
  ComLine.tabDirs [ComLine.currentTab] := FATDIR.CurrentDir();
END FileSelect;

PROCEDURE proc41(prompt: ARRAY OF CHAR; VAR answer: FileName):BOOLEAN;
VAR buffer: FullName;
    i : CARDINAL;
BEGIN
  buffer := ComLine.tabNames[ComLine.currentTab];
  i := 0;
  WHILE (buffer[i] <> '.') AND (buffer[i] <> 0C) DO INC(i) END;
  buffer[i] := 0C;
  proc1(prompt, buffer);
  Texts.ReadString(global2, answer);
  RETURN answer[0] <> 0C
END proc41;

(* EDIT or COMPILE command *)
PROCEDURE proc42(prompt: ARRAY OF CHAR; execute: CARDINAL);
VAR filename: FileName;
BEGIN
  FATDIR.SaveCurrentDir();
  IF ComLine.tabNames[ComLine.currentTab][0] = 0C THEN
    FileSelect;
    filename := global17;
  ELSE
    filename := ComLine.tabNames[ComLine.currentTab];
    FATDIR.SetCurrentDir( ComLine.tabDirs[ComLine.currentTab] );
  END;
  IF filename[0] <> 0C THEN
    BuildStdFileName(filename, "MOD", FALSE);
    ComLine.inName := filename;
    ComLine.progName[0] := 1C;
    exit := TRUE;
    ComLine.execute := execute;
  END;
END proc42;

(*
PROCEDURE proc43; (* LINK command *)
VAR filename: FileName;
BEGIN
  IF proc41("Link main module:", filename) THEN
    ComLine.progName := "LINK";
    exit := TRUE;
    ComLine.execute := 1;
  END;
END proc43;
*)

PROCEDURE RunCommand; (* RUN command *)
VAR
    filename : FileName;
    i : CARDINAL;
    file : FILE;
BEGIN
  IF proc41("Run MCD-file:", filename) THEN
    BuildStdFileName(filename, "MCD", TRUE);
    exit := TRUE;
    MOVE(ADR(filename), ADR(ComLine.progName), 8);
    i := 0;
    WHILE (i<8) AND (ComLine.progName[i]<>'.') DO INC(i) END;
    IF i < 8 THEN ComLine.progName[i] := 0C END;
    ComLine.execute := 1;
    Terminal.WriteLn;
    proc16;
  END;
END RunCommand;
      
PROCEDURE RunCmdLine; (* RUN command *)
VAR
    filename : FileName;
    i : CARDINAL;
    file : FILE;
BEGIN
  IF commandBuffer[0] = 0C THEN showMenu := TRUE; RETURN END;
  exit := TRUE;
  i := 0;
  WHILE (i<8) AND (commandBuffer[i] <> 0C) AND (commandBuffer[i]<>' ') DO
    ComLine.progName[i] := commandBuffer[i];
    INC(i)
  END;
  IF i < 8 THEN ComLine.progName[i] := 0C END;
  HandleRedirection;
  ComLine.execute := 1;
  proc16;
END RunCmdLine;

VAR i: CARDINAL;
(* $[- *)
BEGIN
  showMenu := FALSE;
  REPEAT
    IF showMenu THEN
      Terminal.ClearScreen;
      FOR i:=0 TO 3 DO
        Terminal.GotoXY(i*20, 0);
        IF i = ComLine.currentTab THEN
          Terminal.Highlight
        ELSE
          Terminal.Normal
        END;
        Terminal.WriteChar(CHR(ORD('1') + i));
        Terminal.WriteChar(':');
        Terminal.WriteString(ComLine.tabNames[i]);
      END;
      Terminal.Normal;
      Terminal.WriteLn;

      WriteCommandItem("File  ");
      WriteCommandItem("Edit  ");
      WriteCommandItem("Compile  ");
      WriteCommandItem("Run  ");
      WriteCommandItem("Quit ");
      Terminal.WriteLn;
      showMenu := FALSE;
    END;
    command := proc2('#', "1234FECRQ");
    CASE command OF
    |   0   : RunCmdLine
    |1,2,3,4: ComLine.currentTab := command - 1
    |   5   : FileSelect
    |   6   : proc42("Edit file:", 2)
    |   7   : proc42("Compile file:", 3); ComLine.codepos := 65535
    |   8   : RunCommand (* Run selected file *)
    |   9   : Terminal.WriteLn; exit := TRUE; ComLine.execute := 65535
    END;
    IF command IN {1,2,3,4,5,6} THEN showMenu := TRUE END;
  UNTIL exit;
  Texts.CloseText(global2);
  Terminal.ExitScreen;
END SHELL.