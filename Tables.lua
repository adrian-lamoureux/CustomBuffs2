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

CustomBuffs.INTERRUPTS = {
    [1766] =   		{ duration = 5 }, -- Kick (Rogue)
    [2139] =   		{ duration = 6 }, -- Counterspell (Mage)
    [6552] =   		{ duration = 4 }, -- Pummel (Warrior)
    [19647] =  		{ duration = 6 }, -- Spell Lock (Warlock)
    [47528] =  		{ duration = 3 }, -- Mind Freeze (Death Knight)
    [57994] =  		{ duration = 3 }, -- Wind Shear (Shaman)
    [91802] =  		{ duration = 2 }, -- Shambling Rush (Death Knight)
    [96231] =  		{ duration = 4 }, -- Rebuke (Paladin)
    [93985] = 		{ duration = 4 }, -- Skull Bash (Feral)
    [115781] = 		{ duration = 6 }, -- Optical Blast (Warlock)
    [116705] = 		{ duration = 4 }, -- Spear Hand Strike (Monk)
    [132409] = 		{ duration = 6 }, -- Spell Lock (Warlock)
    [147362] = 		{ duration = 3 }, -- Countershot (Hunter)
    [171138] = 		{ duration = 6 }, -- Shadow Lock (Warlock)
    [183752] = 		{ duration = 3 }, -- Consume Magic (Demon Hunter)
    [187707] = 		{ duration = 3 }, -- Muzzle (Hunter)
    [212619] = 		{ duration = 6 }, -- Call Felhunter (Warlock)
    [231665] = 		{ duration = 3 }, -- Avengers Shield (Paladin)
    ["Solar Beam"] = { duration = 5 },

    --Non player interrupts BETA FEATURE
    ["Quake"] = 				{ duration = 5 }, --240448
    ["Deafening Crash"] = 		{ duration = 2 },
	[296523] =			 		{ duration = 3 },
	[220543] =			 		{ duration = 3 },
	[2676] =			 		{ duration = 2 },
	[335485] =			 		{ duration = 4 },
	[342135] =			 		{ duration = 3 },
    [351252] =			 		{ duration = 6 },
    [318995] =			 		{ duration = 3 },
};


