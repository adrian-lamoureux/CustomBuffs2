local addonName, addonTable = ...; --make use of the default addon namespace
addonTable.CustomBuffs = LibStub("AceAddon-3.0"):NewAddon("CustomBuffs", "AceTimer-3.0", "AceHook-3.0", "AceEvent-3.0", "AceBucket-3.0", "AceConsole-3.0", "AceComm-3.0");
local CustomBuffs = addonTable.CustomBuffs;

local CDFlash = { duration = 1, tbPrio = -2, isFlash = true };
local CDStandard = {["sbPrio"] = 4, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = nil};
local EStandard = {sbPrio = 4, sdPrio = nil, bdPrio = nil, tbPrio = nil};
local ELow = {sbPrio = 5, sdPrio = nil, bdPrio = nil, tbPrio = nil};
local EPStandard = {sbPrio = 5, sdPrio = nil, bdPrio = nil, tbPrio = nil, player = true}; --Only show if source is player
local TCDStandard = {["sbPrio"] = 3, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 2};
local TCDLow      = {["sbPrio"] = 6, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 3};
local ETCDStandard          = {["sbPrio"] = 3, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 3};
local ETCDLow               = {["sbPrio"] = 3, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 4};
local ETCDNoFallthrough     = {["sbPrio"] = nil, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 4};
local ETCDPrioNoFallthrough = {["sbPrio"] = nil, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 1};
local CCStandard =      {["sbPrio"] = nil, ["sdPrio"] = 3, ["bdPrio"] = 4, ["tbPrio"] = nil};
local CCLow =           {["sbPrio"] = nil, ["sdPrio"] = 3, ["bdPrio"] = 5, ["tbPrio"] = nil};
local MagicStandard =   {["dispelType"] = "magic", ["sdPrio"] = 3, ["bdPrio"] = 4};
local CurseStandard =   {["dispelType"] = "curse", ["sdPrio"] = 3, ["bdPrio"] = 4};
local CurseLow =        {["dispelType"] = "curse", ["sdPrio"] = 3, ["bdPrio"] = 5};
local DiseaseStandard = {["dispelType"] = "disease", ["sdPrio"] = 3, ["bdPrio"] = 4};
local DiseaseLow =      {["dispelType"] = "disease", ["sdPrio"] = 3, ["bdPrio"] = 5};
local PoisonStandard =  {["dispelType"] = "poison", ["sdPrio"] = 3, ["bdPrio"] = 4};
local MDStandard =      {["dispelType"] = "massDispel", ["sdPrio"] = 3, ["bdPrio"] = 4};
local PurgeStandard =   {["dispelType"] = "purge", ["sdPrio"] = 3, ["bdPrio"] = 4};


