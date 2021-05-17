--Known bugs:
--issue with taint on show() causing invalid combat show errors sometimes; unsure of cause
--issue with raid frames sometimes losing click interaction functionality maybe because of this addon

local addonName, addonTable = ...; --make use of the default addon namespace
addonTable.CustomBuffs = LibStub("AceAddon-3.0"):NewAddon("CustomBuffs", "AceTimer-3.0", "AceHook-3.0", "AceEvent-3.0", "AceBucket-3.0", "AceConsole-3.0");
local CustomBuffs = addonTable.CustomBuffs;
_G.CustomBuffs = CustomBuffs
    --[[
        CustomBuffsFrame        :   Frame

        playerClass             :   String

        canMassDispel           :   boolean
        canDispelMagic          :   boolean
        canDispelCurse          :   boolean
        canDispelPoison         :   boolean
        canDispelDisease        :   boolean
        dispelType              :   number
        dispelValues            :   Table

        layoutNeedsUpdate       :   boolean

        units                   :   Table

        lookupIDByName          :   Table ??

        MAX_DEBUFFS             :   number
        BUFF_SCALE_FACTOR       :   number
        BIG_BUFF_SCALE_FACTOR   :   number

        INTERRUPTS              :   Table
        CDS                     :   Table
        EXTERNALS               :   Table
        EXTRA_RAID_BUFFS        :   Table
        THROUGHPUT_CDS          :   Table
        EXTERNAL_THROUGHPUT_CDS :   Table
        BOSS_BUFFS              :   Table
        CC                      :   Table

        inRaidGroup             :   boolean
    --]]


--Create a frame so that we can listen for and handle events
CustomBuffs.CustomBuffsFrame = CustomBuffs.CustomBuffsFrame or CreateFrame("Frame","CustomBuffsFrame");

--Create units table
CustomBuffs.units = CustomBuffs.units or {};

--Set up values for dispel types; used to quickly
--determine whether a spell is dispellable by the player class;
--used to increase the debuff priority of dispellable debuffs
CustomBuffs.dispelValues = CustomBuffs.dispelValues or {
    ["magic"] = 0x1,
    ["curse"] = 0x2,
    ["poison"] = 0x4,
    ["disease"] = 0x8,
    ["massDispel"] = 0x10,
    ["purge"] = 0x20    --Tracked for things like MC
};

--Set Max Debuffs
CustomBuffs.MAX_DEBUFFS = CustomBuffs.MAX_DEBUFFS or 6;
CustomBuffs.MAX_BUFFS = CustomBuffs.MAX_BUFFS or 6;

--Set Buff Scale Factor
CustomBuffs.BUFF_SCALE_FACTOR = CustomBuffs.BUFF_SCALE_FACTOR or 10;

CustomBuffs.UPDATE_DELAY_TOLERANCE = CustomBuffs.UPDATE_DELAY_TOLERANCE or 0.01;
--CustomBuffs.inRaidGroup = false;

CustomBuffs.debugMode = CustomBuffs.debugMode or false;


--[[
local needsUpdateVisible = {};
--local oldUpdateVisible = CompactUnitFrame_UpdateVisible;
CompactUnitFrame_UpdateVisible = function(frame)
    if frame:IsForbidden() then
        needsUpdateVisible[frame] = true;
        return;
    end
	if ( UnitExists(frame.unit) or UnitExists(frame.displayedUnit) ) then
		if ( not frame.unitExists ) then
			frame.newUnit = true;
		end
		frame.unitExists = true;
		frame:Show();
	else
		CompactUnitFrame_ClearWidgetSet(frame);
		frame:Hide();
		frame.unitExists = false;
	end
end
--]]

--Create locals for speed

local tinsert = tinsert;
local tsort = table.sort;
local twipe = table.wipe;

local setMaxDebuffs = CompactUnitFrame_SetMaxDebuffs;
local setMaxBuffs = CompactUnitFrame_SetMaxBuffs;
local isPrioDebuff = CompactUnitFrame_Util_IsPriorityDebuff;
local shouldDisplayDebuff = CompactUnitFrame_Util_ShouldDisplayDebuff;
local shouldDisplayBuff = CompactUnitFrame_UtilShouldDisplayBuff;
local setCooldownFrame = CooldownFrame_Set;
local clearCooldownFrame = CooldownFrame_Clear;

local UnitGUID = UnitGUID;
local CompactUnitFrame_UpdateAuras = CompactUnitFrame_UpdateAuras;

local dbSize = 1;
local bSize = 1;
local tbSize = 1.2;
local bdSize = 1.5;

local NameCache = {};

local function ForceUpdateFrame(fNum)
    --local name = GetUnitName(_G["CompactRaidFrame"..fNum].unit, false);
    --print("Forcing frame update for frame "..fNum.." for unit "..name);
    CustomBuffs:UpdateAuras(_G["CompactRaidFrame"..fNum]);
end


----------------------
----    Tables    ----
----------------------

--Each table is responsible for tracking a different type of aura.  Every table of auras maps
--a different pool of buffs/debuffs to a specific priority level and display location.  Smaller
--priority level values correspond to higher priority.

--[[
Priority level for standard buff frames:
    1) Blizzard specified boss buffs that fall through
    2) Custom boss buffs from BOSS_BUFFS that fall through
    3) Throughput CDs from THROUGHPUT_CDS that fall through
    3) External throughput CDs from EXTERNAL_THROUGHPUT_CDS that fall through
    4) Personal CDs from CDS
    4) External CDs from EXTERNALS
    5) Any other tracked buffs from EXTRA_RAID_BUFFS
    6) Pad out remaining buff frames with any remaining buffs flagged for display by Blizzard

Priority level for standard debuff frames:
    1) Blizzard specified boss debuffs that fall through
    2) Dispellable CC debuffs from CC that fall through
    3) Undispellable CC debuffs from CC that fall through
    4) Blizzard flagged priority debuffs (Forbearance)
    5) Pad out remaining debuff frames with any remaining debuffs flagged for display by Blizzard

Priority level for boss debuff frames:
    1) Active interrupts
    2) Blizzard specified boss debuffs
    2) Blizzard specified boss buffs
    3) Dispellable CC debuffs from CC
    4) Undispellable CC debuffs from CC
    5) Custom boss buffs from BOSS_BUFFS
    UNUSED BOSS DEBUFF FRAMES ARE HIDDEN, NOT PADDED OUT

Priority level for throughput frames:
    1) High priority flagged throughput CDs from THROUGHPUT_CDS or EXTERNAL_THROUGHPUT_CDS
    2) Non flagged Throughput CDs from THROUGHPUT_CDS
    3) Non flagged external throughput CDs from EXTERNAL_THROUGHPUT_CDS
    UNUSED THROUGHPUT FRAMES ARE HIDDEN, NOT PADDED OUT

--]]

--Table of interrupts and their durations from BigDebuffs
CustomBuffs.INTERRUPTS = {
    [1766] =   { duration = 5 }, -- Kick (Rogue)
    [2139] =   { duration = 6 }, -- Counterspell (Mage)
    [6552] =   { duration = 4 }, -- Pummel (Warrior)
    [19647] =  { duration = 6 }, -- Spell Lock (Warlock)
    [47528] =  { duration = 3 }, -- Mind Freeze (Death Knight)
    [57994] =  { duration = 3 }, -- Wind Shear (Shaman)
    [91802] =  { duration = 2 }, -- Shambling Rush (Death Knight)
    [96231] =  { duration = 4 }, -- Rebuke (Paladin)
    [106839] = { duration = 4 }, -- Skull Bash (Feral)
    [115781] = { duration = 6 }, -- Optical Blast (Warlock)
    [116705] = { duration = 4 }, -- Spear Hand Strike (Monk)
    [132409] = { duration = 6 }, -- Spell Lock (Warlock)
    [147362] = { duration = 3 }, -- Countershot (Hunter)
    [171138] = { duration = 6 }, -- Shadow Lock (Warlock)
    [183752] = { duration = 3 }, -- Consume Magic (Demon Hunter)
    [187707] = { duration = 3 }, -- Muzzle (Hunter)
    [212619] = { duration = 6 }, -- Call Felhunter (Warlock)
    [231665] = { duration = 3 }, -- Avengers Shield (Paladin)
    ["Solar Beam"] = { duration = 5 },

    --Non player interrupts BETA FEATURE
    ["Quake"]               = { duration = 5 }, --240448
    ["Deafening Crash"]     = { duration = 2 },
};

CustomBuffs.NONAURAS = {
    --SHAMAN
    [108280] = { duration = 12, tbPrio = 1 }, --Healing Tide (Assumes leveling perk for +2 seconds)
    [16191] =  { duration = 8,  tbPrio = 1 }, --Mana Tide
    [198067] = { duration = 30, tbPrio = 1 }, --Fire Elemental
    [192249] = { duration = 30, tbPrio = 1 }, --Storm Elemental
    [51533] =  { duration = 15, tbPrio = 1 }, --Feral Spirit

    --LOCK
    [205180] = { duration = 20, tbPrio = 1 }, --Summon Darkglare
    [111898] = { duration = 17, tbPrio = 1 }, --Grimoire: Felguard
    [265187] = { duration = 15, tbPrio = 1 }, --Summon Demonic Tyrant
    [1122] = { duration = 30, tbPrio = 1 }, --Summon Infernal

    --DRUID
    --[157982] = { duration = 1.5, tbPrio = 1 }, --Tranquility

    --MAGE
    [198149] = { duration = 10, tbPrio = 1 }, --Frozen Orb PvP Talent
    [84714] = { duration = 10, tbPrio = 1 }, --Frozen Orb

    --PRIEST

    --HUNTER
    [131894] = { duration = 15, tbPrio = 1 }, --Murder of Crows
    [201430] = { duration = 12, tbPrio = 1 }, --Stampede

    --DK
    [63560] = { duration = 15, tbPrio = 1 }, --Dark Transformation
    [42650] = { duration = 30, tbPrio = 1 }, --Army of the Dead

    --MONK
    [325197] = { duration = 25, tbPrio = 1 }, --Invoke Chi-ji
    [322118] = { duration = 25, tbPrio = 1 }, --Yu'lon
    [123904] = { duration = 24, tbPrio = 1 }, --Xuen
    [132578] = { duration = 25, tbPrio = 1 }, --Niuzao

    --DH

    --PALADIN

    --WARRIOR

    --ROGUE

};


--CDs show self-applied class-specific buffs in the standard buff location
    --Display Location:     standard buff
    --Aura Sources:         displayed unit
    --Aura Type:            buff
    --Standard Priority Level:
local CDStandard = {["sbPrio"] = 4, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = nil};
        CustomBuffs.CDS = {
            [ 6 ] = { --Death Knight
                ["Icebound Fortitude"] =        CDStandard,
                ["Anti-Magic Shell"] =          CDStandard,
                ["Vampiric Blood"] =            CDStandard,
                ["Corpse Shield"] =             CDStandard,
                ["Bone Shield"] =               CDStandard,
                ["Dancing Rune Weapon"] =       CDStandard,
                ["Hemostasis"] =                CDStandard,
                ["Rune Tap"] =                  CDStandard,
                ["Lichborne"] =                 CDStandard,
                ["Swarming Mist"] =             CDStandard
            } ,
            [ 11 ] = { --Druid
                ["Survival Instincts"] =        CDStandard,
                ["Barkskin"] =                  CDStandard,
                ["Ironfur"] =                   CDStandard,
                ["Frenzied Regeneration"] =     CDStandard
            } ,
            [ 3 ] = { --Hunter
                ["Aspect of the Turtle"] =      CDStandard,
                ["Survival of the Fittest"] =   CDStandard
            } ,
            [ 8 ] = { --Mage
                ["Ice Block"] =                 CDStandard,
                ["Evanesce"] =                  CDStandard,
                ["Greater Invisibility"] =      CDStandard,
                ["Alter Time"] =                CDStandard,
                ["Temporal Shield"] =           CDStandard
            } ,
            [ 10 ] = { --Monk
                ["Zen Meditation"] =            CDStandard,
                ["Diffuse Magic"] =             CDStandard,
                ["Dampen Harm"] =               CDStandard,
                ["Touch of Karma"] =            CDStandard,
                ["Fortifying Brew"] =           CDStandard
            } ,
            [ 2 ] = { --Paladin
                ["Divine Shield"] =             CDStandard,
                ["Divine Protection"] =         CDStandard,
                ["Ardent Defender"] =           CDStandard,
                ["Aegis of Light"] =            CDStandard,
                ["Eye for an Eye"] =            CDStandard,
                ["Shield of Vengeance"] =       CDStandard,
                ["Guardian of Ancient Kings"] = CDStandard,
                --["Seraphim"] =                  CDStandard, moved to throughput cds
                ["Guardian of the fortress"] =  CDStandard,
                ["Shield of the Righteous"] =   CDStandard
            } ,
            [ 5 ] = { --Priest
                ["Dispersion"] =                CDStandard,
                ["Fade"] =                      CDStandard,
                ["Greater Fade"] =              CDStandard
            } ,
            [ 4 ] = { --Rogue
                ["Evasion"] =                   CDStandard,
                ["Cloak of Shadows"] =          CDStandard,
                ["Feint"] =                     CDStandard,
                ["Readiness"] =                 CDStandard,
                ["Riposte"] =                   CDStandard,
                ["Crimson Vial"] =              CDStandard
            } ,
            [ 7 ] = { --Shaman
                ["Astral Shift"] =              CDStandard,
                ["Shamanistic Rage"] =          CDStandard,
                ["Harden Skin"] =               CDStandard
            } ,
            [ 9 ] = { --Warlock
                ["Unending Resolve"] =          CDStandard,
                ["Dark Pact"] =                 CDStandard,
                ["Nether Ward"] =               CDStandard
            } ,
            [ 1 ] = { --Warrior
                ["Shield Wall"] =               CDStandard,
                ["Spell Reflection"] =          CDStandard,
                ["Shield Block"] =              CDStandard,
                ["Last Stand"] =                CDStandard,
                ["Die By The Sword"] =          CDStandard,
                ["Defensive Stance"] =          CDStandard
            },
            [ 12 ] = { --Demon Hunter
                ["Netherwalk"] =                CDStandard,
                ["Blur"] =                      CDStandard,
                ["Darkness"] =                  CDStandard,
                ["Demon Spikes"] =              CDStandard,
                ["Soul Fragments"] =            CDStandard
            }
        };
