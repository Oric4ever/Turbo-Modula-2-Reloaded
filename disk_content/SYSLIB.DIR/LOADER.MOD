IMPLEMENTATION MODULE Loader;
FROM TERMINAL IMPORT WriteLn, WriteString, WriteChar;
FROM FATDIR   IMPORT BaseName, Build83Name, EnterDir, EnterRootDir, CurrentDir, SetCurrentDir,
                     Directory, SaveCurrentDir, BackToSavedDir, EntryNameAndType;
FROM FileDesc IMPORT File, FileDescriptor, InitFile, FindFile, ReadBuffer;
FROM Files    IMPORT ReadBytes;
FROM InitMod  IMPORT ModuleDesc, ModDescPtr, Name, FLAGS, FlagSet, InitModules;
FROM SYSTEM   IMPORT MOVE, FILL, ADR, BYTE, WORD, TSIZE,
                     PROCESS, OUTOFMEMORY, NEWPROCESS, TRANSFER;
FROM STORAGE  IMPORT MARK, RELEASE, FREEMEM;
FROM Texts    IMPORT TEXT, OpenText, CloseText, ReadString, ReadLn;

CONST TRACE = FALSE;

CONST MAXLIB = 3;
      OUTOFMEMORYMSG = "Out of memory";

TYPE
(*
     FLAGS      = (OVERLAY, Z80, TOINIT, RECURSEFLAG);
     FlagSet    = SET OF FLAGS;
     FlagSetPtr = POINTER TO FlagSet;
*)
     Dependency = RECORD
                   name    : Name;
                   version : CARDINAL;
                   location: ADDRESS;
                 END;

(* VAR libraries  [0352H]: ARRAY [0..MAXLIB-1] OF Name; *)

VAR module1    [030CH]: ADDRESS;
    callerTask [0308H]: PROCESS;
    calledTask [030AH]: PROCESS;

    unused      : CARDINAL; (* was public variable firstDrive, keep it in case *)
    nbLibs      : CARDINAL;
    directories : ARRAY [0..7] OF Directory;
    allocAddr   : ADDRESS;
    errorMsg    : ARRAY [0..25] OF CHAR;
    moduleChain : ModDescPtr;
    moduleFile  : File;
    loadSuccess : BOOLEAN;

(* Cherche les bibliothèques déclarées et les initialise *)
PROCEDURE InitLibs;
BEGIN
END InitLibs;

PROCEDURE FileSearch(f: FILE; fname: ARRAY OF CHAR; ext: Extension): BOOLEAN;
VAR i, n: CARDINAL;
    file: File;
BEGIN
  IF TRACE THEN WriteString("Searching "); WriteString(fname); WriteLn END;
  file := ADDRESS(f);
  Build83Name(fname,ext,TRUE,file^.entry.desc.nameAndType);
  
  (* try first in current directory *)
  IF FindFile(file) THEN RETURN TRUE END;
  (* otherwise try in libraries *)
  SaveCurrentDir;
  n := 0;
  REPEAT
    SetCurrentDir( directories[n] );
    IF FindFile(file) THEN
      BackToSavedDir;
      RETURN TRUE
    END;
    INC(n);
  UNTIL n = nbLibs;
  BackToSavedDir;
  RETURN FALSE
END FileSearch;

PROCEDURE LibRead(f: FILE; addr: ADDRESS; nbytes: CARDINAL): BOOLEAN;
BEGIN
  RETURN ReadBytes(f, addr, nbytes) = nbytes
END LibRead;

(* procedure is kept for compatibility with old definition *)
PROCEDURE NLibs(): CARDINAL;
BEGIN
  RETURN 0 (* saves space in programs that reserve memory proportional to NLibs() *)
END NLibs;

(* Try to open a module, first in current dir, then in the "libraries" *)
PROCEDURE LibOpen(f: FILE; fname: ARRAY OF CHAR; symfile: BOOLEAN): BOOLEAN;
BEGIN
  IF symfile
  THEN RETURN FileSearch(f, fname, "SYM")
  ELSE RETURN FileSearch(f, fname, "MCD")
  END;