CustomBuffs.NONAURAS = {
    --SHAMAN
    ["Mana Tide Totem"] =  { duration = 12,  tbPrio = 1, type = "summon" }, --Mana Tide
    [2894] = 					{ duration = 120, tbPrio = 1, type = "summon", chain = true, owner = 32982 }, --Fire Elemental Totem
	[32982] = 					{ duration = 120, tbPrio = 1, type = "summon"}, --Fire Elemental
	[33663] = 					{ duration = 60, tbPrio = 1, type = "summon"}, --Earth Elemental
	[2062] = 					{ duration = 120, tbPrio = 1, type = "summon", chain = true, owner = 33663 }, --Earth Elemental Totem
	--[11315] = 					{ duration = 15, tbPrio = 1, type = "summon"},
	--[25533] = 					{ duration = 60, tbPrio = 1, type = "summon"},

    --DRUID

    --MAGE
    [198149] = { duration = 10, tbPrio = 1 }, --Frozen Orb PvP Talent
    [84714] = { duration = 10, tbPrio = 1 }, --Frozen Orb

    --PRIEST

    --HUNTER

    --PALADIN
	["Blessing of Sacrifice"] =  { duration = 30,  tbPrio = 1 }, --Show when a paladin is taking damage for someone else --TODO move this to normal buff slots

    --WARRIOR

    --ROGUE

	--Cooldown Flashes
	--Show short flash on frame when a player activates an ability or item
	[1766] =  CDFlash, --Show 0.5 second flash on frame when someone uses a pvp trinket
	[1766] =  CDFlash, -- Kick (Rogue)
	[1767] =  CDFlash, -- Kick (Rogue)
	[1768] =  CDFlash, -- Kick (Rogue)
	[1769] =  CDFlash, -- Kick (Rogue)
	[38768] = CDFlash, -- Kick (Rogue)
    [2139] =  CDFlash, -- Counterspell (Mage)
    [6552] =  CDFlash, -- Pummel (Warrior)
	[6554] =  CDFlash, -- Pummel (Warrior)
	[19644] = CDFlash, -- Spell Lock (Warlock)
    [19647] = CDFlash, -- Spell Lock (Warlock)
    [8042] =  CDFlash, -- Earth Shock (Shaman)
	[8044] =  CDFlash, -- Earth Shock (Shaman)
	[8045] =  CDFlash, -- Earth Shock (Shaman)
	[8046] =  CDFlash, -- Earth Shock (Shaman)
	[10412] = CDFlash, -- Earth Shock (Shaman)
	[10413] = CDFlash, -- Earth Shock (Shaman)
	[10414] = CDFlash, -- Earth Shock (Shaman)
	[25454] = CDFlash, -- Earth Shock (Shaman)
    [16979] = CDFlash, -- Feral Charge (Feral)

	--SHAMAN
	[8177] = 	CDFlash, --Grounding Totem
	[16188] = 	CDFlash, --Nature's Swiftness
	[8012] = 	CDFlash, --Purge
	[526] = 	CDFlash, --Dispel
	[2870] = 	CDFlash, --Dispel

	--LOCK

	--DRUID
	[6795] =	CDFlash, --Growl
	[9000] =	CDFlash, --Cower
	[768] =		CDFlash, --Cat Form
	[783] =		CDFlash, --Travel Form
	[9634] =	CDFlash, --Dire Bear Form
	[1066] =	CDFlash, --Aquatic Form
	[5209] =	CDFlash, --Challenging Roar
	[8983] =	CDFlash, --Bash
	[17401] =	CDFlash, --Hurricane
	[9862] =	CDFlash, --Tranquility
	[17116] =	CDFlash, --NS
	[18562] =	CDFlash, --Swiftmend




	--MAGE

	--PRIEST

	--HUNTER

	--PALADIN

	--WARRIOR

	--ROGUE

	--Items
	[42292] = { duration = 1, tbPrio = -2, isFlash = true, iconID = 30345 }, 	--PvP trinket
	[28499] = { duration = 1, tbPrio = -2, isFlash = true, iconID = 22832 },	--Super Mana Potion
	[28495] = { duration = 1, tbPrio = -2, isFlash = true, iconID = 22829 }, 	--Health Potion
	[27237] = { duration = 1, tbPrio = -2, isFlash = true }, 					--Healthstone

	--other
	[16589] = { duration = 1, tbPrio = -2, isFlash = true, iconID = 8529 }, 	--Noggenfogger
};

CustomBuffs.INTERRUPTS = {
    [1766] =   { duration = 5 }, -- Kick (Rogue)
	[1767] =   { duration = 5 }, -- Kick (Rogue)
	[1768] =   { duration = 5 }, -- Kick (Rogue)
	[1769] =   { duration = 5 }, -- Kick (Rogue)
	[38768] =   { duration = 5 }, -- Kick (Rogue)
    [2139] =   { duration = 8 }, -- Counterspell (Mage)
    [6552] =   { duration = 4 }, -- Pummel (Warrior)
	[6554] =   { duration = 4 }, -- Pummel (Warrior)
	[19644] =  { duration = 6 }, -- Spell Lock (Warlock)
    [19647] =  { duration = 6 }, -- Spell Lock (Warlock)
    [8042] =  { duration = 2 }, -- Earth Shock (Shaman)
	[8044] =  { duration = 2 }, -- Earth Shock (Shaman)
	[8045] =  { duration = 2 }, -- Earth Shock (Shaman)
	[8046] =  { duration = 2 }, -- Earth Shock (Shaman)
	[10412] =  { duration = 2 }, -- Earth Shock (Shaman)
	[10413] =  { duration = 2 }, -- Earth Shock (Shaman)
	[10414] =  { duration = 2 }, -- Earth Shock (Shaman)
	[25454] =  { duration = 2 }, -- Earth Shock (Shaman)
    [16979] = { duration = 4 }, -- Feral Charge (Feral)

	--Non Player
	[13281] = { duration = 2 },
	[13728] = { duration = 2 },
	[15122] = { duration = 15},
	[2676] =  { duration = 2 },
	[32691] = { duration = 6 },
	[32846] = { duration = 4 },
	[11972] = { duration = 8 },
	[29560] = { duration = 2 },
	[29961] = { duration = 10},
	[19675] = { duration = 4 },
	[13281] = { duration = 2 },
	[33871] = { duration = 8 },

};

