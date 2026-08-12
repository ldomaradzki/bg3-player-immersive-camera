-- BG3 Player Immersive Camera defaults for macOS.
-- Pitch is measured in degrees. Set Invert to true to reverse vertical input.
return {
    -- Toggle the complete third-person profile. On Macs whose function row is
    -- configured for media controls, hold Fn while pressing this key.
    Hotkey = {
        Enabled = true,
        Key = "BACKSLASH",
        ToggleMovement = true,
    },

    Initial = 25.0,
    -- Keep the camera above the terrain and below the near-vertical tactical
    -- view while retaining a useful third-person pitch range.
    Min = -10.0,
    Max = 42.5,
    Sensitivity = 0.25,
    Invert = false,

    -- Authoritative camera-definition limits. These match the Windows mod's
    -- defaults and expand exploration zoom without changing the game's zoom
    -- interpolation. Combat is intentionally omitted and remains vanilla.
    ZoomLimits = {
        Exploration = {
            Min = 1.5,
            Max = 20.0,
            TacticalMin = 10.0,
            TacticalMax = 50.0,
            AltMin = 10.0,
            AltMax = 40.0,
        },
    },

    -- Mouse wheel selects one of two locked distances. These values are kept
    -- here so a future settings menu can edit the same configuration.
    ZoomToggle = {
        Enabled = true,
        Close = 2.75,
        Far = 7.5,
        -- Exponential transition time in seconds; use 0 for an instant snap.
        SmoothTime = 0.20,
        Invert = false,
    },

    -- Keep the unlocked camera above BG3's native AiGrid floor height. The
    -- distance is reduced only when the pitched camera would enter terrain.
    FloorProtection = {
        Enabled = true,
        FloorOffset = 0.1,
        MinZoom = 1.5,
        Radius = 0.25,
    },

    -- Optional Windows-parity definition overrides. Leave disabled to retain
    -- the game's original FOV and framing while still using pitch and zoom.
    FOV = {
        Enabled = true,
        Exploration = {
            Close = 60.0,
            Far = 60.0,
            Tactical = 25.0,
            AltClose = 50.0,
            AltFar = 50.0,
        },
    },
    Offsets = {
        -- Over-the-shoulder composition: move the camera slightly right and
        -- raise its target so the controlled character sits left and low in
        -- the frame.
        Enabled = true,
        Exploration = {
            Horizontal = 0.625,
            Vertical = 0.725,
        },
    },

    -- Increase BG3's own camera-target translation speed. This keeps the
    -- framing responsive during A/D strafing without directly moving the
    -- camera or interfering with manual mouse rotation.
    Follow = {
        Enabled = true,
        SpeedMultiplier = 2.5,
        ExplorationOnly = true,
    },

    -- Crouching lowers the framing target; camera-target motion widens the
    -- view while running. The exact sneak tag is preferred when available;
    -- the default C/Hide binding mirrors the toggle as a macOS fallback.
    Adaptive = {
        Enabled = true,
        CrouchVerticalDelta = -0.225,
        CrouchSmoothTime = 0.18,
        -- Deliberately obvious for the first live validation; we can reduce
        -- this after confirming the movement speed threshold on this build.
        RunFOVBoost = 10.0,
        RunSpeedThreshold = 0.5,
        RunSmoothTime = 0.30,
    },
}
