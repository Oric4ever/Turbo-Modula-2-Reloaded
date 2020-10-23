# Turbo-Modula-2-Reloaded

This is a Modula-2 system (operating system + compiler + editor) for tiny microcomputers with 64 KB ram : it has a 16-bit address space.

Despite being issued from a reverse-engineering of Borland Turbo Modula-2 for CP/M, it has been re-engineered to be run on any platform, provided that the bytecode interpreter is ported to that platform. So, the system runs in a virtual machine running MCode, and this virtual machine is available on several real hardware: the main target currently is an 8-bit AVR with external ram memory (ATmega162, see V-M8 microcomputer), but the system can also be run on nearly every modern platform (eg. Linux) thanks to a virtual machine written in standard C.

The Modula-2 system gets rid of its CP/M roots thanks to the introduction of a FAT32 filesystem, support of UTF-8 encoding and extended ANSI/Xterm terminal. As such, it becomes a pedagogical human-size system that people can understand in depth.
