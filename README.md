# Turbo-Modula-2-Reloaded

This is a Modula-2 system (operating system + compiler + editor) for tiny microcomputers with 64 KB ram : it has a 16-bit address space.

Despite being issued from a reverse-engineering of Borland Turbo Modula-2 for CP/M, it has been re-engineered to be run on any platform, provided that the bytecode interpreter is ported to that platform. So, the system runs in a virtual machine running MCode, and this virtual machine is available on several real hardware: the main target currently is an 8-bit AVR with external ram memory (ATmega162, see V-M8 microcomputer), but the system can also be run on nearly every modern platform (eg. Linux) thanks to a virtual machine written in standard C.

The Modula-2 system gets rid of its CP/M roots thanks to the introduction of a FAT32 filesystem, support of UTF-8 encoding and extended ANSI/Xterm terminal. As such, it becomes a pedagogical human-size system that people can understand in depth.

TRY IT:

1. Download the virtual machine for Linux and compile it (make). It should work without modification on Linux, Android (in Termux), Windows (with Cygwin).

2. Download the m2.dsk in the same directory as the virtual machine interpreters, it is an image of a FAT32 filesystem with Turbo Modula-2 Reloaded pre-installed in it. You can check the contents of this image:

- file m2.dsk reveals it has 128 reserved sectors (the system image is installed in the reserved sectors), apart from this it is a normal FAT32 filesystem.
- you can access the contents with the mtools on Linux, or mount this disk image (e.g sudo mount -o loop m2.dsk /mnt). For convenience, this repository has all the files of this disk.

3. Start the virtual machine, telling it to boot on the disk image:
./m2_disk m2.dsk

4. Try some examples:
- dir
- cd examples
- dir
- cd rushhour
- rushhour <level.001  (NB: this is a RushHour puzzle solver written in Modula-2, it will surely be way too fast on your PC, so let's complicate things with the following)
- cd ..
- cd interp
- mcode rushhour (mcode is a Modula-2 bytecode interpreter written in Modula-2, so you are running the rushhour solver's bytecode in an interpreter that is itself interpreted by the virtual machine)
- cd ..
- e hello.mod (time to write your own helloworld program: answer Y to create a new file, and type the following before saving and exiting with F10 :
MODULE Hello;
BEGIN
  WRITELN("Hello world!")
END Hello.
- c hello.mod
- hello

or have a look at a small demonstration video: https://youtu.be/2DDvGZ8hrq8

STATUS:
This is not the publicly released version yet, it lacks documentation and I intend to deliver a new shell with the spirit of Midnight Commander.
It's not finished also because there are a few modules from the original Turbo Modula-2 that I haven't decompiled yet (it's a lengthy manual process), and I would like to give all modules in source form so that people can change or recompile them.
However it's already fully functional, I am currently enjoying solving the Advent of Code puzzles with it.
LONGREAL support has just been added in the VM for Linux (not in the AVR version though), so only IOTRANSFER is unimplemented now.
