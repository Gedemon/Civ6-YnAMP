-- ===========================================================================
--	World Builder Plot Editor
-- ===========================================================================

-- YnAMP <<<<<
local DirectionString = {
	[DirectionTypes.DIRECTION_NORTHEAST] 	= "NORTHEAST",
	[DirectionTypes.DIRECTION_EAST] 		= "EAST",
	[DirectionTypes.DIRECTION_SOUTHEAST] 	= "SOUTHEAST",
    [DirectionTypes.DIRECTION_SOUTHWEST] 	= "SOUTHWEST",
	[DirectionTypes.DIRECTION_WEST] 		= "WEST",
	[DirectionTypes.DIRECTION_NORTHWEST] 	= "NORTHWEST"
	}
	
local FlowDirectionString = {
	[FlowDirectionTypes.FLOWDIRECTION_NORTHEAST] 	= "NORTHEAST",
	[FlowDirectionTypes.FLOWDIRECTION_NORTH] 		= "NORTH",
	[FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST] 	= "SOUTHEAST",
    [FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST] 	= "SOUTHWEST",
	[FlowDirectionTypes.FLOWDIRECTION_SOUTH] 		= "SOUTH",
	[FlowDirectionTypes.FLOWDIRECTION_NORTHWEST] 	= "NORTHWEST"
	}
	
local RiverMap = ExposedMembers.RiverMap

function plotToNode(plot, edge)
	return tostring(plot:GetIndex()) .."," .. tostring(edge)
end

function GetRiverIdForNode(plot, edge)
	local node = plotToNode(plot, edge)
	return RiverMap[node]
end
-- YnAMP >>>>>
		
-- ===========================================================================
--	DATA MEMBERS
-- ===========================================================================
local m_SelectedPlot = nil;
local m_TerrainTypeEntries     : table = {};
local m_FeatureTypeEntries     : table = {};
local m_ResourceTypeEntries    : table = {};
local m_ImprovementTypeEntries : table = {};
local m_RouteTypeEntries       : table = {};
local m_LeaderEntries          : table = {};
local m_CivEntries             : table = {};
local m_PlayerEntries          : table = {};
local m_PlayerIndexToEntry     : table = {};
local m_CityEntries            : table = {};
local m_IDsToCityEntry         : table = {};
local m_CoastalLowlandEntries  : table = {};

local m_StartPosTypeEntries : table =
{
	{ Type = "None",         Text = "LOC_WORLDBUILDER_NONE",              Control = nil },
	{ Type = "Player",       Text = "LOC_WORLDBUILDER_PLAYER",            Control = Controls.StartPosPlayerPulldown },
	{ Type = "Leader",       Text = "LOC_WORLDBUILDER_LEADER",            Control = Controls.StartPosLeaderPulldown },
	{ Type = "Civilization", Text = "LOC_WORLDBUILDER_CIVILIZATION",      Control = Controls.StartPosCivPulldown },
	{ Type = "RandomMajor",  Text = "LOC_WORLDBUILDER_RANDOM_PLAYER",     Control = nil },
	{ Type = "RandomMinor",  Text = "LOC_WORLDBUILDER_RANDOM_CITY_STATE", Control = nil }
};

local m_DirectionTypeEntries : table = 
{
	{ Text="LOC_WORLDBUILDER_NO_DIRECTION", Type=DirectionTypes.NO_DIRECTION },
	{ Text="LOC_WORLDBUILDER_DIRECTION_NORTHEAST", Type=DirectionTypes.DIRECTION_NORTHEAST },
	{ Text="LOC_WORLDBUILDER_DIRECTION_EAST", Type=DirectionTypes.DIRECTION_EAST },
	{ Text="LOC_WORLDBUILDER_DIRECTION_SOUTHEAST", Type=DirectionTypes.DIRECTION_SOUTHEAST },
	{ Text="LOC_WORLDBUILDER_DIRECTION_SOUTHWEST", Type=DirectionTypes.DIRECTION_SOUTHWEST },
	{ Text="LOC_WORLDBUILDER_DIRECTION_WEST", Type=DirectionTypes.DIRECTION_WEST },
	{ Text="LOC_WORLDBUILDER_DIRECTION_NORTHWEST", Type=DirectionTypes.DIRECTION_NORTHWEST }
};