CustomBuffs.NONAURAS = {
    --SHAMAN
    [108280] = { duration = 12, tbPrio = 1, type = "summon" }, 	--Healing Tide (Assumes leveling perk for +2 seconds)
    [16191] =  { duration = 8,  tbPrio = 2, type = "summon" }, 	--Mana Tide
    [188592] = { duration = 41.7, tbPrio = 1, type = "summon" },	--Regular Fire Elemental
	[198067] = { duration = 41.7, tbPrio = 1, noSum = 188592 },		--Fire Elemental Pet
	[188616] = { duration = 60, tbPrio = 2, type = "summon" }, 		--Earth Elemental
	[198103] = { duration = 60, tbPrio = 1, noSum = 188616}, 		--Earth Elemental Pet
	[157299] = { duration = 41.7, tbPrio = 1, type = "summon" }, 		--Storm Elemental
    [192249] = { duration = 41.7, tbPrio = 1, noSum = 157299}, 						--Storm Elemental Pet
    [51533] =  { duration = 15, tbPrio = 1}, 						--Feral Spirit
	[5394] =   { duration = 15, tbPrio = 0, sbPrio = 5, type = "summon" }, --Healing Stream
	--[73920] =   { duration = 10, tbPrio = 0, sbPrio = 5}, --Healing Rain
	[8143] =   { duration = 10, tbPrio = 0, sbPrio = 5, type = "summon" }, --Tremor Totem
	[204336] =  { duration = 3, tbPrio = 0, sbPrio = 5, type = "summon" }, --Grounding
	[157153] = { duration = 15, tbPrio = 20, sbPrio = nil, type = "summon" }, --Cloudburst
	--[2484] = 	{ duration = 40, tbPrio = 20, type = "summon" },
	[192077] = 	{ duration = 15, tbPrio = 1, sbPrio = nil, type = "summon" },	--Wind Rush Totem

    --LOCK
    [205180] = { duration = 20, tbPrio = 1, type = "summon" }, --Summon Darkglare
    [111898] = { duration = 17, tbPrio = 1, type = "summon" }, --Grimoire: Felguard
    [265187] = { duration = 15, tbPrio = 1, type = "summon" }, --Summon Demonic Tyrant
    [111685] = { duration = 30, tbPrio = 1, type = "summon" }, --Summon Infernal

    --DRUID
    --[157982] = { duration = 1.5, tbPrio = 1 }, --Tranquility

    --MAGE
    [198149] = { duration = 10, tbPrio = 1 }, --Frozen Orb PvP Talent
    [84714] = { duration = 10, tbPrio = 1 }, --Frozen Orb
	[342130] = { duration = 12, tbPrio = 7, type = "summon" }, --Rune of Power Auto Cast
	[116011] = { duration = 12, tbPrio = 7, type = "summon" }, --Rune of Power Real

    --PRIEST
	[200174] = { duration = 15, tbPrio = 7, type = "summon" }, --Mindbender
	[34433] = { duration = 15, tbPrio = 7, type = "summon" }, --Shadowfiend

    --HUNTER
    [131894] = { duration = 15, tbPrio = 1 }, --Murder of Crows
    [201430] = { duration = 12, tbPrio = 1 }, --Stampede

    --DK
    [63560] = { duration = 15, tbPrio = 1 }, --Dark Transformation
    [42650] = { duration = 30, tbPrio = 1 }, --Army of the Dead
	--[46585] = { duration = 60, tbPrio = 1, type = "summon" }, --Raise Ghoul

    --MONK
    [325197] = { duration = 25, tbPrio = 1, type = "summon" }, --Invoke Chi-ji
    [322118] = { duration = 25, tbPrio = 1, type = "summon" }, --Yu'lon
    [123904] = { duration = 24, tbPrio = 1, type = "summon" }, --Xuen
    [132578] = { duration = 25, tbPrio = 1, type = "summon" }, --Niuzao
	--[115313] = { duration = 900, tbPrio = 0, sbPrio = 20, type = "summon" }, --Serpent Statue

    --DH

    --PALADIN

    --WARRIOR

    --ROGUE

	--COOLDOWN FLASHES
	--Show short flash on frame when a player activates an ability or item

	--Interrupts
	[1766] =   	CDFlash, -- Kick (Rogue)
    [2139] =   	CDFlash, -- Counterspell (Mage)
    [6552] =   	CDFlash, -- Pummel (Warrior)
    [19647] =  	CDFlash, -- Spell Lock (Warlock)
    [47528] =  	CDFlash, -- Mind Freeze (Death Knight)
    [57994] =  	CDFlash, -- Wind Shear (Shaman)
    [91802] =  	CDFlash, -- Shambling Rush (Death Knight)
    [96231] =  	CDFlash, -- Rebuke (Paladin)
    [93985] = 	CDFlash, -- Skull Bash (Feral)
    [115781] = 	CDFlash, -- Optical Blast (Warlock)
	[119910] = 	CDFlash, -- Spell Lock (Warlock)
    [116705] = 	CDFlash, -- Spear Hand Strike (Monk)
    [132409] = 	CDFlash, -- Spell Lock (Warlock)
    [147362] = 	CDFlash, -- Countershot (Hunter)
    [171138] = 	CDFlash, -- Shadow Lock (Warlock)
    [183752] = 	CDFlash, -- Consume Magic (Demon Hunter)
    [187707] = 	CDFlash, -- Muzzle (Hunter)
    [212619] = 	CDFlash, -- Call Felhunter (Warlock)

	--SHAMAN
	[326059] = 	CDFlash, --Primordial Wave
	[328923] = 	CDFlash, --Fae Transfusion
	[328930] = 	CDFlash, --Fae Transfusion
	[98008]  = 	CDFlash, --Spirit Link
	[192058] = 	CDFlash, --Cap Totem
	[51485] = 	CDFlash, --Earthgrab Totem
	[320674] = 	CDFlash, --Chain Harvest
	[157375] = 	CDFlash, --Eye of the Storm
	[157348] = 	CDFlash, --Call Lightning
	[118345] = 	CDFlash, --Pulverize
	[117588] = 	CDFlash, --Meteor
	--[8143] = 	CDFlash, --Tremor
	[197995] = 	CDFlash, --Wellspring
	[51886] = 	CDFlash, --Resto Dispel
	[370] = 	CDFlash, --Purge
	[73685]  = 	CDFlash, --Unleash Life
	[77130]  = 	CDFlash, --Resto dispel


	--LOCK
	[6789] = 	CDFlash, --Coil
	[30283] = 	CDFlash, --Shadowfury
	[19505] = 	CDFlash, --Purge
	[119905] = 	CDFlash, --Imp Dispel
	[6358] = 	CDFlash, --Seduction
	[119907] = 	CDFlash, --Voidwalker Last Stand
	[17735] = 	CDFlash, --Voidwalker Taunt
	[48020] = 	CDFlash, --Port

	--DRUID
	[102793] = 	CDFlash, --Vortex
	[77761] = 	CDFlash, --Stampeding Roar
	[6795] =	CDFlash, --Growl
	[132158] =	CDFlash, --NS
	[18562] =	CDFlash, --Swiftmend
	[22570] =	CDFlash, --Maim
	[5211] =	CDFlash, --Bash
	[108238] =	CDFlash, --Renewal
	[99] =		CDFlash, --Incap Roar

	--MAGE
	[314791] =	CDFlash, --Shifting Power
	[153626] =	CDFlash, --Arcane Orb
	[31661] =	CDFlash, --DB
	[475] =		CDFlash, --Dispel
	[55342] =	CDFlash, --Mirror Images
	[30449] =	CDFlash, --Spellsteal
	[122] =		CDFlash, --Frost Nova
	[321507] =	CDFlash, --Touch of the Magi

	--PRIEST
	[323673] =	CDFlash, --Mind Games
	[2050] =	CDFlash, --Serenity
	[8122] =	CDFlash, --Psychic Scream
	[34861] =	CDFlash, --Sanctify
	[528] =		CDFlash, --Purge
	[527] =		CDFlash, --Dispel Healer
	[213634] =	CDFlash, --Dispel Non healer
	[88625] =	CDFlash, --Chastise
	[32375] =	CDFlash, --MD
	[108968] =	CDFlash, --Life Swap
	[15487] =	CDFlash, --Silence
	[64044] =	CDFlash, --Psychic Horror
	[341374] =	CDFlash, --Damnation
	[73325] =	CDFlash, --LoF
	[62618] =	CDFlash, --Barrier
	[64843] =	CDFlash, --Divine Hymn
	[64901] =	CDFlash, --Symbol of Hope
	[47788] =	CDFlash, --GS

	--HUNTER
	[213691] =	CDFlash, --Scatter Shot
	[1513] =	CDFlash, --Scare Beast
	[187650] =	CDFlash, --Freezing Trap
	[257044] =	CDFlash, --Rapid Fire
	[109304] =	CDFlash, --Exhileration
	[109248] =	CDFlash, --Binding Shot
	[53351] =	CDFlash, --Kill Shot
	[34477] =	CDFlash, --Misdirection
	[186387] =	CDFlash, --Bursting Shot
	[187698] =	CDFlash, --Tar Trap
	[19801] =	CDFlash, --Tranq Shot
	[2649] =	CDFlash, --Pet Taunt
	[236776] =	CDFlash, --Knock Trap
	--[53480] =	CDFlash, --Pet Taunt


	--DK
	[49998] =	CDFlash, --Death Strike

	--MONK
	[115078] =	CDFlash, --Paralysis
	[116844] =	CDFlash, --RoP
	[115310] =	CDFlash, --Revival
	[115450] =	CDFlash, --Healer Dispel
	[115546] =	CDFlash, --Taunt
	[119381] =	CDFlash, --Leg Sweep
	[218164] =	CDFlash, --Non Healer Dispel

	--DH
	[323639] =	CDFlash, --The Hunt
	[278326] =	CDFlash, --Purge
	[207684] =	CDFlash, --Misery
	[202137] =	CDFlash, --Silence
	[204021] =	CDFlash, --Fiery Brand
	[185245] =	CDFlash, --Taunt
	[212084] =	CDFlash, --Fel Dev
	[217832] =	CDFlash, --Imprison

	--PALADIN
	[316958] =	CDFlash, --Ashen
	[633] =		CDFlash, --LoH
	[62124] =	CDFlash, --Taunt
	[31821] =	CDFlash, --Aura Mastery
	[85673] =	CDFlash, --WoG
	[853] =		CDFlash, --HoJ
	--[1022] =	CDFlash, --BoP
	--[1044] =	CDFlash, --Freedom


	--WARRIOR
	[355] =		CDFlash, --Taunt
	[5246] =	CDFlash, --Intimidating Shout
	[46968] =	CDFlash, --Shockwave
	[107570] =	CDFlash, --Storm Bolt
	[64382] =	CDFlash, --Shattering Throw
	[1160] =	CDFlash, --Demo Shout
	[3411] =	CDFlash, --Intervene
	[163201] =	CDFlash, --Execute
	--[23920] =	CDFlash, --Spell Reflect

	--ROGUE
	[1776] =	CDFlash, --Gogue
	[2094] =	CDFlash, --Blind
	[408] =		CDFlash, --Kidney Shot
	[1833] =	CDFlash, --Cheap Shot
	[57934] =	CDFlash, --Tricks
	[6770] =	CDFlash, --Sap
	[319032] =	CDFlash, --Shiv
	[5938] =	CDFlash, --Shiv
	[280719] =	CDFlash, --Secret Technique
	[212283] =	CDFlash, --Symbol of Death
	[121411] =	CDFlash, --Crimson Tempest
	[200806] =	CDFlash, --Exsanguinate
	[79140] =	CDFlash, --Vendetta






	--Items
	[344916] =	CDFlash, --Tuft
	[336126] = 	CDFlash, --PvP trinket
	[42292] = 	CDFlash, --Old PvP trinket
	[6262] = 	CDFlash, --Healthstone
	[177218] = 	CDFlash, --Phial of Serenity

	--Racials
	[7744] = 	CDFlash, --Will of the Forsaken
	[312411] = 	CDFlash, --Bag of Tricks

	--Shadowlands Potions
	[307192] = 	CDFlash, --Health Potion Shadowlands
	[307382] = 	CDFlash, --Phantom Fire Potion
	[307193] = 	CDFlash, --Shadowlands Mana Potion
	[307095] = 	CDFlash, --Shadowlands Sleeper Potion
	[307496] = 	CDFlash, --Divine Awakening Potion
	[307096] = 	CDFlash, --Shadowlands Int Potion
	[307093] = 	CDFlash, --Shadowlands Agi Potion
	[307098] = 	CDFlash, --Shadowlands Str Potion
	[307097] = 	CDFlash, --Shadowlands Stm Potion
	[322301] = 	CDFlash, --Sacrificial Anima Potion
	[307384] = 	CDFlash, --Deathly Fixation Potion
	[307381] = 	CDFlash, --Empowered Exorcisms Potion

	--Other
	[16589] = { duration = 1, tbPrio = -2, isFlash = true, iconID = 8529 }, 	--Noggenfogger
};

