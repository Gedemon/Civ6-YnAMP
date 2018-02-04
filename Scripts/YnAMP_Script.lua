------------------------------------------------------------------------------
--	FILE:	 YnAMP_Script.lua
--  Gedemon (2016-2017)
------------------------------------------------------------------------------

local YnAMP_Version = GameInfo.GlobalParameters["YNAMP_VERSION"].Value
print ("Yet (not) Another Maps Pack version " .. tostring(YnAMP_Version) .." (2016-2018) by Gedemon")
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

local bUseRelativePlacement = MapConfiguration.GetValue("UseRelativePlacement")
local g_ReferenceMapWidth 	= MapConfiguration.GetValue("ReferenceMapWidth") or 180
local g_ReferenceMapHeight 	= MapConfiguration.GetValue("ReferenceMapHeight") or 94

local g_iW, g_iH 	= Map.GetGridSize()
local g_ReferenceWidthFactor  = g_ReferenceMapWidth / g_iW 
local g_ReferenceHeightFactor = g_ReferenceMapHeight / g_iH
local g_ReferenceWidthRatio   = g_iW / g_ReferenceMapWidth 
local g_ReferenceHeightRatio  = g_iH / g_ReferenceMapHeight

local g_ExtraRange = 0
if bUseRelativePlacement then
	g_ExtraRange = 10 --Round(10 * math.sqrt(g_iW * g_iH) / math.sqrt(g_ReferenceMapWidth * g_ReferenceMapHeight))
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
		local refMapX, refMapY = mapX, mapY
		if bUseRelativePlacement then
			-- Convert plot position to the corresponding position on the reference map
			refMapX 	= Round(g_ReferenceWidthFactor * mapX)
			refMapY 	= Round(g_ReferenceHeightFactor * mapY)
		end
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
	local hasMap = {}
	for row in GameInfo.CityMap() do
		local name = row.CityLocaleName
		if name then
			hasMap[name] = true
			hasMap[Locale.Lookup(name)] = true
		else
			print("ERROR : no name at row "..tostring(row.Index + 1))
		end
	end
	for row in GameInfo.CityNames() do
		local name = row.CityName
		local civilization = row.CivilizationType
		if not (hasMap[name] or hasMap[Locale.Lookup(name)]) then
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
		if startingPlot and not startingPlot:IsCity() then
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

-- test
--[[
local g_Timer = 0
local g_Pause = 10

function LaunchScriptWithPause()
	Events.GameCoreEventPublishComplete.Add( CheckTimer )
end
Events.LoadScreenClose.Add( LaunchScriptWithPause ) -- launching the script when the load screen is closed, you can use your own events

function StopScriptWithPause() -- GameCoreEventPublishComplete is called frequently, keep it clean
	Events.GameCoreEventPublishComplete.Remove( CheckTimer )
end

function ChangePause(value)
	print("changing pause value to ", value)
	g_Pause = value
end

local AttachStuffToUnits = coroutine.create(function()
	-- lets do stuff for 10 units
	for unit = 1, 10 do
		print("Doing stuff on unit #"..tostring(unit))
		-- 
		-- attach something to the unit or whatever you want to do before needing a pause
		--
		print("requesting pause in script for ", g_Pause, " seconds at time = ".. tostring( Automation.GetTime() ))
		g_Timer = Automation.GetTime()
		coroutine.yield()
		-- after g_Pause seconds, the script will start again from here
		print("resuming script at time = ".. tostring( Automation.GetTime() ))	
	end	
	StopScriptWithPause()
end)

function CheckTimer()	
	if Automation.GetTime() >= g_Timer + g_Pause then
		g_Timer = Automation.GetTime()
		coroutine.resume(AttachStuffToUnits)
	end
end
--]]

