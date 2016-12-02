------------------------------------------------------------------------------
--	FILE:	 YnAMP_Script.lua
--  Gedemon (2016)
--  Testing things here
------------------------------------------------------------------------------

local YnAMP_Version = GameInfo.GlobalParameters["YNAMP_VERSION"].Value -- can't use GlobalParameters.YNAMP_VERSION because Value is Text ?
print ("Yet (not) Another Maps Pack version " .. tostring(YnAMP_Version) .." (2016) by Gedemon")
print ("loading YnAMP_Script.lua")

include ("YnAMP_Utils.lua") -- can't do that ???

local mapName = MapConfiguration.GetValue("MapName")
print ("Map Name = " .. tostring(mapName))

----------------------------------------------------------------------------------------
-- City renaming
----------------------------------------------------------------------------------------
local nameUsedOnContinent = {}
local nameUsedByCivilization = {}

function SetExistingCityNames()
	nameUsedOnContinent = {}
	nameUsedByCivilization = {}
	for _, player_ID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		local player = Players[player_ID]
		local playerConfig = PlayerConfigurations[player_ID]
		local civilization = playerConfig:GetCivilizationTypeName()
		local playerCities = player:GetCities();
		for j, city in playerCities:Members() do
			local plot = Map.GetPlot(city:GetX(), city:GetY())
			local continent = plot:GetContinentType()
			
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
		SetExistingCityNames()
		local x = pCity:GetX()
		local y = pCity:GetY()
		local CivilizationTypeName = PlayerConfigurations[ownerPlayerID]:GetCivilizationTypeName()
		local startPos, endPos = string.find(CivilizationTypeName, "CIVILIZATION_")
		local sCivSuffix = string.sub(CivilizationTypeName, endPos)
		print("Trying to find name for city of ".. tostring(CivilizationTypeName) .." at "..tostring(x)..","..tostring(y))
		local possibleName = {}
		local maxRange = 1
		local bestDistance = 99
		local bestDefaultDistance = 99
		local bestName = nil
		local bestDefaultName = nil
		local cityPlot = Map.GetPlot(x, y)
		for row in GameInfo.CityMap() do
			if row.MapName == mapName  then
				local name = row.CityLocaleName
				local nameX = row.X
				local nameY = row.Y
				local nameMaxDistance = row.Area or maxRange
				-- rough selection in a square first before really testing distance
				if (math.abs(x - nameX) <= nameMaxDistance) and (math.abs(y - nameY) <= nameMaxDistance) then	
					print("- testing "..tostring(name).." at "..tostring(nameX)..","..tostring(nameY).." max distance is "..tostring(nameMaxDistance)..", best distance so far is "..tostring(bestDistance))
					
					local distance = Map.GetPlotDistance(x, y ,nameX, nameY)
					if distance <= nameMaxDistance and distance < bestDistance then
					
						local sCityNameForCiv = tostring(name) .. sCivSuffix
					
						if CivilizationTypeName == row.Civilization and not IsNameUsedByCivilization(name, CivilizationTypeName) then -- this city is specific to this Civilization, and the name is not already used
							bestDistance = distance
							bestName = name
						elseif not row.Civilization then -- do not use Civilization specific name with another Civilization, only generic							
							if Locale.Lookup(sCityNameForCiv) ~= sCityNameForCiv and not isNameUsedByCivilization(sCityNameForCiv, CivilizationTypeName) then -- means that this civilization has a specific name available for this generic city
								bestDistance = distance
								bestName = sCityNameForCiv
							elseif distance < bestDefaultDistance and not IsNameUsedOnContinent(name, x, y) then -- use generic name
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

------------------------------------------------------

function OnCombat(...)
	print("-------------------------")
	print("Events.Combat : ")
	print(unpack({...}))
	print("-------------------------")
end
Events.Combat.Add( OnCombat )

function OnCombatVisBegin(...)
	print("-------------------------")
	print("Events.CombatVisBegin :")
	print(unpack({...}))
	print("-------------------------")
end
Events.CombatVisBegin.Add( OnCombatVisBegin )

function OnCombatVisEnd(...)
	print("-------------------------")
	print("Events.CombatVisEnd : ")
	print(unpack({...}))
	print("-------------------------")
end
Events.CombatVisEnd.Add( OnCombatVisEnd )
