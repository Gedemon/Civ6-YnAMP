/*
	YnAMP
	RuleSet 2
	by Gedemon (2016)
	
*/

-----------------------------------------------
-- Defines
-----------------------------------------------

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('YNAMP_RULESET', '2');

-- More moves on roads
UPDATE Routes SET MovementCost = 0.75 WHERE RouteType="ROUTE_ANCIENT_ROAD"; 
UPDATE Routes SET MovementCost = 0.50 WHERE RouteType="ROUTE_MEDIEVAL_ROAD"; 
UPDATE Routes SET MovementCost = 0.33 WHERE RouteType="ROUTE_INDUSTRIAL_ROAD"; 
UPDATE Routes SET MovementCost = 0.25 WHERE RouteType="ROUTE_MODERN_ROAD"; 

-- Double movement on Ocean
UPDATE Terrains SET MovementCost = 2 WHERE TerrainType="TERRAIN_COAST"; 
UPDATE GlobalParameters SET Value = Value * 2 WHERE Name ='MOVEMENT_WHILE_EMBARKED_BASE';
UPDATE Units SET BaseMoves = BaseMoves * 2 WHERE Domain = 'DOMAIN_SEA';

-- Cliffs of Dover
INSERT INTO Feature_YieldChanges (FeatureType, YieldType, YieldChange) VALUES ('FEATURE_CLIFFS_DOVER', 'YIELD_FOOD', '2');
UPDATE Feature_YieldChanges SET YieldChange='1' WHERE FeatureType ='FEATURE_CLIFFS_DOVER' AND YieldType='YIELD_CULTURE';
UPDATE Feature_YieldChanges SET YieldChange='1' WHERE FeatureType ='FEATURE_CLIFFS_DOVER' AND YieldType='YIELD_GOLD';


