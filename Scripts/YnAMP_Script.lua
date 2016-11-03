------------------------------------------------------------------------------
--	FILE:	 YnAMP_Script.lua
--  Gedemon (2016)
------------------------------------------------------------------------------

local YnAMP_Version = GameInfo.GlobalParameters["YNAMP_VERSION"].Value -- can't use GlobalParameters.YNAMP_VERSION because Value is Text ?
print ("Yet (not) Another Maps Pack version " .. tostring(YnAMP_Version) .." (2016) by Gedemon")
print ("loading YnAMP_Script.lua")

include ("YnAMP_Utils.lua") -- can't do that ?

----------------------------------------------------------------------------------------
-- Testing City renaming
----------------------------------------------------------------------------------------
function CityNewGetName(self)
	local name = self:OldGetName()
	name = "test"
	--
	return name
end
function InitializeCityFunctions( ownerPlayerID, cityID)
	local pCity= CityManager.GetCity(ownerPlayerID, cityID);
	local c = getmetatable(pCity).__index
	if c.OldGetName then -- initialize once
		return
	end
	
	-- save old functions
	c.OldGetName = c.GetName
	
	-- set replacement functions
	c.GetName = CityNewGetName
	
	-- set new functions
	--c.NewFunction = NewFunction

	--Events.SerialEventGameDataDirty()
end
Events.CityAddedToMap.Add( InitializeCityFunctions )


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
		local ratio = Round(placedPercent * 100 / resRow.Frequency)
		if resRow.Frequency > 0 then
			print("Resource = " .. tostring(resRow.ResourceType).."		placed = " .. tostring(numRes).."	(" .. tostring(placedPercent).."%)	frequency = " .. tostring(resRow.Frequency).."	ratio = " .. tostring(ratio))
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

