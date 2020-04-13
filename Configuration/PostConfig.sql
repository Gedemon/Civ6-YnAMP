/*
	YnAMP
	by Gedemon (2016-2019)
	
*/

-----------------------------------------------
-- Remove invalid XP/DLC entries in <Parameters>
-----------------------------------------------

-- the code below seems to work but the problem with it is that changing the ruleset on setup won't update the CS list...
/*
DELETE FROM Parameters WHERE ParameterId='DLC2' AND NOT EXISTS (SELECT Domain FROM Players WHERE Domain = 'VikingScenario_Players');

DELETE FROM Parameters WHERE ParameterId='XP1' AND NOT EXISTS 
	(SELECT LeaderType FROM Players WHERE LeaderType IN
		(
		'LEADER_POUNDMAKER',
		'LEADER_TAMAR',
		'LEADER_SEONDEOK',
		'LEADER_LAUTARO',
		'LEADER_GENGHIS_KHAN',
		'LEADER_WILHEMINA',
		'LEADER_ROBERT_THE_BRUCE',
		'LEADER_SHAKA',
		'LEADER_CHANDRAGUPTA'
		));

DELETE FROM Parameters WHERE ParameterId='XP2' AND NOT EXISTS 
	(SELECT LeaderType FROM Players WHERE LeaderType IN
		(
		'LEADER_LAURIER',
		'LEADER_PACHACUTI',
		'LEADER_MATTHIAS',
		'LEADER_MANSA_MUSA',
		'LEADER_KUPE',
		'LEADER_SULEIMAN',
		'LEADER_KRISTINA',
		'LEADER_ELEANOR'
		));
--*/

-- Update Parameters SortIndex

UPDATE Parameters SET SortIndex =10 WHERE ParameterId = 'TurnTimerType';
UPDATE Parameters SET SortIndex =15 WHERE ParameterId = 'TurnPhaseType';
UPDATE Parameters SET SortIndex =20 WHERE ParameterId = 'GameDifficulty';
UPDATE Parameters SET SortIndex =25 WHERE ParameterId = 'TurnTimerType';
UPDATE Parameters SET SortIndex =30 WHERE ParameterId = 'GameStartEra';
UPDATE Parameters SET SortIndex =35 WHERE ParameterId = 'GameSpeeds';
UPDATE Parameters SET SortIndex =40 WHERE ParameterId = 'Realism';

UPDATE Parameters SET SortIndex =270 WHERE ParameterId = 'Resources';

-- Legacy setting update
UPDATE ParameterDependencies SET ConfigurationValue = 'RANDOM',	Operator ='NotEquals' WHERE ConfigurationId = 'SelectCityStates' AND ConfigurationValue =1;

-- <Replace ParameterId="BanLeaders" Name="LOC_MAP_BAN_LEADERS_NAME" Description="LOC_MAP_BAN_LEADERS_DESCRIPTION"	Domain="bool" 	DefaultValue="0" 	ConfigurationGroup="Map" 	ConfigurationId="BanLeaders" 	GroupId="MapOptions" 	SortIndex="52"/>
INSERT OR REPLACE INTO Parameters (ParameterId, Name, Description, Domain, DefaultValue, ConfigurationGroup, ConfigurationId, GroupId, SortIndex)
	SELECT	Domain || '_' || LeaderType, LeaderName, CivilizationName, 'bool', 0, 'Map', LeaderType, 'MapOptions', 55
	FROM Players WHERE Domain='Players:StandardPlayers' OR Domain='Players:Expansion1_Players' OR Domain='Players:Expansion2_Players';

INSERT OR REPLACE INTO ParameterDependencies (ParameterId, ConfigurationGroup, ConfigurationId, Operator, ConfigurationValue)
	SELECT	Domain || '_' || LeaderType, 'Map', 'BanLeaders', 'Equals', '1'
	FROM Players WHERE Domain='Players:StandardPlayers' OR Domain='Players:Expansion1_Players' OR Domain='Players:Expansion2_Players';
	
INSERT OR REPLACE INTO ParameterDependencies (ParameterId, ConfigurationGroup, ConfigurationId, Operator, ConfigurationValue)
	SELECT	Domain || '_' || LeaderType, 'Game', 'RULESET', 'Equals', 'RULESET_STANDARD'
	FROM Players WHERE Domain='Players:StandardPlayers';
	
INSERT OR REPLACE INTO ParameterDependencies (ParameterId, ConfigurationGroup, ConfigurationId, Operator, ConfigurationValue)
	SELECT	Domain || '_' || LeaderType, 'Game', 'RULESET', 'Equals', 'RULESET_EXPANSION_1'
	FROM Players WHERE Domain='Players:Expansion1_Players';
	
INSERT OR REPLACE INTO ParameterDependencies (ParameterId, ConfigurationGroup, ConfigurationId, Operator, ConfigurationValue)
	SELECT	Domain || '_' || LeaderType, 'Game', 'RULESET', 'Equals', 'RULESET_EXPANSION_2'
	FROM Players WHERE Domain='Players:Expansion2_Players';
	