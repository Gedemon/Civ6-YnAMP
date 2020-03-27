------------------------------------------------------------------------------
--	FILE:	 YnAMP_Script.lua
--  Gedemon (2016-2019)
------------------------------------------------------------------------------

local YnAMP_Version = GameInfo.GlobalParameters["YNAMP_VERSION"].Value
print ("Yet (not) Another Maps Pack version " .. tostring(YnAMP_Version) .." (2016-2019) by Gedemon")
print ("loading YnAMP_Script.lua")

include "MapEnums"
include "PlotIterators"
include "YnAMP_Common"

function Round(num)
    under = math.floor(num)
    upper = math.floor(num) + 1
    underV = -(under - num)
    upperV = upper - num
    if (upperV > underV) then
        return under
    else
        return upper
    end
end


local mapName = MapConfiguration.GetValue("MapName")
print ("Map Name = " .. tostring(mapName))

local bAutoCityNaming 			= MapConfiguration.GetValue("AutoCityNaming")
local bCanUseCivSpecificName 	= not (MapConfiguration.GetValue("OnlyGenericCityNames"))

local IsCityOnMap 			= {} -- helper to check by name if a city has a position set on the city map
local CityPosition			= {} -- helper to get the first defined position in the city map of a city (by name)

local NotCityPlot			= {} -- helper to store all plots that are too close from other cities
local PlayersSettings		= {} -- player specific setting and variables
local CivTypePlayerID 		= {} -- helper to get playerID <-> CivilizationType
local RouteIndexForEra		= {} -- helper to get the best RouteType for a specific era
local IsTemporaryStartPos	= {} -- helper to check if a Civ "alive" was placed only to prevent the crash from civilizations without starting position
local AliveList				= {} -- helper to get the list of civilization minus the fake starting position civs

local numCitiesOnMap		= 0
local g_MaxDistance			= 999

--[[
local bUseRelativePlacement 	= MapConfiguration.GetValue("UseRelativePlacement")
local bUseRelativeFixedTable 	= bUseRelativePlacement and MapConfiguration.GetValue("UseRelativeFixedTable")
local g_ReferenceMapWidth 		= MapConfiguration.GetValue("ReferenceMapWidth") or 180
local g_ReferenceMapHeight 		= MapConfiguration.GetValue("ReferenceMapHeight") or 94

local g_iW, g_iH 	= Map.GetGridSize()

local g_UncutMapWidth 	= MapConfiguration.GetValue("UncutMapWidth") or g_iW
local g_UncutMapHeight 	= MapConfiguration.GetValue("UncutMapHeight") or g_iH

local g_OffsetX 		= MapConfiguration.GetValue("StartX") or 0
local g_OffsetY 		= MapConfiguration.GetValue("StartY") or 0
local bUseOffset		= (g_OffsetX + g_OffsetY > 0) and (MapConfiguration.GetValue("StartX") ~= MapConfiguration.GetValue("EndX")) and (MapConfiguration.GetValue("StartY") ~= MapConfiguration.GetValue("EndY"))

local g_ReferenceWidthFactor  = g_ReferenceMapWidth / g_UncutMapWidth 
local g_ReferenceHeightFactor = g_ReferenceMapHeight / g_UncutMapHeight
local g_ReferenceWidthRatio   = g_UncutMapWidth / g_ReferenceMapWidth 
local g_ReferenceHeightRatio  = g_UncutMapHeight / g_ReferenceMapHeight
--]]
SetGlobals()

local g_ExtraRange = 0
if bUseRelativePlacement then
	g_ExtraRange = 10 --Round(10 * math.sqrt(g_iW * g_iH) / math.sqrt(g_ReferenceMapWidth * g_ReferenceMapHeight))
end

------------------------------------------------------------------------------
-- http://lua-users.org/wiki/SortedIteration
-- Ordered table iterator, allow to iterate on the natural order of the keys of a table.
------------------------------------------------------------------------------
function __genOrderedIndex( t )
    local orderedIndex = {}
    for key in pairs (t) do
        table.insert ( orderedIndex, key )
    end
    table.sort ( orderedIndex )
    return orderedIndex
end

function orderedNext(t, state)
    -- Equivalent of the next function, but returns the keys in the alphabetic
    -- order.  We use a temporary ordered key table that is stored in the
    -- table being iterated.

    local key = nil
    --print("orderedNext: state = "..tostring(state) )
    if state == nil then
        -- the first time, generate the index
        t.__orderedIndex = __genOrderedIndex( t )
        key = t.__orderedIndex[1]
    else
        -- fetch the next value
        for i = 1, #t.__orderedIndex do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end

    if key then
        return key, t[key]
    end

    -- no more value to return, cleanup
    t.__orderedIndex = nil
    return
end

function orderedPairs(t)
    -- Equivalent of the pairs() function on tables.  Allows to iterate
    -- in order
    return orderedNext, t, nil
end

--local pairs = orderedPairs

-- ===========================================================================
-- Fill helper tables
--
-- Those helpers are used for both the City AutoNaming and some of the Scenario generation options (CityMap placement or with the "Import" option when no position is defined in the Scenario)
-- ===========================================================================
for row in GameInfo.CityMap() do
	local name = row.CityLocaleName
	if mapName == row.MapName then
		if name then
			if not IsCityOnMap[name] then
				IsCityOnMap[name] 					= true
				IsCityOnMap[Locale.Lookup(name)] 	= true
				CityPosition[name] 					= {X = row.X, Y = row.Y }
				CityPosition[Locale.Lookup(name)] 	= {X = row.X, Y = row.Y }
			else
				averageX = (CityPosition[name].X + row.X) / 2
				averageY = (CityPosition[name].Y + row.Y) / 2
				CityPosition[name] 					= {X = averageX, Y = averageY }
				CityPosition[Locale.Lookup(name)] 	= {X = averageX, Y = averageY }
			end
		else
			print("ERROR : no name at row "..tostring(row.Index + 1))
		end
	end
end

-- Initialize players tables
print("Pairing Civilization Type with PlayerIDs...")
for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do -- for _, iPlayer in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
	local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
	if CivilizationTypeName then
		CivTypePlayerID[CivilizationTypeName]	= iPlayer
		CivTypePlayerID[iPlayer] 				= CivilizationTypeName
	else
		print("WARNING for playerID #"..tostring(iPlayer).." : CivilizationTypeName is NIL")
	end
end

------------------------------------------------------------------------------
-- Math functions
------------------------------------------------------------------------------
function GetShuffledCopyOfTable(incoming_table)
	-- Designed to operate on tables with no gaps. Does not affect original table.
	local len = table.maxn(incoming_table);
	local copy = {};
	local shuffledVersion = {};
	-- Make copy of table.
	for loop = 1, len do
		copy[loop] = incoming_table[loop];
	end
	-- One at a time, choose a random index from Copy to insert in to final table, then remove it from the copy.
	local left_to_do = table.maxn(copy);
	for loop = 1, len do
		local random_index = 1 + TerrainBuilder.GetRandomNumber(left_to_do, "Shuffling table entry - Lua");
		table.insert(shuffledVersion, copy[random_index]);
		table.remove(copy, random_index);
		left_to_do = left_to_do - 1;
	end
	return shuffledVersion
end

------------------------------------------------------------------------------
-- Map functions
------------------------------------------------------------------------------
function FindNearestPlayerCity( eTargetPlayer, iX, iY )

	local pCity = nil
    local iShortestDistance = 10000
	local pPlayer = Players[eTargetPlayer]
	if pPlayer then
		local pPlayerCities:table = pPlayer:GetCities()
		for i, pLoopCity in pPlayerCities:Members() do
			local iDistance = Map.GetPlotDistance(iX, iY, pLoopCity:GetX(), pLoopCity:GetY())
			if (iDistance < iShortestDistance) then
				pCity = pLoopCity
				iShortestDistance = iDistance
			end
		end
	else
		print ("WARNING : Player is nil in FindNearestPlayerCity for ID = ".. tostring(eTargetPlayer) .. "at" .. tostring(iX) ..","..tostring(iY))
	end

	if (not pCity) then
		print ("WARNING : No city found of player " .. tostring(eTargetPlayer) .. " in range of " .. tostring(iX) .. ", " .. tostring(iY));
	end
   
    return pCity, iShortestDistance;
end

