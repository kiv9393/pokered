local rumbleActive = false
local frameCount = 0
callbacks:add("frame", function()
    frameCount = frameCount + 1
    local val = emu:read8(0xC700)
    if frameCount % 120 == 0 then
        console:log("Heartbeat - Frame " .. frameCount .. " | C700 = " .. val)
    end
    if val == 1 and not rumbleActive then
        rumbleActive = true
        console:log("[Frame " .. frameCount .. "] >>> RUMBLE ON <<<")
    elseif val == 0 and rumbleActive then
        rumbleActive = false
        console:log("[Frame " .. frameCount .. "] --- rumble off ---")
    end
end)
console:log("Rumble debug v2 loaded! Watching C700 every 2 seconds...")
