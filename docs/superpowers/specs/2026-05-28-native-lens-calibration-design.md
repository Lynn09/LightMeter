# Native Lens Calibration Design

## Goal

LightMeter is intended to replace a physical light meter. The current EV calculation is based on sampled camera-frame luminance, so it needs a calibration system that can connect iPhone camera data to a trustworthy EV reference.

The calibration model must avoid confusing simulated film-camera focal lengths with the actual iPhone camera hardware. Calibration applies to the native iPhone camera lens that produced the image data. Simulated focal lengths only affect framing, crop, zoom, and metering-point coordinate mapping.

## Product Model

Calibration has three trust levels:

1. Professional calibration
   - Reference source: physical light meter.
   - User measures an 18% gray card with a physical meter and enters the reference EV100.
   - Highest trust level.

2. Standard calibration
   - Reference source: 18% gray card plus iPhone exposure parameters.
   - User points the current native lens at an 18% gray card.
   - The app locks or stabilizes iPhone exposure, reads ISO, exposure duration, and lens aperture, then derives EV100.
   - Multiple samples are averaged to reduce noise and auto-exposure drift.

3. Quick calibration
   - Reference source: iPhone auto-exposure parameters in the current scene.
   - No external target is required.
   - Lowest cost and lowest trust because the reference scene may not be middle gray.

The main UI should expose the active calibration source, not only a generic calibrated state:

- `Professional +0.2 EV`
- `Standard -0.1 EV`
- `Quick +0.5 EV`
- `Uncalibrated`

## Calibration Target

Calibration is stored per native iPhone camera lens, not per simulated focal length.

Example:

```text
Native wide camera
  calibration offset: Standard +0.1 EV
  simulated focal lengths: 28mm, 35mm, 50mm

Native ultra-wide camera
  calibration offset: Uncalibrated
  simulated focal lengths: 24mm

Native telephoto camera
  calibration offset: Professional -0.2 EV
  simulated focal lengths: 85mm, 105mm
```

The first implementation can identify native lenses using an internal stable key derived from `AVCaptureDevice.DeviceType`, position, localized name, and unique ID where available.

## EV Flow

The calibrated EV pipeline is:

```text
User taps metering point in simulated focal length preview
  -> preview coordinate maps to native camera frame coordinate
  -> app samples luminance from the native camera frame
  -> uncalibrated EV is calculated from sampled luminance
  -> native-lens calibration offset is applied
  -> calibrated EV is converted to Zone and exposure recommendations
```

Formula:

```text
calibratedEV = measuredEV + calibrationOffset
```

`calibrationOffset` is:

```text
referenceEV - measuredEV
```

For professional calibration, `referenceEV` is user-entered EV100 from the physical meter.

For standard and quick calibration, `referenceEV` is derived from iPhone camera parameters:

```text
EV100 = log2(N^2 / t) - log2(ISO / 100)
```

Where:

- `N` is `AVCaptureDevice.lensAperture`
- `t` is `AVCaptureDevice.exposureDuration`
- `ISO` is `AVCaptureDevice.iso`

## Settings Entry And Top Toolbar

The top toolbar changes to a three-part layout:

```text
[Settings gear]        [Film selector]        [EV / ISO / calibration status]
```

Rules:

- The settings gear sits at the top-left and opens the settings page.
- The film selector is centered in the toolbar.
- EV, ISO, and calibration status remain on the right as read-only status.
- The film selector popover anchors to the centered film button.
- The film selector triangle indicator moves to the horizontal center of the popover and visually points to the centered film button.

## Settings Page

The settings page contains a metering calibration section.

Recommended sections:

1. Current calibration
   - Current native lens name.
   - Active calibration level.
   - Active EV offset.
   - Last calibration time.

2. Native lens calibration list
   - One row per available native iPhone lens.
   - Each row shows calibration level, offset, and simulated focal lengths that currently use the lens.

3. Calibration actions
   - Professional calibration.
   - Standard calibration.
   - Quick calibration.
   - Reset calibration for current native lens.
   - Reset all calibration data.

## Calibration Flows

### Professional Calibration

1. User opens Settings > Metering Calibration > Professional.
2. App asks the user to select or confirm the current native lens.
3. User points the camera at an 18% gray card.
4. User enters reference EV100 from a physical light meter.
5. App samples the same gray card area and computes measured EV.
6. App stores `referenceEV - measuredEV` as a professional offset for the current native lens.

### Standard Calibration

1. User opens Settings > Metering Calibration > Standard.
2. App instructs the user to fill the frame with an 18% gray card.
3. App waits for iPhone auto-exposure to stabilize.
4. App locks exposure if supported.
5. App takes multiple samples.
6. For each sample, app derives iPhone EV100 from ISO, exposure duration, and aperture.
7. App computes measured EV from image luminance.
8. App averages sample offsets and stores the result as a standard offset.

### Quick Calibration

1. User opens Settings > Metering Calibration > Quick.
2. App uses the current scene.
3. App waits briefly for auto-exposure to stabilize.
4. App reads iPhone exposure parameters and derives EV100.
5. App samples center-weighted frame luminance.
6. App stores the resulting offset as a quick offset.

Quick calibration should include UI copy that it is scene-dependent and less trustworthy than gray-card calibration.

## Exposure Locking

Calibration should use `AVCaptureDevice` exposure controls where supported:

- Continuous auto exposure while stabilizing.
- `exposureMode = .locked` after stabilization.
- `setExposureModeCustom(duration:iso:)` only if custom exposure is needed later.

The first version should avoid manual custom exposure unless required. Locking the stabilized exposure is enough for standard and quick calibration.

If locking is unavailable, the app should still allow calibration but mark it as lower confidence or show a warning.

## Data Model

Suggested model:

```swift
enum CalibrationLevel: String, Codable {
    case professional
    case standard
    case quick
}

struct LensCalibration: Codable, Identifiable {
    let id: String
    let nativeLensKey: String
    let level: CalibrationLevel
    let evOffset: Double
    let sampleCount: Int
    let createdAt: Date
    let deviceModel: String
    let appVersion: String
}
```

Selection rule:

```text
For the current native lens, use the highest-trust available calibration:
Professional > Standard > Quick
```

Storage can start with `UserDefaults` or a small JSON file. The first version does not need cloud sync.

## Error Handling

Calibration should handle:

- Camera permission missing.
- No current native lens.
- Exposure parameters unavailable.
- Exposure lock unsupported.
- Gray-card sample too dark or too bright.
- Sample variance too high across repeated standard calibration samples.
- User-entered EV out of reasonable range.

For high variance, standard calibration should ask the user to retry instead of saving a weak offset.

## Testing

Unit-level tests:

- EV100 derivation from aperture, shutter, and ISO.
- Offset calculation.
- Calibration priority selection.
- Applying native-lens offset to measured EV.
- Simulated focal length does not change calibration key.

Source-level UI tests can check:

- Settings gear exists in the top toolbar.
- Film selector is centered.
- Film popover triangle is centered.
- Calibration status is displayed in the top status area.

Manual validation:

1. Use a physical meter and gray card to compare professional calibration output.
2. Repeat standard calibration five times under stable lighting and confirm offset variance is small.
3. Switch between simulated focal lengths that use the same native lens and confirm the same calibration status is applied.
4. Switch to a different native lens and confirm its independent calibration state is used.

## Out Of Scope For First Version

- Cloud sync.
- Per-simulated-focal-length calibration.
- Per-film calibration.
- Color-temperature-specific calibration profiles.
- Cross-device calibration sharing.
- Custom manual camera exposure as a general shooting control.
