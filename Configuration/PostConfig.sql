/*
	YnAMP
	by Gedemon (2016-2019)
	
*/

-----------------------------------------------
-- Remove invalid XP/DLC entries in <Parameters>
-----------------------------------------------

-- the code below seems to work but the problem with it is that changing the ruleset on setup won't update the CS list...
/*
DELETE FROM Parameters WHERE ParameterId='DLC2' AND NOT EXISTS (SELECT Domain FROM Players WHERE Domain = 'VikingScenario_Players');

DELETE FROM Parameters WHERE ParameterId='XP1' AND NOT EXISTS 
	(SELECT LeaderType FROM Players WHERE LeaderType IN
		(
		'LEADER_POUNDMAKER',
		'LEADER_TAMAR',
		'LEADER_SEONDEOK',
		'LEADER_LAUTARO',
		'LEADER_GENGHIS_KHAN',
		'LEADER_WILHEMINA',
		'LEADER_ROBERT_THE_BRUCE',
		'LEADER_SHAKA',
		'LEADER_CHANDRAGUPTA'
		));

DELETE FROM Parameters WHERE ParameterId='XP2' AND NOT EXISTS 
	(SELECT LeaderType FROM Players WHERE LeaderType IN
		(
		'LEADER_LAURIER',
		'LEADER_PACHACUTI',
		'LEADER_MATTHIAS',
		'LEADER_MANSA_MUSA',
		'LEADER_KUPE',
		'LEADER_SULEIMAN',
		'LEADER_KRISTINA',
		'LEADER_ELEANOR'
		));
--*/