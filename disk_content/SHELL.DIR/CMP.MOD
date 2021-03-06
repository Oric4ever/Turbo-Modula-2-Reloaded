MODULE Compare;
FROM Files IMPORT FILE, Open, EOF, ReadByte;
IMPORT Texts, ComLine;

VAR f1, f2: FILE;
    filename1, filename2: ARRAY [0..19] OF CHAR;
    ch1, ch2: CHAR;

PROCEDURE FileCompare;
VAR offset: LONGINT;
BEGIN
  offset := LONG(0);
  WHILE NOT EOF(f1) DO
    IF EOF(f2) THEN WRITELN(filename1, " has additional data at the end."); RETURN END;
    ReadByte(f1, ch1); ReadByte(f2, ch2);
    IF ch1 # ch2 THEN WRITELN("Files differ at offset ",offset); RETURN END;
    offset := offset + LONG(1);
  END;
  IF NOT EOF(f2) THEN WRITELN(filename1, " has additional data at the end.") END;
END FileCompare;

BEGIN
  Texts.ReadString(ComLine.commandLine, filename1);
  Texts.ReadString(ComLine.commandLine, filename2);
  IF filename1[0] = 0C THEN
    WRITE("1st file to compare: "); READ(filename1)
  END;
  IF filename2[0] = 0C THEN
    WRITE("Compare ",filename1," with: "); READ(filename2)
  END;

  IF Open(f1, filename1) THEN
    IF Open(f2, filename2) THEN
      FileCompare
    ELSE WRITELN("Cannot open ", filename2)
    END;
  ELSE WRITELN("Cannot open ", filename1)
  END;
END Compare.              