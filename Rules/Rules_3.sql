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
-- Barbarians
-----------------------------------------------

UPDATE GlobalParameters SET Value ='1' WHERE Name ='BARBARIAN_CAMP_MAX_PER_MAJOR_CIV';
UPDATE GlobalParameters SET Value ='5' WHERE Name ='BARBARIAN_CAMP_MINIMUM_DISTANCE_CITY';
UPDATE GlobalParameters SET Value ='4' WHERE Name ='BARBARIAN_CAMP_ODDS_OF_NEW_CAMP_SPAWNING';

-----------------------------------------------
-- Unit
-----------------------------------------------

/* Range = 1 for all Ranged Land/Sea unit */
UPDATE Units SET Range ='1' WHERE (RangedCombat > 0 OR Bombard > 0) AND (Domain = 'DOMAIN_LAND' OR Domain = 'DOMAIN_SEA');
UPDATE Units SET Combat ='0' WHERE (RangedCombat > 0 OR Bombard > 0) AND (Domain = 'DOMAIN_LAND');
UPDATE Units SET FormationClass = 'FORMATION_CLASS_SUPPORT' WHERE (RangedCombat > 0 OR Bombard > 0) AND (Domain = 'DOMAIN_LAND');

/* Range = 2 for some units */
UPDATE Units SET Range ='2' WHERE UnitType = 'UNIT_BATTLESHIP' OR UnitType = 'UNIT_BRAZILIAN_MINAS_GERAES' OR UnitType = 'UNIT_ROCKET_ARTILLERY';

/* Range = 3 for some units */
UPDATE Units SET Range ='3' WHERE UnitType = 'UNIT_MISSILE_CRUISER' OR UnitType = 'UNIT_NUCLEAR_SUBMARINE';

/* Walls */

--/*
DELETE FROM Buildings WHERE BuildingType ='BUILDING_WALLS';
DELETE FROM BuildingPrereqs WHERE Building ='BUILDING_WALLS';
DELETE FROM ModifierArguments WHERE Value ='BUILDING_WALLS';
--*/

/*
-- Replacement lacks icons and 3D models
INSERT OR REPLACE INTO Types (Type, Kind) VALUES ('BUILDING_ANCIENT_WALLS','KIND_BUILDING');
INSERT OR REPLACE INTO Buildings VALUES('BUILDING_ANCIENT_WALLS','LOC_BUILDING_WALLS_NAME','TECH_MASONRY',NULL,80,-1,-1,0,'DISTRICT_CITY_CENTER',NULL,'LOC_BUILDING_WALLS_DESCRIPTION',0,0,50,0,0,NULL,NULL,0,0,NULL,0,1,0,NULL,1,NULL,0,0,0,0,'NO_ERA',0,0,0,0,0,NULL,NULL,0,'ADVISOR_GENERIC');
DELETE FROM Buildings WHERE BuildingType ='BUILDING_WALLS';
UPDATE BuildingPrereqs SET PrereqBuilding ='BUILDING_ANCIENT_WALLS' WHERE PrereqBuilding ='BUILDING_WALLS';
UPDATE StartingBuildings SET Building ='BUILDING_ANCIENT_WALLS' WHERE Building ='BUILDING_WALLS';
UPDATE ModifierArguments SET Value ='BUILDING_ANCIENT_WALLS' WHERE Value ='BUILDING_WALLS';
--*/



