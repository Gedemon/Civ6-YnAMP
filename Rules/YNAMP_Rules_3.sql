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
-- Unit
-----------------------------------------------

/* Range = 1 for all Ranged Land/Sea unit */
UPDATE Units SET Range ='1' WHERE (RangedCombat > 0 OR Bombard > 0) AND (Domain = 'DOMAIN_LAND' OR Domain = 'DOMAIN_SEA');
UPDATE Units SET Combat ='0' WHERE (RangedCombat > 0 OR Bombard > 0) AND (Domain = 'DOMAIN_LAND');
UPDATE Units SET FormationClass = 'FORMATION_CLASS_SUPPORT' WHERE (RangedCombat > 0 OR Bombard > 0) AND (Domain = 'DOMAIN_LAND');

/* Range = 2 for some units */
UPDATE Units SET Range ='2' WHERE UnitType = 'UNIT_BATTLESHIP' OR UnitType = 'UNIT_BRAZILIAN_MINAS_GERAES' OR UnitType = 'UNIT_ROCKET_ARTILLERY';

/* Range = 3 for some units */
UPDATE Units SET Range ='2' WHERE UnitType = 'UNIT_MISSILE_CRUISER' OR UnitType = 'UNIT_NUCLEAR_SUBMARINE';

/* Walls */
--UPDATE Units SET Range ='2' WHERE UnitType = 'UNIT_MISSILE_CRUISER' OR UnitType = 'UNIT_NUCLEAR_SUBMARINE';


