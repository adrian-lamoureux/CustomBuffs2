--Known bugs:
--issue with taint on show() causing invalid combat show errors sometimes; unsure of cause
--issue with raid frames sometimes losing click interaction functionality maybe because of this addon


local _, addonTable = ...;
local CustomBuffs = addonTable.CustomBuffs;
local LibAceSerializer = LibStub:GetLibrary("AceSerializer-3.0");
CustomBuffs.areWidgetsLoaded = LibStub:GetLibrary("AceGUISharedMediaWidgets-1.0", true);

CustomBuffs.major = 2;
CustomBuffs.mid = 0;
CustomBuffs.minor = 18;
CustomBuffs.version = CustomBuffs.minor + (100 * CustomBuffs.mid) + (10000 * CustomBuffs.major);

if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
	CustomBuffs.gameVersion = 1; --Classic
elseif WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
	CustomBuffs.gameVersion = 2; --BC
else
    CustomBuffs.gameVersion = 0; --Retail
end

_G.CustomBuffs = CustomBuffs;
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
CustomBuffs.partyUnits = CustomBuffs.partyUnits or {};

CustomBuffs.verbose = CustomBuffs.verbose or false;
CustomBuffs.announceSums = CustomBuffs.announceSums or false;
CustomBuffs.announceSpells = CustomBuffs.announceSpells or false;
CustomBuffs.locked = CustomBuffs.locked or true;
CustomBuffs.inRaidGroup = CustomBuffs.inRaidGroup or true;
CustomBuffs.optionsOpen = CustomBuffs.optionsOpen or false;
CustomBuffs.runOnExitCombat = CustomBuffs.runOnExitCombat or {};
CustomBuffs.hasNotified = CustomBuffs.hasNotified or false;


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
CustomBuffs.debugMode = CustomBuffs.debugMode or false;

CustomBuffs.UPDATE_DELAY_TOLERANCE = CustomBuffs.UPDATE_DELAY_TOLERANCE or 0.01;
--CustomBuffs.inRaidGroup = false;

CustomBuffs.debugMode = CustomBuffs.debugMode or false;

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




local NONAURAS = CustomBuffs.NONAURAS;
local INTERRUPTS = CustomBuffs.INTERRUPTS;
local BUFFS = CustomBuffs.BUFFS;
local THROUGHPUT_BUFFS = CustomBuffs.THROUGHPUT_BUFFS;
local CC = CustomBuffs.CC;
local testDebuffs = CustomBuffs.testDebuffs;
local testBuffs = CustomBuffs.testBuffs;
local testThroughputBuffs = CustomBuffs.testThroughputBuffs;
local testBossDebuffs = CustomBuffs.testBossDebuffs;


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
local setCooldownFrame = CooldownFrame_Set;
local clearCooldownFrame = CooldownFrame_Clear;

local UnitGUID = UnitGUID;
local CompactUnitFrame_UpdateAuras = CompactUnitFrame_UpdateAuras;

local dbSize = 1;
local bSize = 1;
local tbSize = 1.2;
local bdSize = 1.5;

local NameCache = {};

--Copies of blizz functions

local CompactUnitFrame_Util_IsPriorityDebuff = CompactUnitFrame_Util_IsPriorityDebuff;
local function isPrioDebuff(...)
    if CustomBuffs.gameVersion == 0 then
        return CompactUnitFrame_Util_IsPriorityDebuff(...);
    else
        return false;
    end
