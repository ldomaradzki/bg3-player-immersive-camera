# Native Camera Tweaks for macOS

This is the native macOS bootstrap for the in-progress port. It requires the
matching `bg3se-macos` camera build and enables mouse-driven pitch whenever a
save reaches the running state.

Edit `CameraConfig.lua` to change the initial pitch, pitch limits, sensitivity,
or vertical-input direction. The current implementation covers free mouse
pitch. Zoom bounds, FOV, controller input, clipping protection, and an in-game
settings UI are still pending.

Install the `BG3NativeCameraTweaks` directory under:

`~/Documents/Larian Studios/Baldur's Gate 3/Mods/`
