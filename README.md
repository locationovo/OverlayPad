# OverlayPad

[English](README.md) | [简体中文](README.zh-CN.md)

A customizable virtual gamepad, designed for touchscreen gaming.
Works with UNDERTALE/DELTARUNE and any game/app that supports gamepads (with four directional keys).

## Features

- Long-press the floating ball to hide/restore controls
- Presets can be exported/imported
- Debug console can be enabled at compile time with `make DEBUG=1`

## Requirements

- Target game or app must support gamepad input (GameController), otherwise the virtual gamepad won't work
- iOS 15+
- Additional permission declarations may be required on visionOS

## Usage

Inject `OverlayPad.dylib` into the target app. Any of the following works:

- Inject into IPA then re-sign / install via TrollStore
- Sideloading environments such as LiveContainer

## License

This project is licensed under [LGPL-3.0](LICENSE).

Forks, modifications, and redistribution are welcome.
Contact: locationovo@outlook.com