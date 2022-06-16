local _, addonTable = ...;
local CustomBuffs = addonTable.CustomBuffs;
local LibAceSerializer = LibStub:GetLibrary("AceSerializer-3.0");
--CustomBuffs.areWidgetsLoaded = LibStub:GetLibrary("AceGUISharedMediaWidgets-1.0", true);

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
  if ret then
    return spellID.." :  "..i..link;
  end
  print(spellID, ": ", i, link);
end