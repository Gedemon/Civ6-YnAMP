-- ===========================================================================
--	Single Player Create Game w/ Advanced Options
-- ===========================================================================
include("InstanceManager");
include("PlayerSetupLogic");
include("Civ6Common");
include("SupportFunctions");
include("PopupDialog");

-- ===========================================================================
-- ===========================================================================

-- YnAMP <<<<<
--print ("loading AdvancedSetup with include for mods... (from Yet (not) Another Maps Pack)")
print("loading AdvancedSetup for Yet (not) Another Maps Pack...")
print("Game version : ".. tostring(UI.GetAppVersion()))
ExposedMembers.ConfigYnAMP 		= ExposedMembers.ConfigYnAMP or {}
ExposedMembers.YnAMP_Loading	= ExposedMembers.YnAMP_Loading or {}
ExposedMembers.YnAMP			= { RiverMap = {}, PlayerToRemove = {}}
YnAMP_Loading 	= ExposedMembers.YnAMP_Loading
ConfigYnAMP 	= ExposedMembers.ConfigYnAMP
YnAMP			= ExposedMembers.YnAMP
------------------------------------------------------------------------------
-- YnAMP defines
------------------------------------------------------------------------------
local currentSelectedNumberMajorCivs	= 2		-- To track change to the number of selected player
local bUpdatePlayerCount				= false	-- To tell when to update player count to prevent UI lag
local bFinishedGameplayContentConfigure	= false	-- Wait before starting to check parameters for YnAMP
local autoSaveConfigName				= "AutoSaveYnAMP"
local availableLeaderList				= {}	-- List of leaders available for Random slots
local maxSupportedMapSize				= 120*62
local maxWorkingMapSize					= 140*74
local maxLoadingMapSize					= 200*104
local maxTotalPlayers					= 62	-- max is 64 but 1 slot is required for barbarian and 1 slot for free cities
local bStartDisabledByYnAMP 			= false
local bStartDisabledBySetup 			= false
--ConfigYnAMP.SavedParameter			= ConfigYnAMP.SavedParameter or {}	-- Saved values for disabled parameters
local SavedParameter					= {}	--ConfigYnAMP.SavedParameter
local cityStatesQuery					= "SELECT DISTINCT Parameters.ConfigurationId, Parameters.Name from Parameters JOIN ParameterDependencies ON Parameters.ParameterId = ParameterDependencies.ParameterId WHERE ParameterDependencies.ConfigurationId ='SelectCityStates' AND Parameters.ConfigurationId LIKE '%LEADER%'" --"SELECT * from Parameters where ConfigurationId LIKE '%LEADER_MINOR_CIV%' and GroupId='MapOptions'"
local slotStatusString					= {}
local civLevelString					= {}
SlotStatus.SS_RESERVED					= 5
for key, v in pairs(SlotStatus) do
	slotStatusString[v] = key
end
for key, v in pairs(CivilizationLevelTypes) do
	civLevelString[v] = key
end

-- There must be a cleaner way to get that...
local RulesetPlayerDomain	= {
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
	["MAPSIZE_LUDICROUS"] 	= {Width = 200,	Height = 104, Size = 200* 104},
	["MAPSIZE_OVERSIZED"] 	= {Width = 230,	Height = 115, Size = 230* 116}
}

-- GetMapSize returns Hash, I don't speak Hash, so build a translation table
-- And get a cached table with MapSizes sorted by size while we're here...
local MapSizeTypesFromHash 	= {}
local SortedMapSize 		= {}
for mapSizeType, row in pairs(ConfigYnAMP.MapSizes) do
	MapSizeTypesFromHash[DB.MakeHash(mapSizeType)] = mapSizeType
	table.insert(SortedMapSize, {MapSizeType = mapSizeType, Width = row.Width,	Height = row.Height, Size = row.Size})
end
table.sort(SortedMapSize, function(a, b) return a.Size > b.Size; end)

-- Cache maps size names
local MapSizeNames	= {}
for i, row in ipairs(CachedQuery("SELECT MapSizeType, Name from MapSizes")) do
	MapSizeNames[row.MapSizeType] = row.Name
end

-- For whatever reasons, changing the "CityStates" SortIndex in the config database with XML is not working for this screen
-- The value in the DB is correctly updated, but the value in the Parameter table is always 230 (even when changing it in the base game files)
-- So we cache the DB value here and affect it manually when the parameters are checked
local CityStatesSortIndex = 230 -- default value
do
	local query		= "SELECT SortIndex from Parameters WHERE ParameterId = ?"
	local results	= DB.ConfigurationQuery(query, "CityStates")

	if results then
		CityStatesSortIndex = results[1].SortIndex
		print("City States Parameter <SortIndex> value in DB is ", CityStatesSortIndex)
	end
end

-- Add known CS to config DB		
-- and get civilization types for each CS leaders
local LeadersCivilizations = {}
if ConfigYnAMP.CityStatesList then

	print("Check City States Selection list after Loading GamePlay DB...")
	local IsAvailable = {}

	-- Add CS imported from GamePlay DB to the config DB
	for i, row in ipairs(ConfigYnAMP.CityStatesList) do
		local LeaderType 						= row.LeaderType
		local CivilizationType					= row.CivilizationType
		local LeaderName 						= (Locale.Lookup(row.LeaderName) ~= row.LeaderName) and row.LeaderName or row.LocalizedLeaderName -- If there is a Config Localization use it, else use the imported GamePlay Localization
		local CivilizationName 					= (Locale.Lookup(row.CivilizationName) ~= row.CivilizationName) and row.CivilizationName or row.LocalizedCivilizationName
		LeadersCivilizations[LeaderType] 		= CivilizationType
		LeadersCivilizations[CivilizationType] 	= LeaderType
		IsAvailable[LeaderType]	= true
	
		--[[
		local query		= "SELECT * FROM Parameters WHERE ConfigurationId = ?"
		local results	= DB.ConfigurationQuery(query, LeaderType)
		
		if results and #results == 0 then
			print("- Adding new City State leader to YnAMP Selection List: ", LeaderType)
			query = "INSERT INTO Parameters (ParameterId, Name, Description, Domain, DefaultValue, ConfigurationGroup, ConfigurationId, GroupId, SortIndex) VALUES (?, ?, ?, 'bool', 0, 'Map', ?, 'MapOptions', 99)"
			DB.ConfigurationQuery(query, LeaderType, LeaderName, CivilizationName, LeaderType)
			
			query = "INSERT INTO ParameterDependencies (ParameterId, ConfigurationGroup, ConfigurationId, Operator, ConfigurationValue) VALUES (?, 'Map', 'SelectCityStates', 'NotEquals', 'RANDOM')"
			DB.ConfigurationQuery(query, LeaderType)
			
			query = "INSERT INTO ParameterDependencies (ParameterId, ConfigurationGroup, ConfigurationId, Operator, ConfigurationValue) VALUES (?, 'Map', 'SelectCityStates', 'NotEquals', NULL)"
			DB.ConfigurationQuery(query, LeaderType)
		end
		--]]
		
		--[[
		-- the code below doesn't seem to update the parameters or the debug config DB
		-- but reloading this file shows that the entry is added in the <CityStates> table linked to that query
		-- the code above was updating parameters
		-- maybe look at calls to CachedQuery vs DB.ConfigurationQuery ?
		-- disabling for now
		
		local query		= "SELECT * FROM CityStates WHERE CivilizationType = ?"
		local results	= DB.ConfigurationQuery(query, CivilizationType)
		
		if results and #results == 0 then
			print("- Adding new City State Civilization to the CS Picker Screen List: ", LeaderType)
			local query = "INSERT INTO CityStates (CivilizationType, Name, Icon, CityStateCategory, Bonus) VALUES (?, ?, 'test_icon', 'test_cs_category', 'test_bonus')"
			DB.ConfigurationQuery(query, CivilizationType, CivilizationName)
		end
		--]]
	end
	
end

-- Remove CS missing in GamePlay DB from the Config DB
local query		= cityStatesQuery
local results	= DB.ConfigurationQuery(query)
if results and #results > 0 then
	for i, row in ipairs(results) do
		print("- Cleaning City State Leader from deprecated Selection List: ", row.ConfigurationId)
		DB.ConfigurationQuery("DELETE FROM Parameters WHERE ConfigurationId = ? ", row.ConfigurationId)
	end
end

-- Build TSL table if available
local TSL = {}
if ConfigYnAMP.TSL then
	for i, row in ipairs(ConfigYnAMP.TSL) do
		local mapName 		= row.MapName
			if mapName then
			local civilization 	= row.Civilization
			local leader 		= row.Leader
			TSL[mapName] 		= TSL[mapName] or {}
			local mapTSL		= TSL[mapName]
			if civilization then
				mapTSL[civilization] = mapTSL[civilization] or {}
				table.insert(mapTSL[civilization], {X = row.X, Y = row.Y})
			end
			if leader then
				mapTSL[leader] = mapTSL[leader] or {}
				table.insert(mapTSL[leader], {X = row.X, Y = row.Y})
			end
		end
	end
end

---[[
-- helper table to check if a value is a leader type
local IsLeaderType = {}
for i, row in ipairs(CachedQuery("SELECT LeaderType from Players")) do
	IsLeaderType[row.LeaderType] = true
end

-- helper table to check if a value is a minor leader type
local IsMinorLeaderType = {}
local duplicateMinor	= {}
for i, row in ipairs(CachedQuery(cityStatesQuery)) do
	IsMinorLeaderType[row.ConfigurationId] = true
end
--]]

-- Build mod list
local listMods		= {}
local IsActiveMod	= {}
local installedMods = Modding.GetInstalledMods()

if installedMods ~= nil then
	for i, modData in ipairs(installedMods) do
		if modData.Enabled then
			table.insert(listMods, modData)
		end
	end
end

for i, v in ipairs(listMods) do
	IsActiveMod[v.Id] = v
end

------------------------------------------------------------------------------
-- Formating
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
-- YnAMP Math functions
------------------------------------------------------------------------------
function GetShuffledCopyOfTable(incoming_table)
	-- Designed to operate on tables with no gaps. Does not affect original table.
	local len = table.maxn(incoming_table);
	local copy = {};
	local shuffledVersion = {};
	local seed = MapConfiguration.GetValue("RANDOM_SEED") -- passing the same table will give the same result.
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

-- ===========================================================================
-- ===========================================================================

local PULLDOWN_TRUNCATE_OFFSET:number = 40;

local MIN_SCREEN_Y			:number = 768;
local SCREEN_OFFSET_Y		:number = 61;
local MIN_SCREEN_OFFSET_Y	:number = -53;

local MAX_SIDEBAR_Y			:number = 960;

-- ===========================================================================
-- ===========================================================================

-- Instance managers for dynamic simple game options.
g_SimpleBooleanParameterManager = InstanceManager:new("SimpleBooleanParameterInstance", "CheckBox", Controls.CheckBoxParent);
g_SimpleGameModeParameterManager = InstanceManager:new("GameModeSelectorInstance", "Top", Controls.CheckBoxParent);
g_SimplePullDownParameterManager = InstanceManager:new("SimplePullDownParameterInstance", "Root", Controls.PullDownParent);
g_SimpleSliderParameterManager = InstanceManager:new("SimpleSliderParameterInstance", "Root", Controls.SliderParent);
g_SimpleStringParameterManager = InstanceManager:new("SimpleStringParameterInstance", "Root", Controls.EditBoxParent);

