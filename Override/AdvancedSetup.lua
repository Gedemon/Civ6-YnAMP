-- ===========================================================================
--	Single Player Create Game w/ Advanced Options
-- ===========================================================================
include("InstanceManager");
include("PlayerSetupLogic");
include("Civ6Common");
include("SupportFunctions");

-- ===========================================================================
-- ===========================================================================

-- YnAMP <<<<<
--print ("loading AdvancedSetup with include for mods... (from Yet (not) Another Maps Pack)")
print("loading AdvancedSetup for Yet (not) Another Maps Pack...")
print("Game version : ".. tostring(UI.GetAppVersion()))
ExposedMembers.ConfigYnAMP = ExposedMembers.ConfigYnAMP or {}
ConfigYnAMP = ExposedMembers.ConfigYnAMP


------------------------------------------------------------------------------
-- YnAMP defines
------------------------------------------------------------------------------
local currentSelectedNumberMajorCivs	= 2		-- To track change to the number of selected player
local bUpdatePlayerCount				= false	-- To tell when to update player count to prevent UI lag
local bFinishedGameplayContentConfigure	= false	-- Wait before starting to check parameters for YnAMP
local autoSaveConfigName				= "AutoSaveYnAMP"
local filteredRandomLeaderList			= {}	-- List of leaders available for Random slots
local maxWorkingMapSize					= 128*80
local maxLoadingMapSize					= 200*104


-- There must be a cleaner way to get that...
local RulesetDomain	= {
	["RULESET_STANDARD"]	= "Players:StandardPlayers",
	["RULESET_EXPANSION_1"]	= "Players:Expansion1_Players",
	["RULESET_EXPANSION_2"]	= "Players:Expansion2_Players"
}

-- MapSizeS default table, rebuild and completed by custom map sizes when loading the database
ConfigYnAMP.MapSizes = ConfigYnAMP.MapSizes or {
	["MAPSIZE_DUEL"] 		= {Width = 44 ,	Height = 26 , Size = 44 * 26 },
	["MAPSIZE_TINY"] 		= {Width = 60 ,	Height = 36 , Size = 60 * 36 },
	["MAPSIZE_SMALL"] 		= {Width = 74 ,	Height = 46 , Size = 74 * 46 },
	["MAPSIZE_STANDARD"] 	= {Width = 84 ,	Height = 54 , Size = 84 * 54 },
	["MAPSIZE_LARGE"] 		= {Width = 96 ,	Height = 60 , Size = 96 * 60 },
	["MAPSIZE_HUGE"] 		= {Width = 106,	Height = 66 , Size = 106* 66 },
	["MAPSIZE_SMALL21"] 	= {Width = 84 ,	Height = 44 , Size = 84 * 44 },
	["MAPSIZE_STANDARD21"] 	= {Width = 95 ,	Height = 50 , Size = 95 * 50 },
	["MAPSIZE_LARGE21"] 	= {Width = 108,	Height = 56 , Size = 108* 56 },
	["MAPSIZE_HUGE21"]		= {Width = 120,	Height = 62 , Size = 120* 62 },
	["MAPSIZE_ENORMOUS21"] 	= {Width = 140,	Height = 74 , Size = 140* 74 },
	["MAPSIZE_ENORMOUS"] 	= {Width = 128,	Height = 80 , Size = 128* 80 },
	["MAPSIZE_GIANT"] 		= {Width = 180,	Height = 94 , Size = 180* 94 },
	["MAPSIZE_LUDICROUS"] 	= {Width = 200,	Height = 104, Size = 200* 104}
}

-- Add known CS to config DB
if ConfigYnAMP.CityStatesList then

	print("Check City States Selection list after Loading GamePlay DB...")
	local IsAvailable = {}

	-- Add CS imported from GamePlay DB to the config DB
	for i, row in ipairs(ConfigYnAMP.CityStatesList) do
		local LeaderType 		= row.LeaderType
		local LeaderName 		= row.LeaderName
		local CivilizationName 	= row.CivilizationName
		IsAvailable[LeaderType]	= true
	
		local query		= "SELECT * FROM Parameters WHERE ConfigurationId = ?"
		local results	= DB.ConfigurationQuery(query, LeaderType)
		
		if results and #results == 0 then
			print("- Adding new City State leader to Selection List: ", LeaderType)
			query = "INSERT INTO Parameters (ParameterId, Name, Description, Domain, DefaultValue, ConfigurationGroup, ConfigurationId, GroupId, SortIndex) VALUES (?, ?, ?, 'bool', 0, 'Map', ?, 'MapOptions', 99)"
			DB.ConfigurationQuery(query, LeaderType, LeaderName, CivilizationName, LeaderType)
			
			query = "INSERT INTO ParameterDependencies (ParameterId, ConfigurationGroup, ConfigurationId, Operator, ConfigurationValue) VALUES (?, 'Map', 'SelectCityStates', 'NotEquals', 'RANDOM')"
			DB.ConfigurationQuery(query, LeaderType)
		end
	end
	
	-- Remove CS missing in GamePlay DB from the Config DB
	local query		= "SELECT * from Parameters where ConfigurationId LIKE '%LEADER_MINOR_CIV%' and GroupId='MapOptions'"
	local results	= DB.ConfigurationQuery(query)
	if results and #results > 0 then
		for i, row in ipairs(results) do
			if not (IsAvailable[row.ConfigurationId]) then
				print("- Removing missing City State Leader from Selection List: ", row.ConfigurationId)
				DB.ConfigurationQuery("DELETE FROM Parameters WHERE ConfigurationId = ? ", row.ConfigurationId)
				--local query		= "SELECT * from Parameters where ConfigurationId LIKE '%LEADER_MINOR_CIV%' and GroupId='MapOptions'"
				--local results	= DB.ConfigurationQuery(query)
			end
		end
	end
end


------------------------------------------------------------------------------
-- YnAMP Math functions
------------------------------------------------------------------------------
function GetShuffledCopyOfTable(incoming_table)
	-- Designed to operate on tables with no gaps. Does not affect original table.
	local len = table.maxn(incoming_table);
	local copy = {};
	local shuffledVersion = {};
	local seed = MapConfiguration.GetValue("RANDOM_SEED")
	print("Using Map Random seed for GetShuffledCopyOfTable :", seed )
	math.randomseed(seed)
	print("random first call = ", math.random(1,10))
	-- Make copy of table.
	for loop = 1, len do
		copy[loop] = incoming_table[loop];
	end
	-- One at a time, choose a random index from Copy to insert in to final table, then remove it from the copy.
	local left_to_do = table.maxn(copy);
	for loop = 1, len do
		local random_index = math.random(1,left_to_do)--1 + TerrainBuilder.GetRandomNumber(left_to_do, "Shuffling table entry - Lua");
		table.insert(shuffledVersion, copy[random_index]);
		table.remove(copy, random_index);
		left_to_do = left_to_do - 1;
	end
	return shuffledVersion
end
-- YnAMP >>>>>

-- ===========================================================================
-- ===========================================================================

local PULLDOWN_TRUNCATE_OFFSET:number = 40;

local MIN_SCREEN_Y			:number = 768;
local SCREEN_OFFSET_Y		:number = 61;
local MIN_SCREEN_OFFSET_Y	:number = -53;

-- ===========================================================================
-- ===========================================================================

-- Instance managers for dynamic simple game options.
g_SimpleBooleanParameterManager = InstanceManager:new("SimpleBooleanParameterInstance", "CheckBox", Controls.CheckBoxParent);
g_SimplePullDownParameterManager = InstanceManager:new("SimplePullDownParameterInstance", "Root", Controls.PullDownParent);
g_SimpleSliderParameterManager = InstanceManager:new("SimpleSliderParameterInstance", "Root", Controls.SliderParent);
g_SimpleStringParameterManager = InstanceManager:new("SimpleStringParameterInstance", "Root", Controls.EditBoxParent);

g_kMapData = {};	-- Global set of map data; enough for map selection context to do it's thing. (Parameter list still truly owns the data.)

local m_NonLocalPlayerSlotManager	:table = InstanceManager:new("NonLocalPlayerSlotInstance", "Root", Controls.NonLocalPlayersSlotStack);
local m_singlePlayerID				:number = 0;			-- The player ID of the human player in singleplayer.
local m_AdvancedMode				:boolean = false;
local m_RulesetData					:table = {};
local m_BasicTooltipData			:table = {};
local m_WorldBuilderImport          :boolean = false;

-- ===========================================================================
-- Override hiding game setup to release simplified instances.
-- ===========================================================================
GameSetup_HideGameSetup = HideGameSetup;
function HideGameSetup(func)
	GameSetup_HideGameSetup(func);
	g_SimpleBooleanParameterManager:ResetInstances();
	g_SimplePullDownParameterManager:ResetInstances();
	g_SimpleSliderParameterManager:ResetInstances();
	g_SimpleStringParameterManager:ResetInstances();
end

-- ===========================================================================
-- Input Handler
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then
		local key:number = pInputStruct:GetKey();
		if key == Keys.VK_ESCAPE then
			OnBackButton();
		end
	end
	return true;
end

local _UI_BeforeRefresh = UI_BeforeRefresh;
function UI_BeforeRefresh()
	
	if(_UI_BeforeRefresh) then
		_UI_BeforeRefresh();
	end

	-- Reset basic setup container states
	Controls.CreateGame_GameDifficultyContainer:SetHide(true);
	Controls.CreateGame_SpeedPulldownContainer:SetHide(true);
	Controls.CreateGame_MapTypeContainer:SetHide(true);
	Controls.CreateGame_MapSizeContainer:SetHide(true);
end

-- Override for SetupParameters to filter ruleset values by non-scenario only.
function GameParameters_FilterValues(o, parameter, values)
	values = o.Default_Parameter_FilterValues(o, parameter, values);
	if(parameter.ParameterId == "Ruleset") then
		local new_values = {};
		for i,v in ipairs(values) do
			local data = GetRulesetData(v.Value);
			if(not data.IsScenario) then
				table.insert(new_values, v);
			end
		end
		values = new_values;
	end

	return values;
end

