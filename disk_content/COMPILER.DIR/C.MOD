MODULE M2C;
FROM FATDIR  IMPORT SaveCurrentDir, SetCurrentDir, BackToSavedDir;
FROM Texts   IMPORT ReadString;
FROM Scanner IMPORT proc30;
FROM ComLine IMPORT commandLine, inName, PromptFor;
IMPORT ShellRes;
VAR filename: ARRAY [0..19] OF CHAR;
BEGIN
  SaveCurrentDir;
  ReadString(commandLine, filename);
  IF filename[0] <> 0C THEN inName := filename
  ELSIF ShellRes.tabNames[ShellRes.currentTab][0] <> 0C THEN
    SetCurrentDir( ShellRes.tabDirs [ShellRes.currentTab]);
    inName      := ShellRes.tabNames[ShellRes.currentTab]
  ELSE
    PromptFor("File to compile: ", inName)
  END;
  proc30;
  BackToSavedDir;
END M2C.