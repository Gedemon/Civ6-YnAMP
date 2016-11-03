/*

	YnAMP
	City States Text creation file
	by Gedemon (2016)	
	
*/

DROP TABLE IF EXISTS CityStatesTextsConfiguration;
		
CREATE TABLE CityStatesTextsConfiguration
	(	Name TEXT,
		en_US_Name TEXT,
		en_US_Adj TEXT,
		en_US_Desc TEXT,
		en_US_CapitalName TEXT		
	);

-----------------------------------------------
-- Fill the initialization table
-----------------------------------------------
INSERT INTO CityStatesTextsConfiguration
	(		Name,			en_US_Name,		en_US_Adj,		en_US_Desc,					en_US_CapitalName 	)
SELECT	'SUTAIO',			'Cheyenne',		'Cheyenne',		'Sutaio city-state',		'Sutaio'		UNION ALL
SELECT	'LAKOTA',			'Sioux',		'Sioux',		'Lakota city-state',		'Lakota'		UNION ALL
SELECT	'HARAPPA',			'Harappa',		'Harappan',		'Harappa city-state',		'Harappa'		UNION ALL
SELECT	'DAKAR',			'Senegal',		'Senegalese',	'Dakar city-state',			'Dakar'			UNION ALL
SELECT	'REYKJAVIK',		'Iceland',		'Icelander',	'Reykjavik city-state',		'Reykjavik'		UNION ALL
SELECT	'GARAMANTES',		'Garama',		'Berber',		'Garama city-state',		'Garama'		UNION ALL
SELECT	'SAMARKAND',		'Uzbekistan',	'Uzbek',		'Samarkand city-state',		'Samarkand'		UNION ALL
SELECT	'TIKAL',			'Maya',			'Maya',			'Tikal city-state',			'Tikal'			UNION ALL
SELECT	'CUZCO',			'Inca',			'Inca',			'Cuzco city-state',			'Cuzco'			UNION ALL
SELECT	'IFE',				'Nigeria',		'Nigerian',		'Ile Ife city-state',		'Ile Ife'		UNION ALL
SELECT	'ULUNDI',			'Zulu',			'Zulu',			'Ulundi city-state',		'Ulundi'		UNION ALL
SELECT	'MOGADISHU',		'Somalia',		'Somalian',		'Mogadishu city-state',		'Mogadishu'		UNION ALL
SELECT	'AKSUM',			'Ethiopia',		'Ethiopian',	'Aksum city-state',			'Aksum'			UNION ALL
SELECT	'RABAT',			'Morocco',		'Moroccan',		'Rabat city-state',			'Rabat'			UNION ALL
SELECT	'END_OF_INSERT',	NULL,			NULL,			NULL,						NULL;
-----------------------------------------------

-- Remove "END_OF_INSERT" entry 
DELETE from CityStatesTextsConfiguration WHERE Name ='END_OF_INSERT';
	
-- <LocalizedText>
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CIVILIZATION_' || Name || '_NAME', en_US_Name, 'en_US'
	FROM CityStatesTextsConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CIVILIZATION_' || Name || '_ADJECTIVE', en_US_Adj, 'en_US'
	FROM CityStatesTextsConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CIVILIZATION_' || Name || '_DESCRIPTION', en_US_Desc, 'en_US'
	FROM CityStatesTextsConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CITY_NAME_' || Name || '_1', en_US_CapitalName, 'en_US'	WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_CITY_NAME_' || Name || '_1' = Tag AND 'en_US' = Language)
	FROM CityStatesTextsConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CITY_NAME_' || Name || '_2', en_US_CapitalName, 'en_US'	WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_CITY_NAME_' || Name || '_2' = Tag AND 'en_US' = Language)
	FROM CityStatesTextsConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CITY_NAME_' || Name || '_3', en_US_CapitalName, 'en_US'	WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_CITY_NAME_' || Name || '_3' = Tag AND 'en_US' = Language)
	FROM CityStatesTextsConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CITY_NAME_' || Name || '_4', en_US_CapitalName, 'en_US'	WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_CITY_NAME_' || Name || '_4' = Tag AND 'en_US' = Language)
	FROM CityStatesTextsConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CITY_NAME_' || Name || '_5', en_US_CapitalName, 'en_US'	WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_CITY_NAME_' || Name || '_5' = Tag AND 'en_US' = Language)
	FROM CityStatesTextsConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_1', en_US_Name, 'en_US' WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_1' = Tag AND 'en_US' = Language)
	FROM CityStatesTextsConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_2', '...', 'en_US' WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_2' = Tag AND 'en_US' = Language)
	FROM CityStatesTextsConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_3', '...', 'en_US' WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_3' = Tag AND 'en_US' = Language)
	FROM CityStatesTextsConfiguration;

-----------------------------------------------
-- Now we can delete CityStatesTextsConfiguration table
-----------------------------------------------

DROP TABLE CityStatesTextsConfiguration;
