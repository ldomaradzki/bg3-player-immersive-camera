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
    if Ext.Camera == nil or Ext.Camera.EnableMousePitch == nil then
        return false, "this build of bg3se-macos does not provide mouse pitch"
    end

    -- Camera TypeIds are registered late during startup on the current game
    -- build. Refreshing here makes save loads deterministic.
    if Ext.Entity ~= nil and Ext.Entity.Discover ~= nil then
        Ext.Entity.Discover()
    end

    local ok, reason = Ext.Camera.EnableMousePitch(Config)
    if ok then
        stopRetrying()
        Ext.Print("[NativeCameraTweaks] Mouse pitch enabled")
        return true
    end

    return false, reason
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
