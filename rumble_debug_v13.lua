-- Rumble v13: Deep diagnostic - tracks all pathways, origin detection,
-- state machine visualization, and mystery buzz forensics
-- 
-- New addresses (CD81-CD88):
-- CD81: countdown timer    CD82: motor shadow
-- CD83: texture tag        CD84: iconic flag  
-- CD85: player tier        CD86: enemy tier
-- CD87: crit flag          CD88: special signals

local MOVE_NAMES = {
    [0x02]="KarateChop",  [0x0E]="SwordsDance", [0x13]="Fly",
    [0x17]="Stomp",       [0x22]="BodySlam",     [0x23]="Wrap",
    [0x35]="Flamethrow",  [0x38]="HydroPump",    [0x39]="Surf",
    [0x3A]="IceBeam",     [0x3B]="Blizzard",     [0x3F]="HyperBeam",
    [0x42]="Submission",  [0x45]="SeismicToss",  [0x48]="MegaDrain",
    [0x53]="FireSpin",    [0x54]="Thundershck",  [0x55]="Thunderbolt",
    [0x56]="ThunderWave", [0x57]="Thunder",      [0x59]="Earthquake",
    [0x5B]="Dig",         [0x5C]="Toxic",        [0x5E]="Psychic",
    [0x61]="Agility",     [0x7E]="FireBlast",    [0x85]="Amnesia",
    [0x98]="Crabhammer",  [0x99]="Explosion",    [0x9C]="Rest",
    [0x9D]="RockSlide",   [0xA3]="Slash",        [0xA4]="Substitute",
    [0x09]="ThunderPunch",[0x19]="RazorLeaf",    [0x28]="SandAttack",
    [0x80]="Clamp",       [0x81]="Swift",        [0x82]="SkullBash",
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
    [5]="BALL-SHAKE", [6]="CAUGHT",      [7]="POISON-BURN",
    [8]="PARALYZED",  [9]="FAINT",       [10]="CUT-tree",
    [11]="CUT-slash", [12]="BOULDER-push",[13]="BOULDER-settle",
}

-- State machine
local frameCount = 0
local lastHeartbeat = 0
local HEARTBEAT = 60 * 60
local sessionEvents = 0

-- Buzz tracking
local lastCountdown = 0
local buzzActive = false
local buzzStartFrame = 0
local peakCountdown = 0
local buzzOrigin = "unknown"

-- Signal state
local lastPlayerTier = 0
local lastEnemyTier = 0
local lastSig = 0

-- Mystery buzz forensics
local mysteryLog = {}
local MAX_MYSTERY = 5

-- RAM snapshot for forensics
local function snapRAM()
    return {
        countdown = emu:read8(0xCD81),
        motor     = emu:read8(0xCD82),
        texture   = emu:read8(0xCD83),
        iconic    = emu:read8(0xCD84),
        pTier     = emu:read8(0xCD85),
        eTier     = emu:read8(0xCD86),
        crit      = emu:read8(0xCD87),
        sig       = emu:read8(0xCD88),
        moveNum   = emu:read8(0xCFD2),
        movePwr   = emu:read8(0xCFD4),
        moveType  = emu:read8(0xCFD5),
        whoseTurn = emu:read8(0xFF83),
    }
end

local function moveName(n)
    return MOVE_NAMES[n] or string.format("Move%02X", n)
end
local function typeName(t)
    return TYPE_NAMES[t] or string.format("Type%02X", t)
end
local function texName(t)
    return TEXTURE_NAMES[t] or string.format("Tex%02X", t)
end

