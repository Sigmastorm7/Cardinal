local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")
local Debug = ns.Debug

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

ns.defaults = {
	iconScale = 0.7,
	throttle = 0.0125,
	poiFOV = 135,
	compassFOV = 90,
}
ns.defaultsPC = {}

ns:RegisterEvent("ADDON_LOADED")

Minimap:UnregisterEvent("MINIMAP_UPDATE_ZOOM")
MinimapCluster = CardinalCluster
Minimap:Hide()

function ns:ADDON_LOADED(event, addon)
	if addon ~= myname then return end

	HBDPins:SetMinimapObject(Cardinal)

	self:InitDB()

	self:RegisterEvent("QUEST_POI_UPDATE")
	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
	self:RegisterEvent("QUEST_DATA_LOAD_RESULT")
	self:RegisterEvent("QUESTLINE_UPDATE")

	self:RegisterEvent("TASK_PROGRESS_UPDATE")

	self:RegisterEvent("LORE_TEXT_UPDATED_CAMPAIGN")

	self:RegisterEvent("COVENANT_CALLINGS_UPDATED")

	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")

	self:RegisterEvent("SUPER_TRACKING_CHANGED")

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
	self:RegisterEvent("PLAYER_CONTROL_LOST")
	self:RegisterEvent("PLAYER_CONTROL_GAINED")
	self:RegisterEvent("PLAYER_ENTER_COMBAT")
	self:RegisterEvent("PLAYER_LEAVE_COMBAT")
	self:RegisterEvent("PLAYER_STARTED_LOOKING")
	self:RegisterEvent("PLAYER_STOPPED_LOOKING")
	self:RegisterEvent("PLAYER_STARTED_TURNING")
	self:RegisterEvent("PLAYER_STOPPED_TURNING")
	self:RegisterEvent("PLAYER_STARTED_MOVING")
	self:RegisterEvent("PLAYER_STOPPED_MOVING")

	-- self:RegisterEvent("CONSOLE_MESSAGE")
	-- "Weather changed to 5, intensity 0.427130"

	local update = function() self:UpdatePOIs() end
	hooksecurefunc(C_QuestLog, "AddQuestWatch", update)
	hooksecurefunc(C_QuestLog, "RemoveQuestWatch", update)

	LibStub("konfig-AboutPanel").new(myfullname, myname) -- Make first arg nil if no parent config panel

	ns.ParentFrame = CreateFrame("Frame")
	QuestPOI_Initialize(ns.ParentFrame)
	ns.wqPool = CreateFramePool("BUTTON", ns.ParentFrame, "QuestPinTemplate")

	ns.buttonPool = CreateFramePoolCollection()
	ns.buttonPool:CreatePool("BUTTON", ns.ParentFrame, "QuestPinTemplate")
	ns.buttonPool:CreatePool("BUTTON", ns.ParentFrame, "StorylineQuestPinTemplate")
	ns.buttonPool:CreatePool("BUTTON", ns.ParentFrame, "WorldQuestPinTemplate")


	self:UnregisterEvent("ADDON_LOADED")
	self.ADDON_LOADED = nil

	if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterEvent("PLAYER_LOGIN") end
end

function ns:PLAYER_LOGIN()
	self:RegisterEvent("PLAYER_LOGOUT")

	-- Do anything you need to do after the player has entered the world

	self:UpdatePOIs()
	self:UnregisterEvent("PLAYER_LOGIN")
	self.PLAYER_LOGIN = nil

end

function ns:PLAYER_LOGOUT()
	self:FlushDB()
	-- Do anything you need to do as the player logs out
end

local timeElapsed = 0
local _value
-- local mediaPath = "Interface/Addons/Cardinal/media/"
-- local covenantData = C_Covenants.GetCovenantData(C_Covenants.GetActiveCovenantID())

--[[
local _TimeManagerClockButton_OnLoad = TimeManagerClockButton_OnLoad
TimeManagerClockButton_OnLoad = function(self)
	self:SetParent(Cardinal)
	_TimeManagerClockButton_OnLoad(self)
end
]]

