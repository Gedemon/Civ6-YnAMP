----------------------------------------------------------------  
-- Staging Room Screen
----------------------------------------------------------------  
include( "InstanceManager" );	--InstanceManager
include( "PlayerSetupLogic" );
include( "SteamUtilities" );
include( "ButtonUtilities" );
include( "PlayerTargetLogic" );
include( "ChatLogic" );
include( "NetConnectionIconLogic" );
include( "PopupDialog" );
include( "Civ6Common" );
include( "TeamSupport" );

----------------------------------------------------------------  
-- Globals
----------------------------------------------------------------  
local g_PlayerEntries = {};					-- All the current player entries, indexed by playerID.
local g_PlayerRootToPlayerID = {};  -- maps the string name of a player entry's Root control to a playerID.
local g_PlayerReady = {};			-- cached player ready status, indexed by playerID.
local g_PlayerModStatus = {};		-- cached player localized mod status strings.
local g_cachedTeams = {};				-- A cached mapping of PlayerID->TeamID.

local m_playerTarget = { targetType = ChatTargetTypes.CHATTARGET_ALL, targetID = GetNoPlayerTargetID() };
local m_playerTargetEntries = {};
local m_ChatInstances		= {};
local m_infoTabsIM:table = InstanceManager:new("ShellTab", "TopControl", Controls.InfoTabs);
local m_shellTabIM:table = InstanceManager:new("ShellTab", "TopControl", Controls.ShellTabs);
local m_friendsIM = InstanceManager:new( "FriendInstance", "RootContainer", Controls.FriendsStack );
local m_playersIM = InstanceManager:new( "PlayerListEntry", "Root", Controls.PlayerListStack );
local g_GridLinesIM = InstanceManager:new( "HorizontalGridLine", "Control", Controls.GridContainer );
local m_gameSetupParameterIM = InstanceManager:new( "GameSetupParameter", "Root", nil );
local m_kPopupDialog:table;

-- Additional Content 
local m_modsIM = InstanceManager:new("AdditionalContentInstance", "Root", Controls.AdditionalContentStack);

-- Reusable tooltip control
local m_CivTooltip:table = {};
ContextPtr:BuildInstanceForControl("CivToolTip", m_CivTooltip, Controls.TooltipContainer);
m_CivTooltip.UniqueIconIM = InstanceManager:new("IconInfoInstance",	"Top", m_CivTooltip.InfoStack);
m_CivTooltip.HeaderIconIM = InstanceManager:new("IconInstance", "Top", m_CivTooltip.InfoStack);
m_CivTooltip.HeaderIM = InstanceManager:new("HeaderInstance", "Top", m_CivTooltip.InfoStack);

-- Game launch blockers
local m_bTeamsValid = true;						-- Are the teams valid for game start?
local g_everyoneConnected = true;				-- Is everyone network connected to the game?
local g_badPlayerForMapSize = false;			-- Are there too many active civs for this map?
local g_notEnoughPlayers = false;				-- Is there at least two players in the game?
local g_everyoneReady = false;					-- Is everyone ready to play?
local g_everyoneModReady = true;				-- Does everyone have the mods for this game?
local g_humanRequiredFilled = true;				-- Are all the human required slots filled by humans?
local g_duplicateLeaders = false;				-- Are there duplicate leaders blocking launch?
												-- Note:  This only applies if No Duplicate Leaders parameter is set.
local g_viewingGameSummary = true;
local g_hotseatNumHumanPlayers = 0;
local g_hotseatNumAIPlayers = 0;
local g_isBuildingPlayerList = false;

local m_iFirstClosedSlot = -1;					-- Closed slot to show Add player line

local g_fCountdownTimer = -1;			-- Start game countdown timer.  Set to -1 when not in use.
local g_fCountdownInitialTime = -1;		-- Initial time for the current countdown.
local g_fCountdownTickSoundTime	= -1;	-- When was the last time we make a countdown tick sound?
local g_fCountdownReadyButtonTime = -1;	-- When was the last time we updated the ready button countdown time?

-- hotseatOnly - Only available in hotseat mode.
-- hotseatInProgress = Available for active civs (AI/HUMAN) when loading a hotseat game
-- hotseatAllowed - Allowed in hotseat mode.
local g_slotTypeData = 
{
	{ name ="LOC_SLOTTYPE_OPEN",		tooltip = "LOC_SLOTTYPE_OPEN_TT",		hotseatOnly=false,	slotStatus=SlotStatus.SS_OPEN,		hotseatInProgress = false,		hotseatAllowed=false},
	{ name ="LOC_SLOTTYPE_AI",			tooltip = "LOC_SLOTTYPE_AI_TT",			hotseatOnly=false,	slotStatus=SlotStatus.SS_COMPUTER,	hotseatInProgress = true,		hotseatAllowed=true },
	{ name ="LOC_SLOTTYPE_CLOSED",		tooltip = "LOC_SLOTTYPE_CLOSED_TT",		hotseatOnly=false,	slotStatus=SlotStatus.SS_CLOSED,	hotseatInProgress = false,		hotseatAllowed=true },		
	{ name ="LOC_SLOTTYPE_HUMAN",		tooltip = "LOC_SLOTTYPE_HUMAN_TT",		hotseatOnly=true,	slotStatus=SlotStatus.SS_TAKEN,		hotseatInProgress = true,		hotseatAllowed=true },		
	{ name ="LOC_MP_SWAP_PLAYER",		tooltip = "TXT_KEY_MP_SWAP_BUTTON_TT",	hotseatOnly=false,	slotStatus=-1,						hotseatInProgress = true,		hotseatAllowed=true },		
};

local g_steamFriendActionsOnline = 
{
	{ name ="LOC_FRIEND_ACTION_INVITE",		tooltip = "LOC_FRIEND_ACTION_INVITE_TT",	action = "invite" },
	{ name ="LOC_FRIEND_ACTION_PROFILE",	tooltip = "LOC_FRIEND_ACTION_PROFILE_TT",	action = "profile" },
	{ name ="LOC_FRIEND_ACTION_CHAT",		tooltip = "LOC_FRIEND_ACTION_CHAT_TT",		action = "chat" },	
};

local g_steamFriendActionsNoInvite = 
{
	{ name ="LOC_FRIEND_ACTION_PROFILE",	tooltip = "LOC_FRIEND_ACTION_PROFILE_TT",	action = "profile" },
	{ name ="LOC_FRIEND_ACTION_CHAT",		tooltip = "LOC_FRIEND_ACTION_CHAT_TT",		action = "chat" },	
};

local MAX_EVER_PLAYERS : number = 62; -- hardwired max possible players in multiplayer, determined by how many players 
local MIN_EVER_PLAYERS : number = 2;  -- hardwired min possible players in multiplayer, the game does bad things if there aren't at least two players on different teams.
local MAX_SUPPORTED_PLAYERS : number = 8; -- Max number of officially supported players in multiplayer.  You can play with more than this number, but QA hasn't vetted it.
local g_currentMaxPlayers : number = MAX_EVER_PLAYERS;
local g_currentMinPlayers : number = MIN_EVER_PLAYERS;
	
local PlayerConnectedChatStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED_CHAT" );
local PlayerDisconnectedChatStr = Locale.Lookup( "LOC_MP_PLAYER_DISCONNECTED_CHAT" );
local PlayerHostMigratedChatStr = Locale.Lookup( "LOC_MP_PLAYER_HOST_MIGRATED_CHAT" );
local PlayerKickedChatStr = Locale.Lookup( "LOC_MP_PLAYER_KICKED_CHAT" );
local BytesStr = Locale.Lookup( "LOC_BYTES" );
local KilobytesStr = Locale.Lookup( "LOC_KILOBYTES" );
local MegabytesStr = Locale.Lookup( "LOC_MEGABYTES" );
local DefaultHotseatPlayerName = Locale.Lookup( "LOC_HOTSEAT_DEFAULT_PLAYER_NAME" );
local NotReadyStatusStr = Locale.Lookup("LOC_NOT_READY");
local ReadyStatusStr = Locale.Lookup("LOC_READY_LABEL");
local BadMapSizeSlotStatusStr = Locale.Lookup("LOC_INVALID_SLOT_MAP_SIZE");
local BadMapSizeSlotStatusStrTT = Locale.Lookup("LOC_INVALID_SLOT_MAP_SIZE_TT");
local UnsupportedText = Locale.Lookup("LOC_READY_UNSUPPORTED");
local UnsupportedTextTT = Locale.Lookup("LOC_READY_UNSUPPORTED_TT");
local downloadPendingStr = Locale.Lookup("LOC_MODS_SUBSCRIPTION_DOWNLOAD_PENDING");
local loadingSaveGameStr = Locale.Lookup("LOC_STAGING_ROOM_LOADING_SAVE");
local gameInProgressGameStr = Locale.Lookup("LOC_STAGING_ROOM_GAME_IN_PROGRESS");

local onlineIconStr = "[ICON_OnlinePip]";
local offlineIconStr = "[ICON_OfflinePip]";

local COLOR_GREEN				:number = 0xFF00FF00;
local COLOR_RED					:number = 0xFF0000FF;
local ColorString_ModGreen		:string = "[color:ModStatusGreen]";
local PLAYER_LIST_SIZE_DEFAULT	:number = 325;
local PLAYER_LIST_SIZE_HOTSEAT	:number = 535;
local GRID_LINE_WIDTH			:number = 1020;
local GRID_LINE_HEIGHT			:number = 51;
local NUM_COLUMNS				:number = 5;

local TEAM_ICON_SIZE			:number = 38;
local TEAM_ICON_PREFIX			:string = "ICON_TEAM_ICON_";

-------------------------------------------------
-- Localized Constants
-------------------------------------------------
local LOC_FRIENDS:string = Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_FRIENDS"));
local LOC_GAME_SETUP:string = Locale.Lookup("LOC_MULTIPLAYER_GAME_SETUP");
local LOC_GAME_SUMMARY:string = Locale.Lookup("LOC_MULTIPLAYER_GAME_SUMMARY");
local LOC_STAGING_ROOM:string = Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_STAGING_ROOM"));

----------------------------------------------------------------        
-- Input Handler
----------------------------------------------------------------        
function OnInputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			LuaEvents.Multiplayer_ExitShell();
			return true;
		end
	end
	return false;
end

----------------------------------------------------------------  
-- Helper Functions
---------------------------------------------------------------- 
function SetCurrentMaxPlayers( newMaxPlayers : number )
	g_currentMaxPlayers = math.min(newMaxPlayers, MAX_EVER_PLAYERS);
end

function SetCurrentMinPlayers( newMinPlayers : number )
	g_currentMinPlayers = math.max(newMinPlayers, MIN_EVER_PLAYERS);
end

----------------------------------------------------------------  
-- Event Handlers
---------------------------------------------------------------- 
function OnMapMaxMajorPlayersChanged(newMaxPlayers : number)
	if(g_currentMaxPlayers ~= newMaxPlayers) then
		SetCurrentMaxPlayers(newMaxPlayers);
		if(ContextPtr:IsHidden() == false) then
			CheckGameAutoStart();	-- game start can change based on the new max players.
			BuildPlayerList();	-- rebuild player list because several player slots will have changed.
		end
	end
end

function OnMapMinMajorPlayersChanged(newMinPlayers : number)
	if(g_currentMinPlayers ~= newMinPlayers) then
		SetCurrentMinPlayers(newMinPlayers);
		if(ContextPtr:IsHidden() == false) then
			CheckGameAutoStart();	-- game start can change based on the new min players.
		end
	end
end

-------------------------------------------------
-- OnGameConfigChanged
-------------------------------------------------
function OnGameConfigChanged()
	if(ContextPtr:IsHidden() == false) then
		RealizeGameSetup(); -- Rebuild the game settings UI.
		RebuildTeamPulldowns();	-- NoTeams setting might have changed.

		-- PLAYBYCLOUDTODO - Remove PBC special case once ready state changes have been moved to cloud player meta data.
		-- PlayByCloud uses GameConfigChanged to communicate player ready state changes, don't reset ready in that mode.
		if(not GameConfiguration.IsPlayByCloud()) then
			SetLocalReady(false);  -- unready so player can acknowledge the new settings.
		end
		CheckGameAutoStart();  -- Toggling "No Duplicate Leaders" can affect the start countdown.
	end
	OnMapMaxMajorPlayersChanged(MapConfiguration.GetMaxMajorPlayers());	
	OnMapMinMajorPlayersChanged(MapConfiguration.GetMinMajorPlayers());
end

