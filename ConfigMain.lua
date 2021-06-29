local _, addonTable = ...
local CustomBuffs = addonTable.CustomBuffs


-------------------------------------------------------------------------
-------------------------------------------------------------------------

function CustomBuffs:CreateGeneralOptions()
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
			blizzardRaidOptionsButton = {
				type = "execute",
				name = "Open the Blizzard Raid Profiles Menu",
				desc = "",
				func = function() InterfaceOptionsFrame_OpenToCategory("Raid Profiles") end,
				width = THIRD_WIDTH * 1.5,
				order = 4,
			},
            spacer2 = {
                type = "header",
				name = "",
				order = 10,
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
				order = 20,
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
				order = 71,
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
				order = 72,
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
				order = 73,
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
				order = 74,
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
				width = THIRD_WIDTH,
				order = 112,
			},
		}
	}

	return generalOptions
end
