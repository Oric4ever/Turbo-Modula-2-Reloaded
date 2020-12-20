This is the (development version) virtual machine for Linux. 

It is really ugly because it evolved at the same time as the Turbo Modula-2 reverse engineering,
so it started from the aim to run the original Turbo Modula-2 for CP/M without requiring Z80 emulation,
but still there are some dependencies to the Z80 hardware in the Turbo Modula-2 kernel (such as support for the exceptions).

So, some hooks are provided to emulate at the procedure level a number of Z80 routines in the original Turbo Modula-2,
these hooks are not used any more when running Turbo Modula-2 Reloaded, a re-engineering of Turbo Modula-2.

Same thing for the CP/M BDOS emulation, it is needed for the original Turbo Modula-2, but not for Turbo Modula-2 Reloaded.
Finally, the BIOS emulation has now both calls for the old CP/M BIOS calls, and new calls for a new reduced Hardware Abstraction Layer.

HOW TO RUN TURBO MODULA-2 RELOADED:

Download the small SD card image (FAT32 format) that is provided at the root of this repository, and put it in the same directory as this virtual machine.
Run the m2 executable in a VT100/ANSI compatible terminal (or better, an Xterm color terminal), the Turbo Modula-2 Reloaded will run.

A few commands to know :
- CD dir   changes to dir directory
- DIR      shows the contents of current directory
- ROOT     returns to root directory
- E file   edits file
- C module compiles a module (extension .MOD or .DEF must be specified)

Sorry, I will provide a documentation soon... but what you can first rely on Turbo Modula-2's user manual, most of it is still usable...
