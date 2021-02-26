/*
	YnAMP
	by Gedemon (2016-2020)
	
*/

-- Update Parameters SortIndex
UPDATE Parameters SET SortIndex =10 WHERE ParameterId = 'TurnTimerType';
UPDATE Parameters SET SortIndex =15 WHERE ParameterId = 'TurnPhaseType';
UPDATE Parameters SET SortIndex =20 WHERE ParameterId = 'GameDifficulty';
UPDATE Parameters SET SortIndex =25 WHERE ParameterId = 'TurnTimerType';
UPDATE Parameters SET SortIndex =30 WHERE ParameterId = 'GameStartEra';
UPDATE Parameters SET SortIndex =35 WHERE ParameterId = 'GameSpeeds';
UPDATE Parameters SET SortIndex =40 WHERE ParameterId = 'Realism';
UPDATE Parameters SET SortIndex =270 WHERE ParameterId = 'Resources';
--
UPDATE Parameters SET SupportsSinglePlayer =0 WHERE ParameterId = 'LeaderPool1';
UPDATE Parameters SET SupportsSinglePlayer =0 WHERE ParameterId = 'LeaderPool2';

-- Legacy update
UPDATE Players SET Domain='Players:StandardPlayers' WHERE Domain='StandardPlayers';

-- Remove some restriction on WorldBuilder Setup
DELETE FROM ParameterDependencies WHERE ParameterId = 'NoDupeCivilizations' AND ConfigurationId = 'WORLD_BUILDER';
DELETE FROM ParameterDependencies WHERE ParameterId = 'NoDupeLeaders' AND ConfigurationId = 'WORLD_BUILDER';
DELETE FROM ParameterDependencies WHERE ParameterId = 'NaturalWonders' AND ConfigurationId = 'WORLD_BUILDER';

-- Legacy setting update for CityState list on first selection
UPDATE ParameterDependencies SET ConfigurationValue = 'RANDOM',	Operator ='NotEquals' WHERE ConfigurationId = 'SelectCityStates' AND ConfigurationValue =1;
INSERT OR REPLACE INTO ParameterDependencies (ParameterId, ConfigurationGroup, ConfigurationId, Operator, ConfigurationValue)
	SELECT ParameterId, ConfigurationGroup, ConfigurationId, Operator, NULL
	FROM ParameterDependencies WHERE ConfigurationId='SelectCityStates' AND ConfigurationValue ='RANDOM';

-- Create Ban Leader list <Replace ParameterId="BanLeaders" Name="LOC_MAP_BAN_LEADERS_NAME" Description="LOC_MAP_BAN_LEADERS_DESCRIPTION"	Domain="bool" 	DefaultValue="0" 	ConfigurationGroup="Map" 	ConfigurationId="BanLeaders" 	GroupId="MapOptions" 	SortIndex="52"/>
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
	
-- Add query to filter unsupported DomainValues for MapScript 
INSERT OR REPLACE INTO QueryParameters (QueryId, 'Index', ConfigurationGroup, ConfigurationId)
	VALUES ('MapUnSupportedValues', 1, 'Map', 'MAP_SCRIPT');
	
-- Hack for scenario configuration :
-- Mark Scenarios requiring CityMap as unsupported for all maps that doesn't have the AutoCityNaming option
-- This requires the scenario to add a fake ParameterDependencies entry like 
-- <Replace ParameterId="YourScenarioID" ConfigurationGroup="Map" ConfigurationId="ScenarioType" Operator="Equals"	ConfigurationValue="RequireCityMap"/>
INSERT OR REPLACE INTO MapUnSupportedValues (Map, Domain, Value)
	SELECT DISTINCT	Maps.File, 'ScenarioType', ParameterDependencies.ParameterId
	FROM Maps JOIN Parameters JOIN ParameterDependencies ON Maps.File = Parameters.Key2 AND ParameterDependencies.ConfigurationValue='RequireCityMap'
		WHERE NOT EXISTS (SELECT * FROM Parameters  WHERE Parameters.Key2 = Maps.File AND Parameters.ConfigurationId = 'AutoCityNaming');

-- Use same method for the generic CityPlacement option
INSERT OR REPLACE INTO MapUnSupportedValues (Map, Domain, Value)
	SELECT DISTINCT	Maps.File, 'CityPlacement', 'PLACEMENT_CITY_MAP'
	FROM Maps JOIN Parameters ON Maps.File = Parameters.Key2
		WHERE NOT EXISTS (SELECT * FROM Parameters  WHERE Parameters.Key2 = Maps.File AND Parameters.ConfigurationId = 'AutoCityNaming');
		
INSERT OR REPLACE INTO MapUnSupportedValues (Map, Domain, Value)
	SELECT DISTINCT	Maps.File, 'CityPlacement', 'PLACEMENT_CITY_MAP_ONLY'
	FROM Maps JOIN Parameters ON Maps.File = Parameters.Key2
		WHERE NOT EXISTS (SELECT * FROM Parameters  WHERE Parameters.Key2 = Maps.File AND Parameters.ConfigurationId = 'AutoCityNaming');

