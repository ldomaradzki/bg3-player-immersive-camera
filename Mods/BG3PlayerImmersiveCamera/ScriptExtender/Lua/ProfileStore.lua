local ProfileStore = {}

local SETTINGS_PATH = "BG3PlayerImmersiveCamera/settings.json"
local PROFILE_COUNT = 4

local function copyProfile(profile)
    return {
        WheelEnabled = profile.WheelEnabled == true,
        Distance = profile.Distance,
        FOV = profile.FOV,
        HorizontalOffset = profile.HorizontalOffset,
        VerticalOffset = profile.VerticalOffset,
        MinimumPitch = profile.MinimumPitch,
        MaximumPitch = profile.MaximumPitch,
        InvertVertical = profile.InvertVertical == true,
        AdaptiveCrouch = profile.AdaptiveCrouch == true,
        HideGameUI = profile.HideGameUI == true,
    }
end

local function defaultProfile(config, distance, wheelEnabled)
    return {
        WheelEnabled = wheelEnabled,
        Distance = distance,
        FOV = config.FOV.Exploration.Close,
        HorizontalOffset = config.Offsets.Exploration.Horizontal,
        VerticalOffset = config.Offsets.Exploration.Vertical,
        MinimumPitch = config.Min,
        MaximumPitch = config.Max,
        InvertVertical = config.Invert == true,
        AdaptiveCrouch = config.Adaptive.CrouchEnabled == true,
        HideGameUI = false,
    }
end

local function defaults(config)
    local close = config.ZoomToggle.Close
    local far = config.ZoomToggle.Far
    return {
        Version = 1,
        SelectedProfile = 1,
        Profiles = {
            defaultProfile(config, close, true),
            defaultProfile(config, far, true),
            defaultProfile(config, close, false),
            defaultProfile(config, close, false),
        },
    }
end

local function numberOr(value, fallback, minimum, maximum)
    if type(value) ~= "number" then return fallback end
    return math.max(minimum, math.min(maximum, value))
end

local function booleanOr(value, fallback)
    if type(value) == "boolean" then return value end
    return fallback
end

local function mergeProfile(saved, fallback)
    if type(saved) ~= "table" then return copyProfile(fallback) end
    local profile = {
        WheelEnabled = booleanOr(saved.WheelEnabled, fallback.WheelEnabled),
        Distance = numberOr(saved.Distance, fallback.Distance, 1.5, 15.0),
        FOV = numberOr(saved.FOV, fallback.FOV, 40.0, 90.0),
        HorizontalOffset = numberOr(saved.HorizontalOffset,
            fallback.HorizontalOffset, -2.0, 2.0),
        VerticalOffset = numberOr(saved.VerticalOffset,
            fallback.VerticalOffset, -1.0, 3.0),
        MinimumPitch = numberOr(saved.MinimumPitch,
            fallback.MinimumPitch, -30.0, 70.0),
        MaximumPitch = numberOr(saved.MaximumPitch,
            fallback.MaximumPitch, -30.0, 70.0),
        InvertVertical = booleanOr(saved.InvertVertical,
            fallback.InvertVertical),
        AdaptiveCrouch = booleanOr(saved.AdaptiveCrouch,
            fallback.AdaptiveCrouch),
        HideGameUI = booleanOr(saved.HideGameUI, fallback.HideGameUI),
    }
    if profile.MinimumPitch > profile.MaximumPitch then
        profile.MinimumPitch, profile.MaximumPitch =
            profile.MaximumPitch, profile.MinimumPitch
    end
    return profile
end

function ProfileStore.Load(config)
    local state = defaults(config)
    if Ext.IO == nil or Ext.IO.LoadFile == nil or Ext.Json == nil then
        return state
    end

    local contents = Ext.IO.LoadFile(SETTINGS_PATH)
    if type(contents) ~= "string" then return state end

    local ok, saved = pcall(Ext.Json.Parse, contents)
    if not ok or type(saved) ~= "table" then
        Ext.Print("[PlayerImmersiveCamera] Ignoring invalid profile settings")
        return state
    end

    state.SelectedProfile = math.floor(numberOr(
        saved.SelectedProfile, 1, 1, PROFILE_COUNT))
    if type(saved.Profiles) == "table" then
        for index = 1, PROFILE_COUNT do
            state.Profiles[index] = mergeProfile(
                saved.Profiles[index], state.Profiles[index])
        end
    end
    return state
end

function ProfileStore.Save(state)
    if Ext.IO == nil or Ext.IO.SaveFile == nil or Ext.Json == nil then
        return false, "profile persistence APIs are unavailable"
    end

    local ok, encoded = pcall(Ext.Json.Stringify, state)
    if not ok or type(encoded) ~= "string" then
        return false, "could not encode profile settings"
    end
    if not Ext.IO.SaveFile(SETTINGS_PATH, encoded) then
        return false, "could not write profile settings"
    end
    return true
end

return ProfileStore
