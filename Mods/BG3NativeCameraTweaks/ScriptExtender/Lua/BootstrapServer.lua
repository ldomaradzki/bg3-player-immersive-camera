local Config = require("CameraConfig")

-- bg3se-macos currently loads mod bootstraps in its primary Lua VM while the
-- separate client VM remains script-empty. Ext.Camera itself is client-world
-- scoped, so this bootstrap never writes server ECS state.

local retryTimer = nil
local retryCount = 0
local maxRetries = 120

local function stopRetrying()
    if retryTimer ~= nil then
        Ext.Timer.Cancel(retryTimer)
        retryTimer = nil
    end
end

local function enableCamera()
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

    stopRetrying()
    Ext.Print("[NativeCameraTweaks] Mouse pitch and expanded zoom enabled")
    return true
end

local function beginEnable()
    stopRetrying()
    retryCount = 0

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

Ext.Events.SessionLoaded:Subscribe(beginEnable)
Ext.Events.GameStateChanged:Subscribe(function(event)
    if event.ToState == "Running" then
        beginEnable()
    end
end)

-- Safe-mode builds cannot receive Osiris-backed session events. Start once at
-- bootstrap and let the Lua timer retry until the client camera exists.
beginEnable()
