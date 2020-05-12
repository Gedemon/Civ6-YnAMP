------------------------------------------------------------------------------
--	FILE:	 YnAMP_Common.lua
--  Gedemon (2020)
------------------------------------------------------------------------------
print ("loading YnAMP_Common.lua")

------------------------------------------------------------------------------
-- Sharing UI/Gameplay context
------------------------------------------------------------------------------

ExposedMembers.YnAMP 			= ExposedMembers.YnAMP or {}
ExposedMembers.ConfigYnAMP 		= ExposedMembers.ConfigYnAMP or {}
ExposedMembers.YnAMP_Loading 	= ExposedMembers.YnAMP_Loading or {}

YnAMP 			= ExposedMembers.YnAMP
ConfigYnAMP 	= ExposedMembers.ConfigYnAMP
YnAMP_Loading 	= ExposedMembers.YnAMP_Loading


------------------------------------------------------------------------------
-- Defines
------------------------------------------------------------------------------

bUseRelativePlacement 	= MapConfiguration.GetValue("UseRelativePlacement")
bUseRelativeFixedTable 	= bUseRelativePlacement and MapConfiguration.GetValue("UseRelativeFixedTable")
g_ReferenceMapWidth 	= MapConfiguration.GetValue("ReferenceMapWidth") or 180
g_ReferenceMapHeight 	= MapConfiguration.GetValue("ReferenceMapHeight") or 94


g_iW		= 0
g_iH		= 0
g_MapSize	= 0

-- The base map is the Largest Earth Map for the Terra Map hardcoded region table
g_LargestMapWidth 		= 230
g_LargestMapHeight 		= 116
g_LargestMapOldWorldX	= 155
g_LargestEarthOceanWidth 	= 24

g_SizeDual      			=  44*26
g_SizeTiny      			=  60*36
g_SizeSmall     			=  74*46
g_SizeStandard  			=  84*54
g_SizeLarge     			=  96*60
g_SizeHuge      			= 106*66
g_SizeEnormous  			= 128*80
g_SizeGiant     			= 180*94
g_SizeLudicrous 			= 200*104--230*115

g_WidthFactor			= 0
g_HeightFactor			= 0
g_WidthRatio			= 0
g_HeightRatio			= 0
g_ReferenceSizeRatio	= 0

-- set values of the reference map for placement
g_ReferenceMapWidth 	= MapConfiguration.GetValue("ReferenceMapWidth") or 180
g_ReferenceMapHeight 	= MapConfiguration.GetValue("ReferenceMapHeight") or 94
g_ReferenceMapSize  	= g_ReferenceMapWidth*g_ReferenceMapHeight
g_ReferenceWidthFactor	= 0
g_ReferenceHeightFactor	= 0
g_ReferenceWidthRatio	= 0
g_ReferenceHeightRatio	= 0

g_UncutMapWidth 		= 0
g_UncutMapHeight 		= 0
g_OffsetX 				= 0
g_OffsetY 				= 0
bUseOffset				= false

g_ReplacementRangeForTSL	= nil
g_StartingPlotRange			= nil
g_MinStartDistanceMajor		= nil
g_MaxStartDistanceMajor		= nil

XFromRefMapX 	= {}
YFromRefMapY 	= {}
RefMapXfromX 	= {}
RefMapYfromY 	= {}
sX, sY 			= 0, 0
lX, lY 			= 0, 0
skipX, skipY	= MapConfiguration.GetValue("RescaleSkipX") or 999, MapConfiguration.GetValue("RescaleSkipY") or 999

g_LatitudeDegreesPerY	= nil
g_OriginLatitude		= nil
g_LatitudeBorderOffset	= 5		-- to allows border to be a but norther or souther than the northern or southern city

g_ExtraRange 			= 0		-- Used when the reference maps is smaller than the actual map


