SOURCES=mcode.c bdos.c bios.c
CFLAGS=-g -O3

m2: $(SOURCES)
	gcc $(CFLAGS) -o $@ -DTRACE_ALL=0 -DEMULATED_DISK=1 $^

clean:
	rm m2 m2_trace m2_disk m2_disk_trace
