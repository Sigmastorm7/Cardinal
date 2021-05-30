--@diagnostic disable: undefined-global, undefined-field
local myname, crdn = ...
local myfullname = GetAddOnMetadata(myname, "Title")

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

crdn.defaults = {
	iconScale = 0.7,
	distanceScaling = true,
	distanceFade = true,
	throttle = 0.0125,
	poiFOV = 135,
	compassFOV = 90,
}
crdn.defaultsPC = {}

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
crdn:RegisterEvent("ADDON_LOADED")
function crdn:ADDON_LOADED(event, addon)
	if addon ~= myname then return end
	self:InitDB()

	-- Quest events
	self:RegisterEvent("QUEST_POI_UPDATE")
	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
	self:RegisterEvent("SUPER_TRACKING_CHANGED")

	-- Map/Zone events
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")

	-- Player events
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_STARTED_TURNING")
	self:RegisterEvent("PLAYER_STOPPED_TURNING")
	self:RegisterEvent("PLAYER_STARTED_MOVING")
	self:RegisterEvent("PLAYER_STOPPED_MOVING")
	self:RegisterEvent("PLAYER_ENTER_COMBAT")

	local update = function() self:DrawPOIs() end
	hooksecurefunc(C_QuestLog, "AddQuestWatch", update)
	hooksecurefunc(C_QuestLog, "RemoveQuestWatch", update)

	QuestPOI_Initialize(Cardinal)
	-- crdn.wqpool = CreateFramePool("BUTTON", crdn.poi_parent, "WorldMap_WorldQuestPinTemplate")

	self:UnregisterEvent("ADDON_LOADED")
	self.ADDON_LOADED = nil

	if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterEvent("PLAYER_LOGIN") end
end

function crdn:PLAYER_LOGIN()
	crdn:RegisterEvent("PLAYER_LOGOUT")
	-- Do anything you need to do after the player has entered the world

	crdn:UnregisterEvent("PLAYER_LOGIN")
	crdn.PLAYER_LOGIN = nil
end

function crdn:PLAYER_LOGOUT()
	crdn:FlushDB()
	-- Do anything you need to do as the player logs out
end
---------------------------------------------------------------------------
-- Local values
---------------------------------------------------------------------------
crdn.cardinalPOIs = crdn.cardinalPOIs or {}
local cardinalPOIs = crdn.cardinalPOIs

local taskPOIs = {}
local timeElapsed = 0
local _value
local lastFacing, lastXX, lastYY

local tableCache = setmetatable({}, {__mode='k'})

local mapID = C_Map.GetBestMapForUnit("PLAYER")
if mapID then
	taskPOIs = C_TaskQuest.GetQuestsForPlayerByMapID(mapID)
else
	return
end
---------------------------------------------------------------------------
-- Frame creation & pool setup
---------------------------------------------------------------------------
local tooltip = CreateFrame("GameTooltip", "POITooltip", UIParent, "GameTooltipTemplate")
---------------------------------------------------------------------------
-- Functions
---------------------------------------------------------------------------
local function CompassUpdate(self, elapsed)
	local facing = GetPlayerFacing()
	if not facing then return end

	timeElapsed = timeElapsed + elapsed
    while (timeElapsed > crdn.db.throttle) do
        timeElapsed = timeElapsed - crdn.db.throttle
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
CardinalSliderCluster.North:HookScript("OnUpdate", CompassUpdate)
CardinalSliderCluster.East:HookScript("OnUpdate", CompassUpdate)
CardinalSliderCluster.South:HookScript("OnUpdate", CompassUpdate)
CardinalSliderCluster.West:HookScript("OnUpdate", CompassUpdate)
-- CardinalSliderCluster.NorthWest:HookScript("OnUpdate", CompassUpdate)
-- CardinalSliderCluster.SouthWest:HookScript("OnUpdate", CompassUpdate)
-- CardinalSliderCluster.SouthEast:HookScript("OnUpdate", CompassUpdate)
-- CardinalSliderCluster.NorthEast:HookScript("OnUpdate", CompassUpdate)