local function CompassUpdate(self, elapsed)
	local facing = GetPlayerFacing()
	if not facing then print("No facing value, returning...") return end

	timeElapsed = timeElapsed + elapsed
    while (timeElapsed > ns.db.throttle) do
        timeElapsed = timeElapsed - ns.db.throttle
        local value = deg(GetPlayerFacing()) + self.offset
        if value == _value then
            return
        elseif value ~= _value then
            if value > 180 then
                self:SetValue(value-360)
                _value = value
            elseif value < 180 then
                self:SetValue(value)
                _value = value
            end
        end
		self.Char:SetPoint("TOP", self.Thumb, "BOTTOM", 0, -11)
		local selfValue = self:GetValue()
		if selfValue < -25 or selfValue > 25 then
			self.Char:SetText("")
		else
			self.Char:SetText(self.direction)
		end
    end
end

-- Script hooks for cardinal direction sliders
do
	CardinalSliderCluster.North:HookScript("OnUpdate", CompassUpdate)
	CardinalSliderCluster.East:HookScript("OnUpdate", CompassUpdate)
	CardinalSliderCluster.South:HookScript("OnUpdate", CompassUpdate)
	CardinalSliderCluster.West:HookScript("OnUpdate", CompassUpdate)
	CardinalSliderCluster.NorthWest:HookScript("OnUpdate", CompassUpdate)
	CardinalSliderCluster.SouthWest:HookScript("OnUpdate", CompassUpdate)
	CardinalSliderCluster.SouthEast:HookScript("OnUpdate", CompassUpdate)
	CardinalSliderCluster.NorthEast:HookScript("OnUpdate", CompassUpdate)
end

local pois = {}
local callings = {}
local lqPOIs, sqPOIs, wqPOIs = {}, {}, {}
local POI_OnEnter, POI_OnLeave, POI_PostClick

ns.pois = pois
ns.callings = callings

function ns:ClosestPOI()
	local closest, closest_distance, poi_distance, _
	for id, poi in pairs(ns.pois) do
		if poi.active then
			_, poi_distance = HBDPins:GetVectorToIcon(poi)

			if closest then
				if poi_distance and closest_distance and poi_distance < closest_distance then
					closest = poi
					closest_distance = poi_distance
				end
			else
				closest = poi
				closest_distance = poi_distance
			end
		end
	end
	return closest
end

function ns:TrackingUpdate()
	if C_SuperTrack.IsSuperTrackingAnything() then
		local tracked = C_SuperTrack.GetSuperTrackedQuestID()
		local objectives = C_QuestLog.GetQuestObjectives(tracked)

		-- When logging in C_.GetQuestObjectives() seems to return 'nil' despite C_.IsSuperTrackingAnything() returning true
		if not objectives then return end

		CardinalTracker.Title:SetText(C_QuestLog.GetTitleForQuestID(tracked))
		CardinalTracker.Objective:SetText(objectives[1]["text"])
	else
		CardinalTracker.Title:SetText("")
		CardinalTracker.Objective:SetText("")
	end
end

function ns:UpdatePOIs(...)
	-- self.Debug("UpdatePOIs", ...)

	ns:TrackingUpdate()

	local x, y, mapid = HBD:GetPlayerZonePosition()
	if not (mapid and x and y) then
		-- Means that this was probably a change triggered by the world map being
		-- opened and browsed around. Since this is the case, we won't update any POIs for now.
		-- self.Debug("Skipped UpdatePOIs because of no player position")
		return
	end
	if WorldMapFrame:IsVisible() and WorldMapFrame.mapID ~= mapid then
		-- TODO: handle microdungeons
		-- self.Debug("Skipped UpdatePOIs because map is open and not viewing current zone")
		return
	end

	for _, poi in pairs(pois) do
		self:ResetPOI(poi)
	end

	self:UpdateLogPOIs(mapid)
	self:UpdateWorldPOIs(mapid)

	for id, poi in pairs(pois) do
		-- ns.Debug("Considering poi", id, poi.questID, poi.active)
		if poi.active then
			poi.poiButton:Show()
		end
	end