------------------------------------------------------------------------------
-- Set globals
------------------------------------------------------------------------------
local bGlobalsInitialized = false
function SetGlobals()

	if bGlobalsInitialized then return end
	
	print("----------------------")
	print("Setting common Globals")
	print("----------------------")
	g_iW, g_iH 	= Map.GetGridSize();
	g_MapSize	= g_iW * g_iH
	
	g_UncutMapWidth 		= MapConfiguration.GetValue("UncutMapWidth") or g_iW
	g_UncutMapHeight 		= MapConfiguration.GetValue("UncutMapHeight") or g_iH

	g_OffsetX 				= MapConfiguration.GetValue("StartX") or 0
	g_OffsetY 				= MapConfiguration.GetValue("StartY") or 0
	bUseOffset				= (g_OffsetX + g_OffsetY > 0) and (MapConfiguration.GetValue("StartX") ~= MapConfiguration.GetValue("EndX")) and (MapConfiguration.GetValue("StartY") ~= MapConfiguration.GetValue("EndY"))

	g_WidthFactor 	= g_LargestMapWidth / g_iW
	g_HeightFactor 	= g_LargestMapHeight / g_iH
	g_WidthRatio 	= g_iW / g_LargestMapWidth
	g_HeightRatio 	= g_iH / g_LargestMapHeight

	g_ReferenceWidthFactor  = g_ReferenceMapWidth / g_iW
	g_ReferenceHeightFactor = g_ReferenceMapHeight / g_iH
	g_ReferenceWidthRatio   = g_iW / g_ReferenceMapWidth
	g_ReferenceHeightRatio  = g_iH / g_ReferenceMapHeight

	g_ReferenceSizeRatio = math.sqrt(g_iW * g_iH) / math.sqrt(g_ReferenceMapSize)

	g_StartingPlotRange 		= 16 * g_ReferenceSizeRatio -- todo: what's that magic number here ?
	
	local replacementRangeForTSL	= MapConfiguration.GetValue("ReplacementRangeForTSL") or 10
	g_ReplacementRangeForTSL 		= replacementRangeForTSL * g_ReferenceSizeRatio

	g_NewWorldX = g_LargestMapOldWorldX * g_WidthRatio
	
	g_MaxStartDistanceMajor = math.sqrt(g_MapSize / PlayerManager.GetWasEverAliveMajorsCount())
	g_MinStartDistanceMajor = g_MaxStartDistanceMajor / 3

	BuildRefXY()
	SetLatitudesGlobals()
	
	if bUseRelativePlacement and g_MapSize > g_ReferenceMapSize then
		g_ExtraRange = 0 --Round(10 * math.sqrt(g_MapSize) / math.sqrt(g_ReferenceMapSize))
	end
	
	print("g_iW, g_iH = ", g_iW, g_iH)
	print("g_LargestMapWidth, g_LargestMapHeight 	= ", g_LargestMapWidth, g_LargestMapHeight)
	print("g_WidthFactor, g_HeightFactor, g_WidthRatio, g_HeightRatio 	= ", g_WidthFactor, g_HeightFactor, g_WidthRatio, g_HeightRatio)
	print("g_ReferenceMapWidth, g_ReferenceMapHeight = ", g_ReferenceMapWidth, g_ReferenceMapHeight)
	print("g_ReferenceWidthFactor, g_ReferenceHeightFactor, g_ReferenceWidthRatio,  g_ReferenceHeightRatio	= ", g_ReferenceWidthFactor, g_ReferenceHeightFactor, g_ReferenceWidthRatio, g_ReferenceHeightRatio)
	print("StartX, EndX, StartY, EndY ", MapConfiguration.GetValue("StartX"), MapConfiguration.GetValue("EndX"), MapConfiguration.GetValue("StartY"), MapConfiguration.GetValue("EndY"))
	print("g_UncutMapWidth, g_UncutMapHeight, bUseOffset", g_UncutMapWidth, g_UncutMapHeight, bUseOffset)
	print("bUseRelativePlacement, bUseRelativeFixedTable, skipX, skipY  = ",bUseRelativePlacement, bUseRelativeFixedTable, skipX, skipY)
	print("g_ReferenceSizeRatio	= ", g_ReferenceSizeRatio)
	print("g_StartingPlotRange = ", g_StartingPlotRange)
	print("replacementRangeForTSL, g_ReplacementRangeForTSL = ", replacementRangeForTSL, g_ReplacementRangeForTSL)
	print("g_MaxStartDistanceMajor, g_MinStartDistanceMajor = ", g_MaxStartDistanceMajor, g_MinStartDistanceMajor)
	print("g_LatitudeDegreesPerY, g_OriginLatitude = ",g_LatitudeDegreesPerY,g_OriginLatitude)
	print("----------------------")

	bGlobalsInitialized = true
end


------------------------------------------------------------------------------
-- Math
------------------------------------------------------------------------------
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


