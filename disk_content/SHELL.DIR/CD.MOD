MODULE ChDir;
FROM FATDIR  IMPORT EnterDir;
FROM ComLine IMPORT PromptFor;
VAR  name : ARRAY [0..19] OF CHAR;
BEGIN
  PromptFor("Enter dir : ", name);
  IF NOT EnterDir(name) THEN WRITELN(name, " not found.") END;
END ChDir.