function GetRulesetData(rulesetType)
	if not m_RulesetData[rulesetType] then
		local query:string = "SELECT Description, LongDescription, IsScenario, ScenarioSetupPortrait, ScenarioSetupPortraitBackground from Rulesets where RulesetType = ? LIMIT 1";
		local result:table = DB.ConfigurationQuery(query, rulesetType);
		if result and #result > 0 then
			m_RulesetData[rulesetType] = result[1];
		else
			m_RulesetData[rulesetType] = {};
		end
	end
	return m_RulesetData[rulesetType];
end

-- Cache frequently accessed data.
local _cachedMapDomain = nil;
local _cachedMapData = nil;
function GetMapData( domain:string, file:string )
	-- Refresh the cache if needed.
	if(_cachedMapData == nil or _cachedMapDomain ~= domain) then
		_cachedMapDomain = domain;
		_cachedMapData = {};
		local query = "SELECT File, Image, StaticMap from Maps where Domain = ?";
		local results = DB.ConfigurationQuery(query, domain);
		if(results) then		
			for i,v in ipairs(results) do
				_cachedMapData[v.File] = v;
			end
		end
	end 

	local mapInfo = _cachedMapData[file];
	if(mapInfo) then
		local isOfficial = mapInfo.IsOfficial;
		if(isOfficial == nil) then
			local modId,path = Modding.ParseModUri(mapInfo.File);
			isOfficial = (modId == nil) or Modding.IsModOfficial(modId);
			mapInfo.IsOfficial = isOfficial;
		end
		
		return mapInfo;
	else
		-- return nothing.
		return nil;
	end
end

-- ===========================================================================
--	Build a sub-set of SetupParameters that can be used to populate a
--	map selection screen.
--
--	To send maps:		LuaEvents.MapSelect_PopulatedMaps( g_kMapData );
--	To receive choice:	LuaEvents.AdvancedSetup_SetMapByHash( Hash );
-- ===========================================================================
function BuildMapSelectData( kMapParameters:table )
	-- Sanity checks
	if kMapParameters == nil then 
		UI.DataError("Unable to build data for map selection; NIL kMapParameter passed in.);");
		return;
	end

	g_kMapData = {};	-- Clear out existing data.

	-- Loop through maps, create subset of data that is enough to show
	-- content in a map select context as well as match up with the
	-- selection.
	-- Note that "Value" in the table below may be one of the following:
	--	somename.lua									- A map script that is generated
	--	{GUID}somefile.Civ6Map							- World builder map prefixed with a GUID
	--	../..Assets/Maps/SomeFolder/myMap.Civ6Map		- World builder map in another folder
	--	{GUID}../..Assets/Maps/SomeFolder/myMap.Civ6Map	- World builder map in another folder
	local kMapCollection:table = kMapParameters.Values;
	for i,kMapData in ipairs( kMapCollection ) do
		local kExtraInfo :table = GetMapData(kMapData.Domain, kMapData.Value);

		local mapData = {
			RawName			= kMapData.RawName,
			RawDescription	= kMapData.RawDescription,
			SortIndex		= kMapData.SortIndex,
			QueryIndex		= kMapData.QueryIndex,
			Hash			= kMapData.Hash,
			Value			= kMapData.Value,
			Name			= kMapData.Name,
			Texture			= nil,
			IsWorldBuilder	= false,
			IsOfficial		= false,
		};

		if(kExtraInfo) then
			mapData.IsOfficial		= kExtraInfo.IsOfficial;
			mapData.Texture			= kExtraInfo.Image;
			mapData.IsWorldBuilder	= kExtraInfo.StaticMap;
		end
		table.insert(g_kMapData, mapData);
	end

	table.sort(g_kMapData, SortMapsByName);
end

-- ===========================================================================
function SortMapsByName(a, b)
	return Locale.Compare(a.Name, b.Name) == -1;
end

-- ===========================================================================
--	LuaEvent
--	Called from the MapSelect popup for what map hash was selected.
--	hash	the map hash to set for the game.
-- ===========================================================================
function OnSetMapByHash( hash:number )
	local kParameters	:table = g_GameParameters["Parameters"];
	local kMapParameters:table = kParameters["Map"];
	local kMapCollection:table = kMapParameters.Values;
	local isFound		:boolean = false;
	for i,kMapData in ipairs( kMapCollection ) do
		if kMapData.Hash == hash then
			g_GameParameters:SetParameterValue(kMapParameters, kMapData);
			Network.BroadcastGameConfig();			
			isFound = true;
			break;	
		end
	end
	if (not isFound) then
		UI.DataError("Unable to set the game's map to a map with the hash '"..tostring(hash).."'");
	end
end

