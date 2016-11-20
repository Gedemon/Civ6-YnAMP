/*
	YnAMP
	RuleSet 2
	by Gedemon (2016)
	
*/

-----------------------------------------------
-- Defines
-----------------------------------------------

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('YNAMP_RULESET', '2');

-- Make some space
DELETE FROM Civilizations WHERE CivilizationType = 'CIVILIZATION_BRUSSELS' OR CivilizationType = 'CIVILIZATION_GENEVA';




