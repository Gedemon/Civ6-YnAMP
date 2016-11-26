/*
	YnAMP
	RuleSet Euro
	by Gedemon (2016)
	
*/

-- Majors ar handled in config with domains
-- this can be reused once I can set loading order for mods
--DELETE FROM Civilizations WHERE Ethnicity = 'ETHNICITY_ASIAN' OR Ethnicity = 'ETHNICITY_SOUTHAM' OR Ethnicity = 'ETHNICITY_AFRICAN';

-- Minors
DELETE FROM Civilizations WHERE
		CivilizationType = 'CIVILIZATION_BUENOS_AIRES'
	OR 	CivilizationType = 'CIVILIZATION_HONG_KONG' 
	OR 	CivilizationType = 'CIVILIZATION_JAKARTA' 
	OR 	CivilizationType = 'CIVILIZATION_KABUL' 
	OR 	CivilizationType = 'CIVILIZATION_KANDY' 
	OR 	CivilizationType = 'CIVILIZATION_KUMASI' 
	OR 	CivilizationType = 'CIVILIZATION_LA_VENTA' 
	OR 	CivilizationType = 'CIVILIZATION_MOHENJO_DARO' 
	OR 	CivilizationType = 'CIVILIZATION_NAN_MADOL' 
	OR 	CivilizationType = 'CIVILIZATION_SEOUL' 
	OR 	CivilizationType = 'CIVILIZATION_TORONTO' 
	OR 	CivilizationType = 'CIVILIZATION_ZANZIBAR';