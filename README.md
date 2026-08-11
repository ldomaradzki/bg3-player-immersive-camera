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
