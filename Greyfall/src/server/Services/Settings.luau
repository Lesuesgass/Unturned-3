-- The session's choices from the main menu: mode, map and difficulty.
-- Set once by Main before the world is built; every service reads its rules from here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Settings = {
	mode = Config.DefaultMode,
	map = Config.DefaultMap,
	difficulty = Config.DefaultDifficulty,
}

function Settings.rules()
	return Config.Difficulty[Settings.difficulty] or Config.Difficulty.Medium
end

-- Chance that a hit causes bleeding. weaponChance is nil for zombie hits.
function Settings.bleedChance(weaponChance: number?): number
	local rules = Settings.rules()
	if not rules.bleeding then
		return 0
	end
	if weaponChance == nil then
		return rules.zombieBleedChance
	end
	return math.min(0.9, weaponChance * rules.weaponBleedScale)
end

return Settings
