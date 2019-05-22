-------------------------------------------------
-- Game Setup Logic
-------------------------------------------------
include( "InstanceManager" );
include ("SetupParameters");

-- Instance managers for dynamic game options.
g_BooleanParameterManager = InstanceManager:new("BooleanParameterInstance", "CheckBox", Controls.CheckBoxParent);
g_PullDownParameterManager = InstanceManager:new("PullDownParameterInstance", "Root", Controls.PullDownParent);
g_SliderParameterManager = InstanceManager:new("SliderParameterInstance", "Root", Controls.SliderParent);
g_StringParameterManager = InstanceManager:new("StringParameterInstance", "StringRoot", Controls.EditBoxParent);

g_ParameterFactories = {};

-- This is a mapping of instanced controls to their parameters.
-- It's used to cross reference the parameter from the control
-- in order to sort that control.
g_SortingMap = {};

-------------------------------------------------------------------------------
-- Determine which UI stack the parameters should be placed in.
-------------------------------------------------------------------------------
function GetControlStack(group)
	local triage = {

		["BasicGameOptions"] = Controls.PrimaryParametersStack,
		["GameOptions"] = Controls.PrimaryParametersStack,
		["BasicMapOptions"] = Controls.PrimaryParametersStack,
		["MapOptions"] = Controls.PrimaryParametersStack,
		["Victories"] = Controls.VictoryParameterStack,
		["AdvancedOptions"] = Controls.SecondaryParametersStack,
		-- YnAMP <<<<<
		["ScenarioOptions"] = Controls.ScenarioParametersStack,
		["CityStatesOptions"] = Controls.CityStatesParametersStack,
		-- YnAMP >>>>>
	};

	-- Triage or default to advanced.
	return triage[group];
end

-------------------------------------------------------------------------------
-- This function wrapper allows us to override this function and prevent
-- network broadcasts for every change made - used currently in Options.lua
-------------------------------------------------------------------------------
function BroadcastGameConfigChanges()
	Network.BroadcastGameConfig();
end

-------------------------------------------------------------------------------
-- Parameter Hooks
-------------------------------------------------------------------------------
function Parameters_Config_EndWrite(o, config_changed)
	SetupParameters.Config_EndWrite(o, config_changed);
	
	-- Dispatch a Lua event notifying that the configuration has changed.
	-- This will eventually be handled by the configuration layer itself.
	if(config_changed) then
		SetupParameters_Log("Marking Configuration as Changed.");
		if(GameSetup_ConfigurationChanged) then
			GameSetup_ConfigurationChanged();
		end
	end
end

function GameParameters_SyncAuxConfigurationValues(o, parameter)
	local result = SetupParameters.Parameter_SyncAuxConfigurationValues(o, parameter);
	
	-- If we don't already need to resync and the parameter is MapSize, perform additional checks.
	if(not result and parameter.ParameterId == "MapSize" and MapSize_ValueNeedsChanging) then
		return MapSize_ValueNeedsChanging(parameter);
	end

	return result;
end

function GameParameters_WriteAuxParameterValues(o, parameter)
	SetupParameters.Config_WriteAuxParameterValues(o, parameter);

	-- Some additional work if the parameter is MapSize.
	if(parameter.ParameterId == "MapSize" and MapSize_ValueChanged) then	
		MapSize_ValueChanged(parameter);
	end
	if(parameter.ParameterId == "Ruleset" and GameSetup_PlayerCountChanged) then
		GameSetup_PlayerCountChanged();
	end
end