end
local function shouldDisplayDebuff(...)
	local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura, isBossAura = ...;
	local hasCustom, alwaysShowMine, showForMySpec = SpellGetVisibilityInfo(spellId, UnitAffectingCombat("player") and "RAID_INCOMBAT" or "RAID_OUTOFCOMBAT");
	if ( hasCustom ) then
		return showForMySpec or (alwaysShowMine and (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle") );	--Would only be "mine" in the case of something like forbearance.
	else
		return true;
	end
end --= CompactUnitFrame_Util_ShouldDisplayDebuff;
local  function shouldDisplayBuff(...)
	local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura = ...;

	if(CustomBuffs.BuffBlacklist[name] or CustomBuffs.BuffBlacklist[spellId]) then
		return false;
	end

	local hasCustom, alwaysShowMine, showForMySpec = SpellGetVisibilityInfo(spellId, UnitAffectingCombat("player") and "RAID_INCOMBAT" or "RAID_OUTOFCOMBAT");
	if ( hasCustom ) then
		return showForMySpec or (alwaysShowMine and (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle"));
	else
		return (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle") and canApplyAura and not SpellIsSelfBuff(spellId);
	end
end --= CompactUnitFrame_UtilShouldDisplayBuff;


local function ForceUpdateFrame(fNum)
	if CustomBuffs.verbose then
		local name = "";
		if _G["CompactRaidFrame"..fNum].unit then
	    	name = CustomBuffs:CleanName(UnitGUID(_G["CompactRaidFrame"..fNum].unit), _G["CompactRaidFrame"..fNum]);
		end
	    print("Forcing frame update for frame", fNum, "for unit", name);
	end
    CustomBuffs:UpdateAuras(_G["CompactRaidFrame"..fNum]);
end

local function ForceUpdateFrames()
	for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
		if frame and frame.debuffFrames then
			if CustomBuffs.verbose then print("Forcing frame update for frame", frame); end
			frame.auraNeedResize = true;
			CustomBuffs:UpdateAuras(frame);
			--if CustomBuffs.db.profile.useClassColors then
			CompactUnitFrame_UpdateStatusText(frame);
			--end
		end
    end
end

CustomBuffs.trackedSummons = CustomBuffs.trackedSummons or {};
CustomBuffs.trackedOwners = CustomBuffs.trackedOwners or {};
CustomBuffs.petToOwner = CustomBuffs.petToOwner or {};


local function vprint(...)
	if CustomBuffs.verbose then
		local txt = "";
		for _, text in ipairs(...) do
			if text then
				txt = txt..text;
			end
		end
		print(txt);
	end
end


function CustomBuffs:sync()
	print("CustomBuffs2 performing sync...");
	if self.db.global.unknownInterrupts then
		local serialized = LibAceSerializer:Serialize(self.db.global.unknownInterrupts);
		local vers = LibAceSerializer:Serialize(CustomBuffs.version);
		self:SendCommMessage("CBSync", serialized, "GUILD", nil, "BULK");
		self:SendCommMessage("CBSync", serialized, "RAID", 	nil, "BULK");
		self:SendCommMessage("CBSync", serialized, "PARTY", nil, "BULK");
		self:SendCommMessage("CBVers", vers, "GUILD", nil, "BULK");
		self:SendCommMessage("CBVers", vers, "RAID", nil, "BULK");
		self:SendCommMessage("CBVers", vers, "PARTY", nil, "BULK");

	end
end

local function getOwner(pet)
	local owner = pet;
	if CustomBuffs.petToOwner and CustomBuffs.petToOwner[pet] then
		owner = CustomBuffs.petToOwner[pet];
	end
	if CustomBuffs.verbose and pet ~= owner then print("Translated pet", pet, "to owner", owner); end
	return owner;
end

local function addPet(pet, owner)
	local petGUID = UnitGUID(pet);
	local guid = UnitGUID(owner);
	if petGUID then
		if CustomBuffs.verbose then print("Adding pet", petGUID, "for unit", guid); end
		CustomBuffs.petToOwner[petGUID] = guid;
	end
end

local function UpdateUnits()
	if CustomBuffs.verbose then print("Updating unit table..."); end
	CustomBuffs.units = CustomBuffs.units or {};
	CustomBuffs.petToOwner = CustomBuffs.petToOwner or {};
	CustomBuffs.partyUnits = CustomBuffs.partyUnits or {};
	twipe(CustomBuffs.partyUnits);

	addPet("pet","player");
	CustomBuffs.partyUnits[UnitGUID("player")] = true;
	for i = 1, 40 do
		local pet = "raidpet"..i;
		local unit = "raid"..i;
		addPet(pet, unit);
	end
	for i = 1, 4 do
		local pet = "partypet"..i;
		local unit = "party"..i;
		local guid = UnitGUID(unit);
		if guid then
			CustomBuffs.partyUnits[guid] = true;
		end
		addPet(pet, unit);
	end
    for _, table in pairs(CustomBuffs.units) do
        table.invalid = true;
    end
	local numUnits = #CompactRaidFrameContainer.units;
	if numUnits < 2 then numUnits = 40; end
    for i=1, numUnits do
        local frame = _G["CompactRaidFrame"..i];
        if frame and frame.unit then
        	local unit = _G["CompactRaidFrame"..i].unit;
        	local guid = UnitGUID(unit);
        	if guid then
            	if CustomBuffs.verbose then
					local name = CustomBuffs:CleanName(UnitGUID(unit), frame);
					print("Adding unit for frame number", i ,"", name);
				end
            	CustomBuffs.units[guid] = CustomBuffs.units[guid] or {};
            	CustomBuffs.units[guid].invalid = nil;
            	CustomBuffs.units[guid].frameNum = i;
            	CustomBuffs.units[guid].unit = unit;
        	end
		end
    end

    for i, table in pairs(CustomBuffs.units) do
        if table.invalid then
            twipe(CustomBuffs.units[i]);
            CustomBuffs.units[i] = nil;
        end
    end
end

function CustomBuffs:UpdateUnits()
	UpdateUnits();
end

local function addTrackedSummon(casterGUID, spellID, spellName, destGUID, daisyChainOwner)
	local owner = casterGUID;

	if daisyChainOwner then
		if (NONAURAS[spellID] or NONAURAS[spellName]).owner then
			CustomBuffs.trackedOwners[spellID] = {destGUID, casterGUID = casterGUID};
		elseif CustomBuffs.trackedOwners[spellID] and CustomBuffs.trackedOwners[spellID].casterGUID == casterGUID then
			owner = CustomBuffs.trackedOwners[spellID].casterGUID;
		end
	end


	if CustomBuffs.verbose then print("Added summon: ", destGUID, " from owner ", owner); end

	local duration = (NONAURAS[spellID] or NONAURAS[spellName]).duration;
	CustomBuffs.trackedSummons[destGUID] = {owner, spellID = spellID, owner = owner};

	--local _, class = UnitClass(unit)

	if CustomBuffs.verbose then
		local link = GetSpellLink(spellID);
		print("Adding fake aura:", spellID, "/", link);
	end

	CustomBuffs.units[casterGUID].nauras = CustomBuffs.units[casterGUID].nauras or {};
	CustomBuffs.units[casterGUID].nauras[spellID] = CustomBuffs.units[casterGUID].nauras[spellID] or {};
	CustomBuffs.units[casterGUID].nauras[spellID].expires = GetTime() + duration;
	CustomBuffs.units[casterGUID].nauras[spellID].spellID = spellID;
	CustomBuffs.units[casterGUID].nauras[spellID].duration = duration;
	CustomBuffs.units[casterGUID].nauras[spellID].spellName = spellName;
	CustomBuffs.units[casterGUID].nauras[spellID].summon = true;
	CustomBuffs.units[casterGUID].nauras[spellID].trackedUnit = destGUID;

	ForceUpdateFrame(CustomBuffs.units[casterGUID].frameNum);

	-- Make sure we clear it after the duration
	C_Timer.After(duration + CustomBuffs.UPDATE_DELAY_TOLERANCE, function()
		if CustomBuffs.units[casterGUID] and CustomBuffs.units[casterGUID].nauras and CustomBuffs.units[casterGUID].nauras[spellID] then
			CustomBuffs.units[casterGUID].nauras[spellID] = nil;
			ForceUpdateFrame(CustomBuffs.units[casterGUID].frameNum);
		end
	end);

end

local function removeTrackedSummon(summonGUID)
	if CustomBuffs.trackedSummons and CustomBuffs.trackedSummons[summonGUID] and not CustomBuffs.trackedSummons[summonGUID].invalid and CustomBuffs.trackedSummons[summonGUID][1] then
	local ownerGUID = CustomBuffs.trackedSummons[summonGUID][1] or summonGUID;
	if CustomBuffs.verbose then print("Removing dead summon:", summonGUID, "from owner", ownerGUID); end
		if CustomBuffs.trackedSummons[summonGUID] and CustomBuffs.trackedSummons[summonGUID].spellID then
			local spellID = CustomBuffs.trackedSummons[summonGUID].spellID;
			twipe(CustomBuffs.trackedSummons[summonGUID]);
			CustomBuffs.trackedSummons[summonGUID].invalid = true;
			CustomBuffs.trackedSummons[summonGUID] = nil;
			if CustomBuffs.units[ownerGUID] and CustomBuffs.units[ownerGUID].nauras and CustomBuffs.units[ownerGUID].nauras[spellID] then
				CustomBuffs.units[ownerGUID].nauras[spellID] = nil;
			end
			ForceUpdateFrame(CustomBuffs.units[ownerGUID].frameNum);
		end
	end
end

local function checkForSummon(spellID)
	for k, v in pairs(CustomBuffs.trackedSummons) do
		if v and not v.invalid then
			if v.spellID and v.spellID == spellID then return true; end
		end
	end
end

local function handleSummon(spellID, spellName, casterGUID, destGUID)
	if CustomBuffs.announceSums then
		local link = GetSpellLink(spellID);
		print("Summon: ", spellID, " : ", link);
	end
	if ((NONAURAS[spellID] and NONAURAS[spellID].type and NONAURAS[spellID].type == "summon") or (NONAURAS[spellName] and NONAURAS[spellName].type and NONAURAS[spellName].type == "summon" )) then
		casterGUID = getOwner(casterGUID);
		if CustomBuffs.units[casterGUID] then
			--local realID = select(14, CombatLogGetCurrentEventInfo());
			addTrackedSummon(casterGUID, spellID, spellName, destGUID, (NONAURAS[spellID] or NONAURAS[spellName]).chain or false);
		end
	end
end



------- Setup -------
--Helper function to determine if the dispel type of a debuff matches available dispels
local function canDispelDebuff(debuffInfo)
    if not debuffInfo or not debuffInfo.dispelType or not CustomBuffs.dispelValues[debuffInfo.dispelType] then return false; end
    return bit.band(CustomBuffs.dispelType,CustomBuffs.dispelValues[debuffInfo.dispelType]) ~= 0;
end

--sets a flag on every element of CC indicating whether it is currently dispellable
local function precalcCanDispel()
    for _, v in pairs(CC)  do
        v.canDispel = canDispelDebuff(v);
    end
end

--Helper function to manage responses to spec changes
function CustomBuffs:updatePlayerSpec()
    --Check if player can dispel magic (is a healing spec or priest)
    --Technically warlocks can sometimes dispel magic with an imp and demon hunters can dispel
    --magic with a pvp talent, but we ignore these cases
    if not CustomBuffs.playerClass then CustomBuffs.playerClass = select(2, UnitClass("player")); end

	local spec = nil;
    --Make sure we can get spec; if not then try again in 5 seconds
	if CustomBuffs.gameVersion == 0 then --No spec lookup in classic
    	local spec = GetSpecialization();
	end
    if spec then
        local role = select(5, GetSpecializationInfo(GetSpecialization()));
    elseif CustomBuffs.gameVersion == 0 then
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
		--if CustomBuffs.verbose then print("Inside extra aura update block"); end
        if GetNumGroupMembers() <= 5 or not IsInGroup() then
            if CustomBuffs.db.profile.extraDebuffs then
				--if CustomBuffs.verbose then print("Enabling extra debuff frames"); end
                CustomBuffs.MAX_DEBUFFS = 15;
                for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
                    --index 1 is a string for some reason so we skip it
                    if index ~= 1 and frame and frame.debuffFrames then
                        frame.debuffNeedUpdate = true;
                    end
                end
			end
            if CustomBuffs.db.profile.extraBuffs then
				--if CustomBuffs.verbose then print("Enabling extra buff frames"); end
                CustomBuffs.MAX_BUFFS = 15;
                for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
                    --index 1 is a string for some reason so we skip it
                    if index ~= 1 and frame and frame.debuffFrames then
                        frame.buffNeedUpdate = true;
                    end
                end
            end
        else
            if CustomBuffs.db.profile.extraDebuffs then
				--if CustomBuffs.verbose then print("Disabling extra debuff frames"); end
                CustomBuffs.MAX_DEBUFFS = 6;
                for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
                    --index 1 is a string for some reason so we skip it
                    if index ~= 1 and frame and frame.debuffFrames then
                        frame.debuffNeedUpdate = true;
                    end
                end
			end
            if CustomBuffs.db.profile.extraBuffs then
				--if CustomBuffs.verbose then print("Disabling extra buff frames"); end
                CustomBuffs.MAX_BUFFS = 6;
                for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
                    --index 1 is a string for some reason so we skip it
                    if index ~= 1 and frame and frame.debuffFrames then
                        frame.buffNeedUpdate = true;
                    end
                end
            end
        end
	end
        --We only show cast bars in groups of 5 or less, so we still need to update our group
        --size tracker if cast bars are enabled
    if GetNumGroupMembers() <= 5 or not IsInGroup() then
        CustomBuffs.inRaidGroup = false;
    else
        CustomBuffs.inRaidGroup = true;
    end

    --Update table of group members
    UpdateUnits();

	for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
		--index 1 is a string for some reason so we skip it
		if index ~= 1 and frame and frame.debuffFrames then
			frame.auraNeedResize = true;
		end
	end

    --Make sure to update raid icons on frames when we enter or leave a group
    CustomBuffs:UpdateRaidIcons();

    CustomBuffs:UpdateCastBars();
end

function CustomBuffs:HandleRosterUpdate()
	handleRosterUpdate();
end

function CustomBuffs:hideExtraAuraFrames(type)
	if CustomBuffs.verbose then print("hiding extra", type, "frames"); end
	if not type or type == "debuffs" then
		CustomBuffs.MAX_DEBUFFS = 6;
		for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
			--index 1 is a string for some reason so we skip it
			if index ~= 1 and frame and frame.debuffFrames then
				frame.debuffNeedUpdate = true;
			end
		end
	end
	if not type or type == "buffs" then
		CustomBuffs.MAX_BUFFS = 6;
		for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
			--index 1 is a string for some reason so we skip it
			if index ~= 1 and frame and frame.debuffFrames then
				frame.buffNeedUpdate = true;
			end
		end
	end
	ForceUpdateFrames();
end

function CustomBuffs:loadFrames()
	if not InCombatLockdown() then
		if not CompactRaidFrame1 then --Don't spam create new raid frames; causes a huge mess
			CompactRaidFrameManager_OnLoad(CompactRaidFrameManager);
			--CompactRaidFrameManagerDisplayFrameProfileSelector_Initialize();
			CompactRaidFrameContainer_OnLoad(CompactRaidFrameContainer);
			CompactRaidFrameContainer_SetGroupMode(CompactRaidFrameContainer, "flush");
			CompactRaidFrameContainer_SetFlowSortFunction(CompactRaidFrameContainer, CRFSort_Role);
			CompactRaidFrameContainer_AddUnitFrame(CompactRaidFrameContainer, "player", "raid");
		end
		CompactRaidFrameContainer_LayoutFrames(CompactRaidFrameContainer);
		CompactRaidFrameContainer_UpdateDisplayedUnits(CompactRaidFrameContainer);
		CompactRaidFrameManager:Show();
		CompactRaidFrameContainer:Show();
		handleRosterUpdate();
	else
		CustomBuffs:RunOnExitCombat(CustomBuffs.loadFrames);
	end
end

function CustomBuffs:unlockFrames()
	CompactRaidFrameManager_ResizeFrame_Reanchor(CompactRaidFrameManager);
	CompactRaidFrameManager_UpdateContainerBounds(CompactRaidFrameManager);
	if not CustomBuffs.locked then
		CustomBuffs.locked = true;
		if CustomBuffs.verbose then print("locking raid frames"); end
		CompactRaidFrameManager_LockContainer(CompactRaidFrameManager);
	else
		CustomBuffs.locked = false;
		if CustomBuffs.verbose then print("unlocking raid frames"); end
		CompactRaidFrameManager_UnlockContainer(CompactRaidFrameManager);
	end
end


local function handleCastSuccess(casterGUID, spellID, spellName)
	local spellName = spellName;
	if not spellName or spellName == "" then
		spellName, _, _, _, _, _, _ = GetSpellInfo(spellID);
	end
	if CustomBuffs.announceSpells then
		local link = GetSpellLink(spellID);
		print("Spell: ", spellID, " : ", link);
	end
	if NONAURAS[spellID] or NONAURAS[spellName] then
		local record = (NONAURAS[spellID] or NONAURAS[spellName]);
		if (not record.type or record.type ~= "summon") then
			if (CustomBuffs.db.profile.cooldownFlash or not record.isFlash) then
				local noSum = record.noSum;

				if not noSum or not checkForSummon(noSum) then
					casterGUID = getOwner(casterGUID);
					if CustomBuffs.verbose then print("Spell from caster: ", casterGUID); end
					if CustomBuffs.units[casterGUID] then
						--print("Found Cast Success");
						local duration = record.duration;

						if CustomBuffs.verbose then
							local link = GetSpellLink(spellID);
							print("Adding fake aura:", spellID, "/", link);
						end
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
			end
		end
	end
end

function CustomBuffs:BCC_UNIT_SPELLCAST_SUCCEEDED(self, unit, castID, spellID)
	local casterGUID = UnitGUID(unit);
	--if casterGUID then
		if CustomBuffs.verbose then
			local link = GetSpellLink(spellID);
			print("Found UNIT_SPELLCAST_SUCCEEDED event for", casterGUID, spellID, " / ", link);
		end
		handleCastSuccess(casterGUID, spellID, nil);
	--end
end


function CustomBuffs:RunOnExitCombat(func, ...)
	CustomBuffs.runOnExitCombat = CustomBuffs.runOnExitCombat or {};

	tinsert(CustomBuffs.runOnExitCombat, {func = func, args = ...});
end

local function handleExitCombat()
	for i, entry in ipairs(CustomBuffs.runOnExitCombat) do
		if entry.func then
			if entry.args then
				entry.func(entry.args);
			else
				entry.func();
			end
		else
			error("Invalid construct found for RunOnExitCombat");
		end
	end
end
--Check combat log events for interrupts
local function handleCLEU()

    local _, event, _,casterGUID,_,_,_, destGUID, destName,_,_, spellID, spellName = CombatLogGetCurrentEventInfo();
	CustomBuffs.trackedSummons = CustomBuffs.trackedSummons or {};
	wipeTrackedSummon = wipeTrackedSummon or {};

	if (event == "SPELL_CAST_SUCCESS") then
		handleCastSuccess(casterGUID, spellID, spellName);
    end

    -- SPELL_INTERRUPT doesn't fire for some channeled spells; if the spell isn't a known interrupt we're done
    if (event == "SPELL_INTERRUPT" or event == "SPELL_CAST_SUCCESS") then
        if (INTERRUPTS[spellName] or INTERRUPTS[spellID]) then
        --Maybe needed if combat log events are returning spellIDs of 0
        --if spellID == 0 then spellID = lookupIDByName[spellName] end


            if CustomBuffs.units[destGUID] and (event ~= "SPELL_CAST_SUCCESS" or
                (UnitChannelInfo and select(7, UnitChannelInfo(CustomBuffs.units[destGUID].unit)) == false))
            then
                local duration = (INTERRUPTS[spellID] or INTERRUPTS[spellName]).duration;
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
				local link = GetSpellLink(spellID);
                print("Detected unknown interrupt: ", spellID, "/", link);
				--CustomBuffs.db.global.unknownInterrupts = CustomBuffs.db.global.unknownInterrupts or {};

				CustomBuffs.db.global.unknownInterrupts[spellID] = spellName;

                -- Make sure we clear it after the duration
                C_Timer.After(duration + CustomBuffs.UPDATE_DELAY_TOLERANCE, function()
                    CustomBuffs.units[destGUID].int = nil;
                    ForceUpdateFrame(CustomBuffs.units[destGUID].frameNum);
                end);


            end
        end
	elseif (event == "SPELL_INSTAKILL" or event == "UNIT_DIED" or event == "UNIT_DISSIPATES" or event == "UNIT_DESTROYED") then
			--print("unit died");
			removeTrackedSummon(destGUID);
			if (GetNumGroupMembers() > 0) then
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
	elseif (event == "SPELL_SUMMON") then
		handleSummon(spellID, spellName, casterGUID, destGUID);
	end
end


    --[[ Adding tracking for PvP Trinkets here
    if (event == "SPELL_CAST_SUCCESS") and
        (NONAURAS[spellID] or NONAURAS[spellName])
    then

    end
    --]]

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

if CustomBuffs.gameVersion == 0 then
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
else --Not live; manually set all dispels based on class
	if (CustomBuffs.playerClass == "PALADIN") then
    	--Class can dispel poisons and diseases but not curses
    	CustomBuffs.canDispelCurse = false;
    	CustomBuffs.canDispelPoison = true;
    	CustomBuffs.canDispelDisease = true;
		CustomBuffs.canDispelMagic = true;

	elseif (CustomBuffs.playerClass == "MAGE") then
    	--Class can dispel curses but not poisons or diseases
    	CustomBuffs.canDispelCurse = true;
    	CustomBuffs.canDispelPoison = false;
    	CustomBuffs.canDispelDisease = false;
		CustomBuffs.canDispelMagic = false;

	elseif (CustomBuffs.playerClass == "SHAMAN") then

		CustomBuffs.canDispelCurse = false;
    	CustomBuffs.canDispelPoison = true;
    	CustomBuffs.canDispelDisease = true;
		CustomBuffs.canDispelMagic = false;

	elseif CustomBuffs.playerClass == "DRUID" then
    --Class can dispel poisons and curses but not disease
    	CustomBuffs.canDispelCurse = true;
    	CustomBuffs.canDispelPoison = true;
    	CustomBuffs.canDispelDisease = false;
		CustomBuffs.canDispelMagic = false;

	elseif CustomBuffs.playerClass == "PRIEST" then
    	--Class can dispel diseases but not curses or poisons
    	CustomBuffs.canDispelCurse = false;
    	CustomBuffs.canDispelPoison = false;
    	CustomBuffs.canDispelDisease = true;
		CustomBuffs.canDispelMagic = true;

	else --[[(CustomBuffs.playerClass == "DEATHKNIGHT") or (CustomBuffs.playerClass == "HUNTER") or (CustomBuffs.playerClass == "ROGUE") or
    	(CustomBuffs.playerClass == "DEMONHUNTER") or (CustomBuffs.playerClass == "WARRIOR") or (CustomBuffs.playerClass == "WARLOCK") then ]]

    	--Either class was not recognized or class cannot dispel curse, poison or disease
    	CustomBuffs.canDispelCurse = false;
    	CustomBuffs.canDispelPoison = false;
    	CustomBuffs.canDispelDisease = false;
		CustomBuffs.canDispelMagic = false;
	end
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
		handleExitCombat();
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
if CustomBuffs.gameVersion == 0 then
    CustomBuffs.CustomBuffsFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
end
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
        --frame.debuffsLoaded = true;
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

    local size = calcBuffSize(frame) * (tbSize or 1.2) * 1.1;

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

	--[[
	if CustomBuffs.verbose and debuffType then
		local link = GetSpellLink(spellID);
		print("Added spell:",link, "dispelType:", debuffType);
	end
	--]]

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

    if ((expirationTime and expirationTime ~= 0) or (auraData and auraData.summon and auraData.trackedSummon and not CustomBuffs.trackedSummons[auraData.trackedSummon])) then
        local startTime = expirationTime - duration;
        setCooldownFrame(auraFrame.cooldown, startTime, duration, true);
		--auraFrame.cooldown:SetAlpha(0.4);
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

local function debugAuras()
	CustomBuffs.debugMode = not CustomBuffs.debugMode;
	if CustomBuffs.verbose then print("CustomBuffs aura display mode", CustomBuffs.debugMode and "enabled" or "disabled"); end
	handleRosterUpdate();
	ForceUpdateFrames();
end

local function contains(spellID, table)
	for id, data in ipairs(table) do
		if data.auraData[6] == spellID then
			return true;
		end
	end
end

function CustomBuffs:debugAuras()
	debugAuras();
end


function CustomBuffs:UpdateAuras(frame)
    if (not frame or not frame.displayedUnit or frame:IsForbidden() or not frame:IsShown() or not frame.debuffFrames or not frame:GetName():match("^Compact") or not frame.optionTable or not frame.optionTable.displayNonBossDebuffs) then return; end

    --Handle pre calculation logic
    if frame.optionTable.displayBuffs then frame.optionTable.displayBuffs = false; end                          --Tell buff frames to skip blizzard logic
    if frame.optionTable.displayDebuffs then frame.optionTable.displayDebuffs = false; end                      --Tell debuff frames to skip blizzard logic
    if frame.optionTable.displayDispelDebuffs then frame.optionTable.displayDispelDebuffs = false; end          --Prevent blizzard frames from showing dispel debuff frames
    if frame.optionTable.displayNameWhenSelected then frame.optionTable.displayNameWhenSelected = false; end    --Don't show names when the frame is selected to prevent bossDebuff overlap

    if frame.auraNeedResize or not frame.debuffFrames[CustomBuffs.MAX_DEBUFFS] or not frame.buffFrames[CustomBuffs.MAX_BUFFS] or not frame.bossDebuffs or not frame.throughputFrames then
        setUpExtraDebuffFrames(frame);
        setUpExtraBuffFrames(frame);
        setUpThroughputFrames(frame);
        setUpBossDebuffFrames(frame);
        frame.auraNeedResize = false;
    end

    --If our custom aura frames have not yet loaded do nothing
    if --[[not frame.debuffsLoaded or]] not frame.bossDebuffs or not frame.throughputFrames then return; end

    if frame.debuffNeedUpdate then
        setUpExtraDebuffFrames(frame);
    end
    if frame.buffNeedUpdate then
        setUpExtraBuffFrames(frame);
    end

    --Check for interrupts
    local guid = UnitGUID(frame.displayedUnit);
	if CustomBuffs.debugMode then
		if CustomBuffs.verbose then print("Adding fake test auras; Max Buffs:", CustomBuffs.MAX_BUFFS, "Max Debuffs:", CustomBuffs.MAX_DEBUFFS); end
		if #buffs < CustomBuffs.MAX_BUFFS then
			for k, data in pairs(testBuffs) do
				if not contains(k, buffs) then
					tinsert(buffs, { index = -1, sbPrio = data.sbPrio, auraData = {
						--{icon, count, expirationTime, duration}
						GetSpellTexture(k),
						data.stacks or 1,
						GetTime() + data.duration,
						data.duration,
						nil,                             --no dispel type
						k,                    --Need a special field containing the spellID
						summon = data.summon or false,
						trackedUnit = data.trackedUnit or nil,
					}});
				end
			end
		end
		if #debuffs < CustomBuffs.MAX_DEBUFFS then
			for k, data in pairs(testDebuffs) do
				if not contains(k, debuffs) then
					tinsert(debuffs, { index = -1, sdPrio = data.sdPrio, auraData = {
						--{icon, count, expirationTime, duration}
						GetSpellTexture(k),
						data.stacks or 1,
						GetTime() + data.duration,
						data.duration,
						data.dispelType,
						k,                    --Need a special field containing the spellID
						summon = data.summon or false,
						trackedUnit = data.trackedUnit or nil,
					}});
				end
			end
		end
		if #throughputBuffs < 2 then
			for k, data in pairs(testThroughputBuffs) do
				if not contains(k, throughputBuffs) then
					tinsert(throughputBuffs, { index = -1, tbPrio = data.tbPrio, auraData = {
						--{icon, count, expirationTime, duration}
						GetSpellTexture(k),
						data.stacks or 1,
						GetTime() + data.duration,
						data.duration,
						data.dispelType,
						k,                    --Need a special field containing the spellID
						summon = data.summon or false,
						trackedUnit = data.trackedUnit or nil,
					}});
				end
			end
		end
		if #bossDebuffs < 2 then
			for k, data in pairs(testBossDebuffs) do
				if not contains(k, bossDebuffs) then
					tinsert(bossDebuffs, { index = -1, bdPrio = data.bdPrio, auraData = {
						--{icon, count, expirationTime, duration}
						GetSpellTexture(k),
						data.stacks or 1,
						GetTime() + data.duration,
						data.duration,
						data.dispelType,
						k,                    --Need a special field containing the spellID
						summon = data.summon or false,
						trackedUnit = data.trackedUnit or nil,
					}});
				end
			end
		end
		C_Timer.After(3 + CustomBuffs.UPDATE_DELAY_TOLERANCE, function()
			ForceUpdateFrame(CustomBuffs.units[guid].frameNum);
		end);
	end
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
				local prioData = nil;
				if (NONAURAS[data.spellID] or NONAURAS[data.spellName]) then
					prioData = (NONAURAS[data.spellID] or NONAURAS[data.spellName]);
				end
				if prioData then
					local texture = nil;
					if prioData.iconID then
						_, _, _, _, _, _, _, _, _, texture, _ = GetItemInfo(prioData.iconID);
					else
						texture = GetSpellTexture(id);
					end

					if prioData.tbPrio ~= 0 then
					--if prioData and prioData.tbPrio then print(prioData.tbPrio); end
                		tinsert(throughputBuffs, { index = -1, tbPrio = prioData.tbPrio or 7, sbPrio = prioData.sbPrio or nil, auraData = {
                    		--{icon, count, expirationTime, duration}
                    		texture,
                    		1,
                    		data.expires,
                    		data.duration,
                    		nil,                             --no dispel type
                    		data.spellID,                    --Need a special field containing the spellID
							summon = data.summon or false,
							trackedUnit = data.trackedUnit or nil,
                		}});
            		elseif prioData.tbPrio == 0 and prioData.sbPrio then
						tinsert(buffs, { index = -1, sbPrio = prioData.sbPrio, auraData = {
                    		--{icon, count, expirationTime, duration}
                    		texture,
                    		1,
                    		data.expires,
                    		data.duration,
                    		nil,                             --no dispel type
                    		data.spellID,                    --Need a special field containing the spellID
							summon = data.summon or false,
							trackedUnit = data.trackedUnit or nil,
                		}});
					end
				end
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
            elseif (CC[name] or CC[spellID]) then
                --Add to bossDebuffs; adjust priority if dispellable
                local auraData = CC[name] or CC[spellID];
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
        --local _, _, displayedClass = UnitClass(frame.displayedUnit);
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
            elseif (THROUGHPUT_BUFFS[name] or THROUGHPUT_BUFFS[spellID]) then
                --Add to throughputBuffs
                local auraData = THROUGHPUT_BUFFS[name] or THROUGHPUT_BUFFS[spellID];
                tinsert(throughputBuffs, {
                    ["index"] = index,
                    ["tbPrio"] = auraData.tbPrio;
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif (BUFFS[name] or BUFFS[spellID]) then
                --Add to buffs
                local auraData = BUFFS[name] or BUFFS[spellID];
				if CustomBuffs.verbose then print(unitCaster); end
				if not auraData.player or unitCaster == "player" then
                	tinsert(buffs, {
                    	["index"] = index,
                    	["sbPrio"] = auraData.sbPrio,
                    	["auraData"] = {icon, count, expirationTime, duration}
                	});
				end
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
	if #bossDebuffs > 1 then
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
	end

    --Sort throughputBuffs in priority order
	if #throughputBuffs > 1 then
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
	end

    --Sort debuffs in priority order
	if #debuffs > 1 then
    	tsort(debuffs, function(a,b)
        	if not a or not b then return true; end
        	return a.sdPrio < b.sdPrio;
    	end);
	end

    --Sort buffs in priority order
	if #buffs > 1 then
    	tsort(buffs, function(a,b)
        	if not a or not b then return true; end
        	return a.sbPrio < b.sbPrio;
    	end);
	end

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
    for i = math.min(#debuffs + 1, frame.maxDebuffs + 1), 15 do
        local auraFrame = frame.debuffFrames[i];
        --if auraFrame ~= frame.bossDebuffs[1] and auraFrame ~= frame.bossDebuffs[2] then auraFrame:Hide(); end
		if auraFrame then
			auraFrame:Hide();
		end
    end

    for i = #bossDebuffs + 1, 2 do
        frame.bossDebuffs[i]:Hide();
    end

    for i = math.min(#buffs + 1, frame.maxBuffs + 1), 15 do
        local auraFrame = frame.buffFrames[i];
        --if auraFrame ~= frame.throughputFrames[1] and auraFrame ~= frame.throughputFrames[2] then auraFrame:Hide(); end
		if auraFrame then
			auraFrame:Hide();
		end
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
        --if self.db.profile.cleanNames then
        CustomBuffs:SetName(frame);
        --end
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
		if self.db.profile.cleanNames then
            frame.name:SetText(name);
        end
		local guid = UnitGUID(frame.unit);
		local r, g, b = 1, 1, 1;
		if self.db.profile.useClassColors then
			_, className, _ = UnitClass(frame.unit);
			r, g, b, _ = GetClassColor(className);
		end
		if not (CustomBuffs.inRaidGroup and self.db.profile.colorNames and CustomBuffs.partyUnits[guid]) then
			--if CustomBuffs.verbose then print("Changing color for unit",guid,r,g,b); end
			frame.name:SetFont(self.SM:Fetch('font', self.db.profile.nameFont), self.db.profile.nameSize, "OUTLINE");
			frame.name:SetShadowColor(r * 0.5, g * 0.5, b * 0.5, 0.5);
			frame.name:SetShadowOffset(1, -1);
			frame.name:SetTextColor(r, g, b, 1);
			--frame.name:SetTextColor(0, 0, 0, 1);
		else
			frame.name:SetFont(self.SM:Fetch('font', self.db.profile.nameFont), self.db.profile.nameSize + 1--[[, "OUTLINE"]]);
			frame.name:SetShadowColor(0.5, 0.5, 0.5, 0.8);
			frame.name:SetShadowOffset(1, -1);
			frame.name:SetTextColor(0, 0, 0, 1);
		end
end--);
--]]

function CustomBuffs:SetStatusText(frame)
	if (not frame or not frame.displayedUnit or frame:IsForbidden() or not frame:IsShown() or not frame.debuffFrames or not frame:GetName():match("^Compact") or not frame.optionTable or not frame.optionTable.displayNonBossDebuffs) then return; end
	local statusText = frame.statusText;
	if CustomBuffs.verbose then print("Inside SetStatusText",statusText,statusText:IsShown()); end
	if statusText and statusText:IsShown() then
		if self.db.profile.useClassColors then
			if CustomBuffs.verbose then print("Setting Status Text to class colors"); end
			local _, className, _ = UnitClass(frame.unit);
			local r, g, b, _ = GetClassColor(className);
			statusText:SetShadowColor(0, 0, 0, 0.5);
			statusText:SetShadowOffset(1, -1);
			statusText:SetTextColor(r, g, b, 1);
		else
			if CustomBuffs.verbose then print("Setting Status Text to default colors"); end
			statusText:SetShadowColor(0, 0, 0, 0.5);
			statusText:SetShadowOffset(1, -1);
			statusText:SetTextColor(0.5, 0.5, 0.5, 1);
		end
	end
end



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

	--Cannot show cast bars if we have keep groups together enabled, so force that setting off
	CompactRaidFrameContainer_SetGroupMode(CompactRaidFrameContainer, "flush");
	CompactRaidFrameContainer_SetFlowSortFunction(CompactRaidFrameContainer, CRFSort_Role);

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












function CustomBuffs:OnCommReceived(prefix, message, distribution, sender)
	local success, deserialized = LibAceSerializer:Deserialize(message);
	if success then
		if self.db.global.unknownInterrupts and deserialized then
			for k, v in pairs(deserialized) do
				spellName, _, _, _, _, _, _ = GetSpellInfo(spellID);
				if not (INTERRUPTS[k] or INTERRUPTS[spellName]) then
					local link = GetSpellLink(k);
					self.db.global.unknownInterrupts[k] = v or nil;
					print(k, ": ", link);
				end
			end
		end
	end
end

function oldVersion()
	local inInstance, instanceType = IsInInstance();
	if not CustomBuffs.hasNotified and not inInstance then
		print("Your version of CustomBuffs2 is out of date, please update");
		StaticPopupDialogs["CustomBuffsUpdatePopup"] = {
			  text = "Your version of CustomBuffs2 is out of date, please update",
			  button1 = "OK",
			  --button2 = "No",
			  OnAccept = function()
			  end,
			  timeout = 0,
			  whileDead = true,
			  hideOnEscape = true,
			  preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
		};
		StaticPopup_Show("CustomBuffsUpdatePopup");
		CustomBuffs.hasNotified = true;
	end
end

function CustomBuffs:VersCheck(prefix, message, distribution, sender)
	local success, deserialized = LibAceSerializer:Deserialize(message);
	if success then
		if deserialized and CustomBuffs.version then
			if deserialized > CustomBuffs.version then
				oldVersion();
			end
		end
	end
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

function CustomBuffs:loaded()
	--if not InCombatLockdown() then
		self:UpdateConfig();
		CustomBuffs:sync();
	--end

end

function createOptionsTab(self, container)
	local tab1 = self.gui:Create("Label");
	tab1:SetFullWidth(true);
	self.dialog:Open("CustomBuffs", container);
	container:AddChild(tab1);
end

function createProfilesTab(self, container)
	local tab2 = self.gui:Create("Label");
	self.dialog:Open("CustomBuffs Profiles", container);
	tab2:SetFullWidth(true);
	container:AddChild(tab2);
end

function CustomBuffs:OpenOptions()
	if not CustomBuffs.optionsOpen then
		CustomBuffs.optionsOpen = true;
		local frame = self.gui:Create("Window");
		frame:SetLayout("Fill");
		frame:SetWidth(670);
		frame:SetTitle("CustomBuffs2 Options");
		frame:SetCallback("OnClose", function(widget)
			self.gui:Release(widget);
			CustomBuffs.optionsOpen = false;
		end);

		local tab =  self.gui:Create("TabGroup");
		tab:SetLayout("Flow");
		tab:SetCallback("OnGroupSelected", function(container, event, group)
			--if CustomBuffs.verbose then print(container); end
			container:ReleaseChildren();
   			if group == "tab1" then
      			createOptionsTab(self, container);
   			elseif group == "tab2" then
      			createProfilesTab(self, container);
   			end
		end);

		tab:SetTabs({{text="Options", value="tab1"}, {text="Profiles", value="tab2"}});
		tab:SelectTab("tab1");
		tab:SetFullWidth(true);

		frame:AddChild(tab);
		-- Add the frame as a global variable under the name `CustomBuffsOptionsFrame`
	    _G["CustomBuffsOptionsFrame"] = frame;
 	    -- Register the global variable `CustomBuffsOptionsFrame` as a "special frame"
	    -- so that it is closed when the escape key is pressed.
	    tinsert(UISpecialFrames, "CustomBuffsOptionsFrame");
	end
end

function CustomBuffs:OnEnable()
	self:SecureHook("CompactUnitFrame_UpdateAuras", function(frame) self:UpdateAuras(frame); end);
	self:RegisterComm("CBSync", "OnCommReceived");
	self:RegisterComm("CBVers", "VersCheck");



	--Workaround for some items not firing combat log events when activated on BCC
	if CustomBuffs.gameVersion ~= 0 then
		self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "BCC_UNIT_SPELLCAST_SUCCEEDED");
	end

	self:loaded();

    -- Hook raid icon updates
	self:RegisterBucketEvent({"RAID_TARGET_UPDATE", "RAID_ROSTER_UPDATE"}, 0.1, "UpdateRaidIcons");

	self:RegisterChatCommand("cb",function(options)
        options = string.lower(options);

        if options == "" then
		    --InterfaceOptionsFrame_OpenToCategory("CustomBuffs");
		    --InterfaceOptionsFrame_OpenToCategory("CustomBuffs");
			CustomBuffs:OpenOptions();
        elseif options == "weekly" and CustomBuffs.gameVersion == 0 then
            LoadAddOn("Blizzard_WeeklyRewards");
            WeeklyRewardsFrame:Show();
        elseif options == "test" then
			CustomBuffs:loadFrames();
			debugAuras();
		elseif options == "test old version" then
			oldVersion();
		elseif options == "show" then
			CustomBuffs:loadFrames();
		elseif options == "lock" then
			CustomBuffs:unlockFrames();
		elseif options == "sync" then
			CustomBuffs:sync();
		elseif options == "ints" then
			print("Printing all unknown interrupts...");
			if self.db.global.unknownInterrupts then
				for k, v in pairs(self.db.global.unknownInterrupts) do
					spellName, _, _, _, _, _, _ = GetSpellInfo(spellID);
					if not (INTERRUPTS[k] or INTERRUPTS[spellName]) then
						local link = GetSpellLink(k);
						print(k, ": ", link);
					else
						self.db.global.unknownInterrupts[k] = nil;
					end
				end
			end
		elseif options == "units" then
			print("Printing Current Units...")
			if CustomBuffs.units then
				for k, v in pairs(CustomBuffs.units) do

					print(k);
				end
			end
		elseif options == "verbose" then
			CustomBuffs.verbose = not CustomBuffs.verbose;
			print("CustomBuffs verbose mode", CustomBuffs.verbose and "enabled" or "disabled");
		elseif options == "recover" then
			print("Attempting to recover from broken state.");
			UpdateUnits();
			ForceUpdateFrames();
		elseif options == "announce" then
			if CustomBuffs.announceSums and CustomBuffs.announceSpells then
				CustomBuffs.announceSums = false;
				CustomBuffs.announceSpells = false;
			elseif not CustomBuffs.announceSums and not CustomBuffs.announceSpells then
				CustomBuffs.announceSums = true;
				CustomBuffs.announceSpells = true;
			end
			print("CustomBuffs announce spells", CustomBuffs.announceSpells and "enabled" or "disabled");
			print("CustomBuffs announce summons", CustomBuffs.announceSums and "enabled" or "disabled");
		elseif options == "announce sums" then
			CustomBuffs.announceSums = not CustomBuffs.announceSums;
			print("CustomBuffs announce summons", CustomBuffs.announceSums and "enabled" or "disabled");
		elseif options == "announce spells" then
			CustomBuffs.announceSpells = not CustomBuffs.announceSpells;
			print("CustomBuffs announce spells", CustomBuffs.announceSpells and "enabled" or "disabled");
		elseif options == "test sums" then
			print("Printing CustomBuffs.trackedSummons table...");
			for k, v in pairs(CustomBuffs.trackedSummons) do
				if v and not v.invalid then
					print(k, ": ", v[1], " from spell", v.spellID);
				end
			end
		elseif options == "test ints" then
			print("setting test value")
			if self.db.global.unknownInterrupts then
				self.db.global.unknownInterrupts[00002] = "fake";
			end
		elseif options == "wipe ints" then
			self.db.global.unknownInterrupts = {};
        end
    end);

	self:RegisterEvent("UNIT_PET", "UpdateUnits");
	if not self:IsHooked("CompactUnitFrame_UpdateName", function(frame) self:SetName(frame); end) then
		self:SecureHook("CompactUnitFrame_UpdateName", function(frame) self:SetName(frame); end);
	end

    handleRosterUpdate();
	self:UpdateConfig();
end

function CustomBuffs:CreateOptions()
	local defaults = self:Defaults();

	-- Create database object
	self.db = LibStub("AceDB-3.0"):New("CustomBuffsData", defaults);

	local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db);

    local generalOptions = self:CreateGeneralOptions();

    self.config = LibStub("AceConfigRegistry-3.0");
	self.config:RegisterOptionsTable("CustomBuffs", generalOptions);
    self.config:RegisterOptionsTable("CustomBuffs Profiles", profiles)

    self.dialog = LibStub("AceConfigDialog-3.0");
	self.dialog:AddToBlizOptions("CustomBuffs", "CustomBuffs");
    self.dialog:AddToBlizOptions("CustomBuffs Profiles", "Profiles", "CustomBuffs");

end

function CustomBuffs:Init()
    -- Set up database defaults
	self.gui = LibStub("AceGUI-3.0");
	self.SM = LibStub("LibSharedMedia-3.0");
	CustomBuffs:CreateOptions();

	if self.db.profile.alwaysShowFrames then
		CustomBuffs:loadFrames();
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "loadFrames");
		self:RegisterEvent("GROUP_ROSTER_UPDATE", "loadFrames");
	end

	self:RegisterEvent("GROUP_JOINED", "sync");
	self:SecureHook("CompactUnitFrameProfiles_CheckAutoActivation", function(frame) self:loadFrames(); end);
	self:SecureHook("CompactUnitFrameProfilesNewProfileDialogBaseProfileSelectorButton_OnClick", function(frame) self:loadFrames(); end);
	self:SecureHook("CompactUnitFrameProfiles_ActivateRaidProfile", function(frame) self:loadFrames(); end);
	self:SecureHook("CompactUnitFrameProfiles_ApplyCurrentSettings", function(frame) self:loadFrames(); end);
	self:SecureHook("CompactUnitFrameProfiles_UpdateCurrentPanel", function(frame) self:loadFrames(); end);
	self:SecureHook("SetActiveRaidProfile", function(frame) self:loadFrames(); end);
	self:SecureHook("CompactUnitFrameProfilesDropdownButton_OnClick", function(frame) self:loadFrames(); end);

end

function CustomBuffs:SetRaidFrameAlpha()
	CompactRaidFrameContainer:SetAlpha(self.db.profile.frameAlpha);

	for index, frame in ipairs(_G.CompactRaidFrameContainer.flowFrames) do
		--index 1 is a string for some reason so we skip it
		if index ~= 1 and frame and frame.background then
			frame.background:SetAlpha(self.db.profile.frameAlpha);
		end
	end
end

function CustomBuffs:UpdateConfig()
    if not InCombatLockdown() then
		CompactRaidFrameContainer:SetScale(self.db.profile.frameScale);
	else
		CustomBuffs:RunOnExitCombat(CompactRaidFrameContainer.SetScale, self.db.profile.frameScale);
	end
	CustomBuffs:SetRaidFrameAlpha();

    if self.db.profile.loadTweaks then
        self:UITweaks();
    end

    if not self:IsHooked("CompactUnitFrame_UpdateName", function(frame) self:SetName(frame); end) then
        self:SecureHook("CompactUnitFrame_UpdateName", function(frame) self:SetName(frame); end);
    end
	if not self:IsHooked("CompactUnitFrame_UpdateStatusText", function(frame) self:SetStatusText(frame); end) then
		self:SecureHook("CompactUnitFrame_UpdateStatusText", function(frame) self:SetStatusText(frame); end);
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


	if self.db.profile.alwaysShowFrames then
		CustomBuffs:loadFrames();
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "loadFrames");
		self:RegisterEvent("GROUP_ROSTER_UPDATE", "loadFrames");
	end


    self:UpdateRaidIcons();

    handleRosterUpdate();

	ForceUpdateFrames();

    --Clear cached names in case updated settings change displayed names
    twipe(NameCache);
end
