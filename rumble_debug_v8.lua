-- Rumble v8: ASM writes tier and leaves it. Lua reads, acts, then clears.
-- C6FC: tier (1=weak 2=med 3=heavy 4=max), Lua clears after reading
-- C6FD: crit flag, Lua clears after reading

local TIERS = {
    [1] = { label="WEAK",   buzz=8  },
    [2] = { label="MEDIUM", buzz=20 },
    [3] = { label="HEAVY",  buzz=35 },
    [4] = { label="MAX",    buzz=55 },
}

local frameCount = 0
local buzzing = false
local buzzFrames = 0
local buzzLabel = ""
local critPending = false
local critPhase = 0
local critTimer = 0
local pendingBuzz = 0
local pendingLabel = ""
local sessionMoves = 0

callbacks:add("frame", function()
    frameCount = frameCount + 1
    local tier = emu:read8(0xC6FC)
    local isCrit = emu:read8(0xC6FD)

    if tier >= 1 and tier <= 4 then
        -- Clear immediately so we don't re-trigger next frame
        emu:write8(0xC6FC, 0)
        emu:write8(0xC6FD, 0)

        local t = TIERS[tier]
        sessionMoves = sessionMoves + 1
        local critStr = isCrit > 0 and " +CRIT" or ""
        console:log("[" .. frameCount .. "] MOVE #" .. sessionMoves .. ": " .. t.label .. critStr .. " (" .. t.buzz .. "f)")

        pendingLabel = t.label
        pendingBuzz = t.buzz
        buzzing = false
        critPending = false

        if isCrit > 0 then
            critPending = true
            critPhase = 0
            critTimer = 6
        else
            buzzing = true
            buzzFrames = t.buzz
            buzzLabel = t.label
        end
    end

    if critPending then
        critTimer = critTimer - 1
        if critPhase == 0 and critTimer <= 0 then critPhase=1; critTimer=4
        elseif critPhase == 1 and critTimer <= 0 then critPhase=2; critTimer=6
        elseif critPhase == 2 and critTimer <= 0 then critPhase=3; critTimer=8
        elseif critPhase == 3 and critTimer <= 0 then
            critPending = false
            buzzing = true
            buzzFrames = pendingBuzz
            buzzLabel = pendingLabel
            console:log("  [crit done] → " .. buzzLabel .. " buzz")
        end
        return
    end

    if buzzing then
        buzzFrames = buzzFrames - 1
        if buzzFrames <= 0 then
            buzzing = false
            console:log("  [buzz done] " .. buzzLabel)
        end
    end
end)

console:log("Rumble v8 ready | ASM writes, Lua clears | watching C6FC")
