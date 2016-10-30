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

