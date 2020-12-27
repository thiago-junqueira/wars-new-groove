local Wargroove = require "wargroove/wargroove"
local GrooveVerb = require "wargroove/groove_verb"

local RaiseDead = GrooveVerb:new()

local spearman_summon_cost = 60

function RaiseDead:getMaximumRange(unit, endPos)
    return 1
end


function RaiseDead:getTargetType()
    return "empty"
end


function RaiseDead:canExecuteWithTarget(unit, endPos, targetPos, strParam)
    if not self:canSeeTarget(targetPos) then
        return false
    end

    local unitThere = Wargroove.getUnitAt(targetPos)
    return (unitThere == nil or unitThere == unit) and Wargroove.canStandAt("soldier", targetPos)
end


function RaiseDead:execute(unit, targetPos, strParam, path)
    Wargroove.setIsUsingGroove(unit.id, true)
    Wargroove.updateUnit(unit)

    Wargroove.playPositionlessSound("battleStart")
    Wargroove.playGrooveCutscene(unit.id)

    Wargroove.playUnitAnimation(unit.id, "groove")
    Wargroove.playMapSound("valder/valderGroove", unit.pos)
    Wargroove.waitTime(1.7)

    Wargroove.playGrooveEffect()

    -- Check value of groove charge and spawn different units based on it
    local groove = Wargroove.getGroove(unit.grooveId)
    if (unit.grooveCharge >= groove.maxCharge) then
        -- Spawn mage
        Wargroove.spawnUnit(unit.playerId, targetPos, "felheim:mage", false, "")
    elseif (unit.grooveCharge >= spearman_summon_cost) then
        -- Spawn spearman
        Wargroove.spawnUnit(unit.playerId, targetPos, "felheim:spearman", false, "")
    else
        -- Spawn soldier
        Wargroove.spawnUnit(unit.playerId, targetPos, "felheim:soldier", false, "summon")
    end

    if Wargroove.canCurrentlySeeTile(targetPos) then
        Wargroove.spawnMapAnimation(targetPos, 0, "fx/mapeditor_unitdrop")
    end

    Wargroove.playMapSound("valder/valderGrooveSummon", targetPos)
    Wargroove.waitTime(1.0)
end

function RaiseDead:generateOrders(unitId, canMove)
    local orders = {}

    local unit = Wargroove.getUnitById(unitId)
    local unitClass = Wargroove.getUnitClass(unit.unitClassId)
    local movePositions = {}
    if canMove then
        movePositions = Wargroove.getTargetsInRange(unit.pos, unitClass.moveRange, "empty")
    end
    table.insert(movePositions, unit.pos)

    for i, pos in pairs(movePositions) do
        local targets = Wargroove.getTargetsInRangeAfterMove(unit, pos, pos, 1, "empty")
        for j, targetPos in pairs(targets) do
            if targetPos ~= pos  and Wargroove.canStandAt("soldier", targetPos) and self:canSeeTarget(targetPos) then
                orders[#orders+1] = {targetPosition = targetPos, strParam = "", movePosition = pos, endPosition = pos}
            end
        end
    end

    return orders
end

function RaiseDead:getScore(unitId, order)
    return {score = 2, introspection = {}}
end

-- Override consume groove method to allow different values to be consumed
function RaiseDead:consumeGroove(unit)
    local groove = Wargroove.getGroove(unit.grooveId)
    -- If charge is at MAX, deplete everything. Else, reduce by groove cost.
    if (unit.grooveCharge >= groove.maxCharge) then
        unit.grooveCharge = 0
    elseif (unit.grooveCharge >= spearman_summon_cost) then
        unit.grooveCharge = unit.grooveCharge - spearman_summon_cost
    else
        unit.grooveCharge = unit.grooveCharge - groove.chargePerUse
    end
    Wargroove.updateUnit(unit)
end

return RaiseDead
