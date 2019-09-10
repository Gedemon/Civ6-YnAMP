include("InstanceManager");
include("LobbyTypes"); --MPLobbyMode

include("PlayerSetupLogic"); -- For PlayNow

-- ===========================================================================
--	Members
-- ===========================================================================
local m_mainOptionIM :	table = InstanceManager:new( "MenuOption", "Top", Controls.MainMenuOptionStack );
local m_subOptionIM :	table = InstanceManager:new( "MenuOption", "Top", Controls.SubMenuOptionStack );
local m_preSaveMainMenuOptions:	table = {};
local m_defaultMainMenuOptions:	table = {};
local m_singlePlayerListOptions:table = {};
local m_hasSaves:boolean = false;
local m_cloudNotify:number = CloudNotifyTypes.CLOUDNOTIFY_NONE;
local m_hasCloudUnseenComplete:boolean = false; -- Do we have completed PlayByCloud games that we haven't seen yet?
local m_checkedCloudNotify:boolean = false;	-- Have we checked for cloud notifications?
local m_currentOptions:table = {};		--Track which main menu options are being displayed and selected. Indices follow the format of {optionControl:table, isSelected:boolean}
local m_initialPause = 1.5;				--How long to wait before building the main menu options when the game first loads
local m_internetButton:table = nil;		--Cache internet button so it can be updated when online status events fire
local m_multiplayerButton:table = nil;	--Cache multiplayer button so it can be updated if a new cloud turn comes in.
local m_cloudGamesButton:table = nil;	--Cache cloud games button so it can be updated if a new cloud turn comes in.
local m_resumeButton:table = nil;		--Cache resume button so it can be updated when FileListQueryResults event fires
local m_scenariosButton:table = nil;	--Cache scenarios button so it can be updated later.
local m_matchMakeButton:table = nil;	--Cache CivRoyale matchmaking button so it can be updated later.
local m_howToRoyaleControl:table = nil;	--Cache CivRoyale how-to button so that it can be updated later.
local m_isQuitting :boolean = false;	-- Is the application shutting down (after user approval.)

g_LogoTexture = nil;	-- Custom Logo texture override.
g_LogoMovie = nil;		-- Custom Logo movie override.
-- YnAMP <<<<<
g_XP1WasEnabled = nil;					-- Track whether the expansion was enabled to avoid resetting the movie/logo.
g_XP2WasEnabled = nil;					-- Track whether the expansion was enabled to avoid resetting the movie/logo.

g_ModWasEnabled	= {}
print("Loading MainMenu.lua for YnAMP...")
print("Game version : ".. tostring(UI.GetAppVersion()))
-- YnAMP >>>>>

-- ===========================================================================
--	Constants
-- ===========================================================================
local PAUSE_INCREMENT = .18;			--How long to wait (in seconds) between main menu flyouts - length of the menu cascade
local TRACK_PADDING = 40;				--The amount of Y pixels to add to the track on top of the list height
local OPTION_SEEN_CIVROYALE_INTRO :string = "HasSeenCivRoyaleIntro";	-- Option key for having seen the CivRoyale How to Play screen.

-- ===========================================================================
--	Globals
-- ===========================================================================
g_LastFileQueryRequestID = nil;			-- The file list ID used to determine whether the call-back is for us or not.
g_MostRecentSave = nil;					-- The most recent single player save a user has (locally)

-- ===========================================================================
-- Button Handlers
-- ===========================================================================
function OnResumeGame()
	if(g_MostRecentSave) then
		local serverType : number = ServerType.SERVER_TYPE_NONE;
		Network.LeaveGame();
		Network.LoadGame(g_MostRecentSave, serverType);
	end
end

function UpdateResumeGame(resumeButton)
	if (resumeButton ~= nil) then
		m_resumeButton = resumeButton;
	end
	if(m_resumeButton ~= nil) then
		if(g_MostRecentSave ~= nil) then

			local mods = g_MostRecentSave.RequiredMods or {};
	
			-- Test for errors.
			-- Will return a combination array/map of any errors regarding this combination of mods.
			-- Array messages are generalized error codes regarding the set.
			-- Map messages are error codes specific to the mod Id.
			local errors = Modding.CheckRequirements(mods, SaveTypes.SINGLE_PLAYER);
			local success = (errors == nil or errors.Success);

			m_resumeButton.Top:SetHide(not success);
		else
			m_resumeButton.Top:SetHide(true);
		end
	end
end

