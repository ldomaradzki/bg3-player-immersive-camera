# Architecture

BG3 Player Immersive Camera is split into two cooperating projects.

## Lua profile

This repository owns the user-facing behavior and configuration:

- enables and disables the complete exploration profile;
- coordinates pitch, zoom, FOV, offsets, follow, and adaptive framing;
- enables direct keyboard movement alongside the camera;
- restores vanilla camera and keyboard behavior during combat;
- connects the native settings panel to live configuration changes.

The entry point is
`Mods/BG3PlayerImmersiveCamera/ScriptExtender/Lua/BootstrapServer.lua`.

## Native extender

The `compat/bg3-7398727` branch of `bg3se-macos` owns the version-sensitive
integration with the game and macOS:

- camera-definition discovery and overrides;
- mouse pitch, zoom interpolation, and floor protection;
- keyboard state and direct character movement;
- combat-aware native behavior;
- the minimal AppKit settings panel and its Lua bridge.

Keeping this layer in the extender avoids placing executable patches or a
second injected library in the mod package. It also gives all native hooks one
place to validate the exact BG3 executable version.

## Runtime flow

1. `bg3se-macos` loads and validates the supported BG3 process.
2. The loose mod bootstrap waits for the client camera and entity types.
3. Lua passes the configured profile to `Ext.Camera` and `Ext.Movement`.
4. Native code applies changes only while the exploration profile is active.
5. Combat restores vanilla behavior; exploration reapplies the profile.
6. The `\` hotkey opens an AppKit panel whose callbacks update the same Lua
   configuration live.

## Version support

Native offsets and hooks are build-specific. Supporting another BG3 release
requires validating the extender against that executable before updating the
compatibility declaration. The Lua package alone cannot add support for a new
game build.
