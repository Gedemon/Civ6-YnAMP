------------------------------------------------------------------------------
--	FILE:	 YnAMP_Script.lua
--  Gedemon (2016-2017)
------------------------------------------------------------------------------

local YnAMP_Version = GameInfo.GlobalParameters["YNAMP_VERSION"].Value
print ("Yet (not) Another Maps Pack version " .. tostring(YnAMP_Version) .." (2016-2019) by Gedemon")
print ("loading YnAMP_Script.lua")

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

local isCityOnMap 	= {} -- helper to check by name if a city has a position set on the city map
local cityPosition	= {} -- helper to get the first defined position in the city map of a city (by name)

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

local g_ExtraRange = 0
if bUseRelativePlacement then
	g_ExtraRange = 10 --Round(10 * math.sqrt(g_iW * g_iH) / math.sqrt(g_ReferenceMapWidth * g_ReferenceMapHeight))
end

-- Scenario Settings
local scenarioName 				= MapConfiguration.GetValue("ScenarioName")
local cityPlacement 			= MapConfiguration.GetValue("CityPlacement")
local borderPlacement			= MapConfiguration.GetValue("BorderPlacement")
local infrastructurePlacement	= MapConfiguration.GetValue("InfrastructurePlacement")

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

------------------------------------------------------------------------------
-- Fill helper tables
------------------------------------------------------------------------------
for row in GameInfo.CityMap() do
	local name = row.CityLocaleName
	if mapName == row.MapName then
		if name then
			if not isCityOnMap[name] then
				isCityOnMap[name] 					= true
				isCityOnMap[Locale.Lookup(name)] 	= true
				cityPosition[name] 					= {X = row.X, Y = row.Y }
				cityPosition[Locale.Lookup(name)] 	= {X = row.X, Y = row.Y }
			else
				averageX = (cityPosition[name].X + row.X) / 2
				averageY = (cityPosition[name].Y + row.Y) / 2
				cityPosition[name] 					= {X = averageX, Y = averageY }
				cityPosition[Locale.Lookup(name)] 	= {X = averageX, Y = averageY }
			end
		else
			print("ERROR : no name at row "..tostring(row.Index + 1))
		end
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
		--print ("No city found of player " .. tostring(eTargetPlayer) .. " in range of " .. tostring(iX) .. ", " .. tostring(iY));
	end
   
    return pCity, iShortestDistance;
end


------------------------------------------------------------------------------
-- Helpers for x,y positions when using a reference or offset map
------------------------------------------------------------------------------

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


------------------------------------------------------------------------------
-- Handling script with pauses
------------------------------------------------------------------------------

local g_Timer 			= 0
local g_Pause 			= 0.1
local g_LoopPerResume 	= 1
local CoroutineList		= {}

function AddCoToList(newCo)
	print("Adding coroutine to script with pause :"..tostring(newCo))
	table.insert(CoroutineList, newCo)
end

function LaunchScriptWithPause()
	print("LaunchScriptWithPause")
	Events.GameCoreEventPublishComplete.Add( CheckTimer )
end
Events.LoadScreenClose.Add( LaunchScriptWithPause ) -- launching the script when the load screen is closed, you can use your own events

function StopScriptWithPause() -- GameCoreEventPublishComplete is called frequently, keep it clean

	print("StopScriptWithPause")
	Events.GameCoreEventPublishComplete.Remove( CheckTimer )
end

function ChangePause(value)
	print("changing pause value to ", value)
	g_Pause = value
end

function CheckTimer()
	if Automation.GetTime() >= g_Timer + g_Pause then
		local toRemove 	= {}
		g_Timer 		= Automation.GetTime()
		for i, runningCo in ipairs(CoroutineList) do
			if coroutine.status(runningCo)=="dead" then
				table.insert(toRemove, i)
			else
				coroutine.resume(runningCo)
			end
		end
		for _, i in ipairs(toRemove) do
			table.remove(CoroutineList, i)
		end
	end
end

----------------------------------------------------------------------------------------
-- City renaming <<<<<
----------------------------------------------------------------------------------------
if bAutoCityNaming then
----------------------------------------------------------------------------------------
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
		if not (isCityOnMap[name] or isCityOnMap[Locale.Lookup(name)]) then
			print("Not mapped for "..tostring(civilization).." : "..tostring(name))
		end
	end
end
Events.LoadScreenClose.Add( ListCityNotOnMap )

----------------------------------------------------------------------------------------
end
----------------------------------------------------------------------------------------
-- City renaming >>>>>
----------------------------------------------------------------------------------------
-- EnforcingTSL <<<<<
----------------------------------------------------------------------------------------
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
----------------------------------------------------------------------------------------
-- EnforcingTSL >>>>>
----------------------------------------------------------------------------------------
-- Limiting Barbarian Scouts <<<<<
----------------------------------------------------------------------------------------
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
----------------------------------------------------------------------------------------
-- Limiting Barbarian Scouts >>>>>
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
-- Scenario settings  <<<<<
----------------------------------------------------------------------------------------
if not Game:GetProperty("YnAMP_ScenarioInitialized") then 
----------------------------------------------------------------------------------------

