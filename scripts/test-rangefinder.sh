#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/LightMeter-rangefinder.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
swiftc -module-cache-path "$test_dir/module-cache" \
    LightMeter/Models/RangefinderReading.swift tests/RangefinderReadingTests.swift \
    -o "$test_dir/rangefinder-tests"
"$test_dir/rangefinder-tests"
swiftc -module-cache-path "$test_dir/module-cache" \
    LightMeter/Models/CameraStartupRecovery.swift tests/CameraStartupRecoveryTests.swift \
    -o "$test_dir/camera-startup-tests"
"$test_dir/camera-startup-tests"