-------------------------------------------------
-- OnPlayerInfoChanged
-------------------------------------------------
function PlayerInfoChanged_SpecificPlayer(playerID)
	-- Targeted update of another player's entry.
	local pPlayerConfig = PlayerConfigurations[playerID];
	if(g_cachedTeams[playerID] ~= pPlayerConfig:GetTeam()) then
		OnTeamChange(playerID, false);
	end

	Controls.PlayerListStack:SortChildren(SortPlayerListStack);
	UpdatePlayerEntry(playerID);
	
	Controls.PlayerListStack:CalculateSize();
	Controls.PlayerListStack:ReprocessAnchoring();
	Controls.PlayersScrollPanel:CalculateInternalSize();
end

function OnPlayerInfoChanged(playerID)
	if(ContextPtr:IsHidden() == false) then
		if(playerID == Network.GetLocalPlayerID()) then
			-- If we are the host and our info changed, we need to locally refresh all the player slots.
			-- We do this because the host's ready status disables/enables pulldowns on all the other player slots.
			if(Network.IsHost()) then
				UpdateAllPlayerEntries();
			else
				-- A remote client needs to update the disabled status of all slot type pulldowns if their data was changed.
				-- We do this because readying up disables the slot type pulldown for all players.
				UpdateAllPlayerEntries_SlotTypeDisabled();

				PlayerInfoChanged_SpecificPlayer(playerID);
			end
		else
			PlayerInfoChanged_SpecificPlayer(playerID);
		end

		CheckGameAutoStart();	-- Player might have changed their ready status.
		UpdateReadyButton();
		
		-- Update chat target pulldown.
		PlayerTarget_OnPlayerInfoChanged( playerID, Controls.ChatPull, Controls.ChatEntry, m_playerTargetEntries, m_playerTarget, false);
	end
end

-------------------------------------------------
-- OnTeamChange
-------------------------------------------------
function OnTeamChange( playerID, isBatchCall )
	local pPlayerConfig = PlayerConfigurations[playerID];
	if(pPlayerConfig ~= nil) then
		local teamID = pPlayerConfig:GetTeam();
		local playerEntry = GetPlayerEntry(playerID);
		local updateOpenEmptyTeam = false;

		-- Check for situations where we might need to update the Open Empty Team slot.
		if( (g_cachedTeams[playerID] ~= nil and GameConfiguration.GetTeamPlayerCount(g_cachedTeams[playerID]) <= 0) -- was last player on old team.
			or (GameConfiguration.GetTeamPlayerCount(teamID) <= 1) ) then -- first player on new team.
			-- this player was the last player on that team.  We might need to create a new empty team.
			updateOpenEmptyTeam = true;
		end
		
		if(g_cachedTeams[playerID] ~= nil and g_cachedTeams[playerID] ~= teamID) then
			-- Reset the player's ready status if they actually changed teams.
			SetLocalReady(false);
		end

		-- cache the player's teamID for the next OnTeamChange.
		g_cachedTeams[playerID] = teamID;
		
		if(not isBatchCall) then
			-- There's some stuff that we have to do it to maintain the player list. 
			-- We intentionally wait to do this if we're in the middle of doing a batch of these updates.
			-- If you're doing a batch of these, call UpdateTeamList(true) when you're done.
			UpdateTeamList(updateOpenEmptyTeam);
		end
	end	
end


-------------------------------------------------
-- OnMultiplayerPingTimesChanged
-------------------------------------------------
function OnMultiplayerPingTimesChanged()
	for playerID, playerEntry in pairs( g_PlayerEntries ) do
		--UpdateNetConnectionIcon(playerID, playerEntry.ConnectionStatus, playerEntry.StatusLabel);
		--UpdateNetConnectionLabel(playerID, playerEntry.StatusLabel);
	end
end

function OnCloudGameKilled( matchID, success )
	if(success) then
		-- On success, exit the screen
		LuaEvents.Multiplayer_ExitShell();
	else
		--Show error prompt.
		m_kPopupDialog:Close();
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MULTIPLAYER_ENDING_GAME_FAIL"));
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_MULTIPLAYER_ENDING_GAME_FAIL_ACCEPT") );
		m_kPopupDialog:Open();
	end
end

-------------------------------------------------
-- Chat
-------------------------------------------------
function OnMultiplayerChat( fromPlayer, toPlayer, text, eTargetType )
	OnChat(fromPlayer, toPlayer, text, eTargetType, true);
end

function OnChat( fromPlayer, toPlayer, text, eTargetType, playSounds :boolean )
	if(ContextPtr:IsHidden() == false) then
		local pPlayerConfig = PlayerConfigurations[fromPlayer];
		local playerName = Locale.Lookup(pPlayerConfig:GetPlayerName());

		-- Selecting chat text color based on eTargetType	
		local chatColor :string = "[color:ChatMessage_Global]";
		if(eTargetType == ChatTargetTypes.CHATTARGET_TEAM) then
			chatColor = "[color:ChatMessage_Team]";
		elseif(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER) then
			chatColor = "[color:ChatMessage_Whisper]";  
		end
		
		local chatString	= "[color:ChatPlayerName]" .. playerName;

		-- When whispering, include the whisperee's name as well.
		if(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER) then
			local pTargetConfig :table	= PlayerConfigurations[toPlayer];
			if(pTargetConfig ~= nil) then
				local targetName = Locale.Lookup(pTargetConfig:GetPlayerName());
				chatString = chatString .. " [" .. targetName .. "]";
			end
		end

		-- Ensure text parsed properly
		text = ParseChatText(text);

		chatString			= chatString .. ": [ENDCOLOR]" .. chatColor;
		chatString			= chatString .. text .. "[ENDCOLOR]";

		AddChatEntry( chatString, Controls.ChatStack, m_ChatInstances, Controls.ChatScroll);

		if(playSounds and fromPlayer ~= Network.GetLocalPlayerID()) then
			UI.PlaySound("Play_MP_Chat_Message_Received");
		end
	end
end

-------------------------------------------------
-------------------------------------------------
function SendChat( text )
    if( string.len( text ) > 0 ) then
		-- Parse text for possible chat commands
		local parsedText :string;
		local chatTargetChanged :boolean = false;
		local printHelp :boolean = false;
		parsedText, chatTargetChanged, printHelp = ParseInputChatString(text, m_playerTarget);
		if(chatTargetChanged) then
			ValidatePlayerTarget(m_playerTarget);
			UpdatePlayerTargetPulldown(Controls.ChatPull, m_playerTarget);
			UpdatePlayerTargetEditBox(Controls.ChatEntry, m_playerTarget);
		end

		if(printHelp) then
			ChatPrintHelp(Controls.ChatStack, m_ChatInstances, Controls.ChatScroll);
		end

		if(parsedText ~= "") then
			-- m_playerTarget uses PlayerTargetLogic values and needs to be converted  
			local chatTarget :table ={};
			PlayerTargetToChatTarget(m_playerTarget, chatTarget);
			Network.SendChat( parsedText, chatTarget.targetType, chatTarget.targetID );
			UI.PlaySound("Play_MP_Chat_Message_Sent");
		end
    end
    Controls.ChatEntry:ClearString();
end

-------------------------------------------------
-- ParseChatText - ensures icon tags parsed properly
-------------------------------------------------
function ParseChatText(text)
	startIdx, endIdx = string.find(string.upper(text), "%[ICON_");
	if(startIdx == nil) then
		return text;
	else
		for i = endIdx + 1, string.len(text) do
			character = string.sub(text, i, i);
			if(character=="]") then
				return string.sub(text, 1, i) .. ParseChatText(string.sub(text,i + 1));
			elseif(character==" ") then
				text = string.gsub(text, " ", "]", 1);
				return string.sub(text, 1, i) .. ParseChatText(string.sub(text, i + 1));
			elseif (character=="[") then
				return string.sub(text, 1, i - 1) .. "]" .. ParseChatText(string.sub(text, i));
			end
		end
		return text.."]";
	end
	return text;
end

-------------------------------------------------
-------------------------------------------------

function OnMultplayerPlayerConnected( playerID )
	if( ContextPtr:IsHidden() == false ) then
		OnChat( playerID, -1, PlayerConnectedChatStr, false );
		UI.PlaySound("Play_MP_Player_Connect");
	end
end

-------------------------------------------------
-------------------------------------------------

function OnMultiplayerPrePlayerDisconnected( playerID )
	if( ContextPtr:IsHidden() == false ) then
		local playerCfg = PlayerConfigurations[playerID];
		if(playerCfg:IsHuman()) then
			if(Network.IsPlayerKicked(playerID)) then
				OnChat( playerID, -1, PlayerKickedChatStr, false );
			else
    			OnChat( playerID, -1, PlayerDisconnectedChatStr, false );
			end
			UI.PlaySound("Play_MP_Player_Disconnect");
		end
	end
end

-------------------------------------------------
-------------------------------------------------

function OnModStatusUpdated(playerID: number, modState : number, bytesDownloaded : number, bytesTotal : number,
							modsRemaining : number, modsRequired : number)
	
	if(modState == 1) then -- MOD_STATE_DOWNLOADING
		local modStatusString = downloadPendingStr;
		modStatusString = modStatusString .. "[NEWLINE][Icon_AdditionalContent]" .. tostring(modsRemaining) .. "/" .. tostring(modsRequired);
		g_PlayerModStatus[playerID] = modStatusString;
	else
		g_PlayerModStatus[playerID] = nil;
	end
	UpdatePlayerEntry(playerID);

	--[[ Prototype Mod Status Progress Bars
	local playerEntry = g_PlayerEntries[playerID];
	if(playerEntry ~= nil) then
		if(modState ~= 1) then
			playerEntry.PlayerModProgressStack:SetHide(true);
		else
			-- MOD_STATE_DOWNLOADING
			playerEntry.PlayerModProgressStack:SetHide(false);

			-- Update Progress Bar
			local progress : number = 0;
			if(bytesTotal > 0) then
				progress = bytesDownloaded / bytesTotal;
			end
			playerEntry.ModProgressBar:SetPercent(progress);

			-- Building Bytes Remaining Label
			if(bytesTotal > 0) then
				local bytesRemainingStr : string = "";
				local modSizeStr : string = BytesStr;
				local bytesDownloadedScaled : number = bytesDownloaded;
				local bytesTotalScaled : number = bytesTotal;
				if(bytesTotal > 1000000) then
					-- Megabytes
					modSizeStr = MegabytesStr;
					bytesDownloadedScaled = bytesDownloadedScaled / 1000000;
					bytesTotalScaled = bytesTotalScaled / 1000000;
				elseif(bytesTotal > 1000) then
					-- kilobytes
					modSizeStr = KilobytesStr;
					bytesDownloadedScaled = bytesDownloadedScaled / 1000;
					bytesTotalScaled = bytesTotalScaled / 1000;
				end
				bytesRemainingStr = string.format("%.02f%s/%.02f%s", bytesDownloadedScaled, modSizeStr, bytesTotalScaled, modSizeStr);
				playerEntry.BytesRemaining:SetText(bytesRemainingStr);
				playerEntry.BytesRemaining:SetHide(false);
			else
				playerEntry.BytesRemaining:SetHide(true);
			end

			-- Bulding ModProgressRemaining Label
			local modProgressStr : string = "";
			modProgressStr = modProgressStr .. " " .. tostring(modsRemaining) .. "/" .. tostring(modsRequired);
			playerEntry.ModProgressRemaining:SetText(modProgressStr);
		end
	end
	--]]
end

-------------------------------------------------
-------------------------------------------------

function OnAbandoned(eReason)
	if (not ContextPtr:IsHidden()) then

		-- We need to CheckLeaveGame before triggering the reason popup because the reason popup hides the staging room
		-- and would block the leave game incorrectly.  This fixes TTP 22192.
		CheckLeaveGame();

		if (eReason == KickReason.KICK_HOST) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_KICKED" );
		elseif (eReason == KickReason.KICK_NO_HOST) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_HOST_LOSTED" );
		elseif (eReason == KickReason.KICK_NO_ROOM) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_ROOM_FULL" );
		elseif (eReason == KickReason.KICK_VERSION_MISMATCH) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_VERSION_MISMATCH" );
		elseif (eReason == KickReason.KICK_MOD_ERROR) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_MOD_ERROR" );
		elseif (eReason == KickReason.KICK_MOD_MISSING) then
			local modMissingErrorStr = Modding.GetLastModErrorString();
			LuaEvents.MultiplayerPopup(modMissingErrorStr);
		else
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_CONNECTION_LOST");
		end
		LuaEvents.Multiplayer_ExitShell();
	end
