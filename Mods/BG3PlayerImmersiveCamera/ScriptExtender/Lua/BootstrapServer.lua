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
            Ext.Print("[PlayerImmersiveCamera] Could not enable W/A/S/D: " ..
                tostring(movementReason))
        end
    end

    stopRetrying()
    profileEnabled = true
    Ext.Print("[PlayerImmersiveCamera] Camera controls enabled")
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
            Ext.Print("[PlayerImmersiveCamera] Could not restore vanilla W/A/S/D: " ..
                tostring(movementReason))
        end
    end

    profileEnabled = false
    Ext.Print("[PlayerImmersiveCamera] Immersive profile disabled; vanilla camera and movement restored")
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

    Ext.Print("[PlayerImmersiveCamera] Camera not ready yet: " .. tostring(reason))
    retryTimer = Ext.Timer.WaitFor(250, function()
        retryCount = retryCount + 1
        local enabled, retryReason = enableCamera()
        if enabled then
            return
        end

        if retryCount >= maxRetries then
            stopRetrying()
            Ext.Print("[PlayerImmersiveCamera] Could not enable camera: " ..
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

local function reportPanelApply(name, ok, reason)
    if not ok then
        Ext.Print("[PlayerImmersiveCamera] Could not apply " .. name .. ": " ..
            tostring(reason))
    end
end

local function refreshAdaptiveBaseline()
    if Config.Adaptive ~= nil and Config.Adaptive.Enabled and
        Ext.Camera.EnableAdaptive ~= nil then
        local ok, reason = Ext.Camera.EnableAdaptive(Config.Adaptive)
        reportPanelApply("adaptive framing", ok, reason)
    end
end

local function suspendAdaptiveBaseline()
    if Config.Adaptive ~= nil and Config.Adaptive.Enabled and
        Ext.Camera.DisableAdaptive ~= nil then
        local ok, reason = Ext.Camera.DisableAdaptive()
        reportPanelApply("adaptive framing suspension", ok, reason)
    end
end

local function applyPanelValue(key, value)
    if key == "Enabled" then
        setProfileEnabled(value ~= 0)
        return
    elseif key == "FOV" then
        local fov = math.max(40.0, math.min(90.0, value))
        Config.FOV.Exploration.Close = fov
        Config.FOV.Exploration.Far = fov
        if profileRequested then
            suspendAdaptiveBaseline()
            local ok, reason = Ext.Camera.SetFOV(Config.FOV)
            reportPanelApply("field of view", ok, reason)
            refreshAdaptiveBaseline()
        end
    elseif key == "CloseZoom" or key == "FarZoom" then
        if key == "CloseZoom" then
            Config.ZoomToggle.Close = math.max(1.5, math.min(6.0, value))
            if Config.ZoomToggle.Close >= Config.ZoomToggle.Far then
                Config.ZoomToggle.Far = Config.ZoomToggle.Close + 0.25
            end
        else
            Config.ZoomToggle.Far = math.max(4.0, math.min(15.0, value))
            if Config.ZoomToggle.Far <= Config.ZoomToggle.Close then
                Config.ZoomToggle.Close = Config.ZoomToggle.Far - 0.25
            end
        end
        if profileRequested then
            local ok, reason = Ext.Camera.EnableZoomToggle(Config.ZoomToggle)
            reportPanelApply("zoom distances", ok, reason)
        end
    elseif key == "HorizontalOffset" or key == "VerticalOffset" then
        if key == "HorizontalOffset" then
            Config.Offsets.Exploration.Horizontal =
                math.max(-2.0, math.min(2.0, value))
        else
            Config.Offsets.Exploration.Vertical =
                math.max(-1.0, math.min(3.0, value))
        end
        if profileRequested then
            suspendAdaptiveBaseline()
            local ok, reason = Ext.Camera.SetOffsets(Config.Offsets)
            reportPanelApply("camera offsets", ok, reason)
            refreshAdaptiveBaseline()
        end
    elseif key == "MinimumPitch" or key == "MaximumPitch" or
        key == "InvertVertical" then
        if key == "MinimumPitch" then
            Config.Min = math.max(-30.0, math.min(20.0, value))
            if Config.Min >= Config.Max then Config.Max = Config.Min + 1.0 end
        elseif key == "MaximumPitch" then
            Config.Max = math.max(20.0, math.min(70.0, value))
            if Config.Max <= Config.Min then Config.Min = Config.Max - 1.0 end
        else
            Config.Invert = value ~= 0
        end

        if profileRequested then
            local state = Ext.Camera.GetState ~= nil and
                Ext.Camera.GetState() or nil
            local currentPitch = state ~= nil and state.PitchDegrees or
                Config.Initial
            Config.Initial = math.max(Config.Min,
                math.min(Config.Max, currentPitch))
            local ok, reason = Ext.Camera.EnableMousePitch(Config)
            reportPanelApply("pitch settings", ok, reason)
        end
    end
end

local function togglePanel()
    if Ext.UI ~= nil and Ext.UI.ToggleNativePanel ~= nil then
        Ext.UI.ToggleNativePanel(
            "BG3 Player Immersive Camera",
            "Camera and movement settings",
            {
                Enabled = profileRequested,
                FOV = Config.FOV.Exploration.Close,
                CloseZoom = Config.ZoomToggle.Close,
                FarZoom = Config.ZoomToggle.Far,
                HorizontalOffset = Config.Offsets.Exploration.Horizontal,
                VerticalOffset = Config.Offsets.Exploration.Vertical,
                MinimumPitch = Config.Min,
                MaximumPitch = Config.Max,
                InvertVertical = Config.Invert,
            },
            applyPanelValue)
        return
    end

    Ext.Print("[PlayerImmersiveCamera] Native UI is unavailable in this bg3se-macos build")
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
    Ext.Print("[PlayerImmersiveCamera] Settings hotkey: " ..
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