-- Also allow the entries to be looked up by type
for i, entry in ipairs(m_StartPosTypeEntries) do
	entry.EntryIndex = i;
	m_StartPosTypeEntries[entry.Type] = entry;
end

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================
function IsExpansion2()
	return Modding.IsModActive("4873eb62-8ccc-4574-b784-dda455e74e68");
end

function UpdateActiveStartPosControl(startPostType)
	if startPostType.Control ~= nil then
		Controls.StartPosTabControl:SelectTab( startPostType.Control );
		Controls.StartPosTabControl:SetHide( false );
	else
		Controls.StartPosTabControl:SetHide( true );
	end
end

function UpdatePlotInfo()

	if m_SelectedPlot ~= nil then

		local plot = Map.GetPlotByIndex( m_SelectedPlot );
		local isWater = plot:IsWater();
		local hasOwner = plot:IsOwned();
		local terrainType = plot:GetTerrainType();
        local owner = hasOwner and WorldBuilder.CityManager():GetPlotOwner( m_SelectedPlot ) or nil;
                		
		local plotFeature = plot:GetFeature();
		Controls.TerrainPullDown:SetSelectedIndex(     terrainType+1,               false );
		Controls.FeaturePullDown:SetSelectedIndex(     plotFeature:GetType()+2,     false );
		Controls.FeatureDirectionPulldown:SetSelectedIndex( plotFeature:GetDirection()+2,     false );
		Controls.ResourcePullDown:SetSelectedIndex(    plot:GetResourceType()+2,    false );
		Controls.ImprovementPullDown:SetSelectedIndex( plot:GetImprovementType()+2, false );
		Controls.RoutePullDown:SetSelectedIndex(       plot:GetRouteType()+2,       false );

        if IsExpansion2() then
            local eCoastalLowlandType:number = TerrainManager.GetCoastalLowlandType( m_SelectedPlot );
            Controls.LowlandTypePulldown:SetSelectedIndex( eCoastalLowlandType + 2, false );
        end

		Controls.ImprovementPillagedButton:SetSelected( plot:IsImprovementPillaged() );
		Controls.RoutePillagedButton:SetSelected( plot:IsRoutePillaged() );

		Controls.RoutePullDown:SetDisabled(isWater);
		Controls.RoutePillagedButton:SetDisabled(isWater);

		if plot:GetResourceType() ~= -1 then
			Controls.ResourceAmount:SetText( tostring(plot:GetResourceCount()) );
			Controls.ResourceAmount:SetDisabled( false );
		else
			Controls.ResourceAmount:SetText( "" );
			Controls.ResourceAmount:SetDisabled( true );
		end

		local plotDir = plotFeature:GetDirection();
		for i, entry in ipairs(m_FeatureTypeEntries) do
			if entry.Type ~= nil then
				if plotDir == -1 then
					entry.Button:SetDisabled(not WorldBuilder.MapManager():CanPlaceFeature(m_SelectedPlot, entry.Type.Index));
				else
					entry.Button:SetDisabled(false);
				end
			end
		end

		for i, entry in ipairs(m_ResourceTypeEntries) do
			if entry.Type ~= nil then
				entry.Button:SetDisabled(not WorldBuilder.MapManager():CanPlaceResource(m_SelectedPlot, entry.Type.Index));
			end
		end

		for i, entry in ipairs(m_ImprovementTypeEntries) do
			if entry.Type ~= nil then
				entry.Button:SetDisabled(not (hasOwner or entry.Type.Goody or entry.Type.BarbarianCamp));
			end
		end

		Controls.OwnerPulldown:SetSelectedIndex( hasOwner and m_IDsToCityEntry[ owner.PlayerID ][ owner.CityID ].EntryIndex or 1, false );

		local startPosInfo = WorldBuilder.PlayerManager():GetStartPositionInfo(m_SelectedPlot);
		if startPosInfo == nil then
			Controls.StartPosPulldown:SetSelectedIndex( m_StartPosTypeEntries["None"].EntryIndex, false );
			Controls.StartPosTabControl:SetHide( true );
		else
			local startPosTypeEntry = m_StartPosTypeEntries[startPosInfo.Type];
			Controls.StartPosPulldown:SetSelectedIndex( startPosTypeEntry.EntryIndex, false );
			UpdateActiveStartPosControl( startPosTypeEntry );

			if startPosInfo.Type == "Player" then
				local playerEntry = m_PlayerIndexToEntry[ startPosInfo.Player ];
				if playerEntry ~= nil then
					Controls.StartPosPlayerPulldown:SetSelectedIndex( playerEntry.EntryIndex, false );
				end
			elseif startPosInfo.Type == "Leader" then
				Controls.StartPosLeaderPulldown:SetSelectedIndex( startPosInfo.Leader + 1, false );
			elseif startPosInfo.Type == "Civilization" then
				Controls.StartPosCivPulldown:SetSelectedIndex( startPosInfo.Civilization + 1, false );
			end
		end
	end