END LibOpen;

PROCEDURE Error(errorNum: CARDINAL; name: ARRAY OF CHAR);
BEGIN
  IF    errorNum = 0 THEN errorMsg := "Read Error      : ";
  ELSIF errorNum = 1 THEN errorMsg := "Module not found: ";
  ELSE                    errorMsg := OUTOFMEMORYMSG;
  END;
IF TRACE THEN WriteString(errorMsg); WriteLn END;
  (* concatenate name to errorMsg *)
  MOVE(ADR(name), ADR(errorMsg[18]), HIGH(name)+1 );
  RAISE LoadError (* will be caught and raised again *)
END Error;


PROCEDURE DisplayConflict(VAR param2, param1: Name);
CONST ConflictMsg = "Version conflict";
BEGIN
  WriteLn;
  WriteString(ConflictMsg);
  WriteString(' between ');
  WriteString(param2);
  WriteString(' and ');
  WriteString(param1);
  loadSuccess := FALSE;
  errorMsg    := ConflictMsg;
END DisplayConflict;

PROCEDURE AlreadyLoadedModule(
                    VAR moduleName: Name;
                    VAR referencingModule: Name;
                    referencedChecksum: CARDINAL;
                    VAR moduleAddr: ADDRESS): BOOLEAN;
VAR module: ModDescPtr;
BEGIN
  module := module1;
  WHILE module <> NIL DO
    IF module^.name = moduleName THEN
      IF (referencedChecksum <> 0) AND (module^.checksum <> referencedChecksum) THEN
        DisplayConflict(referencingModule, moduleName)
      END;
      moduleAddr := ADDRESS(module) + 80;
      RETURN TRUE;
    END;
    module := ADDRESS(module^.link);
  END;
  RETURN FALSE
END AlreadyLoadedModule;

PROCEDURE UpdateReferences(toAddr, from: ADDRESS);
VAR ref: ADDRESS;
BEGIN
  REPEAT
    ref   := ADDRESS(from^);
    from^ := toAddr;
    from  := ref
  UNTIL ref = NIL;
END UpdateReferences;

PROCEDURE TranslateAddresses(nbModules: CARDINAL; ptr: ADDRESS);
VAR module : ModDescPtr;
    local3 : POINTER TO ADDRESS;
    local4 : ADDRESS;
    endVars: ADDRESS;
    local6 : ADDRESS;
    local7 : CARDINAL;
    local8 : ADDRESS;
BEGIN
  WHILE nbModules <> 0 DO
    module := allocAddr + CARDINAL(ptr^) - 80;  INC(ptr, 2);
    local7 := CARDINAL(ptr^);                   INC(ptr, 2);
    IF module <> allocAddr - 80 THEN
      local8  := module^.loadAddr;
      endVars := ptr + (ORD(module^.bytes[1]) + 42) * 2;
      local6  := module;
      REPEAT
        local3 := local8 + CARDINAL(ptr^);      INC(ptr, 2);
        WHILE local3 <> local8 DO
          local4 := local8 + CARDINAL(local3^);
          local3^:= local6;
          local3 := local4;
        END;
        local6 := local6 + 2;
      UNTIL ptr = endVars;

      IF local7 <> 0 THEN
        endVars := ptr + local7 * 2;
        REPEAT
          local3 := local8 + CARDINAL(ptr^);    INC(ptr, 2);
          INC(local3^, CARDINAL(local8));
        UNTIL ptr = endVars;
      END;
    END;
    DEC(nbModules)
  END
END TranslateAddresses;

PROCEDURE LoadWithDependencies(
                          VAR modName, referencer: Name;
                          checksum : CARDINAL;
                          VAR moduleAddr: ADDRESS
                         );


VAR loadedModule  : ModDescPtr;
    module        : ModDescPtr;
    header        : RECORD fileSize, moduleStart, dependencies, nbDependencies, w4,w5,w6,w7: CARDINAL; END;
    i             : INTEGER;
    origin        : CARDINAL;   (* base address of the module *)
    dependencySize: CARDINAL;
    nbModules     : INTEGER;
    dependencies  : ARRAY [0..31] OF Dependency;
    dependModAddr : ADDRESS;
