local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")
------------------------------------------------------------------------------------

local MAJOR, MINOR = "HereBeDragons-Pins-2.0", 8
assert(LibStub, MAJOR .. " requires LibStub")

local pins, _oldversion = LibStub:NewLibrary(MAJOR, MINOR)
if not pins then return end

local HBD = LibStub("HereBeDragons-2.0")

pins.updateFrame          = pins.updateFrame or CreateFrame("Frame")

-- storage for minimap pins
pins.minimapPins          = pins.minimapPins or {}
pins.activeMinimapPins    = pins.activeMinimapPins or {}
pins.minimapPinRegistry   = pins.minimapPinRegistry or {}

-- and worldmap pins
pins.worldmapPins         = pins.worldmapPins or {}
pins.worldmapPinRegistry  = pins.worldmapPinRegistry or {}
pins.worldmapPinsPool     = pins.worldmapPinsPool or CreateFramePool("FRAME")
pins.worldmapProvider     = pins.worldmapProvider or CreateFromMixins(MapCanvasDataProviderMixin)
pins.worldmapProviderPin  = pins.worldmapProviderPin or CreateFromMixins(MapCanvasPinMixin)

-- store a reference to the active minimap object
pins.Minimap = pins.Minimap or Cardinal

-- Data Constants
local WORLD_MAP_ID = 947

-- upvalue lua api
local cos, sin, max = math.cos, math.sin, math.max
local type, pairs = type, pairs

-- upvalue wow api
local GetPlayerFacing = GetPlayerFacing

-- upvalue data tables
local minimapPins         = pins.minimapPins
local activeMinimapPins   = pins.activeMinimapPins
local minimapPinRegistry  = pins.minimapPinRegistry

local worldmapPins        = pins.worldmapPins
local worldmapPinRegistry = pins.worldmapPinRegistry
local worldmapPinsPool    = pins.worldmapPinsPool
local worldmapProvider    = pins.worldmapProvider
local worldmapProviderPin = pins.worldmapProviderPin

local tableCache = setmetatable({}, {__mode='k'})

local function newCachedTable()
    local t = next(tableCache)
    if t then
        tableCache[t] = nil
    else
        t = {}
    end
    return t
end

local function recycle(t)
    tableCache[t] = true
end

-------------------------------------------------------------------------------------------
-- Minimap pin position logic

-- is the minimap indoors or outdoors
-- local indoors = GetCVar("minimapZoom")+0 == pins.Minimap:GetZoom() and "outdoor" or "indoor"

local minimapPinCount, queueFullUpdate = 0, false
local minimapScale, minimapShape, mapRadius, minimapWidth, minimapHeight, mapSin, mapCos
local lastZoom, lastFacing, lastXY, lastYY

-- % Primary Edits for POI movement on the HUD
local function drawMinimapPin(pin, data)

    local facing = GetPlayerFacing()
    local x, y, instance = HBD:GetPlayerWorldPosition()
    local vector, distance = HBD:GetWorldVector(instance, x, y, data.x, data.y)
    local value = deg(facing) - deg(vector)

    pin:Show()
    pin:SetPoint("CENTER", pins.Minimap, "CENTER", 0, 0) -- -diffY * minimapHeight)
    if (value > 0 and value < 180) or (value < 0 and value > -180) then
        pin:SetValue(value)
    elseif value <= -180 then
        pin:SetValue(value + 360)
    elseif value >= 180 then
        pin:SetValue(value - 360)
    end

end

local function IsParentMap(originMapId, toCheckMapId)
    local parentMapID = HBD.mapData[originMapId].parent
    while parentMapID and HBD.mapData[parentMapID] do
        local mapType = HBD.mapData[parentMapID].mapType
        if mapType ~= Enum.UIMapType.Zone and mapType ~= Enum.UIMapType.Dungeon and mapType ~= Enum.UIMapType.Micro then
            return false
        end
        if parentMapID == toCheckMapId then
            return true
        end
        parentMapID = HBD.mapData[parentMapID].parent
    end
    return false
end