end

-- ===========================================================================
function UpdateSelectedPlot(plotID)

	if m_SelectedPlot ~= nil then
		UI.HighlightPlots(PlotHighlightTypes.MOVEMENT, false, { m_SelectedPlot } );
	end

	m_SelectedPlot = plotID;

	local plotSelected = m_SelectedPlot ~= nil;
	
	Controls.TerrainPullDown:SetDisabled(not plotSelected);
	Controls.FeaturePullDown:SetDisabled(not plotSelected);
	Controls.FeatureDirectionPulldown:SetDisabled(not plotSelected);
	Controls.ResourcePullDown:SetDisabled(not plotSelected);
	Controls.ResourceAmount:SetDisabled(not plotSelected);
	Controls.ImprovementPullDown:SetDisabled(not plotSelected);
	Controls.ImprovementPillagedButton:SetDisabled(not plotSelected);
	Controls.RoutePullDown:SetDisabled(not plotSelected);
	Controls.RoutePillagedButton:SetDisabled(not plotSelected);
	Controls.StartPosPulldown:SetDisabled(not plotSelected);
	Controls.StartPosTabControl:SetDisabled(not plotSelected);
	Controls.OwnerPulldown:SetDisabled(not plotSelected);
	Controls.FeatureDirectionPulldown:SetDisabled(not plotSelected);
	Controls.LowlandTypePulldown:SetDisabled(not plotSelected);
	
	if plotSelected then
		local plot = Map.GetPlotByIndex( m_SelectedPlot );
		Controls.SelectedPlotLabel:SetText(string.format("(%i, %i)", plot:GetX(), plot:GetY()));
		UpdatePlotInfo();
		UI.HighlightPlots(PlotHighlightTypes.MOVEMENT, true, { plotID } );
		-- YnAMP <<<<<
		if plot:IsWOfRiver() then
			Controls.IsWOfRiver:SetHide(false);
			local riverID 	= GetRiverIdForNode(plot, DirectionTypes.DIRECTION_EAST)
			local dirString	= FlowDirectionString[plot:GetRiverEFlowDirection()] or plot:GetRiverEFlowDirection()
			Controls.IsWOfRiver:SetText("River# "..tostring(riverID)..", "..tostring(dirString));
		else
			Controls.IsWOfRiver:SetText("false");
		end
		if plot:IsNWOfRiver() then
			Controls.IsNWOfRiver:SetHide(false);
			local riverID 	= GetRiverIdForNode(plot, DirectionTypes.DIRECTION_SOUTHEAST)
			local dirString	= FlowDirectionString[plot:GetRiverSEFlowDirection()] or plot:GetRiverSEFlowDirection()
			Controls.IsNWOfRiver:SetText("River# "..tostring(riverID)..", "..tostring(dirString));
		else
			Controls.IsNWOfRiver:SetText("false");
		end
		if plot:IsNEOfRiver() then
			Controls.IsNEOfRiver:SetHide(false);
			local riverID 	= GetRiverIdForNode(plot, DirectionTypes.DIRECTION_SOUTHWEST)
			local dirString	= FlowDirectionString[plot:GetRiverSWFlowDirection()] or plot:GetRiverSWFlowDirection()
			Controls.IsNEOfRiver:SetText("River# "..tostring(riverID)..", "..tostring(dirString));
		else
			Controls.IsNEOfRiver:SetText("false");
		end
		-- YnAMP >>>>>
	else
		Controls.SelectedPlotLabel:SetText(Locale.Lookup("LOC_WORLD_BUILDER_NO_PLOT_SELECTED_HELP"));
		-- YnAMP <<<<<
			Controls.IsWOfRiver:SetText("false");
			Controls.IsNWOfRiver:SetText("false");
			Controls.IsNEOfRiver:SetText("false");
		-- YnAMP >>>>>
	end

	Controls.PlotEditorScrollPanel:CalculateSize();