end

-------------------------------------------------
-------------------------------------------------

function OnMultiplayerGameLaunchFailed()
	-- Multiplayer game failed for launch for some reason.
	SetLocalReady(false); -- Unready the local player so they can try it again.

	m_kPopupDialog:Close();	-- clear out the popup incase it is already open.
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MULTIPLAYER_GAME_LAUNCH_FAILED"));
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_MULTIPLAYER_GAME_LAUNCH_FAILED_ACCEPT"));
	m_kPopupDialog:Open();
end

-------------------------------------------------
-------------------------------------------------

function OnLeaveGameComplete()
	-- We just left the game, we shouldn't be open anymore.
	UIManager:DequeuePopup( ContextPtr );
end

-------------------------------------------------
-------------------------------------------------

function OnBeforeMultiplayerInviteProcessing()
	-- We're about to process a game invite.  Get off the popup stack before we accidently break the invite!
	UIManager:DequeuePopup( ContextPtr );
end


-------------------------------------------------
-------------------------------------------------

function OnMultiplayerHostMigrated( newHostID : number )
	if(ContextPtr:IsHidden() == false) then
		-- If the local machine has become the host, we need to rebuild the UI so host privileges are displayed.
		local localPlayerID = Network.GetLocalPlayerID();
		if(localPlayerID == newHostID) then
			RealizeGameSetup();
			BuildPlayerList();
		end

		OnChat( newHostID, -1, PlayerHostMigratedChatStr, false );
		UI.PlaySound("Play_MP_Host_Migration");
	end
end

----------------------------------------------------------------
-- Button Handlers
----------------------------------------------------------------

-------------------------------------------------
-- OnSlotType
-------------------------------------------------
function OnSlotType( playerID, id )
	--print("playerID: " .. playerID .. " id: " .. id);
	-- NOTE:  This function assumes that the given player slot is not occupied by a player.  We
	--				assume that players having to be kicked before the slot's type can be manually changed.
	local pPlayerConfig = PlayerConfigurations[playerID];
	local pPlayerEntry = g_PlayerEntries[playerID];

	if g_slotTypeData[id].slotStatus == -1 then
		OnSwapButton(playerID);
		return;
	end

	pPlayerConfig:SetSlotStatus(g_slotTypeData[id].slotStatus);

	-- When setting the slot status to a major civ type, some additional data in the player config needs to be set.
	if(g_slotTypeData[id].slotStatus == SlotStatus.SS_TAKEN or g_slotTypeData[id].slotStatus == SlotStatus.SS_COMPUTER) then
		pPlayerConfig:SetMajorCiv();
	end

	Network.BroadcastPlayerInfo(playerID); -- Network the slot status change.
	
	Controls.PlayerListStack:SortChildren(SortPlayerListStack);
	
	m_iFirstClosedSlot = -1;
	UpdateAllPlayerEntries();

	UpdatePlayerEntry(playerID);

	CheckTeamsValid();
	CheckGameAutoStart();

	if g_slotTypeData[id].slotStatus == SlotStatus.SS_CLOSED then
		Controls.PlayerListStack:CalculateSize();
		Controls.PlayerListStack:ReprocessAnchoring();
		Controls.PlayersScrollPanel:CalculateInternalSize();
	end
end

-------------------------------------------------
-- OnSwapButton
-------------------------------------------------
function OnSwapButton(playerID)
	-- In this case, playerID is the desired playerID.
	local localPlayerID = Network.GetLocalPlayerID();
	local oldDesiredPlayerID = Network.GetChangePlayerID(localPlayerID);
	local newDesiredPlayerID = playerID;
	if(oldDesiredPlayerID == newDesiredPlayerID) then
		-- player already requested to swap to this player.  Toggle back to no player swap.
		newDesiredPlayerID = NetPlayerTypes.INVALID_PLAYERID;
	end
	Network.RequestPlayerIDChange(newDesiredPlayerID);
end

-------------------------------------------------
-- OnKickButton
-------------------------------------------------
function OnKickButton(playerID)
	-- Kick button was clicked for the given player slot.
	--print("playerID " .. playerID);
	UIManager:PushModal(Controls.ConfirmKick, true);
	local pPlayerConfig = PlayerConfigurations[playerID];
	if pPlayerConfig:GetSlotStatus() == SlotStatus.SS_COMPUTER then
		LuaEvents.SetKickPlayer(playerID, "LOC_SLOTTYPE_AI");
	else
		local playerName = pPlayerConfig:GetPlayerName();
		LuaEvents.SetKickPlayer(playerID, playerName);
	end
end

-------------------------------------------------
-- OnAddPlayer
-------------------------------------------------
function OnAddPlayer(playerID)
	-- Add Player was clicked for the given player slot.
	-- Set this slot to open	
	local pPlayerConfig = PlayerConfigurations[playerID];
	local playerName = pPlayerConfig:GetPlayerName();
	m_iFirstClosedSlot = -1;
	
	pPlayerConfig:SetSlotStatus(SlotStatus.SS_OPEN);
	Network.BroadcastPlayerInfo(playerID); -- Network the slot status change.

	Controls.PlayerListStack:SortChildren(SortPlayerListStack);
	UpdateAllPlayerEntries();

	CheckTeamsValid();
	CheckGameAutoStart();

	Controls.PlayerListStack:CalculateSize();
	Controls.PlayerListStack:ReprocessAnchoring();
	Controls.PlayersScrollPanel:CalculateInternalSize();
end

-------------------------------------------------
-- OnPlayerEntryReady
-------------------------------------------------
function OnPlayerEntryReady(playerID)
	-- Every player entry ready button has this callback, but it only does something if this is for the local player.
	local localPlayerID = Network.GetLocalPlayerID();
	if(playerID == localPlayerID) then
		OnReadyButton();
	end
end

-------------------------------------------------
-- OnJoinTeamButton
-------------------------------------------------
function OnTeamPull( playerID :number, teamID :number)
	local playerConfig = PlayerConfigurations[playerID];

	if(playerConfig ~= nil and teamID ~= playerConfig:GetTeam()) then
		playerConfig:SetTeam(teamID);
		Network.BroadcastPlayerInfo(playerID);
		OnTeamChange(playerID, false);
	end

	UpdatePlayerEntry(playerID);
end

-------------------------------------------------
-- OnInviteButton
-------------------------------------------------
function OnInviteButton()
	if (Steam ~= nil) then
		Steam.ActivateInviteOverlay();
	end
end

-------------------------------------------------
-- OnReadyButton
-------------------------------------------------
function OnReadyButton()
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];
	SetLocalReady(not localPlayerConfig:GetReady());
	
	if(GameConfiguration.IsHotseat()) then
		-- Readying up in hotseat just starts the game.
		Network.LaunchGame();
	end
end

----------------------------------------------------------------
-- Screen Scripting
----------------------------------------------------------------
function SetLocalReady(newReady)
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];

	
	if(newReady ~= localPlayerConfig:GetReady()) then
		
		if not GameConfiguration.IsHotseat() then
			Controls.ReadyCheck:SetSelected(newReady);
		end

		localPlayerConfig:SetReady(newReady);
		Network.BroadcastPlayerInfo();
		UpdatePlayerEntry(localPlayerID);
		CheckGameAutoStart();
	end
end

-------------------------------------------------
-- Update Teams valid status
-------------------------------------------------
function CheckTeamsValid()
	m_bTeamsValid = false;
	local noTeamPlayers : boolean = false;
	local teamTest : number = TeamTypes.NO_TEAM;
    
	-- Teams are invalid if all players are on the same team.
	local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		local curPlayerConfig = PlayerConfigurations[iPlayer];
		if( curPlayerConfig:IsParticipant() 
		and curPlayerConfig:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV ) then
			local curTeam : number = curPlayerConfig:GetTeam();
			if(curTeam == TeamTypes.NO_TEAM) then
				-- If someone doesn't have a team, it means that teams are valid.
				m_bTeamsValid = true;
				return;
			elseif(teamTest == TeamTypes.NO_TEAM) then
				teamTest = curTeam;
			elseif(teamTest ~= curTeam) then
				-- people are on different teams.  Teams are valid.
				m_bTeamsValid = true;
				return;
			end
		end
	end
end

-------------------------------------------------
-- CHECK FOR GAME AUTO START
-------------------------------------------------
function CheckGameAutoStart()
	-- Check to see if we should start/stop the multiplayer game.
	if(not Network.IsPlayerHotJoining(Network.GetLocalPlayerID())) then
		local startCountdown = true;

		--reset global blocking variables because we're going to recalculate them.
		g_everyoneReady = true;
		g_everyoneConnected = true;
		g_badPlayerForMapSize = false;
		g_notEnoughPlayers = false;
		g_everyoneModReady = true;
		g_duplicateLeaders = false;
		g_humanRequiredFilled = true;

		-- Count players and check to see if a human player isn't ready.
		local totalPlayers = 0;
		local noDupLeaders = GameConfiguration.GetValue("NO_DUPLICATE_LEADERS");
		local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
		for i, iPlayer in ipairs(player_ids) do	
			local curPlayerConfig = PlayerConfigurations[iPlayer];
			local curSlotStatus = curPlayerConfig:GetSlotStatus();
			local curIsFullCiv = curPlayerConfig:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV;
			if(curSlotStatus == SlotStatus.SS_TAKEN) then
				if(not curPlayerConfig:GetReady()) then
					print("CheckGameAutoStart: Can't start game because player ".. iPlayer .. " isn't ready");
					startCountdown = false;
					g_everyoneReady = false;
				-- Players are set to ModRrady when have they successfully downloaded and configured all the mods required for this game.
				-- See Network::Manager::OnFinishedGameplayContentConfigure()
				elseif(not curPlayerConfig:GetModReady()) then
					print("CheckGameAutoStart: Can't start game because player ".. iPlayer .. " isn't mod ready");
					startCountdown = false;
					g_everyoneModReady = false;
				end
			elseif(curPlayerConfig:IsHumanRequired() == true) then
				--A human required slot is not filled by a human.  Can't launch.
				startCountdown = false;
				g_humanRequiredFilled = false;
			end
			if( (curSlotStatus == SlotStatus.SS_COMPUTER or curSlotStatus == SlotStatus.SS_TAKEN) and curIsFullCiv ) then
				totalPlayers = totalPlayers + 1;
				if(iPlayer >= g_currentMaxPlayers) then
					-- A player is occupying an invalid player slot for this map size.
					print("CheckGameAutoStart: Can't start game because player " .. iPlayer .. " is in an invalid slot for this map size.");
					startCountdown = false;
					g_badPlayerForMapSize = true;
				end

				-- Check for selection error (ownership rules, duplicate leaders, etc)
				local err = GetPlayerParameterError(iPlayer)
				if(err) then
					
					startCountdown = false;
					if(noDupLeaders and err.Id == "InvalidDomainValue" and err.Reason == "LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS") then
						g_duplicateLeaders = true;
					end
				end

			end
		end

		-- Check player count
		if(totalPlayers < g_currentMinPlayers) then
			print("CheckGameAutoStart: Can't start game because there are not enough players. " .. totalPlayers .. "/" .. g_currentMinPlayers);
			startCountdown = false;
			g_notEnoughPlayers = true;
		end

		if(not Network.IsEveryoneConnected()) then
			print("CheckGameAutoStart: Can't start game because players are joining the game.");
			startCountdown = false;
			g_everyoneConnected = false;
		end

		if(not m_bTeamsValid) then
			print("CheckGameAutoStart: Can't start game because all civs are on the same team!");
			startCountdown = false;
		end

	
		-- Hotseat bypasses the countdown system.
		if not GameConfiguration.IsHotseat() then
			if(startCountdown) then
				-- Everyone has readied up and we can start.
				StartCountdown();
			else
				-- We can't autostart now, stop the countdown incase we started it earlier.
				StopCountdown();
			end
		end
	end
	UpdateReadyButton();
end

-------------------------------------------------
-- Leave the Game
-------------------------------------------------
function CheckLeaveGame()
	-- Leave the network session if we're in a state where the staging room should be triggering the exit.
	if not ContextPtr:IsHidden()	-- If the screen is not visible, this exit might be part of a general UI state change (like Multiplayer_ExitShell)
									-- and should not trigger a game exit.
		and Network.IsInSession()	-- Still in a network session.
		and not Network.IsInGameStartedState() then -- Don't trigger leave game if we're being used as an ingame screen. Worldview is handling this instead.
		Network.LeaveGame();
	end
