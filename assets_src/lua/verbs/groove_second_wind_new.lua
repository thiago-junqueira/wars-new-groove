local Wargroove = require "wargroove/wargroove"
local GrooveVerb = require "wargroove/groove_verb"

local SecondWind = GrooveVerb:new()

local full_charge_groove = false

function SecondWind:getMaximumRange(unit, endPos)
    return 0
end


function SecondWind:getTargetType()
    return "unit"
end


function SecondWind:execute(unit, targetPos, strParam, path)
    Wargroove.setIsUsingGroove(unit.id, true)
    Wargroove.updateUnit(unit)

    Wargroove.playPositionlessSound("battleStart")
    Wargroove.playGrooveCutscene(unit.id)

    Wargroove.playUnitAnimation(unit.id, "groove")
    Wargroove.playMapSound("caesar/caesarGroove", unit.pos)
    Wargroove.spawnMapAnimation(unit.pos, 1, "fx/groove/caesar_groove_fx")
    Wargroove.waitTime(1.9)
    Wargroove.playMapSound("caesar/caesarGrooveInspired", unit.pos)

    Wargroove.playGrooveEffect()

    -- If at full charge, Caesar does not lose his turn (see onPostUpdateUnit method)
    local groove = Wargroove.getGroove(unit.grooveId)
    if (unit.grooveCharge >= groove.maxCharge) then
        full_charge_groove = true
    else
        full_charge_groove = false
    end

    for i, pos in ipairs(Wargroove.getTargetsInRange(targetPos, 1, "unit")) do
        local u = Wargroove.getUnitAt(pos)
        if Wargroove.areAllies(u.playerId, unit.playerId) and u.id ~= unit.id then
            if u.hadTurn then
                Wargroove.spawnMapAnimation(pos, 0, "fx/groove/inspire_unit")
                u.hadTurn = false
                Wargroove.updateUnit(u)
            end
        end
    end

    Wargroove.waitTime(1.0)
end

function SecondWind:generateOrders(unitId, canMove)
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
        if #targets ~= 0 then
            orders[#orders+1] = {targetPosition = pos, strParam = "", movePosition = pos, endPosition = pos}
        end
    end

    return orders
end

function SecondWind:getScore(unitId, order)
    local unit = Wargroove.getUnitById(unitId)
    local targets = Wargroove.getTargetsInRangeAfterMove(unit, order.endPosition, order.targetPosition, 1, "unit")

    local opportunityCost = -1

    local effectScore = 0
    for i, pos in ipairs(targets) do
        local u = Wargroove.getUnitAt(pos)
        if u ~= nil and Wargroove.areAllies(u.playerId, unit.playerId) and u.hadTurn then
            local uc = Wargroove.getUnitClass(u.unitClassId)
            if not uc.isStructure then
                local uValue = math.sqrt(uc.cost / 100)
                if uc.isCommander then
                    uValue = 10
                end
                effectScore = effectScore + (u.health / 100) * uValue
            end
        end
    end


    local score = opportunityCost + effectScore

    return {score = score, introspection = {
        { key = "opportunityCost", value = opportunityCost },
        { key = "effectScore", value = effectScore }}}
end

function SecondWind:onPostUpdateUnit(unit, targetPos, strParam, path)
    GrooveVerb.onPostUpdateUnit(self, unit, targetPos, strParam, path)
    if (full_charge_groove) then
        unit.hadTurn = false
    end
end

return SecondWind
