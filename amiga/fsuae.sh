# Project-scoped debugger setup, sourced by the three launchers.
# The shared helper's 40-port hash collides with Pokeri on this host.
DEBUG_PORT="${DEBUG_PORT:-24377}"
export DEBUG_PORT
. "${FSUAE_COMMON:-$HOME/.local/share/amiga/fsuae_common.sh}"

# Only our recorded process can be reclaimed. An occupied port alone does not
# establish ownership, even when its listener is another FS-UAE process.
fsuae_claim_port() {
  fsuae_stop_previous
  local held
  held=$(lsof -nP -iTCP:"$DEBUG_PORT" -sTCP:LISTEN -t 2>/dev/null || true)
  if [ -n "$held" ]; then
    echo "DIAG / DEBUG PORT BUSY: $DEBUG_PORT (pid $held); no process stopped" >&2
    return 1
  fi
  echo "gdb stub port: $DEBUG_PORT (override with \$DEBUG_PORT)"
}
