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

UPDATE GlobalParameters SET Value ='1' WHERE Name ='BARBARIAN_CAMP_MAX_PER_MAJOR_CIV';
UPDATE GlobalParameters SET Value ='5' WHERE Name ='BARBARIAN_CAMP_MINIMUM_DISTANCE_CITY';
UPDATE GlobalParameters SET Value ='4' WHERE Name ='BARBARIAN_CAMP_ODDS_OF_NEW_CAMP_SPAWNING';



