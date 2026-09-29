# Alone in the Dark — repository-level tools.
# The game has no host renderer: host code extracts and inspects original data.
# The Amiga build is the product: `. amiga/env.sh && make -C amiga`.

ARCHIVE ?= tmp/AloneInTheDark.img_.sit
RUNTIME_DATA ?= tmp/runtime-data
SEGMENTS ?= tmp/segments

.PHONY: all help todo amiga extract-original-data segments m68k-sweep lowmem-scan entrypoints-check trap-census host-tests mac-trap-map regression a5world-check lowmem-check

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
	@echo "  make trap-census             generate tmp/trap-census.md"
	@echo "  make host-tests              run static-analysis fixtures"
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
	@python3 tools/m68k_lowmem.py '$(RUNTIME_DATA)/Alone In The Dark'

# cxmon names are generated locally, never vendored.
tmp/trap_names.lua: tools/gen_trap_names.py
	@python3 tools/gen_trap_names.py

trap-census: tmp/trap_names.lua
	@python3 tools/trap_census.py --selftest
	@python3 tools/trap_census.py '$(RUNTIME_DATA)/Alone In The Dark'

mac-trap-map:
	@python3 tools/mac_trap_map.py '$(RUNTIME_DATA)/Alone In The Dark'

regression:
	@./amiga/regression.sh resource-exit
	@./amiga/regression.sh file-write
	@./amiga/regression.sh file-read
	@./amiga/regression.sh window-core
	@./amiga/regression.sh boot
	@./amiga/regression.sh resource-read

a5world-check:
	@python3 tools/a5world_check.py "$(RUNTIME_DATA)/Alone In The Dark"

lowmem-check:
	@python3 tools/check_lowmem.py --resource "$(RUNTIME_DATA)/Alone In The Dark"

host-tests:
	@python3 tools/build_overlay.py --check
	@python3 tools/test_native_resource_exit.py
	@python3 tools/check_resource_map.py
	@python3 tools/check_resource_source.py
	@python3 tools/check_resource_writer.py
	@python3 tools/check_resource_directory.py
	@python3 tools/check_resource_publication.py
	@python3 tools/test_install_layout.py
	@python3 tools/test_installed_metadata.py
	@python3 tools/check_file_metadata.py
	@python3 tools/check_file_sharing.py --selftest
	@python3 tools/check_file_mutations.py --selftest
	@python3 tools/check_file_write_buffer.py
	@python3 tools/check_file_queries.py --selftest
	@python3 tools/check_file_read_cache.py
	@python3 tools/check_mac_files.py
	@python3 tools/check_file_reference.py --selftest
	@python3 tools/check_pak_idle.py --selftest
	@python3 tools/check_font_lookup.py --selftest
	@python3 tools/check_resload_access.py
	@python3 tools/check_mac_heap.py
	@python3 tools/check_lowmem.py --selftest
	@python3 tools/a5world_check.py --selftest
	@python3 tools/regression_result.py --selftest
	@python3 tools/fb_to_png.py --selftest
	@python3 tools/mac_trap_map.py --selftest
	@python3 tools/mac_trap_report.py --selftest
	@python3 tools/trap_census.py --selftest
	@python3 tools/m68k_lowmem.py --selftest
	@python3 tools/m68k_sweep.py --selftest

entrypoints-check:
	@python3 tools/code0_entrypoints.py '$(SEGMENTS)/CODE_0' --check ghidra_scripts/entrypoints.csv

# Compatibility spelling for the earlier CODE 1-only check.
startup-lowmem-check: lowmem-check
