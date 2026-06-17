# Film Light Meter App

A mobile light meter app designed for film photographers who want a practical, affordable alternative to dedicated handheld light meters.

The app uses the phone camera to estimate scene brightness and converts it into usable exposure recommendations, including aperture, shutter speed, and ISO combinations. It is designed around real film-shooting workflows such as spot metering, center-weighted metering, exposure compensation, and gray-card calibration.

## Why This Project

Handheld light meters are reliable, but they are often expensive and not always convenient to carry. For many film photographers, especially beginners, the phone camera is already available and capable of providing useful brightness information.

This project explores how a smartphone can be used as a practical reflective light meter by combining camera brightness sampling, exposure value calculation, calibration, and a photographer-friendly user interface.

## Features

* Camera-based reflective metering
* Spot metering for selected areas of the frame
* Center-weighted metering for general shooting
* Manual film ISO selection
* Aperture-priority exposure calculation
* Shutter-speed recommendation based on standard camera shutter steps
* Exposure compensation support
* Gray-card calibration for improved consistency
* Film-photography-oriented workflow and UI

## Core Concept

The app estimates exposure using the relationship between aperture, shutter speed, ISO, and exposure value.

At a high level, the workflow is:

```text
Camera brightness sampling
→ Scene brightness estimation
→ EV calculation
→ ISO / aperture / shutter-speed conversion
→ User-facing exposure recommendation
```

For example, after estimating the scene exposure value, the app can recommend combinations such as:

```text
ISO 400
f/8
1/125s
```

The goal is not to fully replace a professional incident light meter, but to provide a practical and accessible reflective metering tool for everyday film photography.

## Gray-Card Calibration

Because different phone cameras, sensors, lenses, and image-processing pipelines behave differently, the app supports gray-card calibration.

The calibration workflow helps the app understand how a standard middle-gray reference appears on the specific device. This makes the metering result more consistent across different lighting environments and phone models.

Calibration can help correct:

* Device-specific sensor response
* Lens and camera pipeline differences
* Brightness interpretation bias
* Exposure offset between the phone camera and film shooting workflow

## AI-Assisted Development

This project was developed with the help of OpenAI Codex as an AI pair-programming agent.

I used a “vibe coding” workflow to quickly turn product ideas into working features. Codex was used to assist with:

* Rapid prototyping of UI interactions
* Camera API integration
* Exposure calculation logic
* Refactoring and code organization
* Debugging implementation details
* Exploring alternative product flows

The AI-generated code was not used blindly. I reviewed, tested, modified, and integrated the implementation manually to ensure the app’s behavior matched the intended photography workflow.

This project was also an experiment in AI-assisted software development: using Codex not just to generate isolated snippets, but to continuously support product iteration from concept to functional application.

## Tech Highlights

* Mobile camera integration
* Real-time brightness sampling
* Exposure value calculation
* Manual ISO / aperture / shutter mapping
* Calibration-based correction
* Photographer-focused interaction design
* AI-assisted development workflow with Codex

## Limitations

This app works as a reflective light meter, meaning it measures the light reflected from the subject or scene. Like all reflective meters, it can be affected by subject reflectance.

For example:

* Snow or white walls may cause underexposure
* Dark clothing or black surfaces may cause overexposure
* Backlit scenes may require manual exposure compensation
* Incident metering still requires a dedicated light meter or diffuser-based setup

For best results, users should combine the app with gray-card calibration, exposure compensation, and practical film photography judgment.

## Roadmap

* Zone System support
* Multi-point metering
* Incident-metering simulation with diffuser accessory
* Film stock presets
* Calibration profiles per device and camera lens
* Exposure history and shooting notes
* Apple Watch / widget support

## License

This project is for educational and personal photography use.