end

-- ===========================================================================
function OnPlotSelected(plotID, edge, lbutton)
	
	if not ContextPtr:IsHidden() and lbutton then
		UpdateSelectedPlot( plotID );
	end
end

-- ===========================================================================
function OnShow()

	UpdateSelectedPlot(nil);

	if UI.GetInterfaceMode() ~= InterfaceModeTypes.WB_SELECT_PLOT then
		UI.SetInterfaceMode( InterfaceModeTypes.WB_SELECT_PLOT );
	end

	LuaEvents.WorldBuilderMapTools_SetTabHeader(Locale.Lookup("LOC_WORLDBUILDER_SELECT_TOOL"));
end

-- ===========================================================================
function OnHide()
	UpdateSelectedPlot(nil);
end

-- ===========================================================================
function OnLoadGameViewStateDone()

	UpdatePlayerEntries();
	UpdateCityEntries();

	if not ContextPtr:IsHidden() then
		OnShow();
	end 
end

-- ===========================================================================
function UpdatePlayerEntries()

	m_PlayerEntries = {};
	m_PlayerIndexToEntry = {};

	m_PlayerIndexToEntry[-1] = { PlayerIndex=-1, EntryIndex=0 };
	
	local playerCount = 0;
	for i = 0, GameDefines.MAX_PLAYERS-1 do

		local eStatus = WorldBuilder.PlayerManager():GetSlotStatus(i); 
		if eStatus ~= SlotStatus.SS_CLOSED then
			local playerConfig = WorldBuilder.PlayerManager():GetPlayerConfig(i);
			if playerConfig.IsBarbarian == false then		-- Skipping the Barbarian player
				local playerEntry = { Text=playerConfig.Name, PlayerIndex=i, EntryIndex=playerCount+1 };
				table.insert(m_PlayerEntries, playerEntry);
				m_PlayerIndexToEntry[i] = playerEntry;
				playerCount = playerCount + 1;
			end
		end
	end
	
	Controls.StartPosPlayerPulldown:SetEntries( m_PlayerEntries, m_PlayerIndexToEntry[ WorldBuilder.PlayerManager():GetStartPositionPlayer(m_SelectedPlot) ].EntryIndex );
end