callbacks:add("frame", function()
    frameCount = frameCount + 1

    if frameCount - lastHeartbeat >= HEARTBEAT then
        lastHeartbeat = frameCount
        console:log("[" .. frameCount .. "] alive | events=" .. sessionEvents)
    end

    local s = snapRAM()

    -- === SIGNAL DETECTION ===

    -- Player move
    if s.pTier >= 1 and s.pTier <= 4 and s.pTier ~= lastPlayerTier then
        emu:write8(0xCD85, 0)
        emu:write8(0xCD87, 0)
        sessionEvents = sessionEvents + 1
        local critStr = s.crit > 0 and " CRIT" or ""
        local iconicStr = s.iconic > 0 and " [ICONIC]" or ""
        local ms = math.floor(s.countdown * 16.67)
        console:log("=== YOU #" .. sessionEvents .. critStr .. iconicStr .. " ===")
        console:log("  move=" .. moveName(s.moveNum) .. " pwr=" .. s.movePwr)
        console:log("  type=" .. typeName(s.moveType) .. " tex=" .. texName(s.texture))
        console:log("  tier=" .. (TIER_NAMES[s.pTier] or "?") .. " buzz=" .. s.countdown .. "f=" .. ms .. "ms")
        console:log("  turn=" .. s.whoseTurn .. " iconic=" .. s.iconic)
        buzzOrigin = "player-move"
    end
    lastPlayerTier = s.pTier

    -- Enemy move
    if s.eTier >= 1 and s.eTier <= 4 and s.eTier ~= lastEnemyTier then
        emu:write8(0xCD86, 0)
        sessionEvents = sessionEvents + 1
        local ms = math.floor(s.countdown * 16.67)
        console:log("=== FOE #" .. sessionEvents .. " ===")
        console:log("  buzz=" .. s.countdown .. "f=" .. ms .. "ms")
        buzzOrigin = "enemy-move"
    end
    lastEnemyTier = s.eTier

    -- Special signals
    if s.sig >= 5 and s.sig ~= lastSig and SIGNALS[s.sig] then
        emu:write8(0xCD88, 0)
        sessionEvents = sessionEvents + 1
        console:log("=== " .. SIGNALS[s.sig] .. " #" .. sessionEvents .. " ===")
        buzzOrigin = SIGNALS[s.sig]
    elseif s.sig >= 5 and s.sig ~= lastSig then
        console:log("=== UNKNOWN SIG=" .. s.sig .. " #" .. sessionEvents .. " ===")
        buzzOrigin = "unknown-sig-" .. s.sig
    end
    lastSig = s.sig

    -- === BUZZ TRACKING + MYSTERY DETECTION ===
    if s.countdown > lastCountdown and s.countdown > 5 then
        buzzActive = true
        peakCountdown = s.countdown
        buzzStartFrame = frameCount

        -- Mystery buzz: countdown jumped but no signal triggered this frame
        if s.pTier == 0 and s.eTier == 0 and (s.sig == 0 or s.sig == lastSig) then
            buzzOrigin = "MYSTERY"
            if #mysteryLog < MAX_MYSTERY then
                table.insert(mysteryLog, {
                    frame = frameCount,
                    countdown = s.countdown,
                    moveNum = s.moveNum,
                    movePwr = s.movePwr,
                    moveType = s.moveType,
                    whoseTurn = s.whoseTurn,
                    iconic = s.iconic,
                    texture = s.texture,
                })
            end
            console:log("*** MYSTERY BUZZ frame=" .. frameCount ..
                " cd=" .. s.countdown ..
                " move=" .. moveName(s.moveNum) ..
                " pwr=" .. s.movePwr ..
                " turn=" .. s.whoseTurn ..
                " iconic=" .. s.iconic ..
                " tex=" .. texName(s.texture))
        end
    end

    if buzzActive and s.countdown == 0 and lastCountdown > 0 then
        buzzActive = false
        local actual = frameCount - buzzStartFrame
        local ms = math.floor(actual * 16.67)
        if buzzOrigin == "MYSTERY" then
            console:log("  MYSTERY done peak=" .. peakCountdown .. "f actual=" .. actual .. "f " .. ms .. "ms")
        else
            console:log("  done " .. buzzOrigin .. " peak=" .. peakCountdown .. "f actual=" .. actual .. "f")
        end
        buzzOrigin = "unknown"
    end

    lastCountdown = s.countdown
end)

-- Session summary on demand - press L button to dump
callbacks:add("keysDown", function()
    local keys = emu:getKeys()
    if keys and keys.l then
        console:log("=== SESSION SUMMARY ===")
        console:log("Total events: " .. sessionEvents)
        console:log("Mystery buzzes logged: " .. #mysteryLog)
        for i, m in ipairs(mysteryLog) do
            console:log("  Mystery #" .. i .. " frame=" .. m.frame ..
                " cd=" .. m.countdown ..
                " move=" .. moveName(m.moveNum) ..
                " pwr=" .. m.movePwr ..
                " turn=" .. m.whoseTurn)
        end
        console:log("=======================")
    end
end)

console:log("Rumble v13 | Deep Diagnostic")
console:log("Addresses: CD81-CD88")
console:log("Press L during play for session summary")
console:log("Mystery buzz forensics: auto-logged")
