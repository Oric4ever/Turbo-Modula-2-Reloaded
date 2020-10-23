IMPLEMENTATION MODULE NEWFAT32;

FROM SYSTEM IMPORT ADR,WORD,BYTE,IORESULT,FILL;
IMPORT Disk;

CONST
    (* FAT32-related constants *)
    FREECLUSTER = 0; FIRSTCLUSTER = 2; ENDOFCHAIN = 268435455L (* 0FFFFFFF *);
    CLUSTERSPERSECTOR = 128L;
    BOOTSECTOR = 0; FSINFOSECTOR = 1;

TYPE LongSplit = RECORD
                   CASE : CARDINAL OF
                   | 1  : low, high: CARDINAL;
                   | 2  : long : LONGINT;
                   END;
                 END;
TYPE
    SectorType = (BOOT, FSINFO, FAT, DIR, DATA);
    BootSectorDesc = RECORD
   (* old DOS 2.0 Bios Parameter Block : *)
   (*  00 *)  FirstBytes: ARRAY [0..0DH] OF CHAR;
                    (*  0B : start of DOS 2.0 BPB *)
                    (*  0D : Logical sectors per cluster *)
   (*  0E *)  ReservedSectors: CARDINAL; (* before the first FAT *)
   (*  10 *)  MiscBytes1: ARRAY [10H..15H] OF CHAR;
   (*  10 : Number of FATs *)
   (*  11-12 : root DIR entries *)
   (*  13-14 : total logical sectors if less than 65536 *)
   (*  15 : Media Descriptor byte *)
   (*  16 *)  UnusedOldSectorsPerFAT: CARDINAL;
   (* DOS 3.31 BPB : *)
   (*  18 *)  SectorsPerTrack: CARDINAL; (* for INT13H *)
   (*  1A *)  Heads: CARDINAL;           (* for INT13H *)
   (*  1C *)  HiddenSectors: LONGINT;
   (*  20 *)  TotalSectors: LONGINT; (* if greater than 65535 *)
   (* FAT32 Extended BPB : *)
   (*  24 *)  SectorsPerFAT: LONGINT;
   (*  28 *)  MirroringFlags: BITSET;
   (*  2A *)  Version: CARDINAL;
   (*  2C *)  FirstRootCluster: Cluster;
   (*  30 *)  FSinfoSector: CARDINAL;
   (*  32 *)  BootSectorsBackup: CARDINAL;
   (*  34 *)  MiscBytes2 : ARRAY [34H..51H] OF CHAR;
   (*  52 *)  FileSysType: ARRAY [52H..59H] OF CHAR;
   (*  5A *)  MiscBytes3 : ARRAY [5AH..1FDH] OF CHAR;
   (* 1FE *)  BootSignature: CARDINAL;
            END;
    FSInfoDesc = RECORD
   (*  00 *)  FSInfoSignature : LONGINT;
   (*  04 *)  reserved : ARRAY [4..1E3H] OF BYTE;
   (* 1E4 *)  FSInfoSignature2: LONGINT;
   (* 1E8 *)  nbFreeDataCluster: LONGINT;
   (* 1EC *)  lastAllocatedCluster: Cluster;
   (* 1F0 *)  reserved2: ARRAY [1F0H..1FBH] OF BYTE;
   (* 1FC *)  FSInfoSignature3: LONGINT;
                 END;
    Sector  = RECORD
                CASE : SectorType OF
                | BOOT  : boot : BootSectorDesc;
                | FSINFO: info : FSInfoDesc;
                | FAT   : fat  : ARRAY [0..127] OF Cluster;
                | DIR,
                  DATA  : data : ARRAY [0..511] OF BYTE;
                END
              END;

(* constant variables initialized from Bios Parameter Block *)
VAR sectorsPerCluster: CARDINAL;
    fragmentMask     : BITSET;      (* mask avoids MOD sectorsPerCluster *)
    FATregion        : LBA;
    sectorsPerFAT    : LONGINT;
    dataRegion       : LBA;

(* variable read from FSInfo sector *)
    lastAllocatedCluster: Cluster;