--Externals show important buffs applied by units other than the player in the standard buff location
    --Display Location:     standard buff
    --Aura Sources:         non player (formerly to prevent duplicates for player casted versions)
    --Aura Type:            buff
    --Standard Priority Level:
local EStandard = {["sbPrio"] = 4, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = nil};
local ELow = {["sbPrio"] = 5, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = nil};
CustomBuffs.EXTERNALS = {
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

    ["Stoneform"] =                 EStandard,
    ["Fireblood"] =                 EStandard,


    [344388] =                      EStandard, --Huntsman trinket
    [344384] =                      EStandard, --Huntsman trinket target
    ["Tuft of Smoldering Plumage"]= Estandard,

    ["Fleshcraft"] =                EStandard,

    ["Gladiator's Emblem"] =        EStandard,

    --Minor Externals worth tracking
    ["Enveloping Mist"] =           ELow,


    --Show party/raid member's stealth status in buffs
    ["Stealth"] =                   EStandard,
    ["Vanish"] =                    EStandard,
    ["Prowl"] =                     EStandard,

    --Previous expansion effects
    --["Vampiric Aura"] =             EStandard

};

--Extra raid buffs show untracked buffs from the player on anyone in the standard buff location
    --Display Location:     standard buff
    --Aura Sources:         player
    --Aura Type:            buff
    --Standard Priority Level:
local ERBStandard = {["sbPrio"] = 5, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = nil};
CustomBuffs.EXTRA_RAID_BUFFS = {
    ["Cultivation"] =               ERBStandard,
    ["Spring Blossoms"] =           ERBStandard,
    [290754] =                      ERBStandard, --Lifebloom from early spring honor talent
    ["Glimmer of Light"] =          ERBStandard,
    ["Ancestral Vigor"] =           ERBStandard,
    ["Anti-Magic Zone"] =           ERBStandard,
    ["Blessing of Sacrifice"] =     ERBStandard,

    --BFA procs
    ["Luminous Jellyweed"] =        ERBStandard,
    ["Costal Surge"] =              ERBStandard,
    ["Concentrated Mending"] =      ERBStandard,
    ["Touch of the Voodoo"] =       ERBStandard,
    ["Egg on Your Face"] =          ERBStandard,
    ["Coastal Surge"] =             ERBStandard,
    ["Quickening"] =                ERBStandard,
    ["Ancient Flame"] =             ERBStandard,
    ["Grove Tending"] =             ERBStandard,
    ["Blessed Portents"] =          ERBStandard,

    [344227] =                      ERBStandard, --Consumptive Infusion

    ["Fleshcraft"] =                ERBStandard,

    ["Stoneform"] =                 ERBStandard,
    ["Fireblood"] =                 ERBStandard,

    ["Gladiator's Emblem"] =        ERBStandard,

    [344388] =                      ERBStandard, --Huntsman trinket
    [344384] =                      ERBStandard, --Huntsman trinket target
    ["Tuft of Smoldering Plumage"]= ERBStandard,
};


--Throughput CDs show important CDs cast by the unit in a special set of throughput buff frames
    --Display Location:     throughtput frames
    --Aura Sources:         displayed unit
    --Aura Type:            buff
    --Standard Priority Level:
local TCDStandard = {["sbPrio"] = 3, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 2};
local TCDLow      = {["sbPrio"] = 6, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 3};
CustomBuffs.THROUGHPUT_CDS = {
    [ 6 ] = { -- dk
        ["Pillar of Frost"] =                   TCDStandard,
        ["Unholy Frenzy"] =                     TCDStandard,
        ["Empower Rune Weapon"] =               TCDStandard
    } ,
    [ 11 ] = { --druid
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

    } ,
    [ 3 ] = { -- hunter
        ["Aspect of the Wild"] =                TCDStandard,
        ["Aspect of the Eagle"] =               TCDStandard,
        ["Bestial Wrath"] =                     TCDStandard,
        ["Trueshot"] =                          TCDStandard,
        ["Volley"] =                            TCDStandard
    } ,
    [ 8 ] = { --mage
        ["Icy Veins"] =                         TCDStandard,
        ["Combustion"] =                        TCDStandard,
        ["Arcane Power"] =                      TCDStandard,
        ["Rune of Power"] =                     TCDStandard

    } ,
    [ 10 ] = { --monk
        ["Way of the Crane"] =                  TCDStandard,
        ["Storm, Earth, and Fire"] =            TCDStandard,
        ["Serenity"] =                          TCDStandard,
        ["Thunder Focus Tea"] =                 TCDStandard
    } ,
    [ 2 ] = { --paladin
        ["Avenging Wrath"] =                    TCDStandard,
        ["Avenging Crusader"] =                 TCDStandard,
        ["Holy Avenger"] =                      TCDStandard,
        ["Crusade"] =                           TCDStandard,
        ["Seraphim"] =                          TCDStandard
        --Testing displaying their active aura here; maybe move
        --["Concentration Aura"] =                TCDLow,
        --["Retribution Aura"] =                  TCDLow,
        --["Crusader Aura"] =                     TCDLow,
        --["Devotion Aura"] =                     TCDLow
    } ,
    [ 5 ] = { --priest
        ["Archangel"] =                         TCDStandard,
        ["Dark Archangel"] =                    TCDStandard,
        ["Rapture"] =                           TCDStandard,
        ["Apotheosis"] =                        TCDStandard,
        --["Divinity"] = true,
        ["Voidform"] =                          TCDStandard,
        ["Surrender to Madness"] =              TCDStandard,
        [109964] =                              TCDStandard, --Spirit Shell
        ["Shadow Covenant"] =                   TCDStandard
    } ,
    [ 4 ] = { --rogue
        ["Shadow Blades"] =                     TCDStandard,
        ["Shadow Dance"] =                      TCDStandard,
        ["Shadowy Duel"] =                      TCDStandard,
        ["Adrenaline Rush"] =                   TCDStandard,
        ["Blade Flurry"] =                      TCDStandard,
        ["Killing Spree"] =                     TCDStandard
    } ,
    [ 7 ] = { --shaman
        ["Ascendance"] =                        TCDStandard,
        ["Ancestral Guidance"] =                TCDStandard,
        ["Stormkeeper"] =                       TCDStandard,
        ["Icefury"] =                           TCDStandard,
        ["Doom Winds"] =                        TCDStandard
    } ,
    [ 9 ] = { --lock
        ["Soul Harvest"] =                      TCDStandard,
        ["Dark Soul: Instability"] =            TCDStandard,
        ["Dark Soul: Misery"] =                 TCDStandard,
        ["Nether Portal"] =                     TCDStandard
    } ,
    [ 1 ] = { --warrior
        ["Battle Cry"] =                        TCDStandard,
        ["Avatar"] =                            TCDStandard,
        ["Bladestorm"] =                        TCDStandard,
        ["Bloodbath"] =                         TCDStandard

    },
    [ 12 ] = { --dh
        ["Metamorphosis"] =                     TCDStandard,
        ["Nemesis"] =                           TCDStandard,
        ["Furious Gaze"] =                      TCDLow
    }
};

--External Throughput CDs show important CDs cast by anyone in a special set of throughput buff frames
    --Display Location:     throughtput frames
    --Aura Sources:         any
    --Aura Type:            buff
    --Standard Priority Level:
local ETCDStandard          = {["sbPrio"] = 3, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 3};
local ETCDLow               = {["sbPrio"] = 3, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 4};
local ETCDNoFallthrough     = {["sbPrio"] = nil, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 4};
local ETCDPrioNoFallthrough = {["sbPrio"] = nil, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 1};
CustomBuffs.EXTERNAL_THROUGHPUT_CDS = {
    ["Dark Archangel"] =                ETCDStandard,
    ["Power Infusion"] =                ETCDStandard,
    ["Blood Fury"] =                    ETCDStandard,
    ["Berserking"] =                    ETCDStandard,
    ["Skyfury Totem"] =                 ETCDStandard,

    --TRINKET STUFF
    ["Gladiator's Badge"] =             ETCDNoFallthrough,
    ["Gladiator's Insignia"] =          ETCDNoFallthrough,
    ["Inscrutable Quantum Device"] =    ETCDNoFallthrough,
    ["Anima Infusion"] =                ETCDNoFallthrough,
    ["Anima Font"] =                    ETCDNoFallthrough,
    ["Unbound Changling"] =             ETCDNoFallthrough,
    [345805] =                          ETCDNoFallthrough, --Soulletting Ruby

    --Other Stuff
    ["Earthen Wall"] =                  ETCDPrioNoFallthrough,

    --Dungeon Stuff

    --Spires of Ascension
    ["Bless Weapon"] =                  ETCDLow,
    ["Infuse Weapon"] =                 ETCDLow,
    ["Imbue Weapon"] =                  ETCDLow,
};


--Boss buffs display custom flagged buffs in the boss debuff frames
    --Display Location:     boss debuff frames
    --Aura Sources:         any
    --Aura Type:            buff
    --Standard Priority Level:
local BBStandard = {["sbPrio"] = 2, ["sdPrio"] = nil, ["bdPrio"] = 5, ["tbPrio"] = nil};
CustomBuffs.BOSS_BUFFS = { --Custom Buffs that should be displayed in the Boss Debuff slots
                        --Custom Buffs are lowest priority, and if they fall outside the
                        --number of available Boss Debuff slots, they  fall through to
                        --the normal buff slots

                        --Only tracks buffs cast by the player

    --["Earthen Wall"] =    BBStandard
};


