SOURCES=mcode.c bdos.c bios.c

all: m2 m2_trace m2_disk m2_disk_trace

m2: $(SOURCES)
	gcc -g -o $@ -DTRACE_ALL=0 -DEMULATED_DISK=0 $^

m2_trace: $(SOURCES)
	gcc -g -o $@ -DTRACE_ALL=1 -DEMULATED_DISK=0 $^

m2_disk: $(SOURCES)
	gcc -g -o $@ -DTRACE_ALL=0 -DEMULATED_DISK=1 $^

m2_disk_trace: $(SOURCES)
	gcc -g -o $@ -DTRACE_ALL=1 -DEMULATED_DISK=1 $^

clean:
	rm m2 m2_trace m2_disk m2_disk_trace
