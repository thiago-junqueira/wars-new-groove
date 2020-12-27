local Wargroove = require "wargroove/wargroove"
local Steal = require "verbs/steal"

local StealOrla = Steal:new()

function StealOrla:canExecuteWithTargetId(id)
    return id ~= "hq"
end

function StealOrla:getAmountToSteal()
    return 150
end

function Steal:execute(unit, targetPos, strParam, path)
    local targetUnit = Wargroove.getUnitAt(targetPos)
    local amountToTake = self:getAmountToSteal()

    Wargroove.playMapSound("thiefSteal", targetPos)
    Wargroove.waitTime(0.2)
    Wargroove.spawnMapAnimation(targetPos, 0, "fx/ransack_1", "default", "over_units", { x = 12, y = 0 })
    Wargroove.waitTime(0.8)
    Wargroove.spawnMapAnimation(unit.pos, 0, "fx/ransack_2", "default", "over_units", { x = 12, y = 0 })
    Wargroove.waitTime(0.3)
    Wargroove.playMapSound("thiefGoldObtained", targetPos)
    Wargroove.waitTime(0.3)

    Wargroove.changeMoney(unit.playerId, amountToTake)
    Wargroove.changeMoney(targetUnit.playerId, -amountToTake)

    if (targetUnit.unitClassId ~= "hq") then
        targetUnit:setHealth(targetUnit.health - 25, unit.id)
        Wargroove.updateUnit(targetUnit)
    end

    Wargroove.waitTime(0.5)
end

return StealOrla