--CCs display CC debuffs in the boss debuff frames
    --Display Location:     boss debuff frames
    --Aura Sources:         any
    --Aura Type:            debuff
    --Standard Priority Level: (priority is increased one level for debuffs that are currently dispellable)
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
CustomBuffs.CC = {

    --------------------
    --   Dispelable   --
    --------------------

    ["Polymorph"] =             MagicStandard,
    ["Freezing Trap"] =         MagicStandard,
    ["Fear"] =                  MagicStandard,
    ["Howl of Terror"] =        MagicStandard,
    ["Mortal Coil"] =           MagicStandard,
    ["Psychic Scream"] =        MagicStandard,
    ["Psychic Horror"] =        MagicStandard,
    ["Seduction"] =             MagicStandard,
    ["Hammer of Justice"] =     MagicStandard,
    ["Holy Word: Chastise"] =   MagicStandard,
    ["Chaos Nova"] =            MagicStandard,
    ["Static Charge"] =         MagicStandard,
    ["Mind Bomb"] =             MagicStandard,
    ["Silence"] =               MagicStandard,
    [196364] =                  MagicStandard, --UA Silence
    ["Sin and Punishment"] =    MagicStandard, --VT dispel fear
    ["Faerie Swarm"] =          MagicStandard,
    [117526] =                  MagicStandard, --Binding Shot CC
    --["Arcane Torrent"] = {["dispelType"] = "magic"},
    --["Earthfury"] = {["dispelType"] = "magic"},
    ["Repentance"] =            MagicStandard,
    ["Lightning Lasso"] =       MagicStandard,
    ["Blinding Light"] =        MagicStandard,
    ["Ring of Frost"] =         MagicStandard,
    ["Dragon's Breath"] =       MagicStandard,
    ["Polymorphed"] =           MagicStandard, --engineering grenade sheep
    ["Shadowfury"] =            MagicStandard,
    ["Imprison"] =              MagicStandard,
    ["Strangulate"] =           MagicStandard,
    ["Absolute Zero"] =         MagicStandard, --Frost DK breath stun legendary CC

    --Roots
    ["Frost Nova"] =            MagicStandard,
    ["Entangling Roots"] =      MagicStandard,
    ["Mass Entanglement"] =     MagicStandard,
    ["Earthgrab"] =             MagicStandard,
    ["Ice Nova"] =              MagicStandard,
    ["Freeze"] =                MagicStandard,
    ["Glacial Spike"] =         MagicStandard,

    --poison/curse/disease/MD dispellable
    ["Hex"] =                   CurseStandard,
    ["Mind Control"] =          PurgeStandard,
    ["Wyvern Sting"] =          PoisonStandard,
    ["Spider Sting"] =          PoisonStandard,
    --[233022] = true, --Spider Sting Silence
    ["Cyclone"] =               MDStandard,
    ["Delirium"] =              DiseaseLow,

    --Not CC but track anyway
    [122470] =                  CCStandard, --Touch of karma debuff

    ["Mirrors of Torment"] =    CCStandard,

    --[[ BFA STUFF
    ["Obsidian Claw"] =         MagicStandard,
    ["Gladiator's Maledict"] =  MagicStandard, ]]


    --Warlock Curses
    ["Curse of Exhaustion"] =   CurseLow,
    ["Curse of Tongues"] =      CurseLow,
    ["Curse of Weakness"] =     CurseLow,

    --------------------
    -- Not Dispelable --
    --------------------


    ["Blind"] =                 CCStandard,
    ["Disarm"] =                CCStandard,
    ["Grapple Weapon"] =        CCStandard,
    ["Asphyxiate"] =            CCStandard,
    ["Bull Rush"] =             CCStandard,
    ["Intimidation"] =          CCStandard,
    ["Kidney Shot"] =           CCStandard,
    ["Maim"] =                  CCStandard,
    ["Enraged Maim"] =          CCStandard,
    ["Axe Toss"] =              CCStandard,
    --["Between the Eyes"] =      CCStandard, no longer cc
    ["Mighty Bash"] =           CCStandard,
    ["Sap"] =                   CCStandard,
    ["Storm Bolt"] =            CCStandard,
    ["Cheap Shot"] =            CCStandard,
    ["Leg Sweep"] =             CCStandard,
    ["Intimidating Shout"] =    CCStandard,
    ["Quaking Palm"] =          CCStandard,
    ["Paralysis"] =             CCStandard,
    ["Scatter Shot"] =          CCStandard,
    ["Fel Eruption"] =          CCStandard,
    [207167] =                  CCStandard, --Blinding Sleet CC

    --Area Denials
    ["Solar Beam"] =            CCStandard,
    [212183] =                  CCStandard, --Smoke Bomb



    -------------------------
    -- Shadowlands Dungeon --
    -------------------------

    --De Other Side
    ["Corrupted Blood"] =                       CCStandard,
    ["Arcane Lightning"] =                      CCStandard,
    [321948] =                                  CCStandard, --Localized Explosive Contrivance
    ["Cosmic Artifice"] =                       MagicStandard,

    ["Beak Slice"] =                            CCStandard,
    ["Wailing Grief"] =                         MagicStandard,
    [332707] =                                  MagicStandard, --Shadow word pain from priests

    --Halls of Atonement
    ["Sinlight Visions"] =                      MagicStandard,
    ["Curse of Stone"] =                        CurseStandard,
    ["Haunting Fixation"] =                     CCStandard,
    ["Stigma of Pride"] =                       CCStandard,
    ["W-00F"] =                                 CCStandard,

    [325701] =                                  MagicStandard, --Siphon Life
    ["Curse of Obliteration"] =                 CurseStandard,
    ["Jagged Swipe"] =                          CCStandard,  --TODO: Bleed tag?
    ["Stony Veins"] =                           MagicStandard,
    ["Turn to Stone"] =                         MagicStandard,

    --Mists of Tirna Scithe
    ["Repulsive Visage"] =                      CCStandard,
    ["Freeze Tag Fixation"] =                   CCStandard,
    ["Freezing Burst"] =                        CCStandard,
    ["Mind Link"] =                             CCStandard,

    ["Overgrowth"] =                            CCStandard,
    ["Anima Injection"] =                       MagicStandard,
    ["Debilitating Poison"] =                   PoisonStandard,
    ["Volatile Acid"] =                         CCStandard,
    ["Bewildering Pollen"] =                    MagicStandard,
    ["Soul Split"] =                            MagicStandard,
    ["Triple Bite"] =                           PoisonStandard,

    --Plaguefall
    ["Debilitating Plague"] =                   DiseaseStandard,
    ["Withering Filth"] =                       MagicStandard,
    ["Cytotoxic Slash"] =                       PoisonStandard,
    ["Shadow Ambush"] =                         CCStandard,
    ["Infectious Rain"] =                       DiseaseStandard,

    ["Violent Detonation"] =                    DiseaseStandard,
    ["Plague Bomb"] =                           DiseaseStandard,
    ["Corroded Claws"] =                        DiseaseStandard,
    ["Venompiercer"] =                          PoisonStandard,
    ["Gripping Infection"] =                    MagicStandard,
    ["Corrosive Gunk"] =                        DiseaseStandard,

    --Sanguine Depths
    ["Juggernaut Rush"] =                       CCStandard,
    ["Sintouched Anima"] =                      CurseStandard,
    ["Castigate"] =                             CCStandard,
    ["Anguished Cries"] =                       MagicStandard,
    ["Wicked Gash"] =                           CCLow, --TODO: Maybe add bleed category?

    ["Curse of Suppression"] =                  CurseStandard,
    ["Barbed Shackles"] =                       CCStandard,
    ["Explosive Anger"] =                       CurseStandard,
    ["Wrack Soul"] =                            MagicStandard,


    --Spires of Ascension
    ["Charged Anima"] =                         MagicStandard,
    ["Lingering Doubt"] =                       CCStandard,
    ["Anima Surge"] =                           CCStandard,
    ["Lost Confidence"] =                       MagicStandard,
    ["Dark Lance"] =                            MagicStandard,
    ["Dark Stride"] =                           CCStandard,
    ["Purifying Blast"] =                       CCStandard,
    ["Blinding Flash"] =                        CCStandard,

    ["Forced Confession"] =                     MagicStandard,
    ["Internal Strife"] =                       MagicStandard,
    ["Burden of Knowledge"] =                   MagicStandard,
    ["Insidious Venom"] =                       MagicStandard,

    --Necrotic Wake
    ["Heaving Retch"] =                         DiseaseStandard,
    ["Meat Hook"] =                             CCStandard,
    ["Stitchneedle"] =                          CCStandard,
    ["Morbid Fixation"] =                       CCStandard,

    ["Rasping Scream"] =                        MagicStandard,
    ["Clinging Darkness"] =                     MagicStandard,
    ["Rasping Scream"] =                        MagicStandard,
    ["Drain Fluids"] =                          CCStandard,
    [338357] =                                  CCStandard, --Tenderize
    ["Throw Cleaver"] =                         CCStandard,
    ["Grim Fate"] =                             CCStandard,
    ["Boneflay"] =                              DiseaseStandard,
    ["Goresplatter"] =                          DiseaseStandard,

    --Theater of Pain
    [320069] =                                  CCStandard, --Mortal Strike
    ["Genetic Alteration"] =                    CCStandard,
    ["Phantasmal Parasite"] =                   CCStandard,
    ["Manifest Death"] =                        CCStandard,
    ["Fixate"] =                                CCStandard,

    ["Soul Corruption"] =                       MagicStandard,
    ["Withering Blight"] =                      DiseaseStandard,
    ["Decaying Blight"] =                       DiseaseStandard,
    ["Curse of Desolation"] =                   CurseStandard,


    --------------------
    -- Castle Nathria --
    --------------------
    [324982] =                                  CCStandard,


    --["Vendetta"] =              {["dispelType"] = nil, ["sdPrio"] = 3, ["bdPrio"] = 4},
    --["Counterstrike Totem"] =   {["dispelType"] = nil, ["sdPrio"] = 3, ["bdPrio"] = 4} --Debuff when affected by counterstrike totem
};

------- Setup -------
--Helper function to determine if the dispel type of a debuff matches available dispels
local function canDispelDebuff(debuffInfo)
    if not debuffInfo or not debuffInfo.dispelType or not CustomBuffs.dispelValues[debuffInfo.dispelType] then return false; end
    return bit.band(CustomBuffs.dispelType,CustomBuffs.dispelValues[debuffInfo.dispelType]) ~= 0;
end

--sets a flag on every element of CustomBuffs.CC indicating whether it is currently dispellable
local function precalcCanDispel()
    for _, v in pairs(CustomBuffs.CC)  do
        v.canDispel = canDispelDebuff(v);
    end
end

--Helper function to manage responses to spec changes
function CustomBuffs:updatePlayerSpec()
    --Check if player can dispel magic (is a healing spec or priest)
    --Technically warlocks can sometimes dispel magic with an imp and demon hunters can dispel
    --magic with a pvp talent, but we ignore these cases
    if not CustomBuffs.playerClass then CustomBuffs.playerClass = select(2, UnitClass("player")); end

    --Make sure we can get spec; if not then try again in 5 seconds
    local spec = GetSpecialization();
    if spec then
        local role = select(5, GetSpecializationInfo(GetSpecialization()));
    else
        C_Timer.After(5, function()
            CustomBuffs:updatePlayerSpec();
        end);
        return;
    end

    --All other classes of dispel are class specific, but magic dispels are given by spec
    if (CustomBuffs.playerClass == "PRIEST" or role == "HEALER") then
        CustomBuffs.canDispelMagic = true;
    else
        CustomBuffs.canDispelMagic = false;
    end

    CustomBuffs.dispelType = 0;

    if (CustomBuffs.playerClass == "PRIEST" or CustomBuffs.playerClass == "SHAMAN" or CustomBuffs.playerClass == "DEMONHUNTER"
        or CustomBuffs.playerClass == "MAGE" or CustomBuffs.playerClass == "HUNTER" or CustomBuffs.playerClass == "WARLOCK") then
        CustomBuffs.dispelType = bit.bor(CustomBuffs.dispelType, CustomBuffs.dispelValues.purge);
    end

    --Calculate player's current dispel type

    if CustomBuffs.canDispelMagic then
        CustomBuffs.dispelType = bit.bor(CustomBuffs.dispelType, CustomBuffs.dispelValues.magic);
    end
    if CustomBuffs.canDispelCurse then
        CustomBuffs.dispelType = bit.bor(CustomBuffs.dispelType, CustomBuffs.dispelValues.curse);
    end
    if CustomBuffs.canDispelPoison then
        CustomBuffs.dispelType = bit.bor(CustomBuffs.dispelType, CustomBuffs.dispelValues.poison);
    end
    if CustomBuffs.canDispelDisease then
        CustomBuffs.dispelType = bit.bor(CustomBuffs.dispelType, CustomBuffs.dispelValues.disease);
    end
    if CustomBuffs.canMassDispel then
        CustomBuffs.dispelType = bit.bor(CustomBuffs.dispelType, CustomBuffs.dispelValues.massDispel);
    end

    precalcCanDispel();
end

local function handleRosterUpdate()
    --Update debuff display mode; allow 9 extra overflow debuff frames that grow out
    --of the left side of the unit frame when the player's group is less than 6 people.
    --Frames are disabled when the player's group grows past 5 players because most UI
    --configurations wrap to a new column after 5 players.
    if (CustomBuffs.db.profile.extraDebuffs or CustomBuffs.db.profile.extraBuffs) then
        if GetNumGroupMembers() <= 5 then
            if CustomBuffs.inRaidGroup then
                if CustomBuffs.db.profile.extraDebuffs then
                    CustomBuffs.MAX_DEBUFFS = 15;
                    for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
                        --index 1 is a string for some reason so we skip it
                        if index ~= 1 and frame and frame.debuffFrames then
                            frame.debuffNeedUpdate = true;
                        end
                    end
                else
                    CustomBuffs.MAX_BUFFS = 15;
                    for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
                        --index 1 is a string for some reason so we skip it
                        if index ~= 1 and frame and frame.debuffFrames then
                            frame.buffNeedUpdate = true;
                        end
                    end
                end
                CustomBuffs.inRaidGroup = false;
            end
        else
            if not CustomBuffs.inRaidGroup then
                if CustomBuffs.db.profile.extraDebuffs then
                    CustomBuffs.MAX_DEBUFFS = 6;
                    for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
                        --index 1 is a string for some reason so we skip it
                        if index ~= 1 and frame and frame.debuffFrames then
                            frame.debuffNeedUpdate = true;
                        end
                    end
                else
                    CustomBuffs.MAX_BUFFS = 6;
                    for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
                        --index 1 is a string for some reason so we skip it
                        if index ~= 1 and frame and frame.debuffFrames then
                            frame.buffNeedUpdate = true;
                        end
                    end
                end
                CustomBuffs.inRaidGroup = true;
            end
        end
    elseif CustomBuffs.db.profile.showCastBars then
        --We only show cast bars in groups of 5 or less, so we still need to update our group
        --size tracker if cast bars are enabled
        if GetNumGroupMembers() <= 5 then
             CustomBuffs.inRaidGroup = false;
        else
             CustomBuffs.inRaidGroup = true;
        end
    end

    --Update table of group members
    CustomBuffs.units = CustomBuffs.units or {};
    for _, table in pairs(CustomBuffs.units) do
        table.invalid = true;
    end
    for i=1, #CompactRaidFrameContainer.units do
        local frame = _G["CompactRaidFrame"..i];
        if not frame or not frame.unit then break; end
        local unit = _G["CompactRaidFrame"..i].unit;
        local guid = UnitGUID(unit);
        if guid then
            --print("Frame number "..i.." id "..unit);
            CustomBuffs.units[guid] = CustomBuffs.units[guid] or {};
            CustomBuffs.units[guid].invalid = nil;
            CustomBuffs.units[guid].frameNum = i;
            CustomBuffs.units[guid].unit = unit;
        end
    end

    for i, table in pairs(CustomBuffs.units) do
        if table.invalid then
            twipe(CustomBuffs.units[i]);
            CustomBuffs.units[i] = nil;
        end
    end

    --Make sure to update raid icons on frames when we enter or leave a group
    CustomBuffs:UpdateRaidIcons();

    CustomBuffs:UpdateCastBars();
