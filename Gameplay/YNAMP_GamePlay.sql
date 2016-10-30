/*
	YnAMP
	by Gedemon (2016)
	
*/

-----------------------------------------------
-- Fix Ethnicity
-----------------------------------------------

-- They forgot to set Ethnicity for the Aztec ?
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_SOUTHAM'	WHERE CivilizationType = 'CIVILIZATION_AZTEC';

-- Euro City States
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_AMSTERDAM';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_BRUSSELS';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_GENEVA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_LISBON';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_PRESLAV';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_STOCKHOLM';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_VILNIUS';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_PRESLAV';

-- SouthAm City States
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_SOUTHAM'	WHERE CivilizationType = 'CIVILIZATION_BUENOS_AIRES';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_SOUTHAM'	WHERE CivilizationType = 'CIVILIZATION_LA_VENTA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_SOUTHAM'	WHERE CivilizationType = 'CIVILIZATION_TORONTO';

-- Medit City States 
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_CARTHAGE';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_HATTUSA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_JERUSALEM';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_KABUL';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_MOHENJO_DARO';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_VALLETTA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_YEREVAN';

-- Asian City States
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN'		WHERE CivilizationType = 'CIVILIZATION_HONG_KONG';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN'		WHERE CivilizationType = 'CIVILIZATION_JAKARTA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN'		WHERE CivilizationType = 'CIVILIZATION_KANDY';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN'		WHERE CivilizationType = 'CIVILIZATION_NAN_MADOL';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN'		WHERE CivilizationType = 'CIVILIZATION_SEOUL';

-- African City States
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_AFRICAN'	WHERE CivilizationType = 'CIVILIZATION_KUMASI';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_AFRICAN'	WHERE CivilizationType = 'CIVILIZATION_ZANZIBAR';


-----------------------------------------------
-- Create Tables
-----------------------------------------------

CREATE TABLE IF NOT EXISTS GiantEarth_StartPosition
	(	Civilization TEXT,
		Leader TEXT,
		X INT default 0,
		Y INT default 0);		

CREATE TABLE IF NOT EXISTS GreatestEarthMap_StartPosition
	(	Civilization TEXT,
		Leader TEXT,
		X INT default 0,
		Y INT default 0);
		
CREATE TABLE IF NOT EXISTS PlayEuropeAgain_StartPosition
	(	Civilization TEXT,
		Leader TEXT,
		X INT default 0,
		Y INT default 0);
		