-------------------------------------------------------------------------------
-- Hook to determine whether a parameter is relevant to this setup.
-- Parameters not relevant will be completely ignored.
-------------------------------------------------------------------------------
function GetRelevantParameters(o, parameter)

	-- If we have a player id, only care about player parameters.
	if(o.PlayerId ~= nil and parameter.ConfigurationGroup ~= "Player") then
		return false;

	-- If we don't have a player id, ignore any player parameters.
	elseif(o.PlayerId == nil and parameter.ConfigurationGroup == "Player") then
		return false;

	elseif(not GameConfiguration.IsAnyMultiplayer()) then
		return parameter.SupportsSinglePlayer;

	elseif(GameConfiguration.IsHotseat()) then
		return parameter.SupportsHotSeat;

	elseif(GameConfiguration.IsLANMultiplayer()) then
		return parameter.SupportsLANMultiplayer;

	elseif(GameConfiguration.IsInternetMultiplayer()) then
		return parameter.SupportsInternetMultiplayer;

	elseif(GameConfiguration.IsPlayByCloud()) then
		return parameter.SupportsPlayByCloud;
	end
	
	return true;
end


function GameParameters_UI_DefaultCreateParameterDriver(o, parameter, parent)

	if(parent == nil) then
		parent = GetControlStack(parameter.GroupId);
	end

	local control;
	
	-- If there is no parent, don't visualize the control.  This is most likely a player parameter.
	if(parent == nil) then
		return;
	end;

	if(parameter.Domain == "bool") then
		local c = g_BooleanParameterManager:GetInstance();	
		
		-- Store the root control, NOT the instance table.
		g_SortingMap[tostring(c.CheckBox)] = parameter;		
			
		--c.CheckBox:GetTextButton():SetText(parameter.Name);
		c.CheckBox:SetText(parameter.Name);
		c.CheckBox:SetToolTipString(parameter.Description);
		c.CheckBox:RegisterCallback(Mouse.eLClick, function()
			o:SetParameterValue(parameter, not c.CheckBox:IsSelected());
			BroadcastGameConfigChanges();
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
				g_BooleanParameterManager:ReleaseInstance(c);
			end,
		};

	elseif(parameter.Domain == "int" or parameter.Domain == "uint" or parameter.Domain == "text") then
		local c = g_StringParameterManager:GetInstance();		

		-- Store the root control, NOT the instance table.
		g_SortingMap[tostring(c.StringRoot)] = parameter;
				
		c.StringName:SetText(parameter.Name);
		c.StringRoot:SetToolTipString(parameter.Description);
		c.StringEdit:SetEnabled(true);

		local canChangeEnableState = true;

		if(parameter.Domain == "int") then
			c.StringEdit:SetNumberInput(true);
			c.StringEdit:SetMaxCharacters(16);
			c.StringEdit:RegisterCommitCallback(function(textString)
				o:SetParameterValue(parameter, tonumber(textString));	
				BroadcastGameConfigChanges();
			end);
		elseif(parameter.Domain == "uint") then
			c.StringEdit:SetNumberInput(true);
			c.StringEdit:SetMaxCharacters(16);
			c.StringEdit:RegisterCommitCallback(function(textString)
				local value = math.max(tonumber(textString) or 0, 0);
				o:SetParameterValue(parameter, value);	
				BroadcastGameConfigChanges();
			end);
		else
			c.StringEdit:SetNumberInput(false);
			c.StringEdit:SetMaxCharacters(64);
			if UI.HasFeature("TextEntry") == true then
				c.StringEdit:RegisterCommitCallback(function(textString)
					o:SetParameterValue(parameter, textString);	
					BroadcastGameConfigChanges();
				end);
			else
				canChangeEnableState = false;
				c.StringEdit:SetEnabled(false);
			end
		end

		c.StringRoot:ChangeParent(parent);

		control = {
			Control = c,
			UpdateValue = function(value)
				c.StringEdit:SetText(value);
			end,
			SetEnabled = function(enabled)
				if canChangeEnableState then
					c.StringRoot:SetDisabled(not enabled);
					c.StringEdit:SetDisabled(not enabled);
				end
			end,
			SetVisible = function(visible)
				c.StringRoot:SetHide(not visible);
			end,
			Destroy = function()
				g_StringParameterManager:ReleaseInstance(c);
			end,
		};
	elseif (parameter.Values and parameter.Values.Type == "IntRange") then -- Range
		
		local minimumValue = parameter.Values.MinimumValue;
		local maximumValue = parameter.Values.MaximumValue;

		-- Get the UI instance
		local c = g_SliderParameterManager:GetInstance();	

		-- Store the root control, NOT the instance table.
		g_SortingMap[tostring(c.Root)] = parameter;

		c.Root:ChangeParent(parent);
		if c.StringName ~= nil then
			c.StringName:SetText(parameter.Name);
		end

		c.OptionTitle:SetText(parameter.Name);
		c.Root:SetToolTipString(parameter.Description);
		c.OptionSlider:RegisterSliderCallback(function()
			local stepNum = c.OptionSlider:GetStep();
			
			-- This method can get called pretty frequently, try and throttle it.
			if(parameter.Value ~= minimumValue + stepNum) then
				o:SetParameterValue(parameter, minimumValue + stepNum);
				BroadcastGameConfigChanges();
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
				g_SliderParameterManager:ReleaseInstance(c);
			end,
		};	
	elseif (parameter.Values) then -- MultiValue
		
		-- Get the UI instance
		local c = g_PullDownParameterManager:GetInstance();	

		-- Store the root control, NOT the instance table.
		g_SortingMap[tostring(c.Root)] = parameter;

		c.Root:ChangeParent(parent);
		if c.StringName ~= nil then
			c.StringName:SetText(parameter.Name);
		end

		local cache = {};

		control = {
			Control = c,
			Cache = cache,
			UpdateValue = function(value)
				local valueText = value and value.Name or nil;
				local valueDescription = value and value.Description or nil
				if(cache.ValueText ~= valueText or cache.ValueDescription ~= valueDescription) then
					local button = c.PullDown:GetButton();
					button:SetText(valueText);
					button:SetToolTipString(valueDescription);
					cache.ValueText = valueText;
					cache.ValueDescription = valueDescription;
				end
			end,
			UpdateValues = function(values)
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
					c.PullDown:ClearEntries();			
					for i,v in ipairs(values) do
						local entry = {};
						c.PullDown:BuildEntry( "InstanceOne", entry );
						entry.Button:SetText(v.Name);
						entry.Button:SetToolTipString(Locale.Lookup(v.RawDescription));

						entry.Button:RegisterCallback(Mouse.eLClick, function()
							o:SetParameterValue(parameter, v);
							BroadcastGameConfigChanges();
						end);
					end
					cache.Values = values;
					c.PullDown:CalculateInternals();
				end
			end,
			SetEnabled = function(enabled, parameter)
				c.PullDown:SetDisabled(not enabled or #parameter.Values <= 1);
			end,
			SetVisible = function(visible)
				c.Root:SetHide(not visible);
			end,
			Destroy = function()
				g_PullDownParameterManager:ReleaseInstance(c);
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
	else
		control = GameParameters_UI_DefaultCreateParameterDriver(o, parameter);
	end

	o.Controls[parameter.ParameterId] = control;
end


-- Called whenever a parameter is no longer relevant and should be destroyed.
function UI_DestroyParameter(o, parameter)
	local control = o.Controls[parameter.ParameterId];
	if(control) then
		if(control.Destroy) then
			control.Destroy();
		end

		for i,v in ipairs(control) do
			if(v.Destroy) then
				v.Destroy();
			end	
		end
		o.Controls[parameter.ParameterId] = nil;
	end
end

-- Called whenever a parameter's possible values have been updated.
function UI_SetParameterPossibleValues(o, parameter)
	local control = o.Controls[parameter.ParameterId];
	if(control) then
		if(control.UpdateValues) then
			control.UpdateValues(parameter.Values, parameter);
		end

		for i,v in ipairs(control) do
			if(v.UpdateValues) then
				v.UpdateValues(parameter.Values, parameter);
			end	
		end
	end
end

-- Called whenever a parameter's value has been updated.
function UI_SetParameterValue(o, parameter)
	local control = o.Controls[parameter.ParameterId];
	if(control) then
		if(control.UpdateValue) then
			control.UpdateValue(parameter.Value, parameter);
		end

		for i,v in ipairs(control) do
			if(v.UpdateValue) then
				v.UpdateValue(parameter.Value, parameter);
			end	
		end
	end
end

-- Called whenever a parameter is enabled.
function UI_SetParameterEnabled(o, parameter)
	local control = o.Controls[parameter.ParameterId];
	if(control) then
		if(control.SetEnabled) then
			control.SetEnabled(parameter.Enabled, parameter);
		end

		for i,v in ipairs(control) do
			if(v.SetEnabled) then
				v.SetEnabled(parameter.Enabled, parameter);
			end	
		end
	end
end

-- Called whenever a parameter is visible.
function UI_SetParameterVisible(o, parameter)
	local control = o.Controls[parameter.ParameterId];
	if(control) then
		if(control.SetVisible) then
			control.SetVisible(parameter.Visible, parameter);
		end

		for i,v in ipairs(control) do
			if(v.SetVisible) then
				v.SetVisible(parameter.Visible, parameter);
			end	
		end
	end
end

-------------------------------------------------------------------------------
-- Called after a refresh was performed.
-- Update all of the game option stacks and scroll panels.
-------------------------------------------------------------------------------
function GameParameters_UI_AfterRefresh(o)

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


	Controls.PrimaryParametersStack:SortChildren(sort);
	Controls.SecondaryParametersStack:SortChildren(sort);
	Controls.VictoryParameterStack:SortChildren(sort);

	Controls.PrimaryParametersStack:CalculateSize();
	Controls.PrimaryParametersStack:ReprocessAnchoring();

	Controls.SecondaryParametersStack:CalculateSize();
	Controls.SecondaryParametersStack:ReprocessAnchoring();

	Controls.VictoryParameterStack:CalculateSize();
	Controls.VictoryParameterStack:ReprocessAnchoring();

	Controls.ParametersStack:CalculateSize();
	Controls.ParametersStack:ReprocessAnchoring();

	if Controls.ParametersScrollPanel then
		Controls.ParametersScrollPanel:CalculateInternalSize();
	end
end

-------------------------------------------------------------------------------
-- Perform any additional operations on relevant parameters.
-- In this case, adjust the parameter group so that they are sorted properly.
-------------------------------------------------------------------------------
function GameParameters_PostProcess(o, parameter)
	
	-- Move all groups into 1 singular group for sorting purposes.
	--local triage = {
		--["BasicGameOptions"] = "GameOptions",
		--["BasicMapOptions"] = "GameOptions",
		--["MapOptions"] = "GameOptions",
	--};
--
	--parameter.GroupId = triage[parameter.GroupId] or parameter.GroupId;
end

-- Generate the game setup parameters and populate the UI.
function BuildGameSetup(createParameterFunc)

	-- If BuildGameSetup is called twice, call HideGameSetup to reset things.
	if(g_GameParameters) then
		HideGameSetup();
	end

	print("Building Game Setup");

	g_GameParameters = SetupParameters.new();
	g_GameParameters.Config_EndWrite = Parameters_Config_EndWrite;
	g_GameParameters.Parameter_GetRelevant = GetRelevantParameters;
	g_GameParameters.Parameter_PostProcess = GameParameters_PostProcess;
	g_GameParameters.Parameter_SyncAuxConfigurationValues = GameParameters_SyncAuxConfigurationValues;
	g_GameParameters.Config_WriteAuxParameterValues = GameParameters_WriteAuxParameterValues;
	g_GameParameters.UI_BeforeRefresh = UI_BeforeRefresh;
	g_GameParameters.UI_AfterRefresh = GameParameters_UI_AfterRefresh;
	g_GameParameters.UI_CreateParameter = createParameterFunc ~= nil and createParameterFunc or GameParameters_UI_CreateParameter;
	g_GameParameters.UI_DestroyParameter = UI_DestroyParameter;
	g_GameParameters.UI_SetParameterPossibleValues = UI_SetParameterPossibleValues;
	g_GameParameters.UI_SetParameterValue = UI_SetParameterValue;
	g_GameParameters.UI_SetParameterEnabled = UI_SetParameterEnabled;
	g_GameParameters.UI_SetParameterVisible = UI_SetParameterVisible;

	-- Optional overrides.
	if(GameParameters_FilterValues) then
		g_GameParameters.Default_Parameter_FilterValues = g_GameParameters.Parameter_FilterValues;
		g_GameParameters.Parameter_FilterValues = GameParameters_FilterValues;
	end

	g_GameParameters:Initialize();
	g_GameParameters:FullRefresh();
end

-- Generate the game setup parameters and populate the UI.
function BuildHeadlessGameSetup()

	-- If BuildGameSetup is called twice, call HideGameSetup to reset things.
	if(g_GameParameters) then
		HideGameSetup();
	end

	print("Building Headless Game Setup");

	g_GameParameters = SetupParameters.new();
	g_GameParameters.Config_EndWrite = Parameters_Config_EndWrite;
	g_GameParameters.Parameter_GetRelevant = GetRelevantParameters;
	g_GameParameters.Parameter_PostProcess = GameParameters_PostProcess;
	g_GameParameters.Parameter_SyncAuxConfigurationValues = GameParameters_SyncAuxConfigurationValues;
	g_GameParameters.Config_WriteAuxParameterValues = GameParameters_WriteAuxParameterValues;

	g_GameParameters.UpdateVisualization = function() end
	g_GameParameters.UI_AfterRefresh = nil;
	g_GameParameters.UI_CreateParameter = nil;
	g_GameParameters.UI_DestroyParameter = nil;
	g_GameParameters.UI_SetParameterPossibleValues = nil;
	g_GameParameters.UI_SetParameterValue = nil;
	g_GameParameters.UI_SetParameterEnabled = nil;
	g_GameParameters.UI_SetParameterVisible = nil;

	-- Optional overrides.
	if(GameParameters_FilterValues) then
		g_GameParameters.Default_Parameter_FilterValues = g_GameParameters.Parameter_FilterValues;
		g_GameParameters.Parameter_FilterValues = GameParameters_FilterValues;
	end

	g_GameParameters:Initialize();
end

-- Hide game setup parameters.
function HideGameSetup(hideParameterFunc)
	print("Hiding Game Setup");

	-- Shutdown and nil out the game parameters.
	if(g_GameParameters) then
		g_GameParameters:Shutdown();
		g_GameParameters = nil;
	end

	-- Reset all UI instances.
	if(hideParameterFunc == nil) then
		g_BooleanParameterManager:ResetInstances();
		g_PullDownParameterManager:ResetInstances();
		g_SliderParameterManager:ResetInstances();
		g_StringParameterManager:ResetInstances();
	else
		hideParameterFunc();
	end
end


function MapSize_ValueNeedsChanging(p)
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
			defPlayers = v.DefaultPlayers;
			minCityStates = v.MinCityStates;
			maxCityStates = v.MaxCityStates;
			defCityStates = v.DefaultCityStates;
		end
	end

	-- TODO: Add Min/Max city states, set defaults.
	if(MapConfiguration.GetMinMajorPlayers() ~= minPlayers) then
		SetupParameters_Log("Min Major Players: " .. MapConfiguration.GetMinMajorPlayers() .. " should be " .. minPlayers);
		return true;
	elseif(MapConfiguration.GetMaxMajorPlayers() ~= maxPlayers) then
		SetupParameters_Log("Max Major Players: " .. MapConfiguration.GetMaxMajorPlayers() .. " should be " .. maxPlayers);
		return true;
	elseif(MapConfiguration.GetMinMinorPlayers() ~= minCityStates) then
		SetupParameters_Log("Min Minor Players: " .. MapConfiguration.GetMinMinorPlayers() .. " should be " .. minCityStates);
		return true;
	elseif(MapConfiguration.GetMaxMinorPlayers() ~= maxCityStates) then
		SetupParameters_Log("Max Minor Players: " .. MapConfiguration.GetMaxMinorPlayers() .. " should be " .. maxCityStates);
		return true;
	end

	return false;
end

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
			defPlayers = v.DefaultPlayers;
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