BEGIN
  IF NOT LibOpen(FILE(moduleFile), modName, FALSE)             THEN Error(1, modName) END;
  InitFile(moduleFile);
  origin := allocAddr;
  IF NOT LibRead(FILE(moduleFile), ADR(header), SIZE(header))  THEN Error(0, modName) END;
  (* $O+ *)
  IF allocAddr + header.fileSize + 100 > ADR(header)           THEN Error(2, "") END;
  (* $O- *)
  IF NOT LibRead(FILE(moduleFile), allocAddr, header.fileSize) THEN Error(0, modName) END;

  dependencySize := header.nbDependencies * 12;
  MOVE(allocAddr + header.dependencies, ADR(dependencies), dependencySize);
  loadedModule   := allocAddr + header.moduleStart;

  (* a .MCD may contains *several* modules (when LINKed together), with addresses to translate *)
  module         := loadedModule;
  nbModules      := 0;
  LOOP
    INC(nbModules);
    FOR i := 0 TO 1 - INTEGER(module^.bytes[3]) BY -1 DO
      IF module^.dependencies[i+31] <> 0 THEN    (* if the addr of dependency is present, then *)
        INC(module^.dependencies[i+31], origin)  (* it means the module is in the .MCD, so adjust the addr *)
      END;
    END;
    INC(module^.loadAddr,  origin);
    INC(module^.procsAddr, origin);
    INCL(module^.flags, RECURSEFLAG);     (* mark the module to avoid infinite recursion loops *)
    IF module^.link = NIL THEN EXIT END;  (* end of the module chain *)
    module^.link := ADDRESS(module^.link) + origin;
    module       := module^.link;
  END;
  (* the last module in the chain is the one asked to be loaded, check its version *)
  IF (checksum <> 0) AND (module^.checksum <> checksum) THEN
    DisplayConflict(referencer, module^.name)
  END;

  IF NOT AlreadyLoadedModule(module^.name, referencer, module^.checksum, moduleAddr) THEN
    TranslateAddresses(nbModules, allocAddr + header.dependencies + dependencySize);
    module^.link := module1;
    module1      := loadedModule;
    moduleAddr   := ADR(module^.flags);
    allocAddr    := allocAddr + header.dependencies;
    i := 0;
    WHILE i < INTEGER(CARD(INTEGER(header.nbDependencies))) DO
      WITH dependencies[i] DO
        IF NOT AlreadyLoadedModule(name, module^.name, version, dependModAddr) THEN
          (* recursive call *)
          LoadWithDependencies(name, module^.name, version, dependModAddr);
        END;
        UpdateReferences(dependModAddr, location + origin);
      END;
      INC(i);
    END;
  END;
END LoadWithDependencies;

PROCEDURE ChainAllModules(module: ModDescPtr);
VAR i: INTEGER;
    dependencyModule : ADDRESS;
BEGIN
  EXCL(module^.flags, RECURSEFLAG);
  FOR i:=0 TO 1 - INTEGER(CARD(INTEGER(module^.bytes[3]))) BY -1 DO
    dependencyModule := module^.dependencies[i+31];
    IF (dependencyModule <> NIL)
    AND (RECURSEFLAG IN FlagSet(dependencyModule^)) THEN
      ChainAllModules(dependencyModule - 80)  (* recursive ! *)
    END;
  END;
  IF moduleChain = NIL THEN module1 := module
  ELSE moduleChain^.link := module
  END;
  moduleChain := module;
END ChainAllModules;

