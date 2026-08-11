local Config = require("CameraConfig")

-- bg3se-macos currently loads mod bootstraps in its primary Lua VM while the
-- separate client VM remains script-empty. Ext.Camera itself is client-world
-- scoped, so this bootstrap never writes server ECS state.

local retryTimer = nil
local retryCount = 0
local maxRetries = 120
local profileRequested = true
local profileEnabled = false
local hotkeyDown = false
local hotkeyTimer = nil

local function stopRetrying()
    if retryTimer ~= nil then
        Ext.Timer.Cancel(retryTimer)
        retryTimer = nil
    end
end

local function enableCamera()
    if not profileRequested then
        return false, "third-person profile is disabled"
    end

    if Ext.Camera == nil or Ext.Camera.EnableMousePitch == nil or
        Ext.Camera.SetZoomLimits == nil then
        return false, "this build of bg3se-macos does not provide the required camera controls"
    end

    -- Camera TypeIds are registered late during startup on the current game
    -- build. Refreshing here makes save loads deterministic.
    if Ext.Entity ~= nil and Ext.Entity.Discover ~= nil then
        Ext.Entity.Discover()
    end

    local pitchOk, pitchReason = Ext.Camera.EnableMousePitch(Config)
    if not pitchOk then
        return false, pitchReason
    end

    local zoomOk, zoomReason = Ext.Camera.SetZoomLimits(Config.ZoomLimits)
    if not zoomOk then
        return false, zoomReason
    end

    if Config.ZoomToggle ~= nil and Config.ZoomToggle.Enabled then
        if Ext.Camera.EnableZoomToggle == nil then
            return false, "this build of bg3se-macos does not provide two-state zoom"
        end
        local toggleOk, toggleReason = Ext.Camera.EnableZoomToggle(
            Config.ZoomToggle)
        if not toggleOk then
            return false, toggleReason
        end
    elseif Ext.Camera.DisableZoomToggle ~= nil then
        Ext.Camera.DisableZoomToggle()
    end

    if Config.FloorProtection ~= nil and Config.FloorProtection.Enabled then
        if Ext.Camera.EnableFloorProtection == nil then
            return false, "this build of bg3se-macos does not provide floor protection"
        end
        local floorOk, floorReason = Ext.Camera.EnableFloorProtection(
            Config.FloorProtection)
        if not floorOk then
            return false, floorReason
        end
    elseif Ext.Camera.DisableFloorProtection ~= nil then
        Ext.Camera.DisableFloorProtection()
    end

    if Config.FOV ~= nil and Config.FOV.Enabled then
        if Ext.Camera.SetFOV == nil then
            return false, "this build of bg3se-macos does not provide FOV control"
        end
        local fovOk, fovReason = Ext.Camera.SetFOV(Config.FOV)
        if not fovOk then
            return false, fovReason
        end
    elseif Ext.Camera.ClearFOV ~= nil then
        Ext.Camera.ClearFOV()
    end

    if Config.Offsets ~= nil and Config.Offsets.Enabled then
        if Ext.Camera.SetOffsets == nil then
            return false, "this build of bg3se-macos does not provide camera offsets"
        end
        local offsetsOk, offsetsReason = Ext.Camera.SetOffsets(Config.Offsets)
        if not offsetsOk then
            return false, offsetsReason
        end
    elseif Ext.Camera.ClearOffsets ~= nil then
        Ext.Camera.ClearOffsets()
    end

    if Config.Follow ~= nil and Config.Follow.Enabled then
        if Ext.Camera.SetFollowSpeed == nil then
            return false, "this build of bg3se-macos does not provide camera follow-speed control"
        end
        local followOk, followReason = Ext.Camera.SetFollowSpeed(Config.Follow)
        if not followOk then
            return false, followReason
        end
    elseif Ext.Camera.ClearFollowSpeed ~= nil then
        Ext.Camera.ClearFollowSpeed()
    end

    if Config.Adaptive ~= nil and Config.Adaptive.Enabled then
        if Ext.Camera.EnableAdaptive == nil then
            return false, "this build of bg3se-macos does not provide adaptive framing"
        end
        local adaptiveOk, adaptiveReason = Ext.Camera.EnableAdaptive(
            Config.Adaptive)
        if not adaptiveOk then
            return false, adaptiveReason
        end
    elseif Ext.Camera.DisableAdaptive ~= nil then
        Ext.Camera.DisableAdaptive()
    end

    if Config.Hotkey ~= nil and Config.Hotkey.ToggleMovement and
        Ext.Movement ~= nil and
        Ext.Movement.EnableKeyboardMovement ~= nil then
        local movementOk, movementReason =
            Ext.Movement.EnableKeyboardMovement()
        if not movementOk then
            Ext.Print("[NativeCameraTweaks] Could not enable W/A/S/D: " ..
                tostring(movementReason))
        end
    end

    stopRetrying()
    profileEnabled = true
    Ext.Print("[NativeCameraTweaks] Camera controls enabled")
    return true
