#!/usr/bin/env bash
# Builds the real firmware for the PC and runs it against a simulated oven and
# Shelly, once per supported board, then tests the Shelly script with Node.js.
# Needs g++ (C++17). Node.js is optional: without it the Shelly script test is skipped.
#   ./run.sh              all scenarios
#   ./run.sh "Wi-Fi"      only scenarios whose name contains "Wi-Fi"
#   ./run.sh "STOP" log   ...and print the firmware's serial log
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
fw="$here/../reflow_controller"
build="$here/build"
mkdir -p "$build/freenove"
flags=(-std=c++17 -O1 -Wall -Wextra -Wno-unused-function -Wno-unused-parameter -Wno-unused-variable -x c++)
status=0

# The Arduino IDE writes a prototype for every function in a .ino file and puts
# them near the top of the sketch. A function that takes a type defined further
# down in the .ino then fails to compile there, though plain g++ accepts it. Do
# the same here (prototypes right after the last #include) and check it still
# compiles.
mkdir -p "$build/proto"
cp "$fw"/*.h "$build/proto/"
awk 'FNR == NR {
       if ($0 ~ /^[A-Za-z_][A-Za-z0-9_ :<>&*]*[ &*]+[A-Za-z_][A-Za-z0-9_]*\([^=;{]*\)[ ]*\{/) {
         line = $0; sub(/[ ]*\{.*/, "", line); protos = protos line ";\n"
       }
       if ($0 ~ /^#include/) last = FNR
       next
     }
     { print; if (FNR == last) printf "%s", protos }' \
  "$fw/reflow_controller.ino" "$fw/reflow_controller.ino" > "$build/proto/reflow_controller.ino"
if g++ "${flags[@]}" -fsyntax-only -I "$here/stubs" -I "$build/proto" "$here/host_test.cpp"; then
  echo "Arduino-style prototypes: sketch still compiles"
else
  echo "FAILED: the sketch does not compile with Arduino-style prototypes (move the type to types.h)"
  status=1
fi
echo

# Board 1: as config.h is set up in the repo.
g++ "${flags[@]}" -I "$here/stubs" -I "$fw" "$here/host_test.cpp" -o "$build/host_test_default"
"$build/host_test_default" "$@" || status=1

# Board 2: the same sources with the other board selected in a copy of config.h.
cp "$fw"/*.h "$fw"/*.ino "$build/freenove/"
rm -f "$build/freenove/secrets.h"
if grep -q '^#define BOARD_CROWPANEL_28' "$fw/config.h"; then
  sed -i -e 's|^#define BOARD_CROWPANEL_28|// #define BOARD_CROWPANEL_28|' \
         -e 's|^// #define BOARD_FREENOVE_S3_35|#define BOARD_FREENOVE_S3_35|' "$build/freenove/config.h"
else
  sed -i -e 's|^#define BOARD_FREENOVE_S3_35|// #define BOARD_FREENOVE_S3_35|' \
         -e 's|^// #define BOARD_CROWPANEL_28|#define BOARD_CROWPANEL_28|' "$build/freenove/config.h"
fi
echo
g++ "${flags[@]}" -I "$here/stubs" -I "$build/freenove" "$here/host_test.cpp" -o "$build/host_test_other"
"$build/host_test_other" "$@" || status=1

echo
if command -v node >/dev/null 2>&1; then
  node "$here/shelly_script_test.js" || status=1
else
  echo "Node.js not found: skipping the Shelly script test"
fi
exit $status
