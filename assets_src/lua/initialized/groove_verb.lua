local Wargroove = require "wargroove/wargroove"
local OldGrooveVerb = require "wargroove/groove_verb"

local GrooveVerb = {}

function GrooveVerb.init()
  OldGrooveVerb.consumeGroove = GrooveVerb.consumeGroove
end

function GrooveVerb:consumeGroove(unit)
    local groove = Wargroove.getGroove(unit.grooveId)
    -- If charge is at MAX, deplete everything. Else, reduce by groove cost.
    if (unit.grooveCharge >= groove.maxCharge) then
        unit.grooveCharge = 0
    else
        unit.grooveCharge = unit.grooveCharge - groove.chargePerUse
    end
    Wargroove.updateUnit(unit)
end

return GrooveVerb
