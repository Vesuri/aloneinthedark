# Alone in the Dark — Amiga cross-build (m68k-amiga-elf-gcc)
#
# Usage (from amiga/ with the toolchain on PATH via `. env.sh`):
#   make                 build out/Alone.exe
#   make clean           remove obj/ and out/
#   make PROBES=1        + the timing probes (diag_run.sh needs this)
#   make FPSCOUNT=1      the HONEST framerate build: one counter, no probe instrumentation
#   make VERIFY=1 PROBES=1  run every asm twin against its C oracle on each call
#   make FILLWATCH=1     rolling audit of the planar back buffer against the chunky Mac surface
#   ./run.sh             boot in FS-UAE (CTRL + left mouse button quits)
#   ./debug.sh           source-level debug via the FS-UAE GDB stub
#   ./diag_run.sh [secs] headless probe run (needs PROBES=1)
#
# Builds the native runtime and Macintosh service layer; see docs/development.md.
# Inherited from the Vette! port; its game-specific diagnostic switches were not carried over.
#
# ⚠⚠ `make clean` BEFORE any PROBES=1 build and AFTER editing a widely-included header.
# This Makefile tracks neither the flag nor header deps, so a partial rebuild links stale
# objects into a WORKING-BUT-WRONG binary with silent runtime breakage.  On the prior ports
# that trap cost multiple debugging sessions: treat any unexplained regression right after a
# header edit or a PROBES toggle as a stale build FIRST.  (docs/development.md)
#
# Structure: explicit/wildcarded source lists mapped to objects in a flat obj/ (keyed by
# basename — KEEP BASENAMES UNIQUE across the source trees), sources located via vpath.

OUT      = out/Alone
CC       = m68k-amiga-elf-gcc
AS       = m68k-amiga-elf-as
VASM     = vasmm68k_mot
OBJDUMP  = m68k-amiga-elf-objdump
SDKDIR   = $(abspath $(dir $(shell which $(CC)))../m68k-amiga-elf/sys-include)
SUPPORT  = $(abspath $(dir $(shell which $(CC)))../../support)
REPO      = ..
AMIGA_SRC = $(REPO)/src/platform/amiga
$(shell mkdir -p obj out)

# ---------------------------------------------------------------------------
# Sources
# ---------------------------------------------------------------------------
# C++: the vendored dA JoRMaS hardware framework, then this port's Amiga backend, the shared
# platform layer, and main().  The framework list is explicit because it is fixed and vendored.
FRAMEWORK_CXX_SRCS := \
    $(AMIGA_SRC)/framework/AmigaHardware.cpp \
    $(AMIGA_SRC)/framework/Bitmap.cpp \
    $(AMIGA_SRC)/framework/CopperList.cpp \
    $(AMIGA_SRC)/framework/Palette.cpp \
    $(AMIGA_SRC)/framework/Sprite.cpp \
    $(AMIGA_SRC)/framework/Util.cpp
