------------------------------------------------------------------------------
--	FILE:	 YnAMP_Common.lua
--  Gedemon (2020)
------------------------------------------------------------------------------
print ("loading YnAMP_Common.lua")

------------------------------------------------------------------------------
-- Sharing UI/Gameplay context
------------------------------------------------------------------------------

ExposedMembers.YnAMP = ExposedMembers.YnAMP or {}
YnAMP = ExposedMembers.YnAMP


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

-- The base map is the Largest Earth Map
g_LargestMapWidth 		= 230
g_LargestMapHeight 		= 116
g_LargestMapOldWorldX	= 155

g_SizeDual      			=  44*26
g_SizeTiny      			=  60*36
g_SizeSmall     			=  74*46
g_SizeStandard  			=  84*54
g_SizeLarge     			=  96*60
g_SizeHuge      			= 106*66
g_SizeEnormous  			= 128*80
g_SizeGiant     			= 180*94
g_SizeLudicrous 			= 230*115
g_LargestEarthOceanWidth 	= 24

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


------------------------------------------------------------------------------
-- Set globals
------------------------------------------------------------------------------

function SetGlobals()

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

	g_ReferenceSizeRatio = math.sqrt(g_iW * g_iH) / math.sqrt(g_ReferenceMapWidth * g_ReferenceMapHeight)

	g_StartingPlotRange 		= 16 * g_ReferenceSizeRatio -- todo: what's that magic number here ?
	
	local replacementRangeForTSL	= MapConfiguration.GetValue("ReplacementRangeForTSL") or 10
	g_ReplacementRangeForTSL 		= replacementRangeForTSL * g_ReferenceSizeRatio

	g_NewWorldX = g_LargestMapOldWorldX * g_WidthRatio
	
	g_MaxStartDistanceMajor = math.sqrt(g_iW * g_iH / PlayerManager.GetWasEverAliveMajorsCount())
	g_MinStartDistanceMajor = g_MaxStartDistanceMajor / 3
	
	print("g_iW 	= ", g_iW)
	print("g_iH 	= ", g_iH)
	print("g_LargestMapWidth 	= ", g_LargestMapWidth)
	print("g_LargestMapHeight 	= ", g_LargestMapHeight)
	print("g_WidthFactor 	= ", g_WidthFactor)
	print("g_HeightFactor 	= ", g_HeightFactor)
	print("g_WidthRatio 	= ", g_WidthRatio)
	print("g_HeightRatio 	= ", g_HeightRatio)
	print("g_ReferenceMapWidth 		= ", g_ReferenceMapWidth)
	print("g_ReferenceMapHeight 	= ", g_ReferenceMapHeight)
	print("g_ReferenceWidthFactor 	= ", g_ReferenceWidthFactor)
	print("g_ReferenceHeightFactor 	= ", g_ReferenceHeightFactor)
	print("g_ReferenceWidthRatio 	= ", g_ReferenceWidthRatio)
	print("g_ReferenceHeightRatio 	= ", g_ReferenceHeightRatio)
	print("StartX", MapConfiguration.GetValue("StartX"))
	print("EndX", MapConfiguration.GetValue("EndX"))
	print("StartY", MapConfiguration.GetValue("StartY"))
	print("EndY", MapConfiguration.GetValue("EndY"))
	print("g_UncutMapWidth", g_UncutMapWidth)
	print("g_UncutMapHeight", g_UncutMapHeight)
	print("bUseOffset", bUseOffset)	
	print("g_ReferenceSizeRatio	= ", g_ReferenceSizeRatio)
	print("g_StartingPlotRange =", g_StartingPlotRange)
	print("replacementRangeForTSL =", replacementRangeForTSL)
	print("g_ReplacementRangeForTSL =", g_ReplacementRangeForTSL)
	print("g_MaxStartDistanceMajor = ", g_MaxStartDistanceMajor)
	print("g_MinStartDistanceMajor = ", g_MinStartDistanceMajor)
	print("Map.GetGridSize()", Map.GetGridSize())
	print("bUseRelativePlacement",bUseRelativePlacement)
	print("bUseRelativeFixedTable",bUseRelativeFixedTable)
	print("skipX",skipX)
	print("skipY",skipY)

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
	local iImprovmentType
	local iRouteType
	for iY = 0, g_iH - 1 do
		for iX = g_iW - 1, 0, -1  do
			pPlot 					= Map.GetPlot(iX,iY)
			iImprovmentType 		= pPlot:GetImprovementType()
			iRouteType 				= pPlot:GetRouteType()
			local improvementStr 	= ""
			local routeStr 			= ""
			local bRow = false
			if iImprovmentType ~= -1 then
				improvementStr = "ImprovementType=\"".. tostring(GameInfo.Improvements[iImprovmentType].ImprovementType).."\""
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
	if bUseRelativePlacement and (not bOnlyOffset) then
		if bUseRelativeFixedTable then
			refMapX 	= XFromRefMapX[mapX] and Round(XFromRefMapX[mapX]*customWidthFactor) --Round(g_ReferenceWidthFactor * mapX)
			refMapY 	= YFromRefMapY[mapY] and Round(YFromRefMapY[mapY]*customHeightFactor) --Round(g_ReferenceHeightFactor * mapY)
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
--print(bUseRelativePlacement, bOnlyOffset, bUseOffset, refMapX, refMapY, mapX, mapY, XFromRefMapX[mapX], YFromRefMapY[mapY])
	return refMapX, refMapY
end

-- Convert the reference map position to the current map position
function GetXYFromRefMapXY(x, y, bOnlyOffset, customWidthRatio, customHeightRatio)
	local customWidthRatio	= customWidthRatio or 1
	local customHeightRatio = customHeightRatio or 1
	local mapX, mapY		= x, y
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
--print(bUseRelativePlacement, bOnlyOffset, bUseOffset, x, y, mapX, mapY, RefMapXfromX[mapX], RefMapYfromY[mapY])
	return x, y
end

function GetPlotFromRefMap(x, y, bOnlyOffset)
	return Map.GetPlot(GetXYFromRefMapXY(x,y, bOnlyOffset))
end