CustomBuffs.BUFFS = {
		--Druid
        ["Barkskin"] =                  CDStandard,
		["Enrage"] =                  	CDStandard,
        ["Frenzied Regeneration"] =     CDStandard,
		["Dash"] = 						CDStandard,
		["Prowl"] = 					CDStandard,

		--Hunter
        ["Deterrence"] =      			CDStandard,

		--Mage
        ["Ice Block"] =                 CDStandard,
		["Mana Shield"] =               CDStandard,
		["Ice Barrier"] =               CDStandard,


		--Paladin
        ["Divine Shield"] =             CDStandard,
        ["Divine Protection"] =         CDStandard,
        ["Ardent Defender"] =           CDStandard,
        ["Aegis of Light"] =            CDStandard,
        ["Eye for an Eye"] =            CDStandard,
        ["Shield of Vengeance"] =       CDStandard,
        ["Guardian of Ancient Kings"] = CDStandard,
        ["Guardian of the fortress"] =  CDStandard,
        ["Shield of the Righteous"] =   CDStandard,

		--Priest
        ["Dispersion"] =                CDStandard,
        ["Fade"] =                      CDStandard,
        ["Greater Fade"] =              CDStandard,

		--Rogue
        ["Evasion"] =                   CDStandard,
        ["Cloak of Shadows"] =          CDStandard,
        ["Feint"] =                     CDStandard,
        ["Readiness"] =                 CDStandard,
        ["Riposte"] =                   CDStandard,
        ["Crimson Vial"] =              CDStandard,
		["Stealth"] =              		CDStandard,
		["Vanish"] =              		CDStandard,

		--Shaman
        ["Astral Shift"] =              CDStandard,
		["Water Shield"] =              CDStandard,
        ["Shamanistic Rage"] =          CDStandard,
        ["Harden Skin"] =               CDStandard,

		--Warlock
        ["Unending Resolve"] =          CDStandard,
        ["Dark Pact"] =                 CDStandard,
        ["Nether Ward"] =               CDStandard,

		--Warrior
        ["Shield Wall"] =               CDStandard,
        ["Spell Reflection"] =          CDStandard,
        ["Shield Block"] =              CDStandard,
        ["Last Stand"] =                CDStandard,
        ["Die By The Sword"] =          CDStandard,
        ["Defensive Stance"] =          CDStandard,

		--Major Externals
	    ["Ironbark"] =                  EStandard,
	    ["Life Cocoon"] =               EStandard,
	    ["Blessing of Protection"] =    EStandard,
	    ["Blessing of Sacrifice"] =     EStandard,
	    ["Blessing of Spellwarding"] =  EStandard,
	    ["Pain Suppression"] =          EStandard,
	    ["Guardian Spirit"] =           EStandard,
	    ["Roar of Sacrifice"] =         EStandard,
	    ["Innervate"] =                 EStandard,
	    ["Cenarion Ward"] =             EStandard,
	    ["Safeguard"] =                 EStandard,
	    ["Vigilance"] =                 EStandard,
	    ["Earth Shield"] =              EStandard,
	    ["Tiger's Lust"] =              EStandard,
	    ["Beacon of Virtue"] =          EStandard,
	    ["Beacon of Faith"] =           EStandard,
	    ["Beacon of Light"] =           EStandard,
	    ["Lifebloom"] =                 EStandard,
	    ["Spirit Mend"] =               EStandard,
	    ["Misdirection"] =              EStandard,
	    ["Tricks of the Trade"] =       EStandard,
	    ["Rallying Cry"] =              EStandard,
	    ["Anti-Magic Zone"] =           EStandard,
		["Power Word: Shield"] = 		EStandard,

	    ["Stoneform"] =                 EStandard,
	    ["Fireblood"] =                 EStandard,


	    --Minor Externals worth tracking
	    ["Enveloping Mist"] =           ELow,


	    --Show party/raid member's stealth status in buffs
	    ["Vanish"] =                    EStandard,

		["Cultivation"] =               EPStandard,
	    ["Spring Blossoms"] =           EPStandard,
	    [290754] =                      EPStandard, --Lifebloom from early spring honor talent
	    ["Glimmer of Light"] =          EPStandard,
	    ["Ancestral Vigor"] =           EPStandard,
	    ["Anti-Magic Zone"] =           EPStandard,
	    ["Blessing of Sacrifice"] =     EPStandard,

		["Healing Way"] =     			EPStandard,
		["Ancestral Fortitude"] =     	EStandard,
		["Inspiration"] =     			EStandard,

	    ["Gladiator's Emblem"] =        EStandard,

		["Food"] =              		EStandard,
	    ["Drink"] =           			EStandard,

};

