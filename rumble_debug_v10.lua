-- Rumble v10: Full monitoring - battles + balls + poison + faint + paralysis
-- C6FC: player move tier (1-4)
-- C6FB: enemy move tier (1-4)
-- C6FD: crit flag
-- C6FA: 5=ball shake, 6=catch, 7=poison/burn, 8=paralysis fail, 9=faint

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

-- All pattern definitions in one place for easy tuning
local PATTERNS = {
    catch   = {10, 8, 10, 8, 10, 0},         -- triple pulse
    poison  = {6, 12, 6, 12, 6, 0},           -- slow drip x3
    para    = {4, 3, 4, 3, 2, 3, 0},          -- stutter cut-off
    faint   = {20, 6, 14, 6, 8, 0},           -- descending thumps
}

local frameCount = 0
local sessionEvents = 0
local lastHeartbeat = 0
local HEARTBEAT_INTERVAL = 60 * 60

-- Buzz state
local buzzing = false
local buzzFrames = 0
local buzzLabel = ""

-- Crit state
local critPending = false
local critPhase, critTimer = 0, 0
local pendingBuzz, pendingLabel = 0, ""

-- Pattern state (used for catch, poison, para, faint)
local patternActive = false
local patternPhase = 0
local patternTimer = 0
local patternData = nil
local patternLabel = ""

local function startBuzz(frames, label)
    buzzing = true
    buzzFrames = frames
    buzzLabel = label
end

local function startPattern(data, label)
    patternActive = true
    patternPhase = 1
    patternTimer = data[1]
    patternData = data
    patternLabel = label
    buzzing = false
    critPending = false
end

local function cancelAll()
    buzzing = false
    critPending = false
    patternActive = false
end

callbacks:add("frame", function()
    frameCount = frameCount + 1

    if frameCount - lastHeartbeat >= HEARTBEAT_INTERVAL then
        lastHeartbeat = frameCount
        console:log("[" .. frameCount .. "] ♥ alive | events: " .. sessionEvents)
    end

    local playerTier = emu:read8(0xC6FC)
    local enemyTier  = emu:read8(0xC6FB)
    local isCrit     = emu:read8(0xC6FD)
    local sig        = emu:read8(0xC6FA)

    -- === SIGNAL DISPATCH ===
    if sig == 5 then
        emu:write8(0xC6FA, 0)
        sessionEvents = sessionEvents + 1
        console:log("[" .. frameCount .. "] ◉ BALL SHAKE #" .. sessionEvents)
        cancelAll()
        startBuzz(8, "ball-shake")

    elseif sig == 6 then
        emu:write8(0xC6FA, 0)
        sessionEvents = sessionEvents + 1
        console:log("[" .. frameCount .. "] ★ CAUGHT! #" .. sessionEvents)
        cancelAll()
        startPattern(PATTERNS.catch, "catch")

    elseif sig == 7 then
        emu:write8(0xC6FA, 0)
        sessionEvents = sessionEvents + 1
        console:log("[" .. frameCount .. "] ☠ POISON/BURN #" .. sessionEvents)
        cancelAll()
        startPattern(PATTERNS.poison, "poison-drip")

    elseif sig == 8 then
        emu:write8(0xC6FA, 0)
        sessionEvents = sessionEvents + 1
        console:log("[" .. frameCount .. "] ⚡ PARALYZED! #" .. sessionEvents)
        cancelAll()
        startPattern(PATTERNS.para, "paralysis")

    elseif sig == 9 then
        emu:write8(0xC6FA, 0)
        sessionEvents = sessionEvents + 1
        console:log("[" .. frameCount .. "] 💀 FAINT #" .. sessionEvents)
        cancelAll()
        startPattern(PATTERNS.faint, "faint")

    elseif playerTier >= 1 and playerTier <= 4 then
        emu:write8(0xC6FC, 0)
        emu:write8(0xC6FD, 0)
        local t = PLAYER_TIERS[playerTier]
        sessionEvents = sessionEvents + 1
        local critStr = isCrit > 0 and " +CRIT" or ""
        console:log("[" .. frameCount .. "] ▶ YOU: " .. t.label .. critStr .. " #" .. sessionEvents)
        cancelAll()
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
        sessionEvents = sessionEvents + 1
        console:log("[" .. frameCount .. "] ◀ FOE: " .. t.label .. " #" .. sessionEvents)
        cancelAll()
        startBuzz(t.buzz, t.label)
    end

    -- === PATTERN STATE MACHINE (shared for catch/poison/para/faint) ===
    if patternActive then
        patternTimer = patternTimer - 1
        if patternTimer <= 0 then
            patternPhase = patternPhase + 1
            if patternPhase > #patternData or patternData[patternPhase] == 0 then
                patternActive = false
                console:log("  ✓ " .. patternLabel .. " done")
            else
                patternTimer = patternData[patternPhase]
            end
        end
        return
    end

    -- === CRIT TAP SEQUENCE ===
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

    -- === BUZZ COUNTDOWN ===
    if buzzing then
        buzzFrames = buzzFrames - 1
        if buzzFrames <= 0 then
            buzzing = false
            console:log("  ✓ " .. buzzLabel)
        end
    end
end)

console:log("================================================")
console:log("  Rumble v10 | Full Monitoring")
console:log("  ▶ YOU  ◀ FOE  ◉ Ball  ★ Catch")
console:log("  ☠ Poison  ⚡ Para  💀 Faint")
console:log("  Signals: C6FC/C6FB/C6FD/C6FA")
console:log("================================================")