-- Instance managers for Game Mode placard and details flyouts
local m_gameModeToolTipHeaderIM = InstanceManager:new("HeaderInstance", "Top", Controls.GameModeInfoStack );
local m_gameModeToolTipHeaderIconIM = InstanceManager:new("IconInstance", "Top", Controls.GameModeInfoStack );

g_kMapData = {};	-- Global set of map data; enough for map selection context to do it's thing. (Parameter list still truly owns the data.)

local m_NonLocalPlayerSlotManager	:table = InstanceManager:new("NonLocalPlayerSlotInstance", "Root", Controls.NonLocalPlayersSlotStack);
local m_singlePlayerID				:number = 0;			-- The player ID of the human player in singleplayer.
local m_AdvancedMode				:boolean = false;
local m_RulesetData					:table = {};
local m_BasicTooltipData			:table = {};
local m_WorldBuilderImport          :boolean = false;

local m_pCityStateWarningPopup:table = PopupDialog:new("CityStateWarningPopup");

-- ===========================================================================
-- Override hiding game setup to release simplified instances.
-- ===========================================================================
GameSetup_HideGameSetup = HideGameSetup;
function HideGameSetup(func)
	GameSetup_HideGameSetup(func);
	g_SimpleBooleanParameterManager:ResetInstances();
	g_SimpleGameModeParameterManager:ResetInstances();
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

local _UI_AfterRefresh = GameParameters_UI_AfterRefresh;
function GameParameters_UI_AfterRefresh(o)
	
	if(_UI_AfterRefresh) then
		_UI_AfterRefresh(o);
	end
	
	-- All parameters are provided with a sort index and are manipulated
	-- in that particular order.
	-- However, destroying and re-creating parameters can get expensive
	-- and thus is avoided.  Because of this, some parameters may be 
	-- created in a bad order.  
	-- It is up to this function to ensure order is maintained as well
	-- as refresh/resize any containers.
	-- FYI: Because of the way we're sorting, we need to delete instances
	-- rather than release them.  This is because releasing merely hides it
	-- but it still gets thrown in for sorting, which is frustrating.
	local sort = function(a,b)
	
		-- ForgUI requires a strict weak ordering sort.
		local ap = g_SortingMap[tostring(a)];
		local bp = g_SortingMap[tostring(b)];

		if(ap == nil and bp ~= nil) then
			return true;
		elseif(ap == nil and bp == nil) then
			return tostring(a) < tostring(b);
		elseif(ap ~= nil and bp == nil) then
			return false;
		else
			return o.Utility_SortFunction(ap, bp);
		end
	end

	local stacks = {};
	table.insert(stacks, Controls.CreateGame_ExtraParametersStack);
	table.insert(stacks, Controls.CreateGame_GameModeParametersStack);

	for i,v in ipairs(stacks) do
		v:SortChildren(sort);
	end

	for i,v in ipairs(stacks) do
		v:CalculateSize();
		v:ReprocessAnchoring();
	end
	   
	Controls.CreateGameOptions:CalculateSize();
	Controls.CreateGameOptions:ReprocessAnchoring();

	if Controls.CreateGame_ParametersScrollPanel then
		Controls.CreateGame_ParametersScrollPanel:CalculateInternalSize();
	end

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
--	To receive choice:	LuaEvents.MapSelect_SetMapByValue( value );
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
--	Called from the MapSelect popup for what map was selected.
--	value	the map to set for the game.
-- ===========================================================================
function OnSetMapByValue( value: string )
	local kParameters	:table = g_GameParameters["Parameters"];
	local kMapParameters:table = kParameters["Map"];
	local kMapCollection:table = kMapParameters.Values;
	local isFound		:boolean = false;
	for i,kMapData in ipairs( kMapCollection ) do
		if kMapData.Value == value then
			g_GameParameters:SetParameterValue(kMapParameters, kMapData);
			Network.BroadcastGameConfig();			
			isFound = true;
			break;	
		end
	end
	if (not isFound) then
		UI.DataError("Unable to set the game's map to a map with the value '"..tostring(value).."'");
	end
end

