--Non Aura junk

local _, addonTable = ...
local CustomBuffs = addonTable.CustomBuffs

--Empty function to replace functions that we want to disable
local function CBFVoid()
    return;
end

local BUTTON_SCALE = 0.7;

function CustomBuffs:UITweaks()
--Create a permanently hidden frame to set as the parent of blizzard frames
--we want to hide later
if not MyHiddenFrame then
    MyHiddenFrame = CreateFrame("Frame","MyHiddenFrame");
    MyHiddenFrame:Hide();
end

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


local toy1 = CreateFrame("Button", "toy1", UIParent, "SecureActionButtonTemplate");
toy1:SetAttribute("type", "macro");
toy1:SetAttribute("macrotext", "/use Apexis Focusing Shard\n/use Autographed Hearthstone Card\n/use Azeroth Mini Collection: Mechagon\n/use Brazier of Dancing Flames\n/use Brewfest Keg Pony\n/use Bubble Wand\n/use Chalice of the Mountain Kings\n/use Croak Crock\n/click toy2");

local toy2 = CreateFrame("Button", "toy2", UIParent, "SecureActionButtonTemplate");
toy2:SetAttribute("type", "macro");
toy2:SetAttribute("macrotext", "/use Desert Flute\n/use Echoes of Rezan\n/use Enchanted Stone Whistle\n/use Everlasting Darkmoon Firework\n/use Everlasting Horde Firework\n/use Fire-Eater's Vial\n/use Foul Belly\n/use Fruit Basket\n/click toy3");

local toy3 = CreateFrame("Button", "toy3", UIParent, "SecureActionButtonTemplate");
toy3:SetAttribute("type", "macro");
toy3:SetAttribute("macrotext", "/use Hearthstone Board\n/use Hourglass of Eternity\n/use Hot Buttered Popcorn\n/use Kaldorei Wind Chimes\n/use Ley Spider Eggs\n/use Panflute of Pandaria\n/use Pendant of the Scarab Storm\n/click toy4");

local toy4 = CreateFrame("Button", "toy4", UIParent, "SecureActionButtonTemplate");
toy4:SetAttribute("type", "macro");
toy4:SetAttribute("macrotext", "/use Rainbow Generator\n/use Seafarer's Slidewhistle\n/use Slightly-Chewed Insult Book\n/use Spirit of Bashiok\n/use Stackable Stag\n/use Sylvanas' Music Box\n/use Tear of the Green Aspect\n/click toy5");

local toy5 = CreateFrame("Button", "toy5", UIParent, "SecureActionButtonTemplate");
toy5:SetAttribute("type", "macro");
toy5:SetAttribute("macrotext", "/use Titanium Seal of Dalaran\n/use Verdant Throwing Sphere\n/use Void Totem\n/use Void-Touched Souvenir Totem\n/use Words of Akunda\n/use Wisp in a Bottle\n/use Worn Doll\n/use Winning Hand\n/click toy5");

local toy6 = CreateFrame("Button", "toy6", UIParent, "SecureActionButtonTemplate");
toy6:SetAttribute("type", "macro");
toy6:SetAttribute("macrotext", "/use Xan'tish's Flute\n");



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
--ZoneAbilityFrame.SpellButton.Style:SetAlpha(0);

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

end
