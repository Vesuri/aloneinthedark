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
  local source_root="$(dirname "$AITD_APP_RSRC")" name suffix
  for name in 'ListBod2.PAK' 'Quick Reference' 'Register Triple A Pack'; do
    for suffix in '' '.finfo'; do
      [ -f "$source_root/$name$suffix" ] || {
        echo "Original application-folder file missing: $name$suffix; rerun extractor" >&2
        return 1
      }
    done
  done
  for name in 'Quick Reference' 'Register Triple A Pack'; do
    [ -f "$source_root/$name.rsrc" ] || return 1
  done
  # This dedicated asset directory excludes the port executable and probes.
  # Preserve arbitrary user contents: catalog validation must see unknown layouts.
  local assets="$destination/data"
  mkdir -p "$assets"
  cp -f ../resources/overlay.rsrc "$destination/overlay.rsrc" || return 1
  cp -f "$AITD_APP_RSRC" "$assets/Alone In The Dark"
  cp -f "$AITD_APP_RSRC.finfo" "$assets/Alone In The Dark.finfo"
  for name in 'ListBod2.PAK' 'Quick Reference' 'Register Triple A Pack'; do
    cp -f "$source_root/$name" "$source_root/$name.finfo" "$assets/"
  done
  for name in 'Quick Reference' 'Register Triple A Pack'; do
    cp -f "$source_root/$name.rsrc" "$assets/"
  done
  rm -rf "$assets/Alone Data"
  cp -R "$AITD_DATA_DIR" "$assets/Alone Data"
}