(* buffer for filesystem operations (BOOT, FSINFO, FAT, DIR) *)
    buffer           : Sector;
    currentSector    : LBA;
    sectorDirty      : BOOLEAN;

(********************************************************************)
(* Low-level sector routines                                        *)

PROCEDURE WriteFS;
BEGIN
  Disk.WriteSector(currentSector, bufferFS);
  sectorDirty := FALSE;
  IF (currentSector < dataRegion) AND (currentSector >= FATregion) THEN
    (* assume sector is in first FAT, update second FAT too *)
    Disk.WriteSector(currentSector+sectorsPerFAT, bufferFS);
  END
END WriteFS;

PROCEDURE SyncFS;
BEGIN
  IF sectorDirty THEN WriteFS END
END SyncFS;

PROCEDURE ReadFS(sector: LBA);
BEGIN
  IF sector <> currentSector THEN
    IF sectorDirty THEN WriteFS END;
    Disk.ReadSector(sector, bufferFS);
    currentSector := sector;
  END
END ReadFS;

(**************************************************************************)
(* clusters operations                                                    *)

PROCEDURE ClusterToLBA(cluster: Cluster): LBA;
BEGIN
  RETURN dataRegion + (cluster - LONG(FIRSTCLUSTER)) * LONG(sectorsPerCluster);
END ClusterToLBA;

(* avoid the cost of a 32-bit division *)
PROCEDURE Fragment(lba: LBA): CARDINAL;
VAR union: LongSplit;
BEGIN
  union.long := lba;
  RETURN CARDINAL(BITSET(union.low) * fragmentMask);
END Fragment;

PROCEDURE ReadFragment(cluster: Cluster; fragment: CARDINAL; buf: ADDRESS);
BEGIN
  Disk.ReadSector(ClusterToLBA(cluster) + LONG(fragment), buf);
END ReadFragment;

PROCEDURE WriteFragment(cluster: Cluster; fragment: CARDINAL; buf: ADDRESS);
BEGIN
  Disk.WriteSector(ClusterToLBA(cluster) + LONG(fragment), buf);
END WriteFragment;

PROCEDURE GetFATentry(cluster: Cluster): Cluster;
BEGIN
  IF (cluster<LONG(FIRSTCLUSTER)) OR (cluster>endCluster) THEN RAISE Disk.DiskError END;
  ReadFS(FATregion + cluster DIV CLUSTERSPERSECTOR);
  RETURN buffer.fat[CARD(cluster MOD CLUSTERSPERSECTOR)]
END GetFATentry;

PROCEDURE PutFATentry(cluster, next: Cluster);
BEGIN
  IF (cluster<LONG(FIRSTCLUSTER)) OR (cluster>endCluster) THEN RAISE Disk.DiskError END;
  ReadFS(FATregion + cluster DIV CLUSTERSPERSECTOR);
  buffer.fat[CARD(cluster MOD CLUSTERSPERSECTOR)] := next;
  sectorDirty := TRUE
END PutFATentry;

PROCEDURE DeleteChain(cluster: Cluster);
VAR next: Cluster;
BEGIN
  WHILE (cluster <= endCluster) AND (cluster <> LONG(FREECLUSTER)) DO
    next := GetFATentry(cluster);
    PutFATentry(cluster,LONG(FREECLUSTER));
    cluster := next;
  END;
  WriteFS;
END DeleteChain;

PROCEDURE FindFreeCluster(): Cluster;
VAR cluster: Cluster;
BEGIN
  cluster := lastAllocatedCluster;
  REPEAT
    cluster := cluster + 1L;
    IF cluster > endCluster THEN cluster := LONG(FIRSTCLUSTER) END;
    IF GetFATentry(cluster) = LONG(FREECLUSTER) THEN
      PutFATentry(cluster,ENDOFCHAIN);
      lastAllocatedCluster := cluster;
      RETURN cluster
    END;
  UNTIL cluster = lastAllocatedCluster; (* full loop => no free cluster *)
  RAISE Disk.DiskError
END FindFreeCluster;

