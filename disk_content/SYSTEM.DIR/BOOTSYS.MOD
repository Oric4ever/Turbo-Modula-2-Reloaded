MODULE BootSys;
FROM SYSTEM IMPORT ADR, ADDRESS, MOVE, BIOS;
FROM RunSys IMPORT SystemImage;

BEGIN
  MOVE(ADR(SystemImage), ADDRESS(0300H), SIZE(SystemImage));
  BIOS(0,0)
END BootSys.                                                               