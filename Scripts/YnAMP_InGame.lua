------------------------------------------------------------------------------
--	FILE:	 YnAMP_InGame.lua
--  Gedemon (2016)
------------------------------------------------------------------------------

local YnAMP_Version = GameInfo.GlobalParameters["YNAMP_VERSION"].Value
print ("Yet (not) Another Maps Pack version " .. tostring(YnAMP_Version) .." (2016-2019) by Gedemon")
print ("loading YnAMP_InGame.lua")

-- Sharing UI/Gameplay context (ExposedMembers.YnAMP is initialized in YnAMP_Common.lua, included in YnAMP_Script.lua)
local YnAMP = ExposedMembers.YnAMP

local mods = Modding.GetActiveMods()
if mods ~= nil then
	print("Active mods:")
	for i,v in ipairs(mods) do
		print("- ".. Locale.Lookup(v.Name))
	end
end

local mapName = MapConfiguration.GetValue("MapName")
print ("Map Name = " .. tostring(mapName))


--=====================================================================================--
-- Export Cliffs positions from a civ6 map to Lua.log
--=====================================================================================--
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


--=====================================================================================--
-- Export a complete civ6 map to Lua.log
--=====================================================================================--
-- now set in YnAMP_Script.lua and shared for InGame and WB context
--[[
function ExportMap()
	local g_iW, g_iH = Map.GetGridSize()
	for iY = 0, g_iH - 1 do
		for iX = g_iW - 1, 0, -1  do
			local plot = Map.GetPlot(iX,iY)
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
			local terrainType 	= plot:GetTerrainType()
			local featureType	= plot:GetFeatureType()
			local continentType	= plot:GetContinentType()
			local resourceType	= plot:GetResourceType(-1)
			if terrainType ~= -1 then
				terrainType = "\""..GameInfo.Terrains[terrainType].TerrainType.."\""
			else
				print("Error: terrainType = -1 at ["..plot:GetX().."]["..plot:GetY().."]")
				break
			end
			
			if featureType ~= -1 then
				featureType = "\""..GameInfo.Features[featureType].FeatureType.."\""
			end
			if continentType ~= -1 then
				continentType = "\""..GameInfo.Continents[continentType].ContinentType.."\""
			end
			if resourceType ~= -1 then
				resourceType = "\""..GameInfo.Resources[resourceType].ResourceType.."\""
			end
			local endStr =""
			if plot:IsLake() then endStr = " -- Lake" end
			print("MapToConvert["..plot:GetX().."]["..plot:GetY().."]={"..terrainType..","..featureType..","..continentType..",{{"..NEOfRiver..","..plot:GetRiverSWFlowDirection().. "},{"..WOfRiver..","..plot:GetRiverEFlowDirection().."},{"..NWOfRiver..","..plot:GetRiverSEFlowDirection().."}},{".. resourceType ..","..tostring(1).."},{"..NEOfCliff..","..WOfCliff..","..NWOfCliff.."}}"..endStr)
		end
	end
end
--]]

--=====================================================================================--
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


--=====================================================================================--
-- Add "Export to Lua" button to the Option Menu and add keyboard shortcut (ctrl+alt+E)
--=====================================================================================--
function OnInputHandler( pInputStruct:table )
	local uiMsg:number = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then
		if pInputStruct:GetKey() == Keys.E and pInputStruct:IsControlDown() and pInputStruct:IsAltDown() then
			YnAMP.ExportMap()
			UI.PlaySound("Alert_Neutral")
		end
		-- pInputStruct:IsShiftDown() and pInputStruct:IsAltDown() and  pInputStruct:IsControlDown()
	end
	return false
end

function OnEnterGame()
	Controls.ExportMapToLua:RegisterCallback( Mouse.eLClick, YnAMP.ExportMap )
	Controls.ExportMapToLua:SetHide( false )
	Controls.ExportMapToLua:ChangeParent(ContextPtr:LookUpControl("/InGame/TopOptionsMenu/MainStack"))
	--Automation.SetInputHandler( OnInputHandler )
	--ContextPtr:SetInputHandler(OnInputHandler, true) -- still not working (16-sept-2019)
end
Events.LoadScreenClose.Add(OnEnterGame)


--=====================================================================================--
-- Updating Loading text
--=====================================================================================--

local sCurrentText = "test"
function StartLoadingTextUpdate()
	print("Starting Loading Text Update...")
	Events.GameCoreEventPublishComplete.Add( CheckLoadingTextUpdate )
end
--Events.LoadScreenClose.Add( LaunchScriptWithPause ) -- launching the script when the load screen is closed, you can use your own events

function StopLoadingTextUpdate() -- GameCoreEventPublishComplete is called frequently, keep it clean

	print("Stopping Loading Text Update...")
	Events.GameCoreEventPublishComplete.Remove( CheckLoadingTextUpdate )
end
Events.LoadScreenClose.Add( StopLoadingTextUpdate )

function CheckLoadingTextUpdate()
	if YnAMP and sCurrentText ~= YnAMP.LoadingText then
		sCurrentText = YnAMP.LoadingText
		print("LoadScreen LoadScreen Context = ", ContextPtr:LookUpControl("/LoadScreen/"))
		print("LoadScreen InGame Context = ", ContextPtr:LookUpControl("/InGame/LoadScreen/"))
		print("LoadScreen FrontEnd Context = ", ContextPtr:LookUpControl("/FrontEnd/LoadScreen/"))
		print("FrontEnd Context = ", ContextPtr:LookUpControl("/FrontEnd/"))
		print("InGame Context = ", ContextPtr:LookUpControl("/InGame/"))
	end
end

--=====================================================================================--
-- Sharing UI function with Gameplay context
--=====================================================================================--

function GetGrandStrategicAI(iPlayer)
	local player = Players[iPlayer]
	return player and player:GetGrandStrategicAI()
end
--YnAMP.GetGrandStrategicAI = GetGrandStrategicAI -- move to initialize

--=====================================================================================--
-- Cleaning on exit
--=====================================================================================--
function Cleaning()
	print ("Cleaning YnAMP table...")
	-- 
	ExposedMembers.YnAMP = nil
	--print ("Cleaning InputHandler...")
	--Automation.RemoveInputHandler( OnInputHandler )
end
Events.LeaveGameComplete.Add(Cleaning)
LuaEvents.RestartGame.Add(Cleaning)

function Initialize()
	StartLoadingTextUpdate()
end
Initialize()




