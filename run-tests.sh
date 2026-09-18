#!/bin/bash
# Run the suite. It is an executable rather than an XCTest bundle, see
# docs/adr/0001-spm-only-toolchain.md, so this is all there is to it.
#
# Usage: ./run-tests.sh [--coverage]
#   --coverage  build with coverage instrumentation and report line coverage of MenuCalCore,
#               failing under 80%.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ "${1:-}" != "--coverage" ]; then
  swift run --package-path "$HERE" MenuCalTests
  exit 0
fi

# `swift test --enable-code-coverage` needs XCTest, so the instrumentation is asked for by hand.
# A scratch path of its own keeps instrumented objects out of the normal build.
SCRATCH="$HERE/.build/coverage"
swift build --package-path "$HERE" --scratch-path "$SCRATCH" --product MenuCalTests \
  -Xswiftc -profile-generate -Xswiftc -profile-coverage-mapping
BINARY="$(swift build --package-path "$HERE" --scratch-path "$SCRATCH" --show-bin-path)/MenuCalTests"
LLVM_PROFILE_FILE="$SCRATCH/tests.profraw" "$BINARY"
xcrun llvm-profdata merge -sparse "$SCRATCH/tests.profraw" -o "$SCRATCH/tests.profdata"
xcrun llvm-cov report "$BINARY" -instr-profile="$SCRATCH/tests.profdata" \
  "$HERE/Sources/MenuCalCore" | tee "$SCRATCH/report.txt"

LINES="$(awk '/^TOTAL/ { gsub("%", "", $10); print $10 }' "$SCRATCH/report.txt")"
echo "MenuCalCore line coverage: ${LINES}%"
awk -v value="$LINES" 'BEGIN { exit (value + 0 >= 80) ? 0 : 1 }' || {
  echo "Coverage is under 80%" >&2
  exit 1
}
