/*

	YnAMP
	City States creation file
	by Gedemon (2016)
	
	Category : 	SCIENTIFIC | INDUSTRIAL | MILITARISTIC | CULTURAL | RELIGIOUS | TRADE
	Ethnicity : MEDIT | EURO | SOUTHAM | ASIAN | AFRICAN
	
*/

-----------------------------------------------
-- Fill the initialization table
-----------------------------------------------
INSERT INTO CityStatesConfiguration
	(		Name,			Category,		Ethnicity,	en_US_Name,		en_US_Adj,		en_US_Desc,					en_US_CapitalName 	)
SELECT	'SUTAIO',			'MILITARISTIC',	'SOUTHAM',	'Cheyenne',		'Cheyenne',		'Sutaio city-state',		'Sutaio'		UNION ALL
SELECT	'LAKOTA',			'CULTURAL',		'SOUTHAM',	'Sioux',		'Sioux',		'Lakota city-state',		'Lakota'		UNION ALL
SELECT	'HARAPPA',			'RELIGIOUS',	'ASIAN',	'Harappa',		'Harappan',		'Harappa city-state',		'Harappa'		UNION ALL
SELECT	'DAKAR',			'TRADE',		'AFRICAN',	'Senegal',		'Senegalese',	'Dakar city-state',			'Dakar'			UNION ALL
SELECT	'REYKJAVIK',		'SCIENTIFIC',	'EURO',		'Iceland',		'Icelander',	'Reykjavik city-state',		'Reykjavik'		UNION ALL
SELECT	'GARAMANTES',		'INDUSTRIAL',	'MEDIT',	'Garama',		'Berber',		'Garama city-state',		'Garama'		UNION ALL
SELECT	'SAMARKAND',		'MILITARISTIC',	'ASIAN',	'Uzbekistan',	'Uzbek',		'Samarkand city-state',		'Samarkand'		UNION ALL
SELECT	'TIKAL',			'SCIENTIFIC',	'SOUTHAM',	'Maya',			'Maya',			'Tikal city-state',			'Tikal'			UNION ALL
SELECT	'CUZCO',			'RELIGIOUS',	'SOUTHAM',	'Inca',			'Inca',			'Cuzco city-state',			'Cuzco'			UNION ALL
SELECT	'IFE',				'CULTURAL',		'AFRICAN',	'Nigeria',		'Nigerian',		'Ile Ife city-state',		'Ile Ife'		UNION ALL
SELECT	'ULUNDI',			'MILITARISTIC',	'AFRICAN',	'Zulu',			'Zulu',			'Ulundi city-state',		'Ulundi'		UNION ALL
SELECT	'MOGADISHU',		'INDUSTRIAL',	'AFRICAN',	'Somalia',		'Somalian',		'Mogadishu city-state',		'Mogadishu'		UNION ALL
SELECT	'AKSUM',			'TRADE',		'AFRICAN',	'Ethiopia',		'Ethiopian',	'Aksum city-state',			'Aksum'			UNION ALL
SELECT	'RABAT',			'TRADE',		'MEDIT',	'Morocco',		'Moroccan',		'Rabat city-state',			'Rabat'			UNION ALL
SELECT	'END_OF_INSERT',	NULL,			NULL,		NULL,			NULL,			NULL,						NULL;
-----------------------------------------------

-- Remove "END_OF_INSERT" entry 
DELETE from CityStatesConfiguration WHERE Name ='END_OF_INSERT';

-- Make some space
DELETE FROM Civilizations WHERE CivilizationType = 'CIVILIZATION_BRUSSELS' OR CivilizationType = 'CIVILIZATION_AMSTERDAM' OR CivilizationType = 'CIVILIZATION_GENEVA' OR CivilizationType = 'CIVILIZATION_STOCKHOLM' OR CivilizationType = 'CIVILIZATION_LISBON';


-- <Types> 
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT	'CIVILIZATION_' || Name, 'KIND_CIVILIZATION'
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT	'LEADER_MINOR_CIV_' || Name, 'KIND_LEADER'
	FROM CityStatesConfiguration;	

-- <TypeProperties>
INSERT OR REPLACE INTO TypeProperties (Type, Name, Value)
	SELECT	'CIVILIZATION_' || Name, 'CityStateCategory', Category
	FROM CityStatesConfiguration;
	
-- <Civilizations>
INSERT OR REPLACE INTO Civilizations (CivilizationType, Name, Description, Adjective, StartingCivilizationLevelType, RandomCityNameDepth)
	SELECT	'CIVILIZATION_' || Name, 'LOC_CIVILIZATION_' || Name || '_NAME', 'LOC_CIVILIZATION_' || Name || '_DESCRIPTION', 'LOC_CIVILIZATION_' || Name || '_ADJECTIVE', 'CIVILIZATION_LEVEL_CITY_STATE', 1
	FROM CityStatesConfiguration;
	
-- <CivilizationLeaders>
INSERT OR REPLACE INTO CivilizationLeaders (CivilizationType, LeaderType, CapitalName)
	SELECT	'CIVILIZATION_' || Name, 'LEADER_MINOR_CIV_' || Name, 'LOC_CITY_NAME_' || Name || '_1'
	FROM CityStatesConfiguration;
	
-- <CityNames>
INSERT OR REPLACE INTO CityNames (CivilizationType, CityName)
	SELECT	'CIVILIZATION_' || Name, 'LOC_CITY_NAME_' || Name || '_1'
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO CityNames (CivilizationType, CityName)
	SELECT	'CIVILIZATION_' || Name, 'LOC_CITY_NAME_' || Name || '_2'
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO CityNames (CivilizationType, CityName)
	SELECT	'CIVILIZATION_' || Name, 'LOC_CITY_NAME_' || Name || '_3'
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO CityNames (CivilizationType, CityName)
	SELECT	'CIVILIZATION_' || Name, 'LOC_CITY_NAME_' || Name || '_4'
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO CityNames (CivilizationType, CityName)
	SELECT	'CIVILIZATION_' || Name, 'LOC_CITY_NAME_' || Name || '_5'
	FROM CityStatesConfiguration;

-- <PlayerColors>
INSERT OR REPLACE INTO Colors VALUES ('COLOR_PLAYER_CITY_STATE_SCIENTIFIC_SECONDARY','0.13','0.75','0.97','1'); -- they've used "SCIENCE" instead of "SCIENTIFIC" in that table, adding correct entry here
INSERT OR REPLACE INTO PlayerColors (Type, Usage, PrimaryColor, SecondaryColor, TextColor)
	SELECT	'CIVILIZATION_' || Name, 'Minor', 'COLOR_PLAYER_CITY_STATE_PRIMARY', 'COLOR_PLAYER_CITY_STATE_' || Category || '_SECONDARY', 'COLOR_PLAYER_CITY_STATE_' || Category || '_SECONDARY'
	FROM CityStatesConfiguration;
	
-- <Leaders>
INSERT OR REPLACE INTO Leaders (LeaderType, Name, InheritFrom)
	SELECT	'LEADER_MINOR_CIV_' || Name, 'LOC_CIVILIZATION_' || Name || '_NAME', 'LEADER_MINOR_CIV_' || Category
	FROM CityStatesConfiguration;

----------------------------------------------------------------------------------------------
-- We delete the temporary CityStatesConfiguration table in NewCityStatesTexts.sql
----------------------------------------------------------------------------------------------