end

--Check combat log events for interrupts
local function handleCLEU()

    local _, event, _,casterGUID,_,_,_, destGUID, destName,_,_, spellID, spellName = CombatLogGetCurrentEventInfo();

    -- SPELL_INTERRUPT doesn't fire for some channeled spells; if the spell isn't a known interrupt we're done
    if (event == "SPELL_INTERRUPT" or event == "SPELL_CAST_SUCCESS") then
        if (CustomBuffs.INTERRUPTS[spellName] or CustomBuffs.INTERRUPTS[spellID]) then
        --Maybe needed if combat log events are returning spellIDs of 0
        --if spellID == 0 then spellID = lookupIDByName[spellName] end


            if CustomBuffs.units[destGUID] and (event ~= "SPELL_CAST_SUCCESS" or
                (UnitChannelInfo and select(7, UnitChannelInfo(CustomBuffs.units[destGUID].unit)) == false))
            then
                local duration = (CustomBuffs.INTERRUPTS[spellID] or CustomBuffs.INTERRUPTS[spellName]).duration;
                --local _, class = UnitClass(unit)

                CustomBuffs.units[destGUID].int = CustomBuffs.units[destGUID].int or {};
                CustomBuffs.units[destGUID].int.expires = GetTime() + duration;
                CustomBuffs.units[destGUID].int.spellID = spellID;
                CustomBuffs.units[destGUID].int.duration = duration;
                CustomBuffs.units[destGUID].int.spellName = spellName;
                --self.units[destGUID].spellID = spell.parent and spell.parent or spellId

                ForceUpdateFrame(CustomBuffs.units[destGUID].frameNum);

                -- Make sure we clear it after the duration
                C_Timer.After(duration + CustomBuffs.UPDATE_DELAY_TOLERANCE, function()
                    CustomBuffs.units[destGUID].int = nil;
                    ForceUpdateFrame(CustomBuffs.units[destGUID].frameNum);
                end);


            end
        else
            --If an interrupt was detected but we don't recognize the spell then we just trigger some
            --generic interrupt behavior to show that the player was interrupted.
            --The real problem here is that we don't actually have any way of knowing how long the target
            --is actually locked out for, so we just assume 2 seconds, since there are virtually no interrupts
            --in the game that are shorter than 2 seconds
            if CustomBuffs.units[destGUID] and event ~= "SPELL_CAST_SUCCESS" --or
                --(UnitChannelInfo and select(7, UnitChannelInfo(CustomBuffs.units[destGUID].unit)) == false)
            then
                local duration = 2;
                --local _, class = UnitClass(unit)

                CustomBuffs.units[destGUID].int = CustomBuffs.units[destGUID].int or {};
                CustomBuffs.units[destGUID].int.expires = GetTime() + duration;
                CustomBuffs.units[destGUID].int.spellID = spellID;
                CustomBuffs.units[destGUID].int.duration = duration;
                CustomBuffs.units[destGUID].int.spellName = spellName;
                --self.units[destGUID].spellID = spell.parent and spell.parent or spellId

                ForceUpdateFrame(CustomBuffs.units[destGUID].frameNum);

                --Print a message with the spell's name and ID to make it easier to add new interrupts
                --in the future
                print("Detected unknown interrupt: ", spellName, " / ", spellID);

                -- Make sure we clear it after the duration
                C_Timer.After(duration + CustomBuffs.UPDATE_DELAY_TOLERANCE, function()
                    CustomBuffs.units[destGUID].int = nil;
                    ForceUpdateFrame(CustomBuffs.units[destGUID].frameNum);
                end);


            end
        end
    end
    if (event == "SPELL_CAST_SUCCESS") and
        (CustomBuffs.NONAURAS[spellID] or CustomBuffs.NONAURAS[spellName])
    then
            if CustomBuffs.units[casterGUID] then
                local duration = (CustomBuffs.NONAURAS[spellID] or CustomBuffs.NONAURAS[spellName]).duration;
                --local _, class = UnitClass(unit)

                CustomBuffs.units[casterGUID].nauras = CustomBuffs.units[casterGUID].nauras or {};
                CustomBuffs.units[casterGUID].nauras[spellID] = CustomBuffs.units[casterGUID].nauras[spellID] or {};
                CustomBuffs.units[casterGUID].nauras[spellID].expires = GetTime() + duration;
                CustomBuffs.units[casterGUID].nauras[spellID].spellID = spellID;
                CustomBuffs.units[casterGUID].nauras[spellID].duration = duration;
                CustomBuffs.units[casterGUID].nauras[spellID].spellName = spellName;
                --self.units[destGUID].spellID = spell.parent and spell.parent or spellId

                ForceUpdateFrame(CustomBuffs.units[casterGUID].frameNum);

                -- Make sure we clear it after the duration
                C_Timer.After(duration + CustomBuffs.UPDATE_DELAY_TOLERANCE, function()
                    if CustomBuffs.units[casterGUID] and CustomBuffs.units[casterGUID].nauras and CustomBuffs.units[casterGUID].nauras[spellID] then
                        CustomBuffs.units[casterGUID].nauras[spellID] = nil;
                        ForceUpdateFrame(CustomBuffs.units[casterGUID].frameNum);
                    end
                end);



            end
    end

    --[[ Adding tracking for PvP Trinkets here
    if (event == "SPELL_CAST_SUCCESS") and
        (CustomBuffs.NONAURAS[spellID] or CustomBuffs.NONAURAS[spellName])
    then

    end
    --]]

    if  event == "UNIT_DIED" and (GetNumGroupMembers() > 0) then
            if CustomBuffs.units[destGUID] then
                if UnitHealth(CustomBuffs.units[destGUID].unit) <= 1 then
                    if CustomBuffs.units[destGUID] then
                        if CustomBuffs.units[destGUID].int then
                            twipe(CustomBuffs.units[destGUID].int);
                            CustomBuffs.units[destGUID].int = nil;
                        end
                        if CustomBuffs.units[destGUID].nauras then
                            twipe(CustomBuffs.units[destGUID].nauras);
                            CustomBuffs.units[destGUID].nauras = nil;
                        end
                        ForceUpdateFrame(CustomBuffs.units[destGUID].frameNum);
                    end
                end

            end
    end
end

--[[
local oldRTU = CompactRaidFrameContainer_ReadyToUpdate;
CompactRaidFrameContainer_ReadyToUpdate = function(self)
    return not InCombatLockdown() and oldRTU;
end
--]]

--[[ TODO: look into ways to force Blizzard to not attempt shuffling frames in combat
local oldSetUnit = CompactUnitFrame_SetUnit;
CompactUnitFrame_SetUnit = function(self)

end
--]]

--Deal with combat breaking frames by disabling CompactRaidFrameContainer's layoutFrames function
--while in combat so players joining or leaving the group/raid in combat won't break anyone else's frames
local oldUpdateLayout = CompactRaidFrameContainer_LayoutFrames;
CompactRaidFrameContainer_LayoutFrames = function(self)
    if InCombatLockdown() then
        CustomBuffs.layoutNeedsUpdate = true;
    else

        --updating layout makes calls to update aura frame sizes at an unfortunate time, so we set flags on
        --each of the frames to override blizzard's overriding of their size on the next update
        for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
            --index 1 is a string for some reason so we skip it
            if index ~= 1 and frame and frame.debuffFrames then
                frame.auraNeedResize = true;
            end
        end

        oldUpdateLayout(self);
        --Make sure we update the frame numbers for each of our tracked units
        handleRosterUpdate();
    end
end



--Establish player class and set up class based logic

--Look up player class
CustomBuffs.playerClass = select(2, UnitClass("player"));
CustomBuffs.canMassDispel = (CustomBuffs.playerClass == "PRIEST");

if (CustomBuffs.playerClass == "PALADIN") or (CustomBuffs.playerClass == "MONK") then
    --Class can dispel poisons and diseases but not curses
    CustomBuffs.canDispelCurse = false;
    CustomBuffs.canDispelPoison = true;
    CustomBuffs.canDispelDisease = true;

elseif (CustomBuffs.playerClass == "MAGE") or (CustomBuffs.playerClass == "SHAMAN") then
    --Class can dispel curses but not poisons or diseases
    CustomBuffs.canDispelCurse = true;
    CustomBuffs.canDispelPoison = false;
    CustomBuffs.canDispelDisease = false;

elseif CustomBuffs.playerClass == "DRUID" then
    --Class can dispel poisons and curses but not disease
    CustomBuffs.canDispelCurse = true;
    CustomBuffs.canDispelPoison = true;
    CustomBuffs.canDispelDisease = false;

elseif CustomBuffs.playerClass == "PRIEST" then
    --Class can dispel diseases but not curses or poisons
    CustomBuffs.canDispelCurse = false;
    CustomBuffs.canDispelPoison = false;
    CustomBuffs.canDispelDisease = true;

else --[[(CustomBuffs.playerClass == "DEATHKNIGHT") or (CustomBuffs.playerClass == "HUNTER") or (CustomBuffs.playerClass == "ROGUE") or
    (CustomBuffs.playerClass == "DEMONHUNTER") or (CustomBuffs.playerClass == "WARRIOR") or (CustomBuffs.playerClass == "WARLOCK") then ]]

    --Either class was not recognized or class cannot dispel curse, poison or disease
    CustomBuffs.canDispelCurse = false;
    CustomBuffs.canDispelPoison = false;
    CustomBuffs.canDispelDisease = false;
end


--Use spec based information to set CustomBuffs.canDispelMagic
CustomBuffs:updatePlayerSpec();


--Set up flag to track whether there has been an aborted attempt to call
--CompactRaidFrameContainer_LayoutFrames in combat
if not CustomBuffs.layoutNeedsUpdate then
    CustomBuffs.layoutNeedsUpdate = false;
end

CustomBuffs.CustomBuffsFrame:SetScript("OnEvent",function(self, event, ...)
    --Check combat log events for interrupts
    if (event == "COMBAT_LOG_EVENT_UNFILTERED") then
        handleCLEU();

    --Update spec based logic when the player changes spec
    elseif (event == "PLAYER_SPECIALIZATION_CHANGED") then
        CustomBuffs:updatePlayerSpec();

    --Update the layout when the player leaves combat if needed
    elseif event == "PLAYER_REGEN_ENABLED" then
        if CustomBuffs.layoutNeedsUpdate then
            oldUpdateLayout(CompactRaidFrameContainer);
            CustomBuffs.layoutNeedsUpdate = false;
        end
        --[[
        for frame, _ in ipairs(needsUpdateVisible) do
            CompactUnitFrame_UpdateVisible(frame);
            needsUpdateVisible[frame] = nil;
        end
        --]]
    elseif event == "GROUP_ROSTER_UPDATE" then
        handleRosterUpdate();
    end
end);

--Register frame for events
CustomBuffs.CustomBuffsFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
CustomBuffs.CustomBuffsFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
CustomBuffs.CustomBuffsFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
CustomBuffs.CustomBuffsFrame:RegisterEvent("GROUP_ROSTER_UPDATE");



local function calcBuffSize(frame)
    if not frame then return 14; end
    return CustomBuffs.BUFF_SCALE_FACTOR * min(frame:GetHeight() / 36, frame:GetWidth() / 72);
end

-------------------------------
--    Aura Frame Managers    --
-------------------------------

