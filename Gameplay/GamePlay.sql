/*
	YnAMP
	by Gedemon (2016-2017)
	
*/

-----------------------------------------------
-- WorldBuilder max brush size
-----------------------------------------------

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('WB_MAX_BRUSH_SIZE', 6);


-----------------------------------------------
-- Fix Ethnicity
-----------------------------------------------

-- DLC
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_SOUTHAM'	WHERE CivilizationType = 'CIVILIZATION_AZTEC';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_POLAND';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_PERSIA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_MACEDON';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN'		WHERE CivilizationType = 'CIVILIZATION_INDONESIA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN'		WHERE CivilizationType = 'CIVILIZATION_KHMER';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_SOUTHAM'	WHERE CivilizationType = 'CIVILIZATION_CREE';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_GEORGIA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN'		WHERE CivilizationType = 'CIVILIZATION_KOREA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_SOUTHAM' 	WHERE CivilizationType = 'CIVILIZATION_MAPUCHE';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN' 		WHERE CivilizationType = 'CIVILIZATION_MONGOLIA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_NETHERLANDS';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_SCOTLAND';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_AFRICAN'	WHERE CivilizationType = 'CIVILIZATION_ZULU';

-- Euro City States
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_AMSTERDAM';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_BRUSSELS';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_GENEVA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_LISBON';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_PRESLAV';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_STOCKHOLM';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO'		WHERE CivilizationType = 'CIVILIZATION_VILNIUS';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO' 		WHERE CivilizationType = 'CIVILIZATION_ARMAGH';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_EURO' 		WHERE CivilizationType = 'CIVILIZATION_GRANADA';

-- SouthAm City States
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_SOUTHAM'	WHERE CivilizationType = 'CIVILIZATION_BUENOS_AIRES';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_SOUTHAM'	WHERE CivilizationType = 'CIVILIZATION_LA_VENTA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_SOUTHAM'	WHERE CivilizationType = 'CIVILIZATION_TORONTO';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_SOUTHAM' 	WHERE CivilizationType = 'CIVILIZATION_PALENQUE';

-- Medit City States 
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_CARTHAGE';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_HATTUSA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_JERUSALEM';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_KABUL';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_MOHENJO_DARO';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_VALLETTA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT'		WHERE CivilizationType = 'CIVILIZATION_YEREVAN';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_MEDIT' 		WHERE CivilizationType = 'CIVILIZATION_MUSCAT';

-- Asian City States
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN'		WHERE CivilizationType = 'CIVILIZATION_HONG_KONG';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN'		WHERE CivilizationType = 'CIVILIZATION_JAKARTA';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN'		WHERE CivilizationType = 'CIVILIZATION_KANDY';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN'		WHERE CivilizationType = 'CIVILIZATION_NAN_MADOL';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN'		WHERE CivilizationType = 'CIVILIZATION_SEOUL';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_ASIAN' 		WHERE CivilizationType = 'CIVILIZATION_AUCKLAND';

-- African City States
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_AFRICAN'	WHERE CivilizationType = 'CIVILIZATION_KUMASI';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_AFRICAN'	WHERE CivilizationType = 'CIVILIZATION_ZANZIBAR';
UPDATE Civilizations SET Ethnicity = 'ETHNICITY_AFRICAN' 	WHERE CivilizationType = 'CIVILIZATION_ANTANANARIVO';


		
