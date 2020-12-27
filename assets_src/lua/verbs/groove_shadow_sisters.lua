local Wargroove = require "wargroove/wargroove"
local GrooveVerb = require "wargroove/groove_verb"

local ShadowSisters = GrooveVerb:new()


function ShadowSisters:getMaximumRange(unit, endPos)
    return 1
end


function ShadowSisters:getTargetType()
    return "all"
end

ShadowSisters.selectedLocations = {}

function ShadowSisters:selectedLocationsContains(pos)
    for i, selectedPos in pairs(ShadowSisters.selectedLocations) do
        if selectedPos.x == pos.x and selectedPos.y == pos.y then
           return true
        end
     end
     return false
end

function ShadowSisters:canExecuteWithTarget(unit, endPos, targetPos, strParam)
    if not self:canSeeTarget(targetPos) then
        return false
    end

    local u = Wargroove.getUnitAt(targetPos)
    return (not ShadowSisters.selectedLocationsContains(self, targetPos))
        and (endPos.x ~= targetPos.x or endPos.y ~= targetPos.y)
        and (u == nil or unit.id == u.id)
        and Wargroove.canStandAt("shadow_vesper", targetPos)
end

function ShadowSisters:preExecute(unit, targetPos, strParam, endPos)
    ShadowSisters.selectedLocations = {}

    Wargroove.selectTarget()

    while Wargroove.waitingForSelectedTarget() do
        coroutine.yield()
    end

    local targetOne = Wargroove.getSelectedTarget()

    if (targetOne == nil) then
        return false, ""
    end

    Wargroove.displayTarget(targetOne)

    ShadowSisters.selectedLocations[0] = targetOne

    Wargroove.selectTarget()

    while Wargroove.waitingForSelectedTarget() do
        coroutine.yield()
    end

    local targetTwo = Wargroove.getSelectedTarget()

    if (targetTwo == nil) then
        ShadowSisters.selectedLocations = {}
        Wargroove.clearDisplayTargets()
        return false, ""
    end

    Wargroove.displayTarget(targetTwo)

    ShadowSisters.selectedLocations = {}

    Wargroove.clearDisplayTargets()

    return true, targetOne.x .. "," .. targetOne.y .. ";" .. targetTwo.x .. "," .. targetTwo.y
end

function ShadowSisters:parseTargets(strParam)
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

function ShadowSisters:execute(unit, targetPos, strParam, path)
    if strParam == "" then
        print("ShadowSisters:execute was not given any target positions.")
        return
    end

    Wargroove.setIsUsingGroove(unit.id, true)
    Wargroove.updateUnit(unit)

    Wargroove.playPositionlessSound("battleStart")
    Wargroove.playGrooveCutscene(unit.id, "shadow_sisters")

    local targetPositions = ShadowSisters.parseTargets(self, strParam)

    Wargroove.playUnitAnimation(unit.id, "groove")
    Wargroove.playMapSound("vesper/vesperGroove", unit.pos)
    Wargroove.waitTime(1.1)
    Wargroove.playMapSound("cutscene/smokeBomb", unit.pos)
    Wargroove.spawnMapAnimation(unit.pos, 2, "fx/groove/vesper_groove_fx", "idle", "over_units", {x = 12, y = 12})

    Wargroove.waitTime(0.3)

    Wargroove.playGrooveEffect()

    -- Summon shadow sisters
    for i, sisterPos in pairs(targetPositions) do
        local id = Wargroove.spawnUnit(unit.playerId, sisterPos, "shadow_vesper", false, "")
        if Wargroove.canCurrentlySeeTile(sisterPos) then
            Wargroove.spawnMapAnimation(sisterPos, 0, "fx/mapeditor_unitdrop")
        end

        -- Shadow Sister starts with full groove charge.
        local unit = Wargroove.getUnitById(id)
        local groove = Wargroove.getGroove(unit.grooveId)
        unit.grooveCharge = groove.maxCharge / 2
        Wargroove.updateUnit(unit)
    end

    Wargroove.waitTime(1.0)
end

function ShadowSisters:generateOrders(unitId, canMove)
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

function ShadowSisters:getScore(unitId, order)
    local unit = Wargroove.getUnitById(unitId)
    local targets = ShadowSisters:parseTargets(order.strParam)

    local opportunityCost = -1
    local totalScore = 0

    for i, pos in ipairs(targets) do
        totalScore = totalScore + Wargroove.getAIUnitRecruitScore("shadow_vesper", pos)
    end

    return {score = totalScore + opportunityCost, introspection = {
        {key = "totalScore", value = totalScore},
        {key = "opportunityCost", value = opportunityCost}}}
end

return ShadowSisters
