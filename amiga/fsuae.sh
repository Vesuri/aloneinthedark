# Project-scoped debugger setup, sourced by the three launchers (from amiga/).
# Use a project-specific default; override when running concurrent checkouts.
DEBUG_PORT="${DEBUG_PORT:-24377}"
export DEBUG_PORT
. ./env.sh
. "$FSUAE_COMMON"

# Only our recorded process can be reclaimed. An occupied port alone does not
# establish ownership, even when its listener is another FS-UAE process: the shared
# fsuae_claim_port fails instead of moving to another port.
FSUAE_CLAIM_STRICT=1