local function ThrottledOnUpdate(self, elapsed)

	timeElapsed = timeElapsed + elapsed

    while (timeElapsed > 0.0125) do

    	timeElapsed = timeElapsed - 0.0125
		crdn:DrawPOIs()

	end
end

Cardinal.updateFrame = CreateFrame("FRAME", nil, Cardinal)
Cardinal.updateFrame:HookScript("OnUpdate", ThrottledOnUpdate)

function crdn:DrawPOIs()

	if not cardinalPOIs[1] then crdn:GetPOIButtons() end

	local facing = GetPlayerFacing()
    local x, y, instance = HBD:GetPlayerWorldPosition()

	if not facing then return end

	if x ~= lastXX or y ~= lastYY or facing ~= lastFacing then

		for _, poiButton in ipairs(cardinalPOIs) do

			if not poiButton then break end

    		local vector, distance = HBD:GetWorldVector(instance, x, y, poiButton.x, poiButton.y)
			local value = deg(facing) - deg(vector)

    		if (value > 0 and value < 180) or (value < 0 and value > -180) then
    		    poiButton.slider:SetValue(value)
    		elseif value <= -180 then
    		    poiButton.slider:SetValue(value + 360)
    		elseif value >= 180 then
    		    poiButton.slider:SetValue(value - 360)
    		end

    		local yOffset = distance / 10

    		poiButton:Show()
    		-- poiButton:SetScale(2/(distance/500))
    		poiButton.slider:Show()
    		-- poiButton.slider:SetPoint("CENTER", Cardinal, "BOTTOM", 0, yOffset)
    		poiButton:SetPoint("CENTER", poiButton.slider.Thumb, "CENTER", 0, 0)

		end

		lastXX, lastYY, lastFacing = x, y, facing

	else

	lastXX, lastYY, lastFacing = x, y, facing

		return

	end

end

function crdn:GetPOIButtons()

    if taskPOIs == nil or #taskPOIs == 0 then return end

    for i, info  in ipairs(taskPOIs) do

		local questID = info.questId

		local poiButton = crdn:AddWorldQuest(info, i)
		poiButton:SetScript("OnEnter", POI_OnEnter)
        poiButton:SetScript("OnLeave", POI_OnLeave)
        poiButton:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
        poiButton:SetScript("PostClick", POI_PostClick)

        poiButton.slider = CreateFrame("SLIDER", "WQ"..i..".Slider", Cardinal, "CardinalSliderTemplate")

		local xCoord, yCoord, instanceID = HBD:GetWorldCoordinatesFromZone(info.x, info.y, C_TaskQuest.GetQuestZoneID(questID))

		poiButton:SetScale(0.25)

		poiButton.x = xCoord
		poiButton.y = yCoord

    	cardinalPOIs[i] = poiButton

    end

    return cardinalPOIs

end

function POI_OnEnter(self)
	if not self.questID then return	end
	if UIParent:IsVisible() then tooltip:SetParent(UIParent) else tooltip:SetParent(self) end
	tooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	tooltip:SetHyperlink("quest:" .. self.questID)
end
function POI_OnLeave(self)
	tooltip:Hide()
end
function POI_PostClick(poiButton, mouseButton, down)
    if mouseButton == "LeftButton" then
		if poiButton.selected then
			poiButton.selected = false
		else
			poiButton.selected = true
		end
		-- print(poiButton.ID)
    elseif mouseButton == "RightButton" then
		-- print("right button click")
		return
    elseif mouseButton == "MiddleButton" then
		-- print("middle button click")
		return
    else return end
end