------------------------------------------------------------------------------
-- Handling script with pauses
--
-- When Lua takes too much time to process something, it seems to cause the game to crash
-- so we're using coroutines that can yield during some time-consuming loops and resume
-- after a few ticks of gamecore (using Events.GameCoreEventPublishComplete)
------------------------------------------------------------------------------
---[[
local g_LastPause 		= 0
local g_TimeForPause	= 0.075	--0.1/0.05	-- running time in seconds before yielding
local g_TickBeforeResume= 4		--5		-- number of call to GameCoreEventPublishComplete before resuming the coroutine
local g_Tick			= 0
local bLoadScreenClosed	= false
local CoroutineList		= {}

local bFirstCheck		= true
local g_FirstCheckTime	= 0
local g_FirstCheckPause	= 3


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

	print("Stopping ScriptWithPause...")
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
	if bFirstCheck or (g_LastPause + g_TimeForPause < Automation.GetTime()) then
		print("**** coroutine.yield at ", Automation.GetTime() - g_LastPause, g_TimeForPause)
		if bFirstCheck then
			print("**** Delayed start, pause for ", g_FirstCheckPause)
			g_FirstCheckTime = Automation.GetTime()
		end
		coroutine.yield()
		--return true
	end
end

local countdown = 999
function CheckTimer()

	if bFirstCheck then
		if g_FirstCheckTime > 0 then
			if (g_FirstCheckTime + g_FirstCheckPause > Automation.GetTime()) then
				local t = g_FirstCheckPause - Round(Automation.GetTime()-g_FirstCheckTime)
				if t < countdown then
					print(t)
					countdown = t
				end
				return
			else
				print("**** Starting...")
				bFirstCheck = false
			end
		end
	end

	g_Tick	= g_Tick + 1
	
	if #CoroutineList > 0 then -- show ticking only when there are Coroutine running
		--print("**** Tick = ", g_Tick)
	end

	if g_Tick >= g_TickBeforeResume then
		local toRemove 	= {}
		g_Tick			= 0
		for i, runningCo in ipairs(CoroutineList) do
			if coroutine.status(runningCo)=="dead" then
				print("**** removing dead coroutine: "..tostring(runningCo), i)
				table.insert(toRemove, i)
			elseif coroutine.status(runningCo)=="suspended" then
				g_LastPause = Automation.GetTime()
				local ok, errorMsg = coroutine.resume(runningCo)
				if not ok then
					error("**** ERROR in co-routine : " .. errorMsg)
				end
			end
		end
		for _, i in ipairs(toRemove) do
			if CoroutineList[i] and coroutine.status(CoroutineList[i])=="dead" then
				table.remove(CoroutineList, i)
			else
				print("**** ERROR, trying to remove not dead Coroutine: "..tostring(CoroutineList[i]), i)
			end
		end
		if #CoroutineList == 0 and bLoadScreenClosed and not bFirstCheck then
		--	StopScriptWithPause()
		end
	end
end
--]]

------------------------------------------------------------------------------
-- Strings
------------------------------------------------------------------------------
local indentationString	= ".............................." -- maxLength = 30 car
local indentationSpaces	= "                              "

function Indentation(str, maxLength, bAlignRight, bShowSpace)
	local bIsNumber	= type(str) == "number"
	local minLength	= 2
	local indentStr	= (bShowSpace and indentationString) or indentationSpaces
	local maxLength = math.max(maxLength or string.len(indentStr))
	--local str 		= (bIsNumber and str > math.pow(10,maxLength-2)-1 and tostring(math.floor(str))) or tostring(str)
	--local str 		= (bIsNumber and str > 9 and tostring(math.floor(str))) or tostring(str)
	local str 		= tostring(str)
	local length 	= string.len(str)
	
	if length > maxLength and bIsNumber then
		str		= tostring(math.floor(tonumber(str)))
		length 	= string.len(str)
	end
	
	if length < maxLength then
		if bAlignRight then
			return string.sub(indentStr, 1, maxLength - length) .. str
		else
			return str.. string.sub(indentStr, 1, maxLength - length)
		end
	elseif length > maxLength and length > minLength then
		if bIsNumber then
			return tostring(math.pow(10,maxLength)-1)  -- return 999 for value >= 1000 when maxLength = 3
		else
			return string.sub(str, 1, maxLength-1).."."
		end
	else
		return str
	end
