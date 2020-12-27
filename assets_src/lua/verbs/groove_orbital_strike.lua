local Wargroove = require "wargroove/wargroove"
local GrooveVerb = require "wargroove/groove_verb"
local Combat = require "wargroove/combat"

local OrbitalStrike = GrooveVerb:new()

local goldCost = 1500


function OrbitalStrike:getMaximumRange(unit, endPos)
    return 96
end

function OrbitalStrike:canExecuteAnywhere(unit)
    return Wargroove.getMoney(unit.playerId) >= goldCost
end

function OrbitalStrike:getCostAt(unit, endPos, targetPos)
    return goldCost
end

function OrbitalStrike:getTargetType()
    return "all"
end


function OrbitalStrike:canExecuteWithTarget(unit, endPos, targetPos, strParam)
    if not self:canSeeTarget(targetPos) then
        return false
    end

    return true
end


function OrbitalStrike:execute(unit, targetPos, strParam, path)
    Wargroove.changeMoney(unit.playerId, -goldCost)

    Wargroove.setIsUsingGroove(unit.id, true)
    Wargroove.updateUnit(unit)

    Wargroove.playPositionlessSound("battleStart")
    Wargroove.playGrooveCutscene(unit.id, "orbital_strike", "nuru")

    Wargroove.playUnitAnimation(unit.id, "groove")
    Wargroove.playMapSound("nuru/nuruGroove", unit.pos)
    Wargroove.waitTime(1.7)

    Wargroove.playGrooveEffect()

    -- Randomly select 7 tiles inside a 2 splash radius area having targetPos as origin

    -- First, generate a table with all possible target coordinates
    local coordinates = Wargroove.getTargetsInRange(targetPos, 2, "all")

    -- Number of strike targets is lenght of coordinates divided by 2 (round up)
    local targetNumber = math.ceil(#coordinates / 2)

    -- Generate N random integers, where N is equal to target number
    local indexList = {}
    for i=1, #coordinates do
      indexList[i] = i
    end

    local function permute(tab, n, count, randomString)
      n = n or #tab
      for i = 1, count or n do
        local rng = Wargroove.pseudoRandomFromString(randomString .. ":" .. tostring(i))
        local j = math.ceil(math.max(count * rng, 1))
        tab[i], tab[j] = tab[j], tab[i]
      end
      return tab
    end

    local values = { targetPos.x, targetPos.y, Wargroove.getMoney(unit.playerId), unit.pos.x, unit.pos.y,
                     Wargroove.getTurnNumber(), Wargroove.getCurrentPlayerId() }
		local randomString = ""
		for i, v in ipairs(values) do
			randomString = randomString .. tostring(v) .. ":"
		end

    indexList = permute(indexList, targetNumber, #coordinates, randomString)

    permutedList = {}
    for i=1, targetNumber do
      permutedList[i] = indexList[i]
    end

    -- For each index, fire an orbital strike
    for i, index in ipairs(permutedList) do
      -- Get strike positon
      local pos = coordinates[index]

      -- Fire the laser beam!
      Wargroove.spawnPaletteSwappedMapAnimation(pos, 0, "fx/groove/nuru_groove_fx", unit.playerId)
      Wargroove.playMapSound("cutscene/teleportIn", pos)

      -- Deal damage at unit at target location (friendly fire is on)
      local u = Wargroove.getUnitAt(pos)
      if u then
        -- Depending on unit class, damage dealt is different
        local damageDealt = 100
        local unitClass = Wargroove.getUnitClass(u.unitClassId)

        if unitClass.isCommander then
          damageDealt = 25
        elseif unitClass.isStructure then
          if u.unitClassId == "hq" then
            damageDealt = 25
          else
            damageDealt = 50
          end
        end

        -- Reduce health
        u:setHealth(math.max(0, u.health - damageDealt), u.id)
        Wargroove.updateUnit(u)
        if not unitClass.isStructure then
          Wargroove.playUnitAnimation(u.id, "hit")
        end

      end

      Wargroove.waitTime(0.5)

    end

    Wargroove.waitTime(0.5)
end

return OrbitalStrike