CustomBuffs.THROUGHPUT_BUFFS = {
		--Druid
        ["Incarnation: Tree of Life"] =         TCDStandard,
        ["Incarnation: King of the Jungle"] =   TCDStandard,
        ["Berserk"] =                           TCDStandard,
        ["Incarnation: Guardian of Ursoc"] =    TCDStandard,
        ["Incarnation: Chosen of Elune"] =      TCDStandard,
        ["Celestial Alignment"] =               TCDStandard,
        ["Essence of G'Hanir"] =                TCDStandard,
        ["Tiger's Fury"] =                      TCDStandard,
        ["Heart of the Wild"] =                 TCDStandard,
        ["Flourish"] =                          TCDStandard,

		--Hunter
        ["Aspect of the Wild"] =                TCDStandard,
        ["Aspect of the Eagle"] =               TCDStandard,
        ["Bestial Wrath"] =                     TCDStandard,
        ["Trueshot"] =                          TCDStandard,
        ["Volley"] =                            TCDStandard,

		--Mage
        ["Icy Veins"] =                         TCDStandard,
        ["Combustion"] =                        TCDStandard,
        ["Arcane Power"] =                      TCDStandard,

		--Paladin
        ["Avenging Wrath"] =                    TCDStandard,
        ["Avenging Crusader"] =                 TCDStandard,
        ["Holy Avenger"] =                      TCDStandard,
        ["Crusade"] =                           TCDStandard,
        ["Seraphim"] =                          TCDStandard,
        --Testing displaying their active aura here; maybe move
        --["Concentration Aura"] =                TCDLow,
        --["Retribution Aura"] =                  TCDLow,
        --["Crusader Aura"] =                     TCDLow,
        --["Devotion Aura"] =                     TCDLow

		--Priest
        ["Archangel"] =                         TCDStandard,
        ["Dark Archangel"] =                    TCDStandard,
        ["Rapture"] =                           TCDStandard,
        ["Apotheosis"] =                        TCDStandard,
        --["Divinity"] = true,
        ["Voidform"] =                          TCDStandard,
        ["Surrender to Madness"] =              TCDStandard,
        [109964] =                              TCDStandard, --Spirit Shell
        ["Shadow Covenant"] =                   TCDStandard,

		--Rogue
        ["Shadow Blades"] =                     TCDStandard,
        ["Shadow Dance"] =                      TCDStandard,
        ["Shadowy Duel"] =                      TCDStandard,
        ["Adrenaline Rush"] =                   TCDStandard,
        ["Blade Flurry"] =                      TCDStandard,
        ["Killing Spree"] =                     TCDStandard,

		--Shaman
        ["Ascendance"] =                        TCDStandard,
        ["Ancestral Guidance"] =                TCDStandard,
        ["Stormkeeper"] =                       TCDStandard,
        ["Icefury"] =                           TCDStandard,
        ["Doom Winds"] =                        TCDStandard,

		--Lock
        ["Soul Harvest"] =                      TCDStandard,
        ["Dark Soul: Instability"] =            TCDStandard,
        ["Dark Soul: Misery"] =                 TCDStandard,
        ["Nether Portal"] =                     TCDStandard,

		--Warrior
        ["Battle Cry"] =                        TCDStandard,
        ["Avatar"] =                            TCDStandard,
        ["Bladestorm"] =                        TCDStandard,
        ["Bloodbath"] =                         TCDStandard,

		--Externals
		["Dark Archangel"] =                	ETCDStandard,
	    ["Power Infusion"] =                	ETCDStandard,
	    ["Blood Fury"] =                    	ETCDStandard,
	    ["Berserking"] =                    	ETCDStandard,
	    ["Skyfury Totem"] =                 	ETCDStandard,
		--since these are party specific we show them in bc to see which groups are lusted in raid
		["Bloodlust"] =                 		ETCDStandard,
		["Drums of Battle"] =              		ETCDStandard,

		--Trinkets
		["Haste"] =								ETCDLow,
		["Spell Haste"] =						ETCDLow,
		[35165] =								ETCDLow,

};

