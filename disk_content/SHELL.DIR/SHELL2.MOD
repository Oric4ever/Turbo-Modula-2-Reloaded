IMPLEMENTATION MODULE SHELL;
IMPORT FATDIR, Texts, Files, Terminal, ComLine, Loader, ShellRes;
FROM SYSTEM IMPORT MOVE, ADR, ADDRESS, WORD, BYTE, BDOS, IORESULT, HLRESULT;
FROM STORAGE IMPORT FREEMEM, ALLOCATE, MARK, RELEASE;

CONST CTRLC = 03C; BackSpace = 10C; TAB = 11C; LF = 12C; CR = 15C;
      XOFF = 23C; CTRLX = 30C; EOT = 32C; ESC = 033C; DEL = 177C; 

CONST USERNUM = 32; DMAOFFSET = 26; SEARCHFIRST = 17; SEARCHNEXT = 18;

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

VAR buffer      [0080H] : ARRAY [0..127] OF CHAR;
    commandLine [0081H] : ARRAY [0..126] OF CHAR;
    systemParams[0348H] : BITSET;
    bootFlag    [0322H] : BOOLEAN;
    libraries   [0352H] : ARRAY [0..7],[0..7] OF CHAR;

(*
(*  2 *) global2 : Texts.TEXT;
(*  3 *) global3 : CARDINAL;
(*  4 *) global4 : CARDINAL;
(*  5 *) exit : CARDINAL;
(*  6 *) global6 : BOOLEAN;
(*  7 *) global7 : BOOLEAN;
(*  8 *) index   : CARDINAL;
*)
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
        Terminal.WriteChar(BackSpace);
        Terminal.WriteChar(' ');
        Terminal.WriteChar(BackSpace);
        DEC(i);
      END;
    ELSIF (char = CTRLX) OR (char = ESC) THEN
      WHILE i <> 0 DO
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
  IF ORD(commandLine[index]) - ORD('<') IN {0,2} THEN (* ie. '<' or '>' *)
    REPEAT INC(index) UNTIL commandLine[index] <= ' ';
  END;
  char := commandLine[index];
  IF char = 0C THEN char := EOT END;
  INC(index);
END CmdLineDriver;

PROCEDURE HandleRedirection; (* handle redirection *)
VAR ch: CHAR;
BEGIN
  index := 0;
  Texts.CloseText(global2);
  Texts.ConnectDriver(global2, CmdLineDriver);
  ComLine.inName  := "CON:";
  ComLine.outName := ComLine.inName;
  REPEAT
    ch := commandLine[index];
    INC(index);
    IF ORD(ch) - ORD('<') IN {0,2} THEN
      IF commandLine[index] > ' ' THEN
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
  IF (NOT global7) OR (commandLine[1] = 0C) THEN
    Terminal.WriteLn; Terminal.WriteString(prompt); Terminal.WriteChar(' ');
    ReadCmdLine(commandLine, default);
  END;
  HandleRedirection;
END proc1;

PROCEDURE proc16;
VAR local2: ARRAY [0..19] OF CHAR;
BEGIN
  index := 0;
  Texts.ReadString(global2, local2);
  MOVE(ADR(commandLine[index]), ADR(commandLine[0]), 127-index);
  buffer[0] := 0C;
  WHILE (ORD(buffer[0]) < 126) AND (commandLine[ORD(buffer[0])] <> 0C) DO
    buffer[0] := CHR(ORD(buffer[0]) + 1);
  END;
END proc16;

PROCEDURE proc2(prompt: CHAR; commands : ARRAY OF CHAR): CARDINAL;
VAR i : CARDINAL;
    ch : CHAR;
BEGIN
  Terminal.WriteChar(prompt);
  Terminal.WriteChar(' ');
  ReadCmdLine(commandLine, "");
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

PROCEDURE proc22(filename: FileName; VAR fcb: FCB; VAR user: CARDINAL);
VAR i, j: CARDINAL;
    char : CHAR;
