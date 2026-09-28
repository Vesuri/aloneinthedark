#!/usr/bin/env bash
# Development-run helper. No release archive may contain these inputs; they
# come from the user's original archive via tools/extract_original_data.py.
# Paths remain overridable for local source layouts.

AITD_APP_RSRC="${AITD_APP_RSRC:-../tmp/runtime-data/Alone In The Dark}"
AITD_DATA_DIR="${AITD_DATA_DIR:-../tmp/runtime-data/Alone Data}"

stage_aitd_original_data()
{
  local destination="$1"
  [ -f "$AITD_APP_RSRC" ] || {
    echo "Alone In The Dark resource fork not found: $AITD_APP_RSRC" >&2
    echo "  run: python3 tools/extract_original_data.py tmp/AloneInTheDark.img_.sit tmp/runtime-data" >&2
    return 1
  }
  [ -d "$AITD_DATA_DIR" ] || {
    echo "Alone Data folder not found: $AITD_DATA_DIR" >&2
    return 1
  }
  [ -f "$AITD_APP_RSRC.finfo" ] || {
    echo "Original Finder metadata missing; rerun tools/extract_original_data.py" >&2
    return 1
  }
  cp -f "$AITD_APP_RSRC" "$destination/Alone In The Dark"
  cp -f "$AITD_APP_RSRC.finfo" "$destination/Alone In The Dark.finfo"
  rm -rf "$destination/Alone Data"
  cp -R "$AITD_DATA_DIR" "$destination/Alone Data"
}