CustomBuffs.CC = {

    --------------------
    --   Dispelable   --
    --------------------

    ["Polymorph"] =             MagicStandard,
    ["Freezing Trap"] =         MagicStandard,
    ["Fear"] =                  MagicStandard,
    ["Howl of Terror"] =        MagicStandard,
    ["Death Coil"] =           	MagicStandard,
    ["Psychic Scream"] =        MagicStandard,
    ["Psychic Horror"] =        MagicStandard,
    ["Seduction"] =             MagicStandard,
	["Scare Beast"] =           MagicStandard,
	["Hibernate"] =             MagicStandard,
    ["Hammer of Justice"] =     MagicStandard,
    ["Silence"] =               MagicStandard,
	["Silencing Shot"] =        MagicStandard,
	[18469] =                   MagicStandard, --Mage Blanket
	[24259] =                   MagicStandard, --Lock Blanket
	[18425] =          			MagicStandard, --Improved Kick
    [31117] =                   MagicStandard, --UA Silence
    --["Sin and Punishment"] =    MagicStandard, --VT dispel fear
    --[117526] =                  MagicStandard, --Binding Shot CC
    ["Arcane Torrent"] = 		MagicStandard,
    ["Repentance"] =            MagicStandard,
    ["Dragon's Breath"] =       MagicStandard,
    ["Shadowfury"] =            MagicStandard,
	[22703] =                   MagicStandard, --Infernal Stun


    --Roots
    ["Frost Nova"] =            MagicStandard,
    ["Entangling Roots"] =      MagicStandard,
	["Nature's Grasp"] =      	MagicStandard,
	["Entangling Roots"] =      MagicStandard,
    ["Freeze"] =                MagicStandard,
	[12494] =      				MagicStandard, --Frostbite


    --poison/curse/disease/MD dispellable
    ["Mind Control"] =          PurgeStandard,
    --["Wyvern Sting"] =          PoisonStandard,
    ["Viper Sting"] =          	PoisonStandard,
    --[233022] = true, --Spider Sting Silence
    ["Cyclone"] =               MDStandard,

    --Warlock Curses
    ["Curse of Exhaustion"] =   CurseLow,
    ["Curse of Tongues"] =      CurseLow,
    ["Curse of Weakness"] =     CurseLow,

    --------------------
    -- Not Dispelable --
    --------------------

	["Counterattack"] =      	CCStandard,
	[12809] =                   CCStandard, --Concussion Blow
	[7922] =                    CCStandard, --Charge Stun
	[16922] =                 	CCStandard, --Starfire Stun
	[19410] =                 	CCStandard, --Improved Concussive Shot
	[12355] =                 	CCStandard, --Impact
	[20170] =                 	CCStandard, --Seal of Justice
	[15269] =                 	CCStandard, --Blackout
	[18093] =                 	CCStandard, --Pyroclasm
	[12798] =                 	CCStandard, --Revenge Stun
	[5530] =                 	CCStandard, --Mace Spec Stun
	[15283] =                 	CCStandard, --Stunning Blow
	[56] =                 		CCStandard, --Stun Proc
    ["Blind"] =                 CCStandard,
    ["Disarm"] =                CCStandard,
    ["War Stomp"] =             CCStandard,
    ["Intimidation"] =          CCStandard,
    ["Kidney Shot"] =           CCStandard,
	["Pounce"] =           		CCStandard,
    ["Maim"] =                  CCStandard,
    ["Intercept Stun"] =        CCStandard,
    ["Bash"] =           		CCStandard,
    ["Sap"] =                   CCStandard,
    ["Storm Bolt"] =            CCStandard,
    ["Cheap Shot"] =            CCStandard,
    ["Intimidating Shout"] =    CCStandard,
    ["Scatter Shot"] =          CCStandard,
	["Gouge"] =          		CCStandard,
	["Garrote - Silence"] =     CCStandard,
	["Feral Charge Effect"] =   CCStandard,



};


