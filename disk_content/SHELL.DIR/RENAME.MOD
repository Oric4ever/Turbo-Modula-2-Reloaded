MODULE Rename;
IMPORT Terminal, Texts, Files, ComLine, FileName;

VAR
    filename1, filename2 : ARRAY [0..15] OF CHAR;
    file1, file2 : Files.FILE;
    ch : CHAR;
BEGIN
  Texts.ReadString(ComLine.commandLine, filename1);
  Texts.ReadString(ComLine.commandLine, filename2);
  IF filename1[0] = 0C THEN
    Terminal.WriteString("Rename from: ");
    Terminal.ReadLine(filename1);
  END;
  IF filename2[0] = 0C THEN
    Terminal.WriteString("Rename to  : ");
    Terminal.ReadLine(filename2);
  END;
  IF filename1[0] <> 0C THEN
    IF FileName.CheckFileName(filename2) = FileName.NORMAL THEN
      FileName.BuildStdFileName(filename1, "", FALSE);
      FileName.BuildStdFileName(filename2, "", FALSE);
      IF Files.Open(file1, filename1) THEN
        IF Files.Open(file2, filename2) THEN (* destination exists *)
          Terminal.WriteString(filename2);
          Terminal.WriteString(" exists, overwrite (Y/N)? ");
          Terminal.ReadChar(ch);
          Terminal.WriteChar(ch);
          Terminal.WriteLn;
          IF CAP(ch) = 'Y' THEN
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
        Terminal.WriteString(filename1);
        Terminal.WriteString(" not found.");
        Terminal.WriteLn;
      END;
    ELSE
      Terminal.WriteString(filename2);
      Terminal.WriteString(" is illegal file name.");
      Terminal.WriteLn;
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

END Rename.
                                                                                                             