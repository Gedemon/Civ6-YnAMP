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