BEGIN
  filename[HIGH(filename)] := 0C;
  fcb := "@           ";
  j := 1;
  i := 0;
  REPEAT
    char  := filename[i];
    IF char = '.' THEN
      j := 9; INC(i);
      WHILE filename[i] <> 0C DO
        char := filename[i];
        IF char = '*' THEN
          WHILE j <= 11 DO fcb[j] := '?'; INC(j) END;
        END;
        IF j <= 11 THEN
          fcb[j] := char;
          INC(j);
        END;
        INC(i);
      END;
    END;
    IF char = '*' THEN
      WHILE j <= 8 DO fcb[j] := '?'; INC(j) END;
    END;
    IF (j <= 8) AND (char <> 0C) THEN fcb[j] := char; INC(j) END;
    INC(i);
  UNTIL filename[i] = 0C;
END proc22;

PROCEDURE proc23(filename: FileName);
VAR i, n : CARDINAL;
    fcb : FCB;
    buffer: ARRAY [0..127] OF CHAR;
    local6: NamePtr;
BEGIN
  proc22(filename, fcb, global13);
  BDOS(USERNUM, global13);
  BDOS(DMAOFFSET, ADR(buffer));
  BDOS(SEARCHFIRST, ADR(fcb));
  n := IORESULT;
  global12 := 0;
  WHILE (global12 <= 255) AND (n <> 255) DO
    INC(global12);
    local6 := ADR(global11[global12]);
    local6^.flag         := TRUE;
    local6^.fullname[0] := CHR(ORD(fcb[0]) + 64);
    local6^.fullname[1] := CHR(global13 DIV 10 + ORD('0'));
    local6^.fullname[2] := CHR(global13 MOD 10 + ORD('0'));
    local6^.fullname[3] := ':';
    i := 1;
    REPEAT
      local6^.fullname[i+3] := CHR(ORD(buffer[n*32+i]) MOD 128); (* remove flag bits*)
      INC(i);
    UNTIL i > 8;
    local6^.fullname[12] := '.';
    i := 9;
    REPEAT
      local6^.fullname[i+4] := CHR(ORD(buffer[n*32+i]) MOD 128); (* remove flag bit *)
      INC(i);
    UNTIL i > 11;
    BDOS(SEARCHNEXT, ADR(fcb));
    n := IORESULT;
  END;
  BDOS(USERNUM, userNum);
END proc23;

CONST NoFilesPresent = "No files present.";

PROCEDURE DirCommand;
  PROCEDURE proc27;
    PROCEDURE QuickSort(low, high: CARDINAL);
    VAR i,j : CARDINAL;
        pivot, tmp : NamePtr;
    BEGIN
      i := low;
      j := high;
      pivot := global14[(low + high) DIV 2];
      REPEAT
        WHILE global14[i]^.fullname < pivot^.fullname DO INC(i) END;
        WHILE pivot^.fullname < global14[j]^.fullname DO DEC(j) END;
        IF i <= j THEN
          tmp := global14[i];
          global14[i] := global14[j];
          global14[j] := tmp;
          INC(i); DEC(j);
        END;
      UNTIL i > j;
      IF low < j  THEN QuickSort(low, j)  END;
    IF i < high THEN QuickSort(i, high) END;
    END QuickSort;

  VAR i, j: CARDINAL;
  BEGIN
    i := 1; j := global12;
    WHILE i <= j DO global14[i] := ADR(global11[i]); INC(i) END;
    QuickSort(1, global12);
  END proc27;

VAR filename1, filename2 : FileName;
    local4,
    local5,
    local6,
    local7,
    local8,
    local9,
    local10,
    local11 : CARDINAL;
    local12 : CHAR;
    local13 : CHAR;
    local14 : ARRAY [0..255] OF CHAR;
