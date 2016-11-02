/*
	YnAMP
	RuleSet 2
	by Gedemon (2016)
	
*/

-----------------------------------------------
-- Defines
-----------------------------------------------

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('YNAMP_RULESET', '2');

UPDATE GlobalParameters SET Value = '2'	WHERE Name = 'CITY_MIN_RANGE';

-- More moves on roads
UPDATE Routes SET MovementCost = 0.75 WHERE RouteType="ROUTE_ANCIENT_ROAD"; 
UPDATE Routes SET MovementCost = 0.50 WHERE RouteType="ROUTE_MEDIEVAL_ROAD"; 
UPDATE Routes SET MovementCost = 0.33 WHERE RouteType="ROUTE_INDUSTRIAL_ROAD"; 
UPDATE Routes SET MovementCost = 0.25 WHERE RouteType="ROUTE_MODERN_ROAD"; 

-- Double movement on Ocean
UPDATE Terrains SET MovementCost = 2 WHERE TerrainType="TERRAIN_COAST"; 
UPDATE GlobalParameters SET Value = Value * 2 WHERE Name ='MOVEMENT_WHILE_EMBARKED_BASE';
UPDATE Units SET BaseMoves = BaseMoves * 2 WHERE Domain = 'DOMAIN_SEA';