function FindNearestCityForNewRoad( eTargetPlayer, iX, iY, bAllowForeign )

	local pCity 			= nil
    local iShortestDistance = 10000
	local pPlayer 			= Players[eTargetPlayer]
	local pPlot				= Map.GetPlot(iX, iY)
	
	function CheckForNearestCityWithoutRoadOf(iPlayer)
		local pPlayer = Players[iPlayer]
		if pPlayer then
			local pPlayerCities:table = pPlayer:GetCities()
			if pPlayerCities and pPlayerCities.Members then
				for i, pLoopCity in pPlayerCities:Members() do
					local pCityPlot = pLoopCity:GetPlot()
					if pPlot ~= pCityPlot and pPlot:GetArea() == pCityPlot:GetArea() then
						local iDistance 	= Map.GetPlotDistance(iX, iY, pLoopCity:GetX(), pLoopCity:GetY())
						local path			= GetRoadPath(pPlot, pCityPlot, "Road", nil, nil)
						local bNoShortPath	= not path or (#path > iDistance * 2) -- check path when there is no road or when an existing road length is more than double the straigth distance 
						if (iDistance < iShortestDistance and bNoShortPath) then
							pCity = pLoopCity
							iShortestDistance = iDistance
						end
					end
				end
			end
		else
			print ("WARNING : Player is nil in FindNearestPlayerCity for ID = ".. tostring(iPlayer) .. "at" .. tostring(iX) ..","..tostring(iY))
		end
	end
	
	if bAllowForeign then
		for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
			CheckForNearestCityWithoutRoadOf(iPlayer)
		end
	else
		CheckForNearestCityWithoutRoadOf(eTargetPlayer)
	end

	if (not pCity) then
		--print ("No city found of player " .. tostring(eTargetPlayer) .. " in range of " .. tostring(iX) .. ", " .. tostring(iY));
	end
   
    return pCity, iShortestDistance;
end

function ChangePlotOwner(pPlot, ownerID, cityID)
	local ownerID		= ownerID or -1
	local iX, iY		= pPlot:GetX(), pPlot:GetY()
	local CityManager	= WorldBuilder.CityManager or ExposedMembers.CityManager
	
	if not cityID and ownerID ~= -1 then
		local city	= FindNearestPlayerCity( ownerID, iX, iY )
		cityID		= city and city:GetID()
	end
	
	if CityManager then
		if ownerID ~= -1 then
			if cityID then
				CityManager():SetPlotOwner( iX, iY, false )
				CityManager():SetPlotOwner( iX, iY, ownerID, cityID)
			end
		else
			CityManager():SetPlotOwner( iX, iY, false )
		end
	else
		if ownerID ~= -1 then
			if cityID then
				pPlot:SetOwner(-1)
				pPlot:SetOwner(ownerID, cityID, true)
			end
		else
			pPlot:SetOwner(-1)
		end
	end
end


-----------------------------------------------------------------------------------------
-- Pathfinder Functions
-----------------------------------------------------------------------------------------
function GetRoadPath(plot, destPlot, sRoute, maxRange, iPlayer, bAllowHiddenRoute)
	
	local startPlot	= plot
	local closedSet = {}
	local openSet	= {}
	local comeFrom 	= {}
	local gScore	= {}
	local fScore	= {}
	
	local startNode	= startPlot
	local bestCost	= 0.10
	
	function GetPath(currentNode)
		local path 		= {}
		local seen 		= {}
		local current 	= currentNode
		local count 	= 0
		while true do
			local prev = comeFrom[current]
			if prev == nil then break end
			local plot 		= current
			local plotIndex = plot:GetIndex()
			table.insert(path, 1, plotIndex)
			current = prev
		 end
		table.insert(path, 1, startPlot:GetIndex())
		return path
	end
	
	gScore[startNode]	= 0
	fScore[startNode]	= Map.GetPlotDistance(startPlot:GetX(), startPlot:GetY(), destPlot:GetX(), destPlot:GetY())
	
	local currentNode = startNode
	while currentNode do
	
		local currentPlot 		= currentNode
		closedSet[currentNode] 	= true
		
		if currentPlot == destPlot then
			return GetPath(currentNode)
		end
		
		local neighbors = GetNeighbors(currentNode, iPlayer, sRoute, startPlot, destPlot, maxRange, bAllowHiddenRoute)
		for i, data in ipairs(neighbors) do
			local node = data.Plot
			if not closedSet[node] then
				if gScore[node] == nil then
					local nodeDistance = node:GetMovementCost() --1 --Map.GetPlotDistance(data.Plot:GetX(), data.Plot:GetY(), currentPlot:GetX(), currentPlot:GetY())

					if data.Plot:IsRiverCrossingToPlot(currentPlot) then nodeDistance = nodeDistance + 1 end
					if data.Plot:GetRouteType() ~= -1 then nodeDistance = nodeDistance * bestCost end -- to do : real cost
					
					local destDistance		= Map.GetPlotDistance(data.Plot:GetX(), data.Plot:GetY(), destPlot:GetX(), destPlot:GetY()) * bestCost
					local tentative_gscore 	= (gScore[currentNode] or math.huge) + nodeDistance
				
					table.insert (openSet, {Node = node, Score = tentative_gscore + destDistance})

					if tentative_gscore < (gScore[node] or math.huge) then
						local plot = node
						comeFrom[node] = currentNode
						gScore[node] = tentative_gscore
						fScore[node] = tentative_gscore + destDistance
					end
				end				
			end		
		end
		table.sort(openSet, function(a, b) return a.Score > b.Score; end)
		local data = table.remove(openSet)
		if data then
			local plot = data.Node
			currentNode = data.Node 
		else
			currentNode = nil
		end
	end
	
end

local routes = {"Land", "Road", "Railroad", "Coastal", "Ocean", "Submarine"}
function GetNeighbors(node, iPlayer, sRoute, startPlot, destPlot, maxRange, bAllowHiddenRoute)

	local neighbors 				= {}
	local plot 						= node
	
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
		
		if (adjacentPlot ~= nil) then
			
			local distanceFromStart = Map.GetPlotDistance(adjacentPlot:GetX(), adjacentPlot:GetY(), startPlot:GetX(), startPlot:GetY())
			if maxRange == nil or distanceFromStart <= maxRange then
			
				local distanceFromDest	= Map.GetPlotDistance(adjacentPlot:GetX(), adjacentPlot:GetY(), destPlot:GetX(), destPlot:GetY())				
				if maxRange == nil or distanceFromDest <= maxRange then
			
					local IsPlotRevealed 	= bAllowHiddenRoute
					local pPlayer 			= Players[iPlayer]
					if pPlayer then
						local pPlayerVis = PlayersVisibility[pPlayer:GetID()]
						if (pPlayerVis ~= nil) then
							if (pPlayerVis:IsRevealed(adjacentPlot:GetX(), adjacentPlot:GetY())) then -- IsVisible
							  IsPlotRevealed = true
							end
						end
					end
				
					if (pPlayer == nil or IsPlotRevealed) then
						local bAdd = false

						-- Be careful of order, must check for road before rail, and coastal before ocean
						if (sRoute == routes[1] and not( adjacentPlot:IsImpassable() or adjacentPlot:IsWater())) then
						  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is passable land")
						  bAdd = true
						elseif (sRoute == routes[2] and adjacentPlot:GetRouteType() ~= RouteTypes.NONE) then	
						  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is road")	
						  bAdd = true
						elseif (sRoute == routes[3] and adjacentPlot:GetRouteType() >= 1) then
						  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is railroad")
						  bAdd = true
						elseif (sRoute == routes[4] and adjacentPlot:GetTerrainType() == TERRAIN_COAST) then
						  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is Coast")
						  bAdd = true
						elseif (sRoute == routes[5] and adjacentPlot:IsWater()) then
						  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is Water")
						  bAdd = true
						elseif (sRoute == routes[6] and adjacentPlot:IsWater()) then
						  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is Water")
						  bAdd = true
						end

						-- Special case for water, a city on the coast counts as water
						if (not bAdd and (sRoute == routes[4] or sRoute == routes[5] or sRoute == routes[6])) then
						  bAdd = adjacentPlot:IsCity()
						end

						-- Check for impassable and blockaded tiles
						bAdd = bAdd and isPassable(adjacentPlot, sRoute) --and not isBlockaded(adjacentPlot, pPlayer, fBlockaded, pPlot)

						if (bAdd) then
							table.insert( neighbors, { Plot = adjacentPlot } )
						end
					end
				end
			end
		end
	end
	
	return neighbors
end

-- Is the plot passable for this route type ...
function isPassable(pPlot, sRoute)
  bPassable = true

	-- ... due to terrain, eg those covered in ice
	if (pPlot:GetFeatureType() == g_FEATURE_ICE) then
		if sRoute ~= routes[6] then
			bPassable = false
		end
	elseif pPlot:IsImpassable() then
		bPassable = false
	end

  return bPassable
end


------------------------------------------------------------------------------
-- Helpers for x,y positions when using a reference or offset map
------------------------------------------------------------------------------
--[[
local XFromRefMapX 	= {}
local YFromRefMapY 	= {}
local RefMapXfromX 	= {}
local RefMapYfromY 	= {}
local sX, sY 		= 0, 0
local lX, lY 		= 0, 0
local skipX, skipY	= MapConfiguration.GetValue("RescaleSkipX") or 999, MapConfiguration.GetValue("RescaleSkipY") or 999

--function BuildRefXY()
if bUseRelativeFixedTable then
	for x = 0, g_UncutMapWidth, 1 do
		--MapToConvert[x] = {}
		for y = 0, g_UncutMapHeight, 1 do
			--print (x, y, sX, sY, lX, lY)
			XFromRefMapX[x] = sX
			YFromRefMapY[y] = sY
			
			RefMapXfromX[sX] = x
			RefMapYfromY[sY] = y
			--MapToConvert[x][y] = SmallMap[sX][sY]
			lY = lY + 1
			if lY == skipY then
				lY = 0
			else
				sY = sY +1
			end
		end
		sY = 0
		lX = lX + 1
		if lX == skipX then
			lX = 0
		else
			sX = sX +1
		end
	end
end

-- Convert current map position to the corresponding position on the reference map
function GetRefMapXY(mapX, mapY, bOnlyOffset)
	local refMapX, refMapY = mapX, mapY
	if bUseRelativePlacement and (not bOnlyOffset) then
		if bUseRelativeFixedTable then
			refMapX 	= XFromRefMapX[mapX] --Round(g_ReferenceWidthFactor * mapX)
			refMapY 	= YFromRefMapY[mapY] --Round(g_ReferenceHeightFactor * mapY)
			if refMapX == nil or refMapY == nil then
				return -1, -1
			end
		else
			refMapX 	= Round(g_ReferenceWidthFactor * mapX)
			refMapY 	= Round(g_ReferenceHeightFactor * mapY)		
		end
	end
	if bUseOffset then
		refMapX = refMapX + g_OffsetX
		refMapY = refMapY + g_OffsetY
		
		-- the code below assume that the reference map is wrapX
		if refMapY >= g_UncutMapHeight then
			--refMapY = refMapY - g_UncutMapHeight
			refMapY = (2*g_UncutMapHeight) - refMapY - 1
			refMapX = refMapX + Round(g_UncutMapWidth / 2)
		end
		if refMapX >= g_UncutMapWidth then
			refMapX = refMapX - g_UncutMapWidth -- -1 ?
		end
	end
	return refMapX, refMapY
end

-- Convert the reference map position to the current map position
function GetXYFromRefMapXY(x, y, bOnlyOffset)
	if bUseRelativePlacement and (not bOnlyOffset) then
		if bUseRelativeFixedTable then
			x = RefMapXfromX[x]--Round( g_ReferenceWidthRatio * x)
			y = RefMapYfromY[y]--Round( g_ReferenceHeightRatio * y)
			if x == nil or y == nil then
				return -1, -1
			end
		else
			x = Round( g_ReferenceWidthRatio * x)
			y = Round( g_ReferenceHeightRatio * y)		
		end
	end
	if bUseOffset then
		x = x - g_OffsetX
		y = y - g_OffsetY
		
		-- the code below assume that the reference map is wrapX
		if y < 0 then 
			--y = y + g_iH - 1
			--y = y + g_iH
			--x = x + Round(g_iW / 2)
		end
		--if x < 0 then x = x + g_iW - 1 end
		--if x < 0 and Map.IsWrapX() then x = x + g_iW end
		if x < 0 then
			x = x + g_UncutMapWidth
		end
	end
	return x, y
end

function GetPlotFromRefMap(x, y, bOnlyOffset)
	return Map.GetPlot(GetXYFromRefMapXY(x,y, bOnlyOffset))
end
--]]
BuildRefXY()

function IncrementCityCount()
	numCitiesOnMap = numCitiesOnMap + 1
	print("City count = "..tostring(numCitiesOnMap))
end


------------------------------------------------------------------------------
-- Handling script with pauses
--
-- When Lua takes too much time to process something, it seems to cause the game to crash
-- so we're using coroutines that can yield during some time-consuming loops and resume
-- after a few ticks of gamecore (using Events.GameCoreEventPublishComplete)
------------------------------------------------------------------------------

local g_LastPause 		= 0
local g_TimeForPause	= 0.1	-- running time in seconds before yielding
local g_TickBeforeResume= 5		-- number of call to GameCoreEventPublishComplete before resuming the coroutine
local g_Tick			= 0
local bLoadScreenClosed	= false
local CoroutineList		= {}

function AddCoToList(newCo)
	print("Adding coroutine to script with pause :"..tostring(newCo))
	table.insert(CoroutineList, newCo)
end

function LaunchScriptWithPause()
	print("LaunchScriptWithPause")
	Events.GameCoreEventPublishComplete.Add( CheckTimer )
end
--Events.LoadScreenClose.Add( LaunchScriptWithPause ) -- launching the script when the load screen is closed, you can use your own events

function StopScriptWithPause() -- GameCoreEventPublishComplete is called frequently, keep it clean

	print("StopScriptWithPause")
	Events.GameCoreEventPublishComplete.Remove( CheckTimer )
end

function OnLoadScreenClose()
	bLoadScreenClosed = true
end
Events.LoadScreenClose.Add( OnLoadScreenClose ) 

function ChangePause(value)
	print("changing pause value to ", value)
	g_TimeForPause = value
end

function CheckCoroutinePause()
	if g_LastPause + g_TimeForPause < Automation.GetTime() then
		print("**** coroutine.yield at ", Automation.GetTime() - g_LastPause, g_TimeForPause)
		coroutine.yield()
		--return true
	end
end

function CheckTimer()

	g_Tick	= g_Tick + 1
	
	if #CoroutineList > 0 then -- show ticking only when there are Coroutine running
		print("**** Tick = ", g_Tick)
	end

	if g_Tick >= g_TickBeforeResume then
		local toRemove 	= {}
		g_Tick			= 0
		for i, runningCo in ipairs(CoroutineList) do
			if coroutine.status(runningCo)=="dead" then
				table.insert(toRemove, i)
			elseif coroutine.status(runningCo)=="suspended" then
				g_LastPause = Automation.GetTime()
				local ok, errorMsg = coroutine.resume(runningCo)
				if not ok then
					error("Error in co-routine : " .. errorMsg)
				end
			end
		end
		for _, i in ipairs(toRemove) do
			table.remove(CoroutineList, i)
		end
		if #CoroutineList == 0 and bLoadScreenClosed then
			StopScriptWithPause()
		end
	end
end


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Removing Civilizations that shouldn't have been placed <<<<<
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
if YnAMP.PlayerToRemove then
	for _, iPlayer in ipairs(YnAMP.PlayerToRemove) do
		local player 	= Players[iPlayer]
		local units		= player:GetUnits()
		if units then
			for i, unit in units:Members() do
				units:Destroy(unit)
			end
		end
		IsTemporaryStartPos[iPlayer] = true
	end
end

for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
	if not IsTemporaryStartPos[iPlayer] then
		table.insert(AliveList, iPlayer)
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Removin Civilizations >>>>>
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- City renaming <<<<<
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
if bAutoCityNaming then
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
print("Activating Auto City Naming...")
local nameUsed = {}
local nameUsedOnContinent = {}
local nameUsedByCivilization = {}

function SetExistingCityNames(excludingCity)
	nameUsedOnContinent = {}
	nameUsedByCivilization = {}
	for _, player_ID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		local player = Players[player_ID]
		local playerConfig = PlayerConfigurations[player_ID]
		local civilization = playerConfig:GetCivilizationTypeName()
		local playerCities = player:GetCities();
		for j, city in playerCities:Members() do
			if city ~= excludingCity then -- do not add the current name of the city we are renaming, in case it's valid at the city position.
				local plot = Map.GetPlot(city:GetX(), city:GetY())
				local continent = plot:GetContinentType()
				
				nameUsed[city:GetName()] = true
				nameUsed[Locale.Lookup(city:GetName())] = true
				
				if not nameUsedOnContinent[continent] then
					nameUsedOnContinent[continent] = {}
				end
				nameUsedOnContinent[continent][city:GetName()] = true
				nameUsedOnContinent[continent][Locale.Lookup(city:GetName())] = true
				
				if not nameUsedByCivilization[civilization] then
					nameUsedByCivilization[civilization] = {}
				end
				nameUsedByCivilization[civilization][city:GetName()] = true
				nameUsedByCivilization[civilization][Locale.Lookup(city:GetName())] = true
			end
		end		
	end
end

function IsNameUsedByCivilization(name, civilization)
	return nameUsedByCivilization[civilization] and (nameUsedByCivilization[civilization][name] or nameUsedByCivilization[civilization][Locale.Lookup(name)])
end

function IsNameUsedOnContinent(name, x, y)
	local plot = Map.GetPlot(x, y)
	local continent = plot:GetContinentType()
	return nameUsedOnContinent[continent] and (nameUsedOnContinent[continent][name] or nameUsedOnContinent[continent][Locale.Lookup(name)])
end

function ChangeCityName( ownerPlayerID, cityID)
	local pCity = CityManager.GetCity(ownerPlayerID, cityID)	
	if pCity then
		SetExistingCityNames(pCity)
		local mapX = pCity:GetX()
		local mapY = pCity:GetY()
		local refMapX, refMapY = GetRefMapXY(mapX, mapY)
		local CivilizationTypeName = PlayerConfigurations[ownerPlayerID]:GetCivilizationTypeName()
		local startPos, endPos = string.find(CivilizationTypeName, "CIVILIZATION_")
		local sCivSuffix = string.sub(CivilizationTypeName, endPos)
		print("Trying to find name for city of ".. tostring(CivilizationTypeName) .." at "..tostring(mapX)..","..tostring(mapY))
		local possibleName = {}
		local maxRange = 1
		local bestDistance = 99
		local bestDefaultDistance = 99
		local bestName = nil
		local bestDefaultName = nil
		local cityPlot = Map.GetPlot(mapX, mapY)
		for row in GameInfo.CityMap() do
			if row.MapName == mapName  then
				local name = row.CityLocaleName
				local nameX = row.X
				local nameY = row.Y
				local nameMaxDistance = (row.Area or maxRange) + g_ExtraRange
				-- rough selection in a square first before really testing distance
				if (math.abs(refMapX - nameX) <= nameMaxDistance) and (math.abs(refMapY - nameY) <= nameMaxDistance) then	
					--print("- testing "..tostring(name).." at "..tostring(nameX)..","..tostring(nameY).." max distance is "..tostring(nameMaxDistance)..", best distance so far is "..tostring(bestDistance))
					
					local distance = Map.GetPlotDistance(refMapX, refMapY ,nameX, nameY)
					if distance <= nameMaxDistance and distance < bestDistance then
					
						local sCityNameForCiv = tostring(name) .. sCivSuffix
					
						if bCanUseCivSpecificName and CivilizationTypeName == row.Civilization and not IsNameUsedByCivilization(name, CivilizationTypeName) then -- this city is specific to this Civilization, and the name is not already used
							bestDistance = distance
							bestName = name
						elseif not row.Civilization then -- do not use Civilization specific name with another Civilization, only generic							
							if bCanUseCivSpecificName and Locale.Lookup(sCityNameForCiv) ~= sCityNameForCiv and not IsNameUsedByCivilization(sCityNameForCiv, CivilizationTypeName) then -- means that this civilization has a specific name available for this generic city
								bestDistance = distance
								bestName = sCityNameForCiv
							elseif distance < bestDefaultDistance and not IsNameUsedOnContinent(name, mapX, mapY) then -- use generic name
								bestDefaultDistance = distance
								bestDefaultName = name
							end							
						end
					end	
				end
			end
		end
		if not bestName then
			bestName = bestDefaultName
		end
		if bestName then
			pCity:SetName(bestName)
			print("- New name : " .. tostring(bestName))
		else
			print("- Can't find a name for this position !")
			-- todo : use a name not reserved for the map
		end
	end
end
Events.CityInitialized.Add( ChangeCityName )

function ListCityWithoutLOC()
	for row in GameInfo.CityMap() do
		local name = row.CityLocaleName
		if name then
			if Locale.Lookup(name) == name then
				print("WARNING : no translation for "..tostring(name))
			end
		else
			print("ERROR : no name at row "..tostring(row.Index + 1))
		end
	end
end
Events.LoadScreenClose.Add( ListCityWithoutLOC )

function ListCityNotOnMap()
	for row in GameInfo.CityNames() do
		local name = row.CityName
		local civilization = row.CivilizationType
		if not (IsCityOnMap[name] or IsCityOnMap[Locale.Lookup(name)]) then
			print("Not mapped for "..tostring(civilization).." : "..tostring(name))
		end
	end
end
Events.LoadScreenClose.Add( ListCityNotOnMap )

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- City renaming >>>>>
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- EnforcingTSL <<<<<
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
if MapConfiguration.GetValue("ForceTSL") and MapConfiguration.GetValue("ForceTSL") ~= "FORCE_TSL_OFF" then
----------------------------------------------------------------------------------------
print("Enforcing TSL...")
function ForceTSL( iPrevPlayer )

	if Game.GetCurrentGameTurn() > GameConfiguration.GetStartTurn() then -- only called on first turn
		Events.PlayerTurnDeactivated.Remove( ForceTSL )
		return
	end
	
	local bForceAll = (MapConfiguration.GetValue("ForceTSL") == "FORCE_TSL_ALL")
	local bForceAI = (MapConfiguration.GetValue("ForceTSL") == "FORCE_TSL_AI") or bForceAll
	local bForceCS = (MapConfiguration.GetValue("ForceTSL") == "FORCE_TSL_CS") or bForceAI
	
	local iPlayer = iPrevPlayer + 1
	local player = Players[iPlayer]
	if player and player:WasEverAlive() and player:GetCities():GetCount() == 0	
	   and ((not player:IsMajor() and bForceCS) or (player:IsMajor() and (not player:IsHuman()) and bForceAI) or (player:IsHuman() and bForceAll))
	   and not player:IsBarbarian() then
		print("- Checking for Settler on TSL for player #".. tostring(iPlayer))
		local startingPlot = player:GetStartingPlot()
		if startingPlot and not startingPlot:IsCity() and not startingPlot:IsWater() then
			local unitsInPlot = Units.GetUnitsInPlot(startingPlot)
			if unitsInPlot ~= nil then
				for _, unit in ipairs(unitsInPlot) do
					if unit:GetType() == GameInfo.Units["UNIT_SETTLER"].Index then
						print("  - found Settler !")
						print("  - create city here...")
						local city = player:GetCities():Create(startingPlot:GetX(), startingPlot:GetY())
						if city then
							print ("  - deleting settler...")
							player:GetUnits():Destroy(unit)
							IncrementCityCount()
						else
							print ("  - WARNING : city is nil (tried to place at plot ".. tostring(startingPlot:GetX())..","..tostring(startingPlot:GetY()))
						end
					end
				end
			end		
		end	
	end
end
Events.PlayerTurnDeactivated.Add( ForceTSL ) -- On TurnActivated, it seems the AI has already moved the initial settler...

function OnEnterGame()
	ForceTSL( -1 ) -- test ForceTSL on player 0
end
Events.LoadScreenClose.Add(OnEnterGame)
----------------------------------------------------------------------------------------
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- EnforcingTSL >>>>>
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Limiting Barbarian Scouts <<<<<
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
if GameConfiguration.GetValue("TurnsBeforeBarbarians") and GameConfiguration.GetValue("TurnsBeforeBarbarians") > 0 and GameInfo.Units["UNIT_SCOUT"] then 
----------------------------------------------------------------------------------------

print("Limiting Barbarian Scouts is ON...")
function OnUnitAddedToMap( playerID:number, unitID:number )
	local unit 				= UnitManager.GetUnit(playerID, unitID)
	local player 			= Players[playerID]
	local turnsFromStart 	= Game.GetCurrentGameTurn() - GameConfiguration.GetStartTurn()
	if unit and player and unit:GetType() == GameInfo.Units["UNIT_SCOUT"].Index and player:IsBarbarian() and turnsFromStart < GameConfiguration.GetValue("TurnsBeforeBarbarians") then
		print("Removing Barbarian Scout at turn #"..tostring(Game.GetCurrentGameTurn()) ..", not allowed until turn #"..tostring(GameConfiguration.GetStartTurn()+GameConfiguration.GetValue("TurnsBeforeBarbarians")))
		player:GetUnits():Destroy(unit)
	end
end
Events.UnitAddedToMap.Add(OnUnitAddedToMap)

----------------------------------------------------------------------------------------
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Limiting Barbarian Scouts >>>>>
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Scenario Placement  <<<<<
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
if MapConfiguration.GetValue("ScenarioType") ~= "SCENARIO_NONE" then --and not GameConfiguration.IsWorldBuilderEditor() then	--if not Game:GetProperty("YnAMP_ScenarioInitialized") then -- can't use YnAMP_ScenarioInitialized if we want to use a kind of reinforcement table
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Scenario Settings
local startingEraType			= GameInfo.Eras[GameConfiguration.GetStartEra()].EraType
local scenarioName 				= MapConfiguration.GetValue("ScenarioType")
local cityPlacement 			= MapConfiguration.GetValue("CityPlacement")
local borderPlacement			= MapConfiguration.GetValue("BorderPlacement")
local borderMaxDistance			= MapConfiguration.GetValue("BorderMaxDistance")
local borderAbsoluteMaxDistance	= borderMaxDistance or g_MaxDistance
local infrastructurePlacement	= MapConfiguration.GetValue("InfrastructurePlacement")
local numberOfMajorCity			= MapConfiguration.GetValue("NumberOfCity")
local numberOfMinorCity			= MapConfiguration.GetValue("NumberOfMinorCity")
local capitalSize				= MapConfiguration.GetValue("CapitalSize")
local otherCitySize				= MapConfiguration.GetValue("OtherCitySize")
local bDecreaseOtherCitySize	= MapConfiguration.GetValue("DecreaseOtherCitySize")
local citySizeDecrement			= MapConfiguration.GetValue("CitySizeDecrement")
local numCityPerSizeDecrement	= MapConfiguration.GetValue("NumCityPerSizeDecrement")
local roadPlacement				= MapConfiguration.GetValue("RoadPlacement")
local bInternationalRoads		= MapConfiguration.GetValue("InternationalRoads")
local roadMaxDistance			= MapConfiguration.GetValue("RoadMaxDistance")
local maxRoadPerCity			= MapConfiguration.GetValue("MaxRoadPerCity")
local maxDistanceFromCapital	= MapConfiguration.GetValue("MaxDistanceFromCapital")
local onlySameLandMass			= MapConfiguration.GetValue("OnlySameLandMass")

print("===========================================================================")
print("Scenario Settings")
print("===========================================================================")
print("Scenario Name : ", scenarioName)
print("City Placement 	: ", cityPlacement)
print("Border Placement : ", borderPlacement)
print("Number Major Cities : ", numberOfMajorCity)
print("Number Minor Cities : ", numberOfMinorCity)
print("WorldBuilder.CityManager : ", WorldBuilder.CityManager)
print("ExposedMembers.CityManager : ", ExposedMembers.CityManager)


-- ===========================================================================
-- Get a RouteIndex for each Era
print("Initializing the RouteIndexForEra table...")
for eraRow in GameInfo.Eras() do

	-- Searching best route type available for that era
	local bestEraRoute = nil
	for testRouteRow in GameInfo.Routes() do
	
		local testEraRow = testRouteRow.PrereqEra and GameInfo.Eras[testRouteRow.PrereqEra]
	
		-- If we already know of a possible route from a previous loop...
		if bestEraRoute then
		
			-- ... and the new route PlacementValue > previous route ...
			if (testRouteRow.PlacementValue > bestEraRoute.PlacementValue) then
			
				-- ... and the new route has a prereqEra and that era is coming before or is the current era...
				if testEraRow then
					if testEraRow.ChronologyIndex <= eraRow.ChronologyIndex then
						-- ... mark it as the new best candidate
						bestEraRoute = testRouteRow
					end
					
				-- when there is no prereqEra for the new route with a better placement value...
				else
					-- ... mark it as the new best candidate
					bestEraRoute = testRouteRow
				end
			end
			
		-- If there is no known route yet...
		else
			-- ... and there is no prereqEra for the tested route or if that prereqEra is coming before or is the current eraRow...
			if testRouteRow.PrereqEra == nil or (testEraRow and testEraRow.ChronologyIndex <= eraRow.ChronologyIndex) then
				-- ... mark it as the new best candidate
				bestEraRoute = testRouteRow
			end
		end
	end
	
	RouteIndexForEra[eraRow.EraType] = bestEraRoute and bestEraRoute.Index
end

-- ===========================================================================
-- Function to check if the data in a row is valid for the current game setting, return true (with a matching level as second parameter, higher is better) or nil
--[[
	Row without scenario name: 
		Valid if the map name is matching, even when no scenario are selected 
	Row without map name:
		Valid if the scenario name match the selected scenario, for all map 
		usefull for a multi-map scenario setting using city names, city sizes, number of buildings, etc... but without specific coordinates, thoses are determined by matching the CityMap table or generated.
	Row with both scenario and map name:
		Valid only if both match the selected scenario and map
	Row without scenario or map name:
		always valid but output a warning to the log 
--]] 
function IsRowValid(row, bWithLevel)
	if not row then return false end
--print(row.SpecificEra, row.ScenarioName, row.MapName)
--print(startingEraType, scenarioName, mapName)
	if not (row.ScenarioName) and not (row.MapName) then
		print("Warning at rowID #"..tostring(row.Index).." : ScenarioName AND MapName are NULL, this is a wild row, valid on all maps/scenario :")
		for k, v in pairs(row) do print("  - ", k, v) end
	end
	
	if not bWithLevel then
		return (row.SpecificEra == nil or row.SpecificEra == startingEraType) and (row.ScenarioName == nil or row.ScenarioName == scenarioName) and (row.MapName == nil or row.MapName == mapName)
	end
	
	local matchLevel = 0
	
	if row.MapName then
		if row.MapName == mapName then
			matchLevel = matchLevel + 1
		else
			return false
		end
	end
	
	if row.SpecificEra then
		if row.SpecificEra == startingEraType then
			matchLevel = matchLevel + 1
		else
			return false
		end
	end
	
	if row.ScenarioName then
		if row.ScenarioName == scenarioName then
			matchLevel = matchLevel + 3
		else
			return false
		end
	end
	
	return true, matchLevel
	
end


-- ===========================================================================
-- Function to check if the row is valid for a player type (Human or AI)
function CanPlace(row, player)
	return player and ((player:IsHuman() and (not row.OnlyAI)) or ((not player:IsHuman()) and (not row.OnlyHuman)))
end


-- ===========================================================================
-- Function to get the best CivilizationType's row for the current scenario, map and starting era
-- this allow multiple presets for the same Civilization, the scenario generator will pick the (first found) that match most parameters
function GetScenarioRow(CivilizationType)
	if not CivilizationType then return nil end
	local matchingRow	= nil
	local matchingLevel = -1
	for row in GameInfo.ScenarioCivilizations() do
		if row.CivilizationType == CivilizationType then
			local bReturnMatchingLevel 		= true
			local bIsValid, newMatchLevel 	= IsRowValid(row, bReturnMatchingLevel)
print("GetScenarioRow:", row.Index, CivilizationType, bIsValid, newMatchLevel)
print("----------------------------")
			if bIsValid then
				if newMatchLevel > matchingLevel then --matchingRow == nil or newMatchLevel > matchingLevel then
					matchingRow 	= row
					matchingLevel	= newMatchLevel
				end
			end
		end
	end
	return matchingRow
end


-- ===========================================================================
-- Set Scenario Players options and variables

local ScenarioPlayer		= {}
local bDoCapitalPlacement	= false
local bDoImportPlacement	= false
local bDoCityNamePlacement	= false
local bDoTerrainPlacement	= false
local bDoRoadPlacement		= false
local PlacementImport		= {}
local PlacementCityMap		= {}
local PlacementTerrain		= {}
local CapitalPlacement		= {}

function SetScenarioPlayers()
	
	-- Settings belows are set at scenario/setup level and override civilization settings
	-- In ScenarioCivilizations table only PLACEMENT_IMPORT, PLACEMENT_CITY_MAP, PLACEMENT_TERRAIN and PLACEMENT_MIXED are used
	
	local bOnlyImport			= cityPlacement == "PLACEMENT_IMPORT_ONLY"
	local bOnlyCityMap			= cityPlacement == "PLACEMENT_CITY_MAP_ONLY"
	local bOnlyGenerated		= cityPlacement == "PLACEMENT_TERRAIN_ONLY"
	local bImport				= cityPlacement == "PLACEMENT_IMPORT"
	local bCityMap				= cityPlacement == "PLACEMENT_CITY_MAP"
	local bGenerated			= cityPlacement == "PLACEMENT_TERRAIN"
	local bMixed				= cityPlacement == "PLACEMENT_MIXED"
	local bImportValid			= not (bOnlyCityMap or bOnlyGenerated)
	local bCityMapValid			= not (bOnlyGenerated or bOnlyImport)
	local bGeneratedValid		= not (bOnlyCityMap or bOnlyImport)
	
	-- We allow placement type per civilization from ScenarioCivilization table, building a player table for each placement type then,
	-- in the placement functions, loop each players using that type...
	-- We place Import first, then by name, then by terrain
	-- players with "PLACEMENT_MIXED" setting are in all tables
	
	for _, iPlayer in ipairs(AliveList) do -- for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local civilizationType	= CivTypePlayerID[iPlayer]
		if civilizationType then
			ScenarioPlayer[iPlayer]	= {}
			local playerData		= ScenarioPlayer[iPlayer]
			local ScenarioRow		= GetScenarioRow(civilizationType)
			local player			= Players[iPlayer]
			local bIsMajor			= player and player:IsMajor()
			local bIsMinor			= player and (not bIsMajor) and (not player:IsBarbarian())
			
			print("Scenario settings for "..tostring(civilizationType))
			if ScenarioRow then
				print("ScenarioRow:")
				for key, value in orderedPairs(ScenarioRow) do
					print(" - ", key, value)
					playerData[key] = value
				end
				print("-----")
			else
				print("No Scenario row")
			end
			
			-- a placement type is possible if : 
			-- (1) it's allowed at scenario/setup level AND
			-- (2) it's also set at Civilization level or is default value at scenario/setup level if the option is nil at the Civilization level 
			local bNoCityPlacement 			= not (ScenarioRow and ScenarioRow.CityPlacement)
			
			playerData.CityUseImport		= bImportValid		and ((ScenarioRow and (ScenarioRow.CityPlacement == "PLACEMENT_IMPORT"	or ScenarioRow.CityPlacement == "PLACEMENT_MIXED")) 	or (bNoCityPlacement and bImport)		or (bNoCityPlacement and bMixed))
			playerData.CityUseCityMap		= bCityMapValid		and ((ScenarioRow and (ScenarioRow.CityPlacement == "PLACEMENT_CITY_MAP" or ScenarioRow.CityPlacement == "PLACEMENT_MIXED"))	or (bNoCityPlacement and bCityMap)		or (bNoCityPlacement and bMixed))
			playerData.CityUseTerrain		= bGeneratedValid	and ((ScenarioRow and (ScenarioRow.CityPlacement == "PLACEMENT_TERRAIN"	or ScenarioRow.CityPlacement == "PLACEMENT_MIXED"))		or (bNoCityPlacement and bGenerated)	or (bNoCityPlacement and bMixed))
			
			playerData.PlaceCapital			= ((ScenarioRow and (ScenarioRow.CityPlacement == "PLACEMENT_TERRAIN" or ScenarioRow.CityPlacement == "PLACEMENT_MIXED")) or bGenerated or bMixed)

			playerData.CitiesToPlace		= (ScenarioRow and ScenarioRow.NumberOfCity) or (bIsMajor and numberOfMajorCity) or (bIsMinor and numberOfMinorCity) -- can be nil, which means unlimited.
			playerData.Priority				= (ScenarioRow and ScenarioRow.Priority) or (bIsMajor and 1) or (bIsMinor and 0) or -1
			
			playerData.CapitalSize			= playerData.CapitalSize or capitalSize
			playerData.OtherCitySize		= playerData.OtherCitySize or otherCitySize
			
			playerData.CitySizeDecrement 		= playerData.CitySizeDecrement or (bDecreaseOtherCitySize and citySizeDecrement)
			playerData.NumCityPerSizeDecrement	= playerData.NumCityPerSizeDecrement or (bDecreaseOtherCitySize and numCityPerSizeDecrement)
			
			playerData.StartingPlot 	= player and player:GetStartingPlot()
			
			playerData.RoadPlacement 		= playerData.RoadPlacement or roadPlacement
			playerData.InternationalRoads 	= playerData.InternationalRoads or bInternationalRoads
			playerData.RoadMaxDistance 		= playerData.RoadMaxDistance or roadMaxDistance
			playerData.MaxRoadPerCity 		= playerData.MaxRoadPerCity or maxRoadPerCity or 1
			
			playerData.BorderMaxDistance 	= (ScenarioRow and ScenarioRow.BorderMaxDistance) or (bIsMajor and borderMaxDistance) or (bIsMinor and 1)
			
			playerData.MaxDistanceFromCapital 	= playerData.MaxDistanceFromCapital or maxDistanceFromCapital or 1
			playerData.OnlySameLandMass 		= playerData.OnlySameLandMass or OnlySameLandMass or false
			
			playerData.RouteIndex 			= (playerData.SpecificEra and RouteIndexForEra[playerData.SpecificEra]) or RouteIndexForEra[startingEraType]
			
			if playerData.CityUseImport or bOnlyImport then
				bDoImportPlacement	= true
				table.insert(PlacementImport, {Player = iPlayer, Priority = playerData.Priority})
			end
			if playerData.CityUseCityMap or bOnlyCityMap then
				bDoCityNamePlacement = true
				table.insert(PlacementCityMap, {Player = iPlayer, Priority = playerData.Priority})
			end
			if playerData.CityUseTerrain or bOnlyGenerated then
				bDoTerrainPlacement = true
				table.insert(PlacementTerrain, {Player = iPlayer, Priority = playerData.Priority})
			end
			if playerData.RoadPlacement and playerData.RoadPlacement ~= "PLACEMENT_EMPTY" then
				bDoRoadPlacement = true
			end
			if playerData.PlaceCapital then
				bDoCapitalPlacement = true
				table.insert(CapitalPlacement, {Player = iPlayer, Priority = playerData.Priority})
			end
			if playerData.BorderMaxDistance and playerData.BorderMaxDistance > borderAbsoluteMaxDistance then
				borderAbsoluteMaxDistance = playerData.BorderMaxDistance
			end
			
			for key, value in orderedPairs(playerData) do
				print(" - ", key, value)
			end
		end
	end
end


-- ===========================================================================
-- City Placement Weight
function GetPlotFertility(plot)
	-- Calculate the fertility of the plot
	local iRange 					= 3
	local pPlot 					= plot
	local plotX 					= pPlot:GetX()
	local plotY 					= pPlot:GetY()
	local iProductionYieldWeight	= 3
	local iFoodYieldWeight 			= 5

	local gridWidth, gridHeight = Map.GetGridSize()
	local gridHeightMinus1 = gridHeight - 1

	local iFertility = 0
	
	--Rivers are awesome to start next to
	local terrainType = pPlot:GetTerrainType()
	if(pPlot:IsFreshWater() == true and terrainType ~= g_TERRAIN_TYPE_SNOW and terrainType ~= g_TERRAIN_TYPE_SNOW_HILLS and pPlot:IsImpassable() ~= true) then
		iFertility = iFertility + 50
		if pPlot:IsRiver() == true then
			iFertility = iFertility + 50
		end
	end	
	
	for dx = -iRange, iRange do
		for dy = -iRange,iRange do
			local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, iRange);

			-- Valid plot?  Also, skip plots along the top and bottom edge
			if(otherPlot) then
				local otherPlotY = otherPlot:GetY();
				if(otherPlotY > 0 and otherPlotY < gridHeightMinus1) then

					terrainType = otherPlot:GetTerrainType();
					featureType = otherPlot:GetFeatureType();

					-- Subtract one if there is snow and no resource. Do not count water plots unless there is a resource
					if((terrainType == g_TERRAIN_TYPE_SNOW or terrainType == g_TERRAIN_TYPE_SNOW_HILLS or terrainType == g_TERRAIN_TYPE_SNOW_MOUNTAIN) and otherPlot:GetResourceCount() == 0) then
						iFertility = iFertility - 10
					elseif(featureType == g_FEATURE_ICE) then
						iFertility = iFertility - 20
					elseif((otherPlot:IsWater() == false) or otherPlot:GetResourceCount() > 0) then
						iFertility = iFertility + (otherPlot:GetYield(g_YIELD_PRODUCTION)*iProductionYieldWeight)
						iFertility = iFertility + (otherPlot:GetYield(g_YIELD_FOOD)*iFoodYieldWeight)
					end
				
					-- Lower the Fertility if the plot is impassable
					if(iFertility > 5 and otherPlot:IsImpassable() == true) then
						iFertility = iFertility - 5
					end

					-- Lower the Fertility if the plot has Features
					if(featureType ~= g_FEATURE_NONE) then
						iFertility = iFertility - 2
					end	

				else
					iFertility = iFertility - 5
				end
			else
				iFertility = iFertility - 10
			end
		end
	end 

	return iFertility