--[[ Functions, data structures, enums, and events that I want to remember for later (from various API Documentation files)

    -------------------------------------------------------------------------------------
        Functions
    -------------------------------------------------------------------------------------
    Function = C_Covenants.GetActiveCovenantID() returns: "covenantID"
    Name = "GetActiveCovenantID",
	Type = "Function",
	Returns =
	{
		{ Name = "covenantID", Type = "number", Nilable = false },
	},
    -------------------------------------------------------------------------------------
        Data Structures (with relevant functions)
    -------------------------------------------------------------------------------------
    Function = C_Covenants.GetCovenantData(covenantID = {number}) returns: "data"
    Name = "CovenantData",
	Type = "Structure",
	Fields =
	{
		{ Name = "ID", Type = "number", Nilable = false },
		{ Name = "textureKit", Type = "string", Nilable = false },
		{ Name = "celebrationSoundKit", Type = "number", Nilable = false },
		{ Name = "animaChannelSelectSoundKit", Type = "number", Nilable = false },
		{ Name = "animaChannelActiveSoundKit", Type = "number", Nilable = false },
		{ Name = "animaGemsFullSoundKit", Type = "number", Nilable = false },
		{ Name = "animaNewGemSoundKit", Type = "number", Nilable = false },
		{ Name = "animaReinforceSelectSoundKit", Type = "number", Nilable = false },
		{ Name = "upgradeTabSelectSoundKitID", Type = "number", Nilable = false },
		{ Name = "reservoirFullSoundKitID", Type = "number", Nilable = false },
		{ Name = "beginResearchSoundKitID", Type = "number", Nilable = false },
		{ Name = "renownFanfareSoundKitID", Type = "number", Nilable = false },
		{ Name = "name", Type = "string", Nilable = false },
		{ Name = "soulbindIDs", Type = "table", InnerType = "number", Nilable = false },
	},

    Function = C_TaskQuest.GetQuestsForPlayerByMapID(uiMapID = {number}) returns: "taskPOIs"
    Name = "TaskPOIData",
	Type = "Structure",
	Fields =
    {
	    { Name = "questId", Type = "number", Nilable = false },
	    { Name = "x", Type = "number", Nilable = false },
	    { Name = "y", Type = "number", Nilable = false },
	    { Name = "inProgress", Type = "bool", Nilable = false },
	    { Name = "numObjectives", Type = "number", Nilable = false },
	    { Name = "mapID", Type = "number", Nilable = false },
	    { Name = "isQuestStart", Type = "bool", Nilable = false },
	    { Name = "isDaily", Type = "bool", Nilable = false },
	    { Name = "isCombatAllyQuest", Type = "bool", Nilable = false },
	    { Name = "childDepth", Type = "number", Nilable = true },
	},

    Function = C_QuestLog.GetInfo(questLogIndex = {number}) returns: "info"
    Name = "QuestInfo",
	Type = "Structure",
	Fields =
	{
		{ Name = "title", Type = "string", Nilable = false },
		{ Name = "questLogIndex", Type = "number", Nilable = false },
		{ Name = "questID", Type = "number", Nilable = false },
		{ Name = "campaignID", Type = "number", Nilable = true },
		{ Name = "level", Type = "number", Nilable = false },
		{ Name = "difficultyLevel", Type = "number", Nilable = false },
		{ Name = "suggestedGroup", Type = "number", Nilable = false },
		{ Name = "frequency", Type = "QuestFrequency", Nilable = true },
            Type = "Enumeration", NumValues = 3, MinValue = 0, MaxValue = 2,
	        Fields =
            {
		        { Name = "Default", Type = "QuestFrequency", EnumValue = 0 },
		        { Name = "Daily", Type = "QuestFrequency", EnumValue = 1 },
		        { Name = "Weekly", Type = "QuestFrequency", EnumValue = 2 },
	        },
		{ Name = "isHeader", Type = "bool", Nilable = false },
		{ Name = "isCollapsed", Type = "bool", Nilable = false },
		{ Name = "startEvent", Type = "bool", Nilable = false },
		{ Name = "isTask", Type = "bool", Nilable = false },
		{ Name = "isBounty", Type = "bool", Nilable = false },
		{ Name = "isStory", Type = "bool", Nilable = false },
		{ Name = "isScaling", Type = "bool", Nilable = false },
		{ Name = "isOnMap", Type = "bool", Nilable = false },
		{ Name = "hasLocalPOI", Type = "bool", Nilable = false },
		{ Name = "isHidden", Type = "bool", Nilable = false },
		{ Name = "isAutoComplete", Type = "bool", Nilable = false },
		{ Name = "overridesSortOrder", Type = "bool", Nilable = false },
		{ Name = "readyForTranslation", Type = "bool", Nilable = false, Default = true },
	},

    Function = C_QuestLog.GetQuestTagInfo(questID = {number}) returns: "info"
    Name = "QuestTagInfo",
	Type = "Structure",
	Fields =
	{
		{ Name = "tagName", Type = "string", Nilable = false },
		{ Name = "tagID", Type = "number", Nilable = false },
		{ Name = "worldQuestType", Type = "number", Nilable = true },
		{ Name = "quality", Type = "WorldQuestQuality", Nilable = true },
            Type = "Enumeration", NumValues = 3, MinValue = 0, MaxValue = 2,
			Fields =
			{
				{ Name = "Common", Type = "WorldQuestQuality", EnumValue = 0 },
				{ Name = "Rare", Type = "WorldQuestQuality", EnumValue = 1 },
				{ Name = "Epic", Type = "WorldQuestQuality", EnumValue = 2 },
			},
		{ Name = "tradeskillLineID", Type = "number", Nilable = true },
		{ Name = "isElite", Type = "bool", Nilable = true },
		{ Name = "displayExpiration", Type = "bool", Nilable = true },
	},

    Function = C_QuestLog.GetQuestsOnMap(uiMapID = {number}) returns: "quests"
    Name = "QuestOnMapInfo",
	Type = "Structure",
	Fields =
	{
		{ Name = "questID", Type = "number", Nilable = false },
		{ Name = "x", Type = "number", Nilable = false },
		{ Name = "y", Type = "number", Nilable = false },
		{ Name = "type", Type = "number", Nilable = false },
		{ Name = "isMapIndicatorQuest", Type = "bool", Nilable = false },
	},

    Function = C_QuestLog.GetQuestObjectives(questID = {number})
    Name = "QuestObjectiveInfo",
    Type = "Structure",
    Fields =
    {
    	{ Name = "text", Type = "string", Nilable = false },
    	{ Name = "type", Type = "string", Nilable = false },
    	{ Name = "finished", Type = "bool", Nilable = false },
    	{ Name = "numFulfilled", Type = "number", Nilable = false },
    	{ Name = "numRequired", Type = "number", Nilable = false },
    },

    Function = C_QuestLine.GetQuestLineInfo(questID = {number}, uiMapID = {number})
    Name = "QuestLineInfo",
	Type = "Structure",
	Fields =
	{
		{ Name = "questLineName", Type = "string", Nilable = false },
		{ Name = "questName", Type = "string", Nilable = false },
		{ Name = "questLineID", Type = "number", Nilable = false },
		{ Name = "questID", Type = "number", Nilable = false },
		{ Name = "x", Type = "number", Nilable = false },
		{ Name = "y", Type = "number", Nilable = false },
		{ Name = "isHidden", Type = "bool", Nilable = false },
		{ Name = "isLegendary", Type = "bool", Nilable = false },
		{ Name = "isDaily", Type = "bool", Nilable = false },
		{ Name = "isCampaign", Type = "bool", Nilable = false },
		{ Name = "floorLocation", Type = "QuestLineFloorLocation", Nilable = false },
	},

    -------------------------------------------------------------------------------------
        EVENTS
    -------------------------------------------------------------------------------------
    Name = "MinimapPing",
    Type = "Event",
    LiteralName = "MINIMAP_PING",
    Payload =
    {
    	{ Name = "unitTarget", Type = "string", Nilable = false },
    	{ Name = "y", Type = "number", Nilable = false },
    	{ Name = "x", Type = "number", Nilable = false },
    },

    Name = "CovenantChosen",
	Type = "Event",
	LiteralName = "COVENANT_CHOSEN",
	Payload =
	{
		{ Name = "covenantID", Type = "number", Nilable = false },
	},
]]