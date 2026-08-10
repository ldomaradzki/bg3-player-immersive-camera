-- Native Camera Tweaks defaults for macOS.
-- Pitch is measured in degrees. Set Invert to true to reverse vertical input.
return {
    Initial = 25.0,
    Min = -85.0,
    Max = 85.0,
    Sensitivity = 0.25,
    Invert = false,

    -- Authoritative camera-definition limits. These match the Windows mod's
    -- defaults and expand normal exploration/combat zoom without changing the
    -- game's zoom interpolation.
    ZoomLimits = {
        Exploration = {
            Min = 0.5,
            Max = 20.0,
            TacticalMin = 10.0,
            TacticalMax = 50.0,
            AltMin = 10.0,
            AltMax = 40.0,
        },
        Combat = {
            Min = 0.5,
            Max = 20.0,
            TacticalMin = 10.0,
            TacticalMax = 50.0,
            AltMin = 10.0,
            AltMax = 40.0,
        },
    },
}
