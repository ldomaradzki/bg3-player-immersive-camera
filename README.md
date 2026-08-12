# BG3 Player Immersive Camera

A native macOS camera and direct-movement experience for Baldur's Gate 3.

Player Immersive Camera brings the camera down into the world, puts movement on
W/A/S/D, and keeps the controlled character framed while exploring. It is not a
Windows mod running through a compatibility layer: the Lua profile talks to
native camera, input, movement, and AppKit UI extensions in `bg3se-macos`.

> [!IMPORTANT]
> This is an early, version-specific build. It currently targets Baldur's Gate 3
> `4.1.1.7398727` on Apple Silicon and requires the matching
> [`compat/bg3-7398727`](https://github.com/tdimino/bg3se-macos/tree/compat/bg3-7398727)
> build of `bg3se-macos`. A normal upstream Script Extender build does not yet
> contain the native APIs used here.

## What it does

- Direct W/A/S/D character movement during exploration
- Mouse-controlled horizontal and vertical camera rotation
- Over-the-shoulder framing with responsive character follow
- Smooth two-position close/far zoom on the scroll wheel
- Adjustable FOV, zoom, framing, pitch limits, and vertical inversion
- Adaptive framing while hiding and an FOV increase while moving
- Automatic return to BG3's tactical camera and vanilla keyboard behavior in
  combat, with the immersive profile restored afterward
- A small native settings panel toggled with `\`

Controller mode is intentionally out of scope. The mod keeps BG3 in its native
keyboard-and-mouse interface.

## Installation

1. Install the matching `bg3se-macos` build for BG3 `4.1.1.7398727`.
2. Copy `Mods/BG3PlayerImmersiveCamera` into:

   ```text
   ~/Documents/Larian Studios/Baldur's Gate 3/Mods/
   ```

3. Back up
   `~/Documents/Larian Studios/Baldur's Gate 3/PlayerProfiles/Public/inputconfig_p1.json`.
4. Add or merge these keyboard bindings in that file:

   ```json
   {
       "CharacterMoveBackward": ["key:s"],
       "CharacterMoveForward": ["key:w"],
       "CharacterMoveLeft": ["key:a"],
       "CharacterMoveRight": ["key:d"]
   }
   ```

5. Launch BG3 and load a save. Press `\` once to open the settings panel.

The mod is loaded as a loose Script Extender mod and does not need to be added
to `modsettings.lsx`.

## Settings

The native panel currently exposes:

- Enable Player Immersive Camera
- Field of view
- Close and far zoom distances
- Horizontal and vertical framing offsets
- Minimum and maximum camera pitch
- Invert vertical camera movement

Changes apply live. Defaults are kept in
`Mods/BG3PlayerImmersiveCamera/ScriptExtender/Lua/CameraConfig.lua`; settings
persistence is planned but not implemented yet.

## Compatibility and safety

BG3 internals change between game builds. The native extender gates its hooks
to the supported executable, and unsupported builds should fail closed instead
of applying unknown offsets. Do not replace or rebuild the extender while BG3
is running: quit the game completely, build or install, and then relaunch.

The current build has been tested on Apple Silicon with BG3 `4.1.1.7398727`.
Intel Macs and other game builds are not currently supported.

## Uninstall

Quit BG3, remove the `BG3PlayerImmersiveCamera` directory from the game's
`Mods` folder, and remove the four `CharacterMove*` bindings if you want W/A/S/D
to return entirely to BG3's default camera controls.

## Project structure

- This repository contains the installable Lua profile and its defaults.
- Native engine integration is maintained in the `compat/bg3-7398727` branch of
  `bg3se-macos`.
- The old standalone WASD experiment is no longer needed; camera and movement
  are one coordinated profile here.

See [Architecture](docs/ARCHITECTURE.md) for the boundary between the Lua mod
and the native extender.

## Credits

- [Ersh's BG3 Native Camera Tweaks](https://github.com/ersh1/BG3_NativeCameraTweaks)
  for the original Windows project and camera behavior reference
- [Ch4nKyy's BG3WASD](https://github.com/Ch4nKyy/BG3WASD) for movement design
  reference
- [tdimino's bg3se-macos](https://github.com/tdimino/bg3se-macos), which
  provides the native macOS foundation

This project is an independent native macOS implementation and does not ship
the Windows DLLs from those projects.

## License

GPL-3.0-or-later with the project's modding and linking exceptions. See
[LICENSE](LICENSE) and [EXCEPTIONS](EXCEPTIONS).
