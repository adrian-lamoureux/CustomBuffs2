--Known bugs:
--issue with taint on show() causing invalid combat show errors sometimes; unsure of cause
--issue with raid frames sometimes losing click interaction functionality maybe because of this addon

local addonName, addonTable = ...; --make use of the default addon namespace
addonTable.CustomBuffs = LibStub("AceAddon-3.0"):NewAddon("CustomBuffs", "AceTimer-3.0", "AceHook-3.0", "AceEvent-3.0", "AceBucket-3.0", "AceConsole-3.0");
local CustomBuffs = addonTable.CustomBuffs;
if Profiler then _G.CustomBuffs = CustomBuffs end
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
if not CustomBuffs.CustomBuffsFrame then
    CustomBuffs.CustomBuffsFrame = CreateFrame("Frame","CustomBuffsFrame");
end

--Create units table
if not CustomBuffs.units then
    CustomBuffs.units = {};
end

--Set up values for dispel types; used to quickly
--determine whether a spell is dispellable by the player class;
--used to increase the debuff priority of dispellable debuffs
if not CustomBuffs.dispelValues then
    CustomBuffs.dispelValues = {
        ["magic"] = 0x1,
        ["curse"] = 0x2,
        ["poison"] = 0x4,
        ["disease"] = 0x8,
        ["massDispel"] = 0x10,
        ["purge"] = 0x20    --Tracked for things like MC
    };
end

--Set Max Debuffs
if not CustomBuffs.MAX_DEBUFFS then
    CustomBuffs.MAX_DEBUFFS = 6;
end

if not CustomBuffs.MAX_BUFFS then
    CustomBuffs.MAX_BUFFS = 6;
end

--Set Buff Scale Factor
if not CustomBuffs.BUFF_SCALE_FACTOR then
    CustomBuffs.BUFF_SCALE_FACTOR = 10;
    --CustomBuffs.BIG_BUFF_SCALE_FACTOR = 1.5;
end

CustomBuffs.inRaidGroup = false;

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
    end
end

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

local dbSize = 1;
local bSize = 1;
local tbSize = 1.2;
local bdSize = 1.5;

local NameCache = {};


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
    ["Quake"] = { duration = 5 } --240448
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
                ["Lichborne"] =                 CDStandard
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
                ["Seraphim"] =                  CDStandard,
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
                ["Nether Ward"] =                CDStandard
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

    --Minor Externals worth tracking
    ["Enveloping Mist"] =           ELow,

    --Show party/raid member's stealth status in buffs
    ["Stealth"] =                   EStandard,
    ["Vanish"] =                    EStandard,
    ["Prowl"] =                     EStandard,

    --Previous expansion effects
    ["Vampiric Aura"] =             EStandard

};

--Extra raid buffs show untracked buffs from the player on anyone in the standard buff location
    --Display Location:     standard buff
    --Aura Sources:         player
    --Aura Type:            buff
    --Standard Priority Level:
