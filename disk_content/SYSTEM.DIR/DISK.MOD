IMPLEMENTATION MODULE DISK;
FROM SYSTEM IMPORT BIOS,ADR,WORD,BYTE,IORESULT,FILL;

(* TODO: replace BIOS calls by proper Modula-2 code *)
CONST
    (* BIOS functions *)
    READSECT=4; WRITESECT=5;
    SETTRACK=9; SETSECTOR=10; DMAOFFSET=11; READSECTOR=12; WRITESECTOR=13;

TYPE DiskParams = RECORD
                    sector : LBA;
                    dmaAdr : ADDRESS;
                    offset : CARDINAL;
                    count  : CARDINAL;
                  END;
(********************************************************************)
(* Low-level sector routines                                        *)

PROCEDURE ReadSector(sector: LBA; buf: ADDRESS);
VAR params: DiskParams;
BEGIN
  params.sector := sector;
  params.dmaAdr := buf;
  params.offset := 0;
  params.count  := 512;
  BIOS(READSECT, ADR(params));
(*
  BIOS(DMAOFFSET,  buf);
  BIOS(SETTRACK,   CARD(sector DIV 65536L));
  BIOS(SETSECTOR,  CARD(sector MOD 65536L));
  BIOS(READSECTOR, 0);
*)
  IF IORESULT<>0 THEN RAISE DiskError END;
END ReadSector;

PROCEDURE WriteSector(sector: LBA; buf: ADDRESS);
VAR params: DiskParams;
BEGIN
  params.sector := sector;
  params.dmaAdr := buf;
  params.offset := 0;
  params.count  := 512;
  BIOS(WRITESECT, ADR(params));
(*
  BIOS(DMAOFFSET,   buf);
  BIOS(SETTRACK,    CARD(sector DIV 65536L));
  BIOS(SETSECTOR,   CARD(sector MOD 65536L));
  BIOS(WRITESECTOR, 0);
*)
  IF IORESULT<>0 THEN RAISE DiskError END;
END WriteSector;
  
END DISK.