CXX_SRCS := $(FRAMEWORK_CXX_SRCS) \
    $(AMIGA_SRC)/GCCRuntime.cpp \
    $(wildcard $(AMIGA_SRC)/*.cpp) \
    $(wildcard $(REPO)/src/platform/*.cpp) \
    $(wildcard $(REPO)/src/mac/*.cpp) \
    $(wildcard $(REPO)/src/main.cpp)
# GCCRuntime.cpp is named explicitly AND matched by the wildcard above; de-duplicate.
CXX_SRCS := $(sort $(CXX_SRCS))

CORE_C_SRCS := \
    $(wildcard $(REPO)/src/mac/*.c) \
    $(wildcard $(REPO)/src/platform/*.c)

# Support runtime (freestanding CRT: program entry, memset…). Game CODE and
# resources are deliberately not link inputs; the executable reads the original
# raw Macintosh resource fork from disk before hardware takeover.
SUPPORT_C_SRCS := $(SUPPORT)/gcc8_c_support.c
ASM_SRCS       := $(SUPPORT)/gcc8_a_support.s $(wildcard $(AMIGA_SRC)/*.s)

# Framework hand-written m68k asm (Motorola syntax, assembled by vasm -> ELF).  The matching
# GCC register-marshalling bridges live under `#if defined(ASSEMBLER) && !defined(__SASC)` in
# the corresponding framework .cpp.
FRAMEWORK_ASM_SRCS := \
    $(AMIGA_SRC)/framework/UtilAssembler.s \
    $(AMIGA_SRC)/framework/AmigaHardwareAssembler.s \
    $(AMIGA_SRC)/framework/BitmapAssembler.s \
    $(AMIGA_SRC)/framework/CopperListAssembler.s

# ---------------------------------------------------------------------------
# Build flags / feature toggles
# ---------------------------------------------------------------------------
# ⭐ THE ASM-TWIN SEAM TEMPLATE.  Every hand-asm twin gets one of these as it is written:
#
#   ifneq ($(<NAME>_C),1)
#   EXTRA_DEFINES += -DAITD_<NAME>_ASM
#   ifdef VERIFY
#   EXTRA_DEFINES += -DAITD_<NAME>_VERIFY
#   endif
#   endif
#
# `make <NAME>_C=1` falls back to the clean-C oracle; `make VERIFY=1 PROBES=1` runs the asm and
# the C oracle back-to-back on identical state EVERY CALL and compares.  ⭐ That in-process
# differential is the ONLY valid way to price an asm twin — a cross-run comparison changes the
# workload and measures a different thing.  See docs/development.md.

# Palette-remapped packed-pixel copy.  The C implementation remains the oracle;
# the 68000 twin keeps the 256-byte lookup table in an address register.
ifneq ($(MAPPED_COPY_C),1)
EXTRA_DEFINES += -DAITD_MAPPED_COPY_ASM
ifdef VERIFY
EXTRA_DEFINES += -DAITD_MAPPED_COPY_VERIFY
endif
endif

# Eight-plane reference conversion is active. The measured assembly kernel and
# optimization belongs to M5; inherited four-plane assembly must never be selected.
ifeq ($(C2P_C),0)
$(error eight-plane assembly optimization is deferred to M5)
endif
ifeq ($(C2P_SPLIT),1)
$(error C2P split profiling is deferred to M5)
endif


# `make PROBES=1` — the sub-frame timing accumulators, read via the gdb stub (amiga/diag_run.sh).
# OFF by default: the probes read chip registers several times per iteration, which is exactly
# what a framerate build must not do.  ⚠ NEVER quote a framerate from a PROBES build.
ifdef PROBES
EXTRA_DEFINES += -DAITD_PROBE
endif

ifeq ($(RESOURCEEXITPROBE),1)
ifeq ($(FILEPROBE),1)
$(error RESOURCEEXITPROBE uses original startup, not FILEPROBE)
endif
RESOURCEEXITPHASE ?= 1
RESOURCEEXITPREFS ?= 0
EXTRA_DEFINES += -DAITD_RESOURCE_EXIT_PROBE -DAITD_RESOURCE_EXIT_PHASE=$(RESOURCEEXITPHASE) -DAITD_RESOURCE_EXIT_PREFS=$(RESOURCEEXITPREFS)
PROBE_SYMS_RESOURCEEXIT = g_resourceExitPrefs g_resourceExitOverlayChecks g_resourceExitPhase g_resourceExitStep g_resourceExitError g_resourceExitPrepared g_resourceExitCleanupOK g_resourceExitHandle g_resourceLookupD0 g_resourceFileStackError g_fileProbeCCR g_resourceStageFault g_fileReadCalls g_fileReadBytes g_fileReadMax g_fileOpenHandles g_fileRestoredCloses g_fileCloseErrors
endif

ifeq ($(FILEWRITEPROBE),1)
ifneq ($(FILEPROBE),1)
$(error FILEWRITEPROBE=1 requires FILEPROBE=1)
endif
EXTRA_DEFINES += -DAITD_FILE_WRITE_PROBE
PROBE_SYMS_FILEWRITE = g_resourceDirtyStep g_resourceDirtyValue g_resourceDirtyError g_resourceDirtyMemory g_resourceDirtyWindows g_resourcePermissionStep g_resourcePermissionValue g_resourcePermissionError g_resourcePermissionMemory g_resourcePermissionWindows g_resourceMutationLifecycleChecks g_resourceMutationFaultChecks g_resourceMutationStep g_resourceMutationValue g_resourceMutationError g_resourceMutationMemory g_resourceMutationWindows g_resourceFileStep g_resourceFileStackError g_resourceFileWindows g_resourceFileResult g_fileWriteCalls g_fileWriteBytes g_fileWriteMax g_fileFlushCalls g_fileWriteProbeStep g_fileCatalogProbeStep g_fileForkProbeStep g_fileInstalledProbeStep g_fileIndexProbeStep g_fileVolumeProbeStep g_fileOpenDFProbeStep g_fileVInfoProbeStep g_volumeBackingProbe g_resourceStageError g_resourceStageStep g_resourceStageWindows g_resourceStageHash g_resourceStageFault g_resourceEnumerationStep g_resourceEnumerationHash g_resourceLifecycleStep g_resourceLifecycleHash g_resourceHandleStep g_resourceHandleHash g_resourceLookupStep g_resourceLookupD0 g_resourceLookupHash g_fileAsyncStep g_fileAsyncCallbacks g_fileAsyncPB g_fileAsyncA5 g_fileAsyncResult g_fileAsyncClobber g_fileAsyncNested g_fileAsyncNestedOK g_macFileCompletionDepth
endif
ifeq ($(PALETTEPROBE),1)
EXTRA_DEFINES += -DAITD_PALETTE_PROBE
endif
ifeq ($(CTABLEPROBE),1)
EXTRA_DEFINES += -DAITD_CTABLE_PROBE
endif
ifeq ($(APPLEEVENTPROBE),1)
APPLEEVENTFORM ?= 0
EXTRA_DEFINES += -DAITD_APPLE_EVENT_PROBE -DAITD_APPLE_EVENT_FORM=$(APPLEEVENTFORM)
PROBE_SYMS_AE = g_aeProbeForm
endif
ifeq ($(FILEPROBE),1)
EXTRA_DEFINES += -DAITD_FILE_PROBE
PROBE_SYMS_FILE = g_fileCloseErrors g_fileOpenHandles g_fileRestoredCloses g_fileReadCalls g_fileReadBytes g_fileReadMax g_fileProbeStage g_fileProbeError g_fileProbeDone g_fileProbeCCR g_fileProbeWindows
endif

ifeq ($(AGAPROBE),1)
EXTRA_DEFINES += -DAITD_AGA_PROBE
PROBE_SYMS_AGA = g_agaProbeStage g_agaProbeError g_agaProbeDone g_agaProbeScreen g_agaProbeSource g_agaProbeColors g_agaProbeViewport
endif

ifeq ($(WINDOWPROBE),1)
ifndef PROBES
$(error WINDOWPROBE=1 requires PROBES=1 for window boundary measurements)
endif
EXTRA_DEFINES += -DAITD_WINDOW_PROBE
PROBE_SYMS_WINDOW = g_windowProbeIOChecks g_windowProbeAudio g_windowProbeAudioInside g_windowProbeAudioWindows g_windowEnterTicks g_windowExitTicks g_windowProbePicture g_windowProbeChunk g_windowProbeDone g_windowProbeError g_windowProbeHash g_windowProbeTicks g_windowProbeFields
endif

ifeq ($(SERVICEPROBE),1)
EXTRA_DEFINES += -DAITD_SERVICE_PROBE
PROBE_SYMS_SERVICE = g_serviceProbe
endif

ifeq ($(IDENTITYPROBE),1)
EXTRA_DEFINES += -DAITD_IDENTITY_PROBE
PROBE_SYMS_IDENTITY = g_identityProbeStage
endif

ifeq ($(HEAPPROBE),1)
EXTRA_DEFINES += -DAITD_HEAP_PROBE
PROBE_SYMS_HEAP = g_heapProbeStage g_heapProbeDone
endif

ifeq ($(LINEAPROBE),1)
EXTRA_DEFINES += -DAITD_LINE_A_PROBE
endif

# `make FPSCOUNT=1` — the honest framerate build: one increment per painted frame, no
# instrumentation.  docs/development.md.
ifdef FPSCOUNT
EXTRA_DEFINES += -DAITD_FPSCOUNT
endif

ifeq ($(FILLWATCH),1)
$(error inherited four-plane FILLWATCH is unsupported; use AGAPROBE for eight-plane capture checks)
endif

ifdef PROBEFIELDS
EXTRA_DEFINES += -DAITD_PROBE_FIELDS=$(PROBEFIELDS)
endif

CXX_OBJS       := $(addprefix obj/,$(notdir $(CXX_SRCS:.cpp=.o)))
CORE_C_OBJS    := $(addprefix obj/,$(notdir $(CORE_C_SRCS:.c=.o)))
SUPPORT_C_OBJS := $(addprefix obj/,$(notdir $(SUPPORT_C_SRCS:.c=.o)))
ASM_OBJS       := $(addprefix obj/,$(notdir $(ASM_SRCS:.s=.o)))
FRAMEWORK_ASM_OBJS := $(addprefix obj/,$(notdir $(FRAMEWORK_ASM_SRCS:.s=.o)))
OBJECTS := $(CXX_OBJS) $(CORE_C_OBJS) $(SUPPORT_C_OBJS) $(ASM_OBJS) $(FRAMEWORK_ASM_OBJS)

vpath %.cpp $(AMIGA_SRC)/framework $(AMIGA_SRC) $(REPO)/src/platform $(REPO)/src/mac $(REPO)/src
vpath %.c   $(REPO)/src/mac $(REPO)/src/platform
vpath %.s   $(AMIGA_SRC)/framework $(AMIGA_SRC)

WARN = -Wall -Wno-unused-function -Wno-unused-parameter -Wno-unused-variable

CORE_CINCLUDES = -I"$(AMIGA_SRC)/framework/compat-include" \
                 -I"$(REPO)/src" \
                 -I"$(REPO)/src/mac" \
                 -I"$(REPO)/src/platform"

OPT        ?= -O2 -fomit-frame-pointer
NATIVE_OPT ?= -O3 -funroll-loops

CORE_CFLAGS = -g -MP -MMD -m68020 -mtune=68020 -msoft-float $(OPT) -nostdlib \
              -fno-tree-loop-distribution -ffunction-sections -fdata-sections \
              $(WARN) -DAITD_PLATFORM_AMIGA \
              $(CORE_CINCLUDES) $(EXTRA_DEFINES)

CCFLAGS   = -g -MP -MMD -m68020 -mtune=68020 -msoft-float $(OPT) -nostdlib \
            -fno-tree-loop-distribution -ffunction-sections -fdata-sections \
            $(WARN) $(EXTRA_DEFINES)
CPPFLAGS  = $(CCFLAGS) -fno-rtti -fno-exceptions -fno-use-cxa-atexit -std=gnu++17 \
            -fpermissive -Wno-write-strings -Wno-pointer-arith \
            -DAITD_PLATFORM_AMIGA \
            -include "$(AMIGA_SRC)/framework/SASCCompat.h" \
            -I"$(AMIGA_SRC)/framework" \
            -I"$(AMIGA_SRC)/framework/compat-include" \
            -I"$(AMIGA_SRC)" \
            -I"$(REPO)/src" \
            -I"$(REPO)/src/mac" \
            -I"$(REPO)/src/platform" \
            -I"$(CURDIR)"
# GNU as has no scheduling/tuning flag; hand-written code targets the 68020 ISA.
ASFLAGS   = -mcpu=68020 -mno-float -g --register-prefix-optional -I"$(SDKDIR)" -I"$(CURDIR)"
VASMFLAGS = -m68010 -Felf -quiet -x -no-opt -nowarn=62 $(EXTRA_VASMDEFS)

# ⚠⚠ Every global a committed .gdb script reads MUST be listed here.  -Wl,--gc-sections drops
# an unreferenced counter and gdb then resolves the name into .text and prints INSTRUCTION
# BYTES as a value — a fake measurement, not an obvious zero.  `probe-audit` enforces it.
PROBE_SYMS = g_catalogEntries g_catalogDataFiles g_catalogDataBytes g_applicationFileRef g_vbiCount g_planeChecksum g_screenReady \
             g_stageBState g_trapWord g_trapSelector g_trapSegment g_trapOffset \
             g_trapPC g_trapRegisters g_trapUserStack g_resourceCount g_jumpEntryCount \
             g_blockMoveCount g_trapManager g_trapRoutine
PROBE_SYMS += $(PROBE_SYMS_AGA) $(PROBE_SYMS_FILE) $(PROBE_SYMS_FILEWRITE) $(PROBE_SYMS_RESOURCEEXIT)
PROBE_SYMS += $(PROBE_SYMS_AE) g_defaultPalette g_appleEventHandlers g_soundDriver g_soundDriverHandle g_soundDriverCalls g_effects g_effectStarts g_effectStops
PROBE_SYMS += g_overlayChainVerified g_overlaySourceReads g_overlaySourceBytes g_overlaySourceMax g_overlayRuntimeReads g_overlayRuntimeBytes g_overlaySourceOpen g_overlaySourceCloseErrors
PROBE_SYMS += g_resourceSourceReads g_resourceSourceBytes g_resourceSourceMax g_resourceRuntimeReads g_resourceRuntimeBytes g_resourceSourceOpen g_resourceSourceCloseErrors
PROBE_SYMS += g_systemWindows g_windowFields g_systemWindowActive $(PROBE_SYMS_WINDOW)
PROBE_SYMS += g_macServiceActive g_macServiceEntered g_macServiceCompleted $(PROBE_SYMS_SERVICE)
PROBE_SYMS += g_stageCDepth $(PROBE_SYMS_HEAP) $(PROBE_SYMS_IDENTITY)
PROBE_SYMS += g_loadedCodeMask g_code3Base g_applicationZoneBase g_systemZoneBase g_heapFree g_heapLargest g_heapSystemFree g_heapError g_lowMemoryValidatedSites g_lowMemoryAppliedSites
PROBE_SYMS += g_macLowMemory g_startupCode g_startupLowMemoryPatches
PROBE_SYMS += SysBase g_macStackBase g_macLineAVectorAddress g_macSavedLineAVector g_macLineAInstalled g_macHostReturnSP
ifeq ($(LINEAPROBE),1)
PROBE_SYMS += g_lineAProbe
endif
PROBE_SYMS += g_macTicks
PROBE_SYMS += g_macFramesQueued g_macFramesPresented
PROBE_SYMS += g_beamPresentLine g_beamPresentMin g_beamPresentMax \
              g_beamPresents g_beamPresentsLate
PROBE_SYMS += g_macVBLCallbackEntry g_macVBLCallbackTask g_macVBLCallbackA5 g_macVBLCallbackReturn
ifneq ($(MAPPED_COPY_C),1)
ifdef VERIFY
PROBE_SYMS += g_mappedCopyAsmTicks g_mappedCopyCTicks g_mappedCopyVerifyCalls \
              g_mappedCopyVerifyBytes \
              g_mappedCopyVerifyFailures
endif
endif
ifdef PROBES
PROBE_SYMS += g_probeSkipC2P g_probeC2PFrames g_probeC2PRects g_probeC2PPixels \
              g_probeCopyMapIdentity g_probeCopyMapHits g_probeCopyMapMisses \
              g_probeCopyBitsTicks g_probeCopyBitsCalls \
              g_probeDelayCalls g_probeDelayRequested \
              g_probeBlockMoveTicks g_probeBlockMoveCalls \
              g_probeDrawPictureTicks g_probeDrawPictureCalls \
              g_probeDrawPictureTrace g_probeDrawPictureTraceTicks \
              g_probeCopyTraceEnabled g_probeCopyTraceCount g_probeCopyTrace \
              g_probeCopyModeTicks g_probeCopyModeCalls \
              g_probePaulaZeroedMask \
              g_macExitState g_macHostReturnSP \
              g_restoreSavedDmacon g_restoreActualDmacon \
              g_restoreSavedIntena g_restoreActualIntena g_restoreViewMatches \
              g_profileState g_profileGeneration g_profileStartEpoch g_profileStopEpoch \
              g_profileStartField g_profileStopField g_profileStartFrames g_profileStopFrames \
              g_profileTicks g_profileCalls
endif
ifeq ($(FILLWATCH),1)
PROBE_SYMS += g_fillWatchFrames g_fillWatchRows g_fillBadFrames g_fillBadPixels \
              g_fillBadX g_fillBadY g_fillBadExpected g_fillBadActual
endif

COMMA := ,
LDFLAGS   = -Wl,--emit-relocs,--gc-sections,-Ttext=0,-Map=$(OUT).map \
            $(addprefix -Wl$(COMMA)--undefined=,$(PROBE_SYMS))

VERSION_STRING = $$VER: Alone in the Dark $(shell cat $(REPO)/VERSION)

# ---------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------
.PHONY: all clean no-float-audit probe-audit

all: $(OUT).exe

$(OUT).exe: $(OUT).elf
	$(info Elf2Hunk $@)
	@elf2hunk $(OUT).elf $(OUT).exe -s
	@grep -qa '$(VERSION_STRING) ' $(OUT).exe || { \
	  echo "error: the AmigaOS \$$VER: string is missing from $@ or disagrees with VERSION."; \
	  echo "       See src/platform/amiga/version.s (SHF_GNU_RETAIN)."; \
	  $(RM) $@; exit 1; }

$(OUT).elf: $(OBJECTS)
	$(info Linking $@)
	@$(CC) $(CCFLAGS) $(LDFLAGS) $(OBJECTS) -o $@
	@$(OBJDUMP) --disassemble --no-show-raw-ins -S $@ > $(OUT).s 2>/dev/null || true
	@$(MAKE) --no-print-directory no-float-audit
	@$(MAKE) --no-print-directory probe-audit

# No FPU is required, and libgcc soft-float must not enter the native runtime.
# Inspect symbols (including undefined references), not disassembly text.
no-float-audit:
	@$(OBJDUMP) -t $(OUT).elf > obj/float-audit.symbols
	@if awk '{print $$NF}' obj/float-audit.symbols | grep -E '^__[a-z0-9_]*(sf|df|xf|tf)[a-z0-9_]*$$' > obj/float-audit.bad; then \
	  echo "*** software floating-point helper(s) linked in:"; \
	  cat obj/float-audit.bad; exit 1; \
	else echo "no-float-audit: clean"; fi

# ⚠ MANDATORY AUDIT: every PROBE_SYMS symbol must be a real data symbol in the linked ELF.
# A gc-dropped probe counter makes gdb print instruction bytes as a measurement — see PROBE_SYMS.
probe-audit:
	@bad=""; for s in $(PROBE_SYMS); do \
	  $(OBJDUMP) -t $(OUT).elf | grep -qE "[[:space:]]O[[:space:]]+\.(bss|data)[[:space:]].*[[:space:]]$$s$$" \
	    || bad="$$bad $$s"; \
	done; \
	if [ -n "$$bad" ]; then \
	  echo "*** probe symbol(s) missing from $(OUT).elf (gc-sections ate them):$$bad"; \
	  echo "    gdb would resolve these into .text and print instruction bytes as values."; \
	  exit 1; \
	else echo "probe-audit: clean ($(words $(PROBE_SYMS)) symbols)"; fi

# C++ (framework + the Amiga backend + the shared platform layer).
obj/%.o : %.cpp
	$(info C++  $<)
	@$(CC) $(CPPFLAGS) -c -o $@ "$(abspath $<)"

# The port's plain-C translation units.
obj/%.o : %.c
	$(info C    $< [core])
	@$(CC) $(CORE_CFLAGS) -c -o $@ "$(abspath $<)"

# Support runtime: gcc8_c_support.c needs CCFLAGS (no core include paths).
obj/gcc8_c_support.o : $(SUPPORT)/gcc8_c_support.c
	$(info C    $<)
	@$(CC) $(CCFLAGS) -c -o $@ "$<"

obj/gcc8_a_support.o : $(SUPPORT)/gcc8_a_support.s
	$(info ASM  $<)
	@$(AS) $(ASFLAGS) -o $@ "$<"

# Port-authored GAS assembly (68000 exception/trampoline code).
obj/%.o : $(AMIGA_SRC)/%.s
	$(info ASM  $<)
	@$(AS) $(ASFLAGS) -o $@ "$(abspath $<)"

# Framework hand-written asm (vasm, Motorola syntax -> ELF).  Static pattern rule so it does not
# collide with the gas-assembled gcc8_a_support.s rule.
$(FRAMEWORK_ASM_OBJS) : obj/%.o : %.s
	$(info VASM $<)
	@$(VASM) $(VASMFLAGS) -o $@ "$(abspath $<)"

clean:
	@$(RM) -r obj/ out/

-include $(wildcard obj/*.d)
