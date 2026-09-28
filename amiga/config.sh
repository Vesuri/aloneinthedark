#!/usr/bin/env bash
# Shared, explicit regression configurations (design.md section 6).
AMIGA_CONFIG="${AMIGA_CONFIG:-a1200-020}"
case "$AMIGA_CONFIG" in
  a1200-020) ;;
  a1200-030|a4000-040|a1200-060)
    echo "CONFIG / DEFERRED CPU TARGET: $AMIGA_CONFIG; use a1200-020" >&2; return 1 ;;
  *) echo "CONFIG / UNKNOWN AMIGA_CONFIG: $AMIGA_CONFIG" >&2; return 1 ;;
esac
# Legacy independent overrides would make a named configuration misleading.
if [[ -n "${AMIGA_MODEL:-}${CHIP_MEMORY:-}${FAST_MEMORY:-}" ]]; then
  echo 'CONFIG / use AMIGA_CONFIG instead of legacy model/memory overrides' >&2
  return 1
fi
for aitd_arg in ${EXTRA_ARGS:-}; do
  case "$aitd_arg" in
    --amiga_model*|--cpu*|--chip*|--fast_memory*|--slow_memory*|--zorro_iii_memory*|--jit*|--fpu*|--mmu*|--uae_cpu*|--uae_chip*|--uae_*mem*|--uae_mmu*|--uae_fpu*|--uae_cache*)
      echo "CONFIG / machine override in EXTRA_ARGS: $aitd_arg" >&2; return 1 ;;
  esac
done
AITD_MACHINE_ARGS=(
  --amiga_model=A1200 --cpu=68EC020 --uae_chipset=aga
  --chip_memory=2048 --slow_memory=0 --fast_memory=8192
  --zorro_iii_memory=0 --uae_mbresmem_size=0 --uae_a3000mem_size=0
  --uae_mmu_model=0 --uae_fpu_model=0 --jit_compiler=0
  --uae_cpu_speed=real --uae_cpu_cycle_exact=true --uae_cpu_memory_cycle_exact=true
  --uae_cpu_multiplier=0 --uae_cpu_frequency=14187580
)
echo "CONFIG $AMIGA_CONFIG model=A1200 cpu=68EC020 chipset=AGA chip_kb=2048 fast_kb=8192 mmu=0 jit=0"
