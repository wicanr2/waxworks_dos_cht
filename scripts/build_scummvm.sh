#!/bin/bash
set -euo pipefail
SRC="/home/anr2/scummvm/waxworks/workplace/build/scummvm-src"
docker run --rm -v "$SRC:/src" -w /src waxworks-build bash -c "
  set -e
  [ -f config.mk ] || ./configure --disable-all-engines --enable-engine=agos --enable-release \
     --disable-mad --disable-vorbis --disable-flac --disable-fluidsynth \
     --disable-mpeg2 --disable-theoradec --disable-faad --disable-libcurl 2>&1 | tail -6
  make -j\$(nproc) 2>&1 | tail -12
  chown $(id -u):$(id -g) scummvm 2>/dev/null || true
  ls -lh scummvm
"
