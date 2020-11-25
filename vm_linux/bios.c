#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <termios.h>
#include "mcode.h"
#define IORESULT mem[0x0300]

#define NON_BLOCKING 1
#define TRACE 0

extern FILE *tracelog;
static FILE *disk_image;
static unsigned int lba_addr = 0;
static word dma_addr = 0xFD00;

int key_available(void)
{
  if (NON_BLOCKING) {
    struct timeval tv = { 0L, 10000L }; // 1/100th of a second
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(0, &fds);
    if (!select(1, &fds, NULL, NULL, &tv)) return 0;
  }
  return 0xFF;
}

byte bios(word fct, word param)
{
    char c;
    word offset, count;
    if (fct > 5) fprintf(tracelog,"BIOS fct %d !!\n",fct);
    switch (fct) {
        case 0: /* warm boot */
            printf("\nReboot ?\r\n");
            read(0, &c, sizeof(char));
            if (TRACE) fprintf(tracelog,"BIOS fct 0: warmboot\n");
            if (c=='y' || c=='Y') warm_boot();
            else exit(0);
            break;
        case 1: /* console status */
            return key_available();
        case 2: /* console input */
            read(0, &c, sizeof(char));
            if (TRACE) fprintf(tracelog,"BIOS fct 2: read char %c\n",c);
            return c;
        case 3: /* console output */ 
            putchar(param & 0xFF); fflush(stdout);
            if (TRACE) fprintf(tracelog,"%c",param);
            break;
        case 4: /* New read (partial) sector */
            lba_addr = *(long *)(mem+param);
            dma_addr = *(word *)(mem+param+4);
            offset   = *(word *)(mem+param+6);
            count    = *(word *)(mem+param+8);
            if (TRACE) fprintf(tracelog,"Read sector %d (new)\n",lba_addr);
            if (disk_image==NULL) perror("Trying to read image.dsk\n");
            if (fseek(disk_image, lba_addr*512L+offset, SEEK_SET)) return 1;
            if (fread(mem+dma_addr, 1, count, disk_image) != count) return 1;
            return 0;
        case 5: /* New write sector */
            lba_addr = *(long *)(mem+param);
            dma_addr = *(word *)(mem+param+4);
            if (TRACE) fprintf(tracelog,"Write sector %d\n",lba_addr);
            if (disk_image==NULL) perror("Trying to write image.dsk\n");
            if (fseek(disk_image, lba_addr*512L, SEEK_SET)) return 1;
            if (fwrite(mem+dma_addr, 512, 1, disk_image) != 1) return 1;
            return 0;
        case 8: /* select disc drive => select partition */
            break;
        case 9: /* select track number => high word of LBA sector */
            lba_addr = (param << 16) | (lba_addr & 0xffff);
            break;
        case 10:/* select sector number => low word of LBA sector */
            lba_addr = (lba_addr & 0xffff0000) | param;
            break;
        case 11:/* set "DMA" address => address of sector buffer */
            dma_addr = param;
            break;
        case 12:/* read sector */
            if (TRACE) fprintf(tracelog,"Read sector %d\n",lba_addr);
            if (disk_image==NULL) perror("Trying to read image.dsk\n");
            if (fseek(disk_image, lba_addr*512L, SEEK_SET)) return 1;
            if (fread(mem+dma_addr, 512, 1, disk_image) != 1) return 1;
            return 0;
        case 13:/* write sector */
            if (TRACE) fprintf(tracelog,"Write sector %d\n",lba_addr);
            if (disk_image==NULL) perror("Trying to write image.dsk\n");
            if (fseek(disk_image, lba_addr*512L, SEEK_SET)) return 1;
            if (fwrite(mem+dma_addr, 512, 1, disk_image) != 1) return 1;
            return 0;
        default:
            printf("Error, unknown bios function %d\n", fct);
    }
    return 0;
}

void init_bios(char *diskname)
{
    disk_image = fopen(diskname,"r+");
}
