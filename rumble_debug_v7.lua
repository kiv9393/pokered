-- Rumble v7: silent except for real move events. No per-frame spam.
-- C6FC: tier pulse (1-4, nonzero for one frame only)
-- C6FD: crit flag (set same frame)

local TIERS = {
    [1] = { label="WEAK",   buzz=8  },
    [2] = { label="MEDIUM", buzz=20 },
    [3] = { label="HEAVY",  buzz=35 },
    [4] = { label="MAX",    buzz=55 },
}

local frameCount = 0
local lastTier = 0
local buzzing = false
local buzzFrames = 0
local buzzLabel = ""
local critPending = false
local critPhase = 0
local critTimer = 0
local pendingBuzzFrames = 0
local pendingLabel = ""
local sessionMoves = 0

callbacks:add("frame", function()
    frameCount = frameCount + 1
    local tier = emu:read8(0xC6FC)
    local isCrit = emu:read8(0xC6FD)

    -- Only act on valid tier values, silently ignore everything else
    if tier >= 1 and tier <= 4 then
        local t = TIERS[tier]
        sessionMoves = sessionMoves + 1
        local critStr = isCrit > 0 and " +CRIT" or ""
        console:log("[" .. frameCount .. "] MOVE #" .. sessionMoves .. ": " .. t.label .. critStr)

        buzzing = false
        critPending = false
        pendingLabel = t.label
        pendingBuzzFrames = t.buzz

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

    -- Crit tap sequence (silent state machine, just timing)
    if critPending then
        critTimer = critTimer - 1
        if critPhase == 0 and critTimer <= 0 then
            critPhase = 1; critTimer = 4
        elseif critPhase == 1 and critTimer <= 0 then
            critPhase = 2; critTimer = 6
        elseif critPhase == 2 and critTimer <= 0 then
            critPhase = 3; critTimer = 8
        elseif critPhase == 3 and critTimer <= 0 then
            critPending = false
            buzzing = true
            buzzFrames = pendingBuzzFrames
            buzzLabel = pendingLabel
            console:log("  crit taps done → buzz " .. buzzFrames .. "f")
        end
        return
    end

    -- Buzz countdown, only logs start and end
    if buzzing then
        if buzzFrames == pendingBuzzFrames then
            console:log("  buzz start: " .. buzzLabel .. " (" .. buzzFrames .. "f)")
        end
        buzzFrames = buzzFrames - 1
        if buzzFrames <= 0 then
            buzzing = false
            console:log("  buzz done ✓")
        end
    end
end)

console:log("Rumble v7 ready. Watching C6FC. Silent until a move fires.")