end

ns.QUEST_POI_UPDATE = ns.UpdatePOIs
ns.QUEST_LOG_UPDATE = ns.UpdatePOIs
ns.QUEST_WATCH_LIST_CHANGED = ns.UpdatePOIs

ns.ZONE_CHANGED_NEW_AREA = ns.UpdatePOIs

ns.PLAYER_ENTERING_WORLD = ns.UpdatePOIs

ns.SUPER_TRACKING_CHANGED = ns.UpdatePOIs

ns.TASK_PROGRESS_UPDATE = ns.UpdatePOIs

function ns:UpdateLogPOIs(mapid)
	local cvar = GetCVarBool("questPOI")
	SetCVar("questPOI", 1)
	-- Interestingly, even if this isn't called, *some* POIs will show up. Not sure why.
	QuestPOIUpdateIcons()

	local numNumericQuests = 0
	local numCompletedQuests = 0
	local numPois = QuestMapUpdateAllQuests()
	local questPois = {}

	if ( numPois > 0 and GetCVarBool("questPOI") ) then
		GetQuestPOIs(questPois)
	end
	for i, questID in ipairs(questPois) do
		if C_QuestLog.IsQuestCalling(questID) then
			table.insert(ns.callings, questID)
			return
		else
			-- Debug("Quest", questID)
			local _, posX, posY, objective = QuestPOIGetIconInfo(questID)
			-- local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestId, isOnMap, hasLocalPOI, isTask, isBounty, isStory = GetQuestLogTitle(questLogIndex)
			local isOnMap = C_QuestLog.IsOnMap(questID)
			local isTask = C_QuestLog.IsQuestTask(questID)
			-- IsQuestComplete seems to test for "is quest in a turnable-in state?", distinct from IsQuestFlaggedCompleted...
			local isComplete = C_QuestLog.IsComplete(questID)

			if not isTask then
				-- self.Debug("Skipped POI", i, posX, posY)
				if isComplete then
					numCompletedQuests = numCompletedQuests + 1
				else
					numNumericQuests = numNumericQuests + 1
				end
			end

			if isOnMap and posX and posY and (not self.db.watchedOnly or C_QuestLog.GetQuestWatchType(questID)) and not isTask then
				local title = C_QuestLog.GetTitleForQuestID(questID)
				-- self.Debug("POI", questID, posX, posY, objective, title, isOnMap, isTask)

				local poiButton

				if isComplete then
					-- self.Debug("Making with complete", i)
					poiButton = QuestPOI_GetButton(ns.ParentFrame, questID, isOnMap and 'normal' or 'remote', numCompletedQuests)
				else
					-- self.Debug("Making with numeric", i - numCompletedQuests)
					poiButton = QuestPOI_GetButton(ns.ParentFrame, questID, isOnMap and 'numeric' or 'remote', numNumericQuests)
				end

				poiButton.questType = "LQ"

				local poi = self:GetPOI('LQ' .. i, poiButton)

				poi.index = i
				poi.questID = questID
				poi.title = title
				poi.m = mapid
				poi.x = posX
				poi.y = posY
				poi.active = true
				poi.complete = isComplete

				poiButton.worldQuest = false

				HBDPins:AddMinimapIconMap(self, poi, mapid, posX, posY, false, true)
			end
		end
	end
	SetCVar("questPOI", cvar and 1 or 0)
end

