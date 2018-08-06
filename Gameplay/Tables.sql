/*
	YnAMP
	by Gedemon (2016)
	
*/

-----------------------------------------------
-- Create Tables
-----------------------------------------------

-- City names by Era		
CREATE TABLE IF NOT EXISTS CityNameByEra
	(	CityLocaleName TEXT,
		Era TEXT,
		CityEraName TEXT);
		
-- Resources : Exclusion zones for resources	
CREATE TABLE IF NOT EXISTS ResourceRegionExclude
	(	Region TEXT,
		Resource TEXT);
		
-- Resources : Exclusive zones for resources	
CREATE TABLE IF NOT EXISTS ResourceRegionExclusive
	(	Region TEXT,
		Resource TEXT);	
		
-- Resources : Regions of Major Deposits
CREATE TABLE IF NOT EXISTS ResourceRegionDeposit
	(	Region TEXT,
		Resource TEXT,
		Deposit TEXT,
		MinYield INT default 1,
		MaxYield INT default 1);
		
-- Resources : Requested for each Civilization
CREATE TABLE IF NOT EXISTS CivilizationRequestedResource
	(	Civilization TEXT NOT NULL,
		Resource TEXT,
		Quantity INT default 1);
		
-- Optional Extra Placement
CREATE TABLE IF NOT EXISTS ExtraPlacement
	(	MapName TEXT NOT NULL,
		X INT default 0,
		Y INT default 0,
		ConfigurationId TEXT,
		ConfigurationValue TEXT,
		Civilization TEXT,
		TerrainType TEXT,
		FeatureType TEXT,
		ResourceType TEXT,
		Quantity INT default 0);
		
-- Natural Wonder Positions
CREATE TABLE IF NOT EXISTS NaturalWonderPosition
	(	MapName TEXT NOT NULL,
		FeatureType TEXT NOT NULL,
		TerrainType TEXT,
		X INT default 0,
		Y INT default 0);
		
-- Start Positions
CREATE TABLE IF NOT EXISTS StartPosition
	(	MapName TEXT NOT NULL,
		Civilization TEXT,
		Leader TEXT,
		DisabledByCivilization TEXT,
		DisabledByLeader TEXT,
		AlternateStart INT default 0,		
		X INT default 0,
		Y INT default 0);

-- Regions positions
CREATE TABLE IF NOT EXISTS RegionPosition
	(	MapName TEXT NOT NULL,
		Region TEXT NOT NULL,
		X INT default 0,
		Y INT default 0,
		Width INT default 0,
		Height INT default 0);			

-- City Map		
CREATE TABLE IF NOT EXISTS CityMap
	(	MapName TEXT NOT NULL,
		Civilization TEXT,
		CityLocaleName TEXT NOT NULL,
		X INT default 0,
		Y INT default 0,
		Area INT);

-- Maritime CS
CREATE TABLE IF NOT EXISTS StartBiasCoast
    (   CivilizationType TEXT,
        Tier INT default 1);


-- Scenario Civilization Replacements
-- Replace scenario's <CivilizationType> by the (last) <PreferedType> available
-- Use (last available) <BackupType> when the scenario's <CivilizationType> is not available available
-- If the scenario use a <PreferedType> and it's not available, try to use the first available <CivilizationType> referencing it.
CREATE TABLE IF NOT EXISTS ScenarioCivilizationsReplacement
	(	ScenarioName TEXT NOT NULL,
		CivilizationType TEXT NOT NULL,
		BackupType TEXT,
		PreferedType TEXT);
		
-- Scenario Cities
CREATE TABLE IF NOT EXISTS ScenarioCities
	(	ScenarioName TEXT NOT NULL,
		CivilizationType TEXT,			-- if NULL it will search a possible CivilizationType using the GameInfo.CityNames table (CityName must be set in that case)
		CityName TEXT,					-- if not NULL it will override the civilization city list name
		CitySize INT default 1,
		X INT,
		Y INT);
		
-- Scenario Territory
CREATE TABLE IF NOT EXISTS ScenarioTerritory
	(	ScenarioName TEXT NOT NULL,
		CivilizationType TEXT NOT NULL,
		CityName TEXT,					-- if NULL the plot will be owned by the nearest city in that case
		X INT NOT NULL,
		Y INT NOT NULL);
		
-- Scenario Districts (placed after Territory)
CREATE TABLE IF NOT EXISTS ScenarioDistricts
	(	ScenarioName TEXT NOT NULL,
		DistrictType TEXT NOT NULL,
		CityName TEXT,					-- if NULL the district will be owned by the nearest city in that case
		InnerHealth INT,
		OutterHealth INT,
		X INT NOT NULL,
		Y INT NOT NULL);
		
-- Scenario Buildings (placed after Districts)
CREATE TABLE IF NOT EXISTS ScenarioBuildings
	(	ScenarioName TEXT NOT NULL,
		BuildingType TEXT NOT NULL,
		X INT NOT NULL,
		Y INT NOT NULL);
		
-- Scenario Occupied Territory (placed last - can be used only if there is a Get/SetOriginalOwner method for plots)
CREATE TABLE IF NOT EXISTS ScenarioOccupiedTerritory
	(	ScenarioName TEXT NOT NULL,
		CivilizationType TEXT NOT NULL,
		CityName TEXT,					-- if NULL the plot will be owned by the nearest city in that case
		X INT NOT NULL,
		Y INT NOT NULL);
		
-- Scenario Improvements
CREATE TABLE IF NOT EXISTS ScenarioImprovements
	(	ScenarioName TEXT NOT NULL,
		ImprovementType TEXT NOT NULL,
		X INT NOT NULL,
		Y INT NOT NULL);

-- Scenario Units Replacements
-- Use <BackupType> if the scenario's <UnitType> is not available 
CREATE TABLE IF NOT EXISTS ScenarioUnitsReplacement
	(	ScenarioName TEXT NOT NULL,
		UnitType TEXT NOT NULL,
		BackupType TEXT NOT NULL);

-- Scenario Units
CREATE TABLE IF NOT EXISTS ScenarioUnits
	(	ScenarioName TEXT NOT NULL,
		CivilizationType TEXT NOT NULL,
		UnitType TEXT NOT NULL,
		UnitName TEXT,
		PromotionList TEXT,
		Health INT default 100,
		X INT NOT NULL,
		Y INT NOT NULL);

-- Scenario Technologies
CREATE TABLE IF NOT EXISTS ScenarioTechs
	(	ScenarioName TEXT NOT NULL,
		CivilizationType TEXT,			-- If NULL give the tech (or the era's techs depending on which is set) to all civilizations
		EraType TEXT,
		TechnologyType TEXT);
		
-----------------------------------------------
-- Temporary Tables for initialization
-----------------------------------------------

DROP TABLE IF EXISTS CityStatesConfiguration;
		
CREATE TABLE CityStatesConfiguration
	(	Name TEXT,
		Category TEXT,
		Ethnicity TEXT		
	);