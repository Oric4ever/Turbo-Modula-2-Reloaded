MODULE Type;
IMPORT Terminal, Texts, Files, ComLine, FileName;
FROM FileName IMPORT FileNameType, CheckFileName, BuildStdFileName;

CONST CTRLC = 03C; BackSpace = 10C; TAB = 11C; LF = 12C; CR = 15C;
      XOFF = 23C; CTRLX = 30C; EOT = 32C; ESC = 033C; DEL = 177C;

VAR
    filename : ARRAY [0..15] OF CHAR;
    file : Files.FILE;
    char : CHAR;
    key : CHAR;
    console : BOOLEAN;
BEGIN
  Texts.ReadString(ComLine.commandLine, filename);
  IF filename[0] = 0C THEN
    Terminal.WriteString("Type file: ");
    Terminal.ReadLine(filename);
  END;
  IF filename[0] <> 0C THEN
    IF Files.Open(file, filename) THEN
      Files.NoTrailer(file);
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
      END;
    ELSE
      Terminal.WriteString(filename);
      Terminal.WriteString(" not found.");
      Terminal.WriteLn;
    END;
  END;


END Type.