end

function CheckPotentialCityPlotDistance(plot, iThisPlayer, bNoCloserCheck, bNoLongDistanceCheck)

	if not plot then return false, false end 

	local minDistance 	= math.max(GlobalParameters.CITY_MIN_RANGE, (MapConfiguration.GetValue("CityMinDistance") or 0))
	local homeDistance	= g_MaxDistance -- distance from this player's Civilization closest city
	local civDistance	= g_MaxDistance -- distance from other Civilizations closest city
	local bHasCity		= false
	local bMarkForAll	= true
	local bCheckCloser	= not bNoCloserCheck
	local bCheckFarAway	= not bNoLongDistanceCheck
	local bCloseEnough	= true	-- by default assume that the plot distance is close enough
	local playerData	= ScenarioPlayer[iThisPlayer]
	local thisPriority	= playerData and playerData.Priority or 0
	
	if playerData and bCheckFarAway and playerData.MaxDistanceFromCapital then
		local maxDistance	= playerData.MaxDistanceFromCapital
		local player 		= Players[iThisPlayer]
		local playerCities 	= player:GetCities()
		if playerCities and playerCities.GetCapitalCity then
			local capitalCity	= playerCities:GetCapitalCity()
			if capitalCity then
				local cityPlot	= capitalCity:GetPlot()
				local distance	= g_MaxDistance
				
				if playerData.OnlySameLandMass then
					local path	= GetRoadPath(plot, cityPlot, "Land", maxDistance, nil)
					distance 	= path and (#path-1) or distance
				else
					distance 	= Map.GetPlotDistance(plot:GetIndex(), cityPlot:GetIndex())
				end

				if distance > maxDistance then
					print("     - To far from Capital, distance = ".. tostring(distance) .." > maxDistance of "..tostring(maxDistance))
					bCloseEnough = false
				else
					print("     - Check Capital distance = ".. tostring(distance) .." <= maxDistance of "..tostring(maxDistance))
				end
			end
		end
	end
	
	for _, iPlayer in ipairs(AliveList) do -- for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player 		= Players[iPlayer]
		local otherData		= ScenarioPlayer[iPlayer]
		local otherPriority	= otherData and otherData.Priority or 0
		if player then
			local playerCities 	= player:GetCities()
			if playerCities and playerCities.Members then
				for i, city in playerCities:Members() do
					local cityPlot	= city:GetPlot()
					local distance 	= Map.GetPlotDistance(plot:GetIndex(), cityPlot:GetIndex())
					if distance <= minDistance then
						print("     - Not far enough, distance = ".. tostring(distance) .." <= minDistance of "..tostring(minDistance))
						NotCityPlot[plot] = true
						return false, bCloseEnough
					end
					if iThisPlayer == iPlayer then
						bHasCity = true
						if distance < homeDistance then
							homeDistance = distance
						end
					elseif (otherPriority > thisPriority) or (otherPriority == thisPriority and player:IsMajor()) then
						if distance < civDistance then
							civDistance = distance
						end
					end
				end
			end
		end
	end
	if bCheckCloser and bHasCity and homeDistance >= civDistance then
		print("     - Closer of other civs : Home distance of ".. tostring(homeDistance) .." >= other Civilization distance of "..tostring(civDistance))
		return false, bCloseEnough
	end
--print(CivTypePlayerID[iThisPlayer], bHasCity, homeDistance, civDistance, plot:GetX(), plot:GetY())
	return true, bCloseEnough
end

function CheckLandMassValid(plot, iPlayer)

	if not plot then return false end
	
	local playerData = ScenarioPlayer[iPlayer]
	
	if playerData and playerData.OnlySameLandMass then
		local player = Players[iPlayer]
		local playerCities 	= player and player:GetCities()
		if playerCities and playerCities.GetCapitalCity then
		
			local capitalCity	= playerCities:GetCapitalCity()
			local cityPlot		= capitalCity:GetPlot()
			
			return cityPlot:GetArea() == plot:GetArea()
		end
	else
		return true
	end
end

function GetPotentialCityPlots()

	local potentialPlots 	= {}
	local minFertility		= -250

	for iX = 0, g_iW - 1 do
		for iY = 0, g_iH - 1 do
			local index = (iY * g_iW) + iX;
			pPlot = Map.GetPlotByIndex(index)
			if pPlot:GetResourceCount() == 0 and (not pPlot:IsImpassable()) and (not pPlot:IsNaturalWonder()) and (not pPlot:IsWater()) and pPlot:GetFeatureType() ~= g_FEATURE_OASIS then
				local fertility = GetPlotFertility(pPlot)
				if fertility > minFertility then
					--print("fertility = ", fertility)
					table.insert(potentialPlots, { Plot = pPlot, Fertility = fertility} )
				end
			end
		end
	end
	print("GetPotentialCityPlots returns "..tostring(#potentialPlots).." plots")
	
	table.sort (potentialPlots, function(a, b) return a.Fertility > b.Fertility; end);
	return potentialPlots
end

function GetBestCityPlotFromList(potentialPlots, iPlayer)

	-- to do : use iPlayer and differentiate MinDistanceForeignCity and MinDistanceCity

	if not potentialPlots then 
		print("WARNING: plots is nil for GetBestCityPlotFromList(plots) !")
		print("Skipping...")
		return nil
	end
	
	local iSize		= #potentialPlots;
	local iIndex 	= 1
	local bValid 	= false;
	
	while bValid == false and iSize >= iIndex do
		bValid = true
		if potentialPlots[iIndex].Plot and not NotCityPlot[potentialPlots[iIndex].Plot] then
			pTempPlot = potentialPlots[iIndex].Plot
			
			print("   - testing plot#"..tostring(iIndex) .. ", Fertility = " .. tostring(potentialPlots[iIndex].Fertility))

			-- Distance check with other cities, must be closer from own cities than foreign cities...
			local bFarEnough, bCloseEnough	= CheckPotentialCityPlotDistance(pTempPlot, iPlayer)
			local bLandMassCheck			= CheckLandMassValid(pTempPlot, iPlayer)
			
			if (bFarEnough == false) or (bLandMassCheck == false) then
				bValid = false;
				potentialPlots[iIndex].Plot = nil -- no need to test that plot again...
			end
			
			if(bCloseEnough == false) then
				bValid = false	-- just mark invalid, we may need to test that plot again...
			end

			-- If the plots passes all the checks then the plot equals the temp plot
			if(bValid == true) then
				print("GetBestCityPlotFromList : returning plot #"..tostring(iIndex).."/"..tostring(iSize).." at fertility = ".. tostring(potentialPlots[iIndex].Fertility))
				return pTempPlot;
			end
		else
			bValid = false
		end
		iIndex = iIndex + 1
	end

	return nil;
end

-- ===========================================================================
-- Cities Placement
function InitializeCity(city, name, size)

	IncrementCityCount()
	
	local sizeDiff 		= 0
	local iPlayer 		= city:GetOwner()
	local playerData	= ScenarioPlayer[iPlayer]
	
	if playerData and playerData.CitiesToPlace then
		playerData.CitiesToPlace = playerData.CitiesToPlace - 1
	end
	
	if name then
		city:SetName(name)
	end

	if size then
		sizeDiff = size - city:GetPopulation()
	elseif playerData then
		-- to do : initialize size from scenario settings
		local player 	= Players[iPlayer]
		local cityCount	= player:GetCities():GetCount()
		if cityCount == 1 then
			-- this is the capital
			if playerData.CapitalSize then
				sizeDiff = playerData.CapitalSize - city:GetPopulation()
			end
		elseif playerData.OtherCitySize then
			-- this is not the capital and we have a specific size for other cities
			local sizeReduction = 0
			
			if playerData.CitySizeDecrement and playerData.NumCityPerSizeDecrement then
				sizeReduction = playerData.CitySizeDecrement * math.floor(((cityCount - 1) / playerData.NumCityPerSizeDecrement))
			end
			sizeDiff = math.max(1, playerData.OtherCitySize - sizeReduction) - city:GetPopulation()
		end
	end
		
	if sizeDiff ~= 0 then
		city:ChangePopulation(sizeDiff)
	end
end

function PlaceCities()

	print("===========================================================================")
	print("Starting City placement for Scenario...")
	print("===========================================================================")
	
	-- Place capitals on starting positions
	if bDoCapitalPlacement then -- to do : option for that placement ?
		print("--------------------------------------------")
		print("Placing Capitals on Starting Location...")
		print("--------------------------------------------")
		table.sort (CapitalPlacement, function(a, b) return a.Priority > b.Priority; end)
		
		for playerIndex, data in ipairs(CapitalPlacement) do
			local iPlayer 		= data.Player
			local player 		= Players[iPlayer]
			local playerData	= ScenarioPlayer[iPlayer]
			if playerData and playerData.StartingPlot and ((not playerData.CitiesToPlace) or (playerData.CitiesToPlace and playerData.CitiesToPlace > 0)) then
				print("-", CivTypePlayerID[iPlayer])
				if playerData.StartingPlot:IsWater() or playerData.StartingPlot:IsImpassable() then
					print("    - PLACEMENT IMPOSSIBLE (Water or Impassable plot)")
				else
					local city = player and player:GetCities():Create(playerData.StartingPlot:GetX(), playerData.StartingPlot:GetY())			
					if city then
						print("    - CAPITAL PLACED !")
						InitializeCity(city)
					else
						print("    - PLACEMENT FAILED !")
					end
				end
			end
		end
	end
	
	if bDoImportPlacement then
		print("--------------------------------------------")
		print("Import Cities from Scenario Table...")
		print("--------------------------------------------")
		table.sort (PlacementImport, function(a, b) return a.Priority > b.Priority; end)
		
		local ImportedCities		= {}	-- list of cities available for import
		local CityPlayerID 			= {}	-- helper to get playerID for a city name 
		local CityCivilizationType	= {}	-- helper to get civilizationTypa for a city name
		
		-- Pairing City names with Civilization Type
		-- this is to allow placement of a City that is in the Scenario table but without coordinates by using the CityMap
		-- or getting the Civilization/Player for a City that is in the Scenario table but without civilizationType
		print("Pairing City names with Civilization Type and PlayerIDs...")
		for row in GameInfo.CityNames() do
			
			local cityName 			= row.CityName
			local civilizationType 	= row.CivilizationType
			local iPlayer 			= CivTypePlayerID[row.CivilizationType]
			CityCivilizationType[cityName] 	= civilizationType	-- CityCivilizationType[Locale.Lookup(cityName)] = civilizationType
				
			if iPlayer then
				CityPlayerID[cityName] 	= iPlayer --CivTypePlayerID[row.CityName] <- what was that ??? -- CityPlayerID[Locale.Lookup(cityName)] 	= iPlayer
			end
		end
		
		-- Get the Scenario cities and add them to each player list. 
		print("Add Imported cities to players list...")
		for row in GameInfo.ScenarioCities() do
			if IsRowValid(row) then
				local cityName 			= row.CityName
				local civilizationType	= row.CivilizationType
				
				if cityName == nil and civilizationType == nil then
					print("ERROR at rowID #"..tostring(row.Index).." : CityName and CivilizationType are NULL")
					for k, v in pairs(row) do print("  - ", k, v) end
				else
					
					-- Change name to locale tag name if needed (ie Paris -> LOC_CITY_NAME_PARIS)
					if cityName and string.find(cityName, "LOC_CITY_NAME_") == nil then
						cityName = "LOC_CITY_NAME_" .. string.upper(string.gsub(cityName, "[%- %.]", "_" )) -- string.upper(string.gsub(cityName, "%W", "_" ))
					end
					
					if civilizationType == nil then
						civilizationType = CityCivilizationType[cityName]
					end

					if civilizationType then
						local iPlayer = CivTypePlayerID[civilizationType]
						if iPlayer then
							local player = Players[iPlayer]
							if CanPlace(row, player) then
								local x, y
								if row.X and row.Y then
									x, y = GetXYFromRefMapXY(row.X, row.Y)
									print("    - Getting coordinates from table for ", civilizationType)
									print(" 		-rowXY =", row.X, row.Y, " 	refXY = ", x, y)
								elseif cityName then
									local pos = CityPosition[cityName]
									if pos then
										x, y	= GetXYFromRefMapXY(Round(pos.X), Round(pos.Y))
										print("    - Getting coordinates from city map for ", Locale.Lookup(cityName))
										print(" 		-posXY =", pos.X, pos.Y, " 	refXY = ", x, y)
									else
										print("WARNING at rowID #"..tostring(row.Index).." : no position in city map for "..tostring(cityName))
									end
								else
									print("ERROR at rowID #"..tostring(row.Index).." : CityName and X,Y are NULL")							
								end
								
								if x and y then
									ImportedCities[iPlayer]	= ImportedCities[iPlayer] or {}
									table.insert(ImportedCities[iPlayer], {X = x, Y = y, Name = cityName, Size = row.Size})							
								end
							end
						else
							print("WARNING at rowID #"..tostring(row.Index).." : no playerID for "..tostring(civilizationType).." for city = "..tostring(cityName))
						end
					else
						print("WARNING at rowID #"..tostring(row.Index).." : no civilizationType for "..tostring(cityName), row.X, row.Y)					
					end
				end
			end
		end
		
		-- Place cities for each players
		print("Place Imported cities for each players...")
		local bPlacedCity = true
		while bPlacedCity do
		
			CheckCoroutinePause()
			bPlacedCity 	= false
			local toRemove	= {}
			
			for playerIndex, data in ipairs(PlacementImport) do
				local iPlayer 		= data.Player
				local playerData	= ScenarioPlayer[iPlayer]
				if playerData and ((not playerData.CitiesToPlace) or (playerData.CitiesToPlace and playerData.CitiesToPlace > 0)) then
					local cityIndex		= 1 -- get first entry in list
					local cityData		= ImportedCities[iPlayer] and ImportedCities[iPlayer][cityIndex] 
					if cityData then
						table.remove(ImportedCities[iPlayer], cityIndex)
						local player	= Players[iPlayer]
						local city 		= player and player:GetCities():Create(cityData.X, cityData.Y)
						if city then
							bPlacedCity		= true
							local cityName	= cityData.Name
							InitializeCity(city, cityData.Name, cityData.Size)
							print(" 		- ".. tostring(Locale.Lookup(city:GetName())) .." PLACED !")
						end
					else
						table.insert(toRemove, playerIndex)
					end
				end
			end

			for _, i in ipairs(toRemove) do
				table.remove(PlacementImport, i)
			end
		end
	end
	

	if bDoCityNamePlacement then
		table.sort (PlacementCityMap, function(a, b) return a.Priority > b.Priority; end)
		
		print("--------------------------------------------")
		print("Placing Cities using CityName and CityMap Table...")
		print("--------------------------------------------")
		
		print("Searching cities with known positions in CityMap for each player...")
		local cityList = {}
		
		for playerIndex, data in ipairs(PlacementCityMap) do

			CheckCoroutinePause()
			
			local iPlayer 			= data.Player
			cityList[iPlayer]		= {}
			local playerData		= ScenarioPlayer[iPlayer]
			local civilizationType 	= CivTypePlayerID[iPlayer]

			if playerData and ((not playerData.CitiesToPlace) or (playerData.CitiesToPlace and playerData.CitiesToPlace > 0)) then
				print("-", civilizationType)
				
				for row in GameInfo.CityNames() do
					local cityName = row.CityName
					if civilizationType == row.CivilizationType then
						local pos = CityPosition[cityName] --or CityPosition[Locale.Lookup(cityName)] -- to do : option to allow localization (may cause desync in MP with different language)
						if pos then
						
							local x, y		= GetXYFromRefMapXY(Round(pos.X), Round(pos.Y)) -- CityPosition use average value of x, y as a city name can fit multiple positions on a map
							local distance	= (playerData.StartingPlot and Map.GetPlotDistance(x, y, playerData.StartingPlot:GetX(), playerData.StartingPlot:GetY())) or 0
							print("  - possible position found for ".. Locale.Lookup(cityName) .. " at (".. tostring(x).. ","..tostring(y)..") from average position on reference map at (".. tostring(pos.X), ","..tostring(pos.Y), "), starting plot distance = " .. tostring(distance))
							table.insert(cityList[iPlayer], { Name = cityName, X = x, Y = y, Distance = distance })

						end
					end
				end
				
				table.sort (cityList[iPlayer], function(a, b) return a.Distance < b.Distance; end)
			end
		end
		
		print("Placing cities for each player...")
		local bAnyCityPlaced 	= true
		local cityIndex			= {}
		local loop				= 0
		local bNoCloserCivCheck	= true
		
		while bAnyCityPlaced do
		
			CheckCoroutinePause()
			bAnyCityPlaced = false
			local toRemove	= {}

			for playerIndex, data in ipairs(PlacementCityMap) do
			
				local iPlayer 		= data.Player
				local playerData	= ScenarioPlayer[iPlayer]
				
				if playerData and playerData.CitiesToPlace and playerData.CitiesToPlace > 0 then			
				
					print("- Looking for next placement for ", CivTypePlayerID[iPlayer])
					
					local list 	= cityList[iPlayer]
					if list then
						local player = Players[iPlayer]
						
						-- Initialize player's cityIndex to first entry if not already set
						if not cityIndex[iPlayer] then cityIndex[iPlayer] = 1 end
					
						local bPlayerCityPlaced	= false
						local cityRow			= list[ cityIndex[iPlayer] ]
						local cityName 			= cityRow and cityRow.Name
						
						while cityName and not bPlayerCityPlaced do
						
							print(" - Trying to place : ", cityName and Locale.Lookup(cityName))
							
							cityIndex[iPlayer] 				= cityIndex[iPlayer] + 1
							local plot 						= Map.GetPlot(cityRow.X, cityRow.Y)
							local bFarEnough, bCloseEnough	= CheckPotentialCityPlotDistance(plot, iPlayer, bNoCloserCivCheck)
							local bLandMassCheck			= CheckLandMassValid(plot, iPlayer)
							
							if bFarEnough and bCloseEnough and bLandMassCheck then
								if plot and not (plot:IsWater() or plot:IsImpassable()) then
									print("    - Placing at (".. tostring(cityRow.X).. ","..tostring(cityRow.X)..")")
									local city = player:GetCities():Create(cityRow.X, cityRow.Y)
									if city then
										InitializeCity(city, cityName)
										print("  - ".. tostring(cityName), " entry#"..tostring(cityIndex[iPlayer]-1), " PLACED !")
										bPlayerCityPlaced 		= true
										bAnyCityPlaced			= true
									else
										print("    - Placement failed at entry#"..tostring(cityIndex[iPlayer]-1))
									end
								else
									print("    - Invalid plot at entry#"..tostring(cityIndex[iPlayer]-1))
								end
							else
								print("    - Distance check failed at entry#"..tostring(cityIndex[iPlayer]-1))
							end
							
							if not bPlayerCityPlaced then
								cityRow		= list[ cityIndex[iPlayer] ]
								cityName 	= cityRow and cityRow.Name
							end
						end
						
						if cityName == nil then
							table.insert(toRemove, playerIndex)
						end
					end
				end
			end
			
			for _, i in ipairs(toRemove) do
				table.remove(PlacementCityMap, i)
			end
		end
	end
	
	
	if bDoTerrainPlacement then
	
		print("--------------------------------------------")
		print("Placing cities using Terrain fertility values...")
		print("--------------------------------------------")
		
		table.sort (PlacementTerrain, function(a, b) return a.Priority > b.Priority; end)
		
		local potentialplots	= GetPotentialCityPlots()
		local playerPlots		= {}

		for playerIndex, data in ipairs(PlacementTerrain) do

			CheckCoroutinePause()
			
			local iPlayer 		= data.Player
			local playerData	= ScenarioPlayer[iPlayer]
			local player		= Players[iPlayer]
			
			print(" - Number of cities to place for " .. tostring(CivTypePlayerID[iPlayer]) .. " = " .. tostring(playerData and playerData.CitiesToPlace))
			
			if playerData and playerData.CitiesToPlace and playerData.CitiesToPlace > 0 and playerData.StartingPlot then
				
				-- Sort potential cities plots for that player
				local minDistance 				= GlobalParameters.CITY_MIN_RANGE	-- } to do : specific per player ?
				local distanceWeigthMultiplier	= 0.15								-- }
				playerPlots[iPlayer]			= {}
				local plotList					= playerPlots[iPlayer]
				
				print("   - Get and Sort potential plots for this player cities...")
				for i, row in ipairs(potentialplots) do
					local distance	= Map.GetPlotDistance(row.Plot:GetIndex(), playerData.StartingPlot:GetIndex())
					if distance > minDistance or city == nil then
						local distanceWeight = distance * distanceWeigthMultiplier
						table.insert(plotList, { Plot = row.Plot, Fertility = row.Fertility / (1 + distanceWeight)} )
					end
				end
				table.sort (plotList, function(a, b) return a.Fertility > b.Fertility; end)
			end
		end
	
		-- Place 1 city per civilization per loop, until no more cities can be founded
		local bPlacedCity = true
		while (bPlacedCity) do
		
			bPlacedCity 	= false
			local toRemove	= {}
			
			for playerIndex, data in ipairs(PlacementTerrain) do
			
				CheckCoroutinePause()
				
				local iPlayer 		= data.Player
				local playerData	= ScenarioPlayer[iPlayer]
			
				if playerData and playerData.CitiesToPlace and playerData.CitiesToPlace > 0 then
					print("    - Finding next City position for " .. tostring(CivTypePlayerID[iPlayer]) .. ", cities to place = " .. tostring(playerData and playerData.CitiesToPlace).. ", priority = " .. tostring(playerData and playerData.Priority))

					local plotList	= playerPlots[iPlayer]
					local pBestPlot = GetBestCityPlotFromList(plotList, iPlayer)
					
					if pBestPlot then
print(pBestPlot:GetX(), pBestPlot:GetY())
						local player 	= Players[iPlayer]
						local city 		= player:GetCities():Create(pBestPlot:GetX(), pBestPlot:GetY())			
						if city then
							InitializeCity(city)
							bPlacedCity = true
							print("     - ".. tostring(Locale.Lookup(city:GetName())) .." PLACED !")
						end
						
					else
						table.insert(toRemove, playerIndex)
					end
				end
			end

			for _, i in ipairs(toRemove) do
				table.remove(PlacementTerrain, i)
			end
		end
	end
	
	-- Next :	
	AddCoToList(coroutine.create(PlaceBorders))
end

-- ===========================================================================
-- Borders
function PlaceBorders()

	print("===========================================================================")
	print("Starting Border placement for Scenario...")
	print("===========================================================================")

	if borderPlacement == "PLACEMENT_EXPAND" then

		--[[
		local bAnyBorderExpanded 	= true
		local loop					= 0
		
		while bAnyBorderExpanded do
		
			loop 				= loop + 1
			bAnyBorderExpanded 	= false
			local plotList		= {}
			
			local iPlotCount = Map.GetPlotCount()
			for i = 0, iPlotCount - 1 do			
				local plot = Map.GetPlotByIndex(i)
				if plot and (not plot:IsWater()) and plot:IsAdjacentOwned() and (not plot:IsOwned()) then					
					table.insert(plotList, plot)					
				end			
			end
			
			local aShuffledPlotList = GetShuffledCopyOfTable(plotList)
			for _, plot in ipairs(aShuffledPlotList) do			
				local potentialOwner 	= {}
				local bestAdjacentOwner	= 0
				local newOwnerID		= nil
				for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
					local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
					if (adjacentPlot ~= nil) and (not adjacentPlot:IsWater()) and adjacentPlot:IsOwned() then
						local ownerID = adjacentPlot:GetOwner()
						potentialOwner[ownerID] = (potentialOwner[ownerID] or 0) + 1
						if potentialOwner[ownerID] > bestAdjacentOwner then
							bestAdjacentOwner = potentialOwner[ownerID]
							newOwnerID = ownerID
						end
					end
				end	
				if newOwnerID then
					ChangePlotOwner(plot, newOwnerID)
					--local city = FindNearestPlayerCity( newOwnerID, plot:GetX(), plot:GetY() )
					--if city then
					--	--WorldBuilder.CityManager():SetPlotOwner( plot:GetX(), plot:GetY(), newOwnerID, city:GetID() )
					--	plot:SetOwner(-1)
					--	plot:SetOwner(newOwnerID, city:GetID(), true)
					--	bAnyBorderExpanded = true
					--end
				end
			end
		end
		--]]
		
		-- Expand from cities
		print("--------------------------------------------")
		print("- Expanding Territory from cities positions")
		print("--------------------------------------------")
		print("borderAbsoluteMaxDistance = ", borderAbsoluteMaxDistance)
		
		local cityList = {}
		for _, iPlayer in ipairs(AliveList) do -- for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
			local player = Players[iPlayer]
			if player then
				local playerCities 	= player:GetCities()
				if playerCities and playerCities.Members then
					for i, pLoopCity in playerCities:Members() do
						table.insert(cityList, pLoopCity)
					end				
				end
			end
		end
		
		local shuffledCityList		= GetShuffledCopyOfTable(cityList) -- to do : sort using Priority tag from Civilization settings
		local bAnyBorderExpanded 	= true
		local iLoop					= 0
		local iRing					= 2
		
		while bAnyBorderExpanded and iRing <= borderAbsoluteMaxDistance do
			
			print("  - Check for ownership on ring#"..tostring(iRing))
			
			iLoop 				= iLoop + 1
			bAnyBorderExpanded 	= false
			
			for _, city in ipairs(shuffledCityList) do
		
				CheckCoroutinePause()
				
				print("   - City : "..Locale.Lookup(city:GetName()))
				
				local ownerID 		= city:GetOwner()
				local pPlot			= city:GetPlot()
				local playerData	= ScenarioPlayer[ownerID]
				local iMaxDistance	= playerData and playerData.BorderMaxDistance or borderMaxDistance
				print("   	- Max distance : ", iMaxDistance)
				
				for pEdgePlot in PlotRingIterator(pPlot, iRing) do
					if pEdgePlot:GetOwner() == -1 and pPlot:GetArea() == pEdgePlot:GetArea() and not pEdgePlot:IsWater() then
						local bAquirePlot = false
						--[[
						for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
							local adjacentPlot = Map.GetAdjacentPlot(pEdgePlot:GetX(), pEdgePlot:GetY(), direction);
							if (adjacentPlot ~= nil) and (not adjacentPlot:IsWater()) then --and adjacentPlot:IsOwned() then
								--if ownerID == adjacentPlot:GetOwner() then
								if pPlot:GetArea() == adjacentPlot:GetArea() then
									bAquirePlot = true
								end
							end
						end
						--]]
						local path		= GetRoadPath(pEdgePlot, pPlot, "Land", nil, nil)
						local distance 	= path and (#path-1) or g_MaxDistance
						bAquirePlot		= distance <= iMaxDistance
						print("   	- Testing Plot at : ", pEdgePlot:GetX(),pEdgePlot:GetY())
						print("   	- Landpath Distance : ", distance)
						print("   	- bAquirePlot	= Landpath <= Max distance : ", bAquirePlot)
						if bAquirePlot then
							ChangePlotOwner(pEdgePlot, ownerID, city:GetID())
							bAnyBorderExpanded = true
						end
					end
				end
			end
			iRing = iRing + 1
		end
	end
	
	if borderPlacement == "PLACEMENT_IMPORT" then
		---[[
		
		print("--------------------------------------------")
		print("Importing Territory...")
		print("--------------------------------------------")
		
		local alreadyWarnedFor	= {}
		for row in GameInfo.ScenarioTerritory() do
			if IsRowValid(row) then
				local civilizationType	= row.CivilizationType
				
				if civilizationType == nil then
					print("ERROR at rowID #"..tostring(row.Index).." : CivilizationType is NULL")
				else
					local iPlayer		= CivTypePlayerID[civilizationType]
					if iPlayer then
						local x, y
						if row.X and row.Y then
							x, y = GetXYFromRefMapXY(row.X, row.Y)
							print("    - Getting coordinates from table for ", civilizationType)
							print(" 		-rowXY =", row.X, row.Y, " 	refXY = ", x, y)
						else
							print("ERROR at rowID #"..tostring(row.Index).." : no position")						
						end
						
						if x and y then
							local plot 		= Map.GetPlot(x, y)
							if plot then
								ChangePlotOwner(plot, iPlayer)
								if plot:GetOwner() == iPlayer then
									print(" 		- PLACED !")
								else
									print(" 		- PLACEMENT FAILED !")
								end
							end								
						end
					else
						if not alreadyWarnedFor[civilizationType] then
							print("WARNING at rowID #"..tostring(row.Index).." : no playerID for "..tostring(civilizationType))
							alreadyWarnedFor[civilizationType] = true
						end
					end
				end
			end
		end
		--]]
	end

	-- Next :	
	AddCoToList(coroutine.create(PlaceUnits))

end

-- ===========================================================================
-- Units
function PlaceUnits()

	print("===========================================================================")
	print("Starting Units placement for Scenario...")
	print("===========================================================================")
	
	if true then --	unitPlacement == "PLACEMENT_IMPORT"
		print("--------------------------------------------")
		print("Create replacement table")
		print("--------------------------------------------")
		local backup = {}
		for row in GameInfo.ScenarioUnitsReplacement() do
			if IsRowValid(row) then
				backup[row.UnitType] = row.BackupType
			end
		end
		
		print("--------------------------------------------")
		print("Placing units...")
		print("--------------------------------------------")
		for row in GameInfo.ScenarioUnits() do
			if IsRowValid(row) then
				local unitRow = GameInfo.Units[row.UnitType] or (backup[row.UnitType] and GameInfo.Units[backup[row.UnitType]])
				if unitRow then
					local unitTypeID		= unitRow.Index
					local unitName 			= row.UnitName
					local civilizationType	= row.CivilizationType				

					local iPlayer = CivTypePlayerID[civilizationType]
					if iPlayer then
						local player = Players[iPlayer]
						if CanPlace(row, player) then
							local x, y
							x, y = GetXYFromRefMapXY(row.X, row.Y)
							print("    - Getting coordinates from table for ", tostring(unitType), tostring(civilizationType))
							print(" 		-rowXY =", row.X, row.Y, " 	refXY = ", x, y)
							
							if x and y then
								local unit = player:GetUnits():Create(unitTypeID, x, y)
								-- to do: add gameplay events for mods here
								GameEvents.ScenarioUnitAdded.Call(unit)
								if unit then
									if unitName then
										unit:SetName(unitName)
									end
									print(" 		- ".. tostring(Locale.Lookup(unit:GetName())) .." PLACED !")
								end								
							end
						end
					else
						print("WARNING at rowID #"..tostring(row.Index).." : no playerID for "..tostring(civilizationType), tostring(unitType))
					end				
				else
					print("WARNING at rowID #"..tostring(row.Index).." : no DB entry in Units table for "..tostring(unitType))
				end
			end
		end
	end
	
	-- Next :	
	AddCoToList(coroutine.create(PlaceInfrastructure))
end

-- ===========================================================================
-- Infrastructure
function PlaceInfrastructure()

	print("===========================================================================")
	print("Starting Infrastructure placement for Scenario...")
	print("===========================================================================")
	
	if infrastructurePlacement == "PLACEMENT_IMPORT" then
		
		print("--------------------------------------------")
		print("Importing Infrastructure...")
		print("--------------------------------------------")
		local alreadyWarnedFor	= {}
		for row in GameInfo.ScenarioInfrastructure() do
			if IsRowValid(row) then
				local improvementType	= row.ImprovementType
				local routeType			= row.RouteType
				if improvementType or routeType then
					local x, y
					if row.X and row.Y then
						x, y = GetXYFromRefMapXY(row.X, row.Y)
						print("    - Getting coordinates from table...")
						print(" 		-rowXY =", row.X, row.Y, " 	refXY = ", x, y)
					else
						print("ERROR at rowID #"..tostring(row.Index).." : no position")						
					end
					
					if x and y then
						local plot 		= Map.GetPlot(x, y)
						if plot then
							if routeType then
								RouteBuilder.SetRouteType(plot, routeType)
								print(" 		- ROUTE PLACED !")
							end
							
							if improvementType and GameInfo.Improvements[improvementType] then
								ImprovementBuilder.SetImprovementType(plot, GameInfo.Improvements[improvementType].Index, plot:GetOwner())
								print(" 		- "..tostring(improvementType).." PLACED !")
							end
						end								
					end
				else
					print("ERROR at rowID #"..tostring(row.Index).." : improvement and route types are nil")	
				end
			end
		end
		--]]
	end

	if bDoRoadPlacement then
		
		print("--------------------------------------------")
		print(" - Generating Roads from cities...")
		print("--------------------------------------------")
		
		-- Create a list of cities with roads out
		local cityList = {}
		for _, iPlayer in ipairs(AliveList) do -- for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		
			local playerData	= ScenarioPlayer[iPlayer]
			if playerData and playerData.RoadPlacement and playerData.RoadPlacement ~= "PLACEMENT_EMPTY" then
			
				print(" - Placing roads for " .. tostring(CivTypePlayerID[iPlayer]))
		
				if playerData.RoadPlacement == "PLACEMENT_CENTRALIZED" then
					-- From Capital to all other cities
					local player = Players[iPlayer]
					if player then
						local playerCities 	= player:GetCities()
						if playerCities and playerCities.Members then
						
							local capitalCity	= playerCities:GetCapitalCity()
							local capitalPlot	= capitalCity and capitalCity:GetPlot()
							
							if capitalPlot then
								print("  - Internal roads:")
								local cityList		= {}
								
								for i, pLoopCity in playerCities:Members() do
									if pLoopCity ~= capitalCity then
										local destPlot = pLoopCity:GetPlot()
										if destPlot:GetArea() == capitalPlot:GetArea() then
											local distance = Map.GetPlotDistance(capitalPlot:GetX(), capitalPlot:GetY(), destPlot:GetX(), destPlot:GetY())
											if playerData.RoadMaxDistance == nil or playerData.RoadMaxDistance >= distance then
												table.insert(cityList, {Plot = destPlot, Distance = distance, Name = pLoopCity:GetName() })
											end
										end
									end
								end
								
								table.sort (cityList, function(a, b) return a.Distance < b.Distance; end)
								
								for i, cityRow in ipairs(cityList) do
									print("   - Testing from "..Locale.Lookup(capitalCity:GetName()).." to "..Locale.Lookup(cityRow.Name).." at distance = ".. tostring(cityRow.Distance))
									local path = GetRoadPath(capitalPlot, cityRow.Plot, "Land", nil, iPlayer)
									if path then 
										print("     - Found path, placing roads of length = " .. tostring(#path))
										for j, plotIndex in ipairs(path) do
											local plot = Map.GetPlotByIndex(plotIndex)
											RouteBuilder.SetRouteType(plot, 1) -- to do : select route type
										end
									else
										print("     - No path...")
									end
								end
								
					
								--
								if playerData.InternationalRoads then
									print("  - International roads:")
									local capitalList = {}
									for _, iOtherPlayer in ipairs(AliveList) do -- for iOtherPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
										if iOtherPlayer ~= iPlayer then
										local otherPlayer = Players[iOtherPlayer]
											if otherPlayer then
												local otherPlayerCities 	= otherPlayer:GetCities()
												if otherPlayerCities and playerCities.Members then
													local otherCapitalCity	= otherPlayerCities:GetCapitalCity()
													local otherCapitalPlot	= otherCapitalCity and otherCapitalCity:GetPlot()
												
													if otherCapitalPlot and otherCapitalPlot:GetArea() == capitalPlot:GetArea() then
														local distance = Map.GetPlotDistance(capitalPlot:GetX(), capitalPlot:GetY(), otherCapitalPlot:GetX(), otherCapitalPlot:GetY())
														if playerData.RoadMaxDistance == nil or playerData.RoadMaxDistance >= distance then
															table.insert(capitalList, {Plot = otherCapitalPlot, Distance = distance, Name = otherCapitalCity:GetName() })
														end
													end
												end
											end
										end
									end
									
									table.sort (capitalList, function(a, b) return a.Distance < b.Distance; end)
									
									for i, cityRow in ipairs(capitalList) do
										print("   - Testing from "..Locale.Lookup(capitalCity:GetName()).." to "..Locale.Lookup(cityRow.Name).." at distance = ".. tostring(cityRow.Distance))
										local path = GetRoadPath(capitalPlot, cityRow.Plot, "Land", nil, nil)
										if path then 
											print("     - Found path, placing roads of length = " .. tostring(#path))
											for j, plotIndex in ipairs(path) do
												local plot = Map.GetPlotByIndex(plotIndex)
												RouteBuilder.SetRouteType(plot, 1) -- to do : select route type
											end
										else
											print("     - No path...")
										end
									end
								end
							end				
						end
					end
				
				elseif playerData.RoadPlacement == "PLACEMENT_PER_CITY" then
					
					local player = Players[iPlayer]
					if player then
						local playerCities 	= player:GetCities()
						if playerCities and playerCities.Members then
							for i, pLoopCity in playerCities:Members() do
								--table.insert(cityList, pLoopCity)
								local bAllowForeign			= playerData.InternationalRoads
								for j = 1, playerData.MaxRoadPerCity do
									local pCityPlot				= pLoopCity:GetPlot()
									local pTargetCity, distance	= FindNearestCityForNewRoad( iPlayer, pCityPlot:GetX(), pCityPlot:GetY(), bAllowForeign )
									local path 					= pTargetCity and GetRoadPath(pCityPlot, pTargetCity:GetPlot(), "Land", nil, (not bAllowForeign and iPlayer) or nil)
									print("   - Testing from "..Locale.Lookup(pLoopCity:GetName()).." to "..tostring(pTargetCity and Locale.Lookup(pTargetCity:GetName())).." at distance = ".. tostring(distance))
									if path then 
										print("     - Found path, placing roads of length = " .. tostring(#path))
										for j, plotIndex in ipairs(path) do
											local plot = Map.GetPlotByIndex(plotIndex)
											RouteBuilder.SetRouteType(plot, 1) -- to do : select route type
										end
									else
										print("     - No path...")
									end
								end
							end				
						end
					end
				end
			end
		end
		
	end

end

-- ===========================================================================
function YnAMP_SetScenario()
	--[[
	PlaceCities()
	PlaceBorders()
	PlaceUnits()
	PlaceInfrastructure()
	--]]
	if not Game:GetProperty("YnAMP_ScenarioInitialized") then
	SetScenarioPlayers()
		-- Launch coroutines, each calls the next one...
	AddCoToList(coroutine.create(PlaceCities))
	Game:SetProperty("YnAMP_ScenarioInitialized", true)
	end
end
Events.LoadGameViewStateDone.Add( YnAMP_SetScenario )

--Events.LoadScreenClose.Add( YnAMP_SetScenario )
--Events.LoadScreenContentReady.Add(  );		-- Ready to show player info
--Events.LoadGameViewStateDone.Add(  );			-- Ready to start game

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Scenario settings >>>>>
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- ===========================================================================
function Initialize()
	LaunchScriptWithPause()
end
Initialize()
