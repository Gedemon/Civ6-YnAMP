/*
	YnAMP
	RuleSet 1
	by Gedemon (2016)
	
*/

-----------------------------------------------
-- Defines
-----------------------------------------------

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('YNAMP_RULESET', '1');

-- Allows closer cities
UPDATE GlobalParameters SET Value = '2'	WHERE Name = 'CITY_MIN_RANGE';

-- Remove close CS
DELETE FROM Civilizations WHERE CivilizationType = 'CIVILIZATION_BRUSSELS' OR CivilizationType = 'CIVILIZATION_GENEVA' OR CivilizationType = 'CIVILIZATION_LISBON';