print("Setting scenario : ", scenarioName)
print("City Placement 	: ", cityPlacement)
print("Border Placement : ", borderPlacement)
print("WorldBuilder : ", WorldBuilder)
print("WorldBuilder.CityManager : ", WorldBuilder.CityManager)

local isCityOnMap 	= {} -- helper to check by name if a city has a position set on the city map
local cityPosition	= {} -- helper to get the first defined position in the city map of a city (by name)
for row in GameInfo.CityMap() do
	local name = row.CityLocaleName
	if mapName == row.MapName then
		if name then
			if not isCityOnMap[name] then
				isCityOnMap[name] 					= true
				isCityOnMap[Locale.Lookup(name)] 	= true
				cityPosition[name] 					= {X = row.X, Y = row.Y }
				cityPosition[Locale.Lookup(name)] 	= {X = row.X, Y = row.Y }
			else
				averageX = (cityPosition[name].X + row.X) / 2
				averageY = (cityPosition[name].Y + row.Y) / 2
				cityPosition[name] 					= {X = averageX, Y = averageY }
				cityPosition[Locale.Lookup(name)] 	= {X = averageX, Y = averageY }
			end
		else
			print("ERROR : no name at row "..tostring(row.Index + 1))
		end
	end
end

function IsRowValid(row)
	if not (row.ScenarioName) and not (row.MapName) then
		print("ERROR at rowID #"..tostring(row.Index).." : ScenarioName AND MapName are NULL")
		for k, v in pairs(row) do print("  - ", k, v) end
	end
	return (row.ScenarioName == scenarioName) or (not (row.ScenarioName) and row.MapName == mapName)
end

function CanPlace(row, player)
	return player and ((player:IsHuman() and (not row.OnlyAI)) or ((not player:IsHuman()) and (not row.OnlyHuman)))
end

print("Pairing Civilization Type with PlayerIDs...")
local CivilizationPlayerID 	= {}
for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do -- for _, iPlayer in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
	local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
	if CivilizationTypeName then
		CivilizationPlayerID[CivilizationTypeName] = iPlayer
	else
		print("WARNING for playerID #"..tostring(iPlayer).." : CivilizationTypeName is NIL")
	end
end

-- City
function PlaceCities()

	print("Starting City placement for Scenario...")
	local CitiesPlacedFor = {}
	
	if cityPlacement == "TERRAIN" then

	end

	if cityPlacement == "IMPORT" or cityPlacement == "MIXED"  then
		local CityPlayerID 			= {}
		local CityCivilizationType	= {}
		
		print("Pairing City names with Civilization Type and PlayerIDs...")
		for row in GameInfo.CityNames() do
			
			local cityName 			= row.CityName
			local civilizationType 	= row.CivilizationType
			local iPlayer 			= CivilizationPlayerID[row.CivilizationType]
		
			CityCivilizationType[cityName] 					= civilizationType
			CityCivilizationType[Locale.Lookup(cityName)] 	= civilizationType
				
			if iPlayer then
				CityPlayerID[cityName] 					= CivilizationPlayerID[row.CityName]
				CityPlayerID[Locale.Lookup(cityName)] 	= iPlayer
			end
		end
		
		print("Import cities...")
		for row in GameInfo.ScenarioCities() do
			if IsRowValid(row) then
				local cityName 			= row.CityName
				local civilizationType	= row.CivilizationType
				
				if cityName == nil and civilizationType == nil then
					print("ERROR at rowID #"..tostring(row.Index).." : CityName and CivilizationType are NULL")
					for k, v in pairs(row) do print("  - ", k, v) end
				else
					
					if civilizationType == nil then
						civilizationType = CityCivilizationType[cityName]
					end

					if civilizationType then
						local iPlayer = CivilizationPlayerID[civilizationType]
						if iPlayer then
							local player = Players[iPlayer]
							if CanPlace(row, player) then
								local x, y
								if row.X and row.Y then
									x, y = GetXYFromRefMapXY(row.X, row.Y)
									print("    - Getting coordinates from table for ", civilizationType)
									print(" 		-rowXY =", row.X, row.Y, " 	refXY = ", x, y)
								elseif cityName then
									local pos = cityPosition[cityName]
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
									local city 		= player:GetCities():Create(x, y)
									if city then
										if cityName then
											city:SetName(cityName)
										end
										print(" 		- ".. tostring(Locale.Lookup(city:GetName())) .." PLACED !")
										CitiesPlacedFor[civilizationType] = true
									end								
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

	end
	
	if cityPlacement == "CITY_MAP" or cityPlacement == "MIXED" then
	
		print("Searching cities with known position for each major civs...")
		local cityList = {}
		for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do --for _, iPlayer in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
			local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
			if CivilizationTypeName and not CitiesPlacedFor[CivilizationTypeName] then
				print("-", CivilizationTypeName)
				local player		= Players[iPlayer]
				cityList[iPlayer]	= {}
				local startingPlot 	= player:GetStartingPlot()
				-- place capital
				---[[
				if startingPlot then
					local city 			= player:GetCities():Create(startingPlot:GetX(), startingPlot:GetY())			
					if city then
						print("    - CAPITAL PLACED !")
					end
				end
				--]]
				
				local counter = 0
				for row in GameInfo.CityNames() do
					local cityName = row.CityName
					if CivilizationTypeName == row.CivilizationType then
						local pos = cityPosition[cityName] or cityPosition[Locale.Lookup(cityName)]
						if pos then
						
							print("    - possible position found for ", Locale.Lookup(cityName))
							table.insert(cityList[iPlayer], cityName)

						end
					end
				end
			end
		end
		
		print("Placing cities for each player...")
		local bAnyCityPlaced 	= true
		local playerCounter		= {}
		local loop				= 0
		
		while bAnyCityPlaced do
		
			bAnyCityPlaced = false
			
			for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do --for _, iPlayer in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
			--for player, cityList in pairs(cityList) do
				
				local list 		= cityList[iPlayer]
				if list then
					local player 	= Players[iPlayer]
					if not playerCounter[iPlayer] then playerCounter[iPlayer] = 1 end
				
					local bPlayerCityPlaced	= false
					local cityName 			= list[playerCounter[iPlayer]]
					
					while cityName and not bPlayerCityPlaced do
						playerCounter[iPlayer] 	= playerCounter[iPlayer] + 1
						local pos 				= cityPosition[cityName] or cityPosition[Locale.Lookup(cityName)]
						local x, y				= GetXYFromRefMapXY(Round(pos.X), Round(pos.Y)) -- cityPosition use average value of x, y
						local plot = Map.GetPlot(x, y)
						if plot and not (plot:IsWater() or plot:IsImpassable()) then
							print(" - Trying to place city for player ID#".. tostring(iPlayer)," at (".. tostring(x).. ","..tostring(y)..") from average position (".. tostring(pos.X), ","..tostring(pos.Y), ")")
							local city = player:GetCities():Create(x, y)
							if city then
								print("  - ".. tostring(cityName), " entry#"..tostring(playerCounter[iPlayer]-1), " PLACED !")
								city:SetName(cityName)
								bPlayerCityPlaced 		= true
								bAnyCityPlaced			= true
							else
								print("  - Placement failed at entry#"..tostring(playerCounter[iPlayer]-1))
								cityName = list[playerCounter[iPlayer]]
							end
						else
							print("  - Invalid plot at entry#"..tostring(playerCounter[iPlayer]-1))
							cityName = list[playerCounter[iPlayer]]
						end
					end	
				end				
			end
		end
	end
