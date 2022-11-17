local addonName, addonTable = ...; --make use of the default addon namespace
addonTable.CustomBuffs = LibStub("AceAddon-3.0"):NewAddon("CustomBuffs", "AceTimer-3.0", "AceHook-3.0", "AceEvent-3.0", "AceBucket-3.0", "AceConsole-3.0", "AceComm-3.0");
local CustomBuffs = addonTable.CustomBuffs;

CustomBuffs.major = 2;
CustomBuffs.mid = 2;
CustomBuffs.minor = 2;
CustomBuffs.version = CustomBuffs.minor + (100 * CustomBuffs.mid) + (10000 * CustomBuffs.major);

CustomBuffs.gameVersion = 0; --Retail
if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
	CustomBuffs.gameVersion = 1; --Classic
elseif WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
	CustomBuffs.gameVersion = 2; --BC
end

_G.CustomBuffs = CustomBuffs;


CustomBuffs.GAME_VERSION = {
  "classic",
  "burning crusade",
  "wrath of the lich king"
};
CustomBuffs.GAME_VERSION[0] = "retail";

CustomBuffs.DEF_COLORS = {
  --Major damage reduction or healing increase; applies to all damage types
  {r = 1, g = 0.2, b = 0, a = 0.9}, --1
  --Strong damage reduction or healing increase; potentially only physical or magic
  {r = 1, g = 0.4, b = 0, a = 0.8}, --2
  --Medium damage reduction or healing increase
  {r = 1, g = 0.6, b = 0, a = 0.7}, --3
  --Weak damage reduction or healing increase
  {r = 1, g = 0.8, b = 0, a = 0.6}, --4
  --Rotational defensive buff (mostly tanks and healers)
  {r = 1, g = 1, b = 0, a = 0.5},  --5
  --Special coloring for magic damage only defensives
  {r = 0.4, g = 0.2, b = 0.8, a = 0.8}, --6
  --Special coloring for physical damage only defensives
  {r = 1, g = 1, b = 0, a = 0.8},  --7

};
--Immunities
CustomBuffs.DEF_COLORS[0] = {r = 1, g = 0, b = 0, a = 1};

--Set up values for dispel types; used to quickly
--determine whether a spell is dispellable by the player class
CustomBuffs.dispelValues = CustomBuffs.dispelValues or {
	["magic"] = 0x1,
	["curse"] = 0x2,
	["poison"] = 0x4,
	["disease"] = 0x8,
	["massDispel"] = 0x10,
	["purge"] = 0x20    --Tracked for things like MC
};
