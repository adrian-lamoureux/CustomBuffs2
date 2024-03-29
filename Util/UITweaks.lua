--Non Aura junk

local _, addonTable = ...
local CustomBuffs = addonTable.CustomBuffs

--Empty function to replace functions that we want to disable
local function CBFVoid()
    return;
end

--Create a permanently hidden frame to set as the parent of blizzard frames
--we want to hide later
if not MyHiddenFrame then
    MyHiddenFrame = CreateFrame("Frame","MyHiddenFrame");
    MyHiddenFrame:Hide();
end

local BUTTON_SCALE = 0.7;

function CustomBuffs:UITweaks()
    if CustomBuffs.gameVersion == 0 then
        CustomBuffs:UITweaksRetail();
    else
        CustomBuffs:UITweaksClassic();
    end
end


function CustomBuffs:UITweaksClassic()
    if not InCombatLockdown() then

        MainMenuBarLeftEndCap:Hide();
        MainMenuBarRightEndCap:Hide();
        --:SetParent("MyHiddenFrame");
        MainMenuBarTexture1:Hide();
        MainMenuBarTexture2:Hide();
        MainMenuBarTexture3:Hide();
        MainMenuBarTexture0:Hide();
        MainMenuBarMaxLevelBar:Hide();
        MainMenuBarMaxLevelBar:SetParent("MyHiddenFrame");
        MainMenuBarMaxLevelBar.ignoreFramePositionManager = true;

        MainMenuExpBar:ClearAllPoints();
        MainMenuXPBarTexture0:Hide();
        MainMenuXPBarTexture1:Hide();
        MainMenuXPBarTexture2:Hide();
        MainMenuXPBarTexture3:Hide();
        MainMenuExpBar:SetPoint("BOTTOM",UIParent,"BOTTOM",0,0);
        MainMenuExpBar:SetPoint("TOP",UIParent,"BOTTOM",0,8);
        MainMenuExpBar.ignoreFramePositionManager = true;

        MultiBarBottomLeft:ClearAllPoints();
        MultiBarBottomLeft:SetPoint("BOTTOMLEFT", ActionButton1, "TOPLEFT",0,7);
        MultiBarBottomLeft.ignoreFramePositionManager = true;

        MultiBarBottomRightButton1:ClearAllPoints();
        MultiBarBottomRightButton1:SetPoint("LEFT", MultiBarBottomLeftButton12, "RIGHT",12,0);
        MultiBarBottomRightButton1.ignoreFramePositionManager = true;

        MainMenuBar:ClearAllPoints();
        MainMenuBar:SetPoint("BOTTOM",MainMenuExpBar,"TOP",0,0);
        MainMenuBar.ignoreFramePositionManager = true;

    else
        CustomBuffs:RunOnExitCombat(CustomBuffs.UITweaksClassic);
    end
end