--List of Buffs that will not shown on frames
CustomBuffs.BuffBlacklist = {
	["Healing Stream"] = true,
	["Fire Resistance"] = true,
	["Frost Resistance"] = true,
	["Grace of Air"] = true,
	["Nature Resistance"] = true,
	["Stoneskin"] = true,
	["Strength of Earth"] = true,
	["Windwall"] = true,
	["Wrath of Air Totem"] = true,
	["Mana Spring"] = true,
	["Tranquil Air"] = true,
};

CustomBuffs.testBuffs = {
		[974] = 	{ duration = 600, sbPrio = 2, stacks = 6 }, 	--Earth Shield
		[774] = 	{ duration = 15, sbPrio = 2 }, 		--Rejuv
		[8936] = 	{ duration = 12, sbPrio = 2 }, 		--Regrowth
		[22812] = 	{ duration = 12, sbPrio = 1 }, 		--Barkskin
		[22842] = 	{ duration = 10, sbPrio = 1 }, 		--Frenzied Regen
		[33763] = 	{ duration = 7, sbPrio = 2, stacks = 3 }, 		--Lifebloom
		[25218] = 	{ duration = 15, sbPrio = 2}, 		--Power Word: Shield
};
CustomBuffs.testDebuffs = {
		[33745] = 	{ duration = 15, sdPrio = 2, stacks = 5 }, 					--Lacerate
		[26988] = 	{ duration = 12, sdPrio = 1, dispelType = "Magic"}, 		--Moonfire
		[25457] = 	{ duration = 12, sdPrio = 1, dispelType = "Magic"}, 		--Flame Shock
		[589] = 	{ duration = 16, sdPrio = 2, dispelType = "Magic"}, 		--Shadow Word: Pain
		[14914] = 	{ duration = 10, sdPrio = 2, dispelType = "Magic"}, 		--Holy Fire
		[27218] = 	{ duration = 24, sdPrio = 1, dispelType = "Curse"}, 		--Agony
		[30405] = 	{ duration = 18, sdPrio = 1, dispelType = "Magic"}, 		--UA
		[27216] = 	{ duration = 18, sdPrio = 1, dispelType = "Magic"}, 		--Corruption
		[30911] = 	{ duration = 30, sdPrio = 1, dispelType = "Magic"}, 		--Siphon Life
};

CustomBuffs.testThroughputBuffs = {
		[35165] = 	{ duration = 15, tbPrio = 3 }, 		--Trinket Proc
		[345228] = 	{ duration = 15, tbPrio = 3 }, 		--PvP Badge
		[33697] = 	{ duration = 15, tbPrio = 2 }, 		--Bloodfury
};

CustomBuffs.testBossDebuffs = {
		[8643] = 	{ duration = 6, bdPrio = 1}, 								--Kidney Shot
		[12826] = 	{ duration = 12, bdPrio = 2, dispelType = "Magic"}, 			--Poly
};