end


------------------------------------------------------------------------------
-- Export a complete civ6 map to Lua.log
------------------------------------------------------------------------------
function ExportMap()
	local g_iW, g_iH = Map.GetGridSize()
	for iY = 0, g_iH - 1 do
		for iX = g_iW - 1, 0, -1  do
		
			local plot			= Map.GetPlot(iX,iY)
			local NEOfCliff 	= plot:IsNEOfCliff() and 1 or 0
			local WOfCliff		= plot:IsWOfCliff() and 1 or 0
			local NWOfCliff 	= plot:IsNWOfCliff() and 1 or 0
			local NEOfRiver		= plot:IsNEOfRiver() and 1 or 0 -- GetRiverSWFlowDirection()
			local WOfRiver		= plot:IsWOfRiver() and 1 or 0	-- GetRiverEFlowDirection()
			local NWOfRiver		= plot:IsNWOfRiver() and 1 or 0	-- GetRiverSEFlowDirection()
			local terrainType 	= plot:GetTerrainType()
			local featureType	= plot:GetFeatureType()
			local continentType	= plot:GetContinentType()
			local resourceType	= plot:GetResourceType(-1)
			local lowlandType	= (TerrainManager and TerrainManager.GetCoastalLowlandType and TerrainManager.GetCoastalLowlandType( plot:GetIndex() )) or -1
			local numResource	= plot:GetResourceCount()
			
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

			print("MapToConvert["..plot:GetX().."]["..plot:GetY().."]={"..terrainType..","..featureType..","..continentType..",{{"..NEOfRiver..","..plot:GetRiverSWFlowDirection().. "},{"..WOfRiver..","..plot:GetRiverEFlowDirection().."},{"..NWOfRiver..","..plot:GetRiverSEFlowDirection().."}},{".. resourceType ..","..tostring(numResource).."},{"..NEOfCliff..","..WOfCliff..","..NWOfCliff.."},".. tostring(lowlandType).."}"..endStr)
		end
	end
	
	-- export Scenario
	local scenarioString 	= ScenarioName and "ScenarioName=\""..tostring(ScenarioName).."\"" or ""
	local mapString 		= ScenarioName and "ScenarioName=\""..tostring(ScenarioName).."\"" or ""
	local stringTable 		= {}
	local cityNames 		= {}
	local pPlot
	local iOwner
	
	print("<!--******************************---->")
	print("<!--*******   City list   ********---->")
	print("<!--******************************---->")
	print("<ScenarioCities>")
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local civilizationType	= CivTypePlayerID[iPlayer]
		if civilizationType then
			local player	= Players[iPlayer]
			local Cities	= player and player:GetCities()
			if Cities and Cities.Members then
				for i, pCity in Cities:Members() do
					table.insert( cityNames ,"	<Replace Tag=\"".. tostring(pCity:GetName()) .."\" Text=\"".. Locale.Lookup(pCity:GetName()) .."\" Language=\"en_US\" />")
					print("	<Replace ".. scenarioString .. mapString .." CivilizationType=\"".. tostring(civilizationType).."\" CitySize=\""..tostring(pCity:GetPopulation()) .."\"	CityName=\"".. tostring(pCity:GetName()) .."\"	X=\"".. tostring(pCity:GetX()) .."\" Y=\"".. tostring(pCity:GetY()) .."\"	/>")
				end
			end
		end
	end	
	print("</ScenarioCities>")
	--[[
	print("<!--******************************---->")
	print("<!--*******   City Names  ********---->")
	print("<!--******************************---->")
	print("<LocalizedText>")
	for i, str in ipairs(cityNames) do print(str) end
	print("</LocalizedText>")
	--]]
	
	print("<!--******************************---->")
	print("<!--*******   Territory   ********---->")
	print("<!--******************************---->")
	print("<ScenarioTerritory>")
	for iY = 0, g_iH - 1 do
		for iX = g_iW - 1, 0, -1  do
			pPlot 	= Map.GetPlot(iX,iY)
			iOwner	= pPlot:GetOwner()
			if iOwner ~= -1 then
				local civilizationType	= CivTypePlayerID[iOwner]
				if civilizationType then
					print("	<Replace ".. scenarioString .. mapString .." CivilizationType=\"".. tostring(civilizationType).."\" X=\"".. tostring(pPlot:GetX()) .."\" Y=\"".. tostring(pPlot:GetY()) .."\"		/>")
				end
			end
		end
	end	
	print("</ScenarioTerritory>")	
	
	print("<!--******************************---->")
	print("<!--*******   Unit list   ********---->")
	print("<!--******************************---->")
	print("<ScenarioUnits>")
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local civilizationType	= CivTypePlayerID[iPlayer]
		if civilizationType then
			local player	= Players[iPlayer]
			local units		= player and player:GetUnits()
			if units then
				for i, unit in units:Members() do
					print("	<Replace ".. scenarioString .. mapString .." CivilizationType=\"".. tostring(civilizationType).."\" UnitType=\""..tostring(GameInfo.Units[unit:GetType()].UnitType) .."\"	Name=\"".. tostring(unit:GetName()) .."\"	Damage=\"".. tostring(unit:GetDamage()) .."\"	X=\"".. tostring(unit:GetX()) .."\" Y=\"".. tostring(unit:GetY()) .."\"	/>")
				end
			end
		end
	end	
	print("</ScenarioUnits>")
	
	print("<!--******************************---->")
	print("<!--******* Infrastructure *******---->")
	print("<!--******************************---->")
	print("<ScenarioInfrastructure>")
	local iImprovementType
	local iRouteType
	for iY = 0, g_iH - 1 do
		for iX = g_iW - 1, 0, -1  do
			pPlot 					= Map.GetPlot(iX,iY)
			iImprovementType 		= pPlot:GetImprovementType()
			iRouteType 				= pPlot:GetRouteType()
			local improvementStr 	= ""
			local routeStr 			= ""
			local bRow = false
			if iImprovementType ~= -1 then
				improvementStr = "ImprovementType=\"".. tostring(GameInfo.Improvements[iImprovementType].ImprovementType).."\""
				bRow = true
			end
			if iRouteType ~= -1 then
				routeStr = "RouteType=\"".. tostring(iRouteType).."\""
				bRow = true
			end
			if bRow then
				print("	<Replace ".. scenarioString .. mapString .." "..improvementStr.." ".. routeStr .." X=\"".. tostring(pPlot:GetX()) .."\" Y=\"".. tostring(pPlot:GetY()) .."\"		/>")
			end
		end
	end
	print("</ScenarioInfrastructure>")
	