local function UpdateMinimapPins(force)
    -- get the current player position
    local x, y, instanceID = HBD:GetPlayerWorldPosition()
    local mapID = HBD:GetPlayerZone()

    -- check for all values to be available (starting with 7.1.0, instances don't report coordinates)
    if not x or not y then
        minimapPinCount = 0
        for pin in pairs(activeMinimapPins) do
            pin:Hide()
            activeMinimapPins[pin] = nil
        end
        return
    end

    if x ~= lastXY or y ~= lastYY or force then

        for pin, data in pairs(minimapPins) do
            if data.instanceID == instanceID and (not data.uiMapID or data.uiMapID == mapID or (data.showInParentZone and IsParentMap(data.uiMapID, mapID))) then
                activeMinimapPins[pin] = data
                data.keep = true
                drawMinimapPin(pin, data)
            end
        end

        minimapPinCount = 0
        for pin, data in pairs(activeMinimapPins) do
            if not data.keep then
                pin:Hide()
                activeMinimapPins[pin] = nil
            else
                minimapPinCount = minimapPinCount + 1
                data.keep = nil
            end
        end
    end
end

local function UpdateMinimapIconPosition()
    --[[ get the current map  zoom
    local zoom = _zoom -- pins.Minimap:GetZoom()
    local diffZoom = zoom ~= lastZoom
    -- if the map zoom changed, run a full update sweep
    if diffZoom then
        UpdateMinimapPins()
        return
    end
    ]]
    -- we have no active minimap pins, just return early
    if minimapPinCount == 0 then return end

    local x, y = HBD:GetPlayerWorldPosition()

    -- for rotating minimap support
    local facing = GetPlayerFacing()

    --[[
    if rotateMinimap then
        facing = GetPlayerFacing()
    else
        facing = lastFacing
    end
    ]]

    -- check for all values to be available (starting with 7.1.0, instances don't report coordinates)
    if not x or not y or (rotateMinimap and not facing) then
        UpdateMinimapPins()
        return
    end

    --[[
    local refresh
    local newScale = pins.Minimap:GetScale()
    if minimapScale ~= newScale then
        minimapScale = newScale
        refresh = true
    end
    ]]

    if x ~= lastXY or y ~= lastYY or facing ~= lastFacing then -- or refresh then

        --[[
        -- update radius of the map
        if WoW90 then
            mapRadius = C_Minimap.GetViewRadius()
        else
            mapRadius = minimap_size[indoors][zoom] / 2
        end
        ]]

        -- update upvalues for icon placement
        lastXY, lastYY = x, y
        lastFacing = facing

        --[[
        if rotateMinimap then
            mapSin = sin(facing)
            mapCos = cos(facing)
        end
        ]]

        -- iterate all nodes and check if they are still in range of our minimap display
        for pin, data in pairs(activeMinimapPins) do
            -- update the position of the node
            drawMinimapPin(pin, data)
        end
    end
end

--[[ local function UpdateMinimapZoom()
    if not WoW90 then
        local zoom = _zoom -- pins.Minimap:GetZoom()
        if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
            pins.Minimap:SetZoom(zoom < 2 and zoom + 1 or zoom - 1)
        end
        indoors = GetCVar("minimapZoom")+0 == pins.Minimap:GetZoom() and "outdoor" or "indoor"
        pins.Minimap:SetZoom(zoom)
    end
end ]]

-------------------------------------------------------------------------------------------
-- WorldMap data provider

-- setup pin pool
worldmapPinsPool.parent = WorldMapFrame:GetCanvas()
worldmapPinsPool.creationFunc = function(framePool)
    local frame = CreateFrame(framePool.frameType, nil, framePool.parent)
    frame:SetSize(1, 1)
    return Mixin(frame, worldmapProviderPin)
end
worldmapPinsPool.resetterFunc = function(pinPool, pin)
    FramePool_HideAndClearAnchors(pinPool, pin)
    pin:OnReleased()

    pin.pinTemplate = nil
    pin.owningMap = nil
end

-- register pin pool with the world map
WorldMapFrame.pinPools["HereBeDragonsPinsTemplate"] = worldmapPinsPool

-- provider base API
function worldmapProvider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate("HereBeDragonsPinsTemplate")
end

function worldmapProvider:RemovePinByIcon(icon)
    for pin in self:GetMap():EnumeratePinsByTemplate("HereBeDragonsPinsTemplate") do
        if pin.icon == icon then
            self:GetMap():RemovePin(pin)
        end
    end
end

function worldmapProvider:RemovePinsByRef(ref)
    for pin in self:GetMap():EnumeratePinsByTemplate("HereBeDragonsPinsTemplate") do
        if pin.icon and worldmapPinRegistry[ref][pin.icon] then
            self:GetMap():RemovePin(pin)
        end
    end
end

function worldmapProvider:RefreshAllData(fromOnShow)
    self:RemoveAllData()

    for icon, data in pairs(worldmapPins) do
        self:HandlePin(icon, data)
    end
end

function worldmapProvider:HandlePin(icon, data)
    local uiMapID = self:GetMap():GetMapID()

    -- check for a valid map
    if not uiMapID then return end

    local x, y
    if uiMapID == WORLD_MAP_ID then
        -- should this pin show on the world map?
        if uiMapID ~= data.uiMapID and data.worldMapShowFlag ~= HBD_PINS_WORLDMAP_SHOW_WORLD then return end

        -- translate to the world map
        x, y = HBD:GetAzerothWorldMapCoordinatesFromWorld(data.x, data.y, data.instanceID)
    else
        -- check that it matches the instance
        if not HBD.mapData[uiMapID] or HBD.mapData[uiMapID].instance ~= data.instanceID then return end

        if uiMapID ~= data.uiMapID then
            local mapType = HBD.mapData[uiMapID].mapType
            if not data.uiMapID then
                if mapType == Enum.UIMapType.Continent and data.worldMapShowFlag >= HBD_PINS_WORLDMAP_SHOW_CONTINENT then
                    --pass
                elseif mapType ~= Enum.UIMapType.Zone and mapType ~= Enum.UIMapType.Dungeon and mapType ~= Enum.UIMapType.Micro then
                    -- fail
                    return
                end
            else
                local show = false
                local parentMapID = HBD.mapData[data.uiMapID].parent
                while parentMapID and HBD.mapData[parentMapID] do
                    if parentMapID == uiMapID then
                        local parentMapType = HBD.mapData[parentMapID].mapType
                        -- show on any parent zones if they are normal zones
                        if data.worldMapShowFlag >= HBD_PINS_WORLDMAP_SHOW_PARENT and
                            (parentMapType == Enum.UIMapType.Zone or parentMapType == Enum.UIMapType.Dungeon or parentMapType == Enum.UIMapType.Micro) then
                            show = true
                        -- show on the continent
                        elseif data.worldMapShowFlag >= HBD_PINS_WORLDMAP_SHOW_CONTINENT and
                            parentMapType == Enum.UIMapType.Continent then
                            show = true
                        end
                        break
                        -- worldmap is handled above already
                    else
                        parentMapID = HBD.mapData[parentMapID].parent
                    end
                end

                if not show then return end
            end
        end

        -- translate coordinates
        x, y = HBD:GetZoneCoordinatesFromWorld(data.x, data.y, uiMapID)
    end
    if x and y then
        self:GetMap():AcquirePin("HereBeDragonsPinsTemplate", icon, x, y, data.frameLevelType)
    end
end

--  map pin base API
function worldmapProviderPin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 1.0, 1.2)
end

function worldmapProviderPin:OnAcquired(icon, x, y, frameLevelType)
    self:UseFrameLevelType(frameLevelType or "PIN_FRAME_LEVEL_AREA_POI")
    self:SetPosition(x, y)

    self.icon = icon
    icon:SetParent(self)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", self, "CENTER")
    icon:Show()
end

function worldmapProviderPin:OnReleased()
    if self.icon then
        self.icon:Hide()
        self.icon:SetParent(UIParent)
        self.icon:ClearAllPoints()
        self.icon = nil
    end
end

-- register with the world map
WorldMapFrame:AddDataProvider(worldmapProvider)

-- map event handling
local function UpdateMinimap()
    -- UpdateMinimapZoom()
    UpdateMinimapPins()
end

local last_update = 0
local function OnUpdateHandler(frame, elapsed)
    last_update = last_update + elapsed
    if last_update > 1 or queueFullUpdate then
        UpdateMinimapPins(queueFullUpdate)
        last_update = 0
        queueFullUpdate = false
    else
        UpdateMinimapIconPosition()
    end
end
pins.updateFrame:SetScript("OnUpdate", OnUpdateHandler)

local function OnEventHandler(frame, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        UpdateMinimap()
    end
end

pins.updateFrame:SetScript("OnEvent", OnEventHandler)
pins.updateFrame:UnregisterAllEvents()
pins.updateFrame:RegisterEvent("CVAR_UPDATE")
pins.updateFrame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
pins.updateFrame:RegisterEvent("PLAYER_LOGIN")
pins.updateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

HBD.RegisterCallback(pins, "PlayerZoneChanged", UpdateMinimap)

--- Add a icon to the minimap (x/y world coordinate version)
-- Note: This API does not let you specify a map to limit the pin to, it'll be shown on all maps these coordinates are valid for.
-- $param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- $param icon Icon Frame
-- $param instanceID Instance ID of the map to add the icon to
-- $param x X position in world coordinates
-- $param y Y position in world coordinates
-- $param floatOnEdge flag if the icon should float on the edge of the minimap when going out of range, or hide immediately (default false)
function pins:AddMinimapIconWorld(ref, icon, instanceID, x, y, floatOnEdge)
    if not ref then
        error(MAJOR..": AddMinimapIconWorld: 'ref' must not be nil", 2)
    end
    if type(icon) ~= "table" or not icon.SetPoint then
        error(MAJOR..": AddMinimapIconWorld: 'icon' must be a frame", 2)
    end
    if type(instanceID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        error(MAJOR..": AddMinimapIconWorld: 'instanceID', 'x' and 'y' must be numbers", 2)
    end

    if not minimapPinRegistry[ref] then
        minimapPinRegistry[ref] = {}
    end

    minimapPinRegistry[ref][icon] = true

    local t = minimapPins[icon] or newCachedTable()
    t.instanceID = instanceID
    t.x = x
    t.y = y
    t.floatOnEdge = floatOnEdge
    t.uiMapID = nil
    t.showInParentZone = nil

    minimapPins[icon] = t
    queueFullUpdate = true

    icon:SetParent(pins.Minimap)
end

--- Add a icon to the minimap (UiMapID zone coordinate version)
-- The pin will only be shown on the map specified, or optionally its parent map if specified
-- $param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- $param icon Icon Frame
-- $param uiMapID uiMapID of the map to place the icon on
-- $param x X position in local/point coordinates (0-1), relative to the zone
-- $param y Y position in local/point coordinates (0-1), relative to the zone
-- $param showInParentZone flag if the icon should be shown in its parent zone - ie. an icon in a microdungeon in the outdoor zone itself (default false)
-- $param floatOnEdge flag if the icon should float on the edge of the minimap when going out of range, or hide immediately (default false)
function pins:AddMinimapIconMap(ref, icon, uiMapID, x, y, showInParentZone, floatOnEdge)
    if not ref then
        error(MAJOR..": AddMinimapIconMap: 'ref' must not be nil", 2)
    end
    if type(icon) ~= "table" or not icon.SetPoint then
        error(MAJOR..": AddMinimapIconMap: 'icon' must be a frame", 2)
    end
    if type(uiMapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        error(MAJOR..": AddMinimapIconMap: 'uiMapID', 'x' and 'y' must be numbers", 2)
    end

    -- convert to world coordinates and use our known adding function
    local xCoord, yCoord, instanceID = HBD:GetWorldCoordinatesFromZone(x, y, uiMapID)
    if not xCoord then return end

    self:AddMinimapIconWorld(ref, icon, instanceID, xCoord, yCoord, floatOnEdge)

    -- store extra information
    minimapPins[icon].uiMapID = uiMapID
    minimapPins[icon].showInParentZone = showInParentZone
end

--- Remove a minimap icon
-- $param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- $param icon Icon Frame
function pins:RemoveMinimapIcon(ref, icon)
    if not ref or not icon or not minimapPinRegistry[ref] then return end
    minimapPinRegistry[ref][icon] = nil
    if minimapPins[icon] then
        recycle(minimapPins[icon])
        minimapPins[icon] = nil
        activeMinimapPins[icon] = nil
    end
    icon:Hide()
end

--- Remove all minimap icons belonging to your addon (as tracked by "ref")
-- $param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
function pins:RemoveAllMinimapIcons(ref)
    if not ref or not minimapPinRegistry[ref] then return end
    for icon in pairs(minimapPinRegistry[ref]) do
        recycle(minimapPins[icon])
        minimapPins[icon] = nil
        activeMinimapPins[icon] = nil
        icon:Hide()
    end
    wipe(minimapPinRegistry[ref])
end

--- Set the minimap object to position the pins on. Needs to support the usual functions a Minimap-type object exposes.
-- $param minimapObject The new minimap object, or nil to restore the default
function pins:SetMinimapObject(minimapObject)
    pins.Minimap = minimapObject or Cardinal
    for pin in pairs(minimapPins) do
        pin:SetParent(pins.Minimap)
    end
    UpdateMinimapPins(true)
end

-- world map constants
-- show worldmap pin on its parent zone map (if any)
HBD_PINS_WORLDMAP_SHOW_PARENT    = 1
-- show worldmap pin on the continent map
HBD_PINS_WORLDMAP_SHOW_CONTINENT = 2
-- show worldmap pin on the continent and world map
HBD_PINS_WORLDMAP_SHOW_WORLD     = 3

--- Return the angle and distance from the player to the specified pin
-- $param icon icon object (minimap or worldmap)
-- $return angle, distance where angle is in radians and distance in yards
function pins:GetVectorToIcon(icon)
    if not icon then return nil, nil end
    local data = minimapPins[icon] or worldmapPins[icon]
    if not data then return nil, nil end

    local x, y, instance = HBD:GetPlayerWorldPosition()
    if not x or not y or instance ~= data.instanceID then return nil end

    return HBD:GetWorldVector(instance, x, y, data.x, data.y)
end