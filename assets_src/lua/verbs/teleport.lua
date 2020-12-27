local Wargroove = require "wargroove/wargroove"
local Verb = require "wargroove/verb"

local Teleport = Verb:new()
local spellCost = 500

function Teleport:getMaximumRange(unit, endPos)
    return 3
end

function Teleport:getTargetType()
    return "all"
end

function Teleport:canExecuteAnywhere(unit)
    return Wargroove.getMoney(unit.playerId) >= spellCost
end

function Teleport:getCostAt(unit, endPos, targetPos)
    return spellCost
end

function Teleport:canExecuteWithTarget(unit, endPos, targetPos, strParam)
    if not self:canSeeTarget(targetPos) then
        return false
    end

    local u = Wargroove.getUnitAt(targetPos)
    local uc = Wargroove.getUnitClass("commander_emeric")
    return (u == nil or u.id == unit.id) and Wargroove.canStandAt("commander_emeric", targetPos)
end

function Teleport:execute(unit, targetPos, strParam, path)
    Wargroove.changeMoney(unit.playerId, -spellCost)

    Wargroove.spawnMapAnimation(unit.pos, 0, "fx/hex_spell", "idle", "behind_units", {x = 13, y = 16})
    Wargroove.playMapSound("witchSpell", unit.pos)
    Wargroove.waitTime(1.4)

    unit.pos = { x = targetPos.x, y = targetPos.y }
    Wargroove.updateUnit(unit)

    Wargroove.spawnPaletteSwappedMapAnimation(targetPos, 0, "fx/groove/nuru_groove_fx", unit.playerId)
    Wargroove.playMapSound("cutscene/teleportIn", targetPos)
    Wargroove.waitTime(1.0)
end

function Teleport:onPostUpdateUnit(unit, targetPos, strParam, path)
    GrooveVerb.onPostUpdateUnit(self, unit, targetPos, strParam, path)
    unit.pos = targetPos
    unit.hadTurn = false
end

function Teleport:generateOrders(unitId, canMove)
    local orders = {}

    local unit = Wargroove.getUnitById(unitId)
    local unitClass = Wargroove.getUnitClass(unit.unitClassId)
    local movePositions = {}
    if canMove then
        movePositions = Wargroove.getTargetsInRange(unit.pos, unitClass.moveRange, "empty")
    end
    table.insert(movePositions, unit.pos)

    for i, pos in pairs(movePositions) do
        if Wargroove.canStandAt("commander_emeric", pos) then
            local targets = Wargroove.getTargetsInRangeAfterMove(unit, pos, pos, 4, "empty")
            for j, target in pairs(targets) do
                if self:canSeeTarget(target) and Wargroove.canStandAt("commander_emeric", target) then
                    orders[#orders+1] = {targetPosition = target, strParam = "", movePosition = pos, endPosition = target}
                end
            end
        end
    end

    return orders
end

function Teleport:getScore(unitId, order)
    local unit = Wargroove.getUnitById(unitId)

    local opportunityCost = -1
    local effectivenessScore = 0.0
    local totalValue = 0.0

    local teleportEndDefense = Wargroove.getTerrainDefenceAt(order.endPosition)

    if teleportEndDefense >= 3 then
      effectivenessScore = 1.0
    end

    local locationGradient = 0.0
    if (Wargroove.getAICanLookAhead(unitId)) then
        locationGradient = Wargroove.getAILocationScore(unit.unitClassId, order.endPosition) - Wargroove.getAILocationScore(unit.unitClassId, unit.pos)
    end
    local gradientBonus = 0.0
    if (locationGradient > 0.0001) then
        gradientBonus = 0.25
    end

    local locationScore = Wargroove.getAIUnitValue(unit.id, order.endPosition) - Wargroove.getAIUnitValue(unit.id, unit.pos)

    local bravery = Wargroove.getAIBraveryBonus()
    local attackBias = Wargroove.getAIAttackBias()

    local score = (effectivenessScore + gradientBonus + bravery) * attackBias + locationScore + opportunityCost
    local introspection = {
        {key = "effectivenessScore", value = effectivenessScore},
        {key = "totalValue", value = totalValue},
        {key = "bravery", value = bravery},
        {key = "attackBias", value = attackBias},
        {key = "locationScore", value = locationScore},
        {key = "opportunityCost", value = opportunityCost}}

    return {score = score, introspection = introspection}
end

return Teleport