-- ===========================================================================
function UpdateCityEntries()

	m_CityEntries = {};
	m_IDsToCityEntry = {};

	table.insert(m_CityEntries, { Text="No City", Player=-1, ID=-1, EntryIndex=1 });

	local cityCount = 0;
	for iPlayer = 0, GameDefines.MAX_PLAYERS-1 do
		local player = Players[iPlayer];
		local cities = player:GetCities();
		if cities ~= nil then
			local idToCity = {};
			m_IDsToCityEntry[iPlayer] = idToCity;
			for iCity, city in cities:Members() do
				local cityID = city:GetID();
				local cityEntry = { Text=city:GetName(), Player=iPlayer, ID=cityID, EntryIndex=cityCount+2 };
				table.insert(m_CityEntries, cityEntry);
				idToCity[cityID] = cityEntry;
				cityCount = cityCount + 1;
			end
		end
	end

	local owner = WorldBuilder.CityManager():GetPlotOwner( m_SelectedPlot );
	Controls.OwnerPulldown:SetEntries( m_CityEntries, owner ~= nil and m_IDsToCityEntry[ owner.PlayerID ][ owner.CityID ].EntryIndex or 1 );
end

-- ===========================================================================
function OnTerrainTypeSelected(entry)
	if entry ~= nil then
		if m_SelectedPlot ~= nil then
			WorldBuilder.MapManager():SetTerrainType( m_SelectedPlot, entry.Type.Index );
		end
	end
end

-- ===========================================================================
function OnFeatureTypeSelected(entry)

	if m_SelectedPlot ~= nil then
		if entry.Type~= nil then
			WorldBuilder.MapManager():SetFeatureType( m_SelectedPlot, entry.Type.Index );
		else
			WorldBuilder.MapManager():SetFeatureType( m_SelectedPlot, -1 );
		end

		local plot = Map.GetPlotByIndex( m_SelectedPlot );
		local terrainType = plot:GetTerrainType();
        OnTerrainTypeSelected(m_TerrainTypeEntries[terrainType]);
	end
end

-- ===========================================================================
function OnFeatureDirectionSelected(entry)

	if m_SelectedPlot ~= nil then
		if entry.Type~= nil then
			WorldBuilder.MapManager():SetPlotValue( m_SelectedPlot, "Feature", "Direction", entry.Type );
			for i, entry in ipairs(m_FeatureTypeEntries) do
				entry.Button:SetDisabled(false);
			end
		else
			WorldBuilder.MapManager():SetPlotValue( m_SelectedPlot, "Feature", "Direction", DirectionTypes.NO_DIRECTION );
			for i, entry in ipairs(m_FeatureTypeEntries) do
				if entry.Type ~= nil then
					entry.Button:SetDisabled(not WorldBuilder.MapManager():CanPlaceFeature(m_SelectedPlot, entry.Type.Index));
				end
			end
		end
	end
end

-- ===========================================================================
function GetSelectedResourceAmount()

	local resAmountText = Controls.ResourceAmount:GetText();
	if resAmountText ~= nil then
		local resAmount = tonumber(resAmountText);
		if resAmount ~= nil and resAmount > 0 then
			return resAmount;
		end
	end

	return 1; -- 1 by default
end

-- ===========================================================================
function OnResourceTypeSelected(entry)

	if m_SelectedPlot ~= nil then
		if entry.Type~= nil then
			WorldBuilder.MapManager():SetResourceType( m_SelectedPlot, entry.Type.Index, GetSelectedResourceAmount());
		else
			WorldBuilder.MapManager():SetResourceType( m_SelectedPlot, -1 );
		end
	end
end

-- ===========================================================================
function OnResourceAmountChanged()

	local resAmountText = Controls.ResourceAmount:GetText();
	if resAmountText ~= nil and resAmountText ~= "" and m_SelectedPlot ~= nil then
		local plot = Map.GetPlotByIndex( m_SelectedPlot );
		local resType = plot:GetResourceType();
		local newResAmount = GetSelectedResourceAmount();
		if resType ~= -1 and newResAmount ~= plot:GetResourceCount() then
			WorldBuilder.MapManager():SetResourceType( m_SelectedPlot, resType, newResAmount);
		end
	end