function ns:UpdateWorldPOIs(mapid)

	local numWQs = C_TaskQuest.GetQuestsForPlayerByMapID(mapid)

	if numWQs == nil or #numWQs == 0 then
		return
	end

	local taskIconIndex = 0
	for i, info  in ipairs(numWQs) do
		if info.mapID == mapid and HaveQuestData(info.questId) and C_QuestLog.IsWorldQuest(info.questId) then
			local poiButton = self:GetWorldQuestButton(info)
			-- Debug("WorldMapPOI", info.questId, poiButton)
			if poiButton then
				local poi = self:GetPOI('WQ' .. taskIconIndex, poiButton)
				poiButton.questID = info.questId
				poiButton.numObjectives = info.numObjectives
				poiButton.worldQuest = true

				poiButton.questType = "WQ"

				local distance = C_QuestLog.GetDistanceSqToQuest(poiButton.questID)

				poiButton:SetScale(ns.db.iconScale * poiButton.scaleFactor)-- (rad(rad(sqrt(distance))))*0.75)

				taskIconIndex = taskIconIndex + 1

				poi.index = i
				poi.questID = info.questId
				poi.title = C_TaskQuest.GetQuestInfoByQuestID(info.questId)
				poi.m = mapid
				poi.x = info.x
				poi.y = info.y
				poi.active = true
				poi.complete = false -- world quests vanish when complete, so...

				HBDPins:AddMinimapIconMap(self, poi, mapid, info.x, info.y, false, false)

				--[[
				for _, callingID in pairs(ns.callings) do
					print("Is Quest Criteria For Bounty:")
					if C_QuestLog.IsQuestCriteriaForBounty(info.questId, callingID) then
						print(info.questId.." - true")
					else
						print(info.questId.." - false")
					end
				end
				]]

			end
		end
	end
end

function ns:WorldQuestIsWatched(questID)
	if C_QuestLog.GetQuestWatchType(questID) ~= nil then
		return true
	end
	-- tasks we're currently in the area of count as "watched" for our purposes
	local tasks = GetTasksTable()
	for i, taskId in ipairs(tasks) do
		if taskId == questID then
			return true
		end
	end
	return false
end

do
	local fauxDataProvider = {
		GetBountyQuestID = function() return nil end,
		IsMarkingActiveQuests = function() return true end,
		ShouldHighlightInfo = function() return false end,
	}

	function ns:GetWorldQuestButton(info)
		local poiButton = ns.buttonPool:Acquire("WorldQuestPinTemplate")

		poiButton.poiParent = CardinalSliderCluster

		poiButton.questID = info.questId
		poiButton.dataProvider = fauxDataProvider
		poiButton.scaleFactor = 0.4

		local tagInfo = C_QuestLog.GetQuestTagInfo(info.questId)
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
				poiButton.Underlay:SetAtlas("worldquest-questmarker-dragon");
				poiButton.Underlay:Show();
			elseif tagInfo.quality == Enum.WorldQuestQuality.Epic then
				poiButton.Background:SetAtlas("worldquest-questmarker-epic");
				poiButton.PushedBackground:SetAtlas("worldquest-questmarker-epic-down");
				poiButton.Highlight:SetAtlas("worldquest-questmarker-epic");
				poiButton.SelectedGlow:SetAtlas("worldquest-questmarker-epic");
				poiButton.Underlay:SetAtlas("worldquest-questmarker-dragon");
				poiButton.Underlay:Show();
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

		-- poiButton:SetSize(24, 24)
		-- poiButton.Glow:SetSize(80, 80)
		-- poiButton.BountyRing:SetSize(80, 80)
		-- poiButton.Underlay:SetSize(84, 84)
		-- poiButton.TrackedCheck:SetSize(38, 36)
		-- poiButton.TrackedCheck:SetPoint("BOTTOMLEFT", 16, -12)
		-- poiButton.TimeLowFrame:SetSize(36, 36)

		return poiButton
	end

end

function ns:GetPOI(id, button)
	local poiSlider = pois[id]
	if not poiSlider then
		poiSlider = CreateFrame("Slider", "SliderParent-"..id, CardinalSliderCluster, "CardinalPinSliderTemplate")
		pois[id] = poiSlider
	end

	button:SetPoint("CENTER", poiSlider.Thumb)
	button:SetScale(self.db.iconScale * (button.scaleFactor or 1))
	button:EnableMouse(false)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")

	poiSlider.poiButton = button

	button:SetScript("OnEnter", POI_OnEnter)
	button:SetScript("OnLeave", POI_OnLeave)
	button:SetScript("PostClick", POI_PostClick)

	return poiSlider
end

function ns:ResetPOI(poiSlider)
	HBDPins:RemoveMinimapIcon(self, poiSlider)
	if poiSlider.poiButton then
		ns.wqPool:Release(poiSlider.poiButton)
		poiSlider.poiButton:Hide()
		poiSlider.poiButton:SetParent(poiSlider)
		poiSlider.poiButton = nil
	end
	poiSlider.active = false
end

do
	local selected
	function ns:UpdateGlow()
		selected = self:ClearSelection(selected)
	end

	function ns:SetSelection(poiButton)
		if not poiButton then return end

		local parent = poiButton.poiParent
		parent.poiSelectedButton = poiButton

		if poiButton.worldQuest then

			local tagInfo = C_QuestLog.GetQuestTagInfo(poiButton.questID)

			if tagInfo.quality == Enum.WorldQuestQuality.Common then

				poiButton.Background:SetTexCoord(0.500, 0.625, 0.375, 0.5)

				poiButton.PushedBackground:SetTexCoord(0.375, 0.500, 0.375, 0.5)

			else

				poiButton.SelectedGlow:SetShown(true)

			end

			poiButton.Glow:SetShown(true)

		else

			QuestPOI_SelectButtonByQuestID(poiButton:GetParent(), poiButton.questID)

		end

		poiButton.active = true

		return poiButton
	end

	function ns:ClearSelection(poiButton)
		if (not poiButton) or (not poiButton.active) then return end

		local parent = poiButton.poiParent
		parent.poiSelectedButton = poiButton

		if poiButton.worldQuest then


			local tagInfo = C_QuestLog.GetQuestTagInfo(poiButton.questID)
			-- override this bit from WorldQuestDataProvider.lua
			if tagInfo.quality == Enum.WorldQuestQuality.Common then
				poiButton.Background:SetTexCoord(0.875, 1, 0.375, 0.5)
				poiButton.PushedBackground:SetTexCoord(0.750, 0.875, 0.375, 0.5)
			else
				poiButton.SelectedGlow:SetShown(true)
			end
			poiButton.Glow:SetShown(false)

		else

			QuestPOI_ClearSelection(poiButton:GetParent())

		end

		poiButton.active = false

		return poiButton
	end
end

do
	local t = 0
	local f = CreateFrame("Frame")
	f:SetScript("OnUpdate", function(self, elapsed)
		t = t + elapsed
		if t > 3 then -- this doesn't change very often at all; maybe more than 3 seconds?
			t = 0
			ns:UpdateGlow()
		end
	end)
end

do -- POI Tooltip
	local tooltip = CreateFrame("GameTooltip", "CardinalTooltip", UIParent, "GameTooltipTemplate")
	function POI_OnEnter(self)
		if not self.questID then
			return
		end
		if UIParent:IsVisible() then
			tooltip:SetParent(UIParent)
		else
			tooltip:SetParent(self)
		end

		tooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		tooltip:SetHyperlink("quest:" .. self.questID)
	end

	function POI_OnLeave(self)
		tooltip:Hide()
	end
end

do
	function POI_PostClick(poiButton, mouseButton, down)

		if mouseButton == "LeftButton" then

			if poiButton.active then
				-- ns:ClearSelection(poiButton)
			else
				-- C_SuperTrack.SetSuperTrackedQuestID(poiButton.questID)
				-- ns:SetSelection(poiButton)
			end

		elseif mouseButton == "RightButton" then

			if not poiButton.worldQuest then
				QuestMapFrame_OpenToQuestDetails(poiButton.questID)
			else
				return
			end

		elseif mouseButton == "MiddleButton" then
			return
			--[[if poiButton.worldQuest then
				C_QuestLog.RemoveWorldQuestWatch(poiButton.questID)
			else
				C_QuestLog.RemoveQuestWatch(poiButton.questID)
			end]]

		else return end
	end
end

function ns.Debug(...) print("|cFF33FF99".. myfullname.. "|r:", ...) end