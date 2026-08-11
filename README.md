# Native Camera Tweaks for macOS

This is the native macOS bootstrap for the in-progress port. It requires the
matching `bg3se-macos` camera build and enables mouse-driven pitch plus expanded
zoom limits whenever the client camera becomes available.

Edit `CameraConfig.lua` to change the initial pitch, pitch limits, sensitivity,
vertical-input direction, or exploration/combat zoom ranges. The current
implementation covers free mouse pitch and normal, tactical, and alternate
zoom bounds, plus native AiGrid floor protection. FOV and camera-offset
overrides are implemented but disabled by default; set their `Enabled` flags
after choosing preferred values. An in-game settings UI is still pending.
Controller-specific camera input is not part of the current macOS target.

Install the `BG3NativeCameraTweaks` directory under:

`~/Documents/Larian Studios/Baldur's Gate 3/Mods/`

## Native WASD prototype

`BG3WASDMacOS` is the separate keyboard-only movement bootstrap. It requires a
matching bg3se-macos build with `Ext.Movement`, keeps keyboard/mouse UI active,
does not enable or emulate a controller, and blocks BG3's overlapping keyboard
camera pan while direct movement is active. Mouse camera rotation remains
available. Install its directory beside the camera mod, then add these
bindings to `PlayerProfiles/Public/inputconfig_p1.json`:

```json
{
    "CharacterMoveBackward": ["key:s"],
    "CharacterMoveForward": ["key:w"],
    "CharacterMoveLeft": ["key:a"],
    "CharacterMoveRight": ["key:d"]
}
```

Back up an existing input config before merging the keys. Removing the four
bindings and the `BG3WASDMacOS` directory restores vanilla input; the native
guard is also restored by `Ext.Movement.DisableKeyboardMovement()` within a
running process.
