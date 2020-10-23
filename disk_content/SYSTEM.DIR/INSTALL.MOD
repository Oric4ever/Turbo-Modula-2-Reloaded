MODULE Install;
(* Install a Modula-2 system in the reserved sectors of the disk
*)
FROM SYSTEM IMPORT ADDRESS, BYTE, ADR, BIOS, IORESULT;
IMPORT Files, Strings;

CONST WRITESECT=5;
TYPE DiskParams = RECORD
                    sector: LONGINT;
                    dmaAdr: ADDRESS;
                    offset,count: CARDINAL;
                  END;
VAR image: ARRAY [0..63] OF ARRAY [0..511] OF BYTE;
    name: ARRAY [0..7] OF CHAR;
    SYSname : ARRAY [0..11] OF CHAR;
    file: Files.FILE;
    sect, size: CARDINAL;
    params: DiskParams;
BEGIN
  (* read the system image *)
  WRITE('System filename (without BIN extension): '); READLN(name);
  SYSname := name; Strings.Append('.BIN', SYSname);
  IF NOT Files.Open(file, SYSname) THEN WRITE("Cannot find ",SYSname); HALT END;
  size := Files.ReadBytes(file, ADR(image[8]), 32768);
  Files.Close(file);

  (* and write the reserved sectors *)
  params.offset := 0;
  params.count  := 512;
  FOR sect:=8 TO 63 DO
    params.sector := LONG(sect);
    params.dmaAdr := ADR(image[sect]);
    BIOS(WRITESECT, ADR(params));
    IF IORESULT<>0 THEN WRITELN('Disk error') END;
  END;

  (* read the overlays image too *)
  SYSname := name; Strings.Append('.OVR', SYSname);
  IF NOT Files.Open(file, SYSname) THEN WRITE("Cannot find ",SYSname); HALT END;
  size := Files.ReadBytes(file, ADR(image), 32768);
  Files.Close(file);

  (* and write the reserved sectors *)
  params.offset := 0;
  params.count  := 512;
  FOR sect:=0 TO 63 DO
    params.sector := LONG(sect+64);
    params.dmaAdr := ADR(image[sect]);
    BIOS(WRITESECT, ADR(params));
    IF IORESULT<>0 THEN WRITELN('Disk error') END;
  END
END Install.
