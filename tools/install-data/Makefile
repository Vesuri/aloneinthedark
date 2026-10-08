# Run from anywhere: make -C tools/install-data [amiga]
# Source amiga/env.sh before building the Amiga binary.
ROOT := ../..
BUILD ?= $(ROOT)/build/install-data
CC ?= cc
CFLAGS ?= -O2 -g
WARN = -std=c99 -Wall -Wextra -Werror
SOURCES = install.c sha256.c
HEADERS = io.h sha256.h sit13_tables.h originals.h arsenic.h
AMIGA_CC = m68k-amiga-elf-gcc
AMIGA_NM = $(dir $(shell command -v $(AMIGA_CC)))../m68k-amiga-elf/bin/nm
AMIGA_FLAGS = -std=c99 -O2 -g -m68020 -mtune=68020 -msoft-float -nostdlib -fno-builtin -fno-tree-loop-distribute-patterns -fstack-usage -Wall -Wextra -Wno-volatile-register-var -DINSTALL_AMIGA
AMIGA_FLAGS += $(EXTRA_AMIGA_FLAGS)
.PHONY: all amiga test
all: $(BUILD)/AitdInstallData
$(BUILD):
	mkdir -p $@
$(BUILD)/AitdInstallData: $(SOURCES) io_unix.c $(HEADERS) | $(BUILD)
	$(CC) $(CFLAGS) $(WARN) $(SOURCES) io_unix.c -o $@
amiga: $(BUILD)/AitdInstallData.exe
$(BUILD)/install.o: install.c $(HEADERS) Makefile | $(BUILD)
	$(AMIGA_CC) $(AMIGA_FLAGS) -c $< -o $@
$(BUILD)/sha256.o: sha256.c sha256.h io.h Makefile | $(BUILD)
	$(AMIGA_CC) $(AMIGA_FLAGS) -c $< -o $@
$(BUILD)/io_amiga.o: io_amiga.c io.h Makefile | $(BUILD)
	$(AMIGA_CC) $(AMIGA_FLAGS) -c $< -o $@
$(BUILD)/start.o: start.s | $(BUILD)
	$(AMIGA_CC) -m68020 -mtune=68020 -c $< -o $@
$(BUILD)/AitdInstallData.elf: $(BUILD)/start.o $(BUILD)/install.o $(BUILD)/sha256.o $(BUILD)/io_amiga.o
	$(AMIGA_CC) -nostdlib -m68020 -mtune=68020 -Wl,--emit-relocs,-Ttext=0,-e,_start,-Map=$(BUILD)/AitdInstallData.map $^ -o $@
	$(AMIGA_NM) -u $@ > $(BUILD)/undefined.txt
	@test ! -s $(BUILD)/undefined.txt
$(BUILD)/AitdInstallData.exe: $(BUILD)/AitdInstallData.elf
	elf2hunk $< $@ -s
test: all
	python3 test_install.py $(BUILD)/AitdInstallData