end

local function disableCamera()
    stopRetrying()

    -- Adaptive framing snapshots the configured FOV/offset baseline, so it
    -- must restore that baseline before the definition overrides are cleared.
    if Ext.Camera ~= nil then
        if Ext.Camera.DisableAdaptive ~= nil then
            Ext.Camera.DisableAdaptive()
        end
        if Ext.Camera.DisableZoomToggle ~= nil then
            Ext.Camera.DisableZoomToggle()
        end
        if Ext.Camera.DisableFloorProtection ~= nil then
            Ext.Camera.DisableFloorProtection()
        end
        if Ext.Camera.ClearFollowSpeed ~= nil then
            Ext.Camera.ClearFollowSpeed()
        end
        if Ext.Camera.ClearOffsets ~= nil then
            Ext.Camera.ClearOffsets()
        end
        if Ext.Camera.ClearFOV ~= nil then
            Ext.Camera.ClearFOV()
        end
        if Ext.Camera.ClearZoomLimits ~= nil then
            Ext.Camera.ClearZoomLimits()
        end
        if Ext.Camera.ClearPitch ~= nil then
            Ext.Camera.ClearPitch()
        end
    end

    if Config.Hotkey ~= nil and Config.Hotkey.ToggleMovement and
        Ext.Movement ~= nil and
        Ext.Movement.DisableKeyboardMovement ~= nil then
        local movementOk, movementReason =
            Ext.Movement.DisableKeyboardMovement()
        if not movementOk then
            Ext.Print("[NativeCameraTweaks] Could not restore vanilla W/A/S/D: " ..
                tostring(movementReason))
        end
    end

    profileEnabled = false
    Ext.Print("[NativeCameraTweaks] Third-person profile disabled; vanilla camera and movement restored")
end

local function beginEnable()
    stopRetrying()
    retryCount = 0

    if not profileRequested then
        return
    end

    local ok, reason = enableCamera()
    if ok then
        return
    end

    Ext.Print("[NativeCameraTweaks] Camera not ready yet: " .. tostring(reason))
    retryTimer = Ext.Timer.WaitFor(250, function()
        retryCount = retryCount + 1
        local enabled, retryReason = enableCamera()
        if enabled then
            return
        end

        if retryCount >= maxRetries then
            stopRetrying()
            Ext.Print("[NativeCameraTweaks] Could not enable camera: " ..
                tostring(retryReason))
        end
    end, 250)
end

local function setProfileEnabled(enabled)
    enabled = enabled == true
    if profileRequested == enabled then
        return
    end

    profileRequested = enabled
    if profileRequested then
        beginEnable()
    else
        disableCamera()
    end
end

local function togglePanel()
    if Ext.UI ~= nil and Ext.UI.ToggleNativePanel ~= nil then
        Ext.UI.ToggleNativePanel(
            "Native Camera Tweaks",
            "Camera settings",
            profileRequested,
            function(enabled)
                setProfileEnabled(enabled)
            end)
        return
    end

    Ext.Print("[NativeCameraTweaks] Native UI is unavailable in this bg3se-macos build")
end

if Config.Hotkey ~= nil and Config.Hotkey.Enabled and
    Ext.Input ~= nil and Ext.Input.IsKeyPressed ~= nil then
    hotkeyTimer = Ext.Timer.WaitFor(25, function()
        local down = Ext.Input.IsKeyPressed(Config.Hotkey.Key)
        if down and not hotkeyDown then
            hotkeyDown = true
            togglePanel()
        elseif not down then
            hotkeyDown = false
        end
    end, 25)
    Ext.Print("[NativeCameraTweaks] Settings hotkey: " ..
        tostring(Config.Hotkey.Key))
end

Ext.Events.SessionLoaded:Subscribe(beginEnable)
Ext.Events.GameStateChanged:Subscribe(function(event)
    if event.ToState == "Running" then
        beginEnable()
    end
end)

-- Safe-mode builds cannot receive Osiris-backed session events. Start once at
-- bootstrap and let the Lua timer retry until the client camera exists.
beginEnable()
