--@diagnostic disable: undefined-global, undefined-field
local myname, alpha = ...

alpha.GetMap = WorldQuestDataProviderMixin.GetMap
alpha.AcquirePin = WorldQuestDataProviderMixin.AcquirePin
alpha.GetPinTemplate = WorldQuestDataProviderMixin.GetPinTemplate
alpha.ShouldShowExpirationIcon = WorldQuestDataProviderMixin.ShouldShowExpirationIcon

local fauxDataProvider = {
    GetBountyQuestID = function() return nil end,
    IsMarkingActiveQuests = function() return true end,
    ShouldHighlightInfo = function() return false end,
}

function alpha:AddWorldQuest(info, i)
	local pin = CreateFrame("BUTTON", "WQ"..i..".Button", alpha.frame, "WorldQuestPinTemplate")
	pin.questID = info.questId;
	pin.dataProvider = fauxDataProvider; -- self;

	pin.worldQuest = true;
	pin.numObjectives = info.numObjectives;
	-- pin:UseFrameLevelType("PIN_FRAME_LEVEL_WORLD_QUEST", self:GetMap():GetNumActivePinsByTemplate(self:GetPinTemplate()));

	local tagInfo = C_QuestLog.GetQuestTagInfo(pin.questID);
	pin.tagInfo = tagInfo;
	pin.worldQuestType = tagInfo.worldQuestType;

	if tagInfo.quality ~= Enum.WorldQuestQuality.Common then
		pin.Background:SetTexCoord(0, 1, 0, 1);
		pin.PushedBackground:SetTexCoord(0, 1, 0, 1);
		pin.Highlight:SetTexCoord(0, 1, 0, 1);

		pin.Background:SetSize(45, 45);
		pin.PushedBackground:SetSize(45, 45);
		pin.Highlight:SetSize(45, 45);
		pin.SelectedGlow:SetSize(45, 45);

		if tagInfo.quality == Enum.WorldQuestQuality.Rare then
			pin.Background:SetAtlas("worldquest-questmarker-rare");
			pin.PushedBackground:SetAtlas("worldquest-questmarker-rare-down");
			pin.Highlight:SetAtlas("worldquest-questmarker-rare");
			pin.SelectedGlow:SetAtlas("worldquest-questmarker-rare");
		elseif tagInfo.quality == Enum.WorldQuestQuality.Epic then
			pin.Background:SetAtlas("worldquest-questmarker-epic");
			pin.PushedBackground:SetAtlas("worldquest-questmarker-epic-down");
			pin.Highlight:SetAtlas("worldquest-questmarker-epic");
			pin.SelectedGlow:SetAtlas("worldquest-questmarker-epic");
		end
	else
		pin.Background:SetSize(75, 75);
		pin.PushedBackground:SetSize(75, 75);
		pin.Highlight:SetSize(75, 75);

		-- We are setting the texture without updating the tex coords.  Refresh visuals will handle
		-- updating the tex coords based on whether this pin is selected or not.
		pin.Background:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
		pin.PushedBackground:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
		pin.Highlight:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");

		pin.Highlight:SetTexCoord(0.625, 0.750, 0.875, 1);
	end

	pin:RefreshVisuals();

	if tagInfo.isElite then
		pin.Underlay:SetAtlas("worldquest-questmarker-dragon");
		pin.Underlay:Show();
	else
		pin.Underlay:Hide();
	end

	pin.TimeLowFrame:SetShown(self:ShouldShowExpirationIcon(info.questId, tagInfo.worldQuestType));

	-- pin:SetPosition(info.x, info.y);

	if not HaveQuestRewardData(info.questId) then
		C_TaskQuest.RequestPreloadRewardData(info.questId);
	end

	return pin;
end

--[[
do
	local fauxDataProvider = {
		GetBountyQuestID = function() return nil end,
		IsMarkingActiveQuests = function() return true end,
		ShouldHighlightInfo = function() return false end,
	}
	function alpha:GetWorldQuestButton(info, i)
		local poiButton = CreateFrame("BUTTON", "WQ"..i, alpha.frame, "WorldMap_WorldQuestPinTemplate")

		poiButton.questID = info.questId
		poiButton.dataProvider = fauxDataProvider
		poiButton.scaleFactor = 0.4

		local tagInfo = C_QuestLog.GetQuestTagInfo(info.questId)
		-- local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex, displayTimeLeft = GetQuestTagInfo(info.questId)
		local tradeskillLineID = tagInfo.tradeskillLineID and select(7, GetProfessionInfo(tagInfo.tradeskillLineID))

		poiButton.worldQuestType = tagInfo.worldQuestType

		if tagInfo.quality ~= Enum.WorldQuestQuality.Common then
			poiButton.Background:SetTexCoord(0, 1, 0, 1);
			poiButton.PushedBackground:SetTexCoord(0, 1, 0, 1);
			poiButton.Highlight:SetTexCoord(0, 1, 0, 1);

			poiButton.Background:SetSize(45, 45);
			poiButton.PushedBackground:SetSize(45, 45);
			poiButton.Highlight:SetSize(45, 45);
			poiButton.SelectedGlow:SetSize(45, 45);

			if tagInfo.quality == Enum.WorldQuestQuality.Rare then
				poiButton.Background:SetAtlas("worldquest-questmarker-rare");
				poiButton.PushedBackground:SetAtlas("worldquest-questmarker-rare-down");
				poiButton.Highlight:SetAtlas("worldquest-questmarker-rare");
				poiButton.SelectedGlow:SetAtlas("worldquest-questmarker-rare");
			elseif tagInfo.quality == Enum.WorldQuestQuality.Epic then
				poiButton.Background:SetAtlas("worldquest-questmarker-epic");
				poiButton.PushedBackground:SetAtlas("worldquest-questmarker-epic-down");
				poiButton.Highlight:SetAtlas("worldquest-questmarker-epic");
				poiButton.SelectedGlow:SetAtlas("worldquest-questmarker-epic");
			end
		else
			poiButton.Background:SetSize(75, 75);
			poiButton.PushedBackground:SetSize(75, 75);
			poiButton.Highlight:SetSize(75, 75);

			-- We are setting the texture without updating the tex coords.  Refresh visuals will handle
			-- updating the tex coords based on whether this pin is selected or not.
			poiButton.Background:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
			poiButton.PushedBackground:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
			poiButton.Highlight:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");

			poiButton.Highlight:SetTexCoord(0.625, 0.750, 0.875, 1);
		end

		poiButton:RefreshVisuals()
		-- alpha:RefreshWorldQuestButton(poiButton)

		if tagInfo.isElite then
			poiButton.Underlay:SetAtlas("worldquest-questmarker-dragon");
			poiButton.Underlay:Show();
		else
			poiButton.Underlay:Hide();
		end

		local timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(info.questId)
		if timeLeftMinutes and timeLeftMinutes <= WORLD_QUESTS_TIME_LOW_MINUTES then
			poiButton.TimeLowFrame:Show()
		else
			poiButton.TimeLowFrame:Hide()
		end

		poiButton:SetScale(0.3)

		-- poiButton:SetSize(20, 20)
		-- poiButton.Glow:SetSize(29, 29)
		-- poiButton.BountyRing:SetSize(29, 29)
		-- poiButton.Underlay:SetSize(32, 32)
		-- poiButton.TrackedCheck:SetSize(17, 15)
		-- poiButton.TimeLowFrame:SetSize(18, 18)

		return poiButton
	end
end
]]