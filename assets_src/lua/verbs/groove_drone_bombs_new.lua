local Wargroove = require "wargroove/wargroove"
local GrooveVerb = require "wargroove/groove_verb"

local DroneBombs = GrooveVerb:new()


function DroneBombs:getMaximumRange(unit, endPos)
    return 1
end


function DroneBombs:getTargetType()
    return "all"
end

DroneBombs.selectedLocations = {}

function DroneBombs:selectedLocationsContains(pos)
    for i, selectedPos in pairs(DroneBombs.selectedLocations) do
        if selectedPos.x == pos.x and selectedPos.y == pos.y then
           return true
        end
     end
     return false
end

function DroneBombs:canExecuteWithTarget(unit, endPos, targetPos, strParam)
    if not self:canSeeTarget(targetPos) then
        return false
    end

    local u = Wargroove.getUnitAt(targetPos)
    return (not DroneBombs.selectedLocationsContains(self, targetPos))
        and (endPos.x ~= targetPos.x or endPos.y ~= targetPos.y)
        and (u == nil or unit.id == u.id)
        and Wargroove.canStandAt("drone", targetPos)
end

function DroneBombs:preExecute(unit, targetPos, strParam, endPos)
    -- Modified to spawn 3 bombs if groove 100%. 1 if at least 40%.
    DroneBombs.selectedLocations = {}

    -- Bomb 1
    Wargroove.selectTarget()

    while Wargroove.waitingForSelectedTarget() do
        coroutine.yield()
    end

    local targetOne = Wargroove.getSelectedTarget()

    if (targetOne == nil) then
        return false, ""
    end

    Wargroove.displayTarget(targetOne)
    DroneBombs.selectedLocations[0] = targetOne

    -- Only spawn 2 more bombs if groove value >= max charge
    -- Else, finish preExecute
    local groove = Wargroove.getGroove(unit.grooveId)
    if (unit.grooveCharge >= groove.maxCharge) then
        -- Bomb 2
        Wargroove.selectTarget()

        while Wargroove.waitingForSelectedTarget() do
            coroutine.yield()
        end

        local targetTwo = Wargroove.getSelectedTarget()

        if (targetTwo == nil) then
            DroneBombs.selectedLocations = {}
            Wargroove.clearDisplayTargets()
            return false, ""
        end

        Wargroove.displayTarget(targetTwo)
        DroneBombs.selectedLocations[1] = targetTwo

        -- Bomb 3
        Wargroove.selectTarget();

        while Wargroove.waitingForSelectedTarget() do
            coroutine.yield()
        end

        local targetThree = Wargroove.getSelectedTarget()

        if (targetThree == nil) then
            DroneBombs.selectedLocations = {}
            Wargroove.clearDisplayTargets()
            return false, ""
        end

        Wargroove.displayTarget(targetThree)
        DroneBombs.selectedLocations[2] = targetThree
    end

    -- Create return string
    local targetStr = ""
    for i, target in pairs(DroneBombs.selectedLocations) do
        targetStr = targetStr .. target.x .. "," .. target.y .. ";"
    end

    -- Cleanup and return target string
    DroneBombs.selectedLocations = {}
    Wargroove.clearDisplayTargets()

    return true, targetStr
end

function DroneBombs:parseTargets(strParam)
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

function DroneBombs:execute(unit, targetPos, strParam, path)
    if strParam == "" then
        print("DroneBomb:execute was not given any target positions.")
        return
    end

    Wargroove.setIsUsingGroove(unit.id, true)
    Wargroove.updateUnit(unit)

    Wargroove.playPositionlessSound("battleStart")
    Wargroove.playGrooveCutscene(unit.id)

    local targetPositions = DroneBombs.parseTargets(self, strParam)

    Wargroove.playUnitAnimation(unit.id, "groove")
    Wargroove.playMapSound("koji/kojiGroove", unit.pos)
    Wargroove.waitTime(1.1)
    Wargroove.playMapSound("koji/kojiDroneSpawn", unit.pos)

    for i, dronePos in pairs(targetPositions) do
        local spawnAnimation = ""
        if dronePos.x == unit.pos.x and dronePos.y > unit.pos.y then
            spawnAnimation = "spawn_down"
        elseif dronePos.x == unit.pos.x and dronePos.y < unit.pos.y then
            spawnAnimation = "spawn_up"
        elseif dronePos.y == unit.pos.y and dronePos.x > unit.pos.x then
            spawnAnimation = "spawn_right"
        elseif dronePos.y == unit.pos.y and dronePos.x < unit.pos.x then
            spawnAnimation = "spawn_left"
        end
        Wargroove.spawnUnit(unit.playerId, dronePos, "drone", false, spawnAnimation)
    end
    Wargroove.waitTime(0.3)

    Wargroove.playGrooveEffect()

    Wargroove.waitTime(1.6)

    Wargroove.waitTime(0.5)
end

function DroneBombs:generateOrders(unitId, canMove)
    local orders = {}

    local unit = Wargroove.getUnitById(unitId)
    local groove = Wargroove.getGroove(unit.grooveId)
    local unitClass = Wargroove.getUnitClass(unit.unitClassId)
    local movePositions = {}
    if canMove then
        movePositions = Wargroove.getTargetsInRange(unit.pos, unitClass.moveRange, "empty")
    end
    table.insert(movePositions, unit.pos)

    for i, pos in pairs(movePositions) do
        local targets = Wargroove.getTargetsInRangeAfterMove(unit, pos, pos, 1, "empty")
        if (#targets >= 3 and unit.grooveCharge >= groove.maxCharge) then
            local strParam = ""
            local seenPositions = 0
            local targetOne = nil;
            for j, target in pairs(targets) do
                if self:canSeeTarget(target) then
                    if (targetOne == nil) then
                        targetOne = target
                    end
                    strParam = strParam .. target.x .. "," .. target.y .. ";"
                    seenPositions = seenPositions + 1
                    -- IA can cheat and spawn 4 drones if not checked
                    if (seenPositions >=3) then
                        break
                    end
                end
            end
            -- If all target positions can be seen, send the order
            if (seenPositions >= 3) then
              orders[#orders+1] = {targetPosition = targetOne, strParam = strParam, movePosition = pos, endPosition = pos}
            end
        end
    end

    return orders
end

function DroneBombs:getScore(unitId, order)
    local unit = Wargroove.getUnitById(unitId)
    local targets = DroneBombs:parseTargets(order.strParam)

    local opportunityCost = -1
    local totalScore = 0

    for i, pos in ipairs(targets) do
        totalScore = totalScore + Wargroove.getAIUnitRecruitScore("drone", pos)
    end

    return {score = totalScore + opportunityCost, introspection = {
        {key = "totalScore", value = totalScore},
        {key = "opportunityCost", value = opportunityCost}}}
end

return DroneBombs
