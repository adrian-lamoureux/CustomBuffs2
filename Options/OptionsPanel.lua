local _, addonTable = ...;
local CustomBuffs = addonTable.CustomBuffs;
local LibAceSerializer = LibStub:GetLibrary("AceSerializer-3.0");
CustomBuffs.areWidgetsLoaded = LibStub:GetLibrary("AceGUISharedMediaWidgets-1.0", true);

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
