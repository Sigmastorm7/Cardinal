local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")
local Debug = ns.Debug

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")
-------------------------------------------------------------------------------------

local timeElapsed = 0
local _value
local mediaPath = "Interface/Addons/Micromap/media/"
local covenantData = C_Covenants.GetCovenantData(C_Covenants.GetActiveCovenantID());

ns.defaults = {
	iconScale = 0.9,
	iconAlpha = 1,
	throttleTime = 0.025, -- 0.0125,
	poiFOV = 135,
	compassFOV = 90,
}
ns.defaultsPC = {}

HBDPins:SetMinimapObject(Micromap)
Micromap.TrackedPOI:SetText("Tracked Quest Name")

--[[
local MicromapBackdrop = CreateFrame("Frame", "MicromapBackdrop", Micromap, BackdropTemplateMixin and "BackdropTemplate")
MicromapBackdrop:SetAllPoints(Micromap)
MicromapBackdrop:SetBackdrop({
	bgFile = "Interface/Tooltips/UI-Tooltip-Background-Corrupted",
	edgeFile = mediaPath.."tooltip_border",
	edgeSize = 18,
	insets = { left = 12, right = 12, top = 12, bottom = 12 },
})
MicromapBackdrop:SetBackdropColor(1, 1, 1, 1)
MicromapBackdrop:SetFrameStrata("BACKGROUND")
]]

--[[
local function _CompassUpdate(self, elapsed)
	timeElapsed = timeElapsed + elapsed
    while (timeElapsed > ns.db.throttleTime) do
        timeElapsed = timeElapsed - ns.db.throttleTime
        local facing = floor(deg(GetPlayerFacing()))
		if facing >= 0 and facing < 90 then
			if facing <= 45 then
				
			else

			end	
		elseif facing >= 90 and facing < 180 then
		
		elseif facing >= 180 and facing < 270 then
		
		elseif facing >= 270 and facing < 360 then

		end
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
		self.Char:SetPoint("CENTER", self.Thumb, "BOTTOM", 0, -20)
		local selfValue = self:GetValue()
		if selfValue < -45 or selfValue > 45 then
			self.Char:SetText("")
		else
			self.Char:SetText(self.direction)
		end
    end
end
]]

local function CompassUpdate(self, elapsed)
	timeElapsed = timeElapsed + elapsed
    while (timeElapsed > ns.db.throttleTime) do
        timeElapsed = timeElapsed - ns.db.throttleTime
        local value = floor(deg(GetPlayerFacing())) + self.offset
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
		self.Char:SetPoint("CENTER", self.Thumb, "BOTTOM", 0, -20)
		local selfValue = self:GetValue()
		if selfValue < -45 or selfValue > 45 then
			self.Char:SetText("")
		else
			self.Char:SetText(self.direction)
		end
    end
end

-- MicromapCompass:HookScript("OnUpdate", _CompassUpdate)
MicromapSliderCluster.North:HookScript("OnUpdate", CompassUpdate)
MicromapSliderCluster.East:HookScript("OnUpdate", CompassUpdate)
MicromapSliderCluster.South:HookScript("OnUpdate", CompassUpdate)
MicromapSliderCluster.West:HookScript("OnUpdate", CompassUpdate)
-------------------------------------------------------------------------------------
-- Shamelessly stolen from QuestPointer
-------------------------------------------------------------------------------------
ns:RegisterEvent("ADDON_LOADED")
function ns:ADDON_LOADED(event, addon)
	if addon ~= myname then return end

	-- Hide the default UI Minimap & MinimapCluster
	Minimap:Hide()
	MinimapCluster:Hide()

	self:InitDB()

	self:RegisterEvent("QUEST_POI_UPDATE")
	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
	self:RegisterEvent("QUEST_DATA_LOAD_RESULT")
	self:RegisterEvent("QUESTLINE_UPDATE")

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
	ns.wqPool = CreateFramePool("BUTTON", ns.ParentFrame, "QuestPinTemplate") -- "WorldMap_WorldQuestPinTemplate")
	
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

local pois = {}
local POI_OnEnter, POI_OnLeave, POI_OnMouseUp

ns.pois = pois

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

function ns:UpdatePOIs(...)
	self.Debug("UpdatePOIs", ...)

	local x, y, mapid = HBD:GetPlayerZonePosition()
	if not (mapid and x and y) then
		-- Means that this was probably a change triggered by the world map being
		-- opened and browsed around. Since this is the case, we won't update any POIs for now.
		self.Debug("Skipped UpdatePOIs because of no player position")
		return
	end
	if WorldMapFrame:IsVisible() and WorldMapFrame.mapID ~= mapid then
		-- TODO: handle microdungeons
		self.Debug("Skipped UpdatePOIs because map is open and not viewing current zone")
		return
	end

	for _, poi in pairs(pois) do
		self:ResetPOI(poi)
	end

	self:UpdateLogPOIs(mapid)
	self:UpdateWorldPOIs(mapid)

	for id, poi in pairs(pois) do
		ns.Debug("Considering poi", id, poi.questId, poi.active)
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