end
YnAMP.ExportMap = ExportMap

------------------------------------------------------------------------------
-- Helpers for x,y positions when using a reference or offset map
------------------------------------------------------------------------------
function BuildRefXY()
	if bUseRelativeFixedTable then
		for x = 0, g_UncutMapWidth, 1 do
			--MapToConvert[x] = {}
			for y = 0, g_UncutMapHeight, 1 do
				--print (skipX, skipY, x, y, sX, sY, lX, lY)
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
end

-- Convert current map position to the corresponding position on the reference map
function GetRefMapXY(mapX, mapY, bOnlyOffset, customWidthFactor, customHeightFactor)
	local customWidthFactor		= customWidthFactor or 1
	local customHeightFactor	= customHeightFactor or 1
	local refMapX, refMapY = mapX, mapY
	
	-- First apply the offset value on the current map position
	if bUseOffset then
		refMapX = refMapX + g_OffsetX
		refMapY = refMapY + g_OffsetY
		
		-- the code below assume that the reference map is wrapX or wrapY
		-- else we should limit the choice on the setup screen
		if refMapY >= g_UncutMapHeight then
			refMapY = refMapY - g_UncutMapHeight
			-- No idea how to simulate walking through the north pole / south pole
			-- maybe if the map is limited to 1/2 of width and mirror the other half above/below the poles ?
			--refMapY = (2*g_UncutMapHeight) - refMapY - 1
			--refMapX = refMapX + Round(g_UncutMapWidth / 2)
		end
		if refMapX >= g_UncutMapWidth then
			refMapX = refMapX - g_UncutMapWidth -- -1 ?
		end
	end
	
	-- Now that we have the offset position, get the corresponding relative placement in the reference map
	if bUseRelativePlacement and (not bOnlyOffset) then
		if bUseRelativeFixedTable then
			refMapX 	= XFromRefMapX[refMapX] and Round(XFromRefMapX[refMapX]*customWidthFactor) --Round(g_ReferenceWidthFactor * mapX)
			refMapY 	= YFromRefMapY[refMapY] and Round(YFromRefMapY[refMapY]*customHeightFactor) --Round(g_ReferenceHeightFactor * mapY)
			if refMapX == nil or refMapY == nil then
				print("Warning, can't find refMap y,x for ", mapX, mapY," returning (-1, -1) instead of ",  XFromRefMapX[mapX] and Round(XFromRefMapX[mapX]*customWidthFactor), YFromRefMapY[mapY] and Round(YFromRefMapY[mapY]*customHeightFactor))
				return -1, -1
			end
		else
			refMapX 	= Round(g_ReferenceWidthFactor * refMapX)
			refMapY 	= Round(g_ReferenceHeightFactor * refMapY)		
		end
	end
	return refMapX, refMapY