local ERBStandard = {["sbPrio"] = 5, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = nil};
CustomBuffs.EXTRA_RAID_BUFFS = {
    ["Cultivation"] =           ERBStandard,
    ["Spring Blossoms"] =       ERBStandard,
    [290754] =                  ERBStandard, --Lifebloom from early spring honor talent
    ["Glimmer of Light"] =      ERBStandard,
    ["Ancestral Vigor"] =       ERBStandard,

    --BFA procs
    ["Luminous Jellyweed"] =    ERBStandard,
    ["Costal Surge"] =          ERBStandard,
    ["Concentrated Mending"] =  ERBStandard,
    ["Touch of the Voodoo"] =   ERBStandard,
    ["Egg on Your Face"] =      ERBStandard,
    ["Coastal Surge"] =         ERBStandard,
    ["Quickening"] =            ERBStandard,
    ["Ancient Flame"] =         ERBStandard,
    ["Grove Tending"] =         ERBStandard,
    ["Blessed Portents"] =      ERBStandard

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
        ["Unholy Frenzy"] =                     TCDStandard
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

    } ,
    [ 3 ] = { -- hunter
        ["Aspect of the Wild"] =                TCDStandard,
        ["Aspect of the Eagle"] =               TCDStandard,
        ["Bestial Wrath"] =                     TCDStandard,
        ["Trueshot"] =                          TCDStandard
    } ,
    [ 8 ] = { --mage
        ["Icy Veins"] =                         TCDStandard,
        ["Combustion"] =                        TCDStandard,
        ["Arcane Power"] =                      TCDStandard

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
        ["Crusade"] =                           TCDStandard
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
        ["Spirit Shell"] =                      TCDStandard,
        ["Shadow Covenant"] =                   TCDStandard
    } ,
    [ 4 ] = { --rogue
        ["Shadow Blades"] =                     TCDStandard,
        ["Shadow Dance"] =                      TCDStandard,
        ["Shadowy Duel"] =                      TCDStandard,
        ["Adrenaline Rush"] =                   TCDStandard,
        ["Plunder Armor"] =                     TCDStandard
    } ,
    [ 7 ] = { --shaman
        ["Ascendance"] =                        TCDStandard,
        ["Ancestral Guidance"] =                TCDStandard,
        ["Stormkeeper"] =                       TCDStandard,
        ["Icefury"] =                           TCDStandard
    } ,
    [ 9 ] = { --lock
        ["Soul Harvest"] =                      TCDStandard,
        ["Dark Soul: Instability"] =            TCDStandard,
        ["Dark Soul: Misery"] =                 TCDStandard
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
local ETCDStandard = {["sbPrio"] = 3, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 3};
CustomBuffs.EXTERNAL_THROUGHPUT_CDS = {
    ["Dark Archangel"] =    ETCDStandard,
    ["Blood Fury"] =        ETCDStandard,
    ["Berserking"] =        ETCDStandard,

    --Other Stuff
    ["Earthen Wall"] =      {["sbPrio"] = 3, ["tbPrio"] = 1}
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
local MagicStandard =   {["dispelType"] = "magic", ["sdPrio"] = 3, ["bdPrio"] = 4};
local CurseStandard =   {["dispelType"] = "curse", ["sdPrio"] = 3, ["bdPrio"] = 4};
local CurseLow =        {["dispelType"] = "curse", ["sdPrio"] = 3, ["bdPrio"] = 5};
local DiseaseStandard = {["dispelType"] = "disease", ["sdPrio"] = 3, ["bdPrio"] = 4};
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
    ["Chaos Nova"] =            MagicStandard,
    ["Static Charge"] =         MagicStandard,
    ["Mind Bomb"] =             MagicStandard,
    ["Silence"] =               MagicStandard,
    [65813] =                   MagicStandard, --UA Silence
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

    --Not CC but track anyway
    ["Gladiator's Maledict"] =  MagicStandard,
    ["Touch of Karma"] =        MagicStandard, --Touch of karma debuff
    ["Obsidian Claw"] =         MagicStandard,

    --Warlock Curses
    ["Curse of Exhaustion"] =   CurseLow,
    ["Curse of Tongues"] =      CurseLow,
    ["Curse of Weakness"] =     CurseLow,

    --------------------
    -- Not Dispelable --
    --------------------


    ["Blind"] =                 CCStandard,
    ["Asphyxiate"] =            CCStandard,
    ["Bull Rush"] =             CCStandard,
    ["Intimidation"] =          CCStandard,
    ["Kidney Shot"] =           CCStandard,
    ["Maim"] =                  CCStandard,
    ["Enraged Maim"] =          CCStandard,
    --["Between the Eyes"] =      CCStandard, no longer cc
    ["Mighty Bash"] =           CCStandard,
    ["Sap"] =                   CCStandard,
    ["Storm Bolt"] =            CCStandard,
    ["Cheap Shot"] =            CCStandard,
    ["Leg Sweep"] =             CCStandard,
    ["Intimidating Shout"] =    CCStandard,
    ["Quaking Palm"] =          CCStandard,
    ["Paralysis"] =             CCStandard,

    --Area Denials
    ["Solar Beam"] =            CCStandard,
    [212183] =                  CCStandard --Smoke Bomb

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

--Check combat log events for interrupts
local function handleCLEU()

    local _, event, _,_,_,_,_, destGUID, _,_,_, spellID, spellName = CombatLogGetCurrentEventInfo()

    -- SPELL_INTERRUPT doesn't fire for some channeled spells; if the spell isn't a known interrupt we're done
    if (event ~= "SPELL_INTERRUPT" and event ~= "SPELL_CAST_SUCCESS") or (not CustomBuffs.INTERRUPTS[spellID] and not CustomBuffs.INTERRUPTS[spellName]) then return end
    --Maybe needed if combat log events are returning spellIDs of 0
    --if spellID == 0 then spellID = lookupIDByName[spellName] end

    --Find
    for i=1, #CompactRaidFrameContainer.units do
		local unit = CompactRaidFrameContainer.units[i];
        if destGUID == UnitGUID(unit) and (event ~= "SPELL_CAST_SUCCESS" or
            (UnitChannelInfo and select(7, UnitChannelInfo(unit)) == false))
        then
            local duration = (CustomBuffs.INTERRUPTS[spellID] or CustomBuffs.INTERRUPTS[spellName]).duration;
            --local _, class = UnitClass(unit)

            CustomBuffs.units[destGUID] = CustomBuffs.units[destGUID] or {};
            CustomBuffs.units[destGUID].expires = GetTime() + duration;
            CustomBuffs.units[destGUID].spellID = spellID;
            CustomBuffs.units[destGUID].duration = duration;
            CustomBuffs.units[destGUID].spellName = spellName;
            --self.units[destGUID].spellID = spell.parent and spell.parent or spellId

            -- Make sure we clear it after the duration
            C_Timer.After(duration, function()
                --CompactUnitFrame_UpdateAuras();
                CustomBuffs.units[destGUID] = nil;
            end);

            return

        end
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

    end
end);

--Register frame for events
CustomBuffs.CustomBuffsFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
CustomBuffs.CustomBuffsFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
CustomBuffs.CustomBuffsFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");



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
        if auraFrame.int then
            auraFrame.int = nil;
        end

    elseif index == -1 then
        auraFrame.int = spellID;
        --if CUSTOM_BUFFS_TEST_ENABLED then
            --Aura is a lockout tracker for an interrupt; use tooltip for the
            --interrupt responsible for the lockout
            if not auraFrame.custTooltip then
                ----[[  We update scripts as required
                auraFrame.custTooltip = true;
                --Set an OnEnter handler to show the custom tooltip
                auraFrame:SetScript("OnEnter", function(self)
                    if self.int then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                        GameTooltip:SetSpellByID(self.int);
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
                        if self.int then
                            GameTooltip:SetSpellByID(self.int);
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

--We will sort the auras out into their preffered display locations
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

    --Update debuff display mode; allow 9 extra overflow debuff frames that grow out
    --of the left side of the unit frame when the player's group is less than 6 people.
    --Frames are disabled when the player's group grows past 5 players because most UI
    --configurations wrap to a new column after 5 players.
    if (self.db.profile.extraDebuffs or self.db.profile.extraBuffs) then
        if GetNumGroupMembers() <= 5 then
            if CustomBuffs.inRaidGroup then
                if self.db.profile.extraDebuffs then
                    CustomBuffs.MAX_DEBUFFS = 15;
                    setUpExtraDebuffFrames(frame);
                else
                    CustomBuffs.MAX_BUFFS = 15;
                    setUpExtraBuffFrames(frame);
                end
                CustomBuffs.inRaidGroup = false;
            end
        else
            if not CustomBuffs.inRaidGroup then
                if self.db.profile.extraDebuffs then
                    CustomBuffs.MAX_DEBUFFS = 6;
                    setUpExtraDebuffFrames(frame);
                else
                    CustomBuffs.MAX_BUFFS = 6;
                    setUpExtraBuffFrames(frame);
                end
                CustomBuffs.inRaidGroup = true;
            end
        end
    end


    --Check for interrupts
    local guid = UnitGUID(frame.displayedUnit);
    if guid and CustomBuffs.units[guid] and CustomBuffs.units[guid].expires and CustomBuffs.units[guid].expires > GetTime() then
        --index of -1 for interrupts
        tinsert(bossDebuffs, { ["index"] = -1, ["bdPrio"] = 1, ["auraData"] = {
            --{icon, count, expirationTime, duration}
            GetSpellTexture(CustomBuffs.units[guid].spellID),
            1,
            CustomBuffs.units[guid].expires,
            CustomBuffs.units[guid].duration,
            nil,                                --Interrupts do not have a dispel type
            CustomBuffs.units[guid].spellID     --Interrupts need a special field containing the spellID of the interrupt used
                                                --in order to construct a mouseover tooltip for their aura frames
        }});

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
        --means that our CleanNames code doesn't run until the next update,
        --so we call it manually to override the default blizzard names
        if self.db.profile.cleanNames then
            CustomBuffs:CleanNames(frame);
        end
    end

    --Boss debuff location is variable, so we need to update their location every update
    updateBossDebuffs(frame);

    twipe(bossDebuffs);
    twipe(throughputBuffs);
    twipe(buffs);
    twipe(debuffs);
end --);

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
    tableAccents["ß"] = "s";
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



----[[
--Clean Up Names
function CustomBuffs:CleanNames(frame)
    if (not frame or frame:IsForbidden() or not frame:IsShown() or not frame.debuffFrames or not frame:GetName():match("^Compact")) then return; end
        local name = "";
        if (frame.optionTable and frame.optionTable.displayName) then
            if frame.bossDebuffs and frame.bossDebuffs[1] and frame.bossDebuffs[1]:IsShown() then
                frame.name:Hide();
                return;
            end

            name = NameCache[UnitGUID(frame.unit)];
            if not name or name == "Unknown" then
                --if we don't already have the name cached then we calculate it and add it to the cache
                name = GetUnitName(frame.unit, false);

                --if we still can't find a name we give up
                if not name then frame.name:Hide(); return; end

                --Replace special characters so we only have to deal with standard 8 bit characters
                name = stripChars(name);

                --Limit the name to specified number of characters and hide realm names
                local lastChar, _ = string.find(name, " ");
                if not lastChar or lastChar > (self.db.profile.maxNameLength or 9) then lastChar = (self.db.profile.maxNameLength or 9); end
                name = strsub(name,1,lastChar);

                NameCache[UnitGUID(frame.unit)] = name;
            end
        end
        frame.name:SetText(name);
end--);
--]]

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


	self:RegisterChatCommand("cb",function()
		InterfaceOptionsFrame_OpenToCategory("CustomBuffs");
		InterfaceOptionsFrame_OpenToCategory("CustomBuffs");
	end);
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
    if self.db.profile.cleanNames and not self:IsHooked("CompactUnitFrame_UpdateName", function(frame) self:CleanNames(frame); end) then
        self:SecureHook("CompactUnitFrame_UpdateName", function(frame) self:CleanNames(frame); end);
    elseif not self.db.profile.cleanNames and self:IsHooked("CompactUnitFrame_UpdateName", function(frame) self:CleanNames(frame); end) then
        self:Unhook("CompactUnitFrame_UpdateName", function(frame) self:CleanNames(frame); end);
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

    CustomBuffs.inRaidGroup = true;
    --Clear cached names in case updated settings change displayed names
    twipe(NameCache);
end
