local Wargroove = require "wargroove/wargroove"
local Combat = require "wargroove/combat"
local GrooveVerb = require "wargroove/groove_verb"

local Diplomacy = GrooveVerb:new()


function Diplomacy:getMaximumRange(unit, endPos)
    return 1
end


function Diplomacy:getTargetType()
    return "unit"
end


function Diplomacy:canExecuteWithTarget(unit, endPos, targetPos, strParam)
    if not self:canSeeTarget(targetPos) then
        return false
    end

    local targetUnit = Wargroove.getUnitAt(targetPos)
    return targetUnit and targetUnit.unitClass.isStructure and Wargroove.areEnemies(unit.playerId, targetUnit.playerId)
end

function Diplomacy:preExecute(unit, targetPos, strParam, endPos)
    return true, Wargroove.chooseFish(targetPos)
end

function Diplomacy:execute(unit, targetPos, strParam, path)
    Wargroove.setIsUsingGroove(unit.id, true)
    Wargroove.updateUnit(unit)

    Wargroove.playPositionlessSound("battleStart")
    Wargroove.playGrooveCutscene(unit.id)

    local facingOverride = ""
    if targetPos.x > unit.pos.x then
        facingOverride = "right"
    elseif targetPos.x < unit.pos.x then
        facingOverride = "left"
    end

    local grooveAnimation = "groove"
    if targetPos.y < unit.pos.y then
        grooveAnimation = "groove_up"
    elseif targetPos.y > unit.pos.y then
        grooveAnimation = "groove_down"
    end

    if facingOverride ~= "" then
        Wargroove.setFacingOverride(unit.id, facingOverride)
    end

    Wargroove.playUnitAnimation(unit.id, grooveAnimation)
    Wargroove.playMapSound("mercival/mercivalGroove", targetPos)
    Wargroove.waitTime(3.0)

    Wargroove.playGrooveEffect()
    Wargroove.unsetFacingOverride(unit.id)
    Wargroove.playUnitAnimation(unit.id, "groove_end")
    Wargroove.openFishingUI(unit.pos, strParam)
    Wargroove.waitTime(0.5)
    Wargroove.playMapSound("mercival/mercivalGrooveCatch", unit.pos)
    Wargroove.waitTime(2.5)

    -- Capture structure after fishing
    local targetUnit = Wargroove.getUnitAt(targetPos);
    local previousOwner = targetUnit.playerId
    targetUnit:setHealth(100, unit.id)
    targetUnit.playerId = unit.playerId
    Wargroove.updateUnit(targetUnit)

    -- If enemy HQ was captured, automatically eliminates that player
    if (targetUnit.unitClassId == "hq") then
        Wargroove.eliminate(previousOwner)
    end
end

function Diplomacy:generateOrders(unitId, canMove)
    local orders = {}

    local unit = Wargroove.getUnitById(unitId)
    local unitClass = Wargroove.getUnitClass(unit.unitClassId)
    local movePositions = {}
    if canMove then
        movePositions = Wargroove.getTargetsInRange(unit.pos, unitClass.moveRange, "empty")
    end
    table.insert(movePositions, unit.pos)

    for i, pos in pairs(movePositions) do
        local targets = Wargroove.getTargetsInRangeAfterMove(unit, pos, pos, 1, "unit")
        for j, targetPos in pairs(targets) do
            local u = Wargroove.getUnitAt(targetPos)
            if u ~= nil then
                local uc = Wargroove.getUnitClass(u.unitClassId)
                if Wargroove.areEnemies(u.playerId, unit.playerId) and uc.isStructure then
                    orders[#orders+1] = {targetPosition = targetPos, strParam = "chucklefish", movePosition = pos, endPosition = pos}
                end
            end
        end
    end

    return orders
end

function Diplomacy:getScore(unitId, order)
    local unit = Wargroove.getUnitById(unitId)

    local targetUnit = Wargroove.getUnitAt(order.targetPosition)
    local targetUnitClass = Wargroove.getUnitClass(targetUnit.unitClassId)

    local opportunityCost = -1
    local score = targetUnitClass.cost
    local maxScore = 300

    local normalizedScore = 2 * score / maxScore + opportunityCost

    return {score = normalizedScore, introspection = {
        {key = "unitCost", value = targetUnitClass.cost},
        {key = "unitHealth", value = targetUnit.health},
        {key = "maxScore", value = maxScore},
        {key = "opportunityCost", value = opportunityCost}}}
end

return Diplomacy