function CustomBuffs:UITweaksRetail()

    if not InCombatLockdown() then


        ------- Macro Test Stuff -------
        local hexMac1 = CreateFrame("Button", "hexMac1", UIParent, "SecureActionButtonTemplate");
        hexMac1:SetAttribute("type", "macro");
        hexMac1:SetAttribute("macrotext", "/changeactionbar 2\n/click [mod] ActionButton9; ActionButton10\n/changeactionbar 1\n/click hexMac2");

        local hexMac2 = CreateFrame("Button", "hexMac2", UIParent, "SecureActionButtonTemplate");
        hexMac2:SetAttribute("type", "macro");
        hexMac2:SetAttribute("macrotext", "/stopmacro [@focus,noharm]\n/stopmacro [noexists]\n/targetlasttarget [nomod]\n/stopmacro [exists]\n/target focus");

        local bwonsamdi = CreateFrame("Button", "bwns", UIParent, "SecureActionButtonTemplate");
        bwonsamdi:SetAttribute("type", "macro");
        bwonsamdi:SetAttribute("macrotext", "/stopmacro [noexists]\n/run ID=GetInventoryItemID(\"player\",13);if ID then _,a,b=GetItemCooldown(ID);if not UnitCastingInfo(\"player\") and a==0 and b==1 then PlaySound(122273,true);end end");

        local pathetic = CreateFrame("Button", "sylv", UIParent, "SecureActionButtonTemplate");
        pathetic:SetAttribute("type", "macro");
        pathetic:SetAttribute("macrotext", "/run ID=GetInventoryItemID(\"player\",14);if ID then _,a,b=GetItemCooldown(ID);if not UnitCastingInfo(\"player\") and a==0 and b==1 then PlaySound(17046,true);end end");

        local cds = CreateFrame("Button", "cds", UIParent, "SecureActionButtonTemplate");
        cds:SetAttribute("type", "macro");
        cds:SetAttribute("macrotext", "/click MultiBarRightButton1\n/cast Bloodfury\n/cast Ancestral Call\n/cast Berserking\n/click trink");

        local trinkets = CreateFrame("Button", "trink", UIParent, "SecureActionButtonTemplate");
        trinkets:SetAttribute("type", "macro");
        trinkets:SetAttribute("macrotext", "/use First Sigil\n/use Inscrutable Quantum Device\n/use Soulletting Ruby\n/use Sunblood Amethyst\n/use Cosmic Gladiator's Badge of Ferocity");

        local fireworks = CreateFrame("Button", "fireworks", UIParent, "SecureActionButtonTemplate");
        fireworks:SetAttribute("type", "macro");
        fireworks:SetAttribute("macrotext", "/use Everlasting Horde Firework\n/use Everlasting Alliance Firework\n/use Everlasting Darkmoon Firework\n/use Perpetual Purple Firework");


        local shamcov = CreateFrame("Button", "shmc", UIParent, "SecureActionButtonTemplate");
        shamcov:SetAttribute("type", "macro");
        shamcov:SetAttribute("macrotext", "/cast [@cursor] Vesper Totem\n/cast Chain Harvest\n/cast Primordial Wave\n/cast [@cursor] Fae Transfusion");

        local priestcov = CreateFrame("Button", "prc", UIParent, "SecureActionButtonTemplate");
        priestcov:SetAttribute("type", "macro");
        priestcov:SetAttribute("macrotext", "/cast Boon of the Ascended\n/cast Mindgames\n/cast Unholy Nova\n/cast Fae Guardians");

        --PetActionBar:SetShownOverride(true);
        --PetActionBar:Show();
        --[[ Cov Macros:
        sham:
        #showtooltip
/click [mod] cds
/click shmc
/run local G=GetSpellInfo SetMacroSpell(GetRunningMacro(), G"Vesper Totem" or G"Chain Harvest" or G"Primordial Wave"or G"Fae Transfusion")

        priest:
        #showtooltip
/click [mod] cds
/click prc
/run local G=GetSpellInfo SetMacroSpell(GetRunningMacro(), G"Boon of the Ascended" or G"Mindgames" or G"Unholy Nova"or G"Fae Guardians")

        --]]

        --[[
        --Clean up pet frame
        PetName:SetAlpha(0);
        PetFrameHealthBarTextLeft:SetAlpha(0);
        PetFrameManaBarTextRight:ClearAllPoints();
        PetFrameManaBarTextRight:SetPoint("CENTER","PetFrameManaBar","CENTER",0,-2);
        PetFrameManaBarTextLeft:SetAlpha(0);
        PetFrameHealthBarTextRight:ClearAllPoints();
        PetFrameHealthBarTextRight:SetPoint("CENTER","PetFrameHealthBar","CENTER",0,0);

        --Hide extraactionbutton background
        ExtraActionBarFrame.button.style:SetAlpha(0);
        ZoneAbilityFrame.Style:SetAlpha(0);

        --Hide group number on player frame
        PlayerFrameGroupIndicator.Show = CBFVoid;
        PlayerFrameGroupIndicator:Hide();

        --Move action bars around
        MultiBarBottomLeft:ClearAllPoints();
        MultiBarBottomLeft:SetPoint("BOTTOMLEFT", ActionButton1, "TOPLEFT",0,7);
        MultiBarBottomLeft.ignoreFramePositionManager = true;

        MultiBarBottomRightButton7:ClearAllPoints();
        MultiBarBottomRightButton7:SetPoint("BOTTOMLEFT", MultiBarBottomRightButton1, "TOPLEFT",0,7);
        MultiBarBottomRightButton7.ignoreFramePositionManager = true;

        --Reassign menu buttons to more intuitive parents
        AchievementMicroButton:SetParent(MicroButtonAndBagsBar);
        CharacterMicroButton:SetParent(MicroButtonAndBagsBar);
        CollectionsMicroButton:SetParent(MicroButtonAndBagsBar);
        EJMicroButton:SetParent(MicroButtonAndBagsBar);
        GuildMicroButton:SetParent(MicroButtonAndBagsBar);
        HelpMicroButton:SetParent(MicroButtonAndBagsBar);
        LFDMicroButton:SetParent(MicroButtonAndBagsBar);
        QuestLogMicroButton:SetParent(MicroButtonAndBagsBar);
        SpellbookMicroButton:SetParent(MicroButtonAndBagsBar);
        StoreMicroButton:SetParent(MicroButtonAndBagsBar);
        TalentMicroButton:SetParent(MicroButtonAndBagsBar);
        MainMenuMicroButton:SetParent(MicroButtonAndBagsBar);

        --Scale the row of menu buttons down
        MicroButtonAndBagsBar.MicroBagBar:Hide();
        MicroButtonAndBagsBar:ClearAllPoints();
        MicroButtonAndBagsBar:SetPoint("BOTTOMLEFT",StatusTrackingBarManager,"BOTTOMRIGHT",-5,-23);
        MicroButtonAndBagsBar:SetScale(BUTTON_SCALE);

        MainMenuBarArtFrame.LeftEndCap:Hide();
        MainMenuBarArtFrame.RightEndCap:Hide();
        MainMenuBarArtFrameBackground:Hide();

        StanceBarFrame.ignoreFramePositionManager = true;
        StanceBarFrame:Hide();
        StanceBarFrame:SetParent("MyHiddenFrame");

        --TODO do something smarter with this
        --TargetFramePowerBarAlt.ignoreFramePositionManager = true;
        --TargetFramePowerBarAlt:ClearAllPoints();
        --TargetFramePowerBarAlt:SetPoint("LEFT",StatusTrackingBarManager,"RIGHT",-128,52.5);
        --TargetFramePowerBarAlt:SetParent("MyHiddenFrame");

        --Make sure Blizzard can't reparent the frames
        AchievementMicroButton.SetParent = CBFVoid;
        CharacterMicroButton.SetParent = CBFVoid;
        CollectionsMicroButton.SetParent = CBFVoid;
        EJMicroButton.SetParent = CBFVoid;
        GuildMicroButton.SetParent = CBFVoid;
        HelpMicroButton.SetParent = CBFVoid;
        LFDMicroButton.SetParent = CBFVoid;
        QuestLogMicroButton.SetParent = CBFVoid;
        SpellbookMicroButton.SetParent = CBFVoid;
        StoreMicroButton.SetParent = CBFVoid;
        TalentMicroButton.SetParent = CBFVoid;
        MainMenuMicroButton.SetParent = CBFVoid;
        --]]
    else
        CustomBuffs:RunOnExitCombat(CustomBuffs.UITweaksRetail);
    end

end
