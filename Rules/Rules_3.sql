/*
	YnAMP
	RuleSet 3
	by Gedemon (2016)
	
*/

-----------------------------------------------
-- Defines
-----------------------------------------------

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('YNAMP_RULESET', '3');

-----------------------------------------------
-- More moves on roads
-----------------------------------------------
UPDATE Routes SET MovementCost = 0.75 WHERE RouteType="ROUTE_ANCIENT_ROAD"; 
UPDATE Routes SET MovementCost = 0.50 WHERE RouteType="ROUTE_MEDIEVAL_ROAD"; 
UPDATE Routes SET MovementCost = 0.33 WHERE RouteType="ROUTE_INDUSTRIAL_ROAD"; 
UPDATE Routes SET MovementCost = 0.25 WHERE RouteType="ROUTE_MODERN_ROAD"; 

-----------------------------------------------
-- Double movement on Ocean
-----------------------------------------------
UPDATE Terrains SET MovementCost = 2 WHERE TerrainType="TERRAIN_COAST"; 
UPDATE GlobalParameters SET Value = Value * 2 WHERE Name ='MOVEMENT_WHILE_EMBARKED_BASE';
UPDATE Units SET BaseMoves = BaseMoves * 2 WHERE Domain = 'DOMAIN_SEA';

-----------------------------------------------
-- Border Growth
-----------------------------------------------
/*

-- try lua scripting instead:
-- define regions for faster expansion, for each plot acquired give 1,2,3 or more free plots around (adjacent to the acquired plot and one other of that civilization)
-- could scale with era.
-- could scale with regions. 

UPDATE Terrains SET InfluenceCost = 5 WHERE TerrainType="TERRAIN_COAST";
UPDATE Terrains SET InfluenceCost = 10 WHERE TerrainType="TERRAIN_OCEAN";

UPDATE ModifierArguments SET Value = 50 WHERE ModifierId="RELIGIOUS_SETTLEMENTS_CULTUREBORDER";

INSERT INTO Modifiers (ModifierId, ModifierType) VALUES ('ADJUST_BORDER_EXPANSION', 'MODIFIER_ALL_CITIES_CULTURE_BORDER_EXPANSION');
INSERT INTO ModifierArguments (ModifierId, Name, Value) VALUES ('ADJUST_BORDER_EXPANSION', 'Amount', '100');

INSERT INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_CODE_OF_LAWS', 'ADJUST_BORDER_EXPANSION');
INSERT INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_CRAFTSMANSHIP', 'ADJUST_BORDER_EXPANSION');
INSERT INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_FOREIGN_TRADE', 'ADJUST_BORDER_EXPANSION');
INSERT INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_MILITARY_TRADITION', 'ADJUST_BORDER_EXPANSION');
INSERT INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_STATE_WORKFORCE', 'ADJUST_BORDER_EXPANSION');
INSERT INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_EARLY_EMPIRE', 'ADJUST_BORDER_EXPANSION');
INSERT INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_MYSTICISM', 'ADJUST_BORDER_EXPANSION');
*/
