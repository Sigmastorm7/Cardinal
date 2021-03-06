local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")
local Debug = ns.Debug
----------------------------------------------------------------
-- HereBeDragonsPins integration
----------------------------------------------------------------
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

----------------------------------------------------------------
-- Minimap cluster required functions
----------------------------------------------------------------

function Cardinal_Update()
	CardinalZoneText:SetText(GetMinimapZoneText());

	local pvpType, isSubZonePvP, factionName = GetZonePVPInfo();
	if ( pvpType == "sanctuary" ) then
		CardinalZoneText:SetTextColor(0.41, 0.8, 0.94);
	elseif ( pvpType == "arena" ) then
		CardinalZoneText:SetTextColor(1.0, 0.1, 0.1);
	elseif ( pvpType == "friendly" ) then
		CardinalZoneText:SetTextColor(0.1, 1.0, 0.1);
	elseif ( pvpType == "hostile" ) then
		CardinalZoneText:SetTextColor(1.0, 0.1, 0.1);
	elseif ( pvpType == "contested" ) then
		CardinalZoneText:SetTextColor(1.0, 0.7, 0.0);
	else
		CardinalZoneText:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	end

	Cardinal_SetTooltip( pvpType, factionName );
end

function Cardinal_SetTooltip( pvpType, factionName )
	if ( GameTooltip:IsOwned(CardinalZoneTextButton) ) then
		GameTooltip:SetOwner(CardinalZoneTextButton, "ANCHOR_BOTTOMLEFT");
		local zoneName = GetZoneText();
		local subzoneName = GetSubZoneText();
		if ( subzoneName == zoneName ) then
			subzoneName = "";
		end
		GameTooltip:AddLine( zoneName, 1.0, 1.0, 1.0 );
		if ( pvpType == "sanctuary" ) then
			GameTooltip:AddLine( subzoneName, 0.41, 0.8, 0.94 );
			GameTooltip:AddLine(SANCTUARY_TERRITORY, 0.41, 0.8, 0.94);
		elseif ( pvpType == "arena" ) then
			GameTooltip:AddLine( subzoneName, 1.0, 0.1, 0.1 );
			GameTooltip:AddLine(FREE_FOR_ALL_TERRITORY, 1.0, 0.1, 0.1);
		elseif ( pvpType == "friendly" ) then
			if (factionName and factionName ~= "") then
				GameTooltip:AddLine( subzoneName, 0.1, 1.0, 0.1 );
				GameTooltip:AddLine(format(FACTION_CONTROLLED_TERRITORY, factionName), 0.1, 1.0, 0.1);
			end
		elseif ( pvpType == "hostile" ) then
			if (factionName and factionName ~= "") then
				GameTooltip:AddLine( subzoneName, 1.0, 0.1, 0.1 );
				GameTooltip:AddLine(format(FACTION_CONTROLLED_TERRITORY, factionName), 1.0, 0.1, 0.1);
			end
		elseif ( pvpType == "contested" ) then
			GameTooltip:AddLine( subzoneName, 1.0, 0.7, 0.0 );
			GameTooltip:AddLine(CONTESTED_TERRITORY, 1.0, 0.7, 0.0);
		elseif ( pvpType == "combat" ) then
			GameTooltip:AddLine( subzoneName, 1.0, 0.1, 0.1 );
			GameTooltip:AddLine(COMBAT_ZONE, 1.0, 0.1, 0.1);
		else
			GameTooltip:AddLine( subzoneName, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b );
		end
		GameTooltip:Show();
	end
end

function CardinalMailFrameUpdate()
	local senders = { GetLatestThreeSenders() };
	local headerText = #senders >= 1 and HAVE_MAIL_FROM or HAVE_MAIL;
	FormatUnreadMailTooltip(GameTooltip, headerText, senders);
	GameTooltip:Show();
end

function GarrisonLandingPageCardinalButton_OnLoad(self)
	self.pulseLocks = {};
	self:RegisterEvent("GARRISON_SHOW_LANDING_PAGE");
	self:RegisterEvent("GARRISON_HIDE_LANDING_PAGE");
	self:RegisterEvent("GARRISON_BUILDING_ACTIVATABLE");
	self:RegisterEvent("GARRISON_BUILDING_ACTIVATED");
	self:RegisterEvent("GARRISON_ARCHITECT_OPENED");
	self:RegisterEvent("GARRISON_MISSION_FINISHED");
	self:RegisterEvent("GARRISON_MISSION_NPC_OPENED");
	self:RegisterEvent("GARRISON_SHIPYARD_NPC_OPENED");
	self:RegisterEvent("GARRISON_INVASION_AVAILABLE");
	self:RegisterEvent("GARRISON_INVASION_UNAVAILABLE");
	self:RegisterEvent("SHIPMENT_UPDATE");
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	self:RegisterEvent("ZONE_CHANGED");
	self:RegisterEvent("ZONE_CHANGED_INDOORS");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