end

-- Borders
function PlaceBorders()

	print("Starting Border placement for Scenario...")
	if borderPlacement == "EXPAND" then
		print("Expanding Territory...")


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
					local city = FindNearestPlayerCity( newOwnerID, plot:GetX(), plot:GetY() )
					if city then
						--WorldBuilder.CityManager():SetPlotOwner( plot:GetX(), plot:GetY(), newOwnerID, city:GetID() )
						plot:SetOwner(-1)
						plot:SetOwner(newOwnerID, city:GetID(), true)
						bAnyBorderExpanded = true
					end
				end
			end
		end
	end
	
	if borderPlacement == "IMPORT" then
		---[[
		
		print("Placing Territory...")
		local alreadyWarnedFor	= {}
		for row in GameInfo.ScenarioTerritory() do
			if IsRowValid(row) then
				local civilizationType	= row.CivilizationType
				
				if civilizationType == nil then
					print("ERROR at rowID #"..tostring(row.Index).." : CivilizationType is NULL")
				else
					local iPlayer		= CivilizationPlayerID[civilizationType]
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
								print(" 		- PLACED !")
								plot:SetOwner(iPlayer)
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

end

-- Units
function PlaceUnits()

	print("Starting Units placement for Scenario...")
	if true then --	unitPlacement == "IMPORT"
		print("Create replacement table")
		local backup = {}
		for row in GameInfo.ScenarioUnitsReplacement() do
			if IsRowValid(row) then
				backup[row.UnitType] = row.BackupType
			end
		end
		
		print("Placing units...")
		for row in GameInfo.ScenarioUnits() do
			if IsRowValid(row) then
				local unitRow = GameInfo.Units[row.UnitType] or (backup[row.UnitType] and GameInfo.Units[backup[row.UnitType]])
				if unitRow then
					local unitTypeID		= unitRow.Index
					local unitName 			= row.UnitName
					local civilizationType	= row.CivilizationType				

					local iPlayer = CivilizationPlayerID[civilizationType]
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
end

-- Infrastructure
function PlaceInfrastructure()

	print("Starting Infrastructure placement for Scenario...")
	
	if infrastructurePlacement == "IMPORT" then
		
		print("Placing Infrastructure...")
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

end

function YnAMP_SetScenario()
	PlaceCities()
	PlaceBorders()
	PlaceUnits()
	PlaceInfrastructure()
	Game:SetProperty("YnAMP_ScenarioInitialized", true)
end
Events.LoadScreenClose.Add( YnAMP_SetScenario ) 

----------------------------------------------------------------------------------------
end
----------------------------------------------------------------------------------------
-- Scenario settings >>>>>
----------------------------------------------------------------------------------------
