local _, addonTable = ...
local CustomBuffs = addonTable.CustomBuffs

local profs;
-------------------------------------------------------------------------
-------------------------------------------------------------------------
local function generateProfiles()
	profs = profs or {};
	for i=1, GetNumRaidProfiles() or 5 do
		local name = GetRaidProfileName(i);
		if CustomBuffs.verbose then print("Found profile", name); end
		if name then
			profs[i] = GetRaidProfileName(i);
		end
	end
	return profs;
end
local function findProfileNum(prof)
	for i=1, GetNumRaidProfiles() do
		if GetRaidProfileName(i) == prof then
			return i;
		end
	end
end

function CustomBuffs:CreateGeneralOptions()
	LoadAddOn("Blizzard_CUFProfiles");
	local profs = generateProfiles();
	if not profs[1] then
		C_Timer.After(5, function()
			profs = generateProfiles();
		end);
	end

	local THIRD_WIDTH = 1.15

	local generalOptions = {
		type = "group",
		childGroups = "tree",
		name = "Options",
		args  = {
			topSpacer = {
				type = "header",
				name = "",
				order = 3,
			},
			profileSelecter = {
			type = 'select',
			name = "Profile Selecter",
			desc = "Choose a Raid Profile to Activate",
			values = profs,
			get = function() return findProfileNum(GetCVar("activeCUFProfile")); end,
			set = function(_, value)
				local activeProf = profs[value];
				CompactUnitFrameProfiles.selectedProfile = activeProf;
				SetCVar("activeCUFProfile", activeProf);
				CompactUnitFrameProfiles_ApplyProfile(activeProf);
				CustomBuffs:loadFrames();
			end,
			width = THIRD_WIDTH * 0.75,
			order = 4,
			},
			showButton = {
				type = "execute",
				name = "Show Raid Frames",
				desc = "",
				func = function() CustomBuffs:loadFrames(); end,
				width = THIRD_WIDTH * 0.75,
				order = 5,
			},
			lockButton = {
				type = "toggle",
				name = "Lock Frame Position",
				desc = "toggle raid frame mover",
				get = function() return CustomBuffs.locked end,
				set = function(_, value)
					self:unlockFrames();
				end,
				width = THIRD_WIDTH * 0.75,
				order = 6,
			},
			testAurasButton = {
				type = "toggle",
				name = "Show test auras",
				desc = "Create fake buffs and debuffs on raid frames for testing purposes",
				get = function() return CustomBuffs.debugMode or false end,
				set = function(_, value)
					CustomBuffs:debugAuras();
				end,
				width = THIRD_WIDTH * 0.75,
				order = 7,
			},
			blizzardRaidOptionsButton = {
				type = "execute",
				name = "Open Blizzard Raid Frames Menu",
				desc = "",
				func = function() InterfaceOptionsFrame_OpenToCategory("Raid Profiles") end,
				width = THIRD_WIDTH * 1.5,
				order = 10,
			},
            spacer2 = {
                type = "header",
				name = "",
				order = 20,
            },
			useTweaks = {
				type = "toggle",
				name = "Enable UI Tweaks (requires reload on disable)",
				desc = "",
				get = function() return self.db.profile.loadTweaks end,
				set = function(_, value)
					self.db.profile.loadTweaks = value;
					self:UpdateConfig();
					if not self.db.profile.loadTweaks then
						ReloadUI();
					end
				end,
				width = THIRD_WIDTH * 2,
				order = 30,
			},
            spacer3 = {
                type = "header",
                name = "Raid Frame Name Options",
                order = 40,
            },
            cleanNames = {
				type = "toggle",
				name = "Clean Names",
				desc = "Remove server names and shorten player names on raid frames",
				get = function() return self.db.profile.cleanNames end,
				set = function(_, value)
					self.db.profile.cleanNames = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH,
				order = 50,
			},
			colorNames = {
				type = "toggle",
				name = "Highlight Group Names",
				desc = "Set the color of players in your group to be black while in a raid",
				get = function() return self.db.profile.colorNames end,
				set = function(_, value)
					self.db.profile.colorNames = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH,
				order = 52,
			},
			maxNameLength = {
				type = "range",
				name = "Max Name Length",
				desc = "Set the Maximum number of characters of a unit's name that will be displayed on its raid frame if clean names is enabled",
				min = 1,
				max = 12,
				step = 1,
				get = function() return self.db.profile.maxNameLength end,
				set = function(_, value)
					self.db.profile.maxNameLength = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH,
				order = 51
				,
			},
			spacer4 = {
                type = "header",
				name = "Raid Frame Scaling Options",
				order = 60,
            },
			frameScale = {
				type = "range",
				name = "Raidframe Scale",
				desc = "Adjust the scale of the raid frames and all of their contents",
				min = 0.5,
				max = 2,
				step = 0.1,
				get = function() return self.db.profile.frameScale end,
				set = function(_, value)
					self.db.profile.frameScale = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH,
				order = 70,
			},
			frameAlpha = {
				type = "range",
				name = "Raidframe Alpha",
				desc = "Adjust the trasparency of the raid frames and all of their contents",
				min = 0,
				max = 1,
				step = 0.1,
				get = function() return self.db.profile.frameAlpha end,
				set = function(_, value)
					self.db.profile.frameAlpha = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH,
				order = 70,
			},
			buffScale = {
				type = "range",
				name = "Buff Scale",
				desc = "Adjust the scale of the standard buffs",
				min = 0.5,
				max = 2,
				step = 0.1,
				get = function() return self.db.profile.buffScale end,
				set = function(_, value)
					self.db.profile.buffScale = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH,
				order = 72,
			},
			debuffScale = {
				type = "range",
				name = "Debuff Scale",
				desc = "Adjust the scale of the standard debuffs",
				min = 0.5,
				max = 2,
				step = 0.1,
				get = function() return self.db.profile.debuffScale end,
				set = function(_, value)
					self.db.profile.debuffScale = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH,
				order = 73,
			},
			bossDebuffScale = {
				type = "range",
				name = "Boss Debuff Scale",
				desc = "Adjust the scale of two large aura slots at the top of each frame that track important auras and CC",
				min = 0.5,
				max = 2,
				step = 0.1,
				get = function() return self.db.profile.bossDebuffScale end,
				set = function(_, value)
					self.db.profile.bossDebuffScale = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH,
				order = 74,
			},
			throughputBuffScale = {
				type = "range",
				name = "Throughput Buff Scale",
				desc = "Adjust the scale of two special aura slots in the top right of each frame that track offensive cooldowns and healer cooldowns for the unit",
				min = 0.5,
				max = 2,
				step = 0.1,
				get = function() return self.db.profile.throughputBuffScale end,
				set = function(_, value)
					self.db.profile.throughputBuffScale = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH,
				order = 75,
			},
			spacer5 = {
                type = "header",
				name = "Extra Aura Slot Options",
				order = 80,
            },
			extraDebuffs = {
				type = "toggle",
				name = "Enable Extra Party Debuffs",
				desc = "Creates 9 Extra debuff frames to the left of each of the raid frames when the group size is smaller than 6",
				get = function() return self.db.profile.extraDebuffs end,
				set = function(_, value)
					self.db.profile.extraDebuffs = value;
					if value == false then CustomBuffs:hideExtraAuraFrames("debuffs"); end
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH,
				order = 90,
			},
			extraBuffs = {
				type = "toggle",
				name = "Enable Extra Party Buffs",
				desc = "Creates 9 Extra buff frames to the right of each of the raid frames when the group size is smaller than 6",
				get = function() return self.db.profile.extraBuffs end,
				set = function(_, value)
					self.db.profile.extraBuffs = value;
					if value == false then CustomBuffs:hideExtraAuraFrames("buffs"); end
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH,
				order = 91,
			},

			spacer6 = {
                type = "header",
				name = "Other",
				order = 100,
            },
			raidMarkers = {
				type = "toggle",
				name = "Enable Raid Icons on Raid Frames",
				desc = "When enabled, raid marker icons will be shown in the center of raid frames",
				get = function() return self.db.profile.showRaidMarkers end,
				set = function(_, value)
					self.db.profile.showRaidMarkers = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH * 1.5,
				order = 110,
			},
			partyCastBars = {
				type = "toggle",
				name = "Enable Cast Bars on Raid Frames",
				desc = "When enabled, cast bars will be added to raid frames in groups of 5 or less players",
				get = function() return self.db.profile.showCastBars end,
				set = function(_, value)
					self.db.profile.showCastBars = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH * 1.5,
				order = 111,
			},
			cooldownFlash = {
				type = "toggle",
				name = "Enable Cooldown Flashes",
				desc = "Briefly shows the icon of important spells on party/raid members' frames when they cast them",
				get = function() return self.db.profile.cooldownFlash end,
				set = function(_, value)
					self.db.profile.cooldownFlash = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH * 1.5,
				order = 112,
			},
			alwaysShowFrames = {
				type = "toggle",
				name = "Always Show Frames",
				desc = "Show raid frames even when not in a group",
				get = function() return self.db.profile.alwaysShowFrames end,
				set = function(_, value)
					self.db.profile.alwaysShowFrames = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH * 1.5,
				order = 113,
			},
		}
	}

	return generalOptions
end