CustomBuffs.BUFFS = {
		--Death Knight
        ["Icebound Fortitude"] =        CDStandard,
        ["Anti-Magic Shell"] =          CDStandard,
        ["Vampiric Blood"] =            CDStandard,
        ["Corpse Shield"] =             CDStandard,
        ["Bone Shield"] =               CDStandard,
        ["Dancing Rune Weapon"] =       CDStandard,
        ["Hemostasis"] =                CDStandard,
        ["Rune Tap"] =                  CDStandard,
        ["Lichborne"] =                 CDStandard,
        ["Swarming Mist"] =             CDStandard,

		--Druid
        ["Survival Instincts"] =        CDStandard,
        ["Barkskin"] =                  CDStandard,
        ["Ironfur"] =                   CDStandard,
        ["Frenzied Regeneration"] =     CDStandard,
		["Dash"] =    	 				CDStandard,

		--Hunter
        ["Aspect of the Turtle"] =      CDStandard,
        ["Survival of the Fittest"] =   CDStandard,
		["Double Tap"] =   				CDStandard,
		["Sniper Shot"] =   			CDStandard,


		--Mage
        ["Ice Block"] =                 CDStandard,
        ["Evanesce"] =                  CDStandard,
        ["Greater Invisibility"] =      CDStandard,
        ["Alter Time"] =                CDStandard,
        ["Temporal Shield"] =           CDStandard,
		["Blazing Barrier"] =           CDStandard,
		["Ice Barrier"] =           	CDStandard,
		["Prismatic Barrier"] =         CDStandard,


		--Monk
        ["Zen Meditation"] =            CDStandard,
        ["Diffuse Magic"] =             CDStandard,
        ["Dampen Harm"] =               CDStandard,
        ["Touch of Karma"] =            CDStandard,
        ["Fortifying Brew"] =           CDStandard,

		--Paladin
        ["Divine Shield"] =             CDStandard,
        ["Divine Protection"] =         CDStandard,
        ["Ardent Defender"] =           CDStandard,
        ["Aegis of Light"] =            CDStandard,
        ["Eye for an Eye"] =            CDStandard,
        ["Shield of Vengeance"] =       CDStandard,
        ["Guardian of Ancient Kings"] = CDStandard,
        --["Seraphim"] =                  CDStandard, moved to throughput cds
        ["Guardian of the Fortress"] =  CDStandard,
        ["Shield of the Righteous"] =   CDStandard,

		--Priest
        ["Dispersion"] =                CDStandard,
        ["Fade"] =                      CDStandard,
        ["Greater Fade"] =              CDStandard,
		["Desperate Prayer"] =          CDStandard,
		["Shadowform"] =              	CDStandard,

		--Rogue
        ["Evasion"] =                   CDStandard,
		["Sprint"] =                   	CDStandard,
        ["Cloak of Shadows"] =          CDStandard,
        ["Feint"] =                     CDStandard,
        ["Readiness"] =                 CDStandard,
        ["Riposte"] =                   CDStandard,
        ["Crimson Vial"] =              CDStandard,
		["Shroud of Concealment"] =     CDStandard,


		--Shaman
        ["Astral Shift"] =              CDStandard,
        ["Shamanistic Rage"] =          CDStandard,
		["Water Shield"] =				CDStandard,
		["Lightning Shield"] =			CDStandard,
        ["Harden Skin"] =               CDStandard,
		["Spiritwalker's Grace"] =      CDStandard,

		--Warlock
        ["Unending Resolve"] =          CDStandard,
        ["Dark Pact"] =                 CDStandard,
        ["Nether Ward"] =               CDStandard,
		["Fel Domination"] =            CDStandard,

		--Warrior
        ["Shield Wall"] =               CDStandard,
        ["Spell Reflection"] =          CDStandard,
        ["Shield Block"] =              CDStandard,
        ["Last Stand"] =                CDStandard,
        ["Die By The Sword"] =          CDStandard,
        ["Defensive Stance"] =          CDStandard,
		["Berserker Rage"] =          	CDStandard,
		["Ignore Pain"] =          		CDStandard,

		--Demon Hunter
        ["Netherwalk"] =                CDStandard,
        ["Blur"] =                      CDStandard,
        ["Darkness"] =                  CDStandard,
        ["Demon Spikes"] =              CDStandard,
        ["Soul Fragments"] =            CDStandard,
		["Immolation Aura"] =           CDStandard,
		["Spectral Sight"] =           	CDStandard,



		--Major Externals
	    ["Ironbark"] =                  	EStandard,
	    ["Life Cocoon"] =               	EStandard,
	    ["Blessing of Protection"] =    	EStandard,
	    ["Blessing of Sacrifice"] =     	EStandard,
	    ["Blessing of Spellwarding"] =  	EStandard,
	    ["Pain Suppression"] =          	EStandard,
	    ["Guardian Spirit"] =           	EStandard,
	    ["Roar of Sacrifice"] =         	EStandard,
	    ["Innervate"] =                 	EStandard,
	    ["Cenarion Ward"] =             	EStandard,
	    ["Safeguard"] =                 	EStandard,
	    ["Vigilance"] =                 	EStandard,
	    ["Earth Shield"] =              	EStandard,
	    ["Tiger's Lust"] =              	EStandard,
	    ["Beacon of Virtue"] =          	EStandard,
	    ["Beacon of Faith"] =           	EStandard,
	    ["Beacon of Light"] =           	EStandard,
	    ["Lifebloom"] =                 	EStandard,
	    ["Spirit Mend"] =               	EStandard,
	    ["Misdirection"] =              	EStandard,
	    ["Tricks of the Trade"] =       	EStandard,
	    ["Rallying Cry"] =              	EStandard,
	    ["Anti-Magic Zone"] =           	EStandard,
		["Power Word: Shield"] = 			EStandard,

	    ["Stoneform"] =                 	EStandard,
	    ["Fireblood"] =                 	EStandard,
		["Soulstone"] =                 	EStandard,


	    ["Gladiator's Emblem"] =        	EStandard,

	    --Minor Externals worth tracking
	    ["Enveloping Mist"] =           	EStandard,


	    --Show party/raid member's stealth status in buffs
	    ["Stealth"] =                   	EStandard,
	    ["Vanish"] =                    	EStandard,
	    ["Prowl"] =                     	EStandard,

		["Food"] =              			EStandard,
		["Food & Drink"] =              	EStandard,
	    ["Drink"] =           				EStandard,
		["Refreshment"] =           		EStandard,
		["Invisibility"] =           		EStandard,
		["Invisible"] =           			EStandard,
		["Dimensional Shifter"] =           EStandard,

		["Cultivation"] =               	EPStandard,
	    ["Spring Blossoms"] =           	EPStandard,
	    [290754] =                      	EPStandard, --Lifebloom from early spring honor talent
	    ["Glimmer of Light"] =          	EPStandard,
	    ["Ancestral Vigor"] =           	EPStandard,
	    ["Anti-Magic Zone"] =           	EPStandard,
	    ["Blessing of Sacrifice"] =     	EPStandard,

	    --BFA procs
	    ["Luminous Jellyweed"] =        	EPStandard,
	    ["Costal Surge"] =              	EPStandard,
	    ["Concentrated Mending"] =      	EPStandard,
	    ["Touch of the Voodoo"] =       	EPStandard,
	    ["Egg on Your Face"] =          	EPStandard,
	    ["Coastal Surge"] =             	EPStandard,
	    ["Quickening"] =                	EPStandard,
	    ["Ancient Flame"] =             	EPStandard,
	    ["Grove Tending"] =             	EPStandard,
	    ["Blessed Portents"] =          	EPStandard,

	    [344227] =                      	EStandard, --Consumptive Infusion

	    ["Fleshcraft"] =                	EStandard,
		["Soulshape"] =                		EStandard,

	    ["Stoneform"] =                 	EStandard,
	    ["Fireblood"] =                 	EStandard,

	    ["Gladiator's Emblem"] =        	EStandard,

	    [344388] =                      	EStandard, --Huntsman trinket
	    [344384] =                      	EStandard, --Huntsman trinket target
	    ["Tuft of Smoldering Plumage"] = 	EStandard,
		["Potion of the Hidden Spirit"] = 	EStandard,
		["Nitro Boosts"] = 					EStandard,
		["Goblin Glider"] = 				EStandard,
};


