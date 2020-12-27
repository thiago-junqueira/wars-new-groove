local PassiveConditions = {}
local Wargroove = require "wargroove/wargroove"
local OriginalPassiveConditions = require "wargroove/passive_conditions"

local neighbours = { {x = -1, y = 0}, {x = 1, y = 0}, {x = 0, y = -1}, {x = 0, y = 1} }

local function getNeighbour(pos, i)
    local n = neighbours[i]
    return Wargroove.getUnitAt({ x = n.x + pos.x, y = n.y + pos.y })
end

local function isFlank(attacker, pos_attacker, pos_defender)
    local result = false

    -- Find opposite tile from attacker (assumes always adjacent)
    local flank_x = 0
    local flank_y = 0

    if pos_attacker.x == pos_defender.x then
        -- Vertical flank
        flank_x = pos_defender.x
        if pos_attacker.y > pos_defender.y then
            -- Flank is defender's north
            flank_y = pos_defender.y - 1
        else
            -- Flank is defender's south
            flank_y = pos_defender.y + 1
        end
    else
        -- Horizontal flank
        flank_y = pos_defender.y
        if pos_attacker.x > pos_defender.x then
            -- Flank is defender's left
            flank_x = pos_defender.x - 1
        else
            -- Flank is defender's right
            flank_x = pos_defender.x + 1
        end
    end

    -- Get unit at flank (if it exists) and check if ally
    local unit = Wargroove.getUnitAtXY(flank_x, flank_y)
    if unit and (unit.id ~= attacker.id) and Wargroove.areAllies(attacker.playerId, unit.playerId) then
      result = true
    end

    return result
end

local NewConditions = {}

-- This is called by the game when the map is loaded.
function PassiveConditions.init()
    OriginalPassiveConditions.getPassiveConditions = PassiveConditions.getPassiveConditions
end

function PassiveConditions:getPassiveConditions()
    return NewConditions
end

function NewConditions.soldier(payload)
  local attacker = payload.attacker
	for i = 1, 4 do
        local unit = getNeighbour(payload.attackerPos, i)
        if unit and (unit.id ~= attacker.id) and (Wargroove.getUnitClass(unit.unitClassId).isCommander) and Wargroove.areAllies(attacker.playerId, unit.playerId) then
            return true
        end
	end
	return false
end


function NewConditions.dog(payload)
    -- Dogs also crit if Commander Caesar is adjacent
    local attacker = payload.attacker
	  for i = 1, 4 do
        local unit = getNeighbour(payload.defenderPos, i)
        if unit and (unit.id ~= attacker.id) and (unit.unitClassId == attacker.unitClassId or unit.unitClassId == "commander_caesar") and Wargroove.areAllies(attacker.playerId, unit.playerId) then
            return true
        end
	  end
	  return false
end


function NewConditions.spearman(payload)
  local attacker = payload.attacker
  for i = 1, 4 do
    local unit = getNeighbour(payload.attackerPos, i)
    if unit and (unit.id ~= attacker.id) and (unit.unitClassId == attacker.unitClassId) and Wargroove.areAllies(attacker.playerId, unit.playerId) then
      return true
    end
  end
  return false
end