BEGIN
  proc1("Directory mask:", "*.*");
  Texts.ReadString(global2, filename1);
  filename2 := filename1;
  proc23(filename1);
  IF global12 <> 0 THEN
    proc27;
    local10 := Terminal.numRows - 6;
    local11 := (Terminal.numCols + 2) DIV 20;
    ComLine.RedirectOutput;
    local7 := 0;
    REPEAT
      local8 := local7 + local10 * local11;
      IF local8 > global12 THEN local8 := global12 END;
      local6 := 0;
      local9 := local7;
      REPEAT
        local4 := local6;
        local5 := 0;
        WHILE (local5 <> local10) AND (local7 + local4 < local8) DO
          local14[local4] := CHR(local9);
          INC(local9);
          INC(local4, local11);
          INC(local5);
        END;
        INC(local6);
      UNTIL local6 >= local11;
      local4 := 0;
      REPEAT
        local6 := 0;
        REPEAT
          Texts.SetCol     (Texts.output, local6 * 16);
(*
          Texts.WriteCard  (Texts.output, ORD(local14[local4])+1, 3);
          Texts.WriteChar  (Texts.output, ':');
          Texts.WriteChar  (Texts.output, ' ');
*)
          Texts.WriteString(Texts.output, global14[ORD(local14[local4])+1]^.filename);
          INC(local4);
          INC(local7);
          INC(local6);
        UNTIL (local7 = local8) OR (local6 >= local11);
        Texts.WriteLn(Texts.output);
      UNTIL local7 >= local8;
      IF local8 <> global12 THEN
        Terminal.WriteLn;
        Terminal.WriteString('"C" to continue >');
        Terminal.ReadChar(local13);
        local13 := CAP(local13);
        Terminal.WriteChar(local13);
        Terminal.WriteLn;
        Terminal.WriteLn;
      END;
    UNTIL (local8 = global12) OR (local13 <> 'C');
(*
    Texts.WriteString(Texts.output, "Bytes Remaining on ");
    Texts.WriteChar  (Texts.output, local12);
    Texts.WriteChar  (Texts.output, ':');
    Texts.WriteChar  (Texts.output, ' ');
    Texts.WriteCard  (Texts.output, proc24(ORD(local12) - ORD('A')), 0);
    Texts.WriteChar  (Texts.output, 'K');
    Texts.WriteLn    (Texts.output);
*)
    Texts.CloseText  (Texts.output);
    global15 := TRUE;
  ELSE
    Terminal.WriteString(NoFilesPresent);
    Terminal.WriteLn;
  END;
END DirCommand;

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

