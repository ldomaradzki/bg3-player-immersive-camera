-- Minimal native macOS WASD port. BG3 continues to own locomotion, collision,
-- animation, and all gameplay-state checks. The native capability only allows
-- CharacterMove* keyboard bindings while keyboard/mouse UI is active.

if Ext.Movement == nil or Ext.Movement.EnableKeyboardMovement == nil then
    Ext.Print("[BG3WASDMacOS] This bg3se-macos build has no keyboard movement capability")
    return
end

local ok, reason = Ext.Movement.EnableKeyboardMovement()
if ok then
    Ext.Print("[BG3WASDMacOS] Native W/A/S/D movement enabled; controller UI remains off; keyboard camera pan is blocked")
else
    Ext.Print("[BG3WASDMacOS] Could not enable keyboard movement: " ..
        tostring(reason))
end
