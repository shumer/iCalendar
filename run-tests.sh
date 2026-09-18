#!/bin/bash
# Run the suite. It is an executable rather than an XCTest bundle, see
# docs/adr/0001-spm-only-toolchain.md, so this is all there is to it.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
swift run --package-path "$HERE" MenuCalTests
