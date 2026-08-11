# BG3WASDMacOS

Minimal keyboard-only direct movement for the native macOS build of Baldur's
Gate 3. The bootstrap enables the independently implemented, exact-build-gated
`Ext.Movement` capability in bg3se-macos. W/A/S/D are mapped to BG3's existing
`CharacterMove*` commands through the player's input config; BG3 retains
ownership of movement, animation, collision, terrain, and gameplay-state
checks. While enabled, the native capability also suppresses the overlapping
keyboard camera-pan flag; mouse camera rotation remains available.

Combat automatically suspends the direct-movement unlock and restores BG3's
vanilla keyboard camera controls. Leaving combat resumes direct W/A/S/D
movement and its camera-pan blocker without changing the configured preference.

The behavior and command-binding design were researched with reference to
[Ch4nKyy/BG3WASD](https://github.com/Ch4nKyy/BG3WASD), licensed under GPL-3.0.
No Windows code address, x86 instruction patch, loader, or controller feature
is used by this native ARM64 implementation.

This directory is distributed under the repository's GPL-3.0 terms and modding
exception.
