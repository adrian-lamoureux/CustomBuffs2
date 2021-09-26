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
		nameFont = "Friz Quadrata TT",
		nameSize = 10,
		useClassColors = true,
		frameAlpha = 1,
		colorPartyNames = false,
		alwaysShowFrames = false,
		cooldownFlash = true,
		frameScale = 1.2,
		buffScale = 0.9,
		debuffScale = 0.9,
		bossDebuffScale = 1.1,
		throughputBuffScale = 1,
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