end

function HandleExitRequest()
	print("Staging Room -Handle Exit Request");

	CheckLeaveGame();
	
	-- Force close all popups because they are modal and will remain visible even if the screen is hidden
	for _, playerEntry:table in ipairs(g_PlayerEntries) do
		playerEntry.SlotTypePulldown:ForceClose();
		playerEntry.AlternateSlotTypePulldown:ForceClose();
		playerEntry.TeamPullDown:ForceClose();
		playerEntry.PlayerPullDown:ForceClose();
		playerEntry.HandicapPullDown:ForceClose();
	end

	-- Destroy setup parameters.
	HideGameSetup(function()
		-- Reset instances here.
		m_gameSetupParameterIM:ResetInstances();
	end);
	
	-- Destroy individual player parameters.
	ReleasePlayerParameters();

	-- Exit directly to Lobby
	ResetChat();
	UIManager:DequeuePopup( ContextPtr );
end

function GetPlayerEntry(playerID)
	local playerEntry = g_PlayerEntries[playerID];
	if(playerEntry == nil) then
		-- need to create the player entry.
		--print("creating playerEntry for player " .. tostring(playerID));
		playerEntry = m_playersIM:GetInstance();

		--SetupTeamPulldown( playerID, playerEntry.TeamPullDown );

		local civTooltipData : table = {
			InfoStack			= m_CivTooltip.InfoStack,
			InfoScrollPanel		= m_CivTooltip.InfoScrollPanel;
			CivToolTipSlide		= m_CivTooltip.CivToolTipSlide;
			CivToolTipAlpha		= m_CivTooltip.CivToolTipAlpha;
			UniqueIconIM		= m_CivTooltip.UniqueIconIM;		
			HeaderIconIM		= m_CivTooltip.HeaderIconIM;
			HeaderIM			= m_CivTooltip.HeaderIM;
			HasLeaderPlacard	= false;
		};

		SetupLeaderPulldown(playerID, playerEntry,"PlayerPullDown",nil,nil,civTooltipData);
		SetupTeamPulldown(playerID, playerEntry.TeamPullDown);
		SetupHandicapPulldown(playerID, playerEntry.HandicapPullDown);


		--playerEntry.PlayerCard:RegisterCallback( Mouse.eLClick, OnSwapButton );
		--playerEntry.PlayerCard:SetVoid1(playerID);
		playerEntry.KickButton:RegisterCallback( Mouse.eLClick, OnKickButton );
		playerEntry.KickButton:SetVoid1(playerID);
		playerEntry.AddPlayerButton:RegisterCallback( Mouse.eLClick, OnAddPlayer );
		playerEntry.AddPlayerButton:SetVoid1(playerID);
		--[[ Prototype Mod Status Progress Bars
		playerEntry.PlayerModProgressStack:SetHide(true);
		--]]
		playerEntry.ReadyImage:RegisterCallback( Mouse.eLClick, OnPlayerEntryReady );
		playerEntry.ReadyImage:SetVoid1(playerID);

		g_PlayerEntries[playerID] = playerEntry;
		g_PlayerRootToPlayerID[tostring(playerEntry.Root)] = playerID;

		-- Remember starting ready status.
		local pPlayerConfig = PlayerConfigurations[playerID];
		g_PlayerReady[playerID] = pPlayerConfig:GetReady();

		UpdatePlayerEntry(playerID);

		Controls.PlayerListStack:SortChildren(SortPlayerListStack);
	end

	return playerEntry;
end

-------------------------------------------------
-- PopulateSlotTypePulldown
-------------------------------------------------
function PopulateSlotTypePulldown( pullDown, playerID, slotTypeOptions )
	
	local instanceManager = pullDown["InstanceManager"];
	if not instanceManager then
		instanceManager = PullDownInstanceManager:new("InstanceOne", "Button", pullDown);
		pullDown["InstanceManager"] = instanceManager;
	end
	
	
	instanceManager:ResetInstances();
	pullDown.ItemCount = 0;

	for i, pair in ipairs(slotTypeOptions) do

		local pPlayerConfig = PlayerConfigurations[playerID];
		local playerSlotStatus = pPlayerConfig:GetSlotStatus();

		-- This option is a valid swap player option.
		local showSwapButton = pair.slotStatus == -1 
			and playerSlotStatus ~= SlotStatus.SS_CLOSED -- Can't swap to closed slots.
			and not pPlayerConfig:IsLocked() -- Can't swap to locked slots.
			and not GameConfiguration.IsHotseat(); -- no swap option in hotseat.

		-- This option is a valid slot type option.
		local showSlotButton = pair.slotStatus ~= -1 
			and Network.IsHost() -- Only the host can change slot types.
			-- You can't switch a civilization to open/closed if the game is at the minimum player count.
			and ((pair.slotStatus ~= SlotStatus.SS_CLOSED and pair.slotStatus ~= SlotStatus.SS_OPEN)		-- Target SlotType isn't open/close
				or (playerSlotStatus ~= SlotStatus.SS_TAKEN and playerSlotStatus ~= SlotStatus.SS_COMPUTER) -- Current SlotType isn't a civ
				or (GameConfiguration.IsPlayByCloud() and pair.slotStatus == SlotStatus.SS_OPEN)			-- In PlayByCloud OPEN slots are autoflagged as HumanRequired.
																											-- We allow them to bypass the minimum player count because 
																											-- a human player must occupy the slot for the game to launch. 
				or GameConfiguration.GetParticipatingPlayerCount() > g_currentMinPlayers)					-- Above player count
			and (playerSlotStatus ~= SlotStatus.SS_TAKEN or GameConfiguration.IsHotseat())					-- You can only change the slot type of humans while in hotseat.
			and not pPlayerConfig:IsLocked() -- Can't change the slot type of locked player slots.
			-- Can normally only change slot types in the pregame unless this is a option that can be changed mid-game in hotseat.
			and (GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_PREGAME 
				or (pair.hotseatInProgress and GameConfiguration.IsHotseat())); 

		-- Valid state for hotseatOnly flag
		local hotseatOnlyCheck = (GameConfiguration.IsHotseat() and pair.hotseatAllowed) or (not GameConfiguration.IsHotseat() and not pair.hotseatOnly);

		if(	hotseatOnlyCheck 
			and playerID ~= Network.GetLocalPlayerID()
			and (showSwapButton or showSlotButton)) then

			pullDown.ItemCount = pullDown.ItemCount + 1;
			local instance = instanceManager:GetInstance();
			local slotDisplayName = pair.name;
			local slotToolTip = pair.tooltip;

			-- In PlayByCloud OPEN slots are autoflagged as HumanRequired., morph the display name and tooltip.
			if(GameConfiguration.IsPlayByCloud() and pair.slotStatus == SlotStatus.SS_OPEN) then
				slotDisplayName = "LOC_SLOTTYPE_HUMANREQ";
				slotToolTip = "LOC_SLOTTYPE_HUMANREQ_TT";
			end

			instance.Button:LocalizeAndSetText( slotDisplayName );

			if pair.slotStatus == -1 then
				local isHuman = (playerSlotStatus == SlotStatus.SS_TAKEN);
				instance.Button:LocalizeAndSetToolTip(isHuman and "TXT_KEY_MP_SWAP_WITH_PLAYER_BUTTON_TT" or "TXT_KEY_MP_SWAP_BUTTON_TT");
			else
				instance.Button:LocalizeAndSetToolTip( slotToolTip );
			end
			instance.Button:SetVoids( playerID, i );	
		end
	end

	pullDown:CalculateInternals();
	pullDown:RegisterSelectionCallback(OnSlotType);
	pullDown:SetDisabled(pullDown.ItemCount < 1);
end

-------------------------------------------------
-- Team Scripting
-------------------------------------------------
function GetTeamCounts( teamCountTable :table )
	for playerID, teamID in pairs(g_cachedTeams) do
		if(teamCountTable[teamID] == nil) then
			teamCountTable[teamID] = 1;
		else
			teamCountTable[teamID] = teamCountTable[teamID] + 1;
		end
	end
end

function AddTeamPulldownEntry( playerID:number, pullDown:table, instanceManager:table, teamID:number, teamName:string )
	
	local instance = instanceManager:GetInstance();
	
	if teamID >= 0 then
		local teamIconName:string = TEAM_ICON_PREFIX .. tostring(teamID);
		instance.ButtonImage:SetSizeVal(TEAM_ICON_SIZE, TEAM_ICON_SIZE);
		instance.ButtonImage:SetIcon(teamIconName, TEAM_ICON_SIZE);
		instance.ButtonImage:SetColor(GetTeamColor(teamID));
	end

	instance.Button:SetVoids( playerID, teamID );
end

function SetupTeamPulldown( playerID:number, pullDown:table )

	local instanceManager = pullDown["InstanceManager"];
	if not instanceManager then
		instanceManager = PullDownInstanceManager:new("InstanceOne", "Button", pullDown);
		pullDown["InstanceManager"] = instanceManager;
	end
	instanceManager:ResetInstances();

	local teamCounts = {};
	GetTeamCounts(teamCounts);

	local pulldownEntries = {};
	local noTeams = GameConfiguration.GetValue("NO_TEAMS");

	-- Always add "None" entry
	local newPulldownEntry:table = {};
	newPulldownEntry.teamID = -1;
	newPulldownEntry.teamName = GameConfiguration.GetTeamName(-1);
	table.insert(pulldownEntries, newPulldownEntry);

	if(not noTeams) then
		for teamID, playerCount in pairs(teamCounts) do
			if teamID ~= -1 then
				newPulldownEntry = {};
				newPulldownEntry.teamID = teamID;
				newPulldownEntry.teamName = GameConfiguration.GetTeamName(teamID);
				table.insert(pulldownEntries, newPulldownEntry);
			end
		end

		-- Add an empty team slot so players can join/create a new team
		local newTeamID :number = 0;
		while(teamCounts[newTeamID] ~= nil) do
			newTeamID = newTeamID + 1;
		end
		local newTeamName : string = tostring(newTeamID);
		newPulldownEntry = {};
		newPulldownEntry.teamID = newTeamID;
		newPulldownEntry.teamName = newTeamName;
		table.insert(pulldownEntries, newPulldownEntry);
	end

	table.sort(pulldownEntries, function(a, b) return a.teamID < b.teamID; end);

	for pullID, curPulldownEntry in ipairs(pulldownEntries) do
		AddTeamPulldownEntry(playerID, pullDown, instanceManager, curPulldownEntry.teamID, curPulldownEntry.teamName);
	end

	pullDown:CalculateInternals();
	pullDown:RegisterSelectionCallback( OnTeamPull );
end

function RebuildTeamPulldowns()
	for playerID, playerEntry in pairs( g_PlayerEntries ) do
		SetupTeamPulldown(playerID, playerEntry.TeamPullDown);
	end
end

function UpdateTeamList(updateOpenEmptyTeam)
	if(updateOpenEmptyTeam) then
		-- Regenerate the team pulldowns to show at least one empty team option so players can create new teams.
		RebuildTeamPulldowns();
	end

	CheckTeamsValid(); -- Check to see if the teams are valid for game start.
	CheckGameAutoStart();

	if GameConfiguration.IsHotseat() then
		Controls.PrimaryStackGrid:SetSizeY(PLAYER_LIST_SIZE_HOTSEAT);
	else
		Controls.PrimaryStackGrid:SetSizeY(PLAYER_LIST_SIZE_DEFAULT);
	end

	Controls.PlayerListStack:CalculateSize();
	Controls.PlayerListStack:ReprocessAnchoring();
	Controls.PlayersScrollPanel:CalculateInternalSize();
	Controls.HotseatDeco:SetHide(not GameConfiguration.IsHotseat());
end

-------------------------------------------------
-- UpdatePlayerEntry
-------------------------------------------------
function UpdateAllPlayerEntries()
	for playerID, playerEntry in pairs( g_PlayerEntries ) do
		 UpdatePlayerEntry(playerID);
	end
end

-- Update the disabled state of the slot type pulldown for all players.
function UpdateAllPlayerEntries_SlotTypeDisabled()
	for playerID, playerEntry in pairs( g_PlayerEntries ) do
		 UpdatePlayerEntry_SlotTypeDisabled(playerID);
	end
end

-- Update the disabled state of the slot type pulldown for this player.
function UpdatePlayerEntry_SlotTypeDisabled(playerID)
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];
	local playerEntry = g_PlayerEntries[playerID];
	if(playerEntry ~= nil) then

		-- Disable the pulldown if there are no items in it.
		local itemCount = playerEntry.SlotTypePulldown.ItemCount or 0;

		-- The slot type pulldown handles user access permissions internally (See PopulateSlotTypePulldown()).  
		-- However, we need to disable the pulldown entirely if the local player has readied up.
		local bCanChangeSlotType:boolean = not localPlayerConfig:GetReady() 
											and playerID ~= Network.GetLocalPlayerID()
											and itemCount > 0; -- No available slot type options.

		playerEntry.AlternateSlotTypePulldown:SetDisabled(not bCanChangeSlotType);
		playerEntry.SlotTypePulldown:SetDisabled(not bCanChangeSlotType);
	end
end

function UpdatePlayerEntry(playerID)
	local playerEntry = g_PlayerEntries[playerID];
	if(playerEntry ~= nil) then
		local localPlayerID = Network.GetLocalPlayerID();
		local localPlayerConfig = PlayerConfigurations[localPlayerID];
		local pPlayerConfig = PlayerConfigurations[playerID];
		local slotStatus = pPlayerConfig:GetSlotStatus();
		local isMinorCiv = pPlayerConfig:GetCivilizationLevelTypeID() ~= CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV;
		local isAlive = pPlayerConfig:IsAlive();
		local isActiveSlot = not isMinorCiv and (slotStatus ~= SlotStatus.SS_CLOSED) and (slotStatus ~= SlotStatus.SS_OPEN) and isAlive;
		local isHotSeat:boolean = GameConfiguration.IsHotseat();
		
		-- Has this game aleady been started?  Hot joining or loading a save game.
		local gameInProgress:boolean = GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_PREGAME;

		-- NOTE: UpdatePlayerEntry() currently only has control over the team player attribute.  Everything else is controlled by 
		--		PlayerConfigurationValuesToUI() and the PlayerSetupLogic.  See CheckExternalEnabled().
		-- Can the local player change this slot's attributes (handicap; civ, etc) at this time?
		local bCanChangePlayerValues = not pPlayerConfig:GetReady()  -- Can't change a slot once that player is ready.
										and not gameInProgress -- Can't change player values once the game has been started.
										and not pPlayerConfig:IsLocked() -- Can't change the values of locked players.
										and (playerID == localPlayerID		-- You can change yourself.
											-- Game host can alter all the non-human slots if they are not ready.
											or (slotStatus ~= SlotStatus.SS_TAKEN and Network.IsHost() and not localPlayerConfig:GetReady())
											-- The player has permission to change everything in hotseat.
											or isHotSeat);
		

			
		local isKickable:boolean = Network.IsHost()			-- Only the host may kick
			and slotStatus == SlotStatus.SS_TAKEN
			and playerID ~= localPlayerID			-- Can't kick yourself
			and not isHotSeat;	-- Can't kick in hotseat, players use the slot type pulldowns instead.

		-- Show player card for human players only during online matches
		local hidePlayerCard:boolean = isHotSeat or slotStatus ~= SlotStatus.SS_TAKEN;
		local showHotseatEdit:boolean = isHotSeat and slotStatus == SlotStatus.SS_TAKEN;
		playerEntry.SlotTypePulldown:SetHide(hidePlayerCard);
		playerEntry.HotseatEditButton:SetHide(not showHotseatEdit);
		playerEntry.AlternateEditButton:SetHide(not hidePlayerCard);
		playerEntry.AlternateSlotTypePulldown:SetHide(not hidePlayerCard);


		local statusText:string = "";
		if slotStatus == SlotStatus.SS_TAKEN then
			local hostID:number = Network.GetHostPlayerID()
			statusText = Locale.Lookup(playerID == hostID and "LOC_SLOTLABEL_HOST" or "LOC_SLOTLABEL_PLAYER");
		elseif slotStatus == SlotStatus.SS_COMPUTER then
			statusText = Locale.Lookup("LOC_SLOTLABEL_COMPUTER");
		end
		playerEntry.PlayerStatus:SetText(statusText);
		playerEntry.AlternateStatus:SetText(statusText);

		-- Update cached ready status and play sound if player is newly ready.
		if slotStatus == SlotStatus.SS_TAKEN then
			local isReady:boolean = pPlayerConfig:GetReady();
			if(isReady ~= g_PlayerReady[playerID]) then
				g_PlayerReady[playerID] = isReady;
				if(isReady == true) then
					UI.PlaySound("Play_MP_Player_Ready");
				end
			end
		end

		-- Update ready icon
		if not isHotSeat then
			if g_PlayerReady[playerID] or slotStatus == SlotStatus.SS_COMPUTER then
				playerEntry.ReadyImage:SetTextureOffsetVal(0,136);
			else
				playerEntry.ReadyImage:SetTextureOffsetVal(0,0);
			end

			-- Update status string
			local statusString = NotReadyStatusStr;
			local statusTTString = "";
			if(slotStatus == SlotStatus.SS_TAKEN 
				and not pPlayerConfig:GetModReady() 
				and g_PlayerModStatus[playerID] ~= nil 
				and g_PlayerModStatus[playerID] ~= "") then
				statusString = g_PlayerModStatus[playerID];
			elseif(playerID >= g_currentMaxPlayers) then
				-- Player is invalid slot for this map size.
				statusString = BadMapSizeSlotStatusStr;
				statusTTString = BadMapSizeSlotStatusStrTT;
			elseif(g_PlayerReady[playerID] or slotStatus == SlotStatus.SS_COMPUTER) then
				statusString = ReadyStatusStr;
			end

			-- Check to see if we should warning that this player is above MAX_SUPPORTED_PLAYERS.
			local playersBeforeUs = 0;
			for iLoopPlayer = 0, playerID-1, 1 do	
				local loopPlayerConfig = PlayerConfigurations[iLoopPlayer];
				local loopSlotStatus = loopPlayerConfig:GetSlotStatus();
				local loopIsFullCiv = loopPlayerConfig:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV;
				if( (loopSlotStatus == SlotStatus.SS_COMPUTER or loopSlotStatus == SlotStatus.SS_TAKEN) and loopIsFullCiv ) then
					playersBeforeUs = playersBeforeUs + 1;
				end
			end
			if playersBeforeUs >= MAX_SUPPORTED_PLAYERS then
				statusString = statusString .. "[NEWLINE][COLOR_Red]" .. UnsupportedText;
				if statusTTString ~= "" then
					statusTTString = statusTTString .. "[NEWLINE][COLOR_Red]" .. UnsupportedTextTT;
				else
					statusTTString = "[COLOR_Red]" .. UnsupportedTextTT;
				end
			end

			local err = GetPlayerParameterError(playerID)
			if(err) then
				local reason = err.Reason or "LOC_SETUP_PLAYER_PARAMETER_ERROR";
				statusString = statusString .. "[NEWLINE][COLOR_Red]" .. Locale.Lookup(reason) .. "[ENDCOLOR]";
			end

			playerEntry.StatusLabel:SetText(statusString);
			playerEntry.StatusLabel:SetToolTipString(statusTTString);
		end
		playerEntry.StatusLabel:SetHide(isHotSeat or slotStatus == SlotStatus.SS_OPEN);

		if playerID == localPlayerID then
			playerEntry.YouIndicatorLine:SetHide(false);
		else
			playerEntry.YouIndicatorLine:SetHide(true);
		end

		playerEntry.AddPlayerButton:SetHide(true);
		-- Available actions vary if the slot has an active player in it
		if(isActiveSlot) then
			playerEntry.Root:SetHide(false);
			playerEntry.PlayerPullDown:SetHide(false);
			playerEntry.ReadyImage:SetHide(isHotSeat);
			playerEntry.TeamPullDown:SetHide(false);
			playerEntry.HandicapPullDown:SetHide(false);
			playerEntry.KickButton:SetHide(not isKickable);
		else
			if(playerID >= g_currentMaxPlayers) then
				-- inactive slot is invalid for the current map size, hide it.
				playerEntry.Root:SetHide(true);
			elseif slotStatus == SlotStatus.SS_CLOSED then
				
				if (m_iFirstClosedSlot == -1 or m_iFirstClosedSlot == playerID) 
				and Network.IsHost() 
				and not gameInProgress 
				and g_fCountdownTimer == -1 then -- Don't show Add Player button while in the countdown.
					m_iFirstClosedSlot = playerID;
					playerEntry.AddPlayerButton:SetHide(false);
					playerEntry.Root:SetHide(false);
				else
					playerEntry.Root:SetHide(true);
				end
			else 
				if(gameInProgress) then
					-- Hide inactive slots for games in progress
					playerEntry.Root:SetHide(true);
				else
					-- Inactive slots are visible in the pregame.
					playerEntry.Root:SetHide(false);
					playerEntry.PlayerPullDown:SetHide(true);
					playerEntry.TeamPullDown:SetHide(true);
					playerEntry.ReadyImage:SetHide(true);
					playerEntry.HandicapPullDown:SetHide(true);
					playerEntry.KickButton:SetHide(true);
				end
			end
		end

		--[[ Prototype Mod Status Progress Bars
		-- Hide the player's mod progress if they are mod ready.
		-- This is how the mod progress is hidden once mod downloads are completed.
		if(pPlayerConfig:GetModReady()) then
			playerEntry.PlayerModProgressStack:SetHide(true);
		end
		--]]

		PopulateSlotTypePulldown( playerEntry.AlternateSlotTypePulldown, playerID, g_slotTypeData );
		PopulateSlotTypePulldown(playerEntry.SlotTypePulldown, playerID, g_slotTypeData);
		UpdatePlayerEntry_SlotTypeDisabled(playerID);

		if(isActiveSlot) then
			PlayerConfigurationValuesToUI(playerID); -- Update player configuration pulldown values.
		end
		
		-- TeamPullDown is not controlled by PlayerConfigurationValuesToUI and is set manually.
		local noTeams = GameConfiguration.GetValue("NO_TEAMS");
		playerEntry.TeamPullDown:SetDisabled(not bCanChangePlayerValues or noTeams);
		local teamID:number = pPlayerConfig:GetTeam();
		-- If the game is in progress and this player is on a team by themselves, display it as if they are on no team.
		-- We do this to be consistent with the ingame UI.
		if(gameInProgress and GameConfiguration.GetTeamPlayerCount(teamID) <= 1) then
			teamID = TeamTypes.NO_TEAM;
		end
		if teamID >= 0 then
			-- Adjust the texture offset based on the selected team
			local teamIconName:string = TEAM_ICON_PREFIX .. tostring(teamID);
			playerEntry.ButtonSelectedTeam:SetSizeVal(TEAM_ICON_SIZE, TEAM_ICON_SIZE);
			playerEntry.ButtonSelectedTeam:SetIcon(teamIconName, TEAM_ICON_SIZE);
			playerEntry.ButtonSelectedTeam:SetColor(GetTeamColor(teamID));
			playerEntry.ButtonSelectedTeam:SetHide(false);
			playerEntry.ButtonNoTeam:SetHide(true);
		else
			playerEntry.ButtonSelectedTeam:SetHide(true);
			playerEntry.ButtonNoTeam:SetHide(false);
		end

		-- NOTE: order matters. you MUST call this after all other setup and before resize as hotseat will hide/show manipulate elements specific to that mode.
		if(isHotSeat) then
			UpdatePlayerEntry_Hotseat(playerID);		
		end

		-- Slot name toggles based on slotstatus.
		-- Update AFTER hotseat checks as hot seat checks may upate nickname.
		playerEntry.PlayerName:LocalizeAndSetText(pPlayerConfig:GetSlotName()); 
		playerEntry.AlternateName:LocalizeAndSetText(pPlayerConfig:GetSlotName()); 

		-- Update online pip status for human slots.
		if(pPlayerConfig:IsHuman()) then
			local iconStr = onlineIconStr;
			if(not Network.IsPlayerConnected(playerID)) then
				iconStr = offlineIconStr;
			end
			playerEntry.ConnectionStatus:SetText(iconStr);
		end
		
	else
		print("PlayerEntry not found for playerID(" .. tostring(playerID) .. ").");
	end
end

function UpdatePlayerEntry_Hotseat(playerID)
	if(GameConfiguration.IsHotseat()) then
		local playerEntry = g_PlayerEntries[playerID];
		if(playerEntry ~= nil) then
			local localPlayerID = Network.GetLocalPlayerID();
			local pLocalPlayerConfig = PlayerConfigurations[localPlayerID];
			local pPlayerConfig = PlayerConfigurations[playerID];
			local slotStatus = pPlayerConfig:GetSlotStatus();

			g_hotseatNumHumanPlayers = 0;
			g_hotseatNumAIPlayers = 0;
			local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
			for i, iPlayer in ipairs(player_ids) do	
				local curPlayerConfig = PlayerConfigurations[iPlayer];
				local curSlotStatus = curPlayerConfig:GetSlotStatus();
				
				print("UpdatePlayerEntry_Hotseat: playerID=" .. iPlayer .. ", SlotStatus=" .. curSlotStatus);	
				if(curSlotStatus == SlotStatus.SS_TAKEN) then 
					g_hotseatNumHumanPlayers = g_hotseatNumHumanPlayers + 1;
				elseif(curSlotStatus == SlotStatus.SS_COMPUTER) then
					g_hotseatNumAIPlayers = g_hotseatNumAIPlayers + 1;
				end
			end
			print("UpdatePlayerEntry_Hotseat: g_hotseatNumHumanPlayers=" .. g_hotseatNumHumanPlayers .. ", g_hotseatNumAIPlayers=" .. g_hotseatNumAIPlayers);	

			if(slotStatus == SlotStatus.SS_TAKEN) then
				local nickName = pPlayerConfig:GetNickName();
				if(nickName == nil or #nickName == 0) then
					pPlayerConfig:SetHotseatName(DefaultHotseatPlayerName .. " " .. g_hotseatNumHumanPlayers);
				end
			end

			if(not g_isBuildingPlayerList and GameConfiguration.IsHotseat() and (slotStatus == SlotStatus.SS_TAKEN or slotStatus == SlotStatus.SS_COMPUTER)) then
				UpdateAllDefaultPlayerNames();
			end

			playerEntry.KickButton:SetHide(true);
			--[[ Prototype Mod Status Progress Bars
			playerEntry.PlayerModProgressStack:SetHide(true);
			--]]

			playerEntry.HotseatEditButton:RegisterCallback(Mouse.eLClick, function()
				UIManager:PushModal(Controls.EditHotseatPlayer, true);
				LuaEvents.StagingRoom_SetPlayerID(playerID);
			end);
		end
	end
end

function UpdateAllDefaultPlayerNames()
	local humanDefaultPlayerNameConfigs = {};
	local humanDefaultPlayerNameEntries = {};
	local numHumanPlayers = 0;
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do
		local curPlayerConfig = PlayerConfigurations[iPlayer];
		local curPlayerEntry = g_PlayerEntries[iPlayer];
		if(curPlayerConfig:GetSlotStatus() == SlotStatus.SS_TAKEN) then
			local strRegEx = "^" .. DefaultHotseatPlayerName .. " %d+$"
			print(strRegEx .. " " .. curPlayerConfig:GetNickName());
			local isDefaultPlayerName = string.match(curPlayerConfig:GetNickName(), strRegEx);
			if(isDefaultPlayerName ~= nil) then
				humanDefaultPlayerNameConfigs[#humanDefaultPlayerNameConfigs+1] = curPlayerConfig;
				humanDefaultPlayerNameEntries[#humanDefaultPlayerNameEntries+1] = curPlayerEntry;
			end
		end
	end

	for i, v in ipairs(humanDefaultPlayerNameConfigs) do
		local playerConfig = humanDefaultPlayerNameConfigs[i];
		local playerEntry = humanDefaultPlayerNameEntries[i];
		playerConfig:SetHotseatName(DefaultHotseatPlayerName .. " " .. i);
		playerEntry.PlayerName:LocalizeAndSetText(playerConfig:GetNickName()); 
		playerEntry.AlternateName:LocalizeAndSetText(playerConfig:GetNickName());
	end

end

-------------------------------------------------
-- SortPlayerListStack
-------------------------------------------------
function SortPlayerListStack(a, b)
	-- a and b are the Root controls of the PlayerListEntry we are sorting.
	local playerIDA = g_PlayerRootToPlayerID[tostring(a)];
	local playerIDB = g_PlayerRootToPlayerID[tostring(b)];
	if(playerIDA ~= nil and playerIDB ~= nil) then
		local playerConfigA = PlayerConfigurations[playerIDA];
		local playerConfigB = PlayerConfigurations[playerIDB];

		-- push closed slots to the bottom
		if(playerConfigA:GetSlotStatus() == SlotStatus.SS_CLOSED) then
			return false;
		elseif(playerConfigB:GetSlotStatus() == SlotStatus.SS_CLOSED) then
			return true;
		end

		-- Finally, sort by playerID value.
		return playerIDA < playerIDB;
	elseif (playerIDA ~= nil and playerIDB == nil) then
		-- nil entries should be at the end of the list.
		return true;
	elseif(playerIDA == nil and playerIDB ~= nil) then
		-- nil entries should be at the end of the list.
		return false;
	else
		return tostring(a) < tostring(b);				
	end	
end

function UpdateReadyButton_Hotseat()
	if(GameConfiguration.IsHotseat()) then
		if(g_hotseatNumHumanPlayers == 0) then
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_READY_BLOCKED_HOTSEAT_NO_HUMAN_PLAYERS")));
			Controls.ReadyButton:LocalizeAndSetToolTip("LOC_READY_BLOCKED_HOTSEAT_NO_HUMAN_PLAYERS_TT");
			Controls.ReadyButton:SetDisabled(true);
		elseif(g_hotseatNumHumanPlayers + g_hotseatNumAIPlayers < 2) then
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS")));
			Controls.ReadyButton:LocalizeAndSetToolTip("LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS_TT");
			Controls.ReadyButton:SetDisabled(true);
		elseif(not m_bTeamsValid) then
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_READY_BLOCKED_HOTSEAT_INVALID_TEAMS")));
			Controls.ReadyButton:LocalizeAndSetToolTip("LOC_READY_BLOCKED_HOTSEAT_INVALID_TEAMS_TT");
			Controls.ReadyButton:SetDisabled(true);
		elseif(g_badPlayerForMapSize) then
			Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_PLAYER_MAP_SIZE");
			Controls.ReadyButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_PLAYER_MAP_SIZE_TT", g_currentMaxPlayers);
			Controls.ReadyButton:SetDisabled(true);
		elseif(g_duplicateLeaders) then
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS")));
			Controls.ReadyButton:LocalizeAndSetToolTip("LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
			Controls.ReadyButton:SetDisabled(true);
		else
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_START_GAME")));
			Controls.ReadyButton:LocalizeAndSetToolTip("");
			Controls.ReadyButton:SetDisabled(false);
		end
	end
end

function UpdateReadyButton()
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];

	if(GameConfiguration.IsHotseat()) then
		UpdateReadyButton_Hotseat();
		return;
	end

	local localPlayerEntry = GetPlayerEntry(localPlayerID);
	local localPlayerButton = localPlayerEntry.ReadyImage;
	if(g_fCountdownTimer ~= -1) then
		-- Countdown is active, just show that.
		local intTime = math.floor(g_fCountdownTimer);
		Controls.StartLabel:SetText( Locale.ToUpper(Locale.Lookup("LOC_GAMESTART_COUNTDOWN_FORMAT")) );
		Controls.ReadyButton:LocalizeAndSetText(  intTime );
		Controls.ReadyButton:LocalizeAndSetToolTip( "" );
		Controls.ReadyCheck:LocalizeAndSetToolTip( "" );
		localPlayerButton:LocalizeAndSetToolTip( "" );
	elseif(not g_everyoneReady) then
		-- Local player hasn't readied up yet, just show "Ready"
		Controls.StartLabel:SetText( Locale.ToUpper(Locale.Lookup( "LOC_ARE_YOU_READY" )));
		Controls.ReadyButton:SetText("");
		Controls.ReadyButton:LocalizeAndSetToolTip( "" );
		Controls.ReadyCheck:LocalizeAndSetToolTip( "" );
		localPlayerButton:LocalizeAndSetToolTip( "" );
	-- Local player is ready, show why we're not in the countdown yet!
	elseif(not g_everyoneConnected) then
		-- Waiting for a player to finish connecting to the game.
		Controls.StartLabel:SetText( Locale.ToUpper(Locale.Lookup("LOC_READY_BLOCKED_PLAYERS_CONNECTING")));

		local waitingForJoinersTooltip : string = Locale.Lookup("LOC_READY_BLOCKED_PLAYERS_CONNECTING_TT");
		local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
		for i, iPlayer in ipairs(player_ids) do	
			local curPlayerConfig = PlayerConfigurations[iPlayer];
			local curSlotStatus = curPlayerConfig:GetSlotStatus();
			if(curSlotStatus == SlotStatus.SS_TAKEN and not Network.IsPlayerConnected(playerID)) then
				waitingForJoinersTooltip = waitingForJoinersTooltip .. "[NEWLINE]" .. "(" .. Locale.Lookup(curPlayerConfig:GetPlayerName()) .. ") ";
			end
		end
		Controls.ReadyButton:SetToolTipString( waitingForJoinersTooltip );
		Controls.ReadyCheck:SetToolTipString( waitingForJoinersTooltip );
		localPlayerButton:SetToolTipString( waitingForJoinersTooltip );
	elseif(g_notEnoughPlayers) then
		Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS");
		Controls.ReadyButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS_TT");
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS_TT");
		localPlayerButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS_TT");
	elseif(not m_bTeamsValid) then
		Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_TEAMS_INVALID");
		Controls.ReadyButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_TEAMS_INVALID_TT" );
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_TEAMS_INVALID_TT" );
		localPlayerButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_TEAMS_INVALID_TT" );
	elseif(g_badPlayerForMapSize) then
		Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_PLAYER_MAP_SIZE");
		Controls.ReadyButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_PLAYER_MAP_SIZE_TT", g_currentMaxPlayers);
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_PLAYER_MAP_SIZE_TT", g_currentMaxPlayers);
		localPlayerButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_PLAYER_MAP_SIZE_TT", g_currentMaxPlayers);
	elseif(not g_everyoneModReady) then
		-- A player doesn't have the mods required for this game.
		Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_PLAYERS_NOT_MOD_READY");

		local waitingForModReadyTooltip : string = Locale.Lookup("LOC_READY_BLOCKED_PLAYERS_NOT_MOD_READY");
		local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
		for i, iPlayer in ipairs(player_ids) do	
			local curPlayerConfig = PlayerConfigurations[iPlayer];
			local curSlotStatus = curPlayerConfig:GetSlotStatus();
			if(curSlotStatus == SlotStatus.SS_TAKEN and not curPlayerConfig:GetModReady()) then
				waitingForModReadyTooltip = waitingForModReadyTooltip .. "[NEWLINE]" .. "(" .. Locale.Lookup(curPlayerConfig:GetPlayerName()) .. ") ";
			end
		end
		Controls.ReadyButton:SetToolTipString( waitingForModReadyTooltip );
		Controls.ReadyCheck:SetToolTipString( waitingForModReadyTooltip );
		localPlayerButton:SetToolTipString( waitingForModReadyTooltip );
	elseif(g_duplicateLeaders) then
		Controls.StartLabel:LocalizeAndSetText("LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
		Controls.ReadyButton:LocalizeAndSetToolTip("LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
		localPlayerButton:LocalizeAndSetToolTip( "LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
	elseif(not g_humanRequiredFilled) then
		Controls.StartLabel:LocalizeAndSetText("LOC_SETUP_ERROR_HUMANS_REQUIRED");
		Controls.ReadyButton:LocalizeAndSetToolTip("LOC_SETUP_ERROR_HUMANS_REQUIRED");
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_SETUP_ERROR_HUMANS_REQUIRED");
		localPlayerButton:LocalizeAndSetToolTip( "LOC_SETUP_ERROR_HUMANS_REQUIRED");
	end

	local errorReason;
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		-- Check for selection error (ownership rules, duplicate leaders, etc)
		local err = GetPlayerParameterError(iPlayer)
		if(err) then
			errorReason = err.Reason or "LOC_SETUP_PLAYER_PARAMETER_ERROR"
		end
	end
	-- Block ready up when there is a civ ownership issue.  
	-- We have to do this because ownership is not communicated to the host.
	if(errorReason) then
		Controls.StartLabel:SetText("[COLOR_RED]" .. Locale.Lookup(errorReason) .. "[ENDCOLOR]");
		Controls.ReadyButton:SetDisabled(true)
		Controls.ReadyCheck:SetDisabled(true);
		localPlayerButton:SetDisabled(true);
	else
		Controls.ReadyButton:SetDisabled(false);
		Controls.ReadyCheck:SetDisabled(false);
		localPlayerButton:SetDisabled(false);
	end
end

-------------------------------------------------
-- Start Game Launch Countdown
-------------------------------------------------
function StartCountdown()
	--print("StartCountdown");
	local gameState = GameConfiguration.GetGameState();
	if(GameConfiguration.IsPlayByCloud() and gameState == GameStateTypes.GAMESTATE_LAUNCHED) then
		-- Joining a PlayByCloud game already in progress has a much faster countdown to be less annoying.
		g_fCountdownTimer = 3;
		g_fCountdownTickSoundTime = g_fCountdownTimer; -- start countdown tick now.
	else
		g_fCountdownTimer = 10;
		g_fCountdownTickSoundTime = g_fCountdownTimer - 3; -- start countdown ticks in 3 seconds.
	end
	
	g_fCountdownInitialTime = g_fCountdownTimer;
	g_fCountdownReadyButtonTime = g_fCountdownTimer;
	ContextPtr:SetUpdate( OnUpdate );

	-- Update m_iFirstClosedSlot's player slot so it will hide the Add Player button.
	if(m_iFirstClosedSlot ~= -1) then
		UpdatePlayerEntry(m_iFirstClosedSlot);
	end

	ShowHideReadyButtons();
end

-------------------------------------------------
-- Stop Game Launch Countdown
-------------------------------------------------
function StopCountdown()
	--print("StopCountdown");
	Controls.TurnTimerMeter:SetPercent(0);
	g_fCountdownTimer = -1;
	ContextPtr:ClearUpdate();
	UpdateReadyButton();

	-- Update m_iFirstClosedSlot's player slot so it will show the Add Player button.
	if(m_iFirstClosedSlot ~= -1) then
		UpdatePlayerEntry(m_iFirstClosedSlot);
	end

	ShowHideReadyButtons();
end

-------------------------------------------------
-- BuildPlayerList
-------------------------------------------------
function BuildPlayerList()
	g_isBuildingPlayerList = true;
	-- Clear previous data.
	g_PlayerEntries = {};
	g_PlayerRootToPlayerID = {};
	m_playersIM:ResetInstances();
	m_iFirstClosedSlot = -1;
	local numPlayers:number = 0;

	-- Create a player slot for every current participant and available player slot for the players.
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		local pPlayerConfig = PlayerConfigurations[iPlayer];
		if(pPlayerConfig ~= nil
			and (iPlayer < g_currentMaxPlayers
				or (pPlayerConfig:IsParticipant() 
					and pPlayerConfig:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV)) ) then
			if(GameConfiguration.IsHotseat()) then
				local nickName = pPlayerConfig:GetNickName();
				if(nickName == nil or #nickName == 0) then
					pPlayerConfig:SetHotseatName(DefaultHotseatPlayerName .. " " .. iPlayer + 1);
				end
			end
			-- Trigger a fake OnTeamChange on every active player slot to automagically create required PlayerEntry/TeamEntry
			OnTeamChange(iPlayer, true);
			numPlayers = numPlayers + 1;
		end	
	end

	UpdateTeamList(true);

	SetupGridLines(numPlayers - 1);

	g_isBuildingPlayerList = false;
end

-- Adjust vertical grid lines
function RealizeGridSize()
	Controls.PlayerListStack:CalculateSize();
	Controls.PlayerListStack:ReprocessAnchoring();
	Controls.PlayersScrollPanel:CalculateInternalSize();

	local gridLineHeight:number = math.max(Controls.PlayerListStack:GetSizeY(), Controls.PlayersScrollPanel:GetSizeY());
	for i = 1, NUM_COLUMNS do
		Controls["GridLine_" .. i]:SetEndY(gridLineHeight);
	end
	
	Controls.GridContainer:SetSizeY(gridLineHeight);
end

-------------------------------------------------
-- ResetChat
-------------------------------------------------
function ResetChat()
	m_ChatInstances = {}
	Controls.ChatStack:DestroyAllChildren();
	ChatPrintHelpHint(Controls.ChatStack, m_ChatInstances, Controls.ChatScroll);
end

-------------------------------------------------
-- Context OnUpdate
-------------------------------------------------
function OnUpdate( fDTime )
	-- OnUpdate only runs when the game start countdown is ticking down.
	g_fCountdownTimer = g_fCountdownTimer - fDTime;
	Controls.TurnTimerMeter:SetPercent(g_fCountdownTimer / g_fCountdownInitialTime);
	if( not Network.IsEveryoneConnected() ) then
		-- not all players are connected anymore.  This is probably due to a player join in progress.
		StopCountdown();
	elseif( g_fCountdownTimer <= 0 ) then
		-- Timer elapsed, launch the game if we're the host.
		if(Network.IsHost()) then
			Network.LaunchGame();
		end
		StopCountdown();
	else
		-- Update countdown tick sound.
		if( g_fCountdownTimer < g_fCountdownTickSoundTime) then
			g_fCountdownTickSoundTime = g_fCountdownTickSoundTime-1; -- set countdown tick for next second.
			UI.PlaySound("Play_MP_Game_Launch_Timer_Beep");
		end

		-- Update countdown ready button.
		if( g_fCountdownTimer < g_fCountdownReadyButtonTime) then
			g_fCountdownReadyButtonTime = g_fCountdownReadyButtonTime-1; -- set countdown tick for next second.
			UpdateReadyButton();
		end
	end
end

-------------------------------------------------
-------------------------------------------------
function OnShow()
	
	-- Fetch g_currentMaxPlayers because it might be stale due to loading a save.
	g_currentMaxPlayers = math.min(MapConfiguration.GetMaxMajorPlayers(), MAX_EVER_PLAYERS);

	InitializeReadyUI();
	ShowHideInviteButton();	
	ShowHideEndGameButton();
	RealizeGameSetup();
	BuildPlayerList();
	PopulateTargetPull(Controls.ChatPull, Controls.ChatEntry, m_playerTargetEntries, m_playerTarget, false, OnChatPulldownChanged);
	ShowHideChatPanel();

	if (Steam ~= nil) then
		Steam.SetRichPresence("civPresence", Network.IsHost() and "LOC_PRESENCE_HOSTING_GAME" or "LOC_PRESENCE_IN_STAGING_ROOM");
	end

	UpdateFriendsList();
	RealizeInfoTabs();
	RealizeGridSize();

	-- Forgive me universe!
	Controls.ReadyButton:SetOffsetY(isHotSeat and -16 or -18);
end
ContextPtr:SetShowHandler(OnShow);

function OnChatPulldownChanged(newTargetType :number, newTargetID :number)
	ChangeChatIcon(Controls.ChatIcon, newTargetType);
	local textControl:table = Controls.ChatPull:GetButton():GetTextControl();
	local text:string = textControl:GetText();
	Controls.ChatPull:SetToolTipString(text);
end

function ChangeChatIcon(iconControl:table, targetType:number)
	if(targetType == ChatTargetTypes.CHATTARGET_ALL) then
		iconControl:SetText("[ICON_Global]");
	elseif(targetType == ChatTargetTypes.CHATTARGET_TEAM) then
		iconControl:SetText("[ICON_Team]");
	else
		iconControl:SetText("[ICON_Whisper]");
	end
end

-------------------------------------------------
-------------------------------------------------
function OnHide()
	
end
ContextPtr:SetHideHandler(OnHide);

-------------------------------------------------
-------------------------------------------------
function InitializeReadyUI()
	-- Set initial ready check state.  This might be dirty from a previous staging room.
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];
	Controls.ReadyCheck:SetSelected(localPlayerConfig:GetReady());

	-- Hotseat doesn't use the readying mechanic (countdown; ready background elements; ready column). 
	local isHotSeat:boolean = GameConfiguration.IsHotseat();
	Controls.LargeCompassDeco:SetHide(isHotSeat);
	Controls.TurnTimerBG:SetHide(isHotSeat);
	Controls.TurnTimerMeter:SetHide(isHotSeat);
	Controls.TurnTimerHotseatBG:SetHide(not isHotSeat);
	Controls.ReadyColumnLabel:SetHide(isHotSeat);

	ShowHideReadyButtons();
end

-------------------------------------------------
-------------------------------------------------
function ShowHideInviteButton()
	local steamGame :boolean = Network.GetTransportType() == TransportType.TRANSPORT_STEAM;
	Controls.InviteButton:SetHide( not steamGame );
end

-------------------------------------------------
-------------------------------------------------
function ShowHideEndGameButton()
	local showEndGame :boolean = GameConfiguration.IsPlayByCloud();
	Controls.EndGameButton:SetHide( not showEndGame);
end

-------------------------------------------------
-------------------------------------------------
function ShowHideReadyButtons()
	-- show ready button when in the countdown or hotseat.
	local showReadyCheck = not GameConfiguration.IsHotseat() and (g_fCountdownTimer == -1);
	Controls.ReadyCheckContainer:SetHide(not showReadyCheck);
	Controls.ReadyButtonContainer:SetHide(showReadyCheck);
end

-------------------------------------------------
-------------------------------------------------
function ShowHideChatPanel()
	if(GameConfiguration.IsHotseat()) then
		Controls.ChatContainer:SetHide(true);
	else
		Controls.ChatContainer:SetHide(false);
	end
	--Controls.TwinPanelStack:CalculateSize();
end

-- ===========================================================================
function OnGameSetupTabClicked()
	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================

function RealizeShellTabs()
	m_shellTabIM:ResetInstances();

	local gameSetup:table = m_shellTabIM:GetInstance();
	gameSetup.Button:SetText(LOC_GAME_SETUP);
	gameSetup.SelectedButton:SetText(LOC_GAME_SETUP);
	gameSetup.Selected:SetHide(true);
	gameSetup.Button:RegisterCallback( Mouse.eLClick, OnGameSetupTabClicked );

	AutoSizeGridButton(gameSetup.Button,250,32,10,"H");
	AutoSizeGridButton(gameSetup.SelectedButton,250,32,20,"H");
	gameSetup.TopControl:SetSizeX(gameSetup.Button:GetSizeX());

	local stagingRoom:table = m_shellTabIM:GetInstance();
	stagingRoom.Button:SetText(LOC_STAGING_ROOM);
	stagingRoom.SelectedButton:SetText(LOC_STAGING_ROOM);
	stagingRoom.Button:SetDisabled(not Network.IsInSession());
	stagingRoom.Selected:SetHide(false);

	AutoSizeGridButton(stagingRoom.Button,250,32,20,"H");
	AutoSizeGridButton(stagingRoom.SelectedButton,250,32,20,"H");
	stagingRoom.TopControl:SetSizeX(stagingRoom.Button:GetSizeX());
	
	Controls.ShellTabs:CalculateSize();
	Controls.ShellTabs:ReprocessAnchoring();
end

-- ===========================================================================
function OnGameSummaryTabClicked()
	-- TODO
end

function OnFriendsTabClicked()
	-- TODO
end

-- ===========================================================================
function BuildGameSetupParameter(o, parameter)

	local parent = GetControlStack(parameter.GroupId);
	local control;
	
	-- If there is no parent, don't visualize the control.  This is most likely a player parameter.
	if(parent == nil or not parameter.Visible) then
		return;
	end;

	
	local c = m_gameSetupParameterIM:GetInstance();		
	c.Root:ChangeParent(parent);
			
	c.Label:SetText(parameter.Name);
	c.Value:SetText(parameter.DefaultValue);
	c.Root:SetToolTipString(parameter.Description);

	control = {
		Control = c,
		UpdateValue = function(value)
			local type:string = type(value);
			if type == "table" then
				c.Value:SetText(value.Name);
			elseif type == "boolean" then
				c.Value:SetText(Locale.Lookup(value and "LOC_MULTIPLAYER_TRUE" or "LOC_MULTIPLAYER_FALSE"));
			else
				c.Value:SetText(tostring(value));
			end
		end,
		SetVisible = function(visible)
			c.Root:SetHide(not visible);
		end,
		Destroy = function()
			g_StringParameterManager:ReleaseInstance(c);
		end,
	};

	o.Controls[parameter.ParameterId] = control;
end

function RealizeGameSetup()
	BuildGameState();

	m_gameSetupParameterIM:ResetInstances();
	BuildGameSetup(BuildGameSetupParameter);

	BuildAdditionalContent();
end

function BuildGameState()
	-- Indicate that this game is for loading a save or already in progress.
	local gameState = GameConfiguration.GetGameState();
	if(gameState ~= GameStateTypes.GAMESTATE_PREGAME) then
		local gameModeStr : string;

		if(gameState == GameStateTypes.GAMESTATE_LOAD_PREGAME) then
			-- in the pregame for loading a save
			gameModeStr = loadingSaveGameStr;
		else
			-- standard game in progress
			gameModeStr = gameInProgressGameStr;
		end
		Controls.GameStateText:SetHide(false);
		Controls.GameStateText:SetText(gameModeStr);
	else
		Controls.GameStateText:SetHide(true);
	end

	-- Display join code for PlayByCloud games.
	if(GameConfiguration.IsPlayByCloud()) then
		local joinCode :string = Network.GetJoinCode();
		if(joinCode ~= nil and joinCode ~= "") then
			Controls.JoinCodeRoot:SetHide(false);
			Controls.JoinCodeText:SetText(joinCode);
		else
			Controls.JoinCodeRoot:SetHide(true);
		end
	else
		Controls.JoinCodeRoot:SetHide(true);
	end

	Controls.AdditionalContentStack:CalculateSize();
	Controls.AdditionalContentStack:ReprocessAnchoring();

	Controls.ParametersScrollPanel:CalculateInternalSize();
end

function BuildAdditionalContent()
	m_modsIM:ResetInstances();

	local enabledMods = GameConfiguration.GetEnabledMods();
	for _, curMod in ipairs(enabledMods) do
		local modControl = m_modsIM:GetInstance();
		local modTitleStr : string = curMod.Title;

		-- Color unofficial mods to call them out.
		if(not curMod.Official) then
			modTitleStr = ColorString_ModGreen .. modTitleStr .. "[ENDCOLOR]";
		end
		modControl.ModTitle:SetText(modTitleStr);
	end

	Controls.AdditionalContentStack:CalculateSize();
	Controls.AdditionalContentStack:ReprocessAnchoring();

	Controls.ParametersScrollPanel:CalculateInternalSize();
end

-- ===========================================================================
function RealizeInfoTabs()
	m_infoTabsIM:ResetInstances();
	local friends:table;
	local gameSummary:table

	gameSummary = m_infoTabsIM:GetInstance();
	gameSummary.Button:SetText(LOC_GAME_SUMMARY);
	gameSummary.SelectedButton:SetText(LOC_GAME_SUMMARY);
	gameSummary.Selected:SetHide(not g_viewingGameSummary);

	gameSummary.Button:RegisterCallback(Mouse.eLClick, function()
		g_viewingGameSummary = true;
		Controls.Friends:SetHide(true);
		friends.Selected:SetHide(true);
		gameSummary.Selected:SetHide(false);
		Controls.ParametersScrollPanel:SetHide(false);
	end);

	AutoSizeGridButton(gameSummary.Button,200,32,10,"H");
	AutoSizeGridButton(gameSummary.SelectedButton,200,32,20,"H");
	gameSummary.TopControl:SetSizeX(gameSummary.Button:GetSizeX());

	if not GameConfiguration.IsHotseat() then
		friends = m_infoTabsIM:GetInstance();
		friends.Button:SetText(LOC_FRIENDS);
		friends.SelectedButton:SetText(LOC_FRIENDS);
		friends.Selected:SetHide(g_viewingGameSummary);
		friends.Button:SetDisabled(not Network.IsInSession());
		friends.Button:RegisterCallback( Mouse.eLClick, function()
			g_viewingGameSummary = false;
			Controls.Friends:SetHide(false);
			friends.Selected:SetHide(false);
			gameSummary.Selected:SetHide(true);
			Controls.ParametersScrollPanel:SetHide(true);
		end );

		AutoSizeGridButton(friends.Button,200,32,20,"H");
		AutoSizeGridButton(friends.SelectedButton,200,32,20,"H");
		friends.TopControl:SetSizeX(friends.Button:GetSizeX());
	end

	Controls.InfoTabs:CalculateSize();
	Controls.InfoTabs:ReprocessAnchoring();
end

-------------------------------------------------
function UpdateFriendsList()

	if ContextPtr:IsHidden() or GameConfiguration.IsHotseat() then
		Controls.InfoContainer:SetHide(true);
		return;
	end

	m_friendsIM:ResetInstances();
	Controls.InfoContainer:SetHide(false);
	local friends:table = GetSteamFriendsList();
	local bCanInvite:boolean = not GameConfiguration.IsLANMultiplayer() and not GameConfiguration.IsHotseat();

	-- DEBUG
	--for i = 1, 19 do
	-- /DEBUG
	for _, friend in pairs(friends) do
		local instance:table = m_friendsIM:GetInstance();
		if not bCanInvite or IsFriendInGame(friend) then
			PopulateFriendsInstance(instance, friend, g_steamFriendActionsNoInvite);
		else
			local friendPlayingCiv:boolean = friend.PlayingCiv; -- cache value to ensure it's available in callback function
			PopulateFriendsInstance(instance, friend, g_steamFriendActionsOnline, 
				function(friendID, actionType) 
					if actionType == "invite" then
						local statusText:string = friendPlayingCiv and "LOC_PRESENCE_INVITED_ONLINE" or "LOC_PRESENCE_INVITED_OFFLINE";
						instance.PlayerStatus:LocalizeAndSetText(statusText);
					end
				end
			);
		end
	end
	-- DEBUG
	--end
	-- /DEBUG

	Controls.FriendsStack:CalculateSize();
	Controls.FriendsStack:ReprocessAnchoring();
	Controls.FriendsScrollPanel:CalculateSize();
	Controls.FriendsScrollPanel:ReprocessAnchoring();
	Controls.FriendsScrollPanel:GetScrollBar():SetAndCall(0);

	if Controls.FriendsScrollPanel:GetScrollBar():IsHidden() then
		Controls.FriendsScrollPanel:SetOffsetX(8);
	else
		Controls.FriendsScrollPanel:SetOffsetX(3);
	end

	if table.count(friends) == 0 then
		Controls.InviteButton:SetAnchor("C,C");
		Controls.InviteButton:SetOffsetY(0);
	else
		Controls.InviteButton:SetAnchor("C,B");
		Controls.InviteButton:SetOffsetY(27);
	end
	Controls.InviteButton:ReprocessAnchoring();
	Controls.InviteButton:SetHide(false);
end

function IsFriendInGame(friend:table)
	local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		local curPlayerConfig = PlayerConfigurations[iPlayer];
		local steamID = curPlayerConfig:GetNetworkIdentifer();
		if( steamID ~= nil and steamID == friend.ID and Network.IsPlayerConnected(iPlayer) ) then
			return true;
		end
	end
	return fasle;
end

-------------------------------------------------
function SetupGridLines(numPlayers:number)
	g_GridLinesIM:ResetInstances();
	RealizeGridSize();
	local nextY:number = GRID_LINE_HEIGHT;
	local gridSize:number = Controls.GridContainer:GetSizeY();
	local numLines:number = math.max(numPlayers, gridSize / GRID_LINE_HEIGHT);
	for i:number = 1, numLines do
		g_GridLinesIM:GetInstance().Control:SetOffsetY(nextY);
		nextY = nextY + GRID_LINE_HEIGHT;
	end
end

-------------------------------------------------
-------------------------------------------------
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues( "StagingRoom" );
	end
end

function OnShutdown()
	-- Cache values for hotloading...
	LuaEvents.GameDebug_AddValue("StagingRoom", "isHidden", ContextPtr:IsHidden());
end

function OnGameDebugReturn( context:string, contextTable:table )
	if context == "StagingRoom" and contextTable["isHidden"] == false then
		if ContextPtr:IsHidden() then
			ContextPtr:SetHide(false);
		else
			OnShow();
		end
	end	
end

-- ===========================================================================
--	LUA Event
--	Show the screen
-- ===========================================================================
function OnRaise(resetChat:boolean)
	-- Make sure HostGame screen is on the stack
	LuaEvents.StagingRoom_EnsureHostGame();
	UIManager:QueuePopup( ContextPtr, PopupPriority.Current );
end

function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	local hideLogo = true;
	if(screenY >= Controls.MainWindow:GetSizeY() + Controls.LogoContainer:GetSizeY()+ Controls.LogoContainer:GetOffsetY()) then
		hideLogo = false;
	end
	Controls.LogoContainer:SetHide(hideLogo);
	Controls.MainGrid:ReprocessAnchoring();
	Controls.ReadyContainer:ReprocessAnchoring();
end

function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
	Resize();
  end
end

function OnExitGame()
	LuaEvents.Multiplayer_ExitShell();
end

function OnEndGame_Start()
	Network.CloudKillGame();

	-- Show killing game popup
	m_kPopupDialog:Close(); -- clear out the popup incase it is already open.
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MULTIPLAYER_ENDING_GAME_PROMPT"));
	m_kPopupDialog:Open();

	-- Next step is in OnCloudGameKilled.
end

function OnExitGameAskAreYouSure()
	m_kPopupDialog:Close();	-- clear out the popup incase it is already open.
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_QUIT_WARNING"));
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), nil );
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnExitGame, nil, nil, "PopupButtonInstanceRed" );
	m_kPopupDialog:Open();
end

function OnEndGameAskAreYouSure()
	m_kPopupDialog:Close(); -- clear out the popup incase it is already open.
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_END_GAME_WARNING"));
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), nil );
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnEndGame_Start, nil, nil, "PopupButtonInstanceRed" );
	m_kPopupDialog:Open();
end

-- ===========================================================================
--	Initialize screen
-- ===========================================================================
function Initialize()
	SetCurrentMaxPlayers(MapConfiguration.GetMaxMajorPlayers());
	SetCurrentMinPlayers(MapConfiguration.GetMinMajorPlayers());

	Events.SystemUpdateUI.Add(OnUpdateUI);

	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	ContextPtr:SetInputHandler( OnInputHandler );

	Controls.BackButton:RegisterCallback( Mouse.eLClick, OnExitGameAskAreYouSure );
	Controls.BackButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ChatEntry:RegisterCommitCallback( SendChat );
	Controls.InviteButton:RegisterCallback( Mouse.eLClick, OnInviteButton );
	Controls.InviteButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.EndGameButton:RegisterCallback( Mouse.eLClick, OnEndGameAskAreYouSure );
	Controls.EndGameButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);	
	Controls.ReadyButton:RegisterCallback( Mouse.eLClick, OnReadyButton );
	Controls.ReadyButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ReadyCheck:RegisterCallback( Mouse.eLClick, OnReadyButton );
	Controls.ReadyCheck:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	

	Events.MapMaxMajorPlayersChanged.Add(OnMapMaxMajorPlayersChanged); 
	Events.MapMinMajorPlayersChanged.Add(OnMapMinMajorPlayersChanged);
	Events.MultiplayerPrePlayerDisconnected.Add( OnMultiplayerPrePlayerDisconnected );
	Events.GameConfigChanged.Add(OnGameConfigChanged);
	Events.PlayerInfoChanged.Add(OnPlayerInfoChanged);
	Events.ModStatusUpdated.Add(OnModStatusUpdated);
	Events.MultiplayerChat.Add( OnMultiplayerChat );
	Events.MultiplayerGameAbandoned.Add( OnAbandoned );
	Events.MultiplayerGameLaunchFailed.Add( OnMultiplayerGameLaunchFailed );
	Events.LeaveGameComplete.Add( OnLeaveGameComplete );
	Events.BeforeMultiplayerInviteProcessing.Add( OnBeforeMultiplayerInviteProcessing );
	Events.MultiplayerHostMigrated.Add( OnMultiplayerHostMigrated );
	Events.MultiplayerPlayerConnected.Add( OnMultplayerPlayerConnected );
	Events.MultiplayerPingTimesChanged.Add(OnMultiplayerPingTimesChanged);
	Events.SteamFriendsStatusUpdated.Add( UpdateFriendsList );
	Events.SteamFriendsPresenceUpdated.Add( UpdateFriendsList );
	Events.CloudGameKilled.Add(OnCloudGameKilled);

	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	LuaEvents.HostGame_ShowStagingRoom.Add( OnRaise );
	LuaEvents.JoiningRoom_ShowStagingRoom.Add( OnRaise );
	LuaEvents.EditHotseatPlayer_UpdatePlayer.Add(UpdatePlayerEntry);
	LuaEvents.Multiplayer_ExitShell.Add(HandleExitRequest);

	Controls.TitleLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_STAGING_ROOM")));
	ResizeButtonToText(Controls.BackButton);
	RealizeShellTabs();
	RealizeInfoTabs();
	SetupGridLines(0);

	-- Custom popup setup	
	m_kPopupDialog = PopupDialog:new( "InGameTopOptionsMenu" );
end
Initialize();