end

function GarrisonLandingPageCardinalButton_OnEvent(self, event, ...)
	if (event == "GARRISON_HIDE_LANDING_PAGE") then
		self:Hide();
	elseif (event == "GARRISON_SHOW_LANDING_PAGE") then
		GarrisonLandingPageCardinalButton_UpdateIcon(self);
		self:Show();
	elseif ( event == "GARRISON_BUILDING_ACTIVATABLE" ) then
		local buildingName, garrisonType = ...;
		if ( garrisonType == C_Garrison.GetLandingPageGarrisonType() ) then
			GarrisonCardinalBuilding_ShowPulse(self);
		end
	elseif ( event == "GARRISON_BUILDING_ACTIVATED" or event == "GARRISON_ARCHITECT_OPENED") then
		GarrisonCardinal_HidePulse(self, GARRISON_ALERT_CONTEXT_BUILDING);
	elseif ( event == "GARRISON_MISSION_FINISHED" ) then
		local followerType = ...;
		if ( DoesFollowerMatchCurrentGarrisonType(followerType) ) then
			GarrisonCardinalMission_ShowPulse(self, followerType);
		end
	elseif ( event == "GARRISON_MISSION_NPC_OPENED" ) then
		local followerType = ...;
		GarrisonCardinal_HidePulse(self, GARRISON_ALERT_CONTEXT_MISSION[followerType]);
	elseif ( event == "GARRISON_SHIPYARD_NPC_OPENED" ) then
		GarrisonCardinal_HidePulse(self, GARRISON_ALERT_CONTEXT_MISSION[Enum.GarrisonFollowerType.FollowerType_6_2]);
	elseif (event == "GARRISON_INVASION_AVAILABLE") then
		if ( C_Garrison.GetLandingPageGarrisonType() == Enum.GarrisonType.Type_6_0 ) then
			GarrisonCardinalInvasion_ShowPulse(self);
		end
	elseif (event == "GARRISON_INVASION_UNAVAILABLE") then
		GarrisonCardinal_HidePulse(self, GARRISON_ALERT_CONTEXT_INVASION);
	elseif (event == "SHIPMENT_UPDATE") then
		local shipmentStarted, isTroop = ...;
		if (shipmentStarted) then
			GarrisonCardinalShipmentCreated_ShowPulse(self, isTroop);
		end
	elseif (event == "PLAYER_ENTERING_WORLD") then
		self.isInitialLogin = ...;
		if self.isInitialLogin then
			EventRegistry:RegisterCallback("CovenantCallings.CallingsUpdated", GarrisonCardinal_OnCallingsUpdated, self);
			CovenantCalling_CheckCallings();
		end
	end
end

local function GetCardinalAtlases_GarrisonType8_0(faction)
	if faction == "Horde" then
		return "bfa-landingbutton-horde-up", "bfa-landingbutton-horde-down", "bfa-landingbutton-horde-diamondhighlight", "bfa-landingbutton-horde-diamondglow";
	else
		return "bfa-landingbutton-alliance-up", "bfa-landingbutton-alliance-down", "bfa-landingbutton-alliance-shieldhighlight", "bfa-landingbutton-alliance-shieldglow";
	end
end

local garrisonTypeAnchors = {
	["default"] = AnchorUtil.CreateAnchor("TOPLEFT", "Cardinal", "BOTTOMLEFT"),
	[Enum.GarrisonType.Type_9_0] = AnchorUtil.CreateAnchor("TOPLEFT", "Cardinal", "BOTTOMLEFT"),
}

local function GetGarrisonTypeAnchor(garrisonType)
	return garrisonTypeAnchors[garrisonType or "default"] or garrisonTypeAnchors["default"];
end

local function ApplyGarrisonTypeAnchor(self, garrisonType)
	local anchor = GetGarrisonTypeAnchor(garrisonType);
	local clearAllPoints = true;
	anchor:SetPoint(self, clearAllPoints);
end

local garrisonType9_0AtlasFormats = {
	"shadowlands-landingbutton-%s-up",
	"shadowlands-landingbutton-%s-down",
	"shadowlands-landingbutton-%s-highlight",
	"shadowlands-landingbutton-%s-glow",
};

