-- Rumble debug v4: ASM signals intent, Lua controls all timing
-- C700: 0=idle/status, 1=weak, 2=medium, 3=heavy, 4=max
-- C701: 1=crit prefix should fire

local frameCount = 0
local rumbleFramesLeft = 0
local motorOn = false
local lastTier = 0
local sessionBuzzes = {}

-- Tier config: { buzz_frames, off_frames, pulses }
-- pulses > 1 = pulsed pattern, pulses = 1 = single solid buzz
local TIERS = {
    [1] = { label="WEAK",   buzz=8,  off=0, pulses=1 },
    [2] = { label="MEDIUM", buzz=20, off=0, pulses=1 },
    [3] = { label="HEAVY",  buzz=35, off=0, pulses=1 },
    [4] = { label="MAX",    buzz=55, off=0, pulses=1 },
}

local critPending = false
local critPhase = 0    -- 0=tap1, 1=gap, 2=tap2, 3=pause
local critTimer = 0
local CRIT_TAP = 6
local CRIT_GAP = 4
local CRIT_PAUSE = 8

local mainBuzzFrames = 0
local mainBuzzActive = false

local lastC700 = 0

callbacks:add("frame", function()
    frameCount = frameCount + 1
    local tier = emu:read8(0xC700)
    local isCrit = emu:read8(0xC701)

    -- Detect new move signal (tier changed to nonzero)
    if tier ~= lastC700 and tier > 0 then
        local t = TIERS[tier]
        console:log("[Frame " .. frameCount .. "] >>> MOVE SIGNAL: " .. t.label .. (isCrit == 1 and " + CRIT" or "") .. " <<<")
        table.insert(sessionBuzzes, {tier=tier, frame=frameCount})

        -- Queue crit prefix then main buzz
        if isCrit == 1 then
            critPending = true
            critPhase = 0
            critTimer = CRIT_TAP
        else
            critPending = false
            mainBuzzActive = true
            mainBuzzFrames = t.buzz
        end
        lastTier = tier

        -- Clear the signal so we don't re-trigger
        -- (ASM will reset to 0 on next non-move call naturally,
        --  but we track lastC700 to only fire once per signal)
    end
    lastC700 = tier

    -- Crit prefix state machine
    if critPending then
        critTimer = critTimer - 1
        if critPhase == 0 then
            emu:write8(0xC700, 0x01)  -- motor concept on
            if critTimer <= 0 then critPhase = 1; critTimer = CRIT_GAP end
        elseif critPhase == 1 then
            emu:write8(0xC700, 0x00)  -- motor concept off
            if critTimer <= 0 then critPhase = 2; critTimer = CRIT_TAP end
        elseif critPhase == 2 then
            emu:write8(0xC700, 0x01)
            if critTimer <= 0 then critPhase = 3; critTimer = CRIT_PAUSE end
        elseif critPhase == 3 then
            emu:write8(0xC700, 0x00)
            if critTimer <= 0 then
                critPending = false
                mainBuzzActive = true
                mainBuzzFrames = TIERS[lastTier].buzz
            end
        end
        return
    end

    -- Main buzz
    if mainBuzzActive then
        mainBuzzFrames = mainBuzzFrames - 1
        emu:write8(0xC700, 0x01)
        if mainBuzzFrames <= 0 then
            mainBuzzActive = false
            emu:write8(0xC700, 0x00)
            console:log("[Frame " .. frameCount .. "] --- buzz complete: " .. TIERS[lastTier].label .. " ---")

            if #sessionBuzzes % 5 == 0 then
                console:log("  ┌─ SESSION SUMMARY (" .. #sessionBuzzes .. " moves) ───")
                local counts = {[1]=0,[2]=0,[3]=0,[4]=0}
                for _, b in ipairs(sessionBuzzes) do counts[b.tier] = counts[b.tier] + 1 end
                console:log("  │  WEAK:" .. counts[1] .. " MED:" .. counts[2] .. " HEAVY:" .. counts[3] .. " MAX:" .. counts[4])
                console:log("  └────────────────────────────────────")
            end
        end
    end
end)

console:log("Rumble v4 loaded! Lua controls all timing.")
console:log("Tiers: 1=WEAK(8f) 2=MED(20f) 3=HEAVY(35f) 4=MAX(55f)")