function OnSetParameterValues(pid: string, values: table)
	local indexed_values = {};
	if(values) then
		for i,v in ipairs(values) do
			indexed_values[v] = true;
		end
	end

	if(g_GameParameters) then
		local kParameter: table = g_GameParameters.Parameters and g_GameParameters.Parameters[pid] or nil;
		if(kParameter and kParameter.Values ~= nil) then
			local resolved_values = {};
			for i,v in ipairs(kParameter.Values) do
				if(indexed_values[v.Value]) then
					table.insert(resolved_values, v);
				end
			end		
			g_GameParameters:SetParameterValue(kParameter, resolved_values);
			Network.BroadcastGameConfig();	
		end
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
			local button = c:GetButton();
			if(cache.ValueText ~= valueText or cache.ValueDescription ~= valueDescription) then
				local truncateWidth = button:GetSizeX() - PULLDOWN_TRUNCATE_OFFSET;
				TruncateStringWithTooltip(button, truncateWidth, valueText);
				cache.ValueText = valueText;
			end		
			button:LocalizeAndSetToolTip(value.RawDescription);
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
-- This driver is for launching a multi-select option in a separate window.
-- ===========================================================================
function CreateMultiSelectWindowDriver(o, parameter, parent)

	if(parent == nil) then
		parent = GetControlStack(parameter.GroupId);
	end
			
	-- Get the UI instance
	local c :object = g_ButtonParameterManager:GetInstance();	

	local parameterId = parameter.ParameterId;
	local button = c.Button;
	button:RegisterCallback( Mouse.eLClick, function()
		LuaEvents.MultiSelectWindow_Initialize(o.Parameters[parameterId]);
		Controls.MultiSelectWindow:SetHide(false);
	end);
	button:SetToolTipString(parameter.Description);

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
		UpdateValue = function(value, p)
			local valueText = value and value.Name or nil;
			local valueAmount :number = 0;
		
			if(valueText == nil) then
				if(value == nil) then
					if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
						valueText = "LOC_SELECTION_EVERYTHING";
					else
						valueText = "LOC_SELECTION_NOTHING";
					end
				elseif(type(value) == "table") then
					local count = #value;
					if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
						if(count == 0) then
							valueText = "LOC_SELECTION_EVERYTHING";
						elseif(count == #p.Values) then
							valueText = "LOC_SELECTION_NOTHING";
						else
							valueText = "LOC_SELECTION_CUSTOM";
							valueAmount = #p.Values - count;
						end
					else
						if(count == 0) then
							valueText = "LOC_SELECTION_NOTHING";
						elseif(count == #p.Values) then
							valueText = "LOC_SELECTION_EVERYTHING";
						else
							valueText = "LOC_SELECTION_CUSTOM";
							valueAmount = count;
						end
					end
				end
			end				

			if(cache.ValueText ~= valueText) or (cache.ValueAmount ~= valueAmount) then
				local button = c.Button;			
				button:LocalizeAndSetText(valueText, valueAmount);
				cache.ValueText = valueText;
				cache.ValueAmount = valueAmount;
			end
		end,
		UpdateValues = function(values, p) 
			-- Values are refreshed when the window is open.
		end,
		SetEnabled = function(enabled, p)
			c.Button:SetDisabled(not enabled or #p.Values <= 1);
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
-- This driver is for launching the city-state picker in a separate window.
-- ===========================================================================
function CreateCityStatePickerDriver(o, parameter, parent)

	if(parent == nil) then
		parent = GetControlStack(parameter.GroupId);
	end
			
	-- Get the UI instance
	local c :object = g_ButtonParameterManager:GetInstance();	

	local parameterId = parameter.ParameterId;
	local button = c.Button;
	button:RegisterCallback( Mouse.eLClick, function()
		LuaEvents.CityStatePicker_Initialize(o.Parameters[parameterId], g_GameParameters);
		Controls.CityStatePicker:SetHide(false);
	end);
	button:SetToolTipString(parameter.Description);

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
		UpdateValue = function(value, p)
			local valueText = value and value.Name or nil;
			local valueAmount :number = 0;
		
			if(valueText == nil) then
				if(value == nil) then
					if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
						valueText = "LOC_SELECTION_EVERYTHING";
					else
						valueText = "LOC_SELECTION_NOTHING";
					end
				elseif(type(value) == "table") then
					local count = #value;
					if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
						if(count == 0) then
							valueText = "LOC_SELECTION_EVERYTHING";
						elseif(count == #p.Values) then
							valueText = "LOC_SELECTION_NOTHING";
						else
							valueText = "LOC_SELECTION_CUSTOM";
							valueAmount = #p.Values - count;
						end
					else
						if(count == 0) then
							valueText = "LOC_SELECTION_NOTHING";
						elseif(count == #p.Values) then
							valueText = "LOC_SELECTION_EVERYTHING";
						else
							valueText = "LOC_SELECTION_CUSTOM";
							valueAmount = count;
						end
					end
				end
			end				

			if(cache.ValueText ~= valueText) or (cache.ValueAmount ~= valueAmount) then
				local button = c.Button;			
				button:LocalizeAndSetText(valueText, valueAmount);
				cache.ValueText = valueText;
				cache.ValueAmount = valueAmount;
			end
		end,
		UpdateValues = function(values, p) 
			-- Values are refreshed when the window is open.
		end,
		SetEnabled = function(enabled, p)
			c.Button:SetDisabled(not enabled or #p.Values <= 1);
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
-- This driver is for launching the leader picker in a separate window.
-- ===========================================================================
function CreateLeaderPickerDriver(o, parameter, parent)

	if(parent == nil) then
		parent = GetControlStack(parameter.GroupId);
	end
			
	-- Get the UI instance
	local c :object = g_ButtonParameterManager:GetInstance();	

	local parameterId = parameter.ParameterId;
	local button = c.Button;
	button:RegisterCallback( Mouse.eLClick, function()
		LuaEvents.LeaderPicker_Initialize(o.Parameters[parameterId], g_GameParameters);
		Controls.LeaderPicker:SetHide(false);
	end);
	button:SetToolTipString(parameter.Description);

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
		UpdateValue = function(value, p)
			local valueText = value and value.Name or nil;
			local valueAmount :number = 0;

			-- Remove random leaders from the Values table that is used to determine number of leaders selected
			for i = #p.Values, 1, -1 do
				local kItem:table = p.Values[i];
				if kItem.Value == "RANDOM" or kItem.Value == "RANDOM_POOL1" or kItem.Value == "RANDOM_POOL2" then
					table.remove(p.Values, i);
				end
			end
		
			if(valueText == nil) then
				if(value == nil) then
					if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
						valueText = "LOC_SELECTION_EVERYTHING";
					else
						valueText = "LOC_SELECTION_NOTHING";
					end
				elseif(type(value) == "table") then
					local count = #value;
					if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
						if(count == 0) then
							valueText = "LOC_SELECTION_EVERYTHING";
						elseif(count == #p.Values) then
							valueText = "LOC_SELECTION_NOTHING";
						else
							valueText = "LOC_SELECTION_CUSTOM";
							valueAmount = #p.Values - count;
						end
					else
						if(count == 0) then
							valueText = "LOC_SELECTION_NOTHING";
						elseif(count == #p.Values) then
							valueText = "LOC_SELECTION_EVERYTHING";
						else
							valueText = "LOC_SELECTION_CUSTOM";
							valueAmount = count;
						end
					end
				end
			end				

			if(cache.ValueText ~= valueText) or (cache.ValueAmount ~= valueAmount) then
				local button = c.Button;			
				button:LocalizeAndSetText(valueText, valueAmount);
				cache.ValueText = valueText;
				cache.ValueAmount = valueAmount;
			end
		end,
		UpdateValues = function(values, p) 
			-- Values are refreshed when the window is open.
		end,
		SetEnabled = function(enabled, p)
			c.Button:SetDisabled(not enabled or #p.Values <= 1);
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
	table.insert(drivers, GameParameters_UI_CreateParameterDriver(o, parameter));

	return drivers;
end
g_ParameterFactories["GameDifficulty"] = function(o, parameter)

	local drivers = {};
	-- Basic setup version.
	-- Use an explicit table.
	table.insert(drivers, CreatePulldownDriver(o, parameter, Controls.CreateGame_GameDifficulty, Controls.CreateGame_GameDifficultyContainer));

	-- Advanced setup version.
	-- Create the parameter dynamically like we normally would...
	table.insert(drivers, GameParameters_UI_CreateParameterDriver(o, parameter));

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
	table.insert(drivers, GameParameters_UI_CreateParameterDriver(o, parameter));

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
	-- Restore pulldown menu for map selection
--for k, v in pairs(parameter) do print(k, v) end
	if parameter.SortIndex then
		parameter.SortIndex = parameter.SortIndex + 1
	end
		table.insert(drivers, GameParameters_UI_CreateParameterDriver(o, parameter));
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
	table.insert(drivers, GameParameters_UI_CreateParameterDriver(o, parameter));

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

	if(parameter.GroupId == "GameModes") then
		local c = g_SimpleGameModeParameterManager:GetInstance();	
		
		-- Store the root control, NOT the instance table.
		g_SortingMap[tostring(c.Top)] = parameter;		
		
		local name = Locale.ToUpper(parameter.Name);
		c.CheckBox:RegisterCallback(Mouse.eLClick, function()
			o:SetParameterValue(parameter, not c.CheckBox:IsSelected());
			Network.BroadcastGameConfig();
		end);	
		c.GameModeIcon:SetIcon("ICON_" .. parameter.ParameterId);
		c.Top:ChangeParent(parent);

		control = {
			UpdateValue = function(value, parameter)
				c.CheckBox:SetSelected(value);
			end,
			Control = c,
			SetEnabled = function(enabled)
				c.CheckBox:SetDisabled(not enabled);
			end,
			SetVisible = function(visible)
				c.CheckBox:SetHide(not visible);
			end,
			Destroy = function()
				g_SimpleGameModeParameterManager:ReleaseInstance(c);
			end,
		};
		c.CheckBox:RegisterCallback( Mouse.eMouseEnter, function() OnGameModeMouseEnter(parameter) end);
		c.CheckBox:RegisterCallback( Mouse.eMouseExit, function() OnGameModeMouseExit(parameter) end);

		if(Controls.NoGameModesContainer:IsHidden() == false)then
			Controls.NoGameModesContainer:SetHide(true);
		end

	elseif(parameter.Domain == "bool") then
		local c = g_SimpleBooleanParameterManager:GetInstance();	
		
		-- Store the root control, NOT the instance table.
		g_SortingMap[tostring(c.CheckBox)] = parameter;		
		
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

		-- Store the root control, NOT the instance table.
		g_SortingMap[tostring(c.Root)] = parameter;
		
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
		
		-- Store the root control, NOT the instance table.
		g_SortingMap[tostring(c.Root)] = parameter;
		
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
		
		-- Store the root control, NOT the instance table.
		g_SortingMap[tostring(c.Root)] = parameter;

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

function GameParameters_UI_CreateParameterDriver(o, parameter, ...)

	if(parameter.ParameterId == "CityStates") then
		if GameConfiguration.IsWorldBuilderEditor() then
			-- return nil; -- YnAMP
		end
		return CreateCityStatePickerDriver(o, parameter);
	elseif(parameter.ParameterId == "LeaderPool1" or parameter.ParameterId == "LeaderPool2") then
		if GameConfiguration.IsWorldBuilderEditor() then
			return nil;
		end
		return CreateLeaderPickerDriver(o, parameter);
	elseif(parameter.Array) then
		return CreateMultiSelectWindowDriver(o, parameter);
	else
		return GameParameters_UI_DefaultCreateParameterDriver(o, parameter, ...);
	end
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
			GameParameters_UI_CreateParameterDriver(o, parameter)
		};
	elseif(parameter.GroupId == "GameModes") then	
		control = {
			CreateSimpleParameterDriver(o, parameter, Controls.CreateGame_GameModeParametersStack),
			GameParameters_UI_CreateParameterDriver(o, parameter)
		};	
	else
		control = GameParameters_UI_CreateParameterDriver(o, parameter);
	end

	o.Controls[parameter.ParameterId] = control;
end

-- ===========================================================================
-- Remove player handler.
function RemovePlayer(voidValue1, voidValue2, control)
	print("Removing Player " .. tonumber(voidValue1));
	local playerConfig = PlayerConfigurations[voidValue1];
	playerConfig:SetLeaderTypeName(nil);
	
	GameConfiguration.RemovePlayer(voidValue1);

	-- YnAMP <<<<<
	local nextNumPlayer = GameConfiguration.GetParticipatingPlayerCount()
	if currentSelectedNumberMajorCivs > nextNumPlayer then
		currentSelectedNumberMajorCivs 	= nextNumPlayer
		GameConfiguration.SetValue("MajorCivilizationsCount", currentSelectedNumberMajorCivs)
		GameConfiguration.SetParticipatingPlayerCount(currentSelectedNumberMajorCivs)
	elseif currentSelectedNumberMajorCivs < nextNumPlayer then
		GameConfiguration.SetValue("MajorCivilizationsCount", currentSelectedNumberMajorCivs)
		GameConfiguration.SetParticipatingPlayerCount(currentSelectedNumberMajorCivs)
	end
	-- YnAMP >>>>>

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
			SetupLeaderPulldown(player_id, Controls, "Basic_LocalPlayerPulldown", "Basic_LocalPlayerCivIcon",  "Basic_LocalPlayerCivIconBG", "Basic_LocalPlayerLeaderIcon", "Basic_LocalPlayerScrollText", m_BasicTooltipData);
			SetupLeaderPulldown(player_id, Controls, "Advanced_LocalPlayerPulldown", "Advanced_LocalPlayerCivIcon", "Advanced_LocalPlayerCivIconBG", "Advanced_LocalPlayerLeaderIcon", "Advanced_LocalPlayerScrollText", advancedTooltipData, "Advanced_LocalColorPullDown");
		else
			local ui_instance = m_NonLocalPlayerSlotManager:GetInstance();
			
			-- Assign the Remove handler
			if(can_remove) then
				ui_instance.RemoveButton:SetVoid1(player_id);
				ui_instance.RemoveButton:RegisterCallback(Mouse.eLClick, RemovePlayer);
			end
			ui_instance.RemoveButton:SetHide(not can_remove);
			
			SetupLeaderPulldown(player_id, ui_instance,"PlayerPullDown",nil,nil,nil,nil,advancedTooltipData);
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
	-- YnAMP <<<<<
	bStartDisabledBySetup = false
	if not bStartDisabledByYnAMP then
	-- YnAMP >>>>>
	-- This is primarily used to present ownership errors and custom constraint errors.
	Controls.StartButton:SetDisabled(false);
	Controls.StartButton:SetToolTipString(nil);
	-- YnAMP <<<<<
	end
	-- YnAMP >>>>>

	local game_err = GetGameParametersError();
	if(game_err) then
		Controls.StartButton:SetDisabled(true);
		Controls.StartButton:LocalizeAndSetToolTip("LOC_SETUP_PARAMETER_ERROR");
		-- YnAMP <<<<<
		print("GetGameParametersError = ",game_err)
		if type(game_err)=="table" then for k, v in pairs(game_err) do print("   - ", k, v) end end
		bStartDisabledBySetup = true
		-- YnAMP >>>>>
	end
	
	local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
	for i, player_id in ipairs(player_ids) do	
		local err = GetPlayerParameterError(player_id);
		if(err) then
			Controls.StartButton:SetDisabled(true);
			Controls.StartButton:LocalizeAndSetToolTip("LOC_SETUP_PLAYER_PARAMETER_ERROR");
			Controls.ConflictPopup:SetHide(false);
			-- YnAMP <<<<<
			print("GetPlayerParameterError = ", err)
			if type(err)=="table" then for k, v in pairs(err) do print("   - ", k, v) end end
			bStartDisabledBySetup = true
			-- YnAMP >>>>>
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
	-- YnAMP <<<<<
	-- code below may be a bit intrusive (auto-reduce the number of CS selected)
	-- added text to tooltip about the 62 player limit
	-- maybe better to add a warning or a popup on clicking start when numCS > maxCS
	--[[
	local player_ids 	= GameConfiguration.GetParticipatingPlayerIDs();
	local numPlayers 	= #player_ids
	local numCS			= GameConfiguration.GetValue("CITY_STATE_COUNT") or 0
	local maxCS 		= maxTotalPlayers - numPlayers
	
	if numCS > maxCS then
		--MapConfiguration.SetMaxMinorPlayers(maxCS) -- this doesn't seems to update the slider 
		GameConfiguration.SetValue("CITY_STATE_COUNT", maxCS);
	end
	-- YnAMP >>>>>
	--]]
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
	
	--AutoSizeGridButton(Controls.IgnoreWarning,133,36,15,"H");
	--local offsetX = Controls.DefaultButton:GetSizeX()
	--Controls.IgnoreWarning:SetOffsetX(offsetX)
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
	
	-- We can't have a nil Map Seed for the random selections
	if not MapConfiguration.GetValue("RANDOM_SEED") then
		local gameSeed = GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED")
		GameConfiguration.RegenerateSeeds()
		if gameSeed then
			GameConfiguration.SetValue("GAME_SYNC_RANDOM_SEED", gameSeed)
		end
	end
	
	-- hide the player section first to not show the mod selection for random slots
	Controls.PlayersSection:SetHide(true)
	
	-- output the last validation report to the log
	print(Controls.WindowTitle:GetToolTipString())
	---[[
	local player_ids 	= GameConfiguration.GetParticipatingPlayerIDs();
	local numPlayers 	= #player_ids
	local numCS			= GameConfiguration.GetValue("CITY_STATE_COUNT")
	local newNumCS		= numCS
	local cityStateID	= 0 			-- Player slots IDs start at 0, Human is 0, so we should start at 1, but start at 0 in case some mod (spectator ?) change that
	local maxCS 		= maxTotalPlayers - numPlayers
	local bSelectCS		= MapConfiguration.GetValue("SelectCityStates") ~= "RANDOM"
	local bBanListCS	= MapConfiguration.GetValue("SelectCityStates") == "EXCLUSION"
	local bBanLeaders	= MapConfiguration.GetValue("BanLeaders")
	local bOnlyTSL		= MapConfiguration.GetValue("OnlyLeadersWithTSL")
	local ruleset		= GameConfiguration.GetValue("RULESET")
	local playerDomain	= ruleset and RulesetPlayerDomain[ruleset] or "Players:StandardPlayers"
	local bBarbarians	= GameConfiguration.GetValue("GAMEMODE_BARBARIAN_CLANS")
	
	local ruleset = GameConfiguration.GetValue("RULESET")
	print("Active Ruleset = ", ruleset)
	print("Player Domain = ", playerDomain)
	
	-- Limit number of players for R&F and GS
	print("------------------------------------------------------")
	print("YnAMP checking for number of players limit on Start...")
	print("num. players = ".. tostring(numPlayers) .. ", num. CS = ".. tostring(numCS), ", Selection type = ", MapConfiguration.GetValue("SelectCityStates"), ", Do selection =", bSelectCS)
	if (GameConfiguration.GetValue("RULESET") == "RULESET_EXPANSION_1" or GameConfiguration.GetValue("RULESET") == "RULESET_EXPANSION_2") and numPlayers + numCS > maxTotalPlayers then
		newNumCS = maxCS
		print("new num. CS = ".. tostring(newNumCS))
		GameConfiguration.SetValue("CITY_STATE_COUNT", newNumCS)
	end
	
	if true then --bBanLeaders then -- I prefer the randomization of this function over the Core method (less duplicates when allowed, no duplicate when not), so make it default.
		print("------------------------------------------------------")
		print("Getting Leaders for Random slots...")
		
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
			
			local filteredRandomLeaderList = {}
			for leaderType, bValid in pairs(availableLeaderList) do
				bValid = bValid and #CachedQuery("SELECT LeaderType from Players WHERE Domain = ? AND LeaderType = ?", playerDomain, leaderType)>0
				if bValid then
					table.insert(filteredRandomLeaderList, leaderType)
				end
			end
			
			table.sort(filteredRandomLeaderList) 
			
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
				local bNoDupeLeaders 	= unique_leaders or (not bSecondLoop) 		-- avoid duplicate leaders on first loop, even if allowed
				local bNoDupeCivs 		= unique_civilizations or (not bSecondLoop) -- avoid duplicate civs on first loop, even if allowed
				while(leaderType) do
					if not MapConfiguration.GetValue(leaderType) then -- this leaderType is not banned
						if (not IsUsedLeader[leaderType]) or (not bNoDupeLeaders) then
							local civilizationType = GetPlayerCivilization(leaderType)
							if civilizationType then
								if (not IsUsedCiv[civilizationType]) or (not bNoDupeCivs) then
									MarkUsedCiv(civilizationType)
									MarkUsedLeader(leaderType)
									listIndex 	= listIndex + 1
									return leaderType
								else
									--print(" - Can't use leader because of duplicate Civilization : ", leaderType, civilizationType)
								end
							else
								--print(" - WARNING: can't find civilizationType for : ", leaderType)
							end
						else
							--print(" - Can't use duplicate leader : ", leaderType)
						end
					else
						--print(" - Can't use banned leader : ", leaderType)
					end
					listIndex 	= listIndex + 1
					leaderType 	= shuffledList[listIndex]
				end
				if not bSecondLoop then -- in case duplicates are allowed
					print(" - Can't find next leader, trying second loop")
					shuffledList = GetShuffledCopyOfTable(shuffledList)
					listIndex = 1
					if not unique_leaders then
						IsUsedLeader = {}
					end
					if not unique_civilizations then
						IsUsedCiv = {}
					end
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
	if (bSelectCS or bOnlyTSL) and (not ConfigYnAMP.IsDatabaseChanged) then
		print("------------------------------------------------------")
		print("Generate available slots list for CS...")
		local CityStatesSlotsList	= {}
		while(cityStateID < maxTotalPlayers) do
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
		local query		= cityStatesQuery
		local results	= DB.ConfigurationQuery(query)
		
		-- Get the data from the CS picker if it exists 
		local kParameters:table = g_GameParameters["Parameters"]
		local bUsePickerList	= false
		local pickerNotSelected	= {}
		
		local function GetLeaderNameTypeFromCivType(civTypeName)
			return "LEADER_MINOR_CIV_" .. string.gsub( civTypeName, "CIVILIZATION_", "")
		end
		
		if kParameters["CityStates"] then
		
			print("Using Picker Screen List")
			
			bUsePickerList 		= true
			local tempTable		= {}
			local notSelected 	= kParameters["CityStates"].Value or {}		-- this is the list of unchecked CS in kParameters["CityStates"] from the picker screen, it can be nil
			local allList		= kParameters["CityStates"].Values or {}	-- this is the list of all CS in kParameters["CityStates"] from the picker screen
			
			for _, data in ipairs(notSelected) do 
				local leaderType = GetLeaderNameTypeFromCivType(data.Value)
				pickerNotSelected[leaderType] = true
			end
			
			for _, data in ipairs(allList) do 
				local leaderType = GetLeaderNameTypeFromCivType(data.Value)
				table.insert(tempTable, { ConfigurationId = leaderType, Name = data.RawName })
			end
			results = tempTable
		
		end
		
		
		local function IsSelected(leaderType)
			if bUsePickerList then
				return pickerNotSelected[leaderType] ~= true -- there is no direct check for selected CS in the picker screen, so we check vs the opposite
			else
				return MapConfiguration.GetValue(leaderType) == true -- true if this CS was checked
			end
		end
		
		if(results and #results > 0) then
		
			local filteredList 	= {}
			local duplicate		= {}
			local mapName		= MapConfiguration.GetValue("MapName")
			for i, row in ipairs(results) do
				local leaderType 	= row.ConfigurationId
				local bValid		= true
				
				if bBanListCS then -- first check if the selection list is in "exclusion" mode
					if IsSelected(leaderType) then
						bValid = false
					end
				end
				
				if bValid and bOnlyTSL then -- filter CS list by TSL
					local args				= {}
					args.leaderType			= leaderType
					args.civilizationType	= LeadersCivilizations[leaderType]
					args.mapName			= mapName
					if not HasTSL(args) then--(leaderType, mapName, playerDomain, civilizationType)
						bValid = false
					end
				end
				
				if bValid and not duplicate[leaderType] then
					duplicate[leaderType] = true
					--print("- adding to filtered list : ", leaderType)
					table.insert(filteredList, {ConfigurationId = leaderType, Name = row.Name})
				end
			end
		
			local bCapped			= MapConfiguration.GetValue("SelectCityStates") == "SELECTION" or MapConfiguration.GetValue("SelectCityStates") == "EXCLUSION" or MapConfiguration.GetValue("SelectCityStates") == "RANDOM"
			local bOnlySelection	= MapConfiguration.GetValue("SelectCityStates") == "ONLY_SELECTION"
			local cityStateSlots 	= (bCapped and numCS) or maxCS
			local shuffledList 		= GetShuffledCopyOfTable(filteredList)
			local randomList		= {}
			local barbarianList		= {}
			local slotListID		= 1
			print("------------------------------------------------------")
			print("YnAMP setting specific CS slots...")
			print("Trying to reserve slots for selected CS, available slots = "..tostring(#CityStatesSlotsList)..", maxCS = "..tostring(cityStateSlots).. ", bCapped = ", bCapped, " bOnlySelection = ", bOnlySelection)
			for i, row in ipairs(shuffledList) do
				--print(i)
				--for k, v in pairs(row) do print(k, v) end
				local leaderType = row.ConfigurationId
				local leaderName = row.Name
				if (not bBanListCS) and IsSelected(leaderType) then -- true if this CS was checked and we're not in exclusion mode
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
						print(" - Maximum #CS reached, adding to Barbarian Pool : ".. Locale.Lookup(leaderName) .." at slotListID#"..tostring(slotListID).."/".. tostring(#CityStatesSlotsList) )
						table.insert(barbarianList, row)
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
			local slotID 	= CityStatesSlotsList[slotListID]
			if newNumCS > 0 then
				local nextIndex	= 1
				for slotListID = slotListID, slotListID + newNumCS - 1 do --cityStateSlots do
					slotID 				= CityStatesSlotsList[slotListID]
					local playerConfig 	= PlayerConfigurations[slotID]
					if playerConfig then
						-- get next entry in the random pool
						local row	= randomList[nextIndex]
						nextIndex	= nextIndex + 1
						if row then
							local leaderType = row.ConfigurationId
							local leaderName = row.Name
							print(" - Reserving player slot#"..tostring(slotID).." for ".. Locale.Lookup(leaderName), "slotListID#"..tostring(slotListID) )
							playerConfig:SetSlotStatus(SlotStatus.SS_COMPUTER)
							playerConfig:SetLeaderName(leaderName)
							playerConfig:SetLeaderTypeName(leaderType)
						else
							print(" - No more CS in Random pool, can't set a CS at slotListID#"..tostring(slotListID).."/".. tostring(#CityStatesSlotsList) )
							break
						end
					else
						print(" - No more Slot available, can't set a CS at slotListID#"..tostring(slotListID).."/".. tostring(#CityStatesSlotsList) )
						break
					end
				end
			end
			if bBarbarians then
				print("Reserving Barbarians CS Slots")
				print(" - slotListID",slotListID)
				print(" - slotID",slotID)
				local nextIndex	= 1
				local maxSlotID	= (GameConfiguration.GetValue("RULESET") == "RULESET_EXPANSION_1" or GameConfiguration.GetValue("RULESET") == "RULESET_EXPANSION_2") and maxTotalPlayers - 1 or maxTotalPlayers
				if slotID then
					while (slotID and slotID < maxSlotID) do
						slotID 				= CityStatesSlotsList[slotListID]
						slotListID			= slotListID + 1
						if slotID and slotID < maxSlotID then
							local playerConfig 	= PlayerConfigurations[slotID]
							if playerConfig then
								-- get next entry in the random pool
								local row	= barbarianList[nextIndex]
								nextIndex	= nextIndex + 1
								if row then
									local leaderType = row.ConfigurationId
									local leaderName = row.Name
									print(" - Reserving player slot#"..tostring(slotID).." for Barbarians CS ".. Locale.Lookup(leaderName) , "slotListID#"..tostring(slotListID) )
									playerConfig:SetSlotStatus(SlotStatus.SS_RESERVED)
									playerConfig:SetLeaderName(leaderName)
									playerConfig:SetLeaderTypeName(leaderType)
								else
									print(" - No more CS in Barbarian pool, can't set a CS at slotListID#"..tostring(slotListID).."/".. tostring(#CityStatesSlotsList) )
									break
								end
							end
						elseif slotID then
							print(" - Player Slot #".. tostring(slotID) ..">= "..tostring(maxTotalPlayers).. ", can't set a CS at slotListID#"..tostring(slotListID).."/".. tostring(#CityStatesSlotsList) )
						else
							print(" - No more Slot in CS slotList at ID#"..tostring(slotListID).."/".. tostring(#CityStatesSlotsList) )
						end
					end
				else
					print(" - No more Slot available, can't set a CS at slotListID#"..tostring(slotListID).."/".. tostring(#CityStatesSlotsList) )
				end
			end
			--]]
		end
	elseif ConfigYnAMP.IsDatabaseChanged then
		print("------------------------------------------------------")
		print("Database Changed, skipping CS selection...")
	end
	
	-- Gedemon fix for Free Cities Bug
	--[[
	if (GameConfiguration.GetValue("RULESET") == "RULESET_EXPANSION_1" or GameConfiguration.GetValue("RULESET") == "RULESET_EXPANSION_2") then
        local playerConfig     = PlayerConfigurations[62]
        if playerConfig then
            local leaderType = "LEADER_FREE_CITIES"
            local leaderName = "LOC_LEADER_FREE_CITIES_NAME"
            print(" - Reserving player slot#62 for ".. Locale.Lookup(leaderName) )
            playerConfig:SetSlotStatus(SlotStatus.SS_COMPUTER)
            playerConfig:SetLeaderName(leaderName)
            playerConfig:SetLeaderTypeName(leaderType)
        end
    end
	--]]
    
	-- Make some info available during map creation
	YnAMP_Loading.ListMods 		= listMods
	YnAMP_Loading.GameVersion 	= UI.GetAppVersion()
	-- YNAMP >>>>>

	-- Is WorldBuilder active?
	if (GameConfiguration.IsWorldBuilderEditor()) then
        if (m_WorldBuilderImport) then
            MapConfiguration.SetScript("WBImport.lua");
			local loadGameMenu = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/LoadGameMenu" );
			UIManager:QueuePopup(loadGameMenu, PopupPriority.Current);	
		else
			UI.SetWorldRenderView( WorldRenderView.VIEW_2D );
			UI.PlaySound("Set_View_2D");
			Network.HostGame(ServerType.SERVER_TYPE_NONE);
		end
	else
		-- YNAMP <<<<<
		-- 	if AreAllCityStateSlotsUsed() then
		if bSelectCS or AreAllCityStateSlotsUsed() then -- if bSelectCS is true then we use one of the YnAMP option for CS selection and we can use any number of CS slots 
		-- YNAMP >>>>>
			HostGame();
		else
			m_pCityStateWarningPopup:ShowOkCancelDialog(Locale.Lookup("LOC_CITY_STATE_PICKER_TOO_FEW_WARNING"), HostGame);
		end
	end
end

-- ===========================================================================
function HostGame()
	-- YnAMP <<<<<
	-- Reserve slots if required
	local bHasFreeCities 	= (GameConfiguration.GetValue("RULESET") == "RULESET_EXPANSION_1" or GameConfiguration.GetValue("RULESET") == "RULESET_EXPANSION_2")
	local lastSlot 			= bHasFreeCities and 61 or 62
	local results			= DB.ConfigurationQuery("SELECT * FROM ReservedPlayerSlots")
	local IsUsedLeader		= {}
	for slotID = 0, 63 do
		local playerConfig = PlayerConfigurations[slotID]
		if playerConfig and playerConfig:GetLeaderTypeName() then
			IsUsedLeader[playerConfig:GetLeaderTypeName()] = true
		end
	end
	for i, row in ipairs(results) do
		local playerConfig = PlayerConfigurations[lastSlot]
		local leaderName = "LOC_"..tostring(row.LeaderType).."_NAME"
		if playerConfig then
			if playerConfig:GetLeaderTypeName() == nil or row.ForceReplace then
				if not (row.NoDuplicate and IsUsedLeader[row.LeaderType]) then
					print(" - Reserving player slot#"..tostring(lastSlot).." for ".. tostring(row.LeaderType) )
					
					playerConfig:SetLeaderTypeName(nil)
					GameConfiguration.RemovePlayer(lastSlot)
					
					playerConfig:SetSlotStatus(SlotStatus.SS_COMPUTER)
					playerConfig:SetLeaderName(leaderName)
					playerConfig:SetLeaderTypeName(row.LeaderType)
					if row.IsMajor then
						playerConfig:SetMajorCiv()
					end
				end
				lastSlot = lastSlot - 1
			end
		end
	end
	
	-- List the player slots
	print("------------------------------------------------------")
	print("Setup Player slots :")
	for slotID = 0, 63 do
		local playerConfig = PlayerConfigurations[slotID]
		if playerConfig then
		--Indentation
			print(slotID, Indentation(playerConfig and playerConfig:GetLeaderTypeName(),20), Indentation(playerConfig and playerConfig:GetCivilizationTypeName(),25), Indentation(playerConfig and playerConfig:GetSlotName(),25), Indentation(playerConfig and (slotStatusString[playerConfig:GetSlotStatus()] or "UNK STATUS"),15), Indentation(playerConfig and (civLevelString[playerConfig:GetCivilizationLevelTypeID()] or "UNK LEVEL"),15),  playerConfig and playerConfig:IsAI())
		end
	end
	-- YnAMP >>>>>
	-- Start a normal game
	UI.PlaySound("Set_View_3D");
	Network.HostGame(ServerType.SERVER_TYPE_NONE);
end

-- ===========================================================================
function AreAllCityStateSlotsUsed()
	local kParameters:table = g_GameParameters["Parameters"];

	if kParameters["CityStates"] == nil then
		return true;
	end

	local cityStateSlots:number = kParameters["CityStateCount"].Value;
	local totalCityStates:number = #kParameters["CityStates"].AllValues;
	local excludedCityStates:number = kParameters["CityStates"].Value ~= nil and #kParameters["CityStates"].Value or 0;

	if (totalCityStates - excludedCityStates) < cityStateSlots then
		return false;
	end

	return true;
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
		Controls.NoGameModesContainer:SetHide(false);
	end
end

-- ===========================================================================
--	Realize the animated flyouts with description, icons, and portraits for 
--  the currently hovered game mode toggle.
-- ===========================================================================
function OnGameModeMouseEnter(kGameModeData : table)
	m_gameModeToolTipHeaderIM:ResetInstances();
	m_gameModeToolTipHeaderIconIM:ResetInstances();
	if(Controls.GameModeToolTipSlide:IsReversing())then
		Controls.GameModeSlide:Reverse();
		Controls.GameModeAlpha:Reverse();
		Controls.GameModeToolTipSlide:Reverse();
		Controls.GameModeToolTipAlpha:Reverse();
	else
		Controls.GameModeSlide:Play();
		Controls.GameModeAlpha:Play();
		Controls.GameModeToolTipSlide:Play();
		Controls.GameModeToolTipAlpha:Play();
	end
	local gameModeHeader : table = m_gameModeToolTipHeaderIM:GetInstance();
	gameModeHeader.Header:SetText(Locale.Lookup(kGameModeData.RawName));

	local gameModeDescription : table = m_gameModeToolTipHeaderIconIM:GetInstance();
	gameModeDescription.Description:SetText(kGameModeData.Description);
	gameModeDescription.Header:SetHide(true);

	local gameModeInfo : table = GetGameModeInfo(kGameModeData.ConfigurationId);
	if(gameModeInfo ~= nil)then
		gameModeDescription.Icon:SetIcon(gameModeInfo.Icon);

		if(gameModeInfo.UnitIcon)then
			local gameModeUnitDescription : table = m_gameModeToolTipHeaderIconIM:GetInstance();
			gameModeUnitDescription.Description:SetText(Locale.Lookup(gameModeInfo.UnitDescription));
			gameModeUnitDescription.Icon:SetIcon(gameModeInfo.UnitIcon);
			gameModeUnitDescription.Header:SetText(Locale.ToUpper(gameModeInfo.UnitName));
		end
		if(gameModeInfo.Portrait)then
			Controls.GameModeImage:SetTexture(gameModeInfo.Portrait);
		end
		if(gameModeInfo.Background)then
			Controls.GameModeBG:SetTexture(gameModeInfo.Background);
		end
	end
end

function OnGameModeMouseExit(kGameModeData : table)
	if(not Controls.GameModeToolTipSlide:IsReversing())then
		Controls.GameModeSlide:Reverse();
		Controls.GameModeAlpha:Reverse();
		Controls.GameModeToolTipSlide:Reverse();
		Controls.GameModeToolTipAlpha:Reverse();
	else
		Controls.GameModeSlide:Play();
		Controls.GameModeAlpha:Play();
		Controls.GameModeToolTipSlide:Play();
		Controls.GameModeToolTipAlpha:Play();
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

	local iSidebarSize = Controls.CreateGameWindow:GetSizeY();
	if iSidebarSize > MAX_SIDEBAR_Y then
		iSidebarSize = MAX_SIDEBAR_Y;
	end
	Controls.BasicPlacardContainer:SetSizeY(iSidebarSize);
	Controls.BasicTooltipContainer:SetSizeY(iSidebarSize);
	Controls.GameModePlacardContainer:SetSizeY(iSidebarSize);
	Controls.GameModeTooltipContainer:SetSizeY(iSidebarSize);
end

-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

-- ===========================================================================
function OnBeforeMultiplayerInviteProcessing()
	-- We're about to process a game invite.  Get off the popup stack before we accidentally break the invite!
	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================
function OnShutdown()
	Events.FinishedGameplayContentConfigure.Remove(OnFinishedGameplayContentConfigure);
	Events.SystemUpdateUI.Remove( OnUpdateUI );
	Events.BeforeMultiplayerInviteProcessing.Remove( OnBeforeMultiplayerInviteProcessing );

	LuaEvents.MapSelect_SetMapByValue.Remove( OnSetMapByValue );
	LuaEvents.MultiSelectWindow_SetParameterValues.Remove(OnSetParameterValues);
	LuaEvents.CityStatePicker_SetParameterValues.Remove(OnSetParameterValues);
	LuaEvents.LeaderPicker_SetParameterValues.Remove(OnSetParameterValues);
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
	Controls.ConflictConfirmButton:RegisterCallback( Mouse.eLClick, function() Controls.ConflictPopup:SetHide(true); end);
	Controls.ConflictConfirmButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	
	Events.FinishedGameplayContentConfigure.Add(OnFinishedGameplayContentConfigure);
	Events.SystemUpdateUI.Add( OnUpdateUI );
	Events.BeforeMultiplayerInviteProcessing.Add( OnBeforeMultiplayerInviteProcessing );

	LuaEvents.MapSelect_SetMapByValue.Add( OnSetMapByValue );
	LuaEvents.MultiSelectWindow_SetParameterValues.Add(OnSetParameterValues);
	LuaEvents.CityStatePicker_SetParameterValues.Add(OnSetParameterValues);
	LuaEvents.LeaderPicker_SetParameterValues.Add(OnSetParameterValues);
	-- YnAMP <<<<<
	Controls.LoadDataYnAMP:RegisterCallback( Mouse.eLClick, LoadDatabase);
	Controls.LoadDataYnAMP:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);--
	Controls.IgnoreWarning:RegisterCallback( Mouse.eLClick, IgnoreWarning);
	Controls.IgnoreWarning:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	
	-- Ranting
	--[[
	Controls.Logo:SetAlpha(0.10)
	if(Steam and Steam.IsOverlayEnabled and Steam.IsOverlayEnabled()) then
		local titleText = "[COLOR_Gold]"..Locale.ToUpper("LOC_SETUP_ARTICLE_TITLE_YNAMP").."[ENDCOLOR]" .. Locale.Lookup("LOC_SETUP_ARTICLE_RESUME_STEAM_ON_YNAMP")
		Controls.ArticleTitle:LocalizeAndSetText(titleText)
		Controls.ButtonURL:SetToolTipString("www.pcgamesn.comcivilization-vi/civ-6-new-season-pass-details[NEWLINE]Interview with Anton Strenger, lead designer[NEWLINE]May 11, 2020[NEWLINE][NEWLINE]www.pcgamesn.com/civilization-6/dll-source-release-modding-community[NEWLINE]Article about the modding limitations without the DLL source[NEWLINE]Feb 25, 2020")
		Controls.ButtonURL:RegisterCallback(Mouse.eRClick, function()
			local url = "https://www.pcgamesn.com/civilization-vi/civ-6-new-season-pass-details"
			Steam.ActivateGameOverlayToUrl(url);
		end)
		Controls.ButtonURL:RegisterCallback(Mouse.eLClick, function()
			local url = "https://www.pcgamesn.com/civilization-6/dll-source-release-modding-community"
			Steam.ActivateGameOverlayToUrl(url);
		end)
	else
		Controls.ButtonURL:SetToolTipString("www.pcgamesn.comcivilization-vi/civ-6-new-season-pass-details[NEWLINE]Interview with Anton Strenger, lead designer[NEWLINE]May 11, 2020[NEWLINE][NEWLINE]www.pcgamesn.com/civilization-6/dll-source-release-modding-community[NEWLINE]Article about the modding limitations without the DLL source[NEWLINE]Feb 25, 2020")
	end
	--]]
	-- YnAMP >>>>>

	Resize();
end

-- YnAMP <<<<<

-- ===========================================================================
-- TSL Reference functions
-- ===========================================================================
-- Set globals
local lastSelectedMapName		= nil
local bUseRelativeFixedTable	= false
local RefMapXfromX 				= {}
local RefMapYfromY 				= {}

-- Build Reference table
function BuildRefXY()
	local sX, sY 		= 0, 0
	local lX, lY 		= 0, 0
	local skipX, skipY	= MapConfiguration.GetValue("RescaleSkipX"), MapConfiguration.GetValue("RescaleSkipY")
	for x = 0, g_UncutMapWidth, 1 do
		for y = 0, g_UncutMapHeight, 1 do
			
			RefMapXfromX[sX] = x
			RefMapYfromY[sY] = y
			
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

--
function InitializeMapGlobals()
	-- local
	local referenceMapWidth 	= MapConfiguration.GetValue("ReferenceMapWidth")
	local referenceMapHeight 	= MapConfiguration.GetValue("ReferenceMapHeight")
	
	-- global
	bUseRelativeFixedTable 	= MapConfiguration.GetValue("UseRelativeFixedTable")
	g_UncutMapWidth 		= MapConfiguration.GetValue("UncutMapWidth")
	g_UncutMapHeight 		= MapConfiguration.GetValue("UncutMapHeight")
	g_ReferenceWidthRatio   = g_UncutMapWidth / referenceMapWidth
	g_ReferenceHeightRatio  = g_UncutMapHeight / referenceMapHeight
	
	if bUseRelativeFixedTable then
		BuildRefXY()
	end
end

-- Convert the reference map position to the current map position
function GetXYFromRefMapXY(x, y)
	local currMapScript = MapConfiguration.GetScript()
	if currMapScript ~= lastSelectedMapScript then -- only initialize if the map has changed
		InitializeMapGlobals()
		lastSelectedMapScript = currMapScript
	end
	if bUseRelativeFixedTable then
		x = RefMapXfromX[x]
		y = RefMapYfromY[y]
		if x == nil or y == nil then
			return -1, -1
		end
	else
		x = Round( g_ReferenceWidthRatio * x)
		y = Round( g_ReferenceHeightRatio * y)		
	end
	return x, y
end

--
function IsInDimension(x, y, dimension)
	
	if MapConfiguration.GetValue("UseRelativePlacement") then
		x, y = GetXYFromRefMapXY(x, y)
	end
	
	local xValid = false
	local yValid = false
	
	if (dimension.startX < dimension.endX) then
		xValid = (x > dimension.startX and x < dimension.endX)
	else
		xValid = (x > dimension.startX or  x < dimension.endX)
	end
		
	if (dimension.startY < dimension.endY) then
		yValid = (y > dimension.startY and y < dimension.endY)
	else
		yValid = (y > dimension.startY or  y < dimension.endY)
	end
	
	return xValid and yValid
end

--
function HasTSL(args)--(leaderType, mapName, playerDomain, civilizationType)
	local reason			= nil
	local leaderType		= args.leaderType
	local playerDomain		= (args.civilizationType and nil) or args.playerDomain or (GameConfiguration.GetValue("RULESET") and RulesetPlayerDomain[GameConfiguration.GetValue("RULESET")] or "Players:StandardPlayers") -- don't need it if CivilizationType is already in args
	local civilizationType	= args.civilizationType or GetPlayerCivilization(playerDomain, leaderType)
	local mapName			= args.mapName or MapConfiguration.GetValue("MapName")
	local mapTSL			= mapName and TSL[mapName]
	local leaderTSL			= mapTSL and mapTSL[leaderType]
	local civTSL			= mapTSL and civilizationType and mapTSL[civilizationType]
	
	if not (leaderTSL or civTSL) then -- no TSL for that map
		reason = "LOC_SETUP_ERROR_NO_TSL"
	else
		local dimension = GetCustomMapDimension() 
		if dimension then -- custom dimension found, check in map section
			if leaderTSL then
				for _, row in ipairs(leaderTSL) do
					if IsInDimension(row.X, row.Y, dimension) then
						return true
					end
				end
			end
			if civTSL then
				for _, row in ipairs(civTSL) do
					if IsInDimension(row.X, row.Y, dimension) then
						return true
					end
				end
			end
			reason = "LOC_SETUP_ERROR_NO_TSL_IN_SECTION"
		else -- uncut map, found TSL table, return true
			return true
		end
	end
	
	return false, reason
end


-- ===========================================================================
-- Settings Validation functions
-- ===========================================================================
local bCheckModList 		= true
local bRulesetStateChanged 	= false
local sTooltipSeparator		= "[NEWLINE]----------------------------------------------------------------------------------------------------------------[NEWLINE]"
local IgnoredWarning		= {}
local currentBlock			= nil

local severityNone			= 0
local severityMedium		= 25
local severityHigh			= 75
function GetColorStringSeverity(str, severity)
	if severity == severityNone then
		str = "[COLOR_Civ6Green]"..str.."[ENDCOLOR] [ICON_CheckSuccess]"
	elseif severity > severityHigh then
		str = "[COLOR_Civ6Red]"..str.."[ENDCOLOR] [ICON_Not]"
	elseif severity > severityMedium then
		str = "[COLOR_OperationChance_Orange]"..str.."[ENDCOLOR] [ICON_CheckFail]"
	end
	return str
end

function GetCustomMapDimension() -- return size, iW, iH
	local startX	= MapConfiguration.GetValue("StartX")
	if startX then -- can have a custom section
		local dimension		= {}
		dimension.startX	= startX
		dimension.uncutW	= MapConfiguration.GetValue("UncutMapWidth")
		dimension.uncutH	= MapConfiguration.GetValue("UncutMapHeight")
		dimension.startY	= MapConfiguration.GetValue("StartY")
		dimension.endX		= MapConfiguration.GetValue("EndX")
		dimension.endY		= MapConfiguration.GetValue("EndY")
		
		dimension.iW	= (dimension.startX < dimension.endX) and dimension.endX - dimension.startX + 1 or dimension.uncutW - (dimension.startX - dimension.endX) + 1
		dimension.iH	= (dimension.startY < dimension.endY) and dimension.endY - dimension.startY + 1 or dimension.uncutH - (dimension.startY - dimension.endY) + 1
		
		dimension.size	= dimension.iW * dimension.iH
		return dimension
	end
end

function GetClosestMapSizeType(size)
--MapSizeNames ConfigYnAMP.MapSizes
	local bestDiff 	= 99999
	local closest	= nil
	for _, row in ipairs(SortedMapSize) do
		local diff = math.abs(size - row.Size)
		if diff < bestDiff then
			bestDiff 	= diff
			closest 	= row.MapSizeType
		end
	end
	return closest
end

function SetStartButtonValid(bValid, sReason, sBlockGroup)
	--print("Calling SetStartButtonValid(", bValid, sReason, "), bStartDisabledBySetup = ", bStartDisabledBySetup, " bStartDisabledByYnAMP = ", bStartDisabledByYnAMP)
	if bStartDisabledBySetup then
		return
	end
	if bValid then
		bStartDisabledByYnAMP = false
		Controls.StartButton:SetDisabled(false)
		Controls.StartButton:SetToolTipString(nil)
		Controls.IgnoreWarning:SetHide(true)
		
		if(m_AdvancedMode) then
			Controls.LoadConfig:SetHide(false);
			Controls.SaveConfig:SetHide(false);
			Controls.ButtonStack:CalculateSize();
		end
	else
		currentBlock			= sBlockGroup
		bStartDisabledByYnAMP 	= true
		local sTooltip			= sReason..sTooltipSeparator..Locale.Lookup("LOC_SETUP_IGNORE_WARNING_YNAMP_TT")
		Controls.StartButton:SetDisabled(true)
		Controls.StartButton:SetToolTipString(sTooltip)
		Controls.IgnoreWarning:SetHide(false)
		Controls.IgnoreWarning:SetToolTipString(sTooltip)
		
		if(m_AdvancedMode) then
			Controls.LoadConfig:SetHide(true);
			Controls.SaveConfig:SetHide(true);
			Controls.ButtonStack:CalculateSize();
		end
	end
end

function IgnoreWarning()
	Controls.IgnoreWarning:SetHide(true)
	if currentBlock then
		IgnoredWarning[currentBlock] = true
	end
	ValidateSettingsYnAMP() -- test again, to see if another block exists
end

function ValidateSettingsYnAMP()

	-- Severity trigger values
	-- None		= 0
	-- Medium	= 25
	-- High		= 75

	local reportTable 	= {} -- {{ Severity = [0-100], Title = string, Tooltip = string, DisableStart = bool, BlockGroup = string },}

	-- Database check
	if ConfigYnAMP.IsDatabaseLoaded then
		table.insert(reportTable, { Severity = 0, Title = Locale.Lookup("LOC_SETUP_DATABASE_LOADED_YNAMP"), Tooltip = Locale.Lookup("LOC_SETUP_DATABASE_LOADED_YNAMP_TT") })
		Controls.LoadDataYnAMP:SetHide(true)
	else
		table.insert(reportTable, { Severity = 20, Title = Locale.Lookup("LOC_SETUP_DATABASE_NOT_LOADED_YNAMP"), Tooltip = Locale.Lookup("LOC_SETUP_DATABASE_NOT_LOADED_YNAMP_TT") })
		Controls.LoadDataYnAMP:SetHide(false)
	end
	
	-- Mod check
	if ConfigYnAMP.IsDatabaseLoaded and bCheckModList then -- don't check each time a setting is changed...
	
		bCheckModList		= false 
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
		
	if ConfigYnAMP.IsDatabaseChanged then -- always chech to generate the report
		--print("Database may have changed...")
		--local bLock		= not IgnoredWarning["DatabaseChanged"]
		local severity	= bLock and 40 or 25 --bLock and 75 or 50
		table.insert(reportTable, { Severity = severity, Title = Locale.Lookup("LOC_SETUP_DATABASE_CHANGED_YNAMP"), Tooltip = Locale.Lookup("LOC_SETUP_DATABASE_CHANGED_YNAMP_TT"), DisableStart = bLock, BlockGroup = "DatabaseChanged" })
		Controls.LoadDataYnAMP:SetHide(false)
	end
	
	-- Ruleset check
	local bChangedRuleset	= (ConfigYnAMP.LoadedRuleset ~= GameConfiguration.GetValue("RULESET"))
	
	if bRulesetStateChanged ~= bChangedRuleset then -- redo mod check when Ruleset check state has changed
		bRulesetStateChanged 	= bChangedRuleset
		bCheckModList			= true
	end
	
	if ConfigYnAMP.IsDatabaseLoaded  then
		if bChangedRuleset then
			--print("Database have changed...")
			ConfigYnAMP.IsDatabaseChanged 	= true
			--local bLock		= not IgnoredWarning["RulesetChanged"]
			local severity	= bLock and 40 or 24 --bLock and 100 or 70
			table.insert(reportTable, { Severity = severity, Title = Locale.Lookup("LOC_SETUP_RULESET_CHANGED_YNAMP"), Tooltip = Locale.Lookup("LOC_SETUP_RULESET_CHANGED_YNAMP_TT"), DisableStart = bLock, BlockGroup = "RulesetChanged" })
			Controls.LoadDataYnAMP:SetHide(false)
		end
	end
	
	-- Map Size check
	local dimension		= GetCustomMapDimension()
	local size 			= dimension and dimension.size
	local bMapSizeBlock	= (not IgnoredWarning["MapSize"]) and (not GameConfiguration.IsWorldBuilderEditor())
	if not size then 
		local mapSizetype	= MapSizeTypesFromHash[MapConfiguration.GetMapSize()]
		local mapDimension 	= mapSizetype and ConfigYnAMP.MapSizes[mapSizetype]
		if mapDimension then
			size = mapDimension.Size
		else
			print("No map size ", MapConfiguration.GetMapSize(), mapSizetype)
			local tooltip = Locale.Lookup("LOC_SETUP_MAP_SIZE_UNKNOWN_YNAMP_TT")
			--local bLock		= bMapSizeBlock
			local severity	= bMapSizeBlock and 40 or 24 --bLock and 80 or 55
			table.insert(reportTable, { Severity = severity, Title = Locale.Lookup("LOC_SETUP_MAP_SIZE_UNKNOWN_YNAMP"), Tooltip = tooltip, DisableStart = bLock, BlockGroup = "MapSize" })
		end
	end
	if size then
		if size > maxLoadingMapSize then
			--print("Unsupported map size", mapDimension.Width, mapDimension.Height, mapDimension.Size)
			local tooltip	= Locale.Lookup("LOC_SETUP_MAP_OVERSIZE_YNAMP_TT")
			local bLock		= bMapSizeBlock
			local severity	= bLock and 100 or 70
			table.insert(reportTable, { Severity = severity, Title = Locale.Lookup("LOC_SETUP_MAP_SIZE_LOCK_YNAMP"), Tooltip = tooltip, DisableStart = bLock, BlockGroup = "MapSize" })
		elseif size > maxWorkingMapSize then
			--print("Not loading map size", mapDimension.Width, mapDimension.Height, mapDimension.Size)
			local tooltip = Locale.Lookup("LOC_SETUP_MAP_SIZE_LOCK_YNAMP_TT")
			local bLock		= bMapSizeBlock
			local severity	= bLock and 80 or 55
			table.insert(reportTable, { Severity = severity, Title = Locale.Lookup("LOC_SETUP_MAP_SIZE_LOCK_YNAMP"), Tooltip = tooltip, DisableStart = bLock, BlockGroup = "MapSize" })
		elseif size > maxSupportedMapSize then
			--print("Unsupported map size", mapDimension.Width, mapDimension.Height, mapDimension.Size)
			local tooltip	= Locale.Lookup("LOC_SETUP_MAP_SIZE_UNOFFICIAL_YNAMP_TT")
			local severity	= bMapSizeBlock and 40 or 24
			table.insert(reportTable, { Severity = severity, Title = Locale.Lookup("LOC_SETUP_MAP_SIZE_UNOFFICIAL_YNAMP"), Tooltip = tooltip })
		end
	end
	
	-- Compare Major Civilization slider to actual numbe of players
	if m_AdvancedMode and GameConfiguration.GetParticipatingPlayerCount() ~= GameConfiguration.GetValue("MajorCivilizationsCount") then
		table.insert(reportTable, { Severity = 1, Title = Locale.Lookup("LOC_SETUP_MAJOR_COUNT_DIFFERENCE"), Tooltip = Locale.Lookup("LOC_SETUP_MAJOR_COUNT_DIFFERENCE_TT") })
	end
	
	----------------------------------------------------
	-- Generate Title and Tooltip, check for valid Start
	----------------------------------------------------
	table.sort(reportTable, function(a, b) return a.Severity > b.Severity; end)
	local maxSeverity	= #reportTable > 0 and reportTable[1].Severity or 0
	local titleStr 		= nil
	local mainTitle		= GameConfiguration.IsWorldBuilderEditor() and Locale.ToUpper("LOC_SETUP_CREATE_MAP") or Locale.ToUpper("LOC_SETUP_CREATE_GAME")
	local tooltip		= {Locale.Lookup("LOC_SETUP_YNAMP_REPORT")}
	local bCanStart		= true
	local listIcon		= maxSeverity > 0 and "[ICON_Reports]" or ""
	for i, row in ipairs(reportTable) do
		titleStr 			= titleStr or GetColorStringSeverity(mainTitle, row.Severity)..listIcon -- row.Title -- set title with the highest severity reason "YnAMP - "..
		local severityStr 	= ""--row.Severity > 0 and " "..Locale.Lookup("LOC_SETUP_SEVERITY_YNAMP", row.Severity) or ""
		local blockingStr 	= row.DisableStart and " "..Locale.Lookup("LOC_SETUP_BLOCKING_YNAMP") or ""
		local ignoredStr	= row.BlockGroup and IgnoredWarning[row.BlockGroup] and " "..Locale.Lookup("LOC_SETUP_IGNORE_BLOCK_YNAMP") or nil
		local tooltipStr	= GetColorStringSeverity(row.Title, row.Severity) .. (ignoredStr or (severityStr.." "..blockingStr)) ..sTooltipSeparator.. row.Tooltip
		table.insert(tooltip, "[ICON_Bullet]" .. tooltipStr)
		if bCanStart and row.DisableStart then -- set locked start with the highest severity reason
			bCanStart = false
			SetStartButtonValid(false, tooltipStr, row.BlockGroup)
		end
	end
	
	if bCanStart then
		SetStartButtonValid(true)
	end
	
	-- Show which setup mode we are on
	--[[
	if GameConfiguration.IsWorldBuilderEditor() then
		titleStr = "[ICON_Global] ".. titleStr
	else
		titleStr = "[ICON_ProductionQueue] ".. titleStr
	end
	--]]
	--
	Controls.WindowTitle:SetText(titleStr)
	Controls.WindowTitle:SetToolTipString(table.concat(tooltip, sTooltipSeparator))
end

-- ===========================================================================
function OnGameplayContentConfigure()
	print("Mark to check mods on FinishedGameplayContentConfigure")
	bCheckModList = true
	
	
	print("Rebuild modlist")
	listMods 	= {}
	IsActiveMod	= {}
	local installedMods = Modding.GetInstalledMods()

	if installedMods ~= nil then
		for i, modData in ipairs(installedMods) do
			if modData.Enabled then
				table.insert(listMods, modData)
			end
		end
	end

	for i, v in ipairs(listMods) do
		IsActiveMod[v.Id] = v
	end
end
Events.FinishedGameplayContentConfigure.Add(OnGameplayContentConfigure)
--GameConfigurationRebuilt
--FinishedGameplayContentChange
--FinishedGameplayContentConfigure

-- ===========================================================================
function LoadDatabase()
	print("Set and Launch a quick game to get YnAMP Data...");
	
	ConfigYnAMP.LoadingDatabase = true
	
	local ruleset = GameConfiguration.GetValue("RULESET")
	print("Active Ruleset = ", ruleset)
	
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
	GameConfiguration.SetValue("RULESET", ruleset)
	MapConfiguration.SetMapSize("MAPSIZE_DUEL")
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
function ParameterBackup(parameter) -- Save and Restore specifics parameters when they are hidden
--print("backup : parameter = ", parameter.ConfigurationId, parameter.ConfigurationGroup )
	local ConfGroup		= parameter.ConfigurationGroup
	local Configuration = (ConfGroup == "Game" and GameConfiguration) or (ConfGroup == "Map" and MapConfiguration)
	if Configuration then
		local configurationID	= parameter.ConfigurationId
		if not SavedParameter[configurationID] then SavedParameter[configurationID] = {} end
		local Backup	= SavedParameter[configurationID]
		local curValue	= Configuration.GetValue(configurationID)
		if curValue == nil then -- Mark that the setting is disabled
			Backup.IsDisabled = true
		else
			if Backup.IsDisabled == true then -- The setting was disabled, but is visible again
				Backup.IsDisabled = false
				if Backup.Value ~= nil then -- Restore the previous value if their was one
					Configuration.SetValue(configurationID, Backup.Value)
				end
			else -- The setting was visible, update the users's choice
				Backup.Value = curValue
			end
		end
	end
end

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
print("MapSize_ValueChanged")
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
			defPlayers = m_AdvancedMode and math.max(GameConfiguration.GetParticipatingPlayerCount(), v.DefaultPlayers) or v.DefaultPlayers; --YnAMP currentSelectedNumberMajorCivs
			minCityStates = v.MinCityStates;
			maxCityStates = v.MaxCityStates--math.min(v.MaxCityStates,maxTotalPlayers-defPlayers);
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
--local RelevantParameters
function GetRelevantParameters(o, parameter)

	-- Hack to use parameters to determine if a Mod/DLC/Expansion is enabled
	-- 1/ Define a hidden Parameter with Name="RequireMod" and Description="REQUIRED_MOD_ID": 
	-- <Replace ParameterId="DLC2" Name="RequireMod" Description="2F6E858A-28EF-46B3-BEAC-B985E52E9BC1" Domain="bool" DefaultValue="1" ConfigurationGroup="Map" ConfigurationId="DLC2"	GroupId="MapOptions" Visible="0" SortIndex="82"/>
	-- 2/ Use it as a ParameterDependencies for your settings that require the mod to be enabled:
	-- <Replace ParameterId="LEADER_MINOR_CIV_AUCKLAND"	ConfigurationGroup="Map" ConfigurationId="DLC2" Operator="Equals" ConfigurationValue="1"/>
	-- 3/ Your hidden Parameter can have its own dependencies
	-- <Replace ParameterId="DLC2"	ConfigurationGroup="Map" ConfigurationId="SelectCityStates" Operator="NotEquals" ConfigurationValue="RANDOM"/>
	
	if parameter.Name == "RequireMod" and not IsActiveMod[parameter.Description] then --and not Modding.IsModEnabled(parameter.Description) then --
		return false
	end
	
	
	--
	-- Show dimension for Map with custom sections
	if parameter.ConfigurationId == "MapDimension" then
		local dimension	= GetCustomMapDimension()
		if dimension then
			local size, iW, iH	= dimension.size, dimension.iW, dimension.iH
			local mapSizeType 	= GetClosestMapSizeType(size)
			local currSize		= MapSizeTypesFromHash[MapConfiguration.GetValue("MAP_SIZE")]
			if currSize ~= mapSizeType then
				MapConfiguration.SetMapSize(mapSizeType)
				currSize = mapSizeType
			end
			local sizeName = MapSizeNames[currSize]
			MapConfiguration.SetValue("MapDimension", Locale.Lookup("LOC_MAP_DIMENSION_STRING", iW, iH, size).." - "..Locale.Lookup(sizeName))
		else
			return false
		end
	end

	--
	-- The OnlyLeadersWithTSL option require the Database to be loaded and unmodified
	if parameter.ConfigurationId == "OnlyLeadersWithTSL" then
		if (not ConfigYnAMP.IsDatabaseLoaded) or ConfigYnAMP.IsDatabaseChanged then
			return false
		end
	end
	
	--
	-- Show fake OnlyLeadersWithTSL option when the Database is not loaded or modified
	if parameter.ConfigurationId == "FakeOnlyLeadersWithTSL" then
		if ConfigYnAMP.IsDatabaseLoaded and not ConfigYnAMP.IsDatabaseChanged then
			return false
		end
	end
	
	--[[
	-- we don't need the code below anymore I think, as we use the base game CS piker only and expect modders to follow Firaxis method
	--
	-- The SelectCityStates option require the Database to be unmodified
	if parameter.ConfigurationId == "SelectCityStates" then
		if ConfigYnAMP.IsDatabaseChanged then
			return false
		end
	end
	
	--
	-- Show fake SelectCityStates option when the Database is not loaded or modified
	if parameter.ConfigurationId == "FakeSelectCityStates" then -- or parameter.ParameterId == "HideSelectCityStates"
		if (not ConfigYnAMP.IsDatabaseChanged) then
			return false
		end
	end
	--]]
	
	--
	-- Hide unavailable Leaders from Ban list
	if IsLeaderType[parameter.ConfigurationId] then
		ParameterBackup(parameter) -- to save/restore each leader value even when the setting is hidden
		local leaderType = parameter.ConfigurationId
		if not availableLeaderList[leaderType] then
			return false
		end
	end
	
	--[[
	-- deprecated code related to the old CS selection method
	--
	-- Save/Restore CityState selection list
	-- Hide CityState without TSL from list
	if IsMinorLeaderType[parameter.ConfigurationId] then
		ParameterBackup(parameter)
		if MapConfiguration.GetValue("OnlyLeadersWithTSL") then
			local args				= {}
			args.leaderType			= parameter.ConfigurationId
			args.civilizationType	= LeadersCivilizations[parameter.ConfigurationId]
			if not HasTSL(args) then--(leaderType, mapName, playerDomain, civilizationType)
				return false
			end
		end
	end
	--]]
	
	return OldGetRelevantParameters(o, parameter);
end

-- ===========================================================================
-- for player, create list on start button and fill selection using a mod selection
-- but this could be useful for preventing selection of civs without TSL when the DB is loaded
-------------------------------------------------------------------------------
SetupParameters.OldParameter_FilterValues = SetupParameters.Parameter_FilterValues
function SetupParameters:Parameter_FilterValues(parameter, values)
	values = self:OldParameter_FilterValues(parameter, values)
	
	-- Use the already filtered Leader list to build the list for random slots to use if the Ban Leader option is active
	-- We're not handling the banned leaders here as we still want them to be available for manual selection.
	if (parameter.ParameterId == "PlayerLeader" and self.PlayerId == 0) then -- and don't update for every player slots
		local curPlayerConfig 		= PlayerConfigurations[self.PlayerId]
		local curLeadertype			= curPlayerConfig:GetLeaderTypeName()
		for i,v in ipairs(values) do
			local leaderType = v.Value
			if (curLeadertype ~= leaderType) and (not v.Invalid) then
				if leaderType ~= "RANDOM" then
					availableLeaderList[leaderType] = true
				end
			else
				availableLeaderList[leaderType] = false
			end
		end
	end
	
	-- Filter leaders without TSL
	if (parameter.ParameterId == "PlayerLeader") then
		local newValues = {}
		if (MapConfiguration.GetValue("OnlyLeadersWithTSL")) then
			local ruleset		= GameConfiguration.GetValue("RULESET")
			local playerDomain	= ruleset and RulesetPlayerDomain[ruleset] or "Players:StandardPlayers"
			local mapName		= MapConfiguration.GetValue("MapName")
			for i, row in ipairs(values) do
				local reason		= nil
				local bHasTSL		= true	-- So that leaderType "RANDOM" is always valid
				local leaderType	= row.Value
				if leaderType ~= "RANDOM" then
					local args = {}
					args.leaderType 	= leaderType
					args.mapName 		= mapName
					args.playerDomain 	= playerDomain
					bHasTSL, reason 	= HasTSL(args)--(leaderType, mapName, playerDomain, civilizationType)(leaderType, mapName, playerDomain)
				end
				if(bHasTSL) then
				
					-- 10-Jan-2021
					-- Check below to remove the duplicate leaders/civilizations from the selection list as the UI doesn't notify/disable them now (introduced in the December 2020 patch or earlier)
					-- remove the check and just keep the table.insert and availableLeaderList lines when it's fixed
					if row.Invalid and row.InvalidReason ~= "LOC_SETUP_ERROR_NO_TSL" and row.InvalidReason ~= "LOC_SETUP_ERROR_NO_TSL_IN_SECTION" then
						--print("Removing invalid leader from list :", leaderType, row.Invalid, row.InvalidReason)
					else
						table.insert(newValues, row)
						availableLeaderList[leaderType] = true
					end
				else
					local copy = {}

					-- Copy data from value.
					for k,v in pairs(row) do
						copy[k] = v
					end

					-- Mark value as invalid.
					copy.Invalid 		= true
					copy.InvalidReason 	= reason
					-- 10-Jan-2021
					-- Line below commented out to remove the invalid leaders/civilizations from the selection list as the UI doesn't notify/disable them now (introduced in the December 2020 patch or earlier)
					-- uncomment this line when the display bug has been fixed by Firaxis
					--table.insert(newValues, copy) 
					availableLeaderList[leaderType] = false
				end
			end
			return newValues
		-- fix <<<<<
		-- 10-Jan-2021
		-- This section remove the duplicate leaders/civilizations from the selection list as the UI doesn't notify/disable them now (introduced in the December 2020 patch or earlier)
		-- you can remove it when the bug is fixed
		else
			---[[
			for i, row in ipairs(values) do
				if row.Invalid or row.Value == "RANDOM_POOL1" or row.Value == "RANDOM_POOL2" then
					--print("Removing invalid leader from list :", row.Value, row.Invalid, row.InvalidReason)
				else
					table.insert(newValues, row)
				end
			end
			return newValues
			--]]
		-- fix >>>>>
		end
		
	end
	---[[
	-- Hack to fix the value of the CityStates SortIndex in parameter (it doesn't use the value from the Configuration Database, but the value from the game's XML)
	if (parameter.ParameterId == "CityStates") then
		if parameter.SortIndex ~= CityStatesSortIndex then
			print("Fixing the SortIndex of the CityStates parameter to use Configuration DB value, parameter says "..tostring(parameter.SortIndex).." while DB is "..tostring(CityStatesSortIndex))
			parameter.SortIndex = CityStatesSortIndex
		end
	end
	
	-- Filter CityStates without TSL for the new Picker screen
	if (parameter.ParameterId == "CityStates") and MapConfiguration.GetValue("OnlyLeadersWithTSL") then
		local newValues 	= {}
		local mapName		= MapConfiguration.GetValue("MapName")
		for i, row in ipairs(values) do
			local reason		= nil
			local bHasTSL			= true	-- So that leaderType "RANDOM" is always valid
			local civilizationType	= row.Value
			
			local args = {}
			args.civilizationType 	= row.Value
			args.leaderType 		= LeadersCivilizations[row.Value]
			args.mapName 			= mapName
			bHasTSL, reason 		= HasTSL(args)
				
			if(bHasTSL) then
				table.insert(newValues, row)
			end
		end
		return newValues
	end
	--]]
	return values
end


function InitializeYnAMP()
	bFinishedGameplayContentConfigure = true

	currentSelectedNumberMajorCivs = GameConfiguration.GetParticipatingPlayerCount()
	print("Initial player count =  "..tostring(currentSelectedNumberMajorCivs))
	GameConfiguration.SetValue("MajorCivilizationsCount", currentSelectedNumberMajorCivs)
	
	Events.FinishedGameplayContentConfigure.Remove(InitializeYnAMP)
end
Events.FinishedGameplayContentConfigure.Add(InitializeYnAMP)

-- Neutralize the CS count control in the CS picker screen as we have multiple possible applications for the selection
local CityStateConfirmButton = nil
function UnlockCityStateConfirmButton()
	local CityStateConfirmButton = CityStateConfirmButton or ContextPtr:LookUpControl("/FrontEnd/MainMenu/AdvancedSetup/CityStatePicker/ConfirmButton/")
	if CityStateConfirmButton and CityStateConfirmButton:IsDisabled() then
		CityStateConfirmButton:SetDisabled(false)
		ContextPtr:LookUpControl("/FrontEnd/MainMenu/AdvancedSetup/CityStatePicker/CountWarning/"):SetText("")
	end
end
Events.GameCoreEventPublishComplete.Add(UnlockCityStateConfirmButton)


-- ===========================================================================
-- Mod Compatibility (addon files must be imported in both <FrontEnd> and <InGame>
-- ===========================================================================
print("Including AdvancedSetup_* files...")
include("AdvancedSetup_", true);


-- YnAMP >>>>>
Initialize();