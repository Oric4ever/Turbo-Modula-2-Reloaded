MODULE ED;
FROM SYSTEM  IMPORT ADDRESS;
FROM STORAGE IMPORT ALLOCATE;
IMPORT FATDIR, Texts, Editor, ComLine, ShellRes;
VAR filename: ARRAY [0..19] OF CHAR;
    dummy: ADDRESS;
BEGIN
  FATDIR.SaveCurrentDir;
  Texts.ReadString(ComLine.commandLine, filename);
  IF filename[0] <> 0C THEN ComLine.inName := filename
  ELSIF ShellRes.tabNames[ShellRes.currentTab][0] <> 0C THEN
    FATDIR.SetCurrentDir( ShellRes.tabDirs [ShellRes.currentTab] );
    ComLine.inName     := ShellRes.tabNames[ShellRes.currentTab]
  ELSE
    ComLine.PromptFor("File to edit: ", ComLine.inName)
  END;

  Editor.editPosition := 0;
  Editor.Edit;
  FATDIR.BackToSavedDir;
END ED.