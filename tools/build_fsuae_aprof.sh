#!/usr/bin/env bash
# Build the cycle-profiling FS-UAE used by amiga/aprof.sh (docs/performance.md).
# Base: the barto remote-debugger fork already used by the shared ARM emulator.
# tools/fsuae_aprof.patch adds `monitor aprof start` / `monitor aprof stop FILE`.
# Its SDL2_ttf and libmpeg2 libraries are built statically from pinned tarballs
# (libmpeg2's demo programs do not link on current macOS and are skipped).
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
build="${FSUAE_APROF_BUILD:-$HOME/.local/share/amiga/fs-uae-aprof-build}"
dest="${FSUAE_APROF_DIR:-$HOME/.local/share/amiga/fs-uae-aprof}"
# Autotools flags break on spaces, so the build never runs inside this checkout.
case "$build$dest" in *' '*) echo 'APROF BUILD / paths must not contain spaces' >&2; exit 2 ;; esac
[[ -d /opt/homebrew/bin ]] && PATH="/opt/homebrew/bin:$PATH"
fork=https://github.com/grahambates/fs-uae.git
commit=b70b1180b44ab25b97cd66466c70879897d8a362
ttf_url=https://github.com/libsdl-org/SDL_ttf/releases/download/release-2.0.15/SDL2_ttf-2.0.15.tar.gz
ttf_sha=a9eceb1ad88c1f1545cd7bd28e7cbc0b2c14191d40238f531a15b01b1b22cd33
mpeg_url=https://download.videolan.org/contrib/libmpeg2/libmpeg2-0.5.1.tar.gz
mpeg_sha=dee22e893cb5fc2b2b6ebd60b88478ab8556cb3b93f9a0d7ce8f3b61851871d4
jobs="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || nproc)}"
deps="$build/deps"; src="$build/fs-uae"
mkdir -p "$build/dl" "$deps"

fetch() { # url sha256 -> extracted directory name on stdout
  local file="$build/dl/${1##*/}"
  [[ -f "$file" ]] || curl -fsSL -o "$file" "$1"
  echo "$2  $file" | shasum -a 256 -c - >/dev/null || { echo "APROF BUILD / checksum mismatch: $file" >&2; exit 1; }
  tar xzf "$file" -C "$build"
  basename "$file" .tar.gz
}
dir=$(fetch "$ttf_url" "$ttf_sha")
(cd "$build/$dir" && ./configure --prefix="$deps" --disable-shared --enable-static >"$build/ttf.log" 2>&1 \
  && make -j"$jobs" install >>"$build/ttf.log" 2>&1) || { echo "APROF BUILD / SDL2_ttf failed: $build/ttf.log" >&2; exit 1; }
dir=$(fetch "$mpeg_url" "$mpeg_sha")
# Its 2008 config.guess calls arm64 macOS "arm" (32-bit ARM assembly); use automake's.
cp -f "$(automake --print-libdir)"/config.guess "$(automake --print-libdir)"/config.sub "$build/$dir/.auto/"
(cd "$build/$dir" && ./configure --prefix="$deps" --disable-shared --enable-static --disable-sdl --without-x >"$build/mpeg.log" 2>&1 \
  && make -j"$jobs" -C libmpeg2 install >>"$build/mpeg.log" 2>&1 && make -C include install >>"$build/mpeg.log" 2>&1) \
  || { echo "APROF BUILD / libmpeg2 failed: $build/mpeg.log" >&2; exit 1; }

if [[ ! -d "$src/.git" ]]; then
  git clone -q --filter=blob:none "$fork" "$src"
fi
git -C "$src" checkout -q --force "$commit"
git -C "$src" clean -qfdx
git -C "$src" apply "$repo/tools/fsuae_aprof.patch"
export PKG_CONFIG_PATH="$deps/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
(cd "$src" && ./bootstrap >"$build/fs-uae.log" 2>&1 \
  && ./configure --disable-jit --disable-x86 \
       SDL2_TTF_CFLAGS="-I$deps/include $(pkg-config --cflags SDL2_ttf)" SDL2_TTF_LIBS="$(pkg-config --static --libs SDL2_ttf freetype2)" \
       LIBMPEG2_CFLAGS="$(pkg-config --cflags libmpeg2)" LIBMPEG2_LIBS="$(pkg-config --static --libs libmpeg2 libmpeg2convert)" \
       CFLAGS=-O2 CXXFLAGS=-O2 >>"$build/fs-uae.log" 2>&1 \
  && make -j"$jobs" >>"$build/fs-uae.log" 2>&1) || { echo "APROF BUILD / FS-UAE failed: $build/fs-uae.log" >&2; exit 1; }
mkdir -p "$dest"
rm -rf "$dest/data"
cp -f "$src/fs-uae" "$src/fs-uae.dat" "$dest/"
cp -R "$src/data" "$dest/data"
printf '%s %s + tools/fsuae_aprof.patch %s\n' "$fork" "$commit" "$(shasum -a 256 "$repo/tools/fsuae_aprof.patch" | cut -c1-64)" > "$dest/source-revision.txt"
echo "APROF BUILD / installed $dest/fs-uae"
