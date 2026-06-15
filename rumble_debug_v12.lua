-- Rumble v12.1: Fixed RAM addresses + mystery buzz detection
-- wPlayerMoveNum  = $CFD2
-- wPlayerMovePower = $CFD4
-- wPlayerMoveType  = $CFD5

local MOVE_NAMES = {
    [0x02]="KarateChop",  [0x0E]="SwordsDance", [0x13]="Fly",
    [0x17]="Stomp",       [0x22]="BodySlam",     [0x23]="Wrap",
    [0x35]="Flamethrow",  [0x39]="Surf",         [0x3A]="IceBeam",
    [0x38]="HydroPump",    [0x3B]="Blizzard",    [0x3F]="HyperBeam",    [0x42]="Submission",
    [0x45]="SeismicToss", [0x48]="MegaDrain",    [0x53]="FireSpin",
    [0x54]="Thundershck", [0x55]="Thunderbolt",  [0x56]="ThunderWave",
    [0x57]="Thunder",     [0x59]="Earthquake",   [0x5B]="Dig",
    [0x5C]="Toxic",       [0x5E]="Psychic",      [0x61]="Agility",
    [0x7E]="FireBlast",   [0x85]="Amnesia",      [0x98]="Crabhammer",
    [0x99]="Explosion",   [0x9C]="Rest",         [0x9D]="RockSlide",
    [0xA3]="Slash",       [0xA4]="Substitute",
    [0x09]="ThunderPunch",[0x80]="Clamp",      [0x81]="Swift",
    [0x82]="SkullBash",   [0x19]="RazorLeaf",  [0x28]="Sand-Attack",
}

local TYPE_NAMES = {
    [0x00]="Normal",   [0x01]="Fighting", [0x02]="Flying",
    [0x03]="Poison",   [0x04]="Ground",   [0x05]="Rock",
    [0x06]="Bird",     [0x07]="Bug",      [0x08]="Ghost",
    [0x14]="Fire",     [0x15]="Water",    [0x16]="Grass",
    [0x17]="Electric", [0x18]="Psychic",  [0x19]="Ice",
    [0x1A]="Dragon",
}

local TEXTURE_NAMES = {
    [0x00]="default",  [0x01]="electric", [0x02]="ground",
    [0x03]="psychic",  [0x04]="fire",     [0x05]="water-ice",
    [0x06]="ghost",    [0x07]="dragon",
}

local TIER_NAMES = {
    [1]="WEAK-8f", [2]="MEDIUM-20f", [3]="HEAVY-35f", [4]="MAX-55f"
}

local SIGNALS = {
    [5]="BALL SHAKE", [6]="CAUGHT",    [7]="POISON-BURN",
    [8]="PARALYZED",  [9]="FAINT",     [10]="CUT tree",
    [11]="CUT slash", [12]="BOULDER push", [13]="BOULDER settle",
}

local frameCount = 0
local lastHeartbeat = 0
local HEARTBEAT = 60 * 60
local sessionEvents = 0
local lastCountdown = 0
local buzzActive = false
local buzzStartFrame = 0
local peakCountdown = 0
local lastPlayerTier = 0
local lastEnemyTier = 0
local mysteryBuzzThreshold = 60

callbacks:add("frame", function()
    frameCount = frameCount + 1

    if frameCount - lastHeartbeat >= HEARTBEAT then
        lastHeartbeat = frameCount
        console:log("[" .. frameCount .. "] alive | events: " .. sessionEvents)
    end

    local playerTier = emu:read8(0xCD85)
    local enemyTier  = emu:read8(0xCD86)
    local isCrit     = emu:read8(0xCD87)
    local sig        = emu:read8(0xCD88)
    local countdown  = emu:read8(0xCD81)
    local texture    = emu:read8(0xCD83)

    -- FIXED RAM addresses
    local moveNum   = emu:read8(0xCFD2)
    local movePower = emu:read8(0xCFD4)
    local moveType  = emu:read8(0xCFD5)

    if playerTier >= 1 and playerTier <= 4 and playerTier ~= lastPlayerTier then
        emu:write8(0xCD85, 0)
        emu:write8(0xCD87, 0)
        sessionEvents = sessionEvents + 1
        local moveName = MOVE_NAMES[moveNum] or ("Move" .. string.format("%02X", moveNum))
        local typeName = TYPE_NAMES[moveType] or ("Type" .. string.format("%02X", moveType))
        local texName  = TEXTURE_NAMES[texture] or ("Tex" .. string.format("%02X", texture))
        local tierName = TIER_NAMES[playerTier] or "unknown"
        local critStr  = isCrit > 0 and " CRIT" or ""
        local ms       = math.floor(countdown * 16.67)
        console:log("-----------------------------------")
        console:log("[" .. frameCount .. "] YOU #" .. sessionEvents .. critStr)
        console:log("  Move: " .. moveName .. " pwr=" .. movePower)
        console:log("  Type: " .. typeName .. " tex=" .. texName)
        console:log("  Tier: " .. tierName)
        console:log("  Buzz: " .. countdown .. "f = " .. ms .. "ms")
        console:log("-----------------------------------")
    end
    lastPlayerTier = playerTier

    if enemyTier >= 1 and enemyTier <= 4 and enemyTier ~= lastEnemyTier then
        emu:write8(0xCD86, 0)
        sessionEvents = sessionEvents + 1
        local ms = math.floor(countdown * 16.67)
        console:log("-----------------------------------")
        console:log("[" .. frameCount .. "] FOE #" .. sessionEvents)
        console:log("  Buzz: " .. countdown .. "f = " .. ms .. "ms")
        console:log("-----------------------------------")
    end
    lastEnemyTier = enemyTier

    -- Buzz tracking with mystery buzz detection
    if countdown > lastCountdown and countdown > 5 then
        buzzActive = true
        peakCountdown = countdown
        buzzStartFrame = frameCount
        if countdown > mysteryBuzzThreshold and playerTier == 0 and enemyTier == 0 and sig == 0 then
            console:log("*** MYSTERY BUZZ at frame " .. frameCount .. " countdown=" .. countdown .. "f - no move/signal triggered this!")
        end
    end
    if buzzActive and countdown == 0 and lastCountdown > 0 then
        buzzActive = false
        local actual = frameCount - buzzStartFrame
        local ms = math.floor(actual * 16.67)
        console:log("  done peak=" .. peakCountdown .. "f actual=" .. actual .. "f " .. ms .. "ms")
    end
    lastCountdown = countdown

    if sig >= 5 and SIGNALS[sig] then
        emu:write8(0xCD88, 0)
        sessionEvents = sessionEvents + 1
        console:log("[" .. frameCount .. "] " .. SIGNALS[sig] .. " #" .. sessionEvents)
    end
end)

console:log("Rumble v12.1 - Fixed addresses")
console:log("MoveNum=$CFD2 Power=$CFD4 Type=$CFD5")