local function GetCardinalAtlases_GarrisonType9_0(covenantData)
	local kit = covenantData and covenantData.textureKit or "kyrian";
	if kit then
		local t = garrisonType9_0AtlasFormats;
		return t[1]:format(kit), t[2]:format(kit), t[3]:format(kit), t[4]:format(kit);
	end
end

local function SetLandingPageIconFromAtlases(self, up, down, highlight, glow)
	local info = C_Texture.GetAtlasInfo(up);
	self:SetSize(info and info.width or 0, info and info.height or 0);
	self:GetNormalTexture():SetAtlas(up, true);
	self:GetPushedTexture():SetAtlas(down, true);
	self:GetHighlightTexture():SetAtlas(highlight, true);
	self.LoopingGlow:SetAtlas(glow, true);
end

function GarrisonLandingPageCardinalButton_UpdateIcon(self)
	local garrisonType = C_Garrison.GetLandingPageGarrisonType();
	self.garrisonType = garrisonType;

	ApplyGarrisonTypeAnchor(self, garrisonType);

	if (garrisonType == Enum.GarrisonType.Type_6_0) then
		self.faction = UnitFactionGroup("player");
		if ( self.faction == "Horde" ) then
			self:GetNormalTexture():SetAtlas("GarrLanding-MinimapIcon-Horde-Up", true);
			self:GetPushedTexture():SetAtlas("GarrLanding-MinimapIcon-Horde-Down", true);
		else
			self:GetNormalTexture():SetAtlas("GarrLanding-MinimapIcon-Alliance-Up", true);
			self:GetPushedTexture():SetAtlas("GarrLanding-MinimapIcon-Alliance-Down", true);
		end
		self.title = GARRISON_LANDING_PAGE_TITLE;
		self.description = Cardinal_GARRISON_LANDING_PAGE_TOOLTIP;
	elseif (garrisonType == Enum.GarrisonType.Type_7_0) then
		local _, className = UnitClass("player");
		self:GetNormalTexture():SetAtlas("legionmission-landingbutton-"..className.."-up", true);
		self:GetPushedTexture():SetAtlas("legionmission-landingbutton-"..className.."-down", true);
		self.title = ORDER_HALL_LANDING_PAGE_TITLE;
		self.description = Cardinal_ORDER_HALL_LANDING_PAGE_TOOLTIP;
	elseif (garrisonType == Enum.GarrisonType.Type_8_0) then
		self.faction = UnitFactionGroup("player");
		SetLandingPageIconFromAtlases(self, GetCardinalAtlases_GarrisonType8_0(self.faction));
		self.title = GARRISON_TYPE_8_0_LANDING_PAGE_TITLE;
		self.description = GARRISON_TYPE_8_0_LANDING_PAGE_TOOLTIP;
	elseif (garrisonType == Enum.GarrisonType.Type_9_0) then
		local covenantData = C_Covenants.GetCovenantData(C_Covenants.GetActiveCovenantID());
		if covenantData then
			SetLandingPageIconFromAtlases(self, GetCardinalAtlases_GarrisonType9_0(covenantData));
		end

		self.title = GARRISON_TYPE_9_0_LANDING_PAGE_TITLE;
		self.description = GARRISON_TYPE_9_0_LANDING_PAGE_TOOLTIP;
	end
end

function GarrisonLandingPageCardinalButton_OnClick(self, button)
	GarrisonLandingPage_Toggle();
	GarrisonCardinal_HideHelpTip(self);
end

function GarrisonLandingPage_Toggle()
	if (GarrisonLandingPage and GarrisonLandingPage:IsShown()) then
		HideUIPanel(GarrisonLandingPage);
	else
		ShowGarrisonLandingPage(C_Garrison.GetLandingPageGarrisonType());
	end
end

function GarrisonCardinal_SetPulseLock(self, lock, enabled)
	self.pulseLocks[lock] = enabled;
end

-- We play an animation on the garrison Cardinal icon for a number of reasons, but only want to turn the
-- animation off if the user handles all actions related to that alert. For example if we play the animation
-- because a building can be activated and then another because a garrison invasion has occurred,  we want to
-- turn off the animation after they handle both the building and invasion, but not if they handle only one.
-- We always stop the pulse when they click on the landing page icon.

function GarrisonCardinal_HidePulse(self, lock)
	GarrisonCardinal_SetPulseLock(self, lock, false);
	local enabled = false;
	for k, v in pairs(self.pulseLocks) do
		if ( v ) then
			enabled = true;
			break;
		end
	end

	-- If there are no other reasons to show the pulse, hide it
	if (not enabled) then
		GarrisonLandingPageCardinalButton.CardinalLoopPulseAnim:Stop();
	end
