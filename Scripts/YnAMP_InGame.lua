------------------------------------------------------------------------------
--	FILE:	 YnAMP_InGame.lua
--  Gedemon (2016)
------------------------------------------------------------------------------

local YnAMP_Version = GameInfo.GlobalParameters["YNAMP_VERSION"].Value -- can't use GlobalParameters.YNAMP_VERSION because Value is Text ?
print ("Yet (not) Another Maps Pack version " .. tostring(YnAMP_Version) .." (2016) by Gedemon")
print ("loading YnAMP_InGame.lua")

include ("YnAMP_Utils.lua") -- can't do that ???

local mapName = MapConfiguration.GetValue("MapName")
print ("Map Name = " .. tostring(mapName))

----------------------------------------------------------------------------------------
-- Testing City renaming
----------------------------------------------------------------------------------------

function ChangeCityName( ownerPlayerID, cityID)
	local pCity = CityManager.GetCity(ownerPlayerID, cityID)
	if pCity then
		local x = pCity:GetX()
		local y = pCity:GetY()
		local CivilizationTypeName = PlayerConfigurations[ownerPlayerID]:GetCivilizationTypeName()
		print("Trying to find name for city of ".. tostring(CivilizationTypeName) .." at "..tostring(x)..","..tostring(y))
		local possibleName = {}
		local maxRange = 1
		local bestDistance = maxRange + 1
		local bestName = nil
		local bestDefaultName = nil
		local cityPlot = Map.GetPlot(x, y)
		for row in GameInfo.CityMap() do
			if row.MapName == mapName  then
				local nameX = row.X
				local nameY = row.Y
				local nameMaxDistance = row.Area or maxRange
				-- rough selection before testing distance
				print("- testing "..tostring(row.CityLocaleName).." at "..tostring(nameX)..","..tostring(nameX).." max distance is "..tostring(nameMaxDistance)..", best distance so far is "..tostring(bestDistance))
				if (x - nameMaxDistance <= nameX and x + nameMaxDistance >= nameX) and (y - nameMaxDistance <= nameY and y + nameMaxDistance >= nameY) then	
					local namePlot = Map.GetPlot(nameX, nameY)
					local distance = Map.GetPlotDistance(x, y ,nameX, nameY)
					if distance <= nameMaxDistance and distance < bestDistance then
						if CivilizationTypeName == row.Civilization then
							bestDistance = distance
							bestName = row.CityLocaleName
						elseif not row.Civilization then -- do not use Civilization specific name with another Civilization, only generic
							bestDistance = distance
							bestDefaultName = row.CityLocaleName						
						end
					end				
				end
			end
		end
		if not bestName then
			bestName = bestDefaultName
		end
		if bestName then
			--Send net message to change name.
			local params = {}
			params[CityCommandTypes.PARAM_NAME] = bestName
			CityManager.RequestCommand(pCity, CityCommandTypes.NAME_CITY, params)
			print("- New name : " .. tostring(bestName))
		else
			print("- Can't find a name for this position !")
			-- todo : use a name not reserved for the map
		end
	end
end
Events.CityAddedToMap.Add( ChangeCityName )


----------------------------------------------------------------------------------------
-- Export Cliffs positions from a civ6 map to Lua.log
----------------------------------------------------------------------------------------
function ExportCliffs()
	local iPlotCount = Map.GetPlotCount();
	for iPlotLoop = 0, iPlotCount-1, 1 do
		local bData = false
		local plot = Map.GetPlotByIndex(iPlotLoop)
		local NEOfCliff = 0
		local WOfCliff = 0
		local NWOfCliff = 0
		if plot:IsNEOfCliff() then NEOfCliff = 1 end 
		if plot:IsWOfCliff() then WOfCliff = 1 end 
		if plot:IsNWOfCliff() then NWOfCliff = 1 end 
		
		bData = NEOfCliff + WOfCliff + NWOfCliff > 0
		if bData then
			print("Civ6DataToConvert["..plot:GetX().."]["..plot:GetY().."]={{"..NEOfCliff..","..WOfCliff..","..NWOfCliff.."},}")
		end
	end
end


----------------------------------------------------------------------------------------
-- Export a complete civ6 map to Lua.log
----------------------------------------------------------------------------------------
function ExportMap()
	local iPlotCount = Map.GetPlotCount();
	for iPlotLoop = 0, iPlotCount-1, 1 do
		local bData = false
		local plot = Map.GetPlotByIndex(iPlotLoop)
		local NEOfCliff = 0
		local WOfCliff = 0
		local NWOfCliff = 0
		if plot:IsNEOfCliff() then NEOfCliff = 1 end 
		if plot:IsWOfCliff() then WOfCliff = 1 end 
		if plot:IsNWOfCliff() then NWOfCliff = 1 end 
		local NEOfRiver = 0
		local WOfRiver = 0
		local NWOfRiver = 0
		if plot:IsNEOfRiver() then NEOfRiver = 1 end -- GetRiverSWFlowDirection()
		if plot:IsWOfRiver() then WOfRiver = 1 end -- GetRiverEFlowDirection()
		if plot:IsNWOfRiver() then NWOfRiver = 1 end -- GetRiverSEFlowDirection()
		print("MapToConvert["..plot:GetX().."]["..plot:GetY().."]={"..plot:GetTerrainType()..","..plot:GetFeatureType()..","..plot:GetContinentType()..",{{"..NEOfRiver..","..plot:GetRiverSWFlowDirection().. "},{"..WOfRiver..","..plot:GetRiverEFlowDirection().."},{"..NWOfRiver..","..plot:GetRiverSEFlowDirection().."}},{"..plot:GetResourceType(-1)..","..tostring(1).."},{"..NEOfCliff..","..WOfCliff..","..NWOfCliff.."}}")
	end
end

----------------------------------------------
function ResourcesStatistics(g_iW, g_iH)
	print("------------------------------------")
	print("-- Resources Placement Statistics --")
	print("------------------------------------")
	local resTable = {}
	for resRow in GameInfo.Resources() do
		resTable[resRow.Index] = 0
	end
	
	local totalplots = g_iW * g_iH
	print("-- Total plots on map = " .. tostring(totalplots))
	print("------------------------------------")
	for i = 0, (totalplots) - 1, 1 do
		plot = Map.GetPlotByIndex(i)
		local eResourceType = plot:GetResourceType()
		if (eResourceType ~= -1) then
			if resTable[eResourceType] then
				resTable[eResourceType] = resTable[eResourceType] + 1
			else
				print("WARNING - resTable[eResourceType] is nil for eResourceType = " .. tostring(eResourceType))
			end
		end
	end	

	for resRow in GameInfo.Resources() do
		local numRes = resTable[resRow.Index]
		local placedPercent = Round(numRes / totalplots * 10000) / 100
		if placedPercent == 0 then placedPercent = "0.00" end
		local ratio = Round(placedPercent * 100 / resRow.Frequency)
		if ratio == 0 then ratio = "0.00" end
		if resRow.Frequency > 0 then
			print("Resource = " .. tostring(resRow.ResourceType).."		placed = " .. tostring(numRes).."	(" .. tostring(placedPercent).."%)	frequency = " .. tostring(resRow.Frequency).."		ratio = " .. tostring(ratio))
		end
	end

	print("------------------------------------")
end

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

