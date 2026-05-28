# Native Lens Calibration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build native-iPhone-lens EV calibration so LightMeter can move toward replacing a physical light meter.

**Architecture:** Add a small calibration domain model and store, expose native lens and exposure metadata from `CameraManager`, apply the active native-lens EV offset in `MeteringViewModel`, and add a settings flow for professional, standard, and quick calibration. Simulated focal lengths remain preview/crop controls and never become calibration keys.

**Tech Stack:** Swift, SwiftUI, AVFoundation, UserDefaults, source-level Swift tests.

---

### Task 1: Calibration Model And Store

**Files:**
- Create: `LightMeter/Models/MeteringCalibration.swift`
- Test: `test_metering_calibration_source.swift`

- [ ] **Step 1: Write the failing behavior test**

```swift
import Foundation

@main
struct MeteringCalibrationBehaviorTest {
    static func main() {
        let ev100 = MeteringCalibrationMath.ev100(aperture: 8.0, exposureDuration: 1.0 / 125.0, iso: 100)
        precondition(abs(ev100 - 12.965784) < 0.0001)

        let professional = LensCalibration(nativeLensKey: "wide", level: .professional, evOffset: 0.2, sampleCount: 1, createdAt: Date(timeIntervalSince1970: 1), deviceModel: "iPhone", appVersion: "1")
        let standard = LensCalibration(nativeLensKey: "wide", level: .standard, evOffset: -0.1, sampleCount: 5, createdAt: Date(timeIntervalSince1970: 2), deviceModel: "iPhone", appVersion: "1")
        let quick = LensCalibration(nativeLensKey: "wide", level: .quick, evOffset: 0.5, sampleCount: 1, createdAt: Date(timeIntervalSince1970: 3), deviceModel: "iPhone", appVersion: "1")

        precondition(LensCalibration.best(from: [quick, standard, professional])?.level == .professional)
        precondition(MeteringCalibrationMath.applyOffset(to: 12.5, calibration: professional) == 12.7)
        precondition(professional.statusLabel == "Professional +0.2 EV")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcrun swiftc -parse-as-library LightMeter/Models/MeteringCalibration.swift test_metering_calibration_source.swift -o /tmp/test_metering_calibration_source && /tmp/test_metering_calibration_source`

Expected: FAIL because `LightMeter/Models/MeteringCalibration.swift` does not exist.

- [ ] **Step 3: Implement model and math**

Create `MeteringCalibration.swift` with `CalibrationLevel`, `NativeLensInfo`, `LensCalibration`, `MeteringCalibrationMath`, and `MeteringCalibrationStore`.

- [ ] **Step 4: Run behavior test**

Run the same `xcrun swiftc` command. Expected: PASS.

### Task 2: Camera Metadata And Sampling

**Files:**
- Modify: `LightMeter/Managers/CameraManager.swift`
- Test: `test_camera_calibration_source.swift`

- [ ] **Step 1: Write source test**

Check that `CameraManager` exposes native lens info, exposure metadata, center brightness sampling, exposure lock, and a calibration sample method.

- [ ] **Step 2: Verify source test fails**

Run: `xcrun swiftc -parse-as-library test_camera_calibration_source.swift -o /tmp/test_camera_calibration_source && /tmp/test_camera_calibration_source`

- [ ] **Step 3: Add camera APIs**

Add `currentNativeLensInfo`, `currentExposureSnapshot`, `getCenterWeightedBrightness`, `lockCurrentExposure`, and `captureCalibrationSample`.

- [ ] **Step 4: Verify source test passes**

Run the same command. Expected: PASS.

### Task 3: Apply Calibration In EV Pipeline

**Files:**
- Modify: `LightMeter/ViewModels/MeteringViewModel.swift`
- Modify: `LightMeter/Models/ExposureCalculator.swift`
- Test: `test_metering_view_model_calibration_source.swift`

- [ ] **Step 1: Write source test**

Check that the view model has a calibration store, active native lens key, active calibration status, and applies calibration before converting EV to Zone.

- [ ] **Step 2: Verify source test fails**

Run: `xcrun swiftc -parse-as-library test_metering_view_model_calibration_source.swift -o /tmp/test_metering_view_model_calibration_source && /tmp/test_metering_view_model_calibration_source`

- [ ] **Step 3: Add calibrated EV path**

Add `calibratedEV(for:)`, use it in `addMeteringPoint` and `remeterPoint`, and refresh exposure when calibration changes.

- [ ] **Step 4: Verify source test passes**

Run the same command. Expected: PASS.

### Task 4: Settings UI And Top Toolbar

**Files:**
- Create: `LightMeter/Views/SettingsView.swift`
- Modify: `LightMeter/Views/TopToolbar.swift`
- Modify: `LightMeter/Views/MainMeteringView.swift`
- Modify: `LightMeter/Views/FilmSelectorView.swift`
- Test: `test_calibration_ui_source.swift`

- [ ] **Step 1: Write source test**

Check for gear settings button, centered film selector, centered film popover triangle, settings sheet, calibration status display, and three calibration actions.

- [ ] **Step 2: Verify source test fails**

Run: `xcrun swiftc -parse-as-library test_calibration_ui_source.swift -o /tmp/test_calibration_ui_source && /tmp/test_calibration_ui_source`

- [ ] **Step 3: Implement UI**

Add settings sheet and calibration actions. Keep film selection anchored to center.

- [ ] **Step 4: Verify source test passes**

Run the same command. Expected: PASS.

### Task 5: Full Verification

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run all source tests**

Run all existing `xcrun swiftc` source tests.

- [ ] **Step 2: Run formatting check**

Run: `git diff --check`

- [ ] **Step 3: Build iOS app**

Run: `xcodebuild -project LightMeter.xcodeproj -scheme LightMeter -destination generic/platform=iOS -derivedDataPath /private/tmp/LightMeterDerivedData CODE_SIGNING_ALLOWED=NO build`