local function setUpExtraDebuffFrames(frame)
    if not frame then return; end

    setMaxDebuffs(frame, CustomBuffs.MAX_DEBUFFS);
    local s = calcBuffSize(frame) * (dbSize or 1);

    if not frame.debuffFrames[CustomBuffs.MAX_DEBUFFS] then
        for i = 4, CustomBuffs.MAX_DEBUFFS do
            local bf = CreateFrame("Button", frame:GetName().."Debuff"..i, frame, "CompactDebuffTemplate");
            bf.baseSize=22;
            bf:Hide();
        end
        frame.debuffsLoaded = true;
    end

    --Set the size of default debuffs
    for i = 1, 3 do
        frame.debuffFrames[i]:SetSize(s, s);
    end

    for i=4, CustomBuffs.MAX_DEBUFFS do
        local bf = frame.debuffFrames[i];

        bf:ClearAllPoints();
        if i > 3 and i < 7 then
            bf:SetPoint("BOTTOMRIGHT", frame.debuffFrames[i-3], "TOPRIGHT", 0, 0);
        elseif i > 6 and i < 10 then
            bf:SetPoint("TOPRIGHT", frame.debuffFrames[1], "TOPRIGHT", -(s * (i - 6) + 5), 0);
        elseif i > 9 then
            bf:SetPoint("BOTTOMRIGHT", frame.debuffFrames[i-3], "TOPRIGHT", 0, 0);
        else
            bf:SetPoint("TOPRIGHT", frame.debuffFrames[1], "TOPRIGHT", -(s * (i - 3)), 0);
        end
        frame.debuffFrames[i]:SetSize(s, s);
    end
end

local function setUpExtraBuffFrames(frame)
        if not frame then return; end

        setMaxBuffs(frame, CustomBuffs.MAX_BUFFS);
        local s = calcBuffSize(frame) * (bSize or 1);

        if not frame.buffFrames[CustomBuffs.MAX_BUFFS] then
            for i = 4, CustomBuffs.MAX_BUFFS do
                local bf = CreateFrame("Button", frame:GetName().."Buff"..i, frame, "CompactBuffTemplate");
                bf.baseSize=22;
                bf:Hide();
            end
        end

        --Set the size of default buffs
        for i = 1, 3 do
            frame.buffFrames[i]:SetSize(s, s);
        end

        for i= 4, CustomBuffs.MAX_BUFFS do
            local bf = frame.buffFrames[i];

            bf:ClearAllPoints();
            if i > 3 and i < 7 then
                bf:SetPoint("BOTTOMRIGHT", frame.buffFrames[i-3], "TOPRIGHT", 0, 0);
            elseif i > 6 and i < 10 then
                bf:SetPoint("TOPRIGHT", frame.buffFrames[1], "TOPRIGHT", (s * (i - 6) + 5), 0);
            elseif i > 9 then
                bf:SetPoint("BOTTOMRIGHT", frame.buffFrames[i-3], "TOPRIGHT", 0, 0);
            else
                bf:SetPoint("TOPRIGHT", frame.buffFrames[1], "TOPRIGHT", -(s * (i - 3)), 0);
            end
            frame.buffFrames[i]:SetSize(s, s);
        end
end

local function setUpThroughputFrames(frame)
    if not frame then return; end

    local size = calcBuffSize(frame) * (tbSize or 1.2);

    if not frame.throughputFrames then
        local bfone = CreateFrame("Button", frame:GetName().."ThroughputBuff1", frame, "CompactBuffTemplate");
        table.remove(frame.buffFrames);
        bfone.baseSize = size;
        bfone:SetSize(size, size);

        local bftwo = CreateFrame("Button", frame:GetName().."ThroughputBuff2", frame, "CompactBuffTemplate");
        table.remove(frame.buffFrames);
        bftwo.baseSize = size;
        bftwo:SetSize(size, size);

        frame.throughputFrames = {bfone,bftwo};
    end

    local buffs = frame.throughputFrames;

    buffs[1]:SetSize(size, size);
    buffs[2]:SetSize(size, size);

    buffs[1]:ClearAllPoints();
    buffs[2]:ClearAllPoints();

    buffs[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1);
    buffs[2]:SetPoint("TOPRIGHT", buffs[1], "TOPLEFT", -1, 0);

    --[[
    buffs[1].ClearAllPoints = function() return; end
    buffs[2].ClearAllPoints = function() return; end
    buffs[1].SetPoint = function() return; end
    buffs[2].SetPoint = function() return; end
    buffs[1].SetSize = function() return; end
    buffs[2].SetSize = function() return; end
    --]]

    buffs[1]:Hide();
    buffs[2]:Hide();

    buffs[1]:SetFrameStrata("MEDIUM");
    buffs[2]:SetFrameStrata("MEDIUM");
end

local function updateBossDebuffs(frame)
    local debuffs = frame.bossDebuffs;
    --local size = frame.buffFrames[1]:GetWidth() * (bdSize or 1.5);
    local size = calcBuffSize(frame) * (bdSize or 1.5);

    debuffs[1]:SetSize(size, size);
    debuffs[2]:SetSize(size, size);

    debuffs[1]:ClearAllPoints();
    debuffs[2]:ClearAllPoints();

    if debuffs[2]:IsShown() then
        debuffs[1]:SetPoint("TOPRIGHT",frame,"TOP",-1,-1);
    else
        debuffs[1]:SetPoint("TOP",frame,"TOP",0,-1);
    end

    debuffs[2]:SetPoint("LEFT",debuffs[1],"RIGHT",2,0);

    debuffs[1]:SetFrameStrata("MEDIUM");
    debuffs[2]:SetFrameStrata("MEDIUM");
end

local function setUpBossDebuffFrames(frame)
    if not frame then return; end

    if not frame.bossDebuffs then
        local bfone = CreateFrame("Button", frame:GetName().."BossDebuff1", frame, "CompactDebuffTemplate");
        table.remove(frame.debuffFrames);
        bfone.baseSize = frame.buffFrames[1]:GetWidth() * 1.2;
        bfone.maxHeight= frame.buffFrames[1]:GetWidth() * 1.5;
        bfone:SetSize(frame:GetHeight() / 2, frame:GetHeight() / 2);

        local bftwo = CreateFrame("Button", frame:GetName().."BossDebuff2", frame, "CompactDebuffTemplate");
        table.remove(frame.debuffFrames);
        bftwo.baseSize = frame.buffFrames[1]:GetWidth() * 1.2;
        bftwo.maxHeight = frame.buffFrames[1]:GetWidth() * 1.5;
        bftwo:SetSize(frame:GetHeight() / 2, frame:GetHeight() / 2);

        frame.bossDebuffs = {bfone,bftwo};

        bfone:Hide();
        bftwo:Hide();
    end

    updateBossDebuffs(frame);
end


--------------------------------
--    Update Aura Function    --
--------------------------------


--If debuffType is not specified in auraData then the aura is considered a buff
local function updateAura(auraFrame, index, auraData)
    local icon, count, expirationTime, duration, debuffType, spellID, isBuff = auraData[1], auraData[2], auraData[3], auraData[4], auraData[5], auraData[6], auraData[7];

    auraFrame.icon:SetTexture(icon);
    if ( count > 1 ) then
        local countText = count;
        if ( count >= 100 ) then
            countText = BUFF_STACKS_OVERFLOW;
        end

        auraFrame.count:Show();
        auraFrame.count:SetText(countText);
    else
        auraFrame.count:Hide();
    end

    --If the aura is a buff or debuff then set the ID of the frame and let
    --Blizzard handle the tooltip; if the aura is custom, handle the tooltip ourselves
    --Currently supported custom auras:
        --[-1]: Lockout tracker for an interrupt
    if index > 0 then
        --Standard Blizzard aura
        auraFrame:SetID(index);
        if auraFrame.ID then
            auraFrame.ID = nil;
        end

    elseif index == -1 then
        auraFrame.ID = spellID;
        --if CUSTOM_BUFFS_TEST_ENABLED then
            --Aura is a lockout tracker for an interrupt; use tooltip for the
            --interrupt responsible for the lockout
            if not auraFrame.custTooltip then
                ----[[  We update scripts as required
                auraFrame.custTooltip = true;
                --Set an OnEnter handler to show the custom tooltip
                auraFrame:SetScript("OnEnter", function(self)
                    if self.ID then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                        GameTooltip:SetSpellByID(self.ID);
                    else
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                        local id = self:GetID();
                        if id then
                            --[[
                            if self.filter and self.filter == "HELPFUL" then
                                GameTooltip:SetUnitBuff(frame, id);
                            else
                                GameTooltip:SetUnitDebuff(frame, id);
                            end
                            --]]
                            GameTooltip:SetUnitAura(self:GetParent().displayedUnit, id, self.filter);
                        end

                    end
                end);


                auraFrame:SetScript("OnUpdate", function(self)
                    if ( GameTooltip:IsOwned(self) ) then
                        if self.ID then
                            GameTooltip:SetSpellByID(self.ID);
                        else
                            local id = self:GetID();
                            if id then
                                --[[
                                if self.filter and self.filter == "HELPFUL" then
                                    GameTooltip:SetUnitBuff(frame, id);
                                else
                                    GameTooltip:SetUnitDebuff(frame, id);
                                end
                                --]]
                                GameTooltip:SetUnitAura(self:GetParent().displayedUnit, id, self.filter);
                            end

                        end
                    end
                end);

                --Set an OnExit handler to hide the custom tooltip
                auraFrame:SetScript("OnLeave", function(self)
                    if GameTooltip:IsOwned(self) then
                        GameTooltip:Hide();
                    end
                end);
            end
            --]]
            --[[
            C_Timer.After(duration + 1, function()
                auraFrame:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT");
                    --GameTooltip:SetFrameLevel(self:GetFrameLevel() + 2);
                    GameTooltip:SetUnitAura(frame, self:GetID(), self.filter);
                end);
            end);
            --]]

        --end
    end

    if ( expirationTime and expirationTime ~= 0 ) then
        local startTime = expirationTime - duration;
        setCooldownFrame(auraFrame.cooldown, startTime, duration, true);
    else
        clearCooldownFrame(auraFrame.cooldown);
    end

    --If the aura is a debuff then we have some more work to do
    if auraFrame.border then
        --We know that the frame is a debuff frame but it might contain some form
        --of bossBuff which should be flagged as a buff instead of a debuff
        auraFrame.filter = (isBuff) and "HELPFUL" or "HARMFUL";
        auraFrame.isBossBuff = isBuff;

        --Either way we need to either color the debuff border or hide it
        local color = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
	    auraFrame.border:SetVertexColor(color.r, color.g, color.b);
    end

    auraFrame:Show();

end


-------------------------------
-- Main Aura Update function --
-------------------------------

--We will sort the auras out into their preffered display locations;
--We keep these outside of the UpdateAuras function so we don't have to
--create a new set of tables on every call.  This works because all of
--the UI code is single threaded, so we can never have simultaneous executions
--of UpdateAuras
local bossDebuffs, throughputBuffs, buffs, debuffs = {}, {}, {}, {};

