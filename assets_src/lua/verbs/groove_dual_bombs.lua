local Wargroove = require "wargroove/wargroove"
local GrooveVerb = require "wargroove/groove_verb"

local DualBombs = GrooveVerb:new()


function DualBombs:getMaximumRange(unit, endPos)
    return 4
end


function DualBombs:getTargetType()
    return "all"
end

DualBombs.selectedLocations = {}

function DualBombs:selectedLocationsContains(pos)
    for i, selectedPos in pairs(DualBombs.selectedLocations) do
        if selectedPos.x == pos.x and selectedPos.y == pos.y then
           return true
        end
     end
     return false
end

function DualBombs:canExecuteWithTarget(unit, endPos, targetPos, strParam)
    if not self:canSeeTarget(targetPos) then
        return false
    end

    return (not DualBombs.selectedLocationsContains(self, targetPos))
end

function DualBombs:preExecute(unit, targetPos, strParam, endPos)
    -- Target one: FIRE
    -- Target two: WATER

    DualBombs.selectedLocations = {}

    Wargroove.selectTarget()

    while Wargroove.waitingForSelectedTarget() do
        coroutine.yield()
    end

    local targetOne = Wargroove.getSelectedTarget()

    if (targetOne == nil) then
        return false, ""
    end

    Wargroove.displayTarget(targetOne)

    DualBombs.selectedLocations[0] = targetOne

    Wargroove.selectTarget()

    while Wargroove.waitingForSelectedTarget() do
        coroutine.yield()
    end

    local targetTwo = Wargroove.getSelectedTarget()

    if (targetTwo == nil) then
        DualBombs.selectedLocations = {}
        Wargroove.clearDisplayTargets()
        return false, ""
    end

    Wargroove.displayTarget(targetTwo)

    DualBombs.selectedLocations = {}

    Wargroove.clearDisplayTargets()

    return true, targetOne.x .. "," .. targetOne.y .. ";" .. targetTwo.x .. "," .. targetTwo.y
end

function DualBombs:parseTargets(strParam)
    local targetStrs={}
    local i = 1
    for targetStr in string.gmatch(strParam, "([^"..";".."]+)") do
        targetStrs[i] = targetStr
        i = i + 1
    end

    local targets = {}
    i = 1
    for idx, targetStr in pairs(targetStrs) do
        local vals = {}
        local j = 1
        for val in targetStr.gmatch(targetStr, "([^"..",".."]+)") do
            vals[j] = val
            j = j + 1
        end
        targets[i] = { x = tonumber(vals[1]), y = tonumber(vals[2])}
        i = i + 1
    end

    return targets
end

function DualBombs:execute(unit, targetPos, strParam, path)
    if strParam == "" then
        print("DualBombs:execute was not given any target positions.")
        return
    end

    local targetPositions = DualBombs.parseTargets(self, strParam)
    local firePosition = targetPositions[1]
    local waterPosition = targetPositions[2]

    -- Execute two grooves in succession
    -- Groove 1 - Scorching Fire

    Wargroove.setIsUsingGroove(unit.id, true)
    Wargroove.updateUnit(unit)

    Wargroove.playPositionlessSound("battleStart")
    Wargroove.playGrooveCutscene(unit.id, "area_damage", "orla")

    Wargroove.playUnitAnimation(unit.id, "groove2")
    Wargroove.playMapSound("twins/orlaGroove", unit.pos)
    Wargroove.waitTime(1.9)
    Wargroove.playMapSound("twins/orlaGrooveEffect", firePosition)
    Wargroove.spawnMapAnimation(firePosition, 3, "fx/groove/orla_groove_fx", "idle", "behind_units", {x = 12, y = 12})

    Wargroove.playGrooveEffect()

    local startingState = {}
    local pos = {key = "pos", value = "" .. firePosition.x .. "," .. firePosition.y}
    local radius = {key = "radius", value = "0"}
    table.insert(startingState, pos)
    table.insert(startingState, radius)
    Wargroove.spawnUnit(unit.playerId, {x = -100, y = -100}, "area_damage", false, "", startingState)

    Wargroove.waitTime(1.2)

    -- Groove 2 - Cooling Water
    Wargroove.playPositionlessSound("battleStart")
    Wargroove.playGrooveCutscene(unit.id, "area_heal", "errol")

    Wargroove.playUnitAnimation(unit.id, "groove")
    Wargroove.playMapSound("twins/errolGroove", waterPosition)
    Wargroove.waitTime(1.2)
    Wargroove.spawnMapAnimation(waterPosition, 3, "fx/groove/errol_groove_fx", "idle", "behind_units", {x = 12, y = 12})

    Wargroove.playGrooveEffect()

    local startingState = {}
    local pos = {key = "pos", value = "" .. waterPosition.x .. "," .. waterPosition.y}
    local radius = {key = "radius", value = "3"}
    table.insert(startingState, pos)
    table.insert(startingState, radius)
    Wargroove.spawnUnit(unit.playerId, {x = -100, y = -100}, "area_heal", false, "", startingState)

    Wargroove.waitTime(1.2)
end

function DualBombs:generateOrders(unitId, canMove)
    local orders = {}

    local unit = Wargroove.getUnitById(unitId)
    local unitClass = Wargroove.getUnitClass(unit.unitClassId)
    local movePositions = {}
    if canMove then
        movePositions = Wargroove.getTargetsInRange(unit.pos, unitClass.moveRange, "empty")
    end
    table.insert(movePositions, unit.pos)

    for i, pos in pairs(movePositions) do
        local targets = Wargroove.getTargetsInRangeAfterMove(unit, pos, pos, 4, "empty")
        if #targets >= 2 then
            for j, targetOne in pairs(targets) do
                if self:canSeeTarget(targetOne) then
                    for k=(j+1),(#targets) do
                        local targetTwo = targets[k]
                        if self:canSeeTarget(targetTwo) then
                            strParam = targetOne.x .. "," .. targetOne.y .. ";" .. targetTwo.x .. "," .. targetTwo.y
                            orders[#orders+1] = {targetPosition = targetOne, strParam = strParam, movePosition = pos, endPosition = pos}
                        end
                    end
                end
            end
        end
    end

    return orders
end

function DualBombs:getScore(unitId, order)
    local unit = Wargroove.getUnitById(unitId)
    local targets = Wargroove.getTargetsInRangeAfterMove(unit, order.endPosition, order.targetPosition, 3, "unit")

    local opportunityCost = -1
    local totalScore = 0
    local maxScore = 300

    for i, pos in ipairs(targets) do
        local u = Wargroove.getUnitAt(pos)
        if u ~= nil and (not u.unitClass.isStructure) then
            local uc = u.unitClass
            if not Wargroove.areEnemies(unit.playerId, u.playerId) then
                totalScore = totalScore - uc.cost / 2
            else
                totalScore = totalScore + uc.cost / 3
            end
        end
    end

    local score = totalScore/maxScore + opportunityCost
    return {score = score, introspection = {{key = "totalScore", value = totalScore}}}
end

return DualBombs