PROCEDURE proc30;
  (* $[- *)
  PROCEDURE CopyFile(param2: FileName; param1: FileName): BOOLEAN;
  VAR
      local2: ADDRESS;
      local3: FileName;
      local4: FILE;
      local5: FILE;
      local6: CARDINAL;
      local7: CARDINAL;
      local8: ADDRESS;
      local9: WORD;
  BEGIN
    IF proc21(param1) = 2 THEN 
      BuildStdFileName(param1, "", FALSE);
      BuildStdFileName(param2, "", FALSE);
      local3 := param1;
      param1 := param2;
      MOVE(ADR(local3), ADR(param1), 3);
    END;
    local3 := param1;
    BuildStdFileName(local3, "$$$", TRUE);
    MARK(local8);
    DoCreate(local5, local3);
    IF Files.Open(local4, param2) THEN
      local7 := FREEMEM() - 500;
      ALLOCATE(local2, local7);
      Files.NoTrailer(local4);
      Files.NoTrailer(local5);
      REPEAT
        local6 := Files.ReadBytes(local4, local2, local7);
        Files.WriteBytes(local5, local2, local6);
      UNTIL local6 < local7;
      Files.Close(local4);
      Files.Rename(local5, param1);
    ELSE
      Files.Delete(local5);
      FileNotFound(param2);
    END;
    RELEASE(local8);
    RETURN TRUE;
  
  EXCEPTION Files.DiskFull: 
    proc10;
    Files.Delete(local5);
    RELEASE(local8);
    RETURN FALSE;
  END CopyFile;

(* $[+ *)
CONST Msg1 = "Second argument must be drive-code.";
      COPYTO = "Copy to  : ";
      COPYING = "Copying ";
VAR
    filename1, filename2: FileName;
    local4: CARDINAL;
    local5: CARDINAL;
    local6: CARDINAL;
    local7: BOOLEAN;
    char : CHAR;
    local9 : NamePtr;
BEGIN
  proc1("Copy from:", "");
  Texts.ReadChar(global2, char);
  IF ORD(char) - ORD('0') <= 9 THEN
    IF global15 THEN
      Texts.ReadAgain(global2);
      Terminal.WriteString(COPYTO);
      Texts.ReadString(Texts.input, filename2);
      Texts.ReadLn(Texts.input);
      IF filename2[0] <> 0C THEN
        IF proc21(filename2) = 2 THEN
          filename2[0] := CAP(filename2[0]);
          REPEAT
            local7 := proc4(local6) AND proc29(local6);
            IF local7 THEN
              local9 := global14[local6];
              Terminal.WriteString(COPYING);
              Terminal.WriteString(local9^.fullname);
              Terminal.WriteLn;
              filename1 := local9^.fullname;
              local7 := CopyFile(filename1, filename2);
            END;
          UNTIL NOT local7;
        ELSE
          Terminal.WriteString(Msg1);
          Terminal.WriteLn;
        END;
      END;
    ELSE
      proc9("copying");
    END;
  ELSE
    Texts.ReadAgain(global2);
    Texts.ReadString(global2, filename1);
    IF filename1[0] <> 0C THEN
      local4 := proc21(filename1);
      IF proc18(COPYTO, filename2) THEN
        local5 := proc21(filename2);
        IF local5 IN {1,3} THEN proc19(filename2)
        ELSIF local4 IN {2,3} THEN proc19(filename1)
        ELSIF local4 = 1 THEN
          IF local5 = 0 THEN
            Terminal.WriteString(Msg1);
            Terminal.WriteLn;
          ELSE
            proc23(filename1);
            global15 := FALSE;
            IF global12 <> 0 THEN
              local6 := 0;
              REPEAT
                INC(local6);
                local9 := ADR(global11[local6]);
                Terminal.WriteString("Copying ");
                Terminal.WriteString(local9^.fullname);
                Terminal.WriteLn;
                filename1 := local9^.fullname;
                local7 := CopyFile(filename1, filename2);
              UNTIL (NOT local7) OR (local6 >= global12);
            ELSE
              Terminal.WriteString(NoFilesPresent);
              Terminal.WriteLn;
            END;
          END;
        ELSE
          BuildStdFileName(filename1, "", FALSE);
          local7 := CopyFile(filename1, filename2);
        END;
      END;
    END;
  END;
END proc30;

(* $[- *)

PROCEDURE Renam;
VAR
    filename1, filename2 : FileName;
    unused1, unused2 : WORD; 
    file1, file2 : FILE;
BEGIN
  proc1("Rename from:", "");
  Texts.ReadString(global2, filename1);
  IF (filename1[0] <> 0C) AND proc18("Rename to  : ", filename2) THEN
    global15 := FALSE;
    IF proc21(filename2) = 0 THEN
      BuildStdFileName(filename1, "", FALSE);
      BuildStdFileName(filename2, "", FALSE);
      IF Files.Open(file1, filename1) THEN
        IF Files.Open(file2, filename2) THEN
          Terminal.WriteString(filename2);
          IF Confirm(" exists, overwrite") THEN
            Files.Delete(file2);
            Files.Rename(file1, filename2);
          ELSE
            Files.Close(file2);
            Files.Close(file1);
          END;
        ELSE
          Files.Rename(file1, filename2)
        END;
      ELSE
        FileNotFound(filename1)
      END;
    ELSE
      proc19(filename2)
    END;
  END;

EXCEPTION
| Files.UseError :
  Files.ResetSys;
  Files.Close(file1);
  Files.Delete(file2);  
  IF Files.Open(file1, filename1) THEN 
    Files.Rename(file1, filename2)
  END;
END Renam;

PROCEDURE Delete;
  PROCEDURE Delet(VAR name: FullName);
  VAR file: FILE;
  BEGIN
    IF Files.Open(file, name) THEN Files.Delete(file) END;
  EXCEPTION Files.UseError:
    Files.ResetSys;
    Files.Delete(file);
  END Delet;
VAR
    filename : FileName;
    local3 : CARDINAL;
    local4 : CARDINAL; 
    char : CHAR;
    file : FILE;
    local7 : POINTER TO ARRAY [0..2] OF CHAR;
    local8 : NamePtr;
BEGIN
  proc1("Delete file:", "");
  Texts.ReadChar(global2, char);
  IF ORD(char) - ORD('0') <= 9 THEN
    IF global15 THEN
      Texts.ReadAgain(global2);
      WHILE proc4(local4) AND proc29(local4) DO
        local8 := global14[local4];
        Terminal.WriteString("Delete ");
        IF Confirm(local8^.fullname) THEN
          Delet(local8^.fullname);
          local8^.flag := FALSE;
        END;
      END;
    ELSE
      proc9("deleting");
    END;
  ELSE
    Texts.ReadAgain(global2);
    Texts.ReadString(global2, filename);
    IF filename[0] <> 0C THEN
      local3 := proc21(filename);
      global15 := FALSE;
      IF local3 IN {2,3} THEN proc19(filename)
      ELSIF local3 = 1 THEN
        local7 := ADR(filename[ ORD(filename[1] = ':') * 2]);
        IF (local7^ <> "*.*") OR Confirm("Delete all files") THEN
          proc23(filename);
          IF global12 <> 0 THEN
            local4 := 0;
            REPEAT
              INC(local4);
              local8 := ADR(global11[local4]);
              Terminal.WriteString("Deleting ");
              Terminal.WriteString(local8^.fullname);
              Terminal.WriteLn;
              Delet(local8^.fullname);
            UNTIL local4 >= global12;
          ELSE
            Terminal.WriteString(NoFilesPresent);
            Terminal.WriteLn;
          END;
        END;
      ELSE
        IF Files.Open(file, filename) THEN
          Files.Delete(file)
        ELSE
          FileNotFound(filename)
        END;
      END;
    END;
  END;

EXCEPTION Files.UseError:
  Files.ResetSys;
  Files.Delete(file);
END Delete;

(* $[+ *)

PROCEDURE proc38; (* TYPE command *)
VAR
    filename : FileName;
    file : FILE;
    char : CHAR;
    key : CHAR;
    console : BOOLEAN;
BEGIN
  proc1("Type file:", "");
  Texts.ReadString(global2, filename);
  IF filename[0] <> 0C THEN
    IF Files.Open(file, filename) THEN
      Files.NoTrailer(file);
      Terminal.WriteLn;
      IF NOT Files.EOF(file) THEN
        ComLine.RedirectOutput;
        console := ComLine.outName = "CON:";
        REPEAT
          Files.ReadByte(file, char);
          IF char = CR THEN
            Texts.WriteLn(Texts.output);
            IF console THEN
              Terminal.BusyRead(key);
              IF key <> 0C THEN
                IF key = XOFF THEN
                  REPEAT
                    Terminal.ReadChar(key);
                  UNTIL (key = CTRLC) OR (key = XOFF);
                END;
                IF key = CTRLC THEN char := EOT END;
              END;
            END;
          ELSE
            IF char = TAB THEN
              Texts.SetCol(Texts.output, (Texts.Col(Texts.output) DIV 8 + 1)*8);
            ELSIF (char <> EOT) AND (char <> LF) THEN
              Texts.WriteChar(Texts.output, char)
            END;
          END;
        UNTIL char = EOT;
        Texts.CloseText(Texts.output);
        Files.Close(file);
        Terminal.WriteLn;
      END;
    ELSE
      FileNotFound(filename) 
    END;
  END;         
END proc38;

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
  ShellRes.tabNames[ShellRes.currentTab] := global17;
  ShellRes.tabDirs [ShellRes.currentTab] := FATDIR.CurrentDir();
END FileSelect;

PROCEDURE proc41(prompt: ARRAY OF CHAR; VAR answer: FileName):BOOLEAN;
VAR buffer: FullName;
    i : CARDINAL;
BEGIN
  buffer := ShellRes.tabNames[ShellRes.currentTab];
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
  ShellRes.saveDir := FATDIR.CurrentDir();
  IF ShellRes.tabNames[ShellRes.currentTab][0] = 0C THEN
    FileSelect;
    filename := global17;
  ELSE
    filename := ShellRes.tabNames[ShellRes.currentTab];
    FATDIR.SetCurrentDir( ShellRes.tabDirs[ShellRes.currentTab] );
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
  IF commandLine[0] = 0C THEN showMenu := TRUE; RETURN END;
  exit := TRUE;
  i := 0;
  WHILE (i<8) AND (commandLine[i] <> 0C) AND (commandLine[i]<>' ') DO
    ComLine.progName[i] := commandLine[i];
    INC(i)
  END;
  IF i < 8 THEN ComLine.progName[i] := 0C END;
  HandleRedirection;
  ComLine.execute := 1;
  proc16;
END RunCmdLine;

PROCEDURE proc46; (* Options menu *)
  TYPE Path = ARRAY [0..71] OF CHAR;
  VAR path: Path;
      i : CARDINAL;
      command: CARDINAL;


  PROCEDURE proc47(param1: CARDINAL);
  BEGIN
    Terminal.WriteString(" (O");
    IF param1 IN systemParams
    THEN Terminal.WriteString("N ")
    ELSE Terminal.WriteString("FF");
    END;
    Terminal.WriteString(")  ");
  END proc47;
  
  PROCEDURE GetSearchPath(VAR param1: Path);
  VAR
      local2, i, libnum : CARDINAL;
      char : CHAR;
  BEGIN
    local2 := 0; libnum := 0;
    REPEAT
      i := 0;
      REPEAT
        char := libraries[libnum][i];
        IF char <> 0C THEN
          param1[local2] := char;
          INC(local2); INC(i);
        END;
      UNTIL (i = 8) OR (char = 0C);
      param1[local2] := ' ';
      INC(local2);
      INC(libnum);
    UNTIL (libnum = 8) OR (i = 0);
    param1[local2-1] := 0C;
  END GetSearchPath;
  
  PROCEDURE SetSearchPath;
  VAR filename: FileName;
      local3 : CARDINAL;
      libnum : CARDINAL;
      char : CHAR;
  BEGIN
    proc1("New search path:", path);
    libnum := 0;
    REPEAT
      Texts.ReadString(global2, filename);
      IF filename[0] <> 0C THEN
        BuildStdFileName(filename, "", TRUE);
        local3 := 4;
        REPEAT
          char := filename[local3];
          IF char = '.' THEN char := 0C END;
          libraries[libnum][local3 - 4] := char;
          INC(local3);
        UNTIL (char = 0C) OR (local3 = 12);
        INC(libnum);
      END;
    UNTIL (libnum = 8) OR Texts.EOT(global2);
    IF libnum < 8 THEN libraries[libnum][0] := 0C END;
    GetSearchPath(path);
  END SetSearchPath;

  PROCEDURE ToggleOption(param3: CARDINAL; param2: ARRAY OF CHAR);
  BEGIN
    systemParams := systemParams / {ORD(param2[param3]) - ORD('L')};
  END ToggleOption;

  PROCEDURE FindRuntimeError;
  VAR name : FullName;
      char : CHAR;
  BEGIN
    proc42("Module name:", 
            ORD((ORD('N')-ORD('L')) IN systemParams) + 4);
    name := ComLine.inName;
    IF exit THEN
      IF NOT proc4(ComLine.codepos) THEN
        proc1("Enter PC:", "");
        Texts.ReadChar(global2, char);
        Texts.ReadAgain(global2);
        IF NOT proc4(ComLine.codepos) THEN
          exit := FALSE;
        END;
      END;
    END;
    ComLine.inName := name;
  END FindRuntimeError;

  PROCEDURE SaveOptions;
  VAR
    file : FILE;
    unused : WORD;
    char : CHAR;
  BEGIN
    IF DoOpen(file, "M2.COM") THEN
      Files.SetPos(file, LONG(CARD(ADR(systemParams)) - 0100H));
      Files.WriteWord(file, systemParams);
      Files.SetPos(file, LONG(CARD(ADR(libraries)) - 0100H));
      Files.WriteRec(file, libraries);
      Files.Close(file);
    ELSE
      FileNotFound("ERROR: File M2.COM");
      Terminal.ReadChar(char);
    END;
  END SaveOptions;

  CONST OPTIONS = "LNXTOUPFSQ";
  CONST FIRSTOPTION = 'L';
  
BEGIN
  GetSearchPath(path);
  REPEAT
    Terminal.ClearScreen;
    Terminal.WriteString("Compiler options:");
    Terminal.WriteLn;
    Terminal.WriteLn;
    WriteCommandItem("List");
    proc47(ORD('L') - ORD(FIRSTOPTION));
    Terminal.WriteChar(' ');
    WriteCommandItem("Native (Z80) ");
    proc47(ORD('N') - ORD(FIRSTOPTION));
    Terminal.WriteChar('e'); WriteCommandItem("Xtensions  ");
    proc47(ORD('X') - ORD(FIRSTOPTION));
    Terminal.WriteLn;
  
    WriteCommandItem("Test");
    proc47(ORD('T') - ORD(FIRSTOPTION));
    Terminal.WriteChar(' ');
    WriteCommandItem("Overflow");
    proc47(ORD('O') - ORD(FIRSTOPTION));
    Terminal.WriteChar(' ');
    WriteCommandItem("Upper=lower");
    proc47(ORD('U') - ORD(FIRSTOPTION));
    Terminal.WriteLn;
    Terminal.WriteLn;
    Terminal.WriteLn;
    
    WriteCommandItem("Path to search: ");
    Terminal.WriteString(path);
    Terminal.WriteLn;
    Terminal.WriteLn;

    WriteCommandItem("Find run-time error");
    Terminal.WriteLn;
    Terminal.WriteLn;

    WriteCommandItem("Save current selection");
    i := 1; REPEAT Terminal.WriteChar(' '); INC(i) UNTIL i > 8;
    WriteCommandItem("Quit");
    Terminal.WriteLn;
    Terminal.WriteLn;

    command := proc2('>', OPTIONS);
    IF command <> 0 THEN
      IF    command <= 6 THEN ToggleOption(command-1, OPTIONS)
      ELSIF command =  7 THEN SetSearchPath
      ELSIF command =  8 THEN FindRuntimeError
      ELSIF command =  9 THEN SaveOptions
      END;
    END;
  UNTIL (command = 10) OR exit;
END proc46;

VAR i: CARDINAL;
(* $[- *)
BEGIN
  showMenu := bootFlag;
  bootFlag := FALSE;
  REPEAT
    IF showMenu THEN
      Terminal.ClearScreen;
      FOR i:=0 TO 3 DO
        Terminal.GotoXY(i*20, 0);
        IF i = ShellRes.currentTab THEN
          Terminal.Highlight
        ELSE
          Terminal.Normal
        END;
        Terminal.WriteChar(CHR(ORD('1') + i));
        Terminal.WriteChar(':');
        Terminal.WriteString(ShellRes.tabNames[i]);
      END;
      Terminal.Normal;
      Terminal.WriteLn;

      WriteCommandItem("File  ");
      WriteCommandItem("Edit  ");
      WriteCommandItem("Compile  ");
      WriteCommandItem("Run  ");
      WriteCommandItem("Options  ");
      WriteCommandItem("Quit ");
      Terminal.WriteLn;
      showMenu := FALSE;
    END;
    command := proc2('#', "1234FECROQ");
    CASE command OF
    |   0   : RunCmdLine
    |1,2,3,4: ShellRes.currentTab := command - 1
    |   5   : FileSelect
    |   6   : proc42("Edit file:", 2)
    |   7   : proc42("Compile file:", 3); ComLine.codepos := 65535
    |   8   : RunCommand (* Run selected file *)
    |   9   : proc46 (* Options *)
    |  10   : Terminal.WriteLn; exit := TRUE; ComLine.execute := 65535
    END;
    IF command IN {1,2,3,4,5,6,9} THEN showMenu := TRUE END;
  UNTIL exit;
  Texts.CloseText(global2);
  Terminal.ExitScreen;
END SHELL.