function NewConditions.archer(payload)
    if payload.isCounter then
        return false
    end
    function isSame(a, b)
        return a.x == b.x and a.y == b.y
    end
    return payload.path == nil or (#payload.path == 0) or isSame(payload.attacker.startPos, payload.path[#payload.path])
end


function NewConditions.mage(payload)
    return Wargroove.getTerrainDefenceAt(payload.attackerPos) >= 3
end


function NewConditions.knight(payload)
    local distance = math.abs(payload.attackerPos.x - payload.attacker.startPos.x) + math.abs(payload.attackerPos.y - payload.attacker.startPos.y)
    return distance == 6
end


function NewConditions.merman(payload)
    local terrainName = Wargroove.getTerrainNameAt(payload.attackerPos)
    return terrainName == "river" or terrainName == "sea" or terrainName == "ocean" or terrainName == "reef"
end


function NewConditions.ballista(payload)
    local distance = math.abs(payload.attackerPos.x - payload.defenderPos.x) + math.abs(payload.attackerPos.y - payload.defenderPos.y)
    return distance <= 3
end


function NewConditions.trebuchet(payload)
    local distance = math.abs(payload.attackerPos.x - payload.defenderPos.x) + math.abs(payload.attackerPos.y - payload.defenderPos.y)
    return distance >= 5
end


function NewConditions.harpy(payload)
    local terrainName = Wargroove.getTerrainNameAt(payload.attackerPos)
    return terrainName == "mountain"
end


function NewConditions.witch(payload)
    local units = Wargroove.getAllUnitsForPlayer(payload.defender.playerId, true)
    for i, v in ipairs(units) do
        if v.unitClassId == "witch" and v.id ~= payload.defender.id then
            local distance = math.abs(v.pos.x - payload.defenderPos.x) + math.abs(v.pos.y - payload.defenderPos.y)
            if distance == 1 then
                return false
            end
        end
    end
    return true
end


function NewConditions.dragon(payload)
    local terrainName = Wargroove.getTerrainNameAt(payload.defenderPos)
    return terrainName == "road"
end

function NewConditions.giant(payload)
    return payload.attacker.health <= 40
end

function NewConditions.harpoonship(payload)
    local terrainName = Wargroove.getTerrainNameAt(payload.attackerPos)
    return terrainName == "reef"
end

function NewConditions.warship(payload)
    local terrainName = Wargroove.getTerrainNameAt(payload.attackerPos)
    return terrainName == "beach"
end

function NewConditions.turtle(payload)
    local terrainName = Wargroove.getTerrainNameAt(payload.attackerPos)
    return terrainName == "ocean"
end

function NewConditions.rifleman(payload)
    for i, stateKey in ipairs(payload.unitState) do
        if (stateKey.key == "ammo") then
            return tonumber(stateKey.value) == 1
        end
    end
    return false
end

-- Next to a soldier
function NewConditions.commander_mercia(payload)
    local attacker = payload.attacker
    for i = 1, 4 do
        local unit = getNeighbour(payload.attackerPos, i)
        if unit and (unit.id ~= attacker.id) and (unit.unitClassId == "soldier" or unit.unitClassId == "spearman" or unit.unitClassId == "archer") and Wargroove.areAllies(attacker.playerId, unit.playerId) then
            return true
        end
    end
    return false
end

-- Same as mage
function NewConditions.commander_emeric(payload)
    return Wargroove.getTerrainDefenceAt(payload.attackerPos) >= 3
end

-- Same as dog
function NewConditions.commander_caesar(payload)
    -- Crit is not valid if defender is at sea or in the air
    local attacker = payload.attacker
    local defenderClass = Wargroove.getUnitClass(payload.defender.unitClassId)

    local terrainName = Wargroove.getTerrainNameAt(payload.defenderPos)
    local defenderAtSea = false

    if (terrainName == "ocean" or terrainName == "reef" or terrainName == "sea") then
        defenderAtSea = true
    end

    if (not defenderAtSea) and (not defenderClass.inAir) then
        for i = 1, 4 do
            local unit = getNeighbour(payload.defenderPos, i)
            if unit and (unit.id ~= attacker.id) and (unit.unitClassId == "dog") and
            Wargroove.areAllies(attacker.playerId, unit.playerId) then
                return true
            end
        end
    end
    return false
end

-- If groove gauge is full
function NewConditions.commander_valder(payload)
    if (payload.attacker ~= nil and payload.attacker.grooveCharge ~= nil) then
        local groove = Wargroove.getGroove(payload.attacker.grooveId)
        return payload.attacker.grooveCharge >= groove.maxCharge
    else
        return false
    end
end

-- If fighting a commander
function NewConditions.commander_ragna(payload)
    local defenderClass = Wargroove.getUnitClass(payload.defender.unitClassId)
    return defenderClass.isCommander
end

-- Always active
function NewConditions.commander_sigrid(payload)
    -- Passive multiplier is inverse to current health
    local factor = ((100 - payload.attacker.health) / 100)
    local multiplier = 1.00 + factor
    payload.attacker.unitClass.passiveMultiplier = multiplier
    return true
end

-- If Greenfinger or defender is in a forest
function NewConditions.commander_greenfinger(payload)
    local terrainNameAttacker = Wargroove.getTerrainNameAt(payload.attackerPos)
    local terrainNameDefender = Wargroove.getTerrainNameAt(payload.defenderPos)
    return terrainNameAttacker == "forest" or terrainNameDefender == "forest"
end

-- Check player gold
function NewConditions.commander_nuru(payload)
    attackerMoney = Wargroove.getMoney(payload.attacker.playerId)

    if attackerMoney >= 500 then
        local factor = (attackerMoney / 50) / 100
        local multiplier = math.min(1.00 + factor, 2.00)
        payload.attacker.unitClass.passiveMultiplier = multiplier
        return true
    else
        return false
    end
end

-- Check if defender is alone. Ignore structures
function NewConditions.commander_sedge(payload)
    local defender = payload.defender
    local defenderClass = Wargroove.getUnitClass(defender.unitClassId)
    if (defenderClass.isStructure) then
        return false
    else
        for i = 1, 4 do
            local unit = getNeighbour(payload.defenderPos, i)
            if unit and (unit.id ~= defender.id) and Wargroove.areAllies(defender.playerId, unit.playerId) then
                local unitClass = Wargroove.getUnitClass(unit.unitClassId)
                if (not unitClass.isStructure) then
                  return false
                end
            end
        end
    end
    return true
end

-- Check if it`s a counter
function NewConditions.commander_tenri(payload)
    return payload.isCounter
end

-- Check if move range == 5
function NewConditions.commander_ryota(payload)
    local distance = math.abs(payload.attackerPos.x - payload.attacker.startPos.x) + math.abs(payload.attackerPos.y - payload.attacker.startPos.y)
    return distance == 5
end

-- Check if defender not a commander and is a ground.light unit.
function NewConditions.commander_koji(payload)
  local defenderClass = Wargroove.getUnitClass(payload.defender.unitClassId)
  local defenderTags = payload.defender.unitClass.tags
  for i, tag in ipairs(defenderTags) do
      if ((tag == "type.ground.light" or tag == "type.ground.hideout") and not defenderClass.isCommander) then
          return true
      end
  end
  return false
end

-- Check if turn number is even
function NewConditions.commander_elodie(payload)
    return (Wargroove.getTurnNumber() % 2) == 0
end

-- If defender has 90% or more health
function NewConditions.commander_darkmercia(payload)
    return payload.defender.health >= 100
end

-- If Mercival or enemy is near an allied structure. Does not work on structures.
function NewConditions.commander_mercival(payload)
    local defenderClass = Wargroove.getUnitClass(payload.defender.unitClassId)
    local attacker = payload.attacker
    local defender = payload.defender
    if (not defenderClass.isStructure) then
        -- Check Mercival and defender neighbours
        for i = 1, 4 do
            local attackerNeighbour = getNeighbour(payload.attackerPos, i)
            local defenderNeighbour = getNeighbour(payload.defenderPos, i)
            if attackerNeighbour and attackerNeighbour.id ~= attacker.id and Wargroove.areAllies(attacker.playerId, attackerNeighbour.playerId) then
                local unitClass = Wargroove.getUnitClass(attackerNeighbour.unitClassId)
                if (unitClass.isStructure) then
                    return true
                end
            elseif defenderNeighbour and defenderNeighbour ~= defender.id and Wargroove.areAllies(attacker.playerId, defenderNeighbour.playerId) then
                local unitClass = Wargroove.getUnitClass(defenderNeighbour.unitClassId)
                if (unitClass.isStructure) then
                    return true
                end
            end
        end

    end

    return false
end

-- If has not moved.
function NewConditions.commander_wulfar(payload)
    local distance = math.abs(payload.attackerPos.x - payload.attacker.startPos.x) + math.abs(payload.attackerPos.y - payload.attacker.startPos.y)
    return (distance <= 0) and (not payload.isCounter)
end

-- If defender has full health
function NewConditions.commander_twins(payload)
    return isFlank(payload.attacker, payload.attackerPos, payload.defenderPos)
end

-- If attacker or defender is inside smoke
function NewConditions.commander_vesper(payload)
    local attacker = payload.attacker
    local defender = payload.defender

    return (attacker.canBeAttacked ~= nil and not attacker.canBeAttacked) or (defender.canBeAttacked ~= nil and not defender.canBeAttacked)
end

return PassiveConditions
