#!/usr/bin/env bash
# Shared, explicit regression configurations (design.md section 6).
AMIGA_MODEL="${AMIGA_MODEL:-A4000}"
case "$AMIGA_MODEL" in
  A4000) aitd_default_config=a4000-030-reference ;;
  A1200) aitd_default_config=a1200-020 ;;
  *) echo "CONFIG / UNSUPPORTED MODEL: $AMIGA_MODEL" >&2; return 1 ;;
esac
AMIGA_CONFIG="${AMIGA_CONFIG:-$aitd_default_config}"
AMIGA_VIDEO="${AMIGA_VIDEO:-PAL}"
case "$AMIGA_VIDEO" in
  PAL) aitd_ntsc=0; aitd_core_ntsc=false; aitd_cpu_frequency=14187580 ;;
  NTSC) aitd_ntsc=1; aitd_core_ntsc=true; aitd_cpu_frequency=14318180 ;;
  *) echo "CONFIG / UNKNOWN AMIGA_VIDEO: $AMIGA_VIDEO; use PAL or NTSC" >&2; return 1 ;;
esac
case "$AMIGA_CONFIG" in
  a1200-020) AMIGA_MODEL=A1200; aitd_cpu=68EC020 ;;
  a4000-020) AMIGA_MODEL=A4000; aitd_cpu=68EC020 ;;
  a4000-030) AMIGA_MODEL=A4000; aitd_cpu=68030 ;;
  a4000-030-reference) AMIGA_MODEL=A4000; aitd_cpu=68030; aitd_cpu_frequency=15667200 ;;
  a1200-030|a4000-040|a1200-060)
    echo "CONFIG / DEFERRED CPU TARGET: $AMIGA_CONFIG; use a4000-030, a4000-020 or a1200-020" >&2; return 1 ;;
  *) echo "CONFIG / UNKNOWN AMIGA_CONFIG: $AMIGA_CONFIG" >&2; return 1 ;;
esac
# Legacy independent overrides would make a named configuration misleading.
if [[ -n "${CHIP_MEMORY:-}${FAST_MEMORY:-}" ]]; then
  echo 'CONFIG / use AMIGA_CONFIG instead of legacy model/memory overrides' >&2
  return 1
fi
for aitd_arg in ${EXTRA_ARGS:-}; do
  case "$aitd_arg" in
    --amiga_model*|--cpu*|--chip*|--fast_memory*|--slow_memory*|--zorro_iii_memory*|--jit*|--fpu*|--mmu*|--ntsc_mode*|--uae_ntsc*|--uae_cpu*|--uae_chip*|--uae_*mem*|--uae_mmu*|--uae_fpu*|--uae_cache*)
      echo "CONFIG / machine override in EXTRA_ARGS: $aitd_arg" >&2; return 1 ;;
  esac
done
AITD_MACHINE_ARGS=(
  --amiga_model="$AMIGA_MODEL" --cpu="$aitd_cpu" --uae_chipset=aga
  --ntsc_mode="$aitd_ntsc"
  --uae_ntsc="$aitd_core_ntsc"
  --chip_memory=2048 --slow_memory=0 --fast_memory=8192
  --zorro_iii_memory=0 --uae_mbresmem_size=0 --uae_a3000mem_size=0
  --uae_mmu_model=0 --uae_fpu_model=0 --jit_compiler=0
)
if [[ "$AMIGA_CONFIG" == a1200-020 || "$AMIGA_CONFIG" == a4000-030-reference ]]; then
  AITD_MACHINE_ARGS+=(
    --uae_cpu_speed=real --uae_cpu_cycle_exact=true --uae_cpu_memory_cycle_exact=true
    --uae_cpu_multiplier=0 --uae_cpu_frequency="$aitd_cpu_frequency"
  )
else
  aitd_cpu_frequency=0
  # Owner-approved temporary fast test machine; the port still builds for the 68020 instruction set.
  AITD_MACHINE_ARGS+=(
    --uae_cpu_speed=max --uae_cpu_cycle_exact=false --uae_cpu_memory_cycle_exact=false
    --uae_blitter_cycle_exact=false --uae_cpu_multiplier=0 --uae_cpu_frequency=0
  )
fi
echo "CONFIG $AMIGA_CONFIG model=$AMIGA_MODEL cpu=$aitd_cpu frequency_hz=$aitd_cpu_frequency chipset=AGA chip_kb=2048 fast_kb=8192 mmu=0 jit=0 video=$AMIGA_VIDEO"
