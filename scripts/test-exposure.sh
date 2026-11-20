#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/LightMeter-exposure.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
swiftc -module-cache-path "$test_dir/module-cache" \
    LightMeter/Models/ExposureCalculator.swift tests/ExposureAccuracyTests.swift \
    -o "$test_dir/exposure-tests"
"$test_dir/exposure-tests"
swiftc -module-cache-path "$test_dir/module-cache" \
    LightMeter/Models/ExposureCalculator.swift LightMeter/Models/CameraMeteringReading.swift \
    tests/CameraMeteringTests.swift -o "$test_dir/metering-tests"
"$test_dir/metering-tests"
swiftc -module-cache-path "$test_dir/module-cache" \
    LightMeter/Models/ExposureCalculator.swift LightMeter/Models/CameraMeteringReading.swift \
    LightMeter/Models/FilmPreset.swift LightMeter/Models/MeteringPoint.swift \
    LightMeter/ViewModels/MeteringViewModel.swift tests/MeteringPipelineTests.swift \
    -o "$test_dir/pipeline-tests"
"$test_dir/pipeline-tests"
