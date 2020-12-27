local Wargroove = require "wargroove/wargroove"
local OldCombat = require "wargroove/combat"
local PassiveConditions = require "initialized/passive_conditions"

local Combat = {}

--
local defencePerShield = 0.10
local damageAt0Health = 0.0
local damageAt100Health = 1.0
local randomDamageMin = 0.0
local randomDamageMax = 0.1
--

-- This is called by the game when the map is loaded.
function Combat.init()
  OldCombat.getDamage = Combat.getDamage
  OldCombat.getPassiveMultiplier = Combat.getPassiveMultiplier
  OldCombat.solveRound = Combat.solveRound
end

function Combat:getDamage(attacker, defender, solveType, isCounter, attackerPos, defenderPos, attackerPath, isGroove, grooveWeaponIdOverride)
	if type(solveType) ~= "string" then
		error("solveType should be a string. Value is " .. tostring(solveType))
	end

	local delta = {x = defenderPos.x - attackerPos.x, y = defenderPos.y - attackerPos.y }
	local moved = attackerPath and #attackerPath > 1

	local randomValue = 0.5
	if solveType == "random" and Wargroove.isRNGEnabled() then
		local values = { attacker.id, attacker.unitClassId, attacker.startPos.x, attacker.startPos.y, attackerPos.x, attackerPos.y,
		                 defender.id, defender.unitClassId, defender.startPos.x, defender.startPos.y, defenderPos.x, defenderPos.y,
						 isCounter, Wargroove.getTurnNumber(), Wargroove.getCurrentPlayerId() }
		local str = ""
		for i, v in ipairs(values) do
			str = str .. tostring(v) .. ":"
		end
		randomValue = Wargroove.pseudoRandomFromString(str)
	end
	if solveType == "simulationOptimistic" then
		if isCounter then
			randomValue = 0
		else
			randomValue = 1
		end
	end
	if solveType == "simulationPessimistic" then
		if isCounter then
			randomValue = 1
		else
			randomValue = 0
		end
	end

	local attackerHealth = isGroove and 100 or attacker.health
	local attackerEffectiveness = (attackerHealth * 0.01) * (damageAt100Health - damageAt0Health) + damageAt0Health
  -- Sigrid always does full base damage --
  if attacker.unitClassId == "commander_sigrid" then
    attackerEffectiveness = 1.0
  end
	local defenderEffectiveness = (defender.health * 0.01) * (damageAt100Health - damageAt0Health) + damageAt0Health

	-- For structures, check if there's a garrison; if so, attack as if it was that instead
	local effectiveAttacker
	if attacker.garrisonClassId ~= '' then
		effectiveAttacker = {
			id = attacker.id,
			pos = attacker.pos,
			startPos = attacker.startPos,
			playerId = attacker.playerId,
			unitClassId = attacker.garrisonClassId,
			unitClass = Wargroove.getUnitClass(attacker.garrisonClassId),
			health = attackerHealth,
			state = attacker.state,
			damageTakenPercent = attacker.damageTakenPercent
		}
		attackerEffectiveness = 1.0
	else
		effectiveAttacker = attacker
	end

	local passiveMultiplier = self:getPassiveMultiplier(effectiveAttacker, defender, attackerPos, defenderPos, attackerPath, isCounter, attacker.state)

	local defenderUnitClass = Wargroove.getUnitClass(defender.unitClassId)
	local defenderIsInAir = defenderUnitClass.inAir
	local defenderIsStructure = defenderUnitClass.isStructure

	local terrainDefence
	if defenderIsInAir then
		terrainDefence = Wargroove.getSkyDefenceAt(defenderPos)
	elseif defenderIsStructure then
		terrainDefence = 0
	else
		terrainDefence = Wargroove.getTerrainDefenceAt(defenderPos)
	end

	local terrainDefenceBonus = terrainDefence * defencePerShield

	local baseDamage
	if (isGroove) then
		local weaponId
		if (grooveWeaponIdOverride ~= nil) then
			weaponId = grooveWeaponIdOverride
		else
			weaponId = attacker.unitClass.weapons[1].id
		end
		baseDamage = Wargroove.getWeaponDamageForceGround(weaponId, defender)
	else
		local weapon
		weapon, baseDamage = self:getBestWeapon(effectiveAttacker, defender, delta, moved, attackerPos.facing)

		if weapon == nil or (isCounter and not weapon.canMoveAndAttack) or baseDamage < 0.01 then
			return nil, false
		end

		if #(weapon.terrainExclusion) > 0 then
			local targetTerrain = Wargroove.getTerrainNameAt(defenderPos)
			for i, terrain in ipairs(weapon.terrainExclusion) do
				if targetTerrain == terrain then
					return nil, false
				end
			end
		end
	end

	local multiplier = 1.0
	if Wargroove.isHuman(defender.playerId) then
		multiplier = Wargroove.getDamageMultiplier()

		-- If the player is on "easy" for damage, make the AI overlook that.
		if multiplier < 1.0 and solveType == "aiSimulation" then
			multiplier = 1.0
		end
	end

	-- Damage reduction
	multiplier = multiplier * defender.damageTakenPercent / 100

	local damage = self:solveDamage(baseDamage, attackerEffectiveness, defenderEffectiveness, terrainDefenceBonus, randomValue, passiveMultiplier, multiplier)

	local hasPassive = passiveMultiplier > 1.01
	return damage, hasPassive
end

function Combat:getPassiveMultiplier(attacker, defender, attackerPos, defenderPos, path, isCounter, unitState)
	local condition = PassiveConditions:getPassiveConditions()[attacker.unitClassId]
	local payload = {
		attacker = attacker,
		defender = defender,
		attackerPos = attackerPos,
		defenderPos = defenderPos,
		path = path,
		isCounter = isCounter,
		unitState = unitState
	}

	if condition ~= nil and condition(payload) then
		return attacker.unitClass.passiveMultiplier
	else
		return 1.0
	end
end

function Combat:solveRound(attacker, defender, solveType, isCounter, attackerPos, defenderPos, attackerPath)
	if (defender.canBeAttacked == false and attacker.unitClassId ~= "commander_vesper" and attacker.unitClassId ~= "shadow_vesper") then
		return nil, false
	end

	local damage, hadPassive = self:getDamage(attacker, defender, solveType, isCounter, attackerPos, defenderPos, attackerPath, nil, false, false)
	if (damage == nil) then
		return nil, false
	end

	local defenderHealth = math.floor(defender.health - damage)
	return defenderHealth, hadPassive
end

return Combat
