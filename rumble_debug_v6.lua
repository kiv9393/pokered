-- Rumble debug v6: one-frame pulse detection, clean single logging
-- C6FE: tier pulse (nonzero for exactly one frame per move)
-- C6FF: crit flag (set same frame as tier)

local frameCount = 0
local mainBuzzFrames = 0
local mainBuzzActive = false
local activeTierLabel = ""
local activeTierBuzz = 0
local sessionBuzzes = {}

local critPending = false
local critPhase = 0
local critTimer = 0
local CRIT_TAP = 6
local CRIT_GAP = 4
local CRIT_PAUSE = 8
local lastTierForCrit = 1

local TIERS = {
    [1] = { label="WEAK",   buzz=8  },
    [2] = { label="MEDIUM", buzz=20 },
    [3] = { label="HEAVY",  buzz=35 },
    [4] = { label="MAX",    buzz=55 },
}

callbacks:add("frame", function()
    frameCount = frameCount + 1
    local tier = emu:read8(0xC6FE)
    local isCrit = emu:read8(0xC6FF)

    -- One-frame pulse detection: tier is nonzero for exactly one frame
    if tier >= 1 and tier <= 4 then
        local t = TIERS[tier]
        local critStr = (isCrit > 0) and " +CRIT" or ""
        console:log("[Frame " .. frameCount .. "] MOVE: " .. t.label .. critStr .. " → buzz " .. t.buzz .. "f")
        table.insert(sessionBuzzes, {tier=tier, frame=frameCount})

        -- Cancel any active buzz, start fresh
        mainBuzzActive = false
        critPending = false
        lastTierForCrit = tier

        if isCrit > 0 then
            critPending = true
            critPhase = 0
            critTimer = CRIT_TAP
        else
            mainBuzzActive = true
            mainBuzzFrames = t.buzz
            activeTierLabel = t.label
            activeTierBuzz = t.buzz
        end

    elseif tier > 4 then
        console:log("[Frame " .. frameCount .. "] WARN: unexpected C6FE = " .. tier)
    end

    -- Crit prefix state machine
    if critPending then
        critTimer = critTimer - 1
        if critPhase == 0 and critTimer <= 0 then
            critPhase = 1; critTimer = CRIT_GAP
            console:log("  [crit] tap 1 done")
        elseif critPhase == 1 and critTimer <= 0 then
            critPhase = 2; critTimer = CRIT_TAP
        elseif critPhase == 2 and critTimer <= 0 then
            critPhase = 3; critTimer = CRIT_PAUSE
            console:log("  [crit] tap 2 done")
        elseif critPhase == 3 and critTimer <= 0 then
            critPending = false
            local t = TIERS[lastTierForCrit]
            mainBuzzActive = true
            mainBuzzFrames = t.buzz
            activeTierLabel = t.label
            activeTierBuzz = t.buzz
            console:log("  [crit] prefix done → main buzz " .. t.buzz .. "f")
        end
        return
    end

    -- Main buzz countdown
    if mainBuzzActive then
        mainBuzzFrames = mainBuzzFrames - 1
        if mainBuzzFrames <= 0 then
            mainBuzzActive = false
            console:log("[Frame " .. frameCount .. "] ✓ buzz done: " .. activeTierLabel)

            if #sessionBuzzes > 0 and #sessionBuzzes % 5 == 0 then
                local counts = {[1]=0,[2]=0,[3]=0,[4]=0}
                for _, b in ipairs(sessionBuzzes) do
                    if counts[b.tier] then counts[b.tier] = counts[b.tier] + 1 end
                end
                console:log("── SUMMARY " .. #sessionBuzzes .. " moves | W:" .. counts[1] ..
                    " M:" .. counts[2] .. " H:" .. counts[3] .. " MAX:" .. counts[4] .. " ──")
            end
        end
    end
end)

console:log("Rumble v6 loaded | watching C6FE (tier) + C6FF (crit)")
console:log("WEAK=8f  MEDIUM=20f  HEAVY=35f  MAX=55f")
