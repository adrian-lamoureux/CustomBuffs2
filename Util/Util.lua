local _, addonTable = ...;
local CustomBuffs = addonTable.CustomBuffs;
local LibAceSerializer = LibStub:GetLibrary("AceSerializer-3.0");
--CustomBuffs.areWidgetsLoaded = LibStub:GetLibrary("AceGUISharedMediaWidgets-1.0", true);

if select(4, GetBuildInfo()) >= 100000 then
	CustomBuffs.isDF = 1;
end


local function backoffHelper(attempts, timer, func, ...)
	if attempts < 10 then
		--if the function returns true it succeeded and we're done
		if ... then
			if func(...) then
				return;
			end
		else
			if func() then
				return;
			end
		end
		--if the function did not return true then we try again
		C_Timer.After(timer * 2, backoffHelper(attempts + 1, timer, func, ...));
	end
end

function CustomBuffs:returnTrue(...)
	return true;
end

if CustomBuffs.isDF then
--Bandaid fixes for many addons on prepatch
	function GetContainerNumSlots(id)
		return ContainerFrame_GetContainerNumSlots(id);
	end

	function GetContainerNumFreeSlots(id)
		return C_Container.GetContainerNumFreeSlots(id);
	end

	function GetContainerItemInfo(id, slot)
		return C_Container.GetContainerItemInfo(id, slot);
	end

	function ContainerIDToInventoryID(id)
		return C_Container.ContainerIDToInventoryID(id);
	end

	function IsBattlePayItem(bag, slot)
		return C_Container.IsBattlePayItem(bag, slot);
	end

	function GetContainerItemQuestInfo(bag, slot)
		return C_Container.GetContainerItemQuestInfo(bag, slot);
	end
end

--Function must return status of function on completion (success/failure);
--Keeps attempting to execute the function until it returns true or it
--fails 10 times
function CustomBuffs:BackoffRunIn(timer, func, ...)
	if type(func) ~= "function" then
			error(("Usage: CustomBuffs:BackoffRunIn(timer, func, ...): 'func' - function expected, got '%s'."):format(type(func)), 2);
	elseif type(timer) ~= "number" then
						error(("Usage: CustomBuffs:BackoffRunIn(timer, func, ...): 'timer' - number expected, got '%s'."):format(type(timer)), 2);
	elseif timer < 1 then
			error(("Usage: CustomBuffs:BackoffRunIn(timer, func, ...): 'timer' - initial timer must be a number >= 1, got '%s'"):format(timer), 2);
	else
			--divide by two so the first time it runs after the input amount of time since we multiply by 2 every time
			backoffHelper(0, timer / 2, func, ...);
	end
end

function CustomBuffs:RunOnExitCombat(func, ...)
	CustomBuffs.runOnExitCombat = CustomBuffs.runOnExitCombat or {};

	if type(func) ~= "function" then
			error(("Usage: CustomBuffs:RunOnExitCombat(func, ...): 'func' - function expected, got '%s'."):format(type(func)), 2);
	else
		tinsert(CustomBuffs.runOnExitCombat, {func = func, args = ...});
	end
end

--returns CB game version id, name of expansion string
function CustomBuffs:GetGameVersion()
  return CustomBuffs.gameVersion, CustomBuffs.GAME_VERSION[CustomBuffs.gameVersion];
end

--Technically returns true for any type of arena or battleground regardless of rated
--TODO: figure out how to determine if a bg is normal or rated
function CustomBuffs:InRatedPVP()
  local inst, type = IsInInstance();
  return inst and type == "arena" or type == "pvp";
end

function CustomBuffs:InDungOrRaid()
  local inst, type = IsInInstance();
  return inst and type == "party" or type == "raid";
end

function CustomBuffs:CheckAndHideNameplates()
	if CustomBuffs.gameVersion == 0 then
		if CustomBuffs:InDungOrRaid() then
			SetCVar("nameplateShowFriends", 0);
			SetCVar("nameplateShowFriendlyNPCs", 0);
		else
			--SetCVar("nameplateShowFriends", 1);
			--SetCVar("nameplateShowFriendlyNPCs", 1);
		end
	end
end

function CustomBuffs:Split(str, delim)
        if not delim then delim = "%s"; end
        local ret = {};

        for i in string.gmatch(str, "([^"..delim.."]+)") do
                table.insert(ret, i);
        end

        return ret;
end

function CustomBuffs:PrintSpell(spellID, ret)
  --Verify input
  if type(spellID) == "string" then
    spellID = tonumber(spellID);
  end
  if type(spellID) ~= "number" then
    error(("Usage: CustomBuffs:PrintSpell(spellID, ret): 'spellID' - number expected, got '%s'."):format(type(spellID)), 2);
  end

  local link = GetSpellLink(spellID);
  local _, _, icon = GetSpellInfo(spellID);
  local i = "";
  if icon then
    i = "|T"..icon..":0|t";
  end
	local r = spellID.." : "..i..link;
	if icon then
		r = r.." Icon: "..icon;
	end
  if ret then
    return r;
  end
  print(r);
end

function CustomBuffs:PrintItem(itemID, ret)
  --Verify input
  if type(itemID) == "string" then
    spellID = tonumber(itemID);
  end
  if type(itemID) ~= "number" then
    error(("Usage: CustomBuffs:PrintItem(itemID, ret): 'itemID' - number expected, got '%s'."):format(type(spellID)), 2);
  end

  local link = select(2, GetItemInfo((itemID)));
  local icon = select(10, GetItemInfo(itemID));
  local i = "";
  if icon then
    i = "|T"..icon..":0|t";
  end
  if ret then
    return itemID.." :  "..i..link;
  end
  print(itemID, ": ", i, link);
end