end
YnAMP.GetRefMapXY = GetRefMapXY

-- Convert the reference map position to the current map position
function GetXYFromRefMapXY(x, y, bOnlyOffset, customWidthRatio, customHeightRatio)
	local customWidthRatio	= customWidthRatio or 1
	local customHeightRatio = customHeightRatio or 1
	local mapX, mapY		= x, y
	
	-- First determine where the relative placement position would be on the current map
	if bUseRelativePlacement and (not bOnlyOffset) then
		if bUseRelativeFixedTable then
			x = RefMapXfromX[x] and Round(RefMapXfromX[x]*customWidthRatio)--Round( g_ReferenceWidthRatio * x)
			y = RefMapYfromY[y] and Round(RefMapYfromY[y]*customHeightRatio)--Round( g_ReferenceHeightRatio * y)
			if x == nil or y == nil then
				return -1, -1
			end
		else
			x = Round( g_ReferenceWidthRatio * x)
			y = Round( g_ReferenceHeightRatio * y)		
		end
	end
	
	-- Then apply the offset
	if bUseOffset then
		x = x - g_OffsetX
		y = y - g_OffsetY
		
		-- the code below assume that the reference map is wrapX
		-- else we should limit the choice on the setup screen
		if y < 0 then 
			y = y + g_UncutMapHeight
			-- No idea how to simulate walking through the north pole / south pole
			-- maybe if the map is limited to 1/2 of width and mirror the other half above/below the poles ?
			--y = y + g_iH - 1
			--y = y + g_iH
			--x = x + Round(g_iW / 2)
		end
		if x < 0 then
			x = x + g_UncutMapWidth
		end
	end
	return x, y
end
YnAMP.GetXYFromRefMapXY = GetXYFromRefMapXY

function GetPlotFromRefMap(x, y, bOnlyOffset)
	return Map.GetPlot(GetXYFromRefMapXY(x,y, bOnlyOffset))
end


------------------------------------------------------------------------------
-- Map functions
------------------------------------------------------------------------------
function SetLatitudesGlobals()
	local southPoleLatitude = -90
	local northPoleLatitude	= 90
	local _, southernY = GetRefMapXY(0,0)
	local _, northernY = GetRefMapXY(0, g_iH - 1)
	
	local southernLatitude	= MapConfiguration.GetValue("SouthernLatitude") or southPoleLatitude
	local northernLatitude	= MapConfiguration.GetValue("NorthernLatitude") or northPoleLatitude
	
	local height			= (bUseOffset and g_UncutMapHeight) or g_iH
--print("SetLatitudesGlobals: southernLatitude = ", southernLatitude, "northernLatitude = ", northernLatitude, "bUseOffset = ", bUseOffset, "g_UncutMapHeight = ", g_UncutMapHeight, "g_iH = ", g_iH, "height = ", height, "southernY = ", southernY )
	g_LatitudeDegreesPerY 	= (northernLatitude - southernLatitude) / height  -- but there are 181° of latitudes from -90 to 90, shouldn't we add 1° when crossing the equator ?
	g_OriginLatitude		= (southernY * g_LatitudeDegreesPerY) + southernLatitude
end

function GetLatitude(y)
	return Round((y*g_LatitudeDegreesPerY)+g_OriginLatitude)
end