end

function GarrisonCardinal_ClearPulse()
	local self = GarrisonLandingPageCardinalButton;
	for k, v in pairs(self.pulseLocks) do
		self.pulseLocks[k] = false;
	end
	self.CardinalLoopPulseAnim:Stop();
end

function GarrisonCardinalBuilding_ShowPulse(self)
	GarrisonCardinal_SetPulseLock(self, GARRISON_ALERT_CONTEXT_BUILDING, true);
	self.CardinalLoopPulseAnim:Play();
end

function GarrisonCardinalMission_ShowPulse(self, followerType)
	GarrisonCardinal_SetPulseLock(self, GARRISON_ALERT_CONTEXT_MISSION[followerType], true);
	self.CardinalLoopPulseAnim:Play();
end

function GarrisonCardinal_Justify(text)
	--Center justify if we're on more than one line
	if ( text:GetNumLines() > 1 ) then
		text:SetJustifyH("CENTER");
	else
		text:SetJustifyH("RIGHT");
	end
end

function GarrisonCardinalInvasion_ShowPulse(self)
	PlaySound(SOUNDKIT.UI_GARRISON_TOAST_INVASION_ALERT);
	self.AlertText:SetText(GARRISON_LANDING_INVASION_ALERT);
	GarrisonCardinal_Justify(self.AlertText);
	GarrisonCardinal_SetPulseLock(self, GARRISON_ALERT_CONTEXT_INVASION, true);
	self.CardinalAlertAnim:Play();
	self.CardinalLoopPulseAnim:Play();
end

function GarrisonCardinalShipmentCreated_ShowPulse(self, isTroop)
    local text;
    if (isTroop) then
        text = GARRISON_LANDING_RECRUITMENT_STARTED_ALERT;
    else
        text = GARRISON_LANDING_SHIPMENT_STARTED_ALERT;
    end

	self.AlertText:SetText(text);
	GarrisonCardinal_Justify(self.AlertText);
	self.CardinalAlertAnim:Play();
end

function GarrisonCardinal_ShowCovenantCallingsNotification(self)
	self.AlertText:SetText(COVENANT_CALLINGS_AVAILABLE);
	GarrisonCardinal_Justify(self.AlertText);
	self.CardinalAlertAnim:Play();
	self.CardinalLoopPulseAnim:Play();

	if not GetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_9_0_GRRISON_LANDING_PAGE_BUTTON_CALLINGS) then
		GarrisonCardinal_SetQueuedHelpTip(self, {
			text = FRAME_TUTORIAL_9_0_GRRISON_LANDING_PAGE_BUTTON_CALLINGS,
			buttonStyle = HelpTip.ButtonStyle.Close,
			cvarBitfield = "closedInfoFrames",
			bitfieldFlag = LE_FRAME_TUTORIAL_9_0_GRRISON_LANDING_PAGE_BUTTON_CALLINGS,
			targetPoint = HelpTip.Point.LeftEdgeCenter,
			offsetX = 0,
			useParentStrata = true,
		});
	end
end

function GarrisonCardinal_OnCallingsUpdated(self, callings, completedCount, availableCount)
	if self.isInitialLogin then
		if availableCount > 0 then
			GarrisonCardinal_ShowCovenantCallingsNotification(self);
		end

		self.isInitialLogin = false;
	end
end

function GarrisonCardinal_SetQueuedHelpTip(self, tipInfo)
	self.queuedHelpTip = tipInfo;
end

function GarrisonCardinal_CheckQueuedHelpTip(self)
	if self.queuedHelpTip then
		local tip = self.queuedHelpTip;
		self.queuedHelpTip = nil;
		HelpTip:Show(self, tip);
	end
end

function GarrisonCardinal_ClearQueuedHelpTip(self)
	if self.queuedHelpTip and self.queuedHelpTip.text == FRAME_TUTORIAL_9_0_GRRISON_LANDING_PAGE_BUTTON_CALLINGS then
		self.queuedHelpTip = nil;
	end
end

function GarrisonCardinal_HideHelpTip(self)
	if self.garrisonType == Enum.GarrisonType.Type_9_0 then
		HelpTip:Acknowledge(self, FRAME_TUTORIAL_9_0_GRRISON_LANDING_PAGE_BUTTON_CALLINGS);
		GarrisonCardinal_ClearQueuedHelpTip(self, FRAME_TUTORIAL_9_0_GRRISON_LANDING_PAGE_BUTTON_CALLINGS);
	end
end