function CustomBuffs:UpdateAuras(frame)
    if (not frame or not frame.displayedUnit or frame:IsForbidden() or not frame:IsShown() or not frame.debuffFrames or not frame:GetName():match("^Compact") or not frame.optionTable or not frame.optionTable.displayNonBossDebuffs) then return; end

    --Handle pre calculation logic
    if frame.optionTable.displayBuffs then frame.optionTable.displayBuffs = false; end                          --Tell buff frames to skip blizzard logic
    if frame.optionTable.displayDebuffs then frame.optionTable.displayDebuffs = false; end                      --Tell debuff frames to skip blizzard logic
    if frame.optionTable.displayDispelDebuffs then frame.optionTable.displayDispelDebuffs = false; end          --Prevent blizzard frames from showing dispel debuff frames
    if frame.optionTable.displayNameWhenSelected then frame.optionTable.displayNameWhenSelected = false; end    --Don't show names when the frame is selected to prevent bossDebuff overlap

    if frame.auraNeedResize or not frame.debuffsLoaded or not frame.bossDebuffs or not frame.throughputFrames then
        setUpExtraDebuffFrames(frame);
        setUpExtraBuffFrames(frame);
        setUpThroughputFrames(frame);
        setUpBossDebuffFrames(frame);
        frame.auraNeedResize = false;
    end

    --If our custom aura frames have not yet loaded do nothing
    if not frame.debuffsLoaded or not frame.bossDebuffs or not frame.throughputFrames then return; end

    if frame.debuffNeedUpdate then
        setUpExtraDebuffFrames(frame);
    end
    if frame.buffNeedUpdate then
        setUpExtraBuffFrames(frame);
    end

    --Check for interrupts
    local guid = UnitGUID(frame.displayedUnit);
    if guid and CustomBuffs.units[guid] then
        local unit = CustomBuffs.units[guid];
        if unit.int and unit.int.expires and unit.int.expires > GetTime() then
            --index of -1 for interrupts
            tinsert(bossDebuffs, { ["index"] = -1, ["bdPrio"] = 1, ["auraData"] = {
                --{icon, count, expirationTime, duration}
                GetSpellTexture(unit.int.spellID),
                1,
                unit.int.expires,
                unit.int.duration,
                nil,                                --Interrupts do not have a dispel type
                unit.int.spellID                    --Interrupts need a special field containing the spellID of the interrupt used
                                                    --in order to construct a mouseover tooltip for their aura frames
            }});
        end
        if unit.nauras then
            for id, data in pairs(unit.nauras) do
                tinsert(throughputBuffs, { ["index"] = -1, ["tbPrio"] = data.tbPrio or 1, ["sbPrio"] = data.sbPrio or 1, ["auraData"] = {
                    --{icon, count, expirationTime, duration}
                    GetSpellTexture(id),
                    1,
                    data.expires,
                    data.duration,
                    nil,                                --no dispel type
                    data.spellID                    --Need a special field containing the spellID
                }});
            end
        end
    end


    --Handle Debuffs
    for index = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, unitCaster, _, _, spellID, canApplyAura, isBossAura = UnitDebuff(frame.displayedUnit, index);
        if name then
            if isBossAura then
                --[[ Debug
                if not debuffType then
                    print("potential bug for :", name, ":");
                end
                -- end debug ]]

                --Add to bossDebuffs
                tinsert(bossDebuffs, {
                    ["index"] = index,
                    ["bdPrio"] = 2,
                    ["sdPrio"] = 1,
                    ["auraData"] = {icon, count, expirationTime, duration, debuffType},
                    ["type"] = "debuff"
                });
            elseif (CustomBuffs.CC[name] or CustomBuffs.CC[spellID]) then
                --Add to bossDebuffs; adjust priority if dispellable
                local auraData = CustomBuffs.CC[name] or CustomBuffs.CC[spellID];
                local bdPrio, sdPrio = auraData.bdPrio, auraData.sdPrio;

                if auraData.canDispel then
                    bdPrio = bdPrio - 1;
                    sdPrio = sdPrio - 1;
                end

                tinsert(bossDebuffs, {
                    ["index"] = index,
                    ["bdPrio"] = bdPrio,
                    ["sdPrio"] = sdPrio,
                    ["auraData"] = {icon, count, expirationTime, duration, debuffType},
                    ["type"] = "debuff"
                });
            elseif isPrioDebuff(name, icon, count, debuffType, duration, expirationTime, unitCaster, nil, nil, spellID) then
                --Add to debuffs
                tinsert(debuffs, {
                    ["index"] = index,
                    ["sdPrio"] = 4,
                    ["auraData"] = {icon, count, expirationTime, duration, debuffType},
                    ["type"] = "debuff"
                });
            elseif shouldDisplayDebuff(name, icon, count, debuffType, duration, expirationTime, unitCaster, nil, nil, spellID, canApplyAura, isBossAura) then
                --Add to debuffs
                tinsert(debuffs, {
                    ["index"] = index,
                    ["sdPrio"] = 5,
                    ["auraData"] = {icon, count, expirationTime, duration, debuffType},
                    ["type"] = "debuff"
                });
            end
        else
            break;
        end
    end

    --Update Buffs
    for index = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, unitCaster, _, _, spellID, canApplyAura, isBossAura = UnitBuff(frame.displayedUnit, index);
        local _, _, displayedClass = UnitClass(frame.displayedUnit);
        if name then
            if isBossAura then
                --Debug
                --print("Found boss buff :", name, ":");
                --end debug

                --Add to bossDebuffs
                tinsert(bossDebuffs, {
                    ["index"] = index,
                    ["bdPrio"] = 2,
                    ["sbPrio"] = 1,
                    ["auraData"] = {icon, count, expirationTime, duration, nil, nil, true}
                });
            elseif CustomBuffs.THROUGHPUT_CDS[displayedClass] and (CustomBuffs.THROUGHPUT_CDS[displayedClass][name] or CustomBuffs.THROUGHPUT_CDS[displayedClass][spellID]) then
                --Add to throughputBuffs
                local auraData = CustomBuffs.THROUGHPUT_CDS[displayedClass][name] or CustomBuffs.THROUGHPUT_CDS[displayedClass][spellID];
                tinsert(throughputBuffs, {
                    ["index"] = index,
                    ["tbPrio"] = auraData.tbPrio;
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif CustomBuffs.EXTERNAL_THROUGHPUT_CDS[name] or CustomBuffs.EXTERNAL_THROUGHPUT_CDS[spellID] then
                --Add to throughputBuffs
                local auraData = CustomBuffs.EXTERNAL_THROUGHPUT_CDS[name] or CustomBuffs.EXTERNAL_THROUGHPUT_CDS[spellID];
                tinsert(throughputBuffs, {
                    ["index"] = index,
                    ["tbPrio"] = auraData.tbPrio;
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif (CustomBuffs.CDS[displayedClass] and (CustomBuffs.CDS[displayedClass][name] or CustomBuffs.CDS[displayedClass][spellID])) then
                --Add to buffs
                local auraData = CustomBuffs.CDS[displayedClass][name] or CustomBuffs.CDS[displayedClass][spellID];
                tinsert(buffs, {
                    ["index"] = index,
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif (CustomBuffs.EXTERNALS[name] or CustomBuffs.EXTERNALS[spellID]) and unitCaster ~= "player" and unitCaster ~= "pet" then
                --Add to buffs
                local auraData = CustomBuffs.EXTERNALS[name] or CustomBuffs.EXTERNALS[spellID];
                tinsert(buffs, {
                    ["index"] = index,
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif (CustomBuffs.EXTRA_RAID_BUFFS[name] or CustomBuffs.EXTRA_RAID_BUFFS[spellID]) and (unitCaster == "player" or unitCaster == "pet") then
                --Add to buffs
                local auraData = CustomBuffs.EXTRA_RAID_BUFFS[name] or CustomBuffs.EXTRA_RAID_BUFFS[spellID];
                tinsert(buffs, {
                    ["index"] = index,
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif shouldDisplayBuff(name, icon, count, debuffType, duration, expirationTime, unitCaster, nil, nil, spellID, canApplyAura, isBossAura) then
                --Add to buffs
                tinsert(buffs, {
                    ["index"] = index,
                    ["sbPrio"] = 5,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            end
        else
            break;
        end
    end


    --Assign auras to aura frames


    --Sort bossDebuffs in priority order
    tsort(bossDebuffs, function(a,b)
        if not a or not b then return true; end
        return a.bdPrio < b.bdPrio;
    end);

    --If there are more bossDebuffs than frames, copy extra auras into appropriate fallthrough locations
    for i = 3, #bossDebuffs do
        --Buffs fall through to buffs, debuffs fall through to debuffs
        --If the boss aura is a debuff and has a prio set for debuffs (is intended to fall through)
        --it goes into the debuff list
        if bossDebuffs[i].type and bossDebuffs[i].sdPrio then
            tinsert(debuffs, bossDebuffs[i]);

        --If the boss aura is a buff or doesn't have a standard debuff prio we check if it is flagged
        --to show in a buff slot instead
        elseif bossDebuffs[i].sbPrio then
            --[[ debug stuff
            local name, _, _, _, _, _, _, _, _, _, _, _ = UnitBuff(frame.displayedUnit, bossDebuffs[i].index);
            local name2, _, _, _, _, _, _, _, _, _, _, _ = UnitDebuff(frame.displayedUnit, bossDebuffs[i].index);
            print("Boss buff ", name, " or ", name2, " falling through to buffs.");
            -- end debug stuff ]]

            tinsert(buffs, bossDebuffs[i]);
        end
    end

    --Sort throughputBuffs in priority order
    tsort(throughputBuffs, function(a,b)
        if not a or not b then return true; end
        return a.tbPrio < b.tbPrio;
    end);

    --If there are more throughputBuffs than frames, copy extra auras into appropriate fallthrough locations
    for i = 3, #throughputBuffs do
        --If the extra throughput buff has a standard buff priority then we allow it to fall through
        if throughputBuffs[i].sbPrio then
            tinsert(buffs, throughputBuffs[i]);
        end
    end

    --Sort debuffs in priority order
    tsort(debuffs, function(a,b)
        if not a or not b then return true; end
        return a.sdPrio < b.sdPrio;
    end);

    --Sort buffs in priority order
    tsort(buffs, function(a,b)
        if not a or not b then return true; end
        return a.sbPrio < b.sbPrio;
    end);

    --Update all aura frames

    --Boss Debuffs
    local frameNum = 1;
    while(frameNum <= 2 and bossDebuffs[frameNum]) do
        updateAura(frame.bossDebuffs[frameNum], bossDebuffs[frameNum].index, bossDebuffs[frameNum].auraData);
        frameNum = frameNum + 1;
    end

    --Throughput Frames
    frameNum = 1;
    while(frameNum <= 2 and throughputBuffs[frameNum]) do
        updateAura(frame.throughputFrames[frameNum], throughputBuffs[frameNum].index, throughputBuffs[frameNum].auraData);
        frameNum = frameNum + 1;
    end

    --Standard Debuffs
    frameNum = 1;
    while(frameNum <= frame.maxDebuffs and debuffs[frameNum]) do
        updateAura(frame.debuffFrames[frameNum], debuffs[frameNum].index, debuffs[frameNum].auraData);
        frameNum = frameNum + 1;
    end

    --Standard Buffs
    frameNum = 1;
    while(frameNum <= frame.maxBuffs and buffs[frameNum]) do
        updateAura(frame.buffFrames[frameNum], buffs[frameNum].index, buffs[frameNum].auraData);
        frameNum = frameNum + 1;
    end




    --Hide unused aura frames
    for i = #debuffs + 1, frame.maxDebuffs do
        local auraFrame = frame.debuffFrames[i];
        --if auraFrame ~= frame.bossDebuffs[1] and auraFrame ~= frame.bossDebuffs[2] then auraFrame:Hide(); end
        auraFrame:Hide();
    end

    for i = #bossDebuffs + 1, 2 do
        frame.bossDebuffs[i]:Hide();
    end

    for i = #buffs + 1, frame.maxBuffs do
        local auraFrame = frame.buffFrames[i];
        --if auraFrame ~= frame.throughputFrames[1] and auraFrame ~= frame.throughputFrames[2] then auraFrame:Hide(); end
        auraFrame:Hide();
    end

    for i = #throughputBuffs + 1, 2 do
        frame.throughputFrames[i]:Hide();
    end


    --Hide the name text for frames with active bossDebuffs
    if frame.bossDebuffs[1]:IsShown() then
        frame.name:Hide();
    else
        frame.name:Show();
        --When we call show it doesn't update the text of the name, which
        --means that our SetName code doesn't run until the next update,
        --so we call it manually to override the default blizzard names
        if self.db.profile.cleanNames then
            CustomBuffs:SetName(frame);
        end
    end

    --Boss debuff location is variable, so we need to update their location every update
    updateBossDebuffs(frame);

    twipe(bossDebuffs);
    twipe(throughputBuffs);
    twipe(buffs);
    twipe(debuffs);
end --);


--------------------------------
-- Debug Aura Update function --
--------------------------------

local function DebugUpdateFrame(frame)
    if (not frame or not frame.displayedUnit or frame:IsForbidden() or not frame:IsShown() or not frame.debuffFrames or not frame:GetName():match("^Compact") or not frame.optionTable or not frame.optionTable.displayNonBossDebuffs) then return; end

    --Handle pre calculation logic
    if frame.optionTable.displayBuffs then frame.optionTable.displayBuffs = false; end                          --Tell buff frames to skip blizzard logic
    if frame.optionTable.displayDebuffs then frame.optionTable.displayDebuffs = false; end                      --Tell debuff frames to skip blizzard logic
    if frame.optionTable.displayDispelDebuffs then frame.optionTable.displayDispelDebuffs = false; end          --Prevent blizzard frames from showing dispel debuff frames
    if frame.optionTable.displayNameWhenSelected then frame.optionTable.displayNameWhenSelected = false; end    --Don't show names when the frame is selected to prevent bossDebuff overlap

    if frame.auraNeedResize or not frame.debuffsLoaded or not frame.bossDebuffs or not frame.throughputFrames then
        setUpExtraDebuffFrames(frame);
        setUpExtraBuffFrames(frame);
        setUpThroughputFrames(frame);
        setUpBossDebuffFrames(frame);
        frame.auraNeedResize = false;
    end

    --If our custom aura frames have not yet loaded do nothing
    if not frame.debuffsLoaded or not frame.bossDebuffs or not frame.throughputFrames then return; end

    if frame.debuffNeedUpdate then
        setUpExtraDebuffFrames(frame);
    end
    if frame.buffNeedUpdate then
        setUpExtraBuffFrames(frame);
    end

    --Check for interrupts
    local guid = UnitGUID(frame.displayedUnit);
    if guid and CustomBuffs.units[guid] then
        local unit = CustomBuffs.units[guid];
        if unit.int and unit.int.expires and unit.int.expires > GetTime() then
            --index of -1 for interrupts
            tinsert(bossDebuffs, { ["index"] = -1, ["bdPrio"] = 1, ["auraData"] = {
                --{icon, count, expirationTime, duration}
                GetSpellTexture(unit.int.spellID),
                1,
                unit.int.expires,
                unit.int.duration,
                nil,                                --Interrupts do not have a dispel type
                unit.int.spellID                    --Interrupts need a special field containing the spellID of the interrupt used
                                                    --in order to construct a mouseover tooltip for their aura frames
            }});
        end
        if unit.nauras then
            for id, data in pairs(unit.nauras) do
                tinsert(throughputBuffs, { ["index"] = -1, ["tbPrio"] = data.tbPrio or 1, ["sbPrio"] = data.sbPrio or 1, ["auraData"] = {
                    --{icon, count, expirationTime, duration}
                    GetSpellTexture(id),
                    1,
                    data.expires,
                    data.duration,
                    nil,                                --no dispel type
                    data.spellID                    --Need a special field containing the spellID
                }});
            end
        end
    end


    --Handle Debuffs
    for index = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, unitCaster, _, _, spellID, canApplyAura, isBossAura = UnitDebuff(frame.displayedUnit, index);
        if name then
            if isBossAura then
                --[[ Debug
                if not debuffType then
                    print("potential bug for :", name, ":");
                end
                -- end debug ]]

                --Add to bossDebuffs
                tinsert(bossDebuffs, {
                    ["index"] = index,
                    ["bdPrio"] = 2,
                    ["sdPrio"] = 1,
                    ["auraData"] = {icon, count, expirationTime, duration, debuffType},
                    ["type"] = "debuff"
                });
            elseif (CustomBuffs.CC[name] or CustomBuffs.CC[spellID]) then
                --Add to bossDebuffs; adjust priority if dispellable
                local auraData = CustomBuffs.CC[name] or CustomBuffs.CC[spellID];
                local bdPrio, sdPrio = auraData.bdPrio, auraData.sdPrio;

                if auraData.canDispel then
                    bdPrio = bdPrio - 1;
                    sdPrio = sdPrio - 1;
                end

                tinsert(bossDebuffs, {
                    ["index"] = index,
                    ["bdPrio"] = bdPrio,
                    ["sdPrio"] = sdPrio,
                    ["auraData"] = {icon, count, expirationTime, duration, debuffType},
                    ["type"] = "debuff"
                });
            elseif isPrioDebuff(name, icon, count, debuffType, duration, expirationTime, unitCaster, nil, nil, spellID) then
                --Add to debuffs
                tinsert(debuffs, {
                    ["index"] = index,
                    ["sdPrio"] = 4,
                    ["auraData"] = {icon, count, expirationTime, duration, debuffType},
                    ["type"] = "debuff"
                });
            elseif shouldDisplayDebuff(name, icon, count, debuffType, duration, expirationTime, unitCaster, nil, nil, spellID, canApplyAura, isBossAura) then
                --Add to debuffs
                tinsert(debuffs, {
                    ["index"] = index,
                    ["sdPrio"] = 5,
                    ["auraData"] = {icon, count, expirationTime, duration, debuffType},
                    ["type"] = "debuff"
                });
            end
        else
            break;
        end
    end

    --Update Buffs
    for index = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, unitCaster, _, _, spellID, canApplyAura, isBossAura = UnitBuff(frame.displayedUnit, index);
        local _, _, displayedClass = UnitClass(frame.displayedUnit);
        if name then
            if isBossAura then
                --Debug
                --print("Found boss buff :", name, ":");
                --end debug

                --Add to bossDebuffs
                tinsert(bossDebuffs, {
                    ["index"] = index,
                    ["bdPrio"] = 2,
                    ["sbPrio"] = 1,
                    ["auraData"] = {icon, count, expirationTime, duration, nil, nil, true}
                });
            elseif CustomBuffs.THROUGHPUT_CDS[displayedClass] and (CustomBuffs.THROUGHPUT_CDS[displayedClass][name] or CustomBuffs.THROUGHPUT_CDS[displayedClass][spellID]) then
                --Add to throughputBuffs
                local auraData = CustomBuffs.THROUGHPUT_CDS[displayedClass][name] or CustomBuffs.THROUGHPUT_CDS[displayedClass][spellID];
                tinsert(throughputBuffs, {
                    ["index"] = index,
                    ["tbPrio"] = auraData.tbPrio;
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif CustomBuffs.EXTERNAL_THROUGHPUT_CDS[name] or CustomBuffs.EXTERNAL_THROUGHPUT_CDS[spellID] then
                --Add to throughputBuffs
                local auraData = CustomBuffs.EXTERNAL_THROUGHPUT_CDS[name] or CustomBuffs.EXTERNAL_THROUGHPUT_CDS[spellID];
                tinsert(throughputBuffs, {
                    ["index"] = index,
                    ["tbPrio"] = auraData.tbPrio;
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif (CustomBuffs.CDS[displayedClass] and (CustomBuffs.CDS[displayedClass][name] or CustomBuffs.CDS[displayedClass][spellID])) then
                --Add to buffs
                local auraData = CustomBuffs.CDS[displayedClass][name] or CustomBuffs.CDS[displayedClass][spellID];
                tinsert(buffs, {
                    ["index"] = index,
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif (CustomBuffs.EXTERNALS[name] or CustomBuffs.EXTERNALS[spellID]) and unitCaster ~= "player" and unitCaster ~= "pet" then
                --Add to buffs
                local auraData = CustomBuffs.EXTERNALS[name] or CustomBuffs.EXTERNALS[spellID];
                tinsert(buffs, {
                    ["index"] = index,
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif (CustomBuffs.EXTRA_RAID_BUFFS[name] or CustomBuffs.EXTRA_RAID_BUFFS[spellID]) and (unitCaster == "player" or unitCaster == "pet") then
                --Add to buffs
                local auraData = CustomBuffs.EXTRA_RAID_BUFFS[name] or CustomBuffs.EXTRA_RAID_BUFFS[spellID];
                tinsert(buffs, {
                    ["index"] = index,
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif shouldDisplayBuff(name, icon, count, debuffType, duration, expirationTime, unitCaster, nil, nil, spellID, canApplyAura, isBossAura) then
                --Add to buffs
                tinsert(buffs, {
                    ["index"] = index,
                    ["sbPrio"] = 5,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            end
        else
            break;
        end
    end


    --Assign auras to aura frames

    --Sort bossDebuffs in priority order
    tsort(bossDebuffs, function(a,b)
        if not a or not b then return true; end
        return a.bdPrio < b.bdPrio;
    end);

    --If there are more bossDebuffs than frames, copy extra auras into appropriate fallthrough locations
    for i = 3, #bossDebuffs do
        --Buffs fall through to buffs, debuffs fall through to debuffs
        if bossDebuffs[i].type then
            tinsert(debuffs, bossDebuffs[i]);
        else
            --[[ debug stuff
            local name, _, _, _, _, _, _, _, _, _, _, _ = UnitBuff(frame.displayedUnit, bossDebuffs[i].index);
            local name2, _, _, _, _, _, _, _, _, _, _, _ = UnitDebuff(frame.displayedUnit, bossDebuffs[i].index);
            print("Boss buff ", name, " or ", name2, " falling through to buffs.");
            -- end debug stuff ]]

            tinsert(buffs, bossDebuffs[i]);
        end
    end

    --Sort throughputBuffs in priority order
    tsort(throughputBuffs, function(a,b)
        if not a or not b then return true; end
        return a.tbPrio < b.tbPrio;
    end);

    --If there are more throughputBuffs than frames, copy extra auras into appropriate fallthrough locations
    for i = 3, #throughputBuffs do
        tinsert(buffs, throughputBuffs[i]);
    end

    --Sort debuffs in priority order
    tsort(debuffs, function(a,b)
        if not a or not b then return true; end
        return a.sdPrio < b.sdPrio;
    end);

    --Sort buffs in priority order
    tsort(buffs, function(a,b)
        if not a or not b then return true; end
        return a.sbPrio < b.sbPrio;
    end);

    --Update all aura frames

    --Boss Debuffs
    local frameNum = 1;
    while(frameNum <= 2 and bossDebuffs[frameNum]) do
        updateAura(frame.bossDebuffs[frameNum], bossDebuffs[frameNum].index, bossDebuffs[frameNum].auraData);
        frameNum = frameNum + 1;
    end

    --Throughput Frames
    frameNum = 1;
    while(frameNum <= 2 and throughputBuffs[frameNum]) do
        updateAura(frame.throughputFrames[frameNum], throughputBuffs[frameNum].index, throughputBuffs[frameNum].auraData);
        frameNum = frameNum + 1;
    end

    --Standard Debuffs
    frameNum = 1;
    while(frameNum <= frame.maxDebuffs and debuffs[frameNum]) do
        updateAura(frame.debuffFrames[frameNum], debuffs[frameNum].index, debuffs[frameNum].auraData);
        frameNum = frameNum + 1;
    end

    --Standard Buffs
    frameNum = 1;
    while(frameNum <= frame.maxBuffs and buffs[frameNum]) do
        updateAura(frame.buffFrames[frameNum], buffs[frameNum].index, buffs[frameNum].auraData);
        frameNum = frameNum + 1;
    end




    --Hide unused aura frames
    for i = #debuffs + 1, frame.maxDebuffs do
        local auraFrame = frame.debuffFrames[i];
        --if auraFrame ~= frame.bossDebuffs[1] and auraFrame ~= frame.bossDebuffs[2] then auraFrame:Hide(); end
        auraFrame:Hide();
    end

    for i = #bossDebuffs + 1, 2 do
        frame.bossDebuffs[i]:Hide();
    end

    for i = #buffs + 1, frame.maxBuffs do
        local auraFrame = frame.buffFrames[i];
        --if auraFrame ~= frame.throughputFrames[1] and auraFrame ~= frame.throughputFrames[2] then auraFrame:Hide(); end
        auraFrame:Hide();
    end

    for i = #throughputBuffs + 1, 2 do
        frame.throughputFrames[i]:Hide();
    end


    --Hide the name text for frames with active bossDebuffs
    if frame.bossDebuffs[1]:IsShown() then
        frame.name:Hide();
    else
        frame.name:Show();
        --When we call show it doesn't update the text of the name, which
        --means that our SetName code doesn't run until the next update,
        --so we call it manually to override the default blizzard names
        if self.db.profile.cleanNames then
            CustomBuffs:SetName(frame);
        end
    end

    --Boss debuff location is variable, so we need to update their location every update
    updateBossDebuffs(frame);

    twipe(bossDebuffs);
    twipe(throughputBuffs);
    twipe(buffs);
    twipe(debuffs);
end --);

--TODO: add actual functionality
local function DebugUpdate()
    print(CustomBuffs.debugMode);
end

--Testing fix for special characters
local function stripChars(str)
  local tableAccents = {};
    tableAccents["À"] = "A";
    tableAccents["Á"] = "A";
    tableAccents["Â"] = "A";
    tableAccents["Ã"] = "A";
    tableAccents["Ä"] = "A";
    tableAccents["Å"] = "A";
    tableAccents["Æ"] = "AE";
    tableAccents["Ç"] = "C";
    tableAccents["È"] = "E";
    tableAccents["É"] = "E";
    tableAccents["Ê"] = "E";
    tableAccents["Ë"] = "E";
    tableAccents["Ì"] = "I";
    tableAccents["Í"] = "I";
    tableAccents["Î"] = "I";
    tableAccents["Ï"] = "I";
    tableAccents["Ð"] = "D";
    tableAccents["Ñ"] = "N";
    tableAccents["Ò"] = "O";
    tableAccents["Ó"] = "O";
    tableAccents["Ô"] = "O";
    tableAccents["Õ"] = "O";
    tableAccents["Ö"] = "O";
    tableAccents["Ø"] = "O";
    tableAccents["Ù"] = "U";
    tableAccents["Ú"] = "U";
    tableAccents["Û"] = "U";
    tableAccents["Ü"] = "U";
    tableAccents["Ý"] = "Y";
    tableAccents["Þ"] = "P";
    --tableAccents["ß"] = "s";
    tableAccents["ß"] = "B";
    tableAccents["à"] = "a";
    tableAccents["á"] = "a";
    tableAccents["â"] = "a";
    tableAccents["ã"] = "a";
    tableAccents["ä"] = "a";
    tableAccents["å"] = "a";
    tableAccents["æ"] = "ae";
    tableAccents["ç"] = "c";
    tableAccents["è"] = "e";
    tableAccents["é"] = "e";
    tableAccents["ê"] = "e";
    tableAccents["ë"] = "e";
    tableAccents["ì"] = "i";
    tableAccents["í"] = "i";
    tableAccents["î"] = "i";
    tableAccents["ï"] = "i";
    tableAccents["ð"] = "eth";
    tableAccents["ñ"] = "n";
    tableAccents["ò"] = "o";
    tableAccents["ó"] = "o";
    tableAccents["ô"] = "o";
    tableAccents["õ"] = "o";
    tableAccents["ö"] = "o";
    tableAccents["ø"] = "o";
    tableAccents["ù"] = "u";
    tableAccents["ú"] = "u";
    tableAccents["û"] = "u";
    tableAccents["ü"] = "u";
    tableAccents["ý"] = "y";
    tableAccents["þ"] = "p";
    tableAccents["ÿ"] = "y";

  local normalisedString = '';

  local normalisedString = str: gsub("[%z\1-\127\194-\244][\128-\191]*", tableAccents);

  return normalisedString;

end


function CustomBuffs:CleanName(unitGUID, backupFrame)
    local name = NameCache[unitGUID];
    if not name or name == "Unknown" then
        --if we don't already have the name cached then we calculate it and add it to the cache
        if backupFrame and backupFrame.unit then
            name = GetUnitName(backupFrame.unit, false);
            --manually invalidate unknown names
            if name == "Unknown" then return nil; end
            if name then
                --Replace special characters so we only have to deal with standard 8 bit characters
                name = stripChars(name);

                --Limit the name to specified number of characters and hide realm names
                local lastChar, _ = string.find(name, " "); --there is a space before the realm name; this does cause problems for certain npcs that can join your group
                if not lastChar or lastChar > (self.db.profile.maxNameLength or 12) then lastChar = (self.db.profile.maxNameLength or 12); end
                name = strsub(name,1,lastChar);

                --Update the cache for new unit
                --Don't trust that the unitGUID given actually matches just in case
                NameCache[UnitGUID(backupFrame.unit)] = name;

                return name;
            end
        end
        return nil;
    end
    return name;
end
----[[
--Clean Up Names
function CustomBuffs:SetName(frame)
    if (not frame or frame:IsForbidden() or not frame:IsShown() or not frame.debuffFrames or not frame:GetName():match("^Compact")) then return; end
        local name = "";
        if (frame.optionTable and frame.optionTable.displayName) then
            if frame.bossDebuffs and frame.bossDebuffs[1] and frame.bossDebuffs[1]:IsShown() then
                frame.name:Hide();
                return;
            end

            name = CustomBuffs:CleanName(UnitGUID(frame.unit), frame);
            if not name then frame.name:Hide(); return; end
        end
        frame.name:SetText(name);
end--);
--]]





function CustomBuffs:UpdateRaidIcon(frame)
    if (not frame or not frame:IsShown() or not frame.unit or not frame:GetName():match("^Compact")) then return; end

    if not frame.Icon then
        frame.Icon = {};
	    frame.Icon.texture = frame:CreateTexture(nil, "OVERLAY");
    end

    if not frame.Icon then return; end

    if not self.db.profile.showRaidMarkers and frame.Icon.texture then
        frame.Icon.texture:Hide();
        return;
    end

    local tex = frame.Icon.texture;
    local vertOffset = -0.1 * frame:GetHeight();

    if frame.powerBar and frame.powerBar:IsShown() then
        vertOffset = vertOffset + frame.powerBar:GetHeight() + 1;
    end

    tex:ClearAllPoints();
    tex:SetPoint("CENTER", 0, 0 + vertOffset);

    tex:SetWidth(frame:GetWidth() / 6);
    tex:SetHeight(frame:GetWidth() / 6);

    tex:SetAlpha(0.5);


    -- Get icon on unit
	local index = GetRaidTargetIndex(frame.unit);

	if index and index >= 1 and index <= 8 then
		--the icons are stored in a single image, and UnitPopupButtons["RAID_TARGET_#"] is a table that contains the information for the texture and coords for each icon sub-texture
		local iconTable = UnitPopupButtons["RAID_TARGET_"..index];
		local texture = iconTable.icon;
		local leftTexCoord = iconTable.tCoordLeft;
		local rightTexCoord = iconTable.tCoordRight;
		local topTexCoord = iconTable.tCoordTop;
		local bottomTexCoord = iconTable.tCoordBottom;

		frame.Icon.texture:SetTexture(texture, nil, nil, "TRILINEAR"); --use trilinear filtering to reduce jaggies
		frame.Icon.texture:SetTexCoord(leftTexCoord, rightTexCoord, topTexCoord, bottomTexCoord); --texture contains all the icons in a single texture, and we need to set coords to crop out the other icons
		frame.Icon.texture:Show();
	else
		frame.Icon.texture:Hide();
	end
end


function CustomBuffs:UpdateRaidIcons()
    if not CompactRaidFrameContainer:IsShown() then
        return;
    end

    CompactRaidFrameContainer_ApplyToFrames(CompactRaidFrameContainer, "normal",
			function(frame)
				self:UpdateRaidIcon(frame);
	        end);

end

--Hides but does not fully disable cast bars; used to hide cast bars in raid groups of
--over 5 people
function CustomBuffs:HideCastBars()
    CompactRaidFrameContainer.flowVerticalSpacing = nil;

    if CustomBuffs.CastBars and CustomBuffs.CastBars[1] then
        for _,bar in ipairs(CustomBuffs.CastBars) do
            bar:ClearAllPoints();
            CastingBarFrame_SetUnit(bar, nil, true, true);
        end
    end
end

--Creates 5 cast bars to be used for the player and up to 4 party/raid members
function CustomBuffs:CreateCastBars()
    CustomBuffs.CastBars = CustomBuffs.CastBars or {};

    --Create the frames for the cast bars and set them to track party members' casts
    for i = 1, 5 do
        if not CustomBuffs.CastBars[i] then
            --bar 5 is reserved as the player's cast bar
            local unitName = "party"..i;
            if i == 5 then unitName = "player"; end

            local castBar = CreateFrame("StatusBar", unitName.."CastBar", UIParent, "SmallCastingBarFrameTemplate");
            castBar:SetScale(0.83);
            CastingBarFrame_SetUnit(castBar, unitName, true, true);
            CustomBuffs.CastBars[i] = castBar;
        end
    end
end

function CustomBuffs:UpdateCastBars()
    --Only set up cast bars if enabled and in a group of 5 or less players
    if not self.db.profile.showCastBars then return; end

    --If the raid size is larger than 5 people we need to make sure all of the cast bars are hidden
    if CustomBuffs.inRaidGroup then
        self:HideCastBars();
        return;
    end

    --Create castbars if they don't already exist
    if not CustomBuffs.CastBars or not CustomBuffs.CastBars[1] then
        self:CreateCastBars();
    end

    --Overridable default cast bar positioning values
    CustomBuffs.castBarOffsetX = CustomBuffs.castBarOffsetX or 10;
    CustomBuffs.castBarOffsetY = CustomBuffs.castBarOffsetY or -3;
    CustomBuffs.castBarAnchorPoint = CustomBuffs.castBarAnchorPoint or "TOP";
    CustomBuffs.castBarAnchorTo = CustomBuffs.castBarAnchorTo or "BOTTOM";

    local xOff = CustomBuffs.castBarOffsetX;
    local yOff = CustomBuffs.castBarOffsetY;
    local anchor = CustomBuffs.castBarAnchorPoint;
    local anchorTo = CustomBuffs.castBarAnchorTo;



    --Find the player's raid frame and attach the player cast bar to it
    local pbar = CustomBuffs.CastBars[5];
    for j=1, #CompactRaidFrameContainer.units do
        local frame = _G["CompactRaidFrame"..j];
        if frame and frame.unitExists and UnitIsUnit(frame.unit, "player") then
            pbar:SetParent(frame);
            pbar:SetPoint(anchor, frame, anchorTo, xOff, yOff);
            CastingBarFrame_SetUnit(pbar, frame.unit, true, true);
            pbar:SetWidth(frame:GetWidth());
        end
    end

    --Find the first for party members' raid frames and attach their corresponding cast bars
    for i = 1, 4 do
        local bar = CustomBuffs.CastBars[i];
        if not bar then break; end

        --for i,bar in ipairs(CustomBuffs.CastBars) do
		--bar:SetScale(1);
		bar:ClearAllPoints();
        for j=1, #CompactRaidFrameContainer.units do
            local frame = _G["CompactRaidFrame"..j];
            if frame and frame.unitExists and (UnitIsUnit(frame.unit, "party"..i) and not UnitIsUnit(frame.unit, "player")) then
                bar:SetParent(frame);
                bar:SetPoint(anchor, frame, anchorTo, xOff, yOff);
                CastingBarFrame_SetUnit(bar, frame.unit, true, true);
                bar:SetWidth(frame:GetWidth());
			end
		end
	end

    --Increase the vertical spacing between the raid frames to make space for the new cast bars
    CompactRaidFrameContainer.flowVerticalSpacing = 15;
    FlowContainer_DoLayout(_G.CompactRaidFrameContainer);
end

function CustomBuffs:EnableCastBars()
    self:CreateCastBars();

    --Make sure we catch changing the sort function and update the bars accordingly
    if not self:IsHooked("CompactRaidFrameContainer_SetFlowSortFunction", function(frame) self:UpdateCastBars(); end) then
        self:SecureHook("CompactRaidFrameContainer_SetFlowSortFunction", function(frame) self:UpdateCastBars(); end);
    end

    CustomBuffs:UpdateCastBars();
end



function CustomBuffs:DisableCastBars()
    if self:IsHooked("CompactRaidFrameContainer_SetFlowSortFunction", function(frame) self:UpdateCastBars(); end) then
        self:Unhook("CompactRaidFrameContainer_SetFlowSortFunction", function(frame) self:UpdateCastBars(); end);
    end

    self:HideCastBars();
end

















function CustomBuffs:OnInitialize()
	-- Set up config pane
	self:Init();

	-- Register callbacks for profile switching
	self.db.RegisterCallback(self, "OnProfileChanged", "UpdateConfig");
	self.db.RegisterCallback(self, "OnProfileCopied", "UpdateConfig");
	self.db.RegisterCallback(self, "OnProfileReset", "UpdateConfig");
end

function CustomBuffs:OnDisable() end

function CustomBuffs:OnEnable()
	self:SecureHook("CompactUnitFrame_UpdateAuras", function(frame) self:UpdateAuras(frame); end);



	self:UpdateConfig();

    -- Hook raid icon updates
	self:RegisterBucketEvent({"RAID_TARGET_UPDATE", "RAID_ROSTER_UPDATE"}, 0.1, "UpdateRaidIcons");

	self:RegisterChatCommand("cb",function(options)
        options = string.lower(options);

        if options == "" then
		    InterfaceOptionsFrame_OpenToCategory("CustomBuffs");
		    InterfaceOptionsFrame_OpenToCategory("CustomBuffs");
        elseif options == "weekly" then
            LoadAddOn("Blizzard_WeeklyRewards");
            WeeklyRewardsFrame:Show();
        elseif options == "test" then
            CustomBuffs.debugMode = not CustomBuffs.debugMode;
            DebugUpdate();
        end
    end);

    handleRosterUpdate();
end

function CustomBuffs:Init()
    -- Set up database defaults
	local defaults = self:Defaults();

	-- Create database object
	self.db = LibStub("AceDB-3.0"):New("CustomBuffsData", defaults);
	-- Profile handling
	local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db);

    local generalOptions = self:CreateGeneralOptions();

    self.config = LibStub("AceConfigRegistry-3.0");
	self.config:RegisterOptionsTable("CustomBuffs", generalOptions);
    self.config:RegisterOptionsTable("CustomBuffs Profiles", profiles)

    self.dialog = LibStub("AceConfigDialog-3.0");
	self.dialog:AddToBlizOptions("CustomBuffs", "CustomBuffs");
    self.dialog:AddToBlizOptions("CustomBuffs Profiles", "Profiles", "CustomBuffs");
end

function CustomBuffs:UpdateConfig()
    if not InCombatLockdown() then
		CompactRaidFrameContainer:SetScale(self.db.profile.frameScale);
	end

    if self.db.profile.loadTweaks then
        self:UITweaks();
    end

    if self.db.profile.cleanNames and not self:IsHooked("CompactUnitFrame_UpdateName", function(frame) self:SetName(frame); end) then
        self:SecureHook("CompactUnitFrame_UpdateName", function(frame) self:SetName(frame); end);
    elseif not self.db.profile.cleanNames and self:IsHooked("CompactUnitFrame_UpdateName", function(frame) self:SetName(frame); end) then
        self:Unhook("CompactUnitFrame_UpdateName", function(frame) self:SetName(frame); end);
    end

    if self.db.profile.showCastBars then
        self:EnableCastBars();
    else
        self:DisableCastBars();
    end

    dbSize = self.db.profile.debuffScale;
    bSize = self.db.profile.buffScale;
    tbSize = self.db.profile.throughputBuffScale;
    bdSize = self.db.profile.bossDebuffScale;

    for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
        --index 1 is a string for some reason so we skip it
        if index ~= 1 and frame and frame.debuffFrames then
            frame.auraNeedResize = true;
        end
    end

    self:UpdateRaidIcons();

    handleRosterUpdate();
    --Clear cached names in case updated settings change displayed names
    twipe(NameCache);
end