end

-- ===========================================================================
function OnImprovementTypeSelected(entry)

	if m_SelectedPlot ~= nil then
		if entry.Type~= nil then
			WorldBuilder.MapManager():SetImprovementType( m_SelectedPlot, entry.Type.Index, Map.GetPlotByIndex( m_SelectedPlot ):GetOwner() );
			if Controls.ImprovementPillagedButton:IsSelected() then
				--WorldBuilder.MapManager():SetImprovementPillaged( plot, true );
			end
		else
			WorldBuilder.MapManager():SetImprovementType( m_SelectedPlot, -1 );
		end
	end
end

-- ===========================================================================
function OnImprovementPillagedButton()
	Controls.ImprovementPillagedButton:SetSelected(not Controls.ImprovementPillagedButton:IsSelected());

	if m_SelectedPlot ~= nil then
		local plot = Map.GetPlotByIndex( m_SelectedPlot );
		if plot:GetImprovementType() ~= -1 then
			--WorldBuilder.MapManager():SetImprovementPillaged(plot, Controls.ImprovementPillagedButton:IsSelected());
		end
	end
end

-- ===========================================================================
function OnRouteTypeSelected(entry)

	if m_SelectedPlot ~= nil then
		if entry.Type~= nil then
			WorldBuilder.MapManager():SetRouteType( m_SelectedPlot, entry.Type.Index, Controls.RoutePillagedButton:IsSelected() );
		else
			WorldBuilder.MapManager():SetRouteType( m_SelectedPlot, RouteTypes.NONE );
		end
	end
end

-- ===========================================================================
function OnRoutePillagedButton()
	Controls.RoutePillagedButton:SetSelected(not Controls.RoutePillagedButton:IsSelected());

	if m_SelectedPlot ~= nil then
		local plot = Map.GetPlotByIndex( m_SelectedPlot );
		if plot:GetRouteType() ~= RouteTypes.NONE then
			WorldBuilder.MapManager():SetRouteType( m_SelectedPlot, plot:GetRouteType(), Controls.RoutePillagedButton:IsSelected() );
		end
	end
end

-- ===========================================================================
function OnOwnerSelected(entry)

	if m_SelectedPlot ~= nil then
		local plot = Map.GetPlotByIndex( m_SelectedPlot );
		if entry.ID ~= -1 then
			WorldBuilder.CityManager():SetPlotOwner( plot:GetX(), plot:GetY(), entry.Player, entry.ID );
		else
			WorldBuilder.CityManager():SetPlotOwner( plot:GetX(), plot:GetY(), false );
		end
	end
end

-- ===========================================================================
function OnLowlandSelected(entry)
	if m_SelectedPlot ~= nil then
		local plot = Map.GetPlotByIndex( m_SelectedPlot );
		if entry.Type ~= nil then
			WorldBuilder.MapManager():SetCoastalLowland( m_SelectedPlot, entry.Type.RowId-1 );
		else
			WorldBuilder.MapManager():SetCoastalLowland( m_SelectedPlot, -1 );
		end
	end
end

-- ===========================================================================
function OnStartPosTypeSelected(entry)
	
	UpdateActiveStartPosControl( entry );

	if m_SelectedPlot ~= nil then

		if entry.Type == "None" then
			WorldBuilder.PlayerManager():ClearStartingPosition( m_SelectedPlot );
		elseif entry.Type == "RandomMajor" then
			WorldBuilder.PlayerManager():SetRandomMajorStartingPosition( m_SelectedPlot );
		elseif entry.Type == "RandomMinor" then
			WorldBuilder.PlayerManager():SetRandomMinorStartingPosition( m_SelectedPlot );
		else
			-- If player, leader, or civ was selected then start without a selection and let the user pick.
			-- If we were to pick a default selection we might inadvertantly remove another starting location.
			-- For example, if the default player selection is player 1 then making that selection here
			-- would clear out player 1's previous starting position!
			entry.Control:SetSelectedIndex( 0, false );
		end
	end
