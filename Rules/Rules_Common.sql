/*
	YnAMP
	Common RuleSet
	by Gedemon (2016)
	
*/

UPDATE GlobalParameters SET Value ='2' WHERE Name ='BARBARIAN_CAMP_MAX_PER_MAJOR_CIV';
UPDATE GlobalParameters SET Value ='7' WHERE Name ='BARBARIAN_CAMP_MINIMUM_DISTANCE_CITY';

-- Replace some capitals
UPDATE CivilizationLeaders SET CapitalName ='LOC_CITY_NAME_MECCA' WHERE LeaderType ='LEADER_SALADIN';
UPDATE CivilizationLeaders SET CapitalName ='LOC_CITY_NAME_BERLIN' WHERE LeaderType ='LEADER_BARBAROSSA';
UPDATE CivilizationLeaders SET CapitalName ='LOC_CITY_NAME_THEBES' WHERE LeaderType ='LEADER_CLEOPATRA';
UPDATE CivilizationLeaders SET CapitalName ='LOC_CITY_NAME_MOSCOW' WHERE LeaderType ='LEADER_PETER_GREAT';

-- Cliffs of Dover
INSERT INTO Feature_YieldChanges (FeatureType, YieldType, YieldChange) VALUES ('FEATURE_CLIFFS_DOVER', 'YIELD_FOOD', '2');
UPDATE Feature_YieldChanges SET YieldChange='1' WHERE FeatureType ='FEATURE_CLIFFS_DOVER' AND YieldType='YIELD_CULTURE';
UPDATE Feature_YieldChanges SET YieldChange='1' WHERE FeatureType ='FEATURE_CLIFFS_DOVER' AND YieldType='YIELD_GOLD';
--UPDATE Features SET Settlement='1' WHERE FeatureType ='FEATURE_CLIFFS_DOVER'; -- that removes the feature !
INSERT INTO Improvement_ValidFeatures (FeatureType, ImprovementType) VALUES ('FEATURE_CLIFFS_DOVER', 'IMPROVEMENT_FARM');

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