function ns:UpdateLogPOIs(mapid)
	local cvar = GetCVarBool("questPOI")
	SetCVar("questPOI", 1)
	-- Interestingly, even if this isn't called, *some* POIs will show up. Not sure why.
	QuestPOIUpdateIcons()

	local numNumericQuests = 0
	local numCompletedQuests = 0
	local numPois = QuestMapUpdateAllQuests()
	local questPois = {}
	Debug("Quests on map", numPois)
	if ( numPois > 0 and GetCVarBool("questPOI") ) then
		GetQuestPOIs(questPois)
	end
	for i, questId in ipairs(questPois) do
		if C_QuestLog.IsQuestCalling(questId) then
			return
		else
			Debug("Quest", questId)
			local _, posX, posY, objective = QuestPOIGetIconInfo(questId)
			-- local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questId, startEvent, displayQuestId, isOnMap, hasLocalPOI, isTask, isBounty, isStory = GetQuestLogTitle(questLogIndex)
			local isOnMap = C_QuestLog.IsOnMap(questId)
			local isTask = C_QuestLog.IsQuestTask(questId)
			-- IsQuestComplete seems to test for "is quest in a turnable-in state?", distinct from IsQuestFlaggedCompleted...
			local isComplete = C_QuestLog.IsComplete(questId)

			if not isTask then
				self.Debug("Skipped POI", i, posX, posY)
				if isComplete then
					numCompletedQuests = numCompletedQuests + 1
				else
					numNumericQuests = numNumericQuests + 1
				end
			end

			if isOnMap and posX and posY and (not self.db.watchedOnly or C_QuestLog.GetQuestWatchType(questId)) and not isTask then
				local title = C_QuestLog.GetTitleForQuestID(questId)

				self.Debug("POI", questId, posX, posY, objective, title, isOnMap, isTask)

				local poiButton
				if isComplete then
					self.Debug("Making with complete", i)
					poiButton = QuestPOI_GetButton(ns.ParentFrame, questId, isOnMap and 'normal' or 'remote', numCompletedQuests)
				else
					self.Debug("Making with numeric", i - numCompletedQuests)
					poiButton = QuestPOI_GetButton(ns.ParentFrame, questId, isOnMap and 'numeric' or 'remote', numNumericQuests)
				end

				local poi = self:GetPOI('LQ' .. i, poiButton)

				poi.index = i
				poi.questId = questId
				poi.title = title
				poi.m = mapid
				poi.x = posX
				poi.y = posY
				poi.active = true
				poi.complete = isComplete

				HBDPins:AddMinimapIconMap(self, poi, mapid, posX, posY, false, true)
			end
		end
	end
	SetCVar("questPOI", cvar and 1 or 0)
end

function ns:UpdateWorldPOIs(mapid)
	local taskInfo = C_TaskQuest.GetQuestsForPlayerByMapID(mapid)
	if taskInfo == nil or #taskInfo == 0 then
		return
	end
	local taskIconIndex = 0
	for i, info  in ipairs(taskInfo) do
		if info.mapID == mapid and HaveQuestData(info.questId) and C_QuestLog.IsWorldQuest(info.questId) then
			local wqButton = self:GetWorldQuestButton(info)
			Debug("WorldMapPOI", info.questId, wqButton)
			if wqButton then
				local poi = self:GetPOI('WQ' .. taskIconIndex, wqButton)
				wqButton.questID = info.questId
				wqButton.numObjectives = info.numObjectives

				taskIconIndex = taskIconIndex + 1

				poi.index = i
				poi.questId = info.questId
				poi.title = C_TaskQuest.GetQuestInfoByQuestID(info.questId)
				poi.m = mapid
				poi.x = info.x
				poi.y = info.y
				poi.active = true
				poi.worldQuest = true
				poi.complete = false -- world quests vanish when complete, so...

				-- self:RefreshWorldQuestButton(poi.poiButton)

				HBDPins:AddMinimapIconMap(self, poi, mapid, info.x, info.y, false, true)
			end
		end
	end
end

function ns:UpdateQuestPOI(mapid)

end

function ns:UpdateStorylineQuestPOI(mapid)

end

function ns:UpdateWorldQuestPOI(mapid)

end

function ns:WorldQuestIsWatched(questId)
	if C_QuestLog.GetQuestWatchType(questId) ~= nil then
		return true
	end
	-- tasks we're currently in the area of count as "watched" for our purposes
	local tasks = GetTasksTable()
	for i, taskId in ipairs(tasks) do
		if taskId == questId then
			return true
		end
	end
	return false
end

--[[
do
	function ns:GetQuestButton(info)
		local questButton = ns.getQuestButton:Acquire(info)
	end

	function ns:GetStorylineQuestButton(info)
		local storyButton = ns.getStorylineQuestButton:Acquire(info)
	end

	function ns:_GetWorldQuestButton(info)
		local worldButton = ns.getWorldQuestButton:Acquire(info)
	end
end
]]

do
	local fauxDataProvider = {
		GetBountyQuestID = function() return nil end,
		IsMarkingActiveQuests = function() return true end,
		ShouldHighlightInfo = function() return false end,
	}
	
	function ns:GetWorldQuestButton(info)
		-- local poiButton = ns.wqPool:Acquire()
		local poiButton = ns.buttonPool:Acquire("WorldQuestPinTemplate")

		poiButton.poiParent = MicromapSliderCluster
		-- poiButton.Display = CreateFrame("FRAME", nil, poiButton, "QuestPinTemplate")
		-- poiButton.Display:SetPoint("CENTER")

		poiButton.questID = info.questId
		poiButton.dataProvider = fauxDataProvider
		poiButton.scaleFactor = 0.4

		local tagInfo = C_QuestLog.GetQuestTagInfo(info.questId)
		local tradeskillLineID = tagInfo.tradeskillLineID and select(7, GetProfessionInfo(tagInfo.tradeskillLineID))

		poiButton.worldQuestType = tagInfo.worldQuestType
		self.Debug("World Quest Type:", poiButton.worldQuestType)

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
		-- ns:RefreshWorldQuestButton(poiButton)

		
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

		poiButton:SetScale(1)

		poiButton:SetSize(24, 24)
		poiButton.Glow:SetSize(80, 80)
		poiButton.BountyRing:SetSize(80, 80)
		poiButton.Underlay:SetSize(84, 84)
		poiButton.TrackedCheck:SetSize(38, 36)
		poiButton.TrackedCheck:SetPoint("BOTTOMLEFT", 16, -12)
		poiButton.TimeLowFrame:SetSize(36, 36)

		return poiButton
	end
end

function ns:GetPOI(id, button)
	local poiSlider = pois[id]
	if not poiSlider then
		poiSlider = CreateFrame("Slider", "SliderParent-"..id, MicromapSliderCluster, "MicromapPinSliderTemplate")
		poiSlider.Hitbox:EnableMouse(true)
		poiSlider.Hitbox:HookScript("OnUpdate", function(selfie, elapsed)
			timeElapsed = timeElapsed + elapsed
    		while (timeElapsed > 0.1) do
    		    timeElapsed = timeElapsed - 0.1
    		    selfie:SetPoint("CENTER", poiSlider.Thumb, "CENTER")
    		end
		end)

		pois[id] = poiSlider
	end

	button:SetPoint("CENTER", poiSlider.Thumb)
	button:SetScale(self.db.iconScale * (button.scaleFactor or 1))
	button:EnableMouse(true)
	
	poiSlider.poiButton = button

	button:SetScript("OnEnter", POI_OnEnter)
	button:SetScript("OnLeave", POI_OnLeave)
	button:SetScript("OnMouseUp", POI_OnMouseUp)

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
		
		self.Debug("SetSelection:", poiButton.worldQuest)

		if poiButton.worldQuest then
			local tagInfo = C_QuestLog.GetQuestTagInfo(poiButton.questID)
			-- override this bit from WorldQuestDataProvider.lua
			if tagInfo.quality == Enum.WorldQuestQuality.Common then
				poiButton.Background:SetTexCoord(0.500, 0.625, 0.375, 0.5)
				poiButton.PushedBackground:SetTexCoord(0.375, 0.500, 0.375, 0.5)
			else
				poiButton.SelectedGlow:SetShown(true)
			end
			poiButton.Glow:SetShown(true)
			ns.Debug("SetSelection WQ Check", poiButton, poiButton.worldQuest, tagInfo, tagInfo.quality)
		else
			QuestPOI_SelectButtonByQuestID(poiButton:GetParent(), poiButton.questID)
		end
		return poiButton
	end

	function ns:ClearSelection(poiButton)
		if (not poiButton) or (not poiButton.active) then return end
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
	end
end

--[[
do
	local t = 0
	local f = CreateFrame("Frame")
	f:SetScript("OnUpdate", function(self, elapsed)
		t = t + elapsed
		if t > 1 then -- this doesn't change very often at all; maybe more than 3 seconds?
			t = 0
			ns:UpdateGlow()
		end
	end)
end
]]

do
	local tooltip = CreateFrame("GameTooltip", "MicromapTooltip", UIParent, "GameTooltipTemplate")
	function POI_OnEnter(self)
		if not self.questId then
			return
		end
		if UIParent:IsVisible() then
			tooltip:SetParent(UIParent)
		else
			tooltip:SetParent(self)
		end

		tooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		tooltip:SetHyperlink("quest:" .. self.questId)
	end

	function POI_OnLeave(self)
		tooltip:Hide()
	end
end

do
	local selected
	function POI_OnMouseUp(self)
		ns:Debug("POI_OnMouseUp:", self)
		ns:SetSelection(self)
		QuestMapFrame_OpenToQuestDetails(self.questId)
	end
end

function ns.Debug(...) print("|cFF33FF99".. myfullname.. "|r:", ...) end