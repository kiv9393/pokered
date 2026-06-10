-- Rumble v8.2: player (C6FC) + enemy (C6FB) + crit (C6FD) + ball (C6FA)
-- C6FA: 5=shake thump, 6=catch success triple pulse

local PLAYER_TIERS = {
    [1]={label="WEAK",   buzz=8 },
    [2]={label="MEDIUM", buzz=20},
    [3]={label="HEAVY",  buzz=35},
    [4]={label="MAX",    buzz=55},
}
local ENEMY_TIERS = {
    [1]={label="HIT-weak",   buzz=6 },
    [2]={label="HIT-medium", buzz=14},
    [3]={label="HIT-heavy",  buzz=25},
    [4]={label="HIT-max",    buzz=40},
}

local frameCount = 0
local buzzing = false
local buzzFrames = 0
local buzzLabel = ""
local critPending = false
local critPhase, critTimer = 0, 0
local pendingBuzz, pendingLabel = 0, ""

-- Catch triple pulse state
local catchPulse = false
local catchPhase = 0
local catchTimer = 0
-- 3 pulses: on/off/on/off/on/off
local CATCH_PATTERN = {10, 8, 10, 8, 10, 0}

local function startBuzz(frames, label)
    buzzing = true
    buzzFrames = frames
    buzzLabel = label
end

callbacks:add("frame", function()
    frameCount = frameCount + 1

    local playerTier = emu:read8(0xC6FC)
    local enemyTier  = emu:read8(0xC6FB)
    local isCrit     = emu:read8(0xC6FD)
    local ballSig    = emu:read8(0xC6FA)

    -- Ball signals (highest priority during catching)
    if ballSig == 5 then
        emu:write8(0xC6FA, 0)
        console:log("[" .. frameCount .. "] BALL: shake thump")
        buzzing = false
        catchPulse = false
        startBuzz(8, "shake")

    elseif ballSig == 6 then
        emu:write8(0xC6FA, 0)
        console:log("[" .. frameCount .. "] BALL: *** CAUGHT! triple pulse ***")
        buzzing = false
        catchPulse = true
        catchPhase = 1
        catchTimer = CATCH_PATTERN[1]

    -- Player move
    elseif playerTier >= 1 and playerTier <= 4 then
        emu:write8(0xC6FC, 0)
        emu:write8(0xC6FD, 0)
        local t = PLAYER_TIERS[playerTier]
        local critStr = isCrit > 0 and " +CRIT" or ""
        console:log("[" .. frameCount .. "] YOU: " .. t.label .. critStr)
        buzzing = false
        critPending = false
        catchPulse = false
        pendingLabel = t.label
        pendingBuzz = t.buzz
        if isCrit > 0 then
            critPending = true
            critPhase = 0
            critTimer = 6
        else
            startBuzz(t.buzz, t.label)
        end

    -- Enemy move
    elseif enemyTier >= 1 and enemyTier <= 4 then
        emu:write8(0xC6FB, 0)
        local t = ENEMY_TIERS[enemyTier]
        console:log("[" .. frameCount .. "] FOE: " .. t.label)
        buzzing = false
        critPending = false
        catchPulse = false
        startBuzz(t.buzz, t.label)
    end

    -- Catch triple pulse state machine
    if catchPulse then
        catchTimer = catchTimer - 1
        if catchTimer <= 0 then
            catchPhase = catchPhase + 1
            if catchPhase > #CATCH_PATTERN or CATCH_PATTERN[catchPhase] == 0 then
                catchPulse = false
                console:log("  ✓ caught!")
            else
                catchTimer = CATCH_PATTERN[catchPhase]
            end
        end
        return
    end

    -- Crit tap sequence
    if critPending then
        critTimer = critTimer - 1
        if critPhase == 0 and critTimer <= 0 then critPhase=1; critTimer=4
        elseif critPhase == 1 and critTimer <= 0 then critPhase=2; critTimer=6
        elseif critPhase == 2 and critTimer <= 0 then critPhase=3; critTimer=8
        elseif critPhase == 3 and critTimer <= 0 then
            critPending = false
            startBuzz(pendingBuzz, pendingLabel)
            console:log("  [crit] → " .. pendingLabel)
        end
        return
    end

    -- Main buzz countdown
    if buzzing then
        buzzFrames = buzzFrames - 1
        if buzzFrames <= 0 then
            buzzing = false
            console:log("  ✓ " .. buzzLabel)
        end
    end
end)

console:log("Rumble v8.2 | YOU=C6FC FOE=C6FB CRIT=C6FD BALL=C6FA")
console:log("Ball: shake=8f | catch=triple pulse (10/8/10/8/10f)")