CustomBuffs.THROUGHPUT_BUFFS = {
		--DK
        ["Pillar of Frost"] =                   TCDStandard,
        ["Unholy Frenzy"] =                     TCDStandard,
        ["Empower Rune Weapon"] =               TCDStandard,

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
		["Presence of Mind"] =         			TCDStandard,

    	--Monk
        ["Way of the Crane"] =                  TCDStandard,
        ["Storm, Earth, and Fire"] =            TCDStandard,
        ["Serenity"] =                          TCDStandard,
        ["Thunder Focus Tea"] =                 TCDStandard,

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
        ["Voidform"] =                          TCDStandard,
        ["Surrender to Madness"] =              TCDStandard,
        [109964] =                              TCDStandard, --Spirit Shell
        ["Shadow Covenant"] =                   TCDStandard,
		["Vampiric Embrace"] = 					TCDStandard,

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

		--DH
        ["Metamorphosis"] =                     TCDStandard,
        ["Nemesis"] =                           TCDStandard,
        ["Furious Gaze"] =                      TCDLow,

		["Dark Archangel"] =               		ETCDStandard,
	    ["Power Infusion"] =                	ETCDStandard,
	    ["Blood Fury"] =                    	ETCDStandard,
	    ["Berserking"] =                    	ETCDStandard,
	    ["Skyfury Totem"] =                 	ETCDStandard,

	    --TRINKET STUFF
	    ["Gladiator's Badge"] =             	ETCDNoFallthrough,
	    ["Gladiator's Insignia"] =          	ETCDNoFallthrough,
	    ["Inscrutable Quantum Device"] =    	ETCDNoFallthrough,
	    ["Anima Infusion"] =                	ETCDNoFallthrough,
	    ["Anima Font"] =                    	ETCDNoFallthrough,
	    ["Unbound Changling"] =             	ETCDNoFallthrough,
	    [345805] =                          	ETCDNoFallthrough, --Soulletting Ruby

	    --Other Stuff
	    ["Earthen Wall"] =                  	ETCDPrioNoFallthrough,

	    --Dungeon Stuff

	    --Spires of Ascension
	    ["Bless Weapon"] =                  	ETCDLow,
	    ["Infuse Weapon"] =                 	ETCDLow,
	    ["Imbue Weapon"] =                  	ETCDLow,
};

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
	["Scare Beast"] =           MagicStandard,
	["Hibernate"] =             MagicStandard,
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
	["War Stomp"] =             CCStandard,
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
	["Gouge"] =          		CCStandard,
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


	["Biting Cold"] =                           CCStandard,
    ["Melt Soul"] =                             MagicStandard,

    --------------------
    -- Castle Nathria --
    --------------------
    [324982] =                                  CCStandard,


    --["Vendetta"] =              {["dispelType"] = nil, ["sdPrio"] = 3, ["bdPrio"] = 4},
    --["Counterstrike Totem"] =   {["dispelType"] = nil, ["sdPrio"] = 3, ["bdPrio"] = 4} --Debuff when affected by counterstrike totem
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
		[61295] = 	{ duration = 18, sbPrio = 2 }, 		--Riptide
		[974] = 	{ duration = 600, sbPrio = 2, stacks = 9 }, 	--Earth Shield
		[774] = 	{ duration = 15, sbPrio = 2 }, 		--Rejuv
		[8936] = 	{ duration = 12, sbPrio = 2 }, 		--Regrowth
		[22812] = 	{ duration = 12, sbPrio = 2 }, 		--Barkskin
		[22842] = 	{ duration = 3, sbPrio = 2 }, 		--Frenzied Regen
		[48438] = 	{ duration = 7, sbPrio = 2 }, 		--Wild Growth
		[33763] = 	{ duration = 15, sbPrio = 2 }, 		--Lifebloom
		[108416] = 	{ duration = 20, sbPrio = 1 }, 		--Dark Pact


};
CustomBuffs.testDebuffs = {
		[192090] = 	{ duration = 15, sdPrio = 2, stacks = 3 }, 					--Thrash
		[164812] = 	{ duration = 16, sdPrio = 2, dispelType = "Magic"}, 		--Moonfire
		[188389] = 	{ duration = 16, sdPrio = 2, dispelType = "Magic"}, 		--Flame Shock
		[589] = 	{ duration = 16, sdPrio = 2, dispelType = "Magic"}, 		--Shadow Word: Pain
		[14914] = 	{ duration = 7, sdPrio = 2, dispelType = "Magic"}, 			--Holy Fire
		[980] = 	{ duration = 7, sdPrio = 2, dispelType = "Curse", stacks = 10}, 			--Agony
		[316099] = 	{ duration = 16, sdPrio = 2, dispelType = "Magic"}, 		--UA
		[146739] = 	{ duration = 14, sdPrio = 2, dispelType = "Magic"}, 		--Corruption
		[63106] = 	{ duration = 15, sdPrio = 2, dispelType = "Magic"}, 		--Siphon Life


};

CustomBuffs.testThroughputBuffs = {
		[114052] = 	{ duration = 15, tbPrio = 1 }, 		--Ascendance
		[345228] = 	{ duration = 15, tbPrio = 3 }, 		--PvP Badge
		[33697] = 	{ duration = 15, tbPrio = 2 }, 		--Bloodfury



};

CustomBuffs.testBossDebuffs = {
		[118] = 	{ duration = 8, bdPrio = 2, dispelType = "Magic"}, 			--Polymorph
		[408] = 	{ duration = 6, bdPrio = 1}, 								--Kidney Shot

};
