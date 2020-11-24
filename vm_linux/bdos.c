#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <unistd.h>
#include <termios.h>
#include "mcode.h"

#define NON_BLOCKING 1

static int dma_offset;
static int usernum = 0;
static int current_drive = 'J'-'A';
extern FILE *tracelog;

char kbhit(void)
{
  char c = 0;
  if (NON_BLOCKING) {
    struct timeval tv = { 0L, 10000L }; // 1/100th of a second
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(0, &fds);
    if (!select(1, &fds, NULL, NULL, &tv)) return 0;
  } 
  read(0, &c, sizeof(char));
//  fprintf(tracelog,"BDOS C_RAWIO [%c]\n",c);
  return c;
}

char *filename(int fcb)
{
    static char name[13];
    int len=8; while (mem[fcb+len]==' ') len--;
    int ext=3; while (mem[fcb+8+ext]==' ') ext--;
    if (ext<0) ext=0;
    for (int i=0; i<len; i++) name[i] = mem[fcb+i+1];
    if (ext) {
        name[len] = '.';
        for (int i=0; i<ext; i++) name[len+1+i] = mem[fcb+9+i];
        name[len+1+ext] = 0;
    } else name[len] = 0;
    return &name[0];
}

int file_open(int fcb, char *mode)
{
    char *name = filename(fcb);
//    fprintf(tracelog,"Open %s for %s\n", name, mode);
//    fprintf(tracelog,"FCB at %04x\n", fcb);
    FILE *fd = fopen(name,mode);
    if (fd) { 
//        for (int i=0; i<35; i++) fprintf(tracelog,"%02x ",mem[fcb+i]);
//        fprintf(tracelog,"\n");
        fseek(fd, 0L, SEEK_END);
        long size = ftell(fd);
        fclose(fd); 
        int extent = mem[fcb+12];
        int record = mem[fcb+32];
//        if ( (extent*128+record)*128L > size ) return -1;
        //mem[fcb+12] = mem[fcb+15] = mem[fcb+32] = 0;
        if (strcmp(name,"M2.OVR")==0) return extent==0 ? 2 : 3;
        else if (strcmp(name,"SHELL.MCD")==0) return 1;
        else if (strcmp(name,"SYSLIB.LIB")==3) return 3;
        else if (strcmp(name,"E.MOD")==0) return 2;
        else if (strcmp(name,"Q.MOD")==0) return 2;
        else if (strcmp(name,"E.$$$")==0) return 3;
        else if (strcmp(name,"C.@@@")==0) return 3;
        else if (strcmp(name,"Q.@@@")==0) return 3;
        else if (strcmp(name,"CARDQUEU.SYM")==0) return 3;
        else return 0; 
    } else return -1;
}

int file_size(int fcb)
{
    char *name = filename(fcb);
    FILE *fd = fopen(name,"r");
    if (fd) {
        fseek(fd, 0L, SEEK_END);
//        fprintf(tracelog,"End position : %ld\n",ftell(fd));
        int records = (ftell(fd)-1+127)/128;
        fclose(fd);
//        fprintf(tracelog,"Filesize of %s = %d\n ", name, records);
        mem[fcb+33] = records & 0xff;
        mem[fcb+34] = records >> 8;
    }
    return -1;  // always return error ?
}

int file_readrand(int fcb)
{
    FILE *fd = fopen(filename(fcb),"r");
    if (fd) {
        int record = mem[fcb+33] + 256*mem[fcb+34];
//        fprintf(tracelog,"Read %s record %d at %04X\n",filename(fcb),record,dma_offset);
//        fflush(tracelog);
        fseek(fd, record*128, SEEK_SET);
        fread(mem+dma_offset, 1, 128, fd);
        fclose(fd);
        return 0;
    } else return -1;
}

int file_writrand(int fcb)
{
    FILE *fd = fopen(filename(fcb),"r+");
    if (fd) {
        int record = mem[fcb+33] + 256*mem[fcb+34];
//        fprintf(tracelog,"Write %s record %d from %04X\n",filename(fcb),record,dma_offset);
//        fflush(tracelog);
        fseek(fd, record*128, SEEK_SET);
        fwrite(mem+dma_offset, 1, 128, fd);
        fclose(fd);
//        dma_offset += 128;
//        record ++;
//        mem[fcb+33] = record & 0xff;
//        mem[fcb+34] = record >> 8;
        return 0;
    } else return -1;
}

int file_delete(int fcb) { return unlink(filename(fcb)); }

int file_rename(int fcb)
{
    char oldname[13];
    strcpy(oldname, filename(fcb));
    return rename(oldname, filename(fcb+16));
}

byte bdos(word fct, word param) {
    int c;
    /* just to remove differences on stack */
    STACK[-2] = 0xD806;
    
    fprintf(tracelog,"BDOS function %d\n",fct);
    switch (fct) {
    case  0:/* RESET */ exit(0);
    case  1:/* C_READ    */ 
                        c=getchar();
//                        fprintf(tracelog,"BDOS C_READ : [%c]\n",c);
                        return mem[0x0302] = c==0x0A ? 0x0D : c;
    case  2:/* C_WRITE   */ putchar(param & 0xff); break;
    case  6:/* C_RAWIO   */ param &= 0xff; 
                            if (param==0xff) return kbhit();
                            else {
//                                fprintf(tracelog,"BDOS C_RAWIO %c\n",param);
                                putchar(param); fflush(stdout);
                            }
                            break;
    case 15:/* F_OPEN    */ return file_open(param,"r");
    case 16:/* F_CLOSE   */ return 0;
    case 19:/* F_DELETE  */ return file_delete(param);
    case 22:/* F_MAKE    */ return file_open(param,"w");
    case 23:/* F_RENAME  */ return file_rename(param);
    case 25:/* DRV_GET   */ return current_drive;
    case 26:/* F_DMAOFF  */ dma_offset = param; break;
    case 29:/* DRV_ROVEC */ return 0;
    case 32:/* F_USERNUM */ if ((param & 0xff)==0xff) return usernum;
                            else return usernum=(param & 0xff);
    case 33:/* F_READRAND*/ return file_readrand(param);
    case 34:/* F_WRITRAND*/ return file_writrand(param);
    case 35:/* F_SIZE    */ return file_size(param);
    default: fprintf(tracelog,"BDOS fct %d not implemented\n",fct);
    }
    return 0;
}

