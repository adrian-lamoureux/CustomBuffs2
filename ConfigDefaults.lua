local _, addonTable = ...;
local CustomBuffs = addonTable.CustomBuffs;


-------------------------------------------------------------------------
-------------------------------------------------------------------------

function CustomBuffs:Defaults()
	local defaults = {};

	defaults.global = {
		["unknownInterrupts"] = {},
	};
	defaults.profile = {
		colorPartyNames = false,
		alwaysShowFrames = false,
		cooldownFlash = true,
		frameScale = 1,
		buffScale = 1,
		debuffScale = 1,
		bossDebuffScale = 1.5,
		throughputBuffScale = 1.2,
		loadTweaks = false,
		extraDebuffs = false,
		extraBuffs = false,
		cleanNames = true,
		maxNameLength = 12,
		showRaidMarkers = true,
		showCastBars = false
	};

	return defaults;
end
