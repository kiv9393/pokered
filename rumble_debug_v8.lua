-- Rumble v8.1: player moves (C6FC) + enemy moves (C6FB) + crit (C6FD)
-- ASM writes and leaves, Lua reads, acts, clears.
-- Player moves: full tier buzz
-- Enemy moves: shorter sharp buzz (taking damage feel)

local PLAYER_TIERS = {
    [1] = { label="WEAK",   buzz=8  },
    [2] = { label="MEDIUM", buzz=20 },
    [3] = { label="HEAVY",  buzz=35 },
    [4] = { label="MAX",    buzz=55 },
}

-- Enemy hits feel different: sharper, shorter
local ENEMY_TIERS = {
    [1] = { label="HIT-weak",   buzz=6  },
    [2] = { label="HIT-medium", buzz=14 },
    [3] = { label="HIT-heavy",  buzz=25 },
    [4] = { label="HIT-max",    buzz=40 },
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

    -- Player move takes priority over enemy (shouldn't overlap but just in case)
    if playerTier >= 1 and playerTier <= 4 then
        emu:write8(0xC6FC, 0)
        emu:write8(0xC6FD, 0)
        local t = PLAYER_TIERS[playerTier]
        sessionMoves = sessionMoves + 1
        local critStr = isCrit > 0 and " +CRIT" or ""
        console:log("[" .. frameCount .. "] YOU: " .. t.label .. critStr)
        buzzing = false
        critPending = false
        pendingLabel = t.label
        pendingBuzz = t.buzz
        if isCrit > 0 then
            critPending = true
            critPhase = 0
            critTimer = 6
        else
            startBuzz(t.buzz, t.label)
        end

    elseif enemyTier >= 1 and enemyTier <= 4 then
        emu:write8(0xC6FB, 0)
        local t = ENEMY_TIERS[enemyTier]
        sessionMoves = sessionMoves + 1
        console:log("[" .. frameCount .. "] FOE: " .. t.label)
        buzzing = false
        critPending = false
        startBuzz(t.buzz, t.label)
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

    -- Buzz countdown
    if buzzing then
        buzzFrames = buzzFrames - 1
        if buzzFrames <= 0 then
            buzzing = false
            console:log("  ✓ " .. buzzLabel)
        end
    end
end)

console:log("Rumble v8.1 | YOU=C6FC FOE=C6FB CRIT=C6FD")
console:log("Player: WEAK=8f MED=20f HEAVY=35f MAX=55f")
console:log("Enemy:  WEAK=6f MED=14f HEAVY=25f MAX=40f")
