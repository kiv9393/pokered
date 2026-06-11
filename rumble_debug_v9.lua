-- Rumble v9: full coverage - battles + pokeballs + heartbeat
-- C6FC: player move tier (1-4)
-- C6FB: enemy move tier (1-4)
-- C6FD: crit flag
-- C6FA: 5=ball shake, 6=catch success

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
local sessionEvents = 0
local lastHeartbeat = 0
local HEARTBEAT_INTERVAL = 60 * 60 -- log alive message every 60 seconds

local buzzing = false
local buzzFrames = 0
local buzzLabel = ""

local critPending = false
local critPhase, critTimer = 0, 0
local pendingBuzz, pendingLabel = 0, ""

local catchPulse = false
local catchPhase = 0
local catchTimer = 0
local CATCH_PATTERN = {10, 8, 10, 8, 10, 0}

local function startBuzz(frames, label)
    buzzing = true
    buzzFrames = frames
    buzzLabel = label
end

local function cancelAll()
    buzzing = false
    critPending = false
    catchPulse = false
end

callbacks:add("frame", function()
    frameCount = frameCount + 1

    -- Heartbeat: confirms script alive even when nothing is happening
    if frameCount - lastHeartbeat >= HEARTBEAT_INTERVAL then
        lastHeartbeat = frameCount
        console:log("[" .. frameCount .. "] ♥ alive | events so far: " .. sessionEvents)
    end

    local playerTier = emu:read8(0xC6FC)
    local enemyTier  = emu:read8(0xC6FB)
    local isCrit     = emu:read8(0xC6FD)
    local ballSig    = emu:read8(0xC6FA)

    -- === BALL SIGNALS (highest priority) ===
    if ballSig == 5 then
        emu:write8(0xC6FA, 0)
        sessionEvents = sessionEvents + 1
        console:log("[" .. frameCount .. "] ◉ BALL SHAKE #" .. sessionEvents)
        cancelAll()
        startBuzz(8, "ball-shake")

    elseif ballSig == 6 then
        emu:write8(0xC6FA, 0)
        sessionEvents = sessionEvents + 1
        console:log("[" .. frameCount .. "] ★ CAUGHT! triple pulse #" .. sessionEvents)
        cancelAll()
        catchPulse = true
        catchPhase = 1
        catchTimer = CATCH_PATTERN[1]

    -- === PLAYER MOVE ===
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

    -- === ENEMY MOVE ===
    elseif enemyTier >= 1 and enemyTier <= 4 then
        emu:write8(0xC6FB, 0)
        local t = ENEMY_TIERS[enemyTier]
        sessionEvents = sessionEvents + 1
        console:log("[" .. frameCount .. "] ◀ FOE: " .. t.label .. " #" .. sessionEvents)
        cancelAll()
        startBuzz(t.buzz, t.label)
    end

    -- === CATCH TRIPLE PULSE ===
    if catchPulse then
        catchTimer = catchTimer - 1
        if catchTimer <= 0 then
            catchPhase = catchPhase + 1
            if catchPhase > #CATCH_PATTERN or CATCH_PATTERN[catchPhase] == 0 then
                catchPulse = false
                console:log("  ★ catch pulse complete!")
            else
                catchTimer = CATCH_PATTERN[catchPhase]
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
            console:log("  [crit taps] → " .. pendingLabel .. " buzz")
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
console:log("  Rumble v9 | Full Coverage Debug")
console:log("  ▶ YOU moves  ◀ FOE moves")
console:log("  ◉ Ball shake ★ Catch success")
console:log("  Heartbeat every 60 seconds")
console:log("================================================")
