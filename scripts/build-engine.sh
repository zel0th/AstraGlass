#!/bin/bash
set -eo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build/engine"
mkdir -p "$BUILD/source" "$BUILD/obj" "$ROOT/Engine/bin"
cp "$ROOT"/Upstream/Astrolog/*.{cpp,h} "$BUILD/source/"
# X11 is the only platform frontend removed. File graphics remain enabled.
python3 - "$BUILD/source/astrolog.h" <<'PYHEADER'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); p.write_text(p.read_text().replace("#define X11 ", "//#define X11 "))
PYHEADER
CXX="${CXX:-$(command -v clang++ || command -v g++)}"
PLATFORM_FLAGS=()
if [[ "$(uname -s)" == Darwin ]]; then
  PLATFORM_FLAGS=(-arch arm64 -mmacosx-version-min=27.0)
fi
# Never reuse ELF objects in a Mach-O build (or vice versa), even after copying
# a working directory between Linux validation and the user's Mac.
TARGET="$(uname -s)-$(uname -m)-${PLATFORM_FLAGS[*]}-$($CXX --version | head -n 1)"
if [[ ! -f "$BUILD/target.txt" || "$(cat "$BUILD/target.txt")" != "$TARGET" ]]; then
  rm -f "$BUILD"/obj/*.o
  printf '%s\n' "$TARGET" > "$BUILD/target.txt"
fi
# A failed ephemeris lookup must never appear as a valid 0-degree planet.
# Apply only to the build copy, preserving the upstream distribution verbatim.
python3 - "$BUILD/source/calc.cpp" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
old = '    if (!fRet)\n      continue;\n\n    // Store positions and velocities in object array.'
new = '    if (!fRet) {\n      // South Node is derived below, not requested from Swiss Ephemeris.\n      if (i != oSou) ignore[i] = ignore2[i] = fTrue;\n      if (i == oNod) ignore[oSou] = ignore2[oSou] = fTrue;\n      continue;\n    }\n\n    // Store positions and velocities in object array.'
assert old in s, 'Astrolog source changed: inspect ephemeris failure handling'
p.write_text(s.replace(old, new, 1))
PY
SOURCES=(astrolog atlas calc charts0 charts1 charts2 charts3 data express general intrpret io matrix placalc placalc2 xdata xgeneral xdevice xcharts0 xcharts1 xcharts2 xscreen swecl swedate swehouse swejpl swemmoon swemplan sweph swephlib)
for source in "${SOURCES[@]}"; do
  extra=()
  if [[ "$source" = astrolog ]]; then extra=(-Dmain=AstrologMain); fi
  if [[ ! -f "$BUILD/obj/$source.o" || "$ROOT/Upstream/Astrolog/$source.cpp" -nt "$BUILD/obj/$source.o" || "$ROOT/scripts/build-engine.sh" -nt "$BUILD/obj/$source.o" ]]; then
    "$CXX" "${PLATFORM_FLAGS[@]}" -std=c++11 -O2 -Wno-write-strings -Wno-narrowing -Wno-comment -Wno-deprecated-declarations -Wno-format-security "${extra[@]}" -c "$BUILD/source/$source.cpp" -o "$BUILD/obj/$source.o"
  fi
done
"$CXX" "${PLATFORM_FLAGS[@]}" -std=c++11 -O2 -I"$BUILD/source" -Wno-write-strings -Wno-narrowing -c "$ROOT/Engine/Bridge.cpp" -o "$BUILD/obj/Bridge.o"
"$CXX" "${PLATFORM_FLAGS[@]}" "$BUILD"/obj/*.o -o "$ROOT/Engine/bin/astrolog" -lm
chmod 755 "$ROOT/Engine/bin/astrolog"
echo "$ROOT/Engine/bin/astrolog"
