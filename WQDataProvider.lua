--@diagnostic disable: undefined-global, undefined-field
local myname, crdn = ...

crdn.GetMap = WorldQuestDataProviderMixin.GetMap
crdn.AcquirePin = WorldQuestDataProviderMixin.AcquirePin
crdn.GetPinTemplate = WorldQuestDataProviderMixin.GetPinTemplate
crdn.ShouldShowExpirationIcon = WorldQuestDataProviderMixin.ShouldShowExpirationIcon

crdn.usedQuestNumbers = crdn.usedQuestNumbers or {};
crdn.pinsMissingNumbers = crdn.pinsMissingNumbers or {};

local fauxDataProvider = {
    GetBountyQuestID = function() return nil end,
    IsMarkingActiveQuests = function() return true end,
    ShouldHighlightInfo = function() return false end,
}

function crdn:AssignMissingNumbersToPins()
	if #self.pinsMissingNumbers > 0 then
		for questNumber = 1, C_QuestLog.GetMaxNumQuests() do
			if not self.usedQuestNumbers[questNumber] then
				local pin = table.remove(self.pinsMissingNumbers);
				pin:AssignQuestNumber(questNumber);

				if #self.pinsMissingNumbers == 0 then
					break;
				end
			end
		end

		wipe(self.pinsMissingNumbers);
	end
	wipe(self.usedQuestNumbers);
end

function crdn:AddQuest(info, i)

	if not crdn:UpdatePreCheck() then return end

	local isWaypoint;
	local mapID = crdn:GetMap();
	local pin = crdn.lqButtonPool:Acquire();

	pin.questID = info.questID;
	QuestPOI_SetPinScale(pin, 2.5);

	local isSuperTracked = info.questId == C_SuperTrack.GetSuperTrackedQuestID();
	local isComplete = false; -- QuestCache:Get(questID):IsComplete();

	pin.isSuperTracked = isSuperTracked;

	pin.Display:ClearAllPoints();
	pin.Display:SetPoint("CENTER");
	pin.moveHighlightOnMouseDown = false;
	pin.selected = isSuperTracked;
	pin.style = QuestPOI_GetStyleFromQuestData(pin, isComplete, isWaypoint);

	if pin.style == "numeric" then
		-- try to match the number with tracker or quest log POI if possible
		local poiButton = QuestPOI_FindButton(ObjectiveTrackerFrame.BlocksFrame, info.questID) or QuestPOI_FindButton(QuestScrollFrame.Contents, info.questID);
		if poiButton and poiButton.style == "numeric" then
			local questNumber = poiButton.index;
			self.usedQuestNumbers[questNumber] = true;
			pin:SetQuestNumber(questNumber);
		else
			table.insert(self.pinsMissingNumbers, pin);
		end
	end

	QuestPOI_UpdateButtonStyle(pin);

	-- pin:SetPosition(x, y);
	return pin;
end

function crdn:AddWorldQuest(info)

	if not crdn:UpdatePreCheck() then return end

	local pin = crdn.wqButtonPool:Acquire()
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