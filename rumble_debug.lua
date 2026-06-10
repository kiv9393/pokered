-- Rumble v5: debounced signals, nil guards, cleaner logging
-- C700: 0=idle, 1=weak, 2=medium, 3=heavy, 4=max
-- C701: 1=crit

local frameCount = 0
local lastTier = 0
local lastSignalFrame = -99
local mainBuzzFrames = 0
local mainBuzzActive = false
local activeTierLabel = ""
local sessionBuzzes = {}

local critPending = false
local critPhase = 0
local critTimer = 0
local CRIT_TAP = 6
local CRIT_GAP = 4
local CRIT_PAUSE = 8

local TIERS = {
    [1] = { label="WEAK",   buzz=8  },
    [2] = { label="MEDIUM", buzz=20 },
    [3] = { label="HEAVY",  buzz=35 },
    [4] = { label="MAX",    buzz=55 },
}

callbacks:add("frame", function()
    frameCount = frameCount + 1
    local tier = emu:read8(0xC700)
    local isCrit = emu:read8(0xC701)

    -- New signal: nonzero tier, valid, and not a duplicate within 3 frames
    if tier > 0 and tier <= 4 and (frameCount - lastSignalFrame) > 3 then
        local t = TIERS[tier]
        lastSignalFrame = frameCount
        lastTier = tier
        activeTierLabel = t.label
        table.insert(sessionBuzzes, {tier=tier, frame=frameCount})

        local critStr = (isCrit == 1) and " +CRIT" or ""
        console:log("[Frame " .. frameCount .. "] MOVE: " .. t.label .. critStr .. " (" .. t.buzz .. "f)")

        -- Cancel any active buzz and start fresh
        mainBuzzActive = false
        critPending = false

        if isCrit == 1 then
            critPending = true
            critPhase = 0
            critTimer = CRIT_TAP
        else
            mainBuzzActive = true
            mainBuzzFrames = t.buzz
        end

    elseif tier > 4 then
        console:log("[Frame " .. frameCount .. "] WARN: unexpected C700 value = " .. tier)
    end

    -- Crit prefix state machine
    if critPending then
        critTimer = critTimer - 1
        if critPhase == 0 then
            if critTimer <= 0 then critPhase = 1; critTimer = CRIT_GAP end
        elseif critPhase == 1 then
            if critTimer <= 0 then critPhase = 2; critTimer = CRIT_TAP end
        elseif critPhase == 2 then
            if critTimer <= 0 then critPhase = 3; critTimer = CRIT_PAUSE end
        elseif critPhase == 3 then
            if critTimer <= 0 then
                critPending = false
                mainBuzzActive = true
                mainBuzzFrames = TIERS[lastTier] and TIERS[lastTier].buzz or 8
                console:log("[Frame " .. frameCount .. "] crit prefix done, main buzz starting")
            end
        end
        return
    end

    -- Main buzz countdown
    if mainBuzzActive then
        mainBuzzFrames = mainBuzzFrames - 1
        if mainBuzzFrames <= 0 then
            mainBuzzActive = false
            console:log("[Frame " .. frameCount .. "] buzz done: " .. activeTierLabel)

            if #sessionBuzzes > 0 and #sessionBuzzes % 5 == 0 then
                local counts = {[1]=0,[2]=0,[3]=0,[4]=0}
                for _, b in ipairs(sessionBuzzes) do
                    if counts[b.tier] then counts[b.tier] = counts[b.tier] + 1 end
                end
                console:log("── SUMMARY (" .. #sessionBuzzes .. " moves) WEAK:" .. counts[1] ..
                    " MED:" .. counts[2] .. " HEAVY:" .. counts[3] .. " MAX:" .. counts[4] .. " ──")
            end
        end
    end
end)

console:log("Rumble v5 loaded. Tiers: WEAK=8f MED=20f HEAVY=35f MAX=55f | debounce: 3f")
