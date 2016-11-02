/*

	YnAMP
	City States Text creation file
	by Gedemon (2016)	
	
*/
	
-- <LocalizedText>
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CIVILIZATION_' || Name || '_NAME', en_US_Name, 'en_US'
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CIVILIZATION_' || Name || '_ADJECTIVE', en_US_Adj, 'en_US'
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CIVILIZATION_' || Name || '_DESCRIPTION', en_US_Desc, 'en_US'
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CITY_NAME_' || Name || '_1', en_US_CapitalName, 'en_US'	WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_CITY_NAME_' || Name || '_1' = Tag AND 'en_US' = Language)
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CITY_NAME_' || Name || '_2', en_US_CapitalName, 'en_US'	WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_CITY_NAME_' || Name || '_2' = Tag AND 'en_US' = Language)
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CITY_NAME_' || Name || '_3', en_US_CapitalName, 'en_US'	WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_CITY_NAME_' || Name || '_3' = Tag AND 'en_US' = Language)
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CITY_NAME_' || Name || '_4', en_US_CapitalName, 'en_US'	WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_CITY_NAME_' || Name || '_4' = Tag AND 'en_US' = Language)
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CITY_NAME_' || Name || '_5', en_US_CapitalName, 'en_US'	WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_CITY_NAME_' || Name || '_5' = Tag AND 'en_US' = Language)
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_1', en_US_Name, 'en_US' WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_1' = Tag AND 'en_US' = Language)
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_2', '...', 'en_US' WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_2' = Tag AND 'en_US' = Language)
	FROM CityStatesConfiguration;
INSERT OR REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_3', '...', 'en_US' WHERE NOT EXISTS   (SELECT Tag FROM LocalizedText WHERE 'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_3' = Tag AND 'en_US' = Language)
	FROM CityStatesConfiguration;

-----------------------------------------------
-- Now we can delete CityStatesConfiguration table
-----------------------------------------------

DROP TABLE CityStatesConfiguration;