function UpdateScenariosButton(button)
	if(button) then 
		m_scenariosButton = button; 
	end

	if(button) then
		button.Top:SetHide(true);
		local query = "SELECT 1 from Rulesets where IsScenario = 1 and SupportsSinglePlayer = 1 LIMIT 1";
		local results = DB.ConfigurationQuery(query);
		if(results and #results > 0) then
			button.Top:SetHide(false);
		end
	end
end


function OnPlayCiv6()
	
	-- Avoid double clicks.
	if(_ClickedPlayNow) then 
		return;
	end
	_ClickedPlayNow = true;
	
	local save = Options.GetAppOption("Debug", "PlayNowSave");
	if(save ~= nil) then
		Network.LeaveGame();

		local serverType : number = ServerType.SERVER_TYPE_NONE;
		Network.LoadGame(save, serverType);
	else

		-- Reset the game configuration.
		GameConfiguration.SetToDefaults();
		-- Kludge:  SetToDefaults assigns the ruleset to be standard.
		-- Clear this value so that the setup parameters code can guess the best 
		-- default.
		GameConfiguration.SetValue("RULESET", nil);

		-- Many game setup values are driven by Lua-implemented parameter logic.

		BuildHeadlessGameSetup();
		RebuildPlayerParameters(true);
		GameSetup_RefreshParameters();

		-- Cleanup
		ReleasePlayerParameters();
		HideGameSetup();

		Network.HostGame(ServerType.SERVER_TYPE_NONE);
	end
end

-- ===========================================================================
function OnAdvancedSetup()
	GameConfiguration.SetToDefaults();
	-- Kludge:  SetToDefaults assigns the ruleset to be standard.
	-- Clear this value so that the setup parameters code can guess the best 
	-- default.
	GameConfiguration.SetValue("RULESET", nil);
	-- Reset the load game server type, in case a configuration is loaded.
	LuaEvents.MainMenu_SetLoadGameServerType(ServerType.SERVER_TYPE_NONE);
	UIManager:QueuePopup(Controls.AdvancedSetup, PopupPriority.Current);
end

-- ===========================================================================
function OnScenarioSetup()
	GameConfiguration.SetToDefaults();
	-- Kludge:  SetToDefaults assigns the ruleset to be standard.
	-- Clear this value so that the setup parameters code can guess the best 
	-- default.
	GameConfiguration.SetValue("RULESET", nil);
	-- Reset the load game server type, in case a configuration is loaded.
	LuaEvents.MainMenu_SetLoadGameServerType(ServerType.SERVER_TYPE_NONE);
	UIManager:QueuePopup(Controls.ScenarioSetup, PopupPriority.Current);
end

-- ===========================================================================
function OnLoadSinglePlayer()
	GameConfiguration.SetToDefaults();
	LuaEvents.MainMenu_SetLoadGameServerType(ServerType.SERVER_TYPE_NONE);
	UIManager:QueuePopup(Controls.LoadGameMenu, PopupPriority.Current);		
	Close();
end

-- ===========================================================================
function OnOptions()
	UIManager:QueuePopup(Controls.Options, PopupPriority.Current);
	Close();
end

-- ===========================================================================
function OnMods()
	GameConfiguration.SetToDefaults();
	UIManager:QueuePopup(Controls.ModsContext, PopupPriority.Current);
	Close();
end

function OnHallofFame()
	UIManager:QueuePopup(Controls.HallofFame, PopupPriority.Current);
	Close();
end

-- ===========================================================================
function OnPlayMultiplayer()
	UIManager:QueuePopup(Controls.MultiplayerSelect, PopupPriority.Current);
	Close();
end

-- ===========================================================================
function OnMy2KLogin()
	Events.Begin2KLoginProcess();
	Close();
end

-- Allow for cycling through the MotD text languages.  For previewing only.
local ms_MotDIndex = nil;

-- ===========================================================================
function UpdateMotD()
	
	local bShow = false;
	-- Have a MotD that the user has not dismissed (its still open)?
	local MotDData = UI.GetPushData("MotD", 0, PushDataSearchOptions.IsOpen, ms_MotDIndex);

	if ms_MotDIndex ~= nil and MotDData.Message == "" then
		ms_MotDIndex = nil;
		MotDData = UI.GetPushData("MotD", 0, PushDataSearchOptions.IsOpen, ms_MotDIndex);
	end

	if MotDData ~= nil and MotDData.Message ~= nil then
		Controls.MotDText:SetText(MotDData.Message);
		Controls.MotDText:DoAutoSize();
		bShow = true;
	end
			
	Controls.MotDContainter:SetShow( bShow );
end

-- ===========================================================================
function OnMarketingPushDataUpdated()
	UpdateMotD();
end

-- ===========================================================================
--	Engine Event
-- ===========================================================================
function OnUserRequestClose()
    LuaEvents.MainMenu_UserRequestClose();
end

-- ===========================================================================
--	EVENT
--	Application has been confirmed to close.
-- ===========================================================================
function OnUserConfirmedClose()
	m_isQuitting = true;
	Controls.SubMenuSlide:SetAlpha( 0 ); -- Don't toggle visibility so surrounding stack doesn't collapse.
end

    -- ===========================================================================
function OnGraphicsBenchmark()
	Benchmark.RunGraphicsBenchmark("GraphicsBenchmark.Civ6Save");
end

function OnExp2GraphicsBenchmark()
	Benchmark.RunExp2GraphicsBenchmark("XP2Benchmark.Civ6Save", SaveDirectories.BENCHMARK, "Automation_StandardTests.lua; Automation_BenchmarkCamera_Capitals.lua");
end

function OnAIBenchmark()
	Benchmark.RunAIBenchmark("AIBenchmark.Civ6Save");
end

function OnExp2AIBenchmark()
	Benchmark.RunExp2AIBenchmark("XP2Benchmark.Civ6Save");
end

-- ===========================================================================
function OnCredits()
	UIManager:QueuePopup( Controls.CreditsScreen, PopupPriority.Current );
	Close();
end

-- ===========================================================================
function OnCloudTurnCheckComplete(notifyType :number, turnGameName :string, inGames :boolean)
	m_cloudNotify = notifyType;
	if (not ContextPtr:IsHidden()) then
		UpdateCloudGamesButton();
		UpdateMultiplayerButton();
	end
end

-- ===========================================================================
function OnCloudUnseenCompleteCheckComplete(haveCompletedGame :boolean, gameName :string, matchID :number)
	m_hasCloudUnseenComplete = haveCompletedGame;
	if (not ContextPtr:IsHidden()) then
		UpdateCloudGamesButton();
		UpdateMultiplayerButton();
	end
end

-- ===========================================================================
-- Multiplayer Select Screen
-- ===========================================================================
local InternetButtonOnlineStr : string = Locale.Lookup("LOC_MULTIPLAYER_INTERNET_GAME_TT");
local InternetButtonOfflineStr : string = Locale.Lookup("LOC_MULTIPLAYER_INTERNET_GAME_OFFLINE_TT");
local CloudButtonTTStr : string = Locale.Lookup("LOC_MULTIPLAYER_CLOUD_GAME_TT");
local CloudNotLoggedInTTStr : string = Locale.Lookup("LOC_MULTIPLAYER_CLOUD_GAME_NO_LOGIN_TT");
local CloudButtonUnseenCompleteGameTTStr : string = Locale.Lookup("LOC_MULTIPLAYER_CLOUD_UNSEEN_COMPLETE_GAME_TT");
local CloudButtonHaveTurnTTStr : string = Locale.Lookup("LOC_MULTIPLAYER_CLOUD_GAME_HAVE_TURN_TT");
local CloudButtonGameReadyTTStr: string = Locale.Lookup("LOC_MULTIPLAYER_CLOUD_GAME_GAME_READY_TT");
local CloudButtonNewMPModeTTStr : string = Locale.Lookup("LOC_MULTIPLAYER_CLOUD_GAME_NEW_MODE_TT");
local MultiplayerButtonTTStr : string = Locale.Lookup("LOC_MAINMENU_MULTIPLAYER_BASE_TT");
local MultiplayerButtonHaveTurnTTStr : string = Locale.Lookup("LOC_MAINMENU_MULTIPLAYER_HAVE_CLOUD_TURN_TT");
local MultiplayerButtonGameReadyTTStr : string = Locale.Lookup("LOC_MAINMENU_MULTIPLAYER_GAME_READY_TT");
local MultiplayerButtonUnseenCompleteTTStr : string = Locale.Lookup("LOC_MAINMENU_MULTIPLAYER_UNSEEN_COMPLETE_GAME_TT");
local MultiplayerButtonNewMPModeTTStr : string = Locale.Lookup("LOC_MAINMENU_MULTIPLAYER_NEW_MP_MODE_TT");
local CivRoyaleButtonOnlineStr : string = Locale.Lookup("LOC_MULTIPLAYER_MATCHMAKE_CIVROYALE_TT");
local CivRoyaleButtonOfflineStr : string = Locale.Lookup("LOC_MULTIPLAYER_MATCHMAKE_CIVROYALE_OFFLINE_TT");


-- ===========================================================================
function OnInternet()
	LuaEvents.ChangeMPLobbyMode(MPLobbyTypes.STANDARD_INTERNET);
	UIManager:QueuePopup( Controls.Lobby, PopupPriority.Current );
	Close();	
end

-- ===========================================================================
function OnCivRoyaleMatchMake()
	local skipIntroScreen =  Options.GetUserOption("Tutorial", OPTION_SEEN_CIVROYALE_INTRO) == 1;
	if(skipIntroScreen) then
		StartMatchMaking();
	else
		LuaEvents.MainMenu_ShowCivRoyaleIntro();
	end
end

function OnCivRoyaleHowToPlay()
	LuaEvents.MainMenu_ShowCivRoyaleIntro();
end

function StartMatchMaking()
	GameConfiguration.SetToDefaults(GameModeTypes.INTERNET);	
	GameConfiguration.ClearEnabledMods();
	GameConfiguration.AddEnabledMods("F264EE10-F21B-4A9A-BBCD-D534E9843E90");
	GameConfiguration.SetRuleSet("RULESET_SCENARIO_CIV_ROYALE");

	-- Many game setup values are driven by Lua-implemented parameter logic.
	do
		-- Generate setup parameters that lack any sort of UI.
		BuildHeadlessGameSetup();
		RebuildPlayerParameters(true);

		-- Trigger a refresh.
		GameSetup_RefreshParameters();

		-- Cleanup.
		ReleasePlayerParameters();
		HideGameSetup();
	end

	GameConfiguration.SetMatchMaking(true);
	Network.MatchMake();
end

-- ===========================================================================
--	WB: This callback is complicated by these events which can happen at any time.
--	Because few other buttons in the shell function in this way, using a special 
--	variable to save this control (instead of a more general solution).
-- ===========================================================================
function UpdateAIBenchmark(buttonControl)
	if (buttonControl ~= nil) then
		m_aiButton = buttonControl;
	end
	
	if(m_aiButton ~= nil) then

		--Requires Montezuma DLC
		local allowed = false;
		local modId = "02A8BDDE-67EA-4D38-9540-26E685E3156E";
		local modHandle = Modding.GetModHandle(modId);
		if(modHandle ~= nil) then
			local modInfo = Modding.GetModInfo(modHandle);
			if(modInfo.Allowance ~= false) then
				allowed = true;
			end
		end

		local aiButtonTooltip = Locale.Lookup("LOC_BENCHMARK_AI_TT");

		if(allowed) then
			m_aiButton.OptionButton:SetDisabled(false);
			m_aiButton.Top:SetToolTipString(aiButtonTooltip);
			m_aiButton.ButtonLabel:SetColorByName( "ButtonCS" );
		else
			aiButtonTooltip = aiButtonTooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_BENCHMARK_AI_TT_ERROR");
			m_aiButton.OptionButton:SetDisabled(true);
			m_aiButton.Top:SetToolTipString(aiButtonTooltip);
			m_aiButton.ButtonLabel:SetColorByName( "ButtonDisabledCS" );
		end
	end
end

function UpdateExp2AIBenchmark(buttonControl)
	if (buttonControl ~= nil) then
		m_aiButton = buttonControl;
	end
	
	if(m_aiButton ~= nil) then

		--Requires expansion 2
		local allowed = false;
		local modId = "4873eb62-8ccc-4574-b784-dda455e74e68";
		local modHandle = Modding.GetModHandle(modId);
		if(modHandle ~= nil) then
			local modInfo = Modding.GetModInfo(modHandle);
			if(modInfo.Allowance ~= false) then
				allowed = true;
			end
		end

		local aiButtonTooltip = Locale.Lookup("LOC_BENCHMARK_EXP2_AI_TT");

		if(allowed) then
			m_aiButton.OptionButton:SetDisabled(false);
			m_aiButton.Top:SetToolTipString(aiButtonTooltip);
			m_aiButton.ButtonLabel:SetColorByName( "ButtonCS" );
		else
			aiButtonTooltip = aiButtonTooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_BENCHMARK_EXP2_AI_TT_ERROR");
			m_aiButton.OptionButton:SetDisabled(true);
			m_aiButton.Top:SetToolTipString(aiButtonTooltip);
			m_aiButton.ButtonLabel:SetColorByName( "ButtonDisabledCS" );
		end
	end
end

function UpdateExp2GraphicsBenchmark(buttonControl)
	if (buttonControl ~= nil) then
		m_aiButton = buttonControl;
	end
	
	if(m_aiButton ~= nil) then

		--Requires expansion 2
		local allowed = false;
		local modId = "4873eb62-8ccc-4574-b784-dda455e74e68";
		local modHandle = Modding.GetModHandle(modId);
		if(modHandle ~= nil) then
			local modInfo = Modding.GetModInfo(modHandle);
			if(modInfo.Allowance ~= false) then
				allowed = true;
			end
		end

		local aiButtonTooltip = Locale.Lookup("LOC_BENCHMARK_EXP2_GRAPHICS_TT");

		if(allowed) then
			m_aiButton.OptionButton:SetDisabled(false);
			m_aiButton.Top:SetToolTipString(aiButtonTooltip);
			m_aiButton.ButtonLabel:SetColorByName( "ButtonCS" );
		else
			aiButtonTooltip = aiButtonTooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_BENCHMARK_EXP2_GRAPHICS_TT_ERROR");
			m_aiButton.OptionButton:SetDisabled(true);
			m_aiButton.Top:SetToolTipString(aiButtonTooltip);
			m_aiButton.ButtonLabel:SetColorByName( "ButtonDisabledCS" );
		end
	end
end

function UpdateInternetControls()
	UpdateInternetButton();
	UpdateCivRoyaleMatchMakeButton();
end

function UpdateInternetButton(buttonControl: table)
	if (buttonControl ~=nil) then
		m_internetButton = buttonControl;
	end
	-- Internet available?
	if(m_internetButton ~= nil) then
		if (Network.IsInternetLobbyServiceAvailable()) then
			m_internetButton.OptionButton:SetDisabled(false);
			m_internetButton.Top:SetToolTipString(InternetButtonOnlineStr);
			m_internetButton.ButtonLabel:SetText(Locale.Lookup("LOC_MULTIPLAYER_INTERNET_GAME"));
			m_internetButton.ButtonLabel:SetColorByName( "ButtonCS" );
		else
			m_internetButton.OptionButton:SetDisabled(true);
			m_internetButton.Top:SetToolTipString(InternetButtonOfflineStr);
			m_internetButton.ButtonLabel:SetText(Locale.Lookup("LOC_MULTIPLAYER_INTERNET_GAME_OFFLINE"));
			m_internetButton.ButtonLabel:SetColorByName( "ButtonDisabledCS" );
		end
	end
end

function UpdateCivRoyaleHowToButton(buttonControl: table)
	if (buttonControl ~=nil) then
		m_howToRoyaleControl = buttonControl;
	end
	
	if(m_howToRoyaleControl ~= nil) then
		-- Is CivRoyale enabled?
		local id = "F264EE10-F21B-4A9A-BBCD-D534E9843E90";

		local enabled = Modding.IsModEnabled(id);
		m_howToRoyaleControl.Top:SetHide(not enabled);
	end
end

function UpdateCivRoyaleMatchMakeButton(buttonControl: table)
	if (buttonControl ~=nil) then
		m_matchMakeButton = buttonControl;
	end
	
	if(m_matchMakeButton ~= nil) then
		-- Is CivRoyale enabled?
		local id = "F264EE10-F21B-4A9A-BBCD-D534E9843E90";

		if(Modding.IsModEnabled(id)) then
			m_matchMakeButton.Top:SetHide(false);

			-- Internet available?
			if (Network.IsInternetLobbyServiceAvailable()) then
				m_matchMakeButton.OptionButton:SetDisabled(false);
				m_matchMakeButton.Top:SetToolTipString(CivRoyaleButtonOnlineStr);
				m_matchMakeButton.ButtonLabel:SetText(Locale.Lookup("LOC_MULTIPLAYER_MATCHMAKE_CIVROYALE"));
				m_matchMakeButton.ButtonLabel:SetColorByName( "ButtonCS" );
			else
				m_matchMakeButton.OptionButton:SetDisabled(true);
				m_matchMakeButton.Top:SetToolTipString(CivRoyaleButtonOfflineStr);
				m_matchMakeButton.ButtonLabel:SetText(Locale.Lookup("LOC_MULTIPLAYER_MATCHMAKE_CIVROYALE_OFFLINE"));
				m_matchMakeButton.ButtonLabel:SetColorByName( "ButtonDisabledCS" );
			end
		else
			m_matchMakeButton.Top:SetHide(true);
		end
	end
end

function UpdateCloudGamesButton(buttonControl: table)
	if (buttonControl ~=nil) then
		m_cloudGamesButton = buttonControl;
	end
	
	-- Your turn in a cloud game?
	if(m_cloudGamesButton ~= nil) then
		local isFullyLoggedIn = FiraxisLive.IsFullyLoggedIn() and FiraxisLive.IsPlatformOrFullAccount();
		local seenPBC = Options.GetUserOption("Interface", "SeenPlayByCloudLobby");
		if(not isFullyLoggedIn) then
			m_cloudGamesButton.OptionButton:SetDisabled(true);
			m_cloudGamesButton.Top:SetToolTipString(CloudNotLoggedInTTStr);
			m_cloudGamesButton.ButtonLabel:SetColorByName( "ButtonDisabledCS" );
		elseif (seenPBC == nil or seenPBC == 0) then
			-- Player has never looked at the PBC lobby, show explanation point to indicate this is a new multiplayer mode.
			m_cloudGamesButton.OptionButton:SetDisabled(false);
			m_cloudGamesButton.Top:SetToolTipString(CloudButtonNewMPModeTTStr);
			m_cloudGamesButton.ButtonLabel:SetText(Locale.Lookup("LOC_MULTIPLAYER_CLOUD_NEW_MODE"));
			m_cloudGamesButton.ButtonLabel:SetColorByName( "ButtonCS" );
		elseif (m_cloudNotify ~= CloudNotifyTypes.CLOUDNOTIFY_NONE and m_cloudNotify ~= CloudNotifyTypes.CLOUDNOTIFY_ERROR) then
			m_cloudGamesButton.OptionButton:SetDisabled(false);
			local CloudTTStr = GetCloudButtonTTForNotify(m_cloudNotify);
			m_cloudGamesButton.Top:SetToolTipString(CloudTTStr);
			m_cloudGamesButton.ButtonLabel:SetText(Locale.Lookup("LOC_MULTIPLAYER_CLOUD_GAME_HAVE_CLOUD_NOTIFY"));
			m_cloudGamesButton.ButtonLabel:SetColorByName( "ButtonCS" );
		elseif (m_hasCloudUnseenComplete) then
			m_cloudGamesButton.OptionButton:SetDisabled(false);
			m_cloudGamesButton.Top:SetToolTipString(CloudButtonUnseenCompleteGameTTStr .. "[NEWLINE][NEWLINE]" .. CloudButtonTTStr);
			m_cloudGamesButton.ButtonLabel:SetText(Locale.Lookup("LOC_MULTIPLAYER_CLOUD_UNSEEN_COMPLETE_GAME"));
			m_cloudGamesButton.ButtonLabel:SetColorByName( "ButtonCS" );
		else
			m_cloudGamesButton.OptionButton:SetDisabled(false);
			m_cloudGamesButton.Top:SetToolTipString(CloudButtonTTStr);
			m_cloudGamesButton.ButtonLabel:SetText(Locale.Lookup("LOC_MULTIPLAYER_CLOUD_GAME"));
			m_cloudGamesButton.ButtonLabel:SetColorByName( "ButtonCS" );
		end
	end
end

function GetCloudButtonTTForNotify(cloudNotifyType :number)
	local cloudTTStr :string;
	if(cloudNotifyType == CloudNotifyTypes.CLOUDNOTIFY_YOURTURN) then
		cloudTTStr = CloudButtonHaveTurnTTStr;
	elseif(cloudNotifyType == CloudNotifyTypes.CLOUDNOTIFY_GAMEREADY) then
		cloudTTStr = CloudButtonGameReadyTTStr;
	else
		-- unhandled type.  just show the default text.
		return CloudButtonTTStr;
	end

	cloudTTStr = cloudTTStr .. "[NEWLINE][NEWLINE]" .. CloudButtonTTStr;
	return cloudTTStr;
end

function UpdateMultiplayerButton(buttonControl: table)
	if (buttonControl ~=nil) then
		m_multiplayerButton = buttonControl;
	end

	local seenPBC = Options.GetUserOption("Interface", "SeenPlayByCloudLobby");
	
	-- Your turn in a cloud game?
	if(m_multiplayerButton ~= nil) then
		if (seenPBC == nil or seenPBC == 0) then
			m_multiplayerButton.Top:SetToolTipString(MultiplayerButtonNewMPModeTTStr .. "[NEWLINE][NEWLINE]" .. MultiplayerButtonTTStr);
			m_multiplayerButton.ButtonLabel:SetText(Locale.Lookup("LOC_PLAY_MULTIPLAYER_NEW_MP_MODE"));
		elseif (m_cloudNotify ~= CloudNotifyTypes.CLOUDNOTIFY_NONE and m_cloudNotify ~= CloudNotifyTypes.CLOUDNOTIFY_ERROR) then
			local cloudTTStr = GetMPButtonTTForNotify(m_cloudNotify);
			m_multiplayerButton.Top:SetToolTipString(cloudTTStr);
			m_multiplayerButton.ButtonLabel:SetText(Locale.Lookup("LOC_PLAY_MULTIPLAYER_HAVE_CLOUD_NOTIFY"));
		elseif (m_hasCloudUnseenComplete) then
			m_multiplayerButton.Top:SetToolTipString(MultiplayerButtonUnseenCompleteTTStr .. "[NEWLINE][NEWLINE]" .. MultiplayerButtonTTStr);
			m_multiplayerButton.ButtonLabel:SetText(Locale.Lookup("LOC_PLAY_MULTIPLAYER_UNSEEN_COMPLETE_GAME"));
		else
			m_multiplayerButton.Top:SetToolTipString(MultiplayerButtonTTStr);
			m_multiplayerButton.ButtonLabel:SetText(Locale.Lookup("LOC_PLAY_MULTIPLAYER"));
		end

		m_multiplayerButton.OptionButton:SetEnabled(UI.HasFeature("Multiplayer"));
	end
end

function GetMPButtonTTForNotify(cloudNotifyType :number)
	local cloudTTStr :string;
	if(cloudNotifyType == CloudNotifyTypes.CLOUDNOTIFY_YOURTURN) then
		cloudTTStr = MultiplayerButtonHaveTurnTTStr;
	elseif(cloudNotifyType == CloudNotifyTypes.CLOUDNOTIFY_GAMEREADY) then
		cloudTTStr = MultiplayerButtonGameReadyTTStr;
	else
		-- unhandled type.  just show the default text.
		return MultiplayerButtonTTStr;
	end

	cloudTTStr = cloudTTStr  .. "[NEWLINE][NEWLINE]" .. MultiplayerButtonTTStr;
	return cloudTTStr;
end

-- ===========================================================================
function OnLANGame()
	LuaEvents.ChangeMPLobbyMode(MPLobbyTypes.STANDARD_LAN);
	UIManager:QueuePopup( Controls.Lobby, PopupPriority.Current );
	Close();
end

-- ===========================================================================
function OnHotSeat()
	LuaEvents.ChangeMPLobbyMode(MPLobbyTypes.HOTSEAT);
	LuaEvents.MainMenu_RaiseHostGame();
	Close();
end

-- ===========================================================================
function OnPlayByCloud()
	LuaEvents.ChangeMPLobbyMode(MPLobbyTypes.PLAYBYCLOUD);
	UIManager:QueuePopup( Controls.Lobby, PopupPriority.Current );
	Close();
end

-- ===========================================================================
function OnCloud()
	UIManager:QueuePopup( Controls.CloudGameScreen, PopupPriority.Current );
	Close();
end

-- ===========================================================================
function OnGameLaunched()	
end

-- ===========================================================================
function Close()
	-- Set pause to 0 so it loads in right away when returning from any screen.
	m_initialPause = 0;
end


--[[
--UINETTODO - Do we need this so that multiplayer game invites skip straight into the invited game?
-------------------------------------------------
-------------------------------------------------
-- The UI has requested that we go to the multiplayer select.  Show ourself
function OnUpdateUI( type, tag, iData1, iData2, strData1 )
    if (type == SystemUpdateUI.RestoreUI and tag == "MultiplayerSelect") then
		if (ContextPtr:IsHidden()) then
			UIManager:QueuePopup(ContextPtr, PopupPriority.Current );    
		end
    end
end
Events.SystemUpdateUI.Add( OnUpdateUI );
--]]

-- ===========================================================================
--	ToggleOption - called from button handlers
-- ===========================================================================
--	Toggles the specified index within the main menu
--	ARG0: optionIndex - the index of the button control to deselect
--	ARG1: submenu - if the specified index has a submenu, then build that menu
-- ===========================================================================
function ToggleOption(optionIndex, submenu)
	if (not Controls.SubMenuSlide:IsStopped()) then
		return;
	end
	local optionControl = m_currentOptions[optionIndex].control;
	if(m_currentOptions[optionIndex].isSelected) then
		-- If the thing I selected was already selected, then toggle it off
		UI.PlaySound("Main_Main_Panel_Collapse"); 
		Controls.SubMenuContainer:SetHide(true);
		Controls.SubMenuAlpha:Reverse();
		Controls.SubMenuSlide:Reverse();
		DeselectOption(optionIndex);
	else
		-- OTHERWISE - I am selecting a new thing
		-- Was anything else OTHER than the optionIndex selected?  If so, we should hide its selection fanciness and turn it off
		-- Let's also check to see if the submenu was already open
		local subMenuClosed = true;
		for i=1, table.count(m_currentOptions) do
			if (i ~= optionIndex) then
				if(m_currentOptions[i].isSelected) then
					subMenuClosed = false;
					DeselectOption(i);
				end
			end
		end
		
		if(subMenuClosed) then
			--If the submenu wasn't opened yet, then let's slide it out
			Controls.SubMenuAlpha:SetToBeginning();
			Controls.SubMenuAlpha:Play();
			Controls.SubMenuSlide:SetToBeginning();
			Controls.SubMenuSlide:Play();
			Controls.SubMenuContainer:SetHide(false);
		end
		-- Now show the selector around the new thing 
		optionControl.SelectionAnimAlpha:SetToBeginning();
		optionControl.SelectionAnimSlide:SetToBeginning();
		optionControl.SelectionAnimAlpha:Play();
		optionControl.SelectionAnimSlide:Play();
		optionControl.LabelAlphaAnim:SetPauseTime(0);
		optionControl.LabelAlphaAnim:SetSpeed(6);
		optionControl.LabelAlphaAnim:Reverse();
		if (submenu ~= nil) then
			BuildSubMenu(submenu);
		end
		m_currentOptions[optionIndex].isSelected = true;
	end
end

-- ===========================================================================
--	Called from ToggleOption
--	Visually deselects the specified index and tracks within m_currentOptions
--	ARG0:	index - the index of the button control to deselect
-- ===========================================================================
function DeselectOption(index:number)
	local control:table = m_currentOptions[index].control;
	control.LabelAlphaAnim:SetSpeed(1);
	control.LabelAlphaAnim:SetPauseTime(.4);
	control.SelectionAnimAlpha:Reverse();
	control.SelectionAnimSlide:Reverse();
	control.LabelAlphaAnim:SetToBeginning();
	control.LabelAlphaAnim:Play();
	m_currentOptions[index].isSelected = false;
end

-- ===========================================================================
function OnTutorial()
	GameConfiguration.SetToDefaults();
	UIManager:QueuePopup(Controls.TutorialSetup, PopupPriority.Current);
end


-- ===========================================================================
--	Callbacks for the main menu options which have submenus
--	ARG0:	optionIndex - which index of the current options to toggle
--	ARG1:	submenu - the submenu table to draw in
-- ===========================================================================
function OnSinglePlayer( optionIndex:number, submenu:table )	
	ToggleOption(optionIndex, submenu);
end

function OnMultiPlayer( optionIndex:number, submenu:table )	
	ToggleOption(optionIndex, submenu);
end

function OnAdditionalContent( optionIndex:number, submenu:table )	
	ToggleOption(optionIndex, submenu);
end

function OnBenchmark( optionIndex:number, submenu:table )	
	ToggleOption(optionIndex, submenu);
end

function OnWorldBuilder( optionIndex:number, submenu:table )
	ToggleOption(optionIndex, submenu);
end


function OnNewWorldBuilderMap()
	GameConfiguration.SetToDefaults();
	GameConfiguration.SetWorldBuilderEditor(true);
	local advancedSetup = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/AdvancedSetup" );
	UIManager:QueuePopup(advancedSetup, PopupPriority.Current);
end

function OnLoadWorldBuilderMap()
	GameConfiguration.SetToDefaults();
	LuaEvents.MainMenu_SetLoadGameServerType(ServerType.SERVER_TYPE_NONE);
	GameConfiguration.SetWorldBuilderEditor(true);
	local loadGameMenu = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/LoadGameMenu" );
	UIManager:QueuePopup(loadGameMenu, PopupPriority.Current);
end

function OnImportWorldBuilderMap()
	UIManager:QueuePopup(Controls.WorldBuilder, PopupPriority.Current);
end

-- *******************************************************************************
--	MENUS need to be defined here as the callbacks reference functions which
--	are defined above.
-- *******************************************************************************


-- ===============================================================================
-- Sub Menu Option Tables
--	--------------------------------------------------------------------------
--	label - the text string for the button (un-localized)
--	callback - the function to call from this button
--	tooltip - the tooltip for this button
--	buttonState - a function to call which will update the buttonstate and tooltip
-- ===============================================================================
local m_SinglePlayerSubMenu :table = {
								{label = "LOC_MAIN_MENU_RESUME_GAME",		callback = OnResumeGame,	tooltip = "LOC_MAINMENU_RESUME_GAME_TT", buttonState = UpdateResumeGame},
								{label = "LOC_LOAD_GAME",					callback = OnLoadSinglePlayer,	tooltip = "LOC_MAINMENU_LOAD_GAME_TT",},
								{label = "LOC_PLAY_CIVILIZATION_6",			callback = OnPlayCiv6,	tooltip = "LOC_MAINMENU_PLAY_NOW_TT"},
								{label = "LOC_SETUP_SCENARIOS",				callback = OnScenarioSetup,	tooltip = "LOC_MAINMENU_SCENARIOS_TT", buttonState = UpdateScenariosButton},
								{label = "LOC_SETUP_CREATE_GAME",			callback = OnAdvancedSetup,	tooltip = "LOC_MAINMENU_CREATE_GAME_TT"},
							

							};

local m_MultiPlayerSubMenu :table = {
								{label = "LOC_MULTIPLAYER_CLOUD_GAME",			callback = OnPlayByCloud,			tooltip = "LOC_MULTIPLAYER_CLOUD_GAME_TT", buttonState = UpdateCloudGamesButton},
								{label = "LOC_MULTIPLAYER_INTERNET_GAME",		callback = OnInternet,				tooltip = "LOC_MULTIPLAYER_INTERNET_GAME_TT", buttonState = UpdateInternetButton},
								{label = "LOC_MULTIPLAYER_LAN_GAME",			callback = OnLANGame,				tooltip = "LOC_MULTIPLAYER_LAN_GAME_TT"},
								{label = "LOC_MULTIPLAYER_HOTSEAT_GAME",		callback = OnHotSeat,				tooltip = "LOC_MULTIPLAYER_HOTSEAT_GAME_TT"},
								{space = true},
								{label = "LOC_MULTIPLAYER_MATCHMAKE_CIVROYALE",	callback = OnCivRoyaleMatchMake,	tooltip = "LOC_MULTIPLAYER_MATCHMAKE_CIVROYALE_TT", colorName = "RoyaleButtonCS", buttonState = UpdateCivRoyaleMatchMakeButton},
								{label = "LOC_MULTIPLAYER_HOWTOPLAY_CIVROYALE",	callback = OnCivRoyaleHowToPlay,	tooltip = "LOC_MULTIPLAYER_HOWTOPLAY_CIVROYALE_TT", colorName = "RoyaleButtonCS", buttonState = UpdateCivRoyaleHowToButton},
							};

local m_AdditionalSubMenu :table = {
								{label = "LOC_MAIN_MENU_MODS",					callback = OnMods,					tooltip = "LOC_MAIN_MENU_MODS_AND_DLC_TT"},
								{label = "LOC_MAIN_MENU_HALL_OF_FAME",			callback = OnHallofFame,			tooltip = "LOC_MAIN_MENU_HALL_OF_FAME_TT"},
								{label = "LOC_MAIN_MENU_CREDITS",				callback = OnCredits,				tooltip = "LOC_MAINMENU_CREDITS_TT"},
							};

local m_BenchmarkSubMenu :table = {
								{label = "LOC_BENCHMARK_GRAPHICS",			callback = OnGraphicsBenchmark,		tooltip = "LOC_BENCHMARK_GRAPHICS_TT"},
								{label = "LOC_BENCHMARK_AI",				callback = OnAIBenchmark,			tooltip = "LOC_BENCHMARK_AI_TT", buttonState = UpdateAIBenchmark},
								{label = "LOC_BENCHMARK_EXP2_GRAPHICS",		callback = OnExp2GraphicsBenchmark,	tooltip = "LOC_BENCHMARK_EXP2_GRAPHICS_TT", buttonState = UpdateExp2GraphicsBenchmark},
								{label = "LOC_BENCHMARK_EXP2_AI",			callback = OnExp2AIBenchmark,		tooltip = "LOC_BENCHMARK_EXP2_AI_TT", buttonState = UpdateExp2AIBenchmark},
							};

local m_WorldBuilderSubMenu :table = {
								{label = "LOC_WORLD_BUILDER_START_NEW",			callback = OnNewWorldBuilderMap,   	tooltip = "LOC_WORLD_BUILDER_START_NEW_TOOLTIP"},
								{label = "LOC_WORLD_BUILDER_LOAD",				callback = OnLoadWorldBuilderMap, 	tooltip = "LOC_WORLD_BUILDER_LOAD_TOOLTIP"},
								{label = "LOC_WORLD_BUILDER_IMPORT",		    callback = OnImportWorldBuilderMap,	tooltip = "LOC_WORLD_BUILDER_IMPORT_TOOLTIP"},
							};

-- ===========================================================================
--	Main Menu Option Tables
--	--------------------------------------------------------------------------
--	label - the text string for the button (un-localized)
--	callback - the function to call from this button
--	submenu - the submenu table to open for this button (defined above)
--	buttonState - a function to call which will update the buttonstate and tooltip
-- ===========================================================================
local m_preSaveMainMenuOptions :table = {	{label = "LOC_PLAY_CIVILIZATION_6",			callback = OnPlayCiv6}};  
local m_defaultMainMenuOptions :table = {	
								{label = "LOC_SINGLE_PLAYER",				callback = OnSinglePlayer,		tooltip = "LOC_MAINMENU_SINGLE_PLAYER_TT",			submenu = m_SinglePlayerSubMenu}, 
								{label = "LOC_PLAY_MULTIPLAYER",			callback = OnMultiPlayer,		tooltip = "LOC_MAINMENU_MULTIPLAYER_TT",			submenu = m_MultiPlayerSubMenu, buttonState = UpdateMultiplayerButton},
								{label = "LOC_MAIN_MENU_OPTIONS",			callback = OnOptions,			tooltip = "LOC_MAINMENU_GAME_OPTIONS_TT"},
								{label = "LOC_MAIN_MENU_ADDITIONAL_CONTENT",callback = OnAdditionalContent,	tooltip = "LOC_MAIN_MENU_ADDITIONAL_CONTENT_TT",	submenu = m_AdditionalSubMenu},
								{label = "LOC_MAIN_MENU_TUTORIAL",			callback = OnTutorial,			tooltip = "LOC_MAINMENU_TUTORIAL_TT"},
								{label = "LOC_MAIN_MENU_BENCH",				callback = OnBenchmark,			tooltip = "LOC_MAINMENU_BENCHMARK_TT",				submenu = m_BenchmarkSubMenu},
								{label = "LOC_WORLDBUILDER_TITLE",		    callback = OnWorldBuilder,		tooltip = "LOC_MAINMENU_WORLDBUILDER_TT", 			submenu = m_WorldBuilderSubMenu},								
								{label = "LOC_MAIN_MENU_EXIT_TO_DESKTOP",	callback = OnUserRequestClose,	tooltip = "LOC_MAINMENU_EXIT_GAME_TT"}
							};


-- ===========================================================================
--	Animation callback for top-menu option controls.
-- ===========================================================================
function TopMenuOptionAnimationCallback(control, progress)
	local progress :number = control:GetProgress();
													
	-- Only if the animation has just begun, play its sound
	if(not control:IsReversing() and progress <.1) then 
		UI.PlaySound("Main_Menu_Expand_Notch");				
	elseif(not control:IsReversing() and progress >.65) then 
		control:SetSpeed(.9);	-- As the flag is nearing the top of its bounce, slow it down
	end													
													
	-- After the flag animation has bounced, stop it at the correct position													
	if(control:IsReversing() and progress > .2) then
		control:SetProgress( 0.2 );
		control:Stop();																									
	elseif(control:IsReversing() and progress < .03) then
		control:SetSpeed(.4);	-- Right after the flag animation has bounced, slow it down dramatically
	end
end

-- ===========================================================================
--	Animation callback for sub-menu option controls.
-- ===========================================================================
function SubMenuOptionAnimationCallback(control, progress) 
	if(not control:IsReversing() and progress <.1) then 
		UI.PlaySound("Main_Menu_Panel_Expand_Short"); 
	elseif(not control:IsReversing() and progress >.65) then 
		control:SetSpeed(2);
	end
	if(control:IsReversing() and progress > .2) then
		control:SetProgress( 0.2 );
		control:Stop();														
	elseif(control:IsReversing() and progress < .03) then
		control:SetSpeed(1);
	end
end


function MenuOptionMouseEnterCallback()
	UI.PlaySound("Main_Menu_Mouse_Over"); 
end

-- ===========================================================================
--	Animates the main menu options in
--	ARG0:	menuOptions - Expects the table of options that is to appear on 
--			the topmost level - either [m_preSave/m_default]MainMenuOptions
-- ===========================================================================
function BuildMenu(menuOptions:table)
	m_mainOptionIM:ResetInstances();
	UI.PlaySound("Main_Menu_Panel_Expand_Top_Level");	
	local pauseAccumulator = m_initialPause + PAUSE_INCREMENT;
	for i, menuOption in ipairs(menuOptions) do

		-- Add the instances to the table and play the animations and add the sounds
		local option = m_mainOptionIM:GetInstance();
		option.ButtonLabel:LocalizeAndSetText(menuOption.label);
		option.SelectedLabel:LocalizeAndSetText(menuOption.label);
		option.LabelAlphaAnim:SetToBeginning();
		option.LabelAlphaAnim:Play();
		-- The label begin its alpha animation slightly after the flag begins to fly out
		option.LabelAlphaAnim:SetPauseTime(pauseAccumulator + .2);
		option.OptionButton:RegisterCallback( Mouse.eLClick, function() 
																--If a submenu exists, specify the index and pass the submenu along to the callback
																if (menuOption.submenu ~= nil) then 
																	menuOption.callback(i, menuOption.submenu);
																else  
																	menuOption.callback();
																end
															end);
		option.OptionButton:RegisterCallback( Mouse.eMouseEnter, MenuOptionMouseEnterCallback);

		-- Define a custom animation curve and sounds for the button flag - this function is called for every frame
		option.FlagAnim:RegisterAnimCallback(TopMenuOptionAnimationCallback);
		-- Will not be called due to "Bounce" cycle being used: option.FlagAnim:RegisterEndCallback( function() print("done!"); end ); 
		option.FlagAnim:SetPauseTime(pauseAccumulator);
		option.FlagAnim:SetSpeed(4);
		option.FlagAnim:SetToBeginning();
		option.FlagAnim:Play();

		
		option.Top:LocalizeAndSetToolTip(menuOption.tooltip);

		-- Use special button update function if it exists for this menu option.
		if (menuOption.buttonState ~= nil) then
			menuOption.buttonState(option); 
		end	
		
		-- Accumulate a pause so that the flags appear one at a time
		pauseAccumulator = pauseAccumulator + PAUSE_INCREMENT;
		-- Track which options are being displayed and preserve the selection state so that we can rebuild a submenu
		m_currentOptions[i] = {control = option, isSelected = false};
	end
	Controls.MainMenuOptionStack:CalculateSize();


	local trackHeight = Controls.MainMenuOptionStack:GetSizeY() + TRACK_PADDING;
	-- Make sure the vertical div line is correctly sized for the number of options and draw it in
	Controls.MainButtonTrack:SetSizeY(trackHeight);
	Controls.MainButtonTrackAnim:SetBeginVal(0,-trackHeight);
	Controls.MainButtonTrackAnim:Play();
	Controls.MainMenuClip:SetSizeY(trackHeight);
end

-- ===========================================================================
--	Builds the table of submenu options
--	ARG0:	menuOptions - Expects the table specified in the 'submenu' field 
--			of the m_defaultMainMenuOptions table	
--
--	WB: While this function shares a fair amount of code with BuildMenu, 
--	I have decided to keep them separate as I continue differentiate behavior
--	and tweak the animations. 
-- ===========================================================================
function BuildSubMenu(menuOptions:table)
	m_subOptionIM:ResetInstances();
	for i, kMenuOption in ipairs(menuOptions) do

		local uiOption = m_subOptionIM:GetInstance();
		if kMenuOption.space then
			-- Do nothing, animate nothing.
			uiOption.FlagAnim:SetToBeginning();
			uiOption.FlagAnim:Stop();
			uiOption.OptionButton:SetHide(true);
			uiOption.Top:LocalizeAndSetToolTip("");		-- Clear any prior tooltip
		else
			-- Add the instances to the table and play the animations and add the sounds
			-- * Submenu options animate in all at once, instead of one at at a time	
			
			uiOption.ButtonLabel:LocalizeAndSetText(kMenuOption.label);
			uiOption.SelectedLabel:LocalizeAndSetText(kMenuOption.label);			
			uiOption.LabelAlphaAnim:SetToBeginning();
			uiOption.LabelAlphaAnim:Play();
			uiOption.LabelAlphaAnim:SetPauseTime(0);
			uiOption.OptionButton:RegisterCallback( Mouse.eLClick, kMenuOption.callback);
			uiOption.OptionButton:RegisterCallback( Mouse.eMouseEnter, MenuOptionMouseEnterCallback);
			uiOption.OptionButton:SetHide(false);

			-- * Submenu options have a slightly different animation curve as well as a different animation sound
			uiOption.FlagAnim:RegisterAnimCallback(SubMenuOptionAnimationCallback);

			-- Will not be called due to "Bounce" cycle being used: option.FlagAnim:RegisterEndCallback( function() print("done!"); end ); 
			uiOption.FlagAnim:SetSpeed(4);
			uiOption.FlagAnim:SetToBeginning();
			uiOption.FlagAnim:Play();

			uiOption.Top:LocalizeAndSetToolTip(kMenuOption.tooltip);
		
			-- Set a special disabled state for buttons (right now, only the Internet button has this function)
			if (kMenuOption.buttonState ~= nil) then
				kMenuOption.buttonState(uiOption); 
			else
				--ATTN:TRON For some reason my instances are not being completely reset when I rebuild the my list here
				-- So I have to reset my tooltip string and button state.
				uiOption.OptionButton:SetDisabled(false);
				uiOption.ButtonLabel:SetColorByName( "ButtonCS" );
			end
			if kMenuOption.colorName then
				uiOption.ButtonLabel:SetColorByName( kMenuOption.colorName );
			end

		end		
	end

	Controls.SubMenuOptionStack:CalculateSize();
	local trackHeight = Controls.SubMenuOptionStack:GetSizeY() + TRACK_PADDING;
	Controls.SubButtonTrack:SetSizeY(trackHeight);
	Controls.SubButtonTrackAnim:SetBeginVal(0,-trackHeight);
	-- * The track line for the submenu also draws in more quickly since all the options are feeding in at once
	Controls.SubButtonTrackAnim:SetSpeed(5);
	Controls.SubButtonTrackAnim:SetToBeginning();
	Controls.SubButtonTrackAnim:Play();
	Controls.SubMenuClip:SetSizeY(trackHeight);
	Controls.SubMenuAlpha:SetSizeY(trackHeight);
	Controls.SubButtonClip:SetSizeY(trackHeight);
	Controls.SubMenuContainer:SetSizeY(Controls.MainMenuClip:GetSizeY());
end


-- =============================================================================
--	Searches the menu table for a value which contains a matching [label]. If 
--	found, that index is removed
--	ARG0:	menu - the parent menu table.  Expects options to have a name 
--			string in the [label] field to compare against
--	ARG1:	option - the table containing both the [label] and [callback] 
--			for the submenu option
-- =============================================================================
function RemoveOptionFromMenu(menu:table, option:table)
	for i=1, table.count(menu) do
		if(menu[i] ~= nil) then
			if(menu[i].label == option.label) then
				table.remove(menu,i);
			end
		end
	end
end

-- =============================================================================
--	Searches the menu table for a value which contains a matching [label]. If 
--	that value is NOT found, the submenu option is inserted at the first index
--	ARG0:	menu - the parent menu table.  Expects options to have a name 
--			string in the [label] field to compare against
--	ARG1:	option - the table containing both the [label] and [callback] 
--			for the submenu option
--	ARG2:	(OPTIONAL) index - the index of the submenu where the option should
--			be inserted.
-- =============================================================================
function AddOptionToMenu(menu:table, option:table, index:number)
	local hasOption = false;
	if (index == nil) then
		index = 1;
	end
	for i=1, table.count(menu) do
		if(menu[i].label == option) then
			hasOption = true;
		end
	end
	if (not hasOption) then
		table.insert(menu,submenu,1);
	end
end

-- =============================================================================
--	Called from the ESC handler and also when we show the screen
--	Rebuilds the menu taking into account any submenus that were already open
-- =============================================================================
function BuildAllMenus()

	if m_isQuitting then 
		return; 
	end

	-- Reset cached buttons to make sure we don't reference reused instances
	m_resumeButton = nil;
	m_internetButton = nil;
	m_scenariosButton = nil;
	m_multiplayerButton = nil;
	m_cloudGamesButton = nil;
	m_matchMakeButton = nil;
	m_howToRoyaleControl = nil;

	-- WISHLIST: When we rebuild the menus, let's check to see if there are ANY saved games whatsoever.  
	-- If none exist, then do not display the option in the submenu. (See: OnFileListQueryResults)
	local selectedIndex = -1;
	for i=1, table.count(m_currentOptions) do
		if(m_currentOptions[i].isSelected) then
			selectedIndex = i;
		end
	end
	if(selectedIndex ~= -1) then
		if(m_defaultMainMenuOptions[selectedIndex].submenu ~= nil) then
			BuildSubMenu(m_defaultMainMenuOptions[selectedIndex].submenu);
		else
			BuildMenu(m_defaultMainMenuOptions);
		end
	else
		BuildMenu(m_defaultMainMenuOptions);
	end
end

-- ===========================================================================
--	UI Callback
--	Restart animation on show
-- ===========================================================================
function OnShow()

	-- Re-enable the play now button.
	_ClickedPlayNow = nil;

	local save = Options.GetAppOption("Debug", "PlayNowSave");
	if (save ~= nil) then
		--If we have a save specified in AppOptions, then only display the play button
		BuildMenu(m_preSaveMainMenuOptions);
	else
		BuildAllMenus();
	end
	GameConfiguration.SetToDefaults();
	UI.SetSoundStateValue("Game_Views", "Main_Menu");
	LuaEvents.UpdateFiraxisLiveState();

	local pFriends = Network.GetFriends();
	if (pFriends ~= nil) then
		pFriends:SetRichPresence("civPresence", "LOC_PRESENCE_IN_SHELL");
	end

	local gameType = SaveTypes.SINGLE_PLAYER;
	local saveLocation = SaveLocations.LOCAL_STORAGE;

	g_MostRecentSave = nil;
	g_LastFileQueryRequestID = nil;
	local options = SaveLocationOptions.NORMAL + SaveLocationOptions.AUTOSAVE + SaveLocationOptions.QUICKSAVE + SaveLocationOptions.MOST_RECENT_ONLY + SaveLocationOptions.LOAD_METADATA ;
	g_LastFileQueryRequestID = UI.QuerySaveGameList( saveLocation, gameType, options );

	local error = Modding.GetLastLoadError();
	if (not m_bHasShownError and error ~= nil) then
		m_bHasShownError = true;

		local reasonString;
		if error == DB.MakeHash("UNKNOWN_VERSION") then
			reasonString = "LOC_GAME_START_ERROR_UNKNOWN_VERSION";
		elseif error == DB.MakeHash("MOD_CONTENT") then
			reasonString = "LOC_GAME_START_ERROR_MOD_CONTENT";
		elseif error == DB.MakeHash("MOD_CONFIG") then
			reasonString = "LOC_GAME_START_ERROR_MOD_CONFIG";
		elseif error == DB.MakeHash("MOD_OWNERSHIP") then
			reasonString = "LOC_GAME_START_ERROR_MOD_OWNERSHIP";
		elseif error == DB.MakeHash("SCRIPT_PROCESSING") then
			reasonString = "LOC_GAME_START_ERROR_SCRIPT_PROCESSING";
		else
			reasonString = string.format("%X", error);
		end

		local error_string = Locale.Lookup("LOC_GAME_START_ERROR_DESC") .. "[NEWLINE][NEWLINE]" .. Locale.Lookup("LOC_GAME_START_ERROR_CODE", reasonString);

		LuaEvents.MainMenu_LaunchError(error_string);
	end

	m_checkedCloudNotify = false;
	UpdateCheckCloudNotify();
end

function OnHide()
	-- Set the pause to 0 as soon as we hide the main menu, so it loads in right 
	-- away when we return from any screen.
	m_bHasShownError = nil;
	m_initialPause = 0;
end

-- Call-back for when the list of files have been updated.
function OnFileListQueryResults( fileList, queryID )
	if g_LastFileQueryRequestID ~= nil then
		if (g_LastFileQueryRequestID == queryID) then
			g_MostRecentSave = nil;
			if (fileList ~= nil) then
				for i, v in ipairs(fileList) do
					g_MostRecentSave = v;		-- There really should only be one or 
				end
			
				UpdateResumeGame();
			end

			UI.CloseFileListQuery(g_LastFileQueryRequestID);
			g_LastFileQueryRequestID = nil;
		end
	end
	
end

-- ===========================================================================
function OnCycleMotD()
	if (ms_MotDIndex == nil) then
		ms_MotDIndex = 0;
	else
		ms_MotDIndex = ms_MotDIndex + 1;
	end

	UpdateMotD();
end

-- ===========================================================================
function OnFiraxisLiveActivate(bActive)
	UpdateCheckCloudNotify();
end

function UpdateCheckCloudNotify()
	if(not m_checkedCloudNotify) then
		local kandoConnected = FiraxisLive.IsFiraxisLiveLoggedIn();
		if(kandoConnected) then
			FiraxisLive.SetAutoCloudNotificationChecks(true); -- continue polling the turn notification check in the future.
			local started = FiraxisLive.CheckForCloudNotifications();
			if(started) then
				m_checkedCloudNotify = true;
			end
		end
	end
end

function UpdateMenuLogo()
	local logos = DB.ConfigurationQuery("SELECT LogoTexture, LogoMovie from Logos ORDER BY Priority DESC LIMIT 1");
	if(logos and #logos > 0) then
		local logo = logos[1];
		if(logo and g_LogoTexture ~= logo.LogoTexture and g_LogoMovie ~= logo.LogoMovie) then
			g_LogoTexture = logo.LogoTexture
			g_LogoMovie = logo.LogoMovie

			-- change texture
			Controls.Logo:SetTexture(g_LogoTexture);

			-- change movie
			local movieControl:table = ContextPtr:LookUpControl("/FrontEnd/BackgroundMovie");
			if(movieControl ~= nil) then
				movieControl:SetMovie(g_LogoMovie, true);
			end
		
			-- YnAMP <<<<<
			-- reset mod status and check for custom medias
			g_ModWasEnabled = {}
			--CheckMainMenuMedia()
			-- YnAMP >>>>>

		end
	end
end

-- YnAMP <<<<<
-- ===========================================================================
local bMenuHadCustomLogo 	= false
local bMenuHadCustomMovie	= false
function CheckMainMenuMedia()
	print("Checking Mods status for MainMenu Media...")
	
	local logoTexture
	local logoMovie
	local modTexture
	local modMovie
	local bModHasCustomLogo 	= false
	local bModHasCustomMovie	= false
	local installedMods = Modding.GetInstalledMods()

	---[[
	if installedMods ~= nil then
		for i, modData in ipairs(installedMods) do
			if modData.Enabled and modData.Allowance then
				--local info	= Modding.GetModInfo(modData.Handle)
				modTexture			= Modding.GetModProperty(modData.Handle, "MainMenuLogo")
				modMovie			= Modding.GetModProperty(modData.Handle, "MainMenuVideo")
				bModHasCustomLogo	= modTexture or bModHasCustomLogo
				bModHasCustomMovie	= modMovie or bModHasCustomMovie
				--for k, v in pairs(modData) do print (k,v) end
				if not g_ModWasEnabled[modData.Handle] then
					print("- Enabled : ".. Locale.Lookup(modData.Name), modTexture and " - Logo : ".. tostring(modTexture) or "", modMovie and " - Movie : ".. tostring(modMovie) or "")
					logoTexture						= modTexture or logoTexture
					logoMovie						= modMovie or logoMovie
					g_ModWasEnabled[modData.Handle] = true
					bMenuHadCustomLogo				= logoTexture ~= nil
					bMenuHadCustomMovie				= logoMovie ~= nil
				end
			else
				if g_ModWasEnabled[modData.Handle] then
					print("- Disabled : ".. Locale.Lookup(modData.Name), modTexture or "", modMovie or "")
				end
				g_ModWasEnabled[modData.Handle] = nil
			end
		end
	end
--print(bMenuHadCustomLogo, bModHasCustomLogo, bMenuHadCustomMovie, bModHasCustomMovie)
	if bMenuHadCustomLogo and not bModHasCustomLogo then
		if(Expansion2IsEnabled()) then
			logoTexture = "Shell_LogoEXP2.dds"
		elseif( Expansion1IsEnabled() ) then
			logoTexture = "Shell_LogoEXP.dds"
		else
			logoTexture = "MainLogo.dds"
		end
	end
	
	if bMenuHadCustomMovie and not bModHasCustomMovie then
		if(Expansion2IsEnabled()) then
			logoMovie = "Expansion2FrontEndBackground.bk2"
		elseif( Expansion1IsEnabled() ) then
			logoMovie = "Expansion1FrontEndBackground.bk2"
		else
			logoMovie = "TitleBG.bk2"
		end
	end
	
--print(logoTexture, logoMovie)
	---[[
	-- If there are changes, apply them.
	if logoTexture then
		-- change texture
		Controls.Logo:SetTexture(logoTexture);
	end

	if logoMovie then
		-- change movie
		local movieControl:table = ContextPtr:LookUpControl("/FrontEnd/BackgroundMovie");
		if(movieControl ~= nil) then
			movieControl:SetMovie(logoMovie, true);
		end
	end
	--]]
end
-- YnAMP >>>>>

-- ===========================================================================
function OnMy2KLinkAccountResult(bSuccess)
	-- account link status changes can toggle the cloud games button.
	UpdateCloudGamesButton();
end

-- ===========================================================================
function OnGameplayContentChanged( kEvent )
	if(kEvent.Success and kEvent.ConfigurationChanged) then
		UpdateMenuLogo();
	end
end

-- ===========================================================================
function OnShutdown()
	if Controls.Logo:IsTextureLoaded() then
		Controls.Logo:UnloadTexture();
	end	
end

-- ===========================================================================
function Initialize()

	UI.CheckUserSetup();
	UIManager:DisablePopupQueue( false );	-- If coming back from a (PBC) game, it is possible this may have been left on; ensure popups work or the main menu won't show.	

	-- Remove the Play By Cloud option if it is not available
	if(not Network.HasCapability("CloudGame")) then
		local l_CloudGame : table = { label = "LOC_MULTIPLAYER_CLOUD_GAME" };
		RemoveOptionFromMenu(m_MultiPlayerSubMenu, l_CloudGame);
	end

	if(not Network.HasCapability("FiraxisLiveSupport")) then
		Controls.My2KContents:SetShow(false);
	end

	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetShutdown( OnShutdown );
	
	Controls.VersionLabel:SetText( UI.GetAppVersion() );
	Controls.My2KLogin:RegisterCallback( Mouse.eLClick, OnMy2KLogin );
	Controls.My2KLogin:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	if (not UI.IsFinalRelease()) then
		Controls.MotDLogo:RegisterCallback( Mouse.eLClick, OnCycleMotD );
	end

	-- YnAMP <<<<<
	--g_XP1WasEnabled = Expansion1IsEnabled();
	--g_XP2WasEnabled = Expansion2IsEnabled();
	-- YnAMP >>>>>
	
	-- Game Events
	Events.SteamServersConnected.Add( UpdateInternetControls );
	Events.SteamServersDisconnected.Add( UpdateInternetControls );
	Events.MultiplayerGameLaunched.Add( OnGameLaunched );
    Events.UserRequestClose.Add( OnUserRequestClose );
	Events.UserConfirmedClose.Add( OnUserConfirmedClose );
	Events.CloudTurnCheckComplete.Add( OnCloudTurnCheckComplete );
	Events.CloudUnseenCompleteCheckComplete.Add( OnCloudUnseenCompleteCheckComplete );
	Events.FiraxisLiveActivate.Add( OnFiraxisLiveActivate );
	Events.My2KLinkAccountResult.Add( OnMy2KLinkAccountResult );
	Events.MarketingPushDataUpdated.Add( OnMarketingPushDataUpdated );

	Events.FinishedGameplayContentConfigure.Add( OnGameplayContentChanged );

	-- LUA Events
	LuaEvents.FileListQueryResults.Add( OnFileListQueryResults );
	LuaEvents.MainMenu_ShowAdditionalContent.Add(OnMods);
	LuaEvents.CivRoyaleIntro_StartMatchMaking.Add(StartMatchMaking);

	BuildAllMenus();
	UpdateMotD();
	UpdateMenuLogo();
	
	-- YnAMP <<<<<
	--Events.ModStatusUpdated.Add( CheckMainMenuMedia )
	--Events.FinishedGameplayContentConfigure.Add( CheckMainMenuMedia );
	--CheckMainMenuMedia()
	-- YnAMP >>>>>
end
Initialize();