end

-- ===========================================================================
function OnStartPosPlayerSelected(entry)

	if m_SelectedPlot ~= nil then
		WorldBuilder.PlayerManager():SetPlayerStartingPosition( entry.PlayerIndex, m_SelectedPlot );
	end
end

-- ===========================================================================
function OnStartPosLeaderSelected(entry)

	if m_SelectedPlot ~= nil then
		WorldBuilder.PlayerManager():SetLeaderStartingPosition( entry.Type.Index, m_SelectedPlot );
	end
end

-- ===========================================================================
function OnStartPosCivSelected(entry)

	if m_SelectedPlot ~= nil then
		WorldBuilder.PlayerManager():SetCivilizationStartingPosition( entry.Type.Index, m_SelectedPlot );
	end
end

-- ===========================================================================
function OnStartPositionChanged(plot)

	if m_SelectedPlot == plot then
		UpdatePlotInfo();
	end
end

-- ===========================================================================
--	Init
-- ===========================================================================
function OnInit()

	-- TerrainPullDown
	for type in GameInfo.Terrains() do
		table.insert(m_TerrainTypeEntries, { Text=type.Name, Type=type });
	end
	Controls.TerrainPullDown:SetEntries( m_TerrainTypeEntries, 1 );
	Controls.TerrainPullDown:SetEntrySelectedCallback( OnTerrainTypeSelected );

	-- FeaturePullDown
	table.insert(m_FeatureTypeEntries, { Text="LOC_WORLDBUILDER_NO_FEATURE" });
	for type in GameInfo.Features() do
		table.insert(m_FeatureTypeEntries, { Text=type.Name, Type=type });
	end
	Controls.FeaturePullDown:SetEntries( m_FeatureTypeEntries, 1 );
	Controls.FeaturePullDown:SetEntrySelectedCallback( OnFeatureTypeSelected );

	-- FeatureDirectionPulldown
	Controls.FeatureDirectionPulldown:SetEntries( m_DirectionTypeEntries, 1 );
	Controls.FeatureDirectionPulldown:SetEntrySelectedCallback( OnFeatureDirectionSelected );

	-- ResourcePullDown
	table.insert(m_ResourceTypeEntries, { Text="LOC_WORLDBUILDER_NO_RESOURCE" });
	for type in GameInfo.Resources() do
		table.insert(m_ResourceTypeEntries, { Text=type.Name, Type=type });
	end
	Controls.ResourcePullDown:SetEntries( m_ResourceTypeEntries, 1 );
	Controls.ResourcePullDown:SetEntrySelectedCallback( OnResourceTypeSelected );
	Controls.ResourceAmount:RegisterStringChangedCallback( OnResourceAmountChanged );

	-- ImprovementPullDown
	table.insert(m_ImprovementTypeEntries, { Text="LOC_WORLDBUILDER_NO_IMPROVEMENT" });
	for type in GameInfo.Improvements() do
		table.insert(m_ImprovementTypeEntries, { Text=type.Name, Type=type });
	end
	Controls.ImprovementPullDown:SetEntries( m_ImprovementTypeEntries, 1 );
	Controls.ImprovementPullDown:SetEntrySelectedCallback( OnImprovementTypeSelected );

	-- RoutePullDown
	table.insert(m_RouteTypeEntries, { Text="LOC_WORLDBUILDER_NO_ROUTE" });
	for type in GameInfo.Routes() do
		table.insert(m_RouteTypeEntries, { Text=type.Name, Type=type });
	end
	Controls.RoutePullDown:SetEntries( m_RouteTypeEntries, 1 );
	Controls.RoutePullDown:SetEntrySelectedCallback( OnRouteTypeSelected );

	-- RoutePillagedButton
	Controls.RoutePillagedButton:RegisterCallback( Mouse.eLClick, OnRoutePillagedButton );

	-- OwnerPulldown
	Controls.OwnerPulldown:SetEntrySelectedCallback( OnOwnerSelected );

	-- StartPosPulldown
	Controls.StartPosPulldown:SetEntries( m_StartPosTypeEntries, 1 );
	Controls.StartPosPulldown:SetEntrySelectedCallback( OnStartPosTypeSelected );

	-- StartPosPlayerPulldown
	Controls.StartPosPlayerPulldown:SetEntrySelectedCallback( OnStartPosPlayerSelected );

	-- StartPosLeaderPulldown
	for type in GameInfo.Leaders() do
		table.insert(m_LeaderEntries, { Text=type.Name, Type=type });
	end
	Controls.StartPosLeaderPulldown:SetEntries( m_LeaderEntries, 1 );
	Controls.StartPosLeaderPulldown:SetEntrySelectedCallback( OnStartPosLeaderSelected );

	-- StartPosCivPulldown
	for type in GameInfo.Civilizations() do
		table.insert(m_CivEntries, { Text=type.Name, Type=type });
	end
	Controls.StartPosCivPulldown:SetEntries( m_CivEntries, 1 );
	Controls.StartPosCivPulldown:SetEntrySelectedCallback( OnStartPosCivSelected );

    if IsExpansion2() then
        -- LowlandTypePulldown
    	table.insert(m_CoastalLowlandEntries, { Text="LOC_WORLDBUILDER_NO_LOWLAND" });
    	for type in GameInfo.CoastalLowlands() do
    		table.insert(m_CoastalLowlandEntries, { Text=type.Name, Type=type });
    	end
    	Controls.LowlandTypePulldown:SetEntries( m_CoastalLowlandEntries, 1 );
    	Controls.LowlandTypePulldown:SetEntrySelectedCallback( OnLowlandSelected );
        Controls.LowlandTypePulldown:SetHide(false);
        Controls.LowlandLabel:SetHide(false);
    else
        Controls.LowlandTypePulldown:SetHide(true);
        Controls.LowlandLabel:SetHide(true);
    end

	-- Register for events
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetHideHandler( OnHide );
	Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone );
	LuaEvents.WorldInput_WBSelectPlot.Add( OnPlotSelected );

	Events.TerrainTypeChanged.Add( UpdatePlotInfo );

	Events.FeatureAddedToMap.Add( UpdatePlotInfo );
	Events.FeatureChanged.Add( UpdatePlotInfo );
	Events.FeatureRemovedFromMap.Add( UpdatePlotInfo );

	Events.ResourceAddedToMap.Add( UpdatePlotInfo );
	Events.ResourceChanged.Add( UpdatePlotInfo );
	Events.ResourceRemovedFromMap.Add( UpdatePlotInfo );

	Events.CityAddedToMap.Add( UpdateCityEntries );
	Events.CityRemovedFromMap.Add( UpdateCityEntries );

	Events.ImprovementAddedToMap.Add( UpdatePlotInfo );
	Events.ImprovementChanged.Add( UpdatePlotInfo );
	Events.ImprovementRemovedFromMap.Add( UpdatePlotInfo );

	Events.RouteAddedToMap.Add( UpdatePlotInfo );
	Events.RouteChanged.Add( UpdatePlotInfo );
	Events.RouteRemovedFromMap.Add( UpdatePlotInfo );

	LuaEvents.WorldBuilder_PlayerAdded.Add( UpdatePlayerEntries );
	LuaEvents.WorldBuilder_PlayerRemoved.Add( UpdatePlayerEntries );
	LuaEvents.WorldBuilder_PlayerEdited.Add( UpdatePlayerEntries );
	LuaEvents.WorldBuilder_StartPositionChanged.Add( OnStartPositionChanged );
end
ContextPtr:SetInitHandler( OnInit );