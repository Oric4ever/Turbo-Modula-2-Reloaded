IMPLEMENTATION MODULE Files;
 FROM SYSTEM  IMPORT ADR, MOVE, FILL;
 FROM STORAGE IMPORT ALLOCATE, DEALLOCATE;
 IMPORT FATDIR;
 FROM Disk IMPORT LBA;
 FROM FATDIR IMPORT EntryNameAndType, Build83Name, BaseName, Extension, FullName;
 FROM NEWFAT32 IMPORT Cluster, ReadFragment, NextSector, WriteFragment, SkipSectors, Fragment;
 FROM FileDesc IMPORT File, FileDescriptor, FILEMARKER, FindFile, InitFile, ReadBuffer;

 (* for debugging : *) IMPORT Terminal;

 TYPE FILE = POINTER TO FileDescriptor;
 TYPE ERROR = (USEERROR, STATUSERROR, ENDERROR, DEVICEERROR, DISKFULL);

 CONST EXT = "EXT";

 PROCEDURE Error(f: FILE; error: ERROR);
 VAR msgBuffer: ARRAY [0..37] OF CHAR;
     ptr: POINTER TO ARRAY [0..15] OF CHAR;
 BEGIN
   msgBuffer := "While processing file ";
   ptr := ADR(msgBuffer[22]);
   GetName(f, ptr^);
   CASE error OF
   | ENDERROR    : RAISE EndError, msgBuffer
   | DEVICEERROR : RAISE DeviceError, msgBuffer
   | DISKFULL    : RAISE DiskFull, msgBuffer
   END;
 END Error;

 PROCEDURE CheckFile(f: FILE);
 BEGIN
   IF (f = NIL) OR (f^.marker <> FILEMARKER) THEN
     RAISE StatusError, "Processing unopened file"
   END;
 END CheckFile;

 (* $[- keep procedure names *)

 PROCEDURE GetName(f: FILE; VAR name: ARRAY OF CHAR);
 VAR filename: ARRAY [0..11] OF CHAR;
 VAR i: CARDINAL;
 VAR n: CARDINAL;
 VAR char: CHAR;
 BEGIN
   CheckFile(f);
   n := 0; i := 0;
   REPEAT
     IF i = 8 THEN filename[n] := '.'; INC(n) END;
     char := f^.entry.desc.nameAndType.fullName[i];
     IF char <> ' ' THEN filename[n] := char; INC(n) END;
     INC(i);
   UNTIL i > 11;
   name := filename;
 END GetName;

 PROCEDURE NextFileSector(f: FILE; extend: BOOLEAN);
 VAR dummy: BOOLEAN;
 BEGIN
   dummy := NextSector(f^.currCluster, f^.currentSect, extend);
 END NextFileSector;


 (* Read bytes (up to nbytes) in a file.
    Corner cases to test:
    pos =    y, bufpos =   y,    fileSize = z,   nbytes = 0      =>   0 byte  read      OK
    pos =    0, bufpos =   0,    fileSize = 0,   nbytes = x      =>   0 byte  read      OK
    pos =    0, bufpos =   0,    fileSize = y,   nbytes = x<y    =>   x bytes read      OK
    pos =    y, bufpos =   y,    fileSize = y,   nbytes = x      =>   0 byte  read      OK
    pos =  512, bufpos =   0,    fileSize > 512, nbytes = 1      =>   1 byte  read      OK
    pos =  512, bufpos = 512,    fileSize > 512, nbytes = 1      =>   1 byte  read      OK
    pos =    1, bufpos =   1,    fileSize = 512, nbytes = 511    => 511 bytes read      OK, index = 512
 *)
 PROCEDURE ReadBytes(f: FILE; buf: ADDRESS; nbytes: CARDINAL): CARDINAL;
 VAR bytesInBuffer : CARDINAL;
 VAR remainingBytes: LONGINT;
 VAR bytesToRead   : CARDINAL;
 VAR dummy         : BOOLEAN;
 BEGIN
   CheckFile(f);
   remainingBytes := f^.entry.desc.fileSize - f^.pos; (* Caution: can it be negative ? *)

   (* limit nbytes to what the file contains *)
   IF LONG(nbytes) > remainingBytes THEN nbytes := CARD(remainingBytes) END;
   (* so now nbytes <= remainingBytes, we won't exceed the file's end *)

   bytesInBuffer  := f^.bufferEnd - f^.ptr;
   IF nbytes <= bytesInBuffer THEN (* enough bytes in buffer *)
     MOVE(f^.ptr, buf, nbytes);
     f^.pos := f^.pos + LONG(nbytes);
     INC(f^.ptr, nbytes);
     RETURN nbytes;
   END;
   (* not enough bytes in buffer, transfer these buffer bytes *)
   MOVE(f^.ptr, buf, bytesInBuffer);
   INC(buf, bytesInBuffer);
   f^.pos      := f^.pos + LONG(bytesInBuffer);
   f^.ptr      := f^.bufferEnd;
   bytesToRead := nbytes - bytesInBuffer;
   (* now there are 0 bytes remaining in the buffer, we need to refill it *)
   Flush(f); (* in case some bytes were written *)
   WHILE bytesToRead >= 512 DO (* need at least a full sector *)
     NextFileSector(f, FALSE); (* no worry, we know we won't exceed file's end *)
     ReadFragment(f^.currCluster, Fragment(f^.currentSect), buf); (* direct transfer *)
     INC(buf, 512); DEC(bytesToRead, 512);
     f^.pos := f^.pos + LONG(512);
   END;
   IF bytesToRead <> 0 THEN
     (* read last sector in buffer *)
     NextFileSector(f, FALSE);
     ReadBuffer(File(f));
     MOVE(ADR(f^.buffer), buf, bytesToRead);
     INC(f^.ptr, bytesToRead);
     f^.pos   := f^.pos + LONG(bytesToRead);
   END;
   RETURN nbytes;
 END ReadBytes;

 PROCEDURE WriteBytes(f: FILE; buf: ADDRESS; nbytes: CARDINAL);
 VAR roomInBuffer : CARDINAL;
 VAR bytesToWrite : CARDINAL;
 BEGIN
   CheckFile(f);
   roomInBuffer := f^.bufferEnd - f^.ptr;
   IF roomInBuffer <> 0 THEN
     f^.bufferDirty := TRUE;
     IF nbytes <= roomInBuffer THEN (* enough room in buffer *)
       MOVE(buf, f^.ptr, nbytes);
       INC(f^.ptr, nbytes);
       f^.pos := f^.pos + LONG(nbytes);
       RETURN
     END;
     (* otherwise, start by filling the current buffer *)
     MOVE(buf, f^.ptr, roomInBuffer);
     DEC(nbytes, roomInBuffer);
     INC(buf,    roomInBuffer);
     f^.pos := f^.pos + LONG(roomInBuffer);
   END;
   (* buffer is now full *)
   f^.ptr := f^.bufferEnd;
   Flush(f);
   WHILE nbytes >= 512 DO           (* do full sectors transfers first *)
     NextFileSector(f, TRUE);
     MOVE(buf, ADR(f^.buffer), 512);
     DEC(nbytes, 512); INC(buf, 512);
     f^.pos := f^.pos + LONG(512);
     f^.bufferDirty := TRUE;
     Flush(f);
   END;
   IF nbytes <> 0 THEN
     NextFileSector(f, TRUE);
     (* the buffer needs to be read before being partially modified *)
     (* TODO: avoid to read the buffer if the write will go further than file's end *)
     ReadBuffer(File(f));
     MOVE(buf, ADR(f^.buffer), nbytes);
     f^.bufferDirty := TRUE;
     f^.ptr := ADR(f^.buffer) + nbytes;
     f^.pos := f^.pos + LONG(nbytes);
   END;
 END WriteBytes;


 PROCEDURE Flush(f: FILE);
 VAR size: LONGINT;
 BEGIN
   IF f^.bufferDirty THEN
     WriteFragment(f^.currCluster, Fragment(f^.currentSect), ADR(f^.buffer));
     f^.bufferDirty := FALSE;
     IF f^.pos > f^.entry.desc.fileSize THEN f^.entry.desc.fileSize := f^.pos END;
   END;
 END Flush;

 (* $[- keep procedure names *)

 PROCEDURE Open(VAR f: FILE; name: ARRAY OF CHAR): BOOLEAN;
 VAR file : File;
 BEGIN
   NEW(file);
   Build83Name(name,EXT,FALSE,file^.entry.desc.nameAndType);
   IF FindFile(file) THEN
     InitFile(file);
     f := ADDRESS(file);
     RETURN TRUE
   END;
   DISPOSE(file);
   RETURN FALSE
 END Open;

 PROCEDURE Create(VAR f: FILE; name: ARRAY OF CHAR);
 VAR file : File;
 BEGIN
   NEW(file);
   Build83Name(name,EXT,FALSE,file^.entry.desc.nameAndType);
   IF FindFile(file) THEN FATDIR.DeleteEntry(file^.entry) END;
   IF NOT FATDIR.CreateEntry(file^.entry.desc.nameAndType, file^.entry) THEN
     DISPOSE(file);
     RAISE DiskFull
   END;

   InitFile(file);
   f := ADDRESS(file);
 END Create;

 PROCEDURE Close(VAR f: FILE);
 BEGIN
   IF (f <> NIL) AND (f^.marker = FILEMARKER) THEN
     Flush(f);
     FATDIR.UpdateEntry(f^.entry);
     DISPOSE(f);
   END;
 END Close;

 PROCEDURE Delete(VAR f: FILE);
 BEGIN
   CheckFile(f);
   FATDIR.DeleteEntry(f^.entry);
   DISPOSE(f);
 END Delete;

 PROCEDURE Rename(VAR f: FILE; name: ARRAY OF CHAR);
 VAR newName   : EntryNameAndType;
 VAR destEntry : FATDIR.Entry;
 BEGIN
   CheckFile(f);
   Build83Name(name,EXT,FALSE,newName);
   FATDIR.InitFind(newName.fullName);
   IF FATDIR.FindNextMatch(destEntry) THEN FATDIR.DeleteEntry(destEntry) END;
   f^.entry.desc.nameAndType.fullName := newName.fullName;
   FATDIR.UpdateEntry(f^.entry);
   Close(f);
 END Rename;

 PROCEDURE NoTrailer(f: FILE);
 BEGIN
 END NoTrailer;

 PROCEDURE FileSize(f: FILE): LONGINT;
 BEGIN
   CheckFile(f);
   IF f^.pos > f^.entry.desc.fileSize THEN f^.entry.desc.fileSize := f^.pos END;
   RETURN f^.entry.desc.fileSize
 END FileSize;

 PROCEDURE EOF(f: FILE): BOOLEAN;
 BEGIN
   CheckFile(f);
   RETURN f^.pos >= f^.entry.desc.fileSize;
 END EOF;


 VAR byteBuf: ARRAY [0..0] OF BYTE;

 PROCEDURE ReadByte(f: FILE; VAR ch: BYTE);
 VAR ptr: POINTER TO ARRAY [0..0] OF BYTE;
 BEGIN
   IF (f <> NIL) AND (f^.marker = FILEMARKER) THEN
     IF f^.pos < f^.entry.desc.fileSize THEN
       ptr := f^.ptr;
       IF ptr <> f^.bufferEnd THEN
         ch     := ptr^[0];
         f^.ptr := ADDRESS(ptr) + 1;
         f^.pos := f^.pos + LONG(1);
         RETURN
       END;
     END;
   END;
   (* otherwise use ReadBytes to refill the buffer *)
   IF ReadBytes(f, ADR(byteBuf), 1) <> 1 THEN Error(f, ENDERROR) END;
   ch := byteBuf[0];
 END ReadByte;

 PROCEDURE ReadWord(f: FILE; VAR w : WORD);
 VAR ptr : ADDRESS;
 BEGIN
   CheckFile(f);
   IF f^.pos + LONG(1) < f^.entry.desc.fileSize THEN
     ptr := f^.ptr;
     IF ptr + 1 < f^.bufferEnd THEN
       w      := ptr^;
       f^.ptr := ptr + 2;
       f^.pos := f^.pos + LONG(2);
       RETURN
     END;
   END;
   (* else use ReadRec to refill the buffer *)
   ReadRec(f, w);
 END ReadWord;

 PROCEDURE ReadRec(f: FILE; VAR rec: ARRAY OF WORD);
 BEGIN
   IF ReadBytes(f, ADR(rec), (HIGH(rec)+1)*2 ) <> (HIGH(rec)+1)*2 THEN
     Error(f, ENDERROR)
   END;
 END ReadRec;

 PROCEDURE WriteByte(f: FILE; ch: BYTE);
 VAR ptr: POINTER TO ARRAY [0..0] OF BYTE;
 BEGIN
   IF (f <> NIL) AND (f^.marker = FILEMARKER) THEN
     ptr := f^.ptr;
     IF ADDRESS(ptr) < f^.bufferEnd THEN
       f^.bufferDirty := TRUE;
       ptr^[0]        := ch;
       f^.ptr         := ADDRESS(ptr) + 1;
       f^.pos         := f^.pos + LONG(1);
       RETURN
     END;
   END;
   byteBuf[0] := ch;
   WriteBytes(f, ADR(byteBuf), 1);
 END WriteByte;

 PROCEDURE WriteWord(f: FILE;  w: WORD);
 BEGIN
   CheckFile(f);
   IF f^.ptr < f^.bufferEnd - 1 THEN
     f^.bufferDirty := TRUE;
     f^.ptr^        := w;
     f^.pos         := f^.pos + LONG(2);
     INC(f^.ptr,2);
     RETURN
   END;
   WriteRec(f, w);
 END WriteWord;

 PROCEDURE WriteRec(f: FILE; VAR rec: ARRAY OF WORD);
 BEGIN
   WriteBytes(f, ADR(rec), (HIGH(rec)+1)*2 );
 END WriteRec;

 PROCEDURE NextPos(f: FILE): LONGINT;
 BEGIN
   CheckFile(f);
   RETURN f^.pos
 END NextPos;

 PROCEDURE SetPos(f: FILE; pos: LONGINT);
 VAR bufOffset: CARDINAL;
 VAR sector: LONGINT;
 VAR changeBuffer: BOOLEAN;
 BEGIN
   CheckFile(f);
   IF pos > FileSize(f) THEN Error(f, ENDERROR) END;
   bufOffset := CARD(pos MOD LONG(512));
   sector    :=      pos DIV LONG(512);
   IF (bufOffset = 0) AND (sector <> LONG(0)) AND (sector <> f^.currentSect) THEN
     bufOffset := 512;
     sector    := sector - LONG(1);
   END;
   IF sector <> f^.currentSect THEN
     Flush(f);
     IF sector > f^.currentSect
     THEN sector := sector - f^.currentSect (* follow chain from current cluster *);
     ELSE f^.currentSect := LONG(0); f^.currCluster := FATDIR.StartCluster(f^.entry) (* follow chain from start *)
     END;
     SkipSectors(f^.currCluster, f^.currentSect, sector);
     IF bufOffset <> 512 THEN ReadBuffer(File(f)) END;
   END;
   f^.ptr := ADR(f^.buffer) + bufOffset;
   f^.pos := pos;
 END SetPos;

 (* $[+ remove procedure names *)

 PROCEDURE ResetSys( );
 BEGIN
 END ResetSys;

END Files.
