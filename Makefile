# Alone in the Dark — repository-level tools.
# The game has no host renderer: host code extracts and inspects original data.
# The Amiga build is the product: `. amiga/env.sh && make -C amiga`.

ARCHIVE ?= tmp/AloneInTheDark.img_.sit
RUNTIME_DATA ?= tmp/runtime-data
SEGMENTS ?= tmp/segments

.PHONY: all help todo amiga extract-original-data segments m68k-sweep lowmem-scan entrypoints-check

all: help

help:
	@echo "Alone in the Dark — Macintosh 68k -> Amiga port"
	@echo
	@echo "  make todo                    what is open (docs/open-work.md + a live marker sweep)"
	@echo "  make amiga                   build amiga/out/Alone.exe (needs . amiga/env.sh)"
	@echo "  make extract-original-data   unpack ARCHIVE=$(ARCHIVE) into $(RUNTIME_DATA)"
	@echo "  make segments                dump the CODE resources into $(SEGMENTS)"
	@echo "  make m68k-sweep              68020-only instructions on reachable paths"
	@echo "  make lowmem-scan             reachable absolute Page-0 references"
	@echo "  make entrypoints-check       ghidra_scripts/entrypoints.csv matches CODE 0"
	@echo
	@echo "There is deliberately no host game build; the Amiga executable is the product."

# The pattern uses character classes (TOD[O] etc) so this Makefile does not match itself.
todo:
	@cat docs/open-work.md
	@echo
	@echo "=== live marker sweep (tracked, non-vendored) ==="
	@if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
	  hits=$$(git grep -nE '(TOD[O]|FIXM[E]|HAC[K]|XX[X])' -- \
	            ':!src/platform/amiga/framework' ':!docs' 2>/dev/null); \
	  if [ -n "$$hits" ]; then echo "$$hits"; else echo "none"; fi; \
	else echo "(not a git repo)"; fi

amiga:
	@$(MAKE) -C amiga

extract-original-data:
	@python3 tools/extract_original_data.py '$(ARCHIVE)' '$(RUNTIME_DATA)'

segments:
	@python3 tools/dump_resources.py '$(RUNTIME_DATA)/Alone In The Dark' '$(SEGMENTS)' CODE

m68k-sweep:
	@cd tools && python3 m68k_sweep.py --selftest >/dev/null && python3 m68k_sweep.py '../$(SEGMENTS)'

lowmem-scan:
	@cd tools && python3 m68k_lowmem.py '../$(SEGMENTS)'

entrypoints-check:
	@python3 tools/code0_entrypoints.py '$(SEGMENTS)/CODE_0' --check ghidra_scripts/entrypoints.csv