(* $[- : retain procedure name because of exception handler *)

PROCEDURE LoadThisModule(name: Name);
VAR oldFirstModule : ADDRESS;
    moduleAddr     : ADDRESS;
    fd             : FileDescriptor;
BEGIN
  moduleFile := ADR(fd);
  oldFirstModule := module1;
  loadSuccess    := TRUE;  (* Load Success *)
  LoadWithDependencies(name, name, 0, moduleAddr);
  IF loadSuccess THEN
    IF module1 <> oldFirstModule THEN
      moduleChain := NIL; ChainAllModules(moduleAddr - 80);
    END;
  END;
EXCEPTION
| LoadError : loadSuccess := FALSE
END LoadThisModule;

PROCEDURE WriteCard(i: CARDINAL);
BEGIN
  IF TRACE THEN
    IF i>9 THEN WriteCard(i DIV 10) END;
    WriteChar(CHR(ORD('0') + i MOD 10));
  END;
END WriteCard;

PROCEDURE Call(modName: ARRAY OF CHAR);
VAR modulePtr      : ModDescPtr;
    oldFirstModule : ModDescPtr;
    saveHeapAddr   : ADDRESS;
    saveCallerTask : PROCESS;
    saveCalledTask : PROCESS;
    varCount       : CARDINAL;
    varSize        : CARDINAL;
    globalVarsPtr  : POINTER TO ARRAY [0..255] OF CARDINAL;
    name           : Name;
BEGIN
IF TRACE THEN WriteString("Calling "); WriteString(modName); WriteLn END;
  name            := modName;
  oldFirstModule  := module1;
  saveCallerTask  := callerTask;
  saveCalledTask  := calledTask;
  MARK(saveHeapAddr);
  allocAddr       := saveHeapAddr + 4;

  LoadThisModule(name);

  (* allocate memory for global arrays and records *)
  modulePtr := module1;
  WHILE loadSuccess AND (modulePtr <> oldFirstModule) DO
    varCount := ORD(modulePtr^.bytes[1]);
    globalVarsPtr := ADDRESS(modulePtr) + TSIZE(ModuleDesc);
    WHILE loadSuccess AND (varCount <> 0) DO
      DEC(varCount);
      varSize := globalVarsPtr^[varCount];
      IF varSize <> 0 THEN
        (* $O+ *)
        IF allocAddr + varSize + 100 > ADR(name) THEN
        (* $O- *)
          errorMsg := OUTOFMEMORYMSG;
          loadSuccess := FALSE
        ELSE
          FILL(allocAddr, varSize, 0);
          globalVarsPtr^[varCount] := CARDINAL(allocAddr);
          allocAddr := allocAddr + varSize;
        END;
      END;
    END;
    modulePtr := modulePtr^.link;
  END;
  IF TRACE THEN WriteCard(FREEMEM()); WriteString(' bytes free'); WriteLn END;

  (* if all is ok so far, init all the loaded modules (ie. up to the old first) *)
  IF loadSuccess THEN InitModules(oldFirstModule, allocAddr) END;

  (* clean memory after the called module has been run *)
  RELEASE(saveHeapAddr);
  callerTask := saveCallerTask;
  calledTask := saveCalledTask;
  module1    := oldFirstModule;
  IF NOT loadSuccess THEN RAISE LoadError, errorMsg END
END Call;

(* $[+ : remove procedure names *)

VAR i       : CARDINAL;
    dirname : EntryNameAndType;
    paths   : TEXT;
BEGIN
  dirname.extension := "DIR";
  SaveCurrentDir; EnterRootDir;
  IF OpenText(paths, "LOADPATH.TXT") THEN
    nbLibs := 0;
    REPEAT
      ReadString(paths, dirname.baseName);
      ReadLn(paths);
      IF dirname.baseName[0] # 0C THEN
        EnterRootDir;
        WITH dirname DO
          i := 0;
          WHILE (i <= HIGH(baseName)) AND (baseName[i] # 0C) DO INC(i) END;
          WHILE  i <= HIGH(baseName)  DO   baseName[i] := ' ';  INC(i) END;
          IF EnterDir(dirname.fullName) THEN
            directories[nbLibs] := CurrentDir();
            INC(nbLibs);
          ELSE
            WriteString("Warning: loadpath /");
            WriteString(baseName);
            WriteString(" not found.");
            WriteLn;
          END;
        END;
      END;
    UNTIL (dirname.baseName[0] = 0C) OR (nbLibs > HIGH(directories));
    CloseText(paths);
  ELSE
    WriteString("No LOADPATH.TXT file.");
    WriteLn;
  END;
  BackToSavedDir;
END Loader.