-----------------------------------------------------------------------------------------
-- Setup Screen Functions
-----------------------------------------------------------------------------------------
function LoadGameplayDatabaseForConfig()

	print("Loading Data For YnAMP Setup Screen...")
	ConfigYnAMP.ModList			= {}
	ConfigYnAMP.CityStatesList	= {}
	ConfigYnAMP.TSL				= {}
	ConfigYnAMP.MapSizes		= {}
	
	local mapName				= MapConfiguration.GetValue("MapName")
	
	-- Load TSL
	for row in GameInfo.StartPosition() do
		table.insert(ConfigYnAMP.TSL, row)
	end
	print("TSL list loaded, rows = ", #ConfigYnAMP.TSL)
	
	-- Load MapSizes
	for row in GameInfo.Maps() do
		ConfigYnAMP.MapSizes[row.MapSizeType] = {Width = row.GridWidth,	Height = row.GridHeight , Size = row.GridWidth * row.GridHeight } 
	end
	print("MapSizes loaded")
	
	-- Load CityStates
	for row in GameInfo.CivilizationLeaders() do
		local civilizationRow 	= GameInfo.Civilizations[row.CivilizationType]
		local leaderRow 		= GameInfo.Leaders[row.LeaderType]
		if civilizationRow and civilizationRow.StartingCivilizationLevelType =="CIVILIZATION_LEVEL_CITY_STATE" then
			table.insert(ConfigYnAMP.CityStatesList, {LeaderType = row.LeaderType, CivilizationType = civilizationRow.CivilizationType, LeaderName = leaderRow.Name, CivilizationName = civilizationRow.Name, LocalizedLeaderName = Locale.Lookup(leaderRow.Name), LocalizedCivilizationName = Locale.Lookup(civilizationRow.Name) })
		end
	end
	print("CityState list loaded, rows = ", #ConfigYnAMP.CityStatesList)
	
	-- Load mod list
	--print("Loading mod list...")
	local listMods		= {}
	local installedMods = Modding.GetInstalledMods()

	if installedMods ~= nil then
		for i, modData in ipairs(installedMods) do
			if modData.Enabled then
				table.insert(listMods, modData)
			end
		end
	end
	
	for i, v in ipairs(listMods) do
		--print("Set mod activated :" .. Locale.Lookup(v.Name))
		ConfigYnAMP.ModList[v.Id] = v
	end
	print("Mod list loaded, rows = ", #listMods)
	
	local ruleset = GameConfiguration.GetValue("RULESET")
	print("Current Ruleset = ", ruleset)
		
	ConfigYnAMP.IsDatabaseLoaded 	= true
	ConfigYnAMP.IsDatabaseChanged	= false
	ConfigYnAMP.LoadedRuleset 		= ruleset
	
	if ConfigYnAMP.LoadingDatabase then
		ConfigYnAMP.LoadingDatabase = false
		UIManager:SetUICursor( 1 )
		UITutorialManager:EnableOverlay( false )	
		UITutorialManager:HideAll()
		Events.ExitToMainMenu()
	end
end


-----------------------------------------------------------------------------------------
-- City Names for debug
-----------------------------------------------------------------------------------------
function GetCityNamesAt(x, y, bShowCivSpecificNames)

	local nameList			= {}
	local mapName			= MapConfiguration.GetValue("MapName")
	local refMapX, refMapY 	= GetRefMapXY(x, y)
	local out 		= 0
	local added		= 0
	local far 		= 0
	local reserved	= 0
	
	for row in GameInfo.CityMap() do
		if row.MapName == mapName  then
			if (row.Civilization and bShowCivSpecificNames) or (row.Civilization == nil) then
				local name				= row.CityLocaleName
				local nameX 			= row.X
				local nameY 			= row.Y
				local nameMaxDistance 	= row.Area + g_ExtraRange
				local distance 			= Map.GetPlotDistance(refMapX, refMapY ,nameX, nameY)
				if distance <= nameMaxDistance then
					table.insert(nameList, {Name = name, Distance = distance})
					added = added + 1
				else
					far = far + 1
				end	
			else
				reserved = reserved + 1
			end
		else
			out = out + 1
		end
	end
	--print(string.format("Added: %i, Not on Map = %i, Reserved = %i, Too far = %i", added, out, reserved, far))
	return #nameList > 0 and nameList
end

-----------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------
function UpdateLoadingText(sText)
print("YnAMP_Loading.FallbackMessage",YnAMP_Loading.FallbackMessage)
print("YnAMP_Loading.LoadGameMenu",YnAMP_Loading.LoadGameMenu)
print(sText)
	if YnAMP_Loading.LoadGameMenu then
	
	else
	
	end
end