PROCEDURE NextSector(VAR cluster: Cluster; VAR sector: LBA; extendChain: BOOLEAN): BOOLEAN;
VAR next: Cluster;
BEGIN
  sector := sector + LONG(1);
  IF Fragment(sector) <> 0 THEN RETURN TRUE END;
  next := GetFATentry(cluster);
  IF next > endCluster THEN
    IF NOT extendChain THEN RETURN FALSE END;
    next := FindFreeCluster();
    PutFATentry(cluster, next);
  END;
  cluster := next;
  RETURN TRUE
END NextSector;

(* Follows a chain of clusters,
   updates cluster and sector, and extends the chain of clusters if reaching its end.
   Raises DiskError if the number of clusters to skip exceeds the file's number of clusters.
 *)
PROCEDURE SkipSectors(VAR cluster: Cluster; VAR sector: LBA; nbSectors: LONGINT);
VAR clustersToSkip: LONGINT;
    previous : Cluster;
    remainingFragments : LONGINT;
    sectorsPerClusterL : LONGINT;
BEGIN
  remainingFragments := LONG(sectorsPerCluster - Fragment(sector));
  IF nbSectors < remainingFragments THEN (* stay in this cluster *)
    sector := sector + nbSectors;
    RETURN
  END;
  (* else advance to next Cluster *)
  sector    := sector    + remainingFragments;
  nbSectors := nbSectors - remainingFragments;
  previous  := cluster;
  cluster   := GetFATentry(previous);
  sectorsPerClusterL := LONG(sectorsPerCluster);
  WHILE nbSectors >= sectorsPerClusterL DO
    previous  := cluster;
    cluster   := GetFATentry(previous); (* raises DiskError when trying to go after end of chain *)
    nbSectors := nbSectors - sectorsPerClusterL;
    sector    := sector    + sectorsPerClusterL;
  END;
  IF cluster > endCluster THEN (* cluster is absent, only allocate one if final sector reached *)
    IF nbSectors <> LONG(0) THEN RAISE Disk.DiskError END;
    cluster := FindFreeCluster();
    PutFATentry(previous, cluster);
  END;
  sector := sector + nbSectors;
END SkipSectors;

PROCEDURE InitFS;
CONST FAT32SIG = "FAT32   ";
VAR totalSectors: LBA;
    numberOfFATs: CARDINAL;
    bit, power2: CARDINAL;
BEGIN
  bufferFS := ADR(buffer); currentSector := LONG(FSINFOSECTOR); sectorDirty := FALSE;
  ReadFS(LONG(BOOTSECTOR));
  WITH buffer.boot DO
    numberOfFATs     := ORD(MiscBytes1[10H]);
    IF (BootSignature <> 0AA55H)
    OR (FileSysType   <> FAT32SIG)
    OR (numberOfFATs  <> 2) THEN
      RAISE Disk.DiskError
    END;
    sectorsPerCluster:= ORD(FirstBytes[0DH]);
    FATregion        := LONG(ReservedSectors);
    totalSectors     := TotalSectors;
    sectorsPerFAT    := SectorsPerFAT;
    firstRootCluster := FirstRootCluster;
    dataRegion       := FATregion + sectorsPerFAT + sectorsPerFAT;
    endCluster       := (totalSectors-dataRegion) DIV LONG(sectorsPerCluster);
  END;
  bit := 0; power2 := 1; fragmentMask := {};
  REPEAT (* calculate a bitmask to avoid MOD sectorsPerCluster *)
    INCL(fragmentMask, bit); INC(bit); power2 := 2 * power2
  UNTIL power2 = sectorsPerCluster;

  ReadFS(LONG(FSINFOSECTOR));
  lastAllocatedCluster:= buffer.info.lastAllocatedCluster;
  IF lastAllocatedCluster < LONG(FIRSTCLUSTER) THEN
    lastAllocatedCluster := LONG(FIRSTCLUSTER)
  END;
END InitFS;

PROCEDURE UnmountFS;
BEGIN
  ReadFS(LONG(FSINFOSECTOR));
  buffer.info.lastAllocatedCluster := lastAllocatedCluster;
  WriteFS;
END UnmountFS;

BEGIN
  InitFS
END NEWFAT32.                                                                         