-- ===========================================================================
function CreatePulldownDriver(o, parameter, c, container)

	local cache = {};
	local driver = {
		Control = c,
		Container = container,
		UpdateValue = function(value)
			local valueText = value and value.Name or nil;
			if(cache.ValueText ~= valueText or cache.ValueDescription ~= valueDescription) then
				local button = c:GetButton();
				local truncateWidth = button:GetSizeX() - PULLDOWN_TRUNCATE_OFFSET;
				TruncateStringWithTooltip(button, truncateWidth, valueText);
				cache.ValueText = valueText;
			end		
		end,
		UpdateValues = function(values)
			-- If container was included, hide it if there is only 1 possible value.
			if(#values == 1 and container ~= nil) then
				container:SetHide(true);
			else
				if(container) then
					container:SetHide(false);
				end

				local refresh = false;
				local cValues = cache.Values;
				if(cValues and #cValues == #values) then
					for i,v in ipairs(values) do
						local cv = cValues[i];
						if(cv == nil) then
							refresh = true;
							break;
						elseif(cv.QueryId ~= v.QueryId or cv.QueryIndex ~= v.QueryIndex or cv.Invalid ~= v.Invalid or cv.InvalidReason ~= v.InvalidReason) then
							refresh = true;
							break;
						end
					end
				else
					refresh = true;
				end

				if(refresh) then
					c:ClearEntries();
					for i,v in ipairs(values) do
						local entry = {};
						c:BuildEntry( "InstanceOne", entry );
						entry.Button:SetText(v.Name);
						if v.RawDescription then
							entry.Button:SetToolTipString(Locale.Lookup(v.RawDescription));
						else
							entry.Button:SetToolTipString(v.Description);
						end

						entry.Button:RegisterCallback(Mouse.eLClick, function()
							o:SetParameterValue(parameter, v);
							Network.BroadcastGameConfig();
						end);
					end
					c:CalculateInternals();
					cache.Values = values;
				end
			end			
		end,
		SetEnabled = function(enabled, parameter)
			c:SetDisabled(not enabled or #parameter.Values <= 1);
		end,
		SetVisible = function(visible, parameter)
			container:SetHide(not visible or parameter.Value == nil);
		end,	
		Destroy = nil,		-- It's a fixed control, no need to delete.
	};
	
	return driver;	
end

-- ===========================================================================
--	Driver for the simple menu's "Map Select"
-- ===========================================================================
function CreateSimpleMapPopupDriver(o, parameter )
	local uiMapPopupButton:object = Controls.MapSelectButton;
	local kDriver :table = {
		UpdateValues = function(o, parameter) 
			BuildMapSelectData(parameter);
		end,
		UpdateValue = function( kValue:table )
			local valueText			:string = kValue and kValue.Name or nil;
			local valueDescription	:string = kValue and kValue.Description or nil
			uiMapPopupButton:SetText( valueText );
			uiMapPopupButton:SetToolTipString( valueDescription );
		end
	}
	return kDriver;
end

-- ===========================================================================
--	Used to launch popups
--	o				main object of all the parameters
--	parameter		the parameter being changed
--	activateFunc	The function to be called when the button is pressed
--	parent			(optional) The parent control to connect to
--
--	RETURNS:		A 'driver' that represents a UI control and various common
--					functions that manipulate the control in a setup screen.
-- ===========================================================================
function CreateButtonPopupDriver(o, parameter, activateFunc, parent )

	-- Sanity check
	if(activateFunc == nil) then
		UI.DataError("Ignoring creating popup button because no callback function was passed in. Parameters: name="..parameter.Name..", groupID="..tostring(parameter.GroupId));
		return {}
	end

	-- Apply defaults
	if(parent == nil) then
		parent = GetControlStack(parameter.GroupId);
	end
			
	-- Get the UI instance
	local c :object = g_ButtonParameterManager:GetInstance();	

	-- Store the root control, NOT the instance table.
	g_SortingMap[tostring(c.ButtonRoot)] = parameter;

	c.ButtonRoot:ChangeParent(parent);
	if c.StringName ~= nil then
		c.StringName:SetText(parameter.Name);
	end

	local cache = {};

	local kDriver :table = {
		Control = c,
		Cache = cache,
		UpdateValue = function(value)
			local valueText = value and value.Name or nil;
			local valueDescription = value and value.Description or nil
			if(cache.ValueText ~= valueText or cache.ValueDescription ~= valueDescription) then
				local button = c.Button;
				button:RegisterCallback( Mouse.eLClick, activateFunc );					
				button:SetText(valueText);
				button:SetToolTipString(valueDescription);
				cache.ValueText = valueText;
				cache.ValueDescription = valueDescription;
			end
		end,
		UpdateValues = function(values, p) 
			BuildMapSelectData(p);
		end,
		SetEnabled = function(enabled, parameter)
			c.Button:SetDisabled(not enabled or #parameter.Values <= 1);
		end,
		SetVisible = function(visible)
			c.ButtonRoot:SetHide(not visible);
		end,
		Destroy = function()
			g_ButtonParameterManager:ReleaseInstance(c);
		end,
	};	

	return kDriver;
end

-- ===========================================================================
-- Override parameter behavior for basic setup screen.
g_ParameterFactories["Ruleset"] = function(o, parameter)
	
	local drivers = {};
	-- Basic setup version.
	-- Use an explicit table.
	table.insert(drivers, CreatePulldownDriver(o, parameter, Controls.CreateGame_GameRuleset, Controls.CreateGame_RulesetContainer));

	-- Advanced setup version.
	-- Create the parameter dynamically like we normally would...
	table.insert(drivers, GameParameters_UI_DefaultCreateParameterDriver(o, parameter));

	return drivers;
end
g_ParameterFactories["GameDifficulty"] = function(o, parameter)

	local drivers = {};
	-- Basic setup version.
	-- Use an explicit table.
	table.insert(drivers, CreatePulldownDriver(o, parameter, Controls.CreateGame_GameDifficulty, Controls.CreateGame_GameDifficultyContainer));

	-- Advanced setup version.
	-- Create the parameter dynamically like we normally would...
	table.insert(drivers, GameParameters_UI_DefaultCreateParameterDriver(o, parameter));

	return drivers;
end

-- ===========================================================================
g_ParameterFactories["GameSpeeds"] = function(o, parameter)

	local drivers = {};
	-- Basic setup version.
	-- Use an explicit table.
	table.insert(drivers, CreatePulldownDriver(o, parameter, Controls.CreateGame_SpeedPulldown, Controls.CreateGame_SpeedPulldownContainer));

	-- Advanced setup version.
	-- Create the parameter dynamically like we normally would...
	table.insert(drivers, GameParameters_UI_DefaultCreateParameterDriver(o, parameter));

	return drivers;
end

-- ===========================================================================
g_ParameterFactories["Map"] = function(o, parameter)

	local drivers = {};

    if (m_WorldBuilderImport) then
        return drivers;
    end

	-- Basic setup version.
	table.insert(drivers, CreateSimpleMapPopupDriver(o, parameter) );
	
	-- Advanced setup version.	
	table.insert( drivers, CreateButtonPopupDriver(o, parameter, OnMapSelect) );
	
	-- YNAMP <<<<<
	-- Restore pulldown menu for map selection, less clicks = good UI
	table.insert(drivers, GameParameters_UI_DefaultCreateParameterDriver(o, parameter));
	-- YNAMP >>>>>

	return drivers;
end

-- ===========================================================================
g_ParameterFactories["MapSize"] = function(o, parameter)

	local drivers = {};

    if (m_WorldBuilderImport) then
        return drivers;
    end

	-- Basic setup version.
	-- Use an explicit table.
	table.insert(drivers, CreatePulldownDriver(o, parameter, Controls.CreateGame_MapSize, Controls.CreateGame_MapSizeContainer));

	-- Advanced setup version.
	-- Create the parameter dynamically like we normally would...
	table.insert(drivers, GameParameters_UI_DefaultCreateParameterDriver(o, parameter));

	return drivers;
end

function CreateSimpleParameterDriver(o, parameter, parent)

	if(parent == nil) then
		parent = GetControlStack(parameter.GroupId);
	end

	local control;
	
	-- If there is no parent, don't visualize the control.  This is most likely a player parameter.
	if(parent == nil) then
		return;
	end;

	if(parameter.Domain == "bool") then
		local c = g_SimpleBooleanParameterManager:GetInstance();	
		
		local name = Locale.ToUpper(parameter.Name);
		c.CheckBox:SetText(name);
		c.CheckBox:SetToolTipString(parameter.Description);
		c.CheckBox:RegisterCallback(Mouse.eLClick, function()
			o:SetParameterValue(parameter, not c.CheckBox:IsSelected());
			Network.BroadcastGameConfig();
		end);
		c.CheckBox:ChangeParent(parent);

		control = {
			Control = c,
			UpdateValue = function(value, parameter)
				
				-- Sometimes the parameter name is changed, be sure to update it.
				c.CheckBox:SetText(parameter.Name);
				c.CheckBox:SetToolTipString(parameter.Description);
				
				-- We have to invalidate the selection state in order
				-- to trick the button to use the right vis state..
				-- Please change this to a real check box in the future...please
				c.CheckBox:SetSelected(not value);
				c.CheckBox:SetSelected(value);
			end,
			SetEnabled = function(enabled)
				c.CheckBox:SetDisabled(not enabled);
			end,
			SetVisible = function(visible)
				c.CheckBox:SetHide(not visible);
			end,
			Destroy = function()
				g_SimpleBooleanParameterManager:ReleaseInstance(c);
			end,
		};

	elseif(parameter.Domain == "int" or parameter.Domain == "uint" or parameter.Domain == "text") then
		local c = g_SimpleStringParameterManager:GetInstance();		

		local name = Locale.ToUpper(parameter.Name);	
		c.StringName:SetText(name);
		c.Root:SetToolTipString(parameter.Description);
		c.StringEdit:SetEnabled(true);

		local canChangeEnableState = true;

		if(parameter.Domain == "int") then
			c.StringEdit:SetNumberInput(true);
			c.StringEdit:SetMaxCharacters(16);
			c.StringEdit:RegisterCommitCallback(function(textString)
				o:SetParameterValue(parameter, tonumber(textString));	
				Network.BroadcastGameConfig();
			end);
		elseif(parameter.Domain == "uint") then
			c.StringEdit:SetNumberInput(true);
			c.StringEdit:SetMaxCharacters(16);
			c.StringEdit:RegisterCommitCallback(function(textString)
				local value = math.max(tonumber(textString) or 0, 0);
				o:SetParameterValue(parameter, value);	
				Network.BroadcastGameConfig();
			end);
		else
			c.StringEdit:SetNumberInput(false);
			c.StringEdit:SetMaxCharacters(64);
			if UI.HasFeature("TextEntry") == true then
				c.StringEdit:RegisterCommitCallback(function(textString)
					o:SetParameterValue(parameter, textString);	
					Network.BroadcastGameConfig();
				end);
			else
				canChangeEnableState = false;
				c.StringEdit:SetEnabled(false);
			end
		end

		c.Root:ChangeParent(parent);

		control = {
			Control = c,
			UpdateValue = function(value)
				c.StringEdit:SetText(Locale.Lookup(value));
			end,
			SetEnabled = function(enabled)
				if canChangeEnableState then
					c.Root:SetDisabled(not enabled);
					c.StringEdit:SetDisabled(not enabled);
				end
			end,
			SetVisible = function(visible)
				c.Root:SetHide(not visible);
			end,
			Destroy = function()
				g_SimpleStringParameterManager:ReleaseInstance(c);
			end,
		};
	elseif (parameter.Values and parameter.Values.Type == "IntRange") then -- Range
		
		local minimumValue = parameter.Values.MinimumValue;
		local maximumValue = parameter.Values.MaximumValue;

		-- Get the UI instance
		local c = g_SimpleSliderParameterManager:GetInstance();	
		
		c.Root:ChangeParent(parent);

		local name = Locale.ToUpper(parameter.Name);
		if c.StringName ~= nil then
			c.StringName:SetText(name);
		end
			
		c.OptionTitle:SetText(name);
		c.Root:SetToolTipString(parameter.Description);
		c.OptionSlider:RegisterSliderCallback(function()
			local stepNum = c.OptionSlider:GetStep();
			
			-- This method can get called pretty frequently, try and throttle it.
			if(parameter.Value ~= minimumValue + stepNum) then
				o:SetParameterValue(parameter, minimumValue + stepNum);
				Network.BroadcastGameConfig();
			end
		end);


		control = {
			Control = c,
			UpdateValue = function(value)
				if(value) then
					c.OptionSlider:SetStep(value - minimumValue);
					c.NumberDisplay:SetText(tostring(value));
				end
			end,
			UpdateValues = function(values)
				c.OptionSlider:SetNumSteps(values.MaximumValue - values.MinimumValue);
			end,
			SetEnabled = function(enabled, parameter)
				c.OptionSlider:SetHide(not enabled or parameter.Values == nil or parameter.Values.MinimumValue == parameter.Values.MaximumValue);
			end,
			SetVisible = function(visible, parameter)
				c.Root:SetHide(not visible or parameter.Value == nil );
			end,
			Destroy = function()
				g_SimpleSliderParameterManager:ReleaseInstance(c);
			end,
		};	
	elseif (parameter.Values) then -- MultiValue
		
		-- Get the UI instance
		local c = g_SimplePullDownParameterManager:GetInstance();	

		c.Root:ChangeParent(parent);
		if c.StringName ~= nil then
			local name = Locale.ToUpper(parameter.Name);
			c.StringName:SetText(name);
		end

		control = {
			Control = c,
			UpdateValue = function(value)
				local button = c.PullDown:GetButton();
				button:SetText( value and value.Name or nil);
				button:SetToolTipString(value and value.Description or nil);
			end,
			UpdateValues = function(values)
				c.PullDown:ClearEntries();

				for i,v in ipairs(values) do
					local entry = {};
					c.PullDown:BuildEntry( "InstanceOne", entry );
					entry.Button:SetText(v.Name);
					entry.Button:SetToolTipString(v.Description);

					entry.Button:RegisterCallback(Mouse.eLClick, function()
						o:SetParameterValue(parameter, v);
						Network.BroadcastGameConfig();
					end);
				end
				c.PullDown:CalculateInternals();
			end,
			SetEnabled = function(enabled, parameter)
				c.PullDown:SetDisabled(not enabled or #parameter.Values <= 1);
			end,
			SetVisible = function(visible)
				c.Root:SetHide(not visible);
			end,
			Destroy = function()
				g_SimplePullDownParameterManager:ReleaseInstance(c);
			end,
		};	
	end

	return control;
end

-- The method used to create a UI control associated with the parameter.
-- Returns either a control or table that will be used in other parameter view related hooks.
function GameParameters_UI_CreateParameter(o, parameter)
	local func = g_ParameterFactories[parameter.ParameterId];

	local control;
	if(func)  then
		control = func(o, parameter);
	elseif(parameter.GroupId == "BasicGameOptions" or parameter.GroupId == "BasicMapOptions") then	
		control = {
			CreateSimpleParameterDriver(o, parameter, Controls.CreateGame_ExtraParametersStack),
			GameParameters_UI_DefaultCreateParameterDriver(o, parameter)
		};
	else
		control = GameParameters_UI_DefaultCreateParameterDriver(o, parameter);
	end

	o.Controls[parameter.ParameterId] = control;
end

-- ===========================================================================
-- Remove player handler.
function RemovePlayer(voidValue1, voidValue2, control)
	print("Removing Player " .. tonumber(voidValue1));
	local playerConfig = PlayerConfigurations[voidValue1];
	playerConfig:SetLeaderTypeName(nil);
	
	-- YnAMP <<<<<
	local nextNumPlayer = GameConfiguration.GetParticipatingPlayerCount() - 1
	if currentSelectedNumberMajorCivs > nextNumPlayer then
		currentSelectedNumberMajorCivs 	= nextNumPlayer
		bUpdatePlayerCount 				= true
		GameConfiguration.SetValue("MajorCivilizationsCount", currentSelectedNumberMajorCivs)
		GameConfiguration.SetParticipatingPlayerCount(currentSelectedNumberMajorCivs)
	elseif currentSelectedNumberMajorCivs < nextNumPlayer then
		GameConfiguration.SetValue("MajorCivilizationsCount", currentSelectedNumberMajorCivs)
		GameConfiguration.SetParticipatingPlayerCount(currentSelectedNumberMajorCivs)
	end
	-- YnAMP >>>>>
	
	GameConfiguration.RemovePlayer(voidValue1);

	GameSetup_PlayerCountChanged();
end

-- ===========================================================================
-- Add UI entries for all the players.  This does not set the
-- UI values of the player.
-- ===========================================================================
function RefreshPlayerSlots()

	RebuildPlayerParameters();
	m_NonLocalPlayerSlotManager:ResetInstances();

	local player_ids = GameConfiguration.GetParticipatingPlayerIDs();

	local minPlayers = MapConfiguration.GetMinMajorPlayers() or 2;
	local maxPlayers = MapConfiguration.GetMaxMajorPlayers() or 2;
	local can_remove = #player_ids > minPlayers;
	local can_add = #player_ids < maxPlayers;

	Controls.AddAIButton:SetHide(not can_add);

	print("There are " .. #player_ids .. " participating players.");

	Controls.BasicTooltipContainer:DestroyAllChildren();
	Controls.BasicPlacardContainer:DestroyAllChildren();
	Controls.AdvancedTooltipContainer:DestroyAllChildren();
	
	local basicTooltip = {};
	ContextPtr:BuildInstanceForControl( "CivToolTip", basicTooltip, Controls.BasicTooltipContainer );
	local basicPlacard	:table = {};
	ContextPtr:BuildInstanceForControl( "LeaderPlacard", basicPlacard, Controls.BasicPlacardContainer );

	m_BasicTooltipData = {
		InfoStack			= basicTooltip.InfoStack,
		InfoScrollPanel		= basicTooltip.InfoScrollPanel;
		CivToolTipSlide		= basicTooltip.CivToolTipSlide;
		CivToolTipAlpha		= basicTooltip.CivToolTipAlpha;
		UniqueIconIM		= InstanceManager:new("IconInfoInstance",	"Top",	basicTooltip.InfoStack );		
		HeaderIconIM		= InstanceManager:new("IconInstance",		"Top",	basicTooltip.InfoStack );
		CivHeaderIconIM		= InstanceManager:new("CivIconInstance",	"Top",	basicTooltip.InfoStack );
		HeaderIM			= InstanceManager:new("HeaderInstance",		"Top",	basicTooltip.InfoStack );
		HasLeaderPlacard	= true;
		LeaderBG			= basicPlacard.LeaderBG;
		LeaderImage			= basicPlacard.LeaderImage;
		DummyImage			= basicPlacard.DummyImage;
		CivLeaderSlide		= basicPlacard.CivLeaderSlide;
		CivLeaderAlpha		= basicPlacard.CivLeaderAlpha;
	};

	local advancedTooltip	:table = {};
	ContextPtr:BuildInstanceForControl( "CivToolTip", advancedTooltip, Controls.AdvancedTooltipContainer );

	local advancedTooltipData : table = {
		InfoStack			= advancedTooltip.InfoStack,
		InfoScrollPanel		= advancedTooltip.InfoScrollPanel;
		CivToolTipSlide		= advancedTooltip.CivToolTipSlide;
		CivToolTipAlpha		= advancedTooltip.CivToolTipAlpha;
		UniqueIconIM		= InstanceManager:new("IconInfoInstance",	"Top",	advancedTooltip.InfoStack );		
		HeaderIconIM		= InstanceManager:new("IconInstance",		"Top",	advancedTooltip.InfoStack );
		CivHeaderIconIM		= InstanceManager:new("CivIconInstance",	"Top",	advancedTooltip.InfoStack );
		HeaderIM			= InstanceManager:new("HeaderInstance",		"Top",	advancedTooltip.InfoStack );
		HasLeaderPlacard	= false;
	};

	for i, player_id in ipairs(player_ids) do	
		if(m_singlePlayerID == player_id) then
			SetupLeaderPulldown(player_id, Controls, "Basic_LocalPlayerPulldown", "Basic_LocalPlayerCivIcon",  "Basic_LocalPlayerCivIconBG", "Basic_LocalPlayerLeaderIcon", m_BasicTooltipData);
			SetupLeaderPulldown(player_id, Controls, "Advanced_LocalPlayerPulldown", "Advanced_LocalPlayerCivIcon", "Advanced_LocalPlayerCivIconBG", "Advanced_LocalPlayerLeaderIcon", advancedTooltipData, "Advanced_LocalColorPullDown");
		else
			local ui_instance = m_NonLocalPlayerSlotManager:GetInstance();
			
			-- Assign the Remove handler
			if(can_remove) then
				ui_instance.RemoveButton:SetVoid1(player_id);
				ui_instance.RemoveButton:RegisterCallback(Mouse.eLClick, RemovePlayer);
			end
			ui_instance.RemoveButton:SetHide(not can_remove);
			
			SetupLeaderPulldown(player_id, ui_instance,"PlayerPullDown",nil,nil,nil,advancedTooltipData);
		end
	end

	Controls.NonLocalPlayersSlotStack:CalculateSize();
	Controls.NonLocalPlayersSlotStack:ReprocessAnchoring();
	Controls.NonLocalPlayersStack:CalculateSize();
	Controls.NonLocalPlayersStack:ReprocessAnchoring();
	Controls.NonLocalPlayersPanel:CalculateInternalSize();
	Controls.NonLocalPlayersPanel:CalculateSize();

	-- Queue another refresh
	GameSetup_RefreshParameters();
end

-- ===========================================================================
-- Called every time parameters have been refreshed.
-- This is a useful spot to perform validation.
function UI_PostRefreshParameters()
	-- Most of the options self-heal due to the setup parameter logic.
	-- However, player options are allowed to be in an 'invalid' state for UI
	-- This way, instead of hiding/preventing the user from selecting an invalid player
	-- we can allow it, but display an error message explaining why it's invalid.

	-- This is primarily used to present ownership errors and custom constraint errors.
	Controls.StartButton:SetDisabled(false);
	Controls.StartButton:SetToolTipString(nil);

	local game_err = GetGameParametersError();
	if(game_err) then
	-- YnAMP <<<<<
	print("GetGameParametersError = ",game_err)
	-- YnAMP >>>>>
		Controls.StartButton:SetDisabled(true);
		Controls.StartButton:LocalizeAndSetToolTip("LOC_SETUP_PARAMETER_ERROR");
	end
	
	local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
	for i, player_id in ipairs(player_ids) do	
		local err = GetPlayerParameterError(player_id);
		if(err) then
			-- YnAMP <<<<<
			print("GetPlayerParameterError = ", err)
			-- YnAMP >>>>>
			Controls.StartButton:SetDisabled(true);
			Controls.StartButton:LocalizeAndSetToolTip("LOC_SETUP_PLAYER_PARAMETER_ERROR");
		end
	end

	-- TTP[20948]: Display leader placard for the currently selected leader
	local playerConfig = PlayerConfigurations[m_singlePlayerID];
	if(playerConfig and m_BasicTooltipData) then
		local selectedLeader = playerConfig:GetLeaderTypeID();
		if(selectedLeader ~= -1) then
			local leaderType = playerConfig:GetLeaderTypeName();
			local info = GetPlayerInfo(playerConfig:GetValue("LEADER_DOMAIN"), leaderType);
			DisplayCivLeaderToolTip(info, m_BasicTooltipData, false);
		end
	end
	
	Controls.CreateGameOptions:CalculateSize();
	Controls.CreateGameOptions:ReprocessAnchoring();
end

-------------------------------------------------------------------------------
-- Event Listeners
-------------------------------------------------------------------------------
function OnFinishedGameplayContentConfigure(result)
	if(ContextPtr and not ContextPtr:IsHidden() and result.Success) then
		GameSetup_RefreshParameters();
	end
end

-- ===========================================================================
function GameSetup_PlayerCountChanged()
	print("Player Count Changed");
	RefreshPlayerSlots();
end

-- ===========================================================================
function OnShow()

	 m_WorldBuilderImport = false;
	local bWorldBuilder = GameConfiguration.IsWorldBuilderEditor();

	if (bWorldBuilder) then
		Controls.WindowTitle:LocalizeAndSetText("{LOC_SETUP_CREATE_MAP:upper}");

        if (MapConfiguration.GetScript() == "WBImport.lua") then
            m_WorldBuilderImport = true;
        end
		
		-- KLUDGE: Ideally setup parameters in a group should have some sort of control mechanism for whether or not the group should show.
		Controls.CreateGame_LocalPlayerContainer:SetHide(true);
		Controls.PlayersSection:SetHide(true);
		Controls.VictoryParametersHeader:SetHide(true);
		-- YnAMP <<<<<
		-- Unhide for faster testing of map and scenario settings using the WB
		Controls.CreateGame_LocalPlayerContainer:SetHide(false);
		Controls.PlayersSection:SetHide(false);
		Controls.VictoryParametersHeader:SetHide(false);
		-- ynAMP >>>>>
		
    else
		Controls.CreateGame_LocalPlayerContainer:SetHide(false);
		Controls.PlayersSection:SetHide(false);
		Controls.VictoryParametersHeader:SetHide(false);
		
		Controls.WindowTitle:LocalizeAndSetText("{LOC_SETUP_CREATE_GAME:upper}");
	end

	RefreshPlayerSlots();	-- Will trigger a game parameter refresh.
	AutoSizeGridButton(Controls.DefaultButton,133,36,15,"H");
	AutoSizeGridButton(Controls.CloseButton,133,36,10,"H");
	-- YnAMP <<<<<
	AutoSizeGridButton(Controls.LoadDataYnAMP,133,36,15,"H");
	local offsetX = Controls.CloseButton:GetSizeX()
	Controls.LoadDataYnAMP:SetOffsetX(offsetX)
	-- ynAMP >>>>>

	-- the map size and type dropdowns don't make sense on a map import

    if (m_WorldBuilderImport) then
        Controls.CreateGame_MapType:SetDisabled(true);
        Controls.CreateGame_MapSize:SetDisabled(true);
        Controls.StartButton:LocalizeAndSetText("LOC_LOAD_TILED");
		MapConfiguration.SetScript("WBImport.lua");
    elseif(bWorldBuilder) then
		Controls.CreateGame_MapType:SetDisabled(false);
        Controls.CreateGame_MapSize:SetDisabled(false);
        Controls.StartButton:LocalizeAndSetText("LOC_SETUP_WORLDBUILDER_START");
	else
        Controls.CreateGame_MapType:SetDisabled(false);
        Controls.CreateGame_MapSize:SetDisabled(false);
        Controls.StartButton:LocalizeAndSetText("LOC_START_GAME");
    end
end

-- ===========================================================================
function OnHide()
	HideGameSetup();
	ReleasePlayerParameters();
	m_RulesetData = {};
end


-- ===========================================================================
-- Button Handlers
-- ===========================================================================

-- ===========================================================================
function OnAddAIButton()
	-- Search for an empty slot number and mark the slot as computer.
	-- Then dispatch the player count changed event.
	local iPlayer = 0;
	while(true) do
		local playerConfig = PlayerConfigurations[iPlayer];
		
		-- If we've reached the end of the line, exit.
		if(playerConfig == nil) then
			break;
		end

		-- Find a suitable slot to add the AI.
		if (playerConfig:GetSlotStatus() == SlotStatus.SS_CLOSED) then
			playerConfig:SetSlotStatus(SlotStatus.SS_COMPUTER);
			playerConfig:SetMajorCiv();
			
			-- YnAMP <<<<<
			-- todo : clean implementation with a counter in the while loop until currentSelectedNumberMajorCivs is reached.
			local nextNumPlayer = GameConfiguration.GetParticipatingPlayerCount()
			if currentSelectedNumberMajorCivs < nextNumPlayer then
				currentSelectedNumberMajorCivs 	= nextNumPlayer
				bUpdatePlayerCount 				= true
				GameConfiguration.SetValue("MajorCivilizationsCount", currentSelectedNumberMajorCivs)
				GameConfiguration.SetParticipatingPlayerCount(currentSelectedNumberMajorCivs)
			elseif currentSelectedNumberMajorCivs > nextNumPlayer then
				GameConfiguration.SetValue("MajorCivilizationsCount", currentSelectedNumberMajorCivs)
				GameConfiguration.SetParticipatingPlayerCount(currentSelectedNumberMajorCivs)
			end
			-- YnAMP >>>>>

			GameSetup_PlayerCountChanged();
			break;
		end

		-- Increment the AI, this assumes that either player config will hit nil 
		-- or we'll reach a suitable slot.
		iPlayer = iPlayer + 1;
	end
end

-- ===========================================================================
function OnAdvancedSetup()
	local bWorldBuilder = GameConfiguration.IsWorldBuilderEditor();

	Controls.CreateGameWindow:SetHide(true);
	Controls.AdvancedOptionsWindow:SetHide(false);
	Controls.LoadConfig:SetHide(bWorldBuilder);
	Controls.SaveConfig:SetHide(bWorldBuilder);
	-- YnAMP <<<<<
	Controls.LoadConfig:SetHide(false);
	Controls.SaveConfig:SetHide(false);
	-- YnAMP >>>>>
	Controls.ButtonStack:CalculateSize();

	m_AdvancedMode = true;
end

-- ===========================================================================
function OnMapSelect()
	LuaEvents.MapSelect_PopulatedMaps( g_kMapData );
	Controls.MapSelectWindow:SetHide(false);
end

-- ===========================================================================
function OnDefaultButton()
	print("Reseting Setup Parameters");

	local bWorldBuilder = GameConfiguration.IsWorldBuilderEditor();
	GameConfiguration.SetToDefaults();
	GameConfiguration.SetWorldBuilderEditor(bWorldBuilder);
	
	-- In World Builder we want to default to Standard Rules.
	if(not bWorldBuilder) then
		-- Kludge:  SetToDefaults assigns the ruleset to be standard.
		-- Clear this value so that the setup parameters code can guess the best 
		-- default.
		GameConfiguration.SetValue("RULESET", nil);
	end

	GameConfiguration.RegenerateSeeds();
	return GameSetup_PlayerCountChanged();
end

-- ===========================================================================
function OnStartButton()

	-- <<<<< YNAMP
	---[[
	local player_ids 	= GameConfiguration.GetParticipatingPlayerIDs();
	local numPlayers 	= #player_ids
	local numCS			= GameConfiguration.GetValue("CITY_STATE_COUNT")
	local newNumCS		= numCS
	local maxPlayer		= 62 			-- max is 64 but 1 slot is required for barbarian and 1 slot for free cities
	local cityStateID	= 0 			-- Player slots IDs start at 0, Human is 0, so we should start at 1, but start at 0 in case some mod (spectator ?) change that
	local maxCS 		= maxPlayer - numPlayers
	local bSelectCS		= MapConfiguration.GetValue("SelectCityStates") ~= "RANDOM"
	local bBanLeaders	= MapConfiguration.GetValue("BanLeaders")
	local ruleset		= GameConfiguration.GetValue("RULESET")
	local playerDomain	= ruleset and RulesetDomain[ruleset] or "Players:StandardPlayers"
	
	-- Limit number of players for R&F and GS
	print("------------------------------------------------------")
	print("YnAMP checking for number of players limit on Start...")
	print("num. players = ".. tostring(numPlayers) .. ", num. CS = ".. tostring(numCS), ", Selection type = ", MapConfiguration.GetValue("SelectCityStates"), ", Do selection =", bSelectCS)
	if (GameConfiguration.GetValue("RULESET") == "RULESET_EXPANSION_1" or GameConfiguration.GetValue("RULESET") == "RULESET_EXPANSION_2") and numPlayers + numCS > maxPlayer then
		newNumCS = maxCS
		print("new num. CS = ".. tostring(newNumCS))
		GameConfiguration.SetValue("CITY_STATE_COUNT", newNumCS)
	end
	
	if bBanLeaders then
		print("------------------------------------------------------")
		print("Applying Leader Ban list on Random slots...")
		
		local IsUsedCiv		= {}
		local IsUsedLeader 	= {}
		
		-- Taken from SetupParameters:Parameter_FilterValues
		-- <<<
		local unique_leaders 		= GameConfiguration.GetValue("NO_DUPLICATE_LEADERS");
		local unique_civilizations 	= GameConfiguration.GetValue("NO_DUPLICATE_CIVILIZATIONS");

		local leaders_in_use;
		local civilizations_in_use;

		local InsertIntoDuplicateBucket = function(map, key, other_key)
			local bucketA = map[key];
			local bucketB = map[other_key];

			if(bucketA == nil and bucketB == nil) then
				bucketA = {key, other_key};
				map[key] = bucketA;
				map[other_key] = bucketA;

			elseif(bucketA == nil and bucketB ~= nil) then
				table.insert(bucketB, key);
				map[key] = bucketB;

			elseif(bucketA ~= nil and bucketB == nil) then
				table.insert(bucketA, other_key);
				map[other_key] = bucketA;
			
			elseif(bucketA ~= nil and bucketB ~= nil and bucketA ~= bucketB) then
				-- consolidate buckets
				-- if A is a dupe of B and B is a dupe of C, then A is a dupe of C.
				for i,v in ipairs(bucketB) do
					table.insert(bucketA, v);
					map[v] = bucketA;
				end

			elseif(bucketA == bucketB) then
				-- buckets are same, no need to do anything since they are already dupes of each other
			end
		end;

		local duplicate_civilizations;
		if(unique_civilizations) then
			duplicate_civilizations = {};
			for i, row in ipairs(CachedQuery("SELECT CivilizationType, OtherCivilizationType from DuplicateCivilizations where Domain = ?", playerDomain)) do
				InsertIntoDuplicateBucket(duplicate_civilizations, row.CivilizationType, row.OtherCivilizationType);
			end
		end

		local duplicate_leaders;
		if(unique_leaders) then
			duplicate_leaders = {};
			for i, row in ipairs(CachedQuery("SELECT LeaderType, OtherLeaderType from DuplicateLeaders where Domain = ?", playerDomain)) do
				InsertIntoDuplicateBucket(duplicate_leaders, row.LeaderType, row.OtherLeaderType);
			end
		end
		-->>>
		
		local function MarkUsedCiv(civilizationType)
			IsUsedCiv[civilizationType] = true
			local dupes = duplicate_civilizations and duplicate_civilizations[civilizationType]
			if(dupes) then
				for i,v in ipairs(dupes) do
					IsUsedCiv[v] = true
				end
			end 
		end
		
		local function MarkUsedLeader(leaderType)
			IsUsedLeader[leaderType] = true
			local dupes = duplicate_leaders and duplicate_leaders[leaderType]
			if(dupes) then
				for i,v in ipairs(dupes) do
					IsUsedLeader[v] = true
				end
			end 
		end
			
		-- Get Random slots and used leaders and Civs
		local randomSlots = {}
		for i, slotID in ipairs(player_ids) do	
			local playerConfig = PlayerConfigurations[slotID];
			if playerConfig:GetSlotName() == "LOC_RANDOM_LEADER" then
				table.insert(randomSlots, slotID)
			else
				local civilizationType 	= playerConfig:GetCivilizationTypeName()
				local leaderType 		= playerConfig:GetLeaderTypeName()
				MarkUsedCiv(civilizationType)
				MarkUsedLeader(leaderType)
			end
		end
		print("Random Leaders Slots = ", #randomSlots)
		
		if #randomSlots > 0 then -- don't waste time if there are no random slots...
			
			local shuffledList 	= GetShuffledCopyOfTable(filteredRandomLeaderList)
			local listIndex		= 1
		
			-- Helper to get the CivilizationType of a LeaderType
			local function GetPlayerCivilization(leaderType)
				for i, row in ipairs(CachedQuery("SELECT CivilizationType from Players where LeaderType = ? LIMIT 1", leaderType)) do
					return row.CivilizationType
				end
			end
			--
			local function GetLeaderName(leaderType)
				for i, row in ipairs(CachedQuery("SELECT LeaderName from Players where LeaderType = ? LIMIT 1", leaderType)) do
					return row.LeaderName
				end
			end
			-- 			
			local function GetNextLeaderType(bSecondLoop)
				local leaderType 		= shuffledList[listIndex]
				local bNoDupeLeaders 	= unique_leaders or (not bSecondLoop) 		-- avoid duplicate leaders on first loop, even if allowaed
				local bNoDupeCivs 		= unique_civilizations or (not bSecondLoop) -- avoid duplicate civs on first loop, even if allowed
				while(leaderType) do
					if not MapConfiguration.GetValue(leaderType) then -- this leaderType is not banned
						if (not IsUsedLeader[leaderType]) or (not bNoDupeLeaders) then
							local civilizationType = GetPlayerCivilization(leaderType)
							if (not IsUsedCiv[civilizationType]) or (not bNoDupeCivs) then
								MarkUsedCiv(civilizationType)
								MarkUsedLeader(leaderType)
								listIndex 	= listIndex + 1
								return leaderType
							else
								print(" - Can't use leader because of duplicate Civilization : ", leaderType, civilizationType)
							end
						else
							print(" - Can't use duplicate leader : ", leaderType)
						end
					else
						print(" - Can't use banned leader : ", leaderType)
					end
					listIndex 	= listIndex + 1
					leaderType 	= shuffledList[listIndex]
				end
				if not bSecondLoop then -- in case duplicates are allowed
					print(" - Can't find next leader, trying second loop")
					listIndex = 1
					return GetNextLeaderType(true)
				else
					print(" - Can't find next leader after second loop")
				end
			end
			
			print("Setting random slots...")
			for i, slotID in ipairs(randomSlots) do
				local playerConfig 	= PlayerConfigurations[slotID]
				local leaderType 	= GetNextLeaderType()
				if leaderType then
					print("- Placing ", leaderType, " in slot#", slotID)
					playerConfig:SetSlotStatus(SlotStatus.SS_COMPUTER)
					playerConfig:SetLeaderName(GetLeaderName(leaderType))
					playerConfig:SetLeaderTypeName(leaderType)
					playerConfig:SetMajorCiv()
				else
					print("- No LeaderType available, clearing slot#", slotID)
					playerConfig:SetLeaderTypeName(nil)
					GameConfiguration.RemovePlayer(slotID)
				end
			end
		end
	end
	
	-- Get available player slots list for CS
	if bSelectCS then
		print("------------------------------------------------------")
		print("Generate available slots list for CS...")
		local CityStatesSlotsList	= {}
		while(cityStateID < maxPlayer) do
			local playerConfig = PlayerConfigurations[cityStateID];
			
			-- If we've reached the end of the line, exit.
			if(playerConfig == nil) then
				print("playerConfig is nil at cityStateID#", cityStateID)
				--break;
			end

			-- Check for free slots to add to the CS list.
			if (playerConfig:GetSlotStatus() == SlotStatus.SS_CLOSED) then
				table.insert(CityStatesSlotsList, cityStateID)
			end

			-- Increment the AI, this assumes that either player config will hit nil 
			-- or we'll reach a suitable slot.
			cityStateID = cityStateID + 1;
		end
		
		-- Get the City States list
		local query		= "SELECT * from Parameters where ConfigurationId LIKE '%LEADER_MINOR_CIV%' and GroupId='MapOptions'"
		local results	= DB.ConfigurationQuery(query)
		
		if(results and #results > 0) then
			local bCapped			= MapConfiguration.GetValue("SelectCityStates") == "SELECTION"
			local bOnlySelection	= MapConfiguration.GetValue("SelectCityStates") == "ONLY_SELECTION"
			local cityStateSlots 	= (bCapped and numCS) or maxCS
			local shuffledList 		= GetShuffledCopyOfTable(results)
			local randomList		= {}
			local slotListID		= 1
			print("------------------------------------------------------")
			print("YnAMP setting specific CS slots...")
			print("Trying to reserve slots for selected CS, available slots = "..tostring(#CityStatesSlotsList)..", maxCS = "..tostring(cityStateSlots).. ", bCapped = ", bCapped, " bOnlySelection = ", bOnlySelection)
			for i, row in ipairs(shuffledList) do
				--print(i)
				--for k, v in pairs(row) do print(k, v) end
				local leaderType = row.ConfigurationId
				local leaderName = row.Name
				if MapConfiguration.GetValue(leaderType) then -- true if this CS was checked
					if cityStateSlots > 0 then
						local slotID = CityStatesSlotsList[slotListID]
						if slotID then
							print(" - Reserving player slot#"..tostring(slotID).." for ".. Locale.Lookup(leaderName) )
							local playerConfig = PlayerConfigurations[slotID]
							playerConfig:SetSlotStatus(SlotStatus.SS_COMPUTER)
							playerConfig:SetLeaderName(leaderName)
							playerConfig:SetLeaderTypeName(leaderType)
							cityStateSlots	= cityStateSlots - 1
							slotListID		= slotListID + 1
						else
							print(" - ERROR, No slots found for ".. Locale.Lookup(leaderName) .." at slotListID#"..tostring(slotListID).."/".. tostring(#CityStatesSlotsList) .." but calculated slots left = ".. tostring(cityStateSlots) )
						end
					else
						print(" - Maximum #CS reached, can't set a slot for ".. Locale.Lookup(leaderName) .." at slotListID#"..tostring(slotListID).."/".. tostring(#CityStatesSlotsList) )					
					end
				else -- add unselected CS to the random pool
					table.insert(randomList, row)
				end
			end
			local placedCS	= slotListID - 1
			local newNumCS 	= bOnlySelection and 0 or math.max(0, numCS - placedCS)
			print("Unused slots left = ", cityStateSlots )
			print("Setting Random CS to number of slots = ", newNumCS )
			--GameConfiguration.SetValue("CITY_STATE_COUNT", newNumCS)
			---[[
			if newNumCS > 0 then
				local nextIndex	= 1
				for slotListID = slotListID, slotListID + newNumCS - 1 do --cityStateSlots do
					local slotID 		= CityStatesSlotsList[slotListID]
					local playerConfig 	= PlayerConfigurations[slotID]
					if playerConfig then
						-- get next entry in the random pool
						local row	= randomList[nextIndex]
						nextIndex	= nextIndex + 1
						if row then
							local leaderType = row.ConfigurationId
							local leaderName = row.Name
							print(" - Reserving player slot#"..tostring(slotID).." for ".. Locale.Lookup(leaderName) )
							playerConfig:SetSlotStatus(SlotStatus.SS_COMPUTER)
							playerConfig:SetLeaderName(leaderName)
							playerConfig:SetLeaderTypeName(leaderType)
						else
							print(" - No more CS in Random pool, can't set a CS at slotListID#"..tostring(slotListID).."/".. tostring(#CityStatesSlotsList) )
						end
					else
						print(" - No more Slot available, can't set a CS at slotListID#"..tostring(slotListID).."/".. tostring(#CityStatesSlotsList) )
					end
				end
			end
			--]]
		end
	end
	
	-- List the player slots
	local slotStatusString	= {}
	local civLevelString	= {}
	for key, v in pairs(SlotStatus) do
		slotStatusString[v] = key
	end
	for key, v in pairs(CivilizationLevelTypes) do
		civLevelString[v] = key
	end
		
	print("------------------------------------------------------")
	print("Setup Player slots :")
	for slotID = 0, 63 do
		local playerConfig = PlayerConfigurations[slotID]
		print(slotID, playerConfig and playerConfig:GetLeaderTypeName(), playerConfig and playerConfig:GetLeaderTypeName(), playerConfig and playerConfig:GetCivilizationTypeName(), playerConfig and playerConfig:GetSlotName(), playerConfig and (slotStatusString[playerConfig:GetSlotStatus()] or "UNK STATUS"), playerConfig and (civLevelString[playerConfig:GetCivilizationLevelTypeID()] or "UNK LEVEL"),  playerConfig and playerConfig:IsAI())
	end
	
	-- Make some debugging info available during map creation
	--local listMods	= Modding.GetActiveMods()
	local listMods		= {}
	local installedMods = Modding.GetInstalledMods()

	---[[
	if installedMods ~= nil then
		for i, modData in ipairs(installedMods) do
			if modData.Enabled then
				table.insert(listMods, modData)
			end
		end
	end
	ExposedMembers.YnAMP_Loading	= {
		ListMods 	= listMods,
		GameVersion = UI.GetAppVersion()
	}
	--]]
	-- YNAMP >>>>>
	
	-- Is WorldBuilder active?
	if (GameConfiguration.IsWorldBuilderEditor()) then
        if (m_WorldBuilderImport) then
            MapConfiguration.SetScript("WBImport.lua");
			local loadGameMenu 		= ContextPtr:LookUpControl( "/FrontEnd/MainMenu/LoadGameMenu" );
			UIManager:QueuePopup(loadGameMenu, PopupPriority.Current);	
		else
			UI.SetWorldRenderView( WorldRenderView.VIEW_2D );
			UI.PlaySound("Set_View_2D");
			Network.HostGame(ServerType.SERVER_TYPE_NONE);
		end
	else
		-- No, start a normal game
		UI.PlaySound("Set_View_3D");
		Network.HostGame(ServerType.SERVER_TYPE_NONE);
	end
end

----------------------------------------------------------------    
function OnBackButton()
	if(m_AdvancedMode) then
		Controls.CreateGameWindow:SetHide(false);
		Controls.AdvancedOptionsWindow:SetHide(true);
		Controls.LoadConfig:SetHide(true);
		Controls.SaveConfig:SetHide(true);
		Controls.ButtonStack:CalculateSize();
		
		UpdateCivLeaderToolTip();					-- Need to make sure we update our placard/flyout card if we make a change in advanced setup and then come back
		m_AdvancedMode = false;		
	else
		LuaEvents.MapSelect_ClearMapData();
		UIManager:DequeuePopup( MapSelectWindow );
		UIManager:DequeuePopup( ContextPtr );
	end
end

-- ===========================================================================
function OnLoadConfig()

	local loadGameMenu = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/LoadGameMenu" );
	local kParameters = {
		FileType = SaveFileTypes.GAME_CONFIGURATION
	};

	UIManager:QueuePopup(loadGameMenu, PopupPriority.Current, kParameters);
end

-- ===========================================================================
function OnSaveConfig()

	local saveGameMenu = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/SaveGameMenu" );
	local kParameters = {
		FileType = SaveFileTypes.GAME_CONFIGURATION
	};
    
	UIManager:QueuePopup(saveGameMenu, PopupPriority.Current, kParameters);	
end

----------------------------------------------------------------    
-- ===========================================================================
--	Handle Window Sizing
-- ===========================================================================

function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	if(screenY >= MIN_SCREEN_Y + (Controls.LogoContainer:GetSizeY() + Controls.LogoContainer:GetOffsetY() * 2)) then
		Controls.MainWindow:SetSizeY(screenY - (Controls.LogoContainer:GetSizeY() + Controls.LogoContainer:GetOffsetY() * 2));
		Controls.CreateGameWindow:SetSizeY(SCREEN_OFFSET_Y + Controls.MainWindow:GetSizeY() - (Controls.ButtonStack:GetSizeY() + Controls.LogoContainer:GetSizeY()));
		Controls.AdvancedOptionsWindow:SetSizeY(SCREEN_OFFSET_Y + Controls.MainWindow:GetSizeY() - (Controls.ButtonStack:GetSizeY() + Controls.LogoContainer:GetSizeY()));
	else
		Controls.MainWindow:SetSizeY(screenY);
		Controls.CreateGameWindow:SetSizeY(MIN_SCREEN_OFFSET_Y + Controls.MainWindow:GetSizeY() - (Controls.ButtonStack:GetSizeY()));
		Controls.AdvancedOptionsWindow:SetSizeY(MIN_SCREEN_OFFSET_Y + Controls.MainWindow:GetSizeY() - (Controls.ButtonStack:GetSizeY()));
	end
	
end

-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

-- ===========================================================================
function OnBeforeMultiplayerInviteProcessing()
	-- We're about to process a game invite.  Get off the popup stack before we accidently break the invite!
	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================
function OnShutdown()
	Events.FinishedGameplayContentConfigure.Remove(OnFinishedGameplayContentConfigure);
	Events.SystemUpdateUI.Remove( OnUpdateUI );
	Events.BeforeMultiplayerInviteProcessing.Remove( OnBeforeMultiplayerInviteProcessing );

	LuaEvents.AdvancedSetup_SetMapByHash.Remove( OnSetMapByHash );
end

-- ===========================================================================
--
-- ===========================================================================
function Initialize()

	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetHideHandler( OnHide );

	Controls.AddAIButton:RegisterCallback( Mouse.eLClick, OnAddAIButton );
	Controls.AddAIButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.AdvancedSetupButton:RegisterCallback( Mouse.eLClick, OnAdvancedSetup );
	Controls.AdvancedSetupButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.DefaultButton:RegisterCallback( Mouse.eLClick, OnDefaultButton);
	Controls.DefaultButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.StartButton:RegisterCallback( Mouse.eLClick, OnStartButton );
	Controls.StartButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnBackButton );
	Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.LoadConfig:RegisterCallback( Mouse.eLClick, OnLoadConfig );
	Controls.LoadConfig:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.SaveConfig:RegisterCallback( Mouse.eLClick, OnSaveConfig );
	Controls.SaveConfig:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.MapSelectButton:RegisterCallback( Mouse.eLClick, OnMapSelect );
	Controls.MapSelectButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	
	Events.FinishedGameplayContentConfigure.Add(OnFinishedGameplayContentConfigure);
	Events.SystemUpdateUI.Add( OnUpdateUI );
	Events.BeforeMultiplayerInviteProcessing.Add( OnBeforeMultiplayerInviteProcessing );

	LuaEvents.AdvancedSetup_SetMapByHash.Add( OnSetMapByHash );
	-- YnAMP <<<<<
	Controls.LoadDataYnAMP:RegisterCallback( Mouse.eLClick, LoadDatabase);
	Controls.LoadDataYnAMP:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	-- YnAMP >>>>>

	Resize();
end
-- YnAMP <<<<<

-- ===========================================================================
-- YnAMP settings functions
-- ===========================================================================
local bCheckModList 	= true
function ValidateSettingsYnAMP()
	if ConfigYnAMP.IsDatabaseLoaded then
		Controls.WindowTitle:SetText(Locale.Lookup("LOC_SETUP_DATABASE_LOADED_YNAMP"))
		Controls.WindowTitle:SetToolTipString(Locale.Lookup("LOC_SETUP_DATABASE_LOADED_YNAMP_TT"))
		Controls.LoadDataYnAMP:SetHide(true)
	else
		Controls.WindowTitle:SetText(Locale.Lookup("LOC_SETUP_DATABASE_NOT_LOADED_YNAMP"))
		Controls.WindowTitle:SetToolTipString(Locale.Lookup("LOC_SETUP_DATABASE_NOT_LOADED_YNAMP_TT"))
		Controls.LoadDataYnAMP:SetHide(false)
	end
	
	if ConfigYnAMP.IsDatabaseLoaded and bCheckModList then
	
		bCheckModList		= false -- don't check each time a setting is changed...
		local bFoundChange	= false
		local listMods		= {}
		local installedMods = Modding.GetInstalledMods()

		---[[
		if installedMods ~= nil then
			for i, modData in ipairs(installedMods) do
				if modData.Enabled then
					table.insert(listMods, modData)
				end
			end
		end

		print("Checking mod list...")
		for i, v in ipairs(listMods) do
			--print("Modding.GetActiveMods() :" .. Locale.Lookup(v.Name))
			if not ConfigYnAMP.ModList[v.Id] then
				print("New Mod was activated :" .. Locale.Lookup(v.Name))
				bFoundChange = true
				--ConfigYnAMP.ModList[v.Id]	= v
			end
		end
		for modID, v in pairs(ConfigYnAMP.ModList) do
			--print("ConfigYnAMP.ModList :" .. Locale.Lookup(v.Name))
			if not Modding.IsModEnabled(modID) then
				print("Previous Mod was deactivated :" .. Locale.Lookup(v.Name))
				bFoundChange = true
				--ConfigYnAMP.ModList[modID]	= nil
			end
		end
		ConfigYnAMP.IsDatabaseChanged = bFoundChange
	end
		
	if ConfigYnAMP.IsDatabaseChanged then
		print("Database may have changed...")
		Controls.WindowTitle:SetText(Locale.Lookup("LOC_SETUP_DATABASE_CHANGED_YNAMP"))
		Controls.WindowTitle:SetToolTipString(Locale.Lookup("LOC_SETUP_DATABASE_CHANGED_YNAMP_TT"))
		Controls.LoadDataYnAMP:SetHide(false)
	end
end

-- ===========================================================================
function OnGameplayContentConfigure()
	--print("Mark to check mods on FinishedGameplayContentConfigure")
	bCheckModList = true
end
Events.FinishedGameplayContentConfigure.Add(OnGameplayContentConfigure)
--GameConfigurationRebuilt
--FinishedGameplayContentChange
--FinishedGameplayContentConfigure

-- ===========================================================================
function LoadDatabase()
	print("Set and Launch a quick game to get YnAMP Data...");
	ConfigYnAMP.LoadingDatabase = true
	
	-- save config
	local saveGame 			= {}
	saveGame.Name 			= autoSaveConfigName
	saveGame.Location 		= SaveLocations.LOCAL_STORAGE
	saveGame.Type			= SaveTypes.SINGLE_PLAYER
	saveGame.FileType		= SaveFileTypes.GAME_CONFIGURATION
	saveGame.IsAutosave 	= false
	saveGame.IsQuicksave 	= false
	Network.SaveGame(saveGame)

	GameConfiguration.SetToDefaults();
	GameConfiguration.SetWorldBuilderEditor(true)
	
	GameConfiguration.SetValue("MapSize", "MAPSIZE_DUEL")
	MapConfiguration.SetScript("WorldBuilderMap.lua")
	MapConfiguration.SetValue("ScenarioType", "SCENARIO_NONE")
	GameConfiguration.SetValue("CITY_STATE_COUNT", 0)
	GameConfiguration.SetParticipatingPlayerCount(2)
	GameSetup_PlayerCountChanged()

	UI.SetWorldRenderView( WorldRenderView.VIEW_2D )
	UI.PlaySound("Set_View_2D")
	Network.HostGame(ServerType.SERVER_TYPE_NONE)
end

-- ===========================================================================
-- Mod Compatibility (not working, files are nil when reloading advanced setup as of sept 2019 patch)
-- ===========================================================================
--print("Including AdvancedSetup_* files...")
--include("AdvancedSetup_", true);


-- ===========================================================================
-- Override vanilla setting functions
-- ===========================================================================
---[[
local bMajorCountChanged				= false	-- 
OldGameSetup_RefreshParameters 			= GameSetup_RefreshParameters 
function GameSetup_RefreshParameters()

	if bFinishedGameplayContentConfigure then
		--print("Calling YnAMP GameSetup_RefreshParameters override", bUpdatePlayerCount, bMajorCountChanged)
		
		local minNumberPlayers 	= GameConfiguration.GetValue("MajorCivilizationsCount")
		bMajorCountChanged		= minNumberPlayers and minNumberPlayers ~= currentSelectedNumberMajorCivs			
		if bMajorCountChanged then
			print("Player count slider changed to "..tostring(minNumberPlayers))
			currentSelectedNumberMajorCivs = minNumberPlayers
		end
	end
	
	OldGameSetup_RefreshParameters()
	ValidateSettingsYnAMP()
end
--]]


-- ===========================================================================
function MapSize_ValueChanged(p)
	SetupParameters_Log("MAP SIZE CHANGED");

	-- The map size has changed!
	-- Adjust the number of players to match the default players of the map size.
	local results = CachedQuery("SELECT * from MapSizes where Domain = ? and MapSizeType = ? LIMIT 1", p.Value.Domain, p.Value.Value);

	local minPlayers = 2;
	local maxPlayers = 2;
	local defPlayers = 2;
	local minCityStates = 0;
	local maxCityStates = 0;
	local defCityStates = 0;

	if(results) then
		for i, v in ipairs(results) do
			minPlayers = v.MinPlayers;
			maxPlayers = v.MaxPlayers;
			defPlayers = math.max(GameConfiguration.GetParticipatingPlayerCount(), v.DefaultPlayers); --YnAMP currentSelectedNumberMajorCivs
			minCityStates = v.MinCityStates;
			maxCityStates = v.MaxCityStates;
			defCityStates = v.DefaultCityStates;
		end
	end

	MapConfiguration.SetMinMajorPlayers(minPlayers);
	MapConfiguration.SetMaxMajorPlayers(maxPlayers);
	MapConfiguration.SetMinMinorPlayers(minCityStates);
	MapConfiguration.SetMaxMinorPlayers(maxCityStates);
	GameConfiguration.SetValue("CITY_STATE_COUNT", defCityStates);
	
	-- Clamp participating player count in network multiplayer so we only ever auto-spawn players up to the supported limit. 
	local mpMaxSupportedPlayers = 8; -- The officially supported number of players in network multiplayer games.
	local participatingCount = defPlayers + GameConfiguration.GetHiddenPlayerCount();
	if GameConfiguration.IsNetworkMultiplayer() or GameConfiguration.IsPlayByCloud() then
		participatingCount = math.clamp(participatingCount, 0, mpMaxSupportedPlayers);
	end

	SetupParameters_Log("Setting participating player count to " .. tonumber(participatingCount));
	local playerCountChange = GameConfiguration.SetParticipatingPlayerCount(participatingCount);
	Network.BroadcastGameConfig(true);


	-- NOTE: This used to only be called if playerCountChange was non-zero.
	-- This needs to be called more frequently than that because each player slot entry's add/remove button
	-- needs to be potentially updated to reflect the min/max player constraints.
	if(GameSetup_PlayerCountChanged) then
		GameSetup_PlayerCountChanged();
	end
end

-- ===========================================================================
local OldGetRelevantParameters = GetRelevantParameters
function GetRelevantParameters(o, parameter)
	
	-- Hack to use parameters to determine if a Mod/DLC/Expansion is enabled
	-- 1/ Define a hidden Parameter with Name="RequireMod" and Description="REQUIRED_MOD_ID": 
	-- <Replace ParameterId="DLC2" Name="RequireMod" Description="2F6E858A-28EF-46B3-BEAC-B985E52E9BC1" Domain="bool" DefaultValue="1" ConfigurationGroup="Map" ConfigurationId="DLC2"	GroupId="MapOptions" Visible="0" SortIndex="82"/>
	-- 2/ Use it as a ParameterDependencies for your settings that require the mod to be enabled:
	-- <Replace ParameterId="LEADER_MINOR_CIV_AUCKLAND"	ConfigurationGroup="Map" ConfigurationId="DLC2" Operator="Equals" ConfigurationValue="1"/>
	-- 3/ Your hidden Parameter can have its own dependencies
	-- <Replace ParameterId="DLC2"	ConfigurationGroup="Map" ConfigurationId="SelectCityStates" Operator="NotEquals" ConfigurationValue="RANDOM"/>
	if parameter.Name == "RequireMod" and not Modding.IsModEnabled(parameter.Description) then
		return false
	end
	
	return OldGetRelevantParameters(o, parameter);
end

-- ===========================================================================
-- for player, create list on start button and fill selection using a mod selection
-- but this could be useful for preventing selection of civs without TSL when the DB is loaded
-------------------------------------------------------------------------------
SetupParameters.OldParameter_FilterValues = SetupParameters.Parameter_FilterValues
function SetupParameters:Parameter_FilterValues(parameter, values)
	values = self:OldParameter_FilterValues(parameter, values)
	
	-- Use the already filtered Leader list to build the list for random slots if the Ban Leader option is active
	if (parameter.ParameterId == "PlayerLeader" and MapConfiguration.GetValue("BanLeaders") and self.PlayerId == 0) then -- and don't update for every player slots
		--print("Building filtered Available Leader List for Random Slots...", self.PlayerId)
		local curPlayerConfig 	= PlayerConfigurations[self.PlayerId]
		local curLeadertype		= curPlayerConfig:GetLeaderTypeName()
		for i,v in ipairs(values) do
			local leaderType = v.Value
			if curLeadertype ~= leaderType and not v.Invalid then
				table.insert(filteredRandomLeaderList,leaderType)
			else
				--print(leaderType, v.InvalidReason and Locale.Lookup(v.InvalidReason) or Locale.Lookup("LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS"))
			end
		end
	end
	--[[
	if false then --(parameter.ParameterId == "PlayerLeader") then
		local unique_leaders = GameConfiguration.GetValue("NO_DUPLICATE_LEADERS");
		local unique_civilizations = GameConfiguration.GetValue("NO_DUPLICATE_CIVILIZATIONS");

		local leaders_in_use;
		local civilizations_in_use;

		local InsertIntoDuplicateBucket = function(map, key, other_key)
			local bucketA = map[key];
			local bucketB = map[other_key];

			if(bucketA == nil and bucketB == nil) then
				bucketA = {key, other_key};
				map[key] = bucketA;
				map[other_key] = bucketA;

			elseif(bucketA == nil and bucketB ~= nil) then
				table.insert(bucketB, key);
				map[key] = bucketB;

			elseif(bucketA ~= nil and bucketB == nil) then
				table.insert(bucketA, other_key);
				map[other_key] = bucketA;
			
			elseif(bucketA ~= nil and bucketB ~= nil and bucketA ~= bucketB) then
				-- consolidate buckets
				-- if A is a dupe of B and B is a dupe of C, then A is a dupe of C.
				for i,v in ipairs(bucketB) do
					table.insert(bucketA, v);
					map[v] = bucketA;
				end

			elseif(bucketA == bucketB) then
				-- buckets are same, no need to do anything since they are already dupes of each other
			end
		end;

		local duplicate_civilizations;
		if(unique_civilizations) then
			duplicate_civilizations = {};
			for i, row in ipairs(CachedQuery("SELECT CivilizationType, OtherCivilizationType from DuplicateCivilizations where Domain = ?", parameter.Domain)) do
				InsertIntoDuplicateBucket(duplicate_civilizations, row.CivilizationType, row.OtherCivilizationType);
			end
		end

		local duplicate_leaders;
		if(unique_leaders) then
			duplicate_leaders = {};
			for i, row in ipairs(CachedQuery("SELECT LeaderType, OtherLeaderType from DuplicateLeaders where Domain = ?", parameter.Domain)) do
				InsertIntoDuplicateBucket(duplicate_leaders, row.LeaderType, row.OtherLeaderType);
			end
		end

		if(unique_civilizations or unique_leaders) then

			civilizations_in_use = {};
			leaders_in_use = {};

			local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
			for i, player_id in ipairs(player_ids) do	
				if(player_id ~= self.PlayerId) then
					local playerConfig = PlayerConfigurations[player_id];
					if(playerConfig) then
						local civilization = playerConfig:GetCivilizationTypeName();
						if(type(civilization) == "string") then
							civilizations_in_use[civilization] = true;

							local dupes = duplicate_civilizations and duplicate_civilizations[civilization];
							if(dupes) then
								for i,v in ipairs(dupes) do
									civilizations_in_use[v] = true;
								end
							end 
						end

						local leader = playerConfig:GetLeaderTypeName();
						if(type(leader) == "string") then
							leaders_in_use[leader] = true;

							local dupes = duplicate_leaders and duplicate_leaders[leader];
							if(dupes) then
								for i,v in ipairs(dupes) do
									leaders_in_use[v] = true;
								end
							end 
						end
					end
				end
			end
		end

		local new_values = {};
		
		local gameInProgress = GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_PREGAME;
	
		local checkOwnership = true;
		if(GameConfiguration.IsAnyMultiplayer()) then
			local checkComputerSlots = Network.IsGameHost() and not gameInProgress;

			local curPlayerConfig = PlayerConfigurations[self.PlayerId];
			local curSlotStatus = curPlayerConfig:GetSlotStatus();
			local localPlayerId = Network.GetLocalPlayerID();
			checkOwnership = self.PlayerId == localPlayerId or (checkComputerSlots and curSlotStatus == SlotStatus.SS_COMPUTER);
		end

		for i,v in ipairs(values) do
			local reason;
			if(checkOwnership and not Modding.IsLeaderAllowed(self.PlayerId, v.Value)) then
				reason = "LOC_SETUP_ERROR_LEADER_NOT_OWNED";
			elseif(unique_leaders and leaders_in_use[v.Value]) then
				reason = "LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS";
			elseif(unique_civilizations) then
				local civilization = GetPlayerCivilization(v.Domain, v.Value);
				if(civilization and civilizations_in_use[civilization]) then
					reason = "LOC_SETUP_ERROR_NO_DUPLICATE_CIVILIZATIONS";
				end
			end

			if(reason == nil) then
				table.insert(new_values, v);
			else
				local new_value = {};

				-- Copy data from value.
				for k,v in pairs(v) do
					new_value[k] = v;
				end

				-- Mark value as invalid.
				new_value.Invalid = true;
				new_value.InvalidReason = reason;
				table.insert(new_values, new_value);
			end
		end
		return new_values;
	else
		return values;
	end
	--]]
	return values;
end


function InitializeYnAMP()
	bFinishedGameplayContentConfigure = true

	currentSelectedNumberMajorCivs = GameConfiguration.GetParticipatingPlayerCount()
	print("Initial player count =  "..tostring(currentSelectedNumberMajorCivs))
	GameConfiguration.SetValue("MajorCivilizationsCount", currentSelectedNumberMajorCivs)
	
	Events.FinishedGameplayContentConfigure.Remove(InitializeYnAMP)
end
Events.FinishedGameplayContentConfigure.Add(InitializeYnAMP)

-- YnAMP >>>>>
Initialize();