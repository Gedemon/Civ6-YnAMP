/*
	YnAMP
	RuleSet 1
	by Gedemon (2016)
	
*/

-----------------------------------------------
-- Defines
-----------------------------------------------

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('YNAMP_RULESET', '1');

UPDATE GlobalParameters SET Value = '30' WHERE Name = 'START_DISTANCE_MAJOR_CIVILIZATION';
UPDATE GlobalParameters SET Value ='2' WHERE Name ='BARBARIAN_CAMP_MAX_PER_MAJOR_CIV';
UPDATE GlobalParameters SET Value ='7' WHERE Name ='BARBARIAN_CAMP_MINIMUM_DISTANCE_CITY';

-- Replace some capitals
UPDATE CivilizationLeaders SET CapitalName ='LOC_CITY_NAME_MECCA' WHERE LeaderType ='LEADER_SALADIN';
UPDATE CivilizationLeaders SET CapitalName ='LOC_CITY_NAME_BERLIN' WHERE LeaderType ='LEADER_BARBAROSSA';
UPDATE CivilizationLeaders SET CapitalName ='LOC_CITY_NAME_THEBES' WHERE LeaderType ='LEADER_CLEOPATRA';
UPDATE CivilizationLeaders SET CapitalName ='LOC_CITY_NAME_MOSCOW' WHERE LeaderType ='LEADER_PETER_GREAT';

-- tweak resource placement
INSERT OR REPLACE INTO Resource_ValidTerrains (ResourceType, TerrainType) VALUES ('RESOURCE_ALUMINUM', 'TERRAIN_GRASS_HILLS');
INSERT OR REPLACE INTO Resource_ValidTerrains (ResourceType, TerrainType) VALUES ('RESOURCE_ALUMINUM', 'TERRAIN_PLAINS_HILLS');
INSERT OR REPLACE INTO Resource_ValidTerrains (ResourceType, TerrainType) VALUES ('RESOURCE_ALUMINUM', 'TERRAIN_TUNDRA_HILLS');
INSERT OR REPLACE INTO Resource_ValidTerrains (ResourceType, TerrainType) VALUES ('RESOURCE_ALUMINUM', 'TERRAIN_SNOW_HILLS');

INSERT OR REPLACE INTO Resource_ValidTerrains (ResourceType, TerrainType) VALUES ('RESOURCE_WHALES', 'TERRAIN_OCEAN');
INSERT OR REPLACE INTO Resource_ValidTerrains (ResourceType, TerrainType) VALUES ('RESOURCE_FISH', 'TERRAIN_OCEAN');

INSERT OR REPLACE INTO Resource_ValidTerrains (ResourceType, TerrainType) VALUES ('RESOURCE_WHEAT', 'TERRAIN_GRASS');

INSERT OR REPLACE INTO Resource_ValidFeatures (ResourceType, FeatureType) VALUES ('RESOURCE_ALUMINUM', 'FEATURE_FOREST');
INSERT OR REPLACE INTO Resource_ValidFeatures (ResourceType, FeatureType) VALUES ('RESOURCE_ALUMINUM', 'FEATURE_JUNGLE');

INSERT OR REPLACE INTO Resource_ValidFeatures (ResourceType, FeatureType) VALUES ('RESOURCE_COAL', 'FEATURE_FOREST');
INSERT OR REPLACE INTO Resource_ValidFeatures (ResourceType, FeatureType) VALUES ('RESOURCE_COAL', 'FEATURE_JUNGLE');

INSERT OR REPLACE INTO Resource_ValidFeatures (ResourceType, FeatureType) VALUES ('RESOURCE_IRON', 'FEATURE_FOREST');
INSERT OR REPLACE INTO Resource_ValidFeatures (ResourceType, FeatureType) VALUES ('RESOURCE_IRON', 'FEATURE_JUNGLE');

