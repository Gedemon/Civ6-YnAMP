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
	(	MapName TEXT,
		MapScript TEXT,
		X INT default 0,
		Y INT default 0,
		ConfigurationId TEXT,
		ConfigurationValue TEXT,
		RuleSet TEXT,
		Civilization TEXT,
		TerrainType TEXT,
		FeatureType TEXT,
		ResourceType TEXT,
		DisabledByFeature TEXT,
		Elevation INT,
		Quantity INT default 0);
		
-- Natural Wonder Positions
CREATE TABLE IF NOT EXISTS NaturalWonderPosition
	(	MapName TEXT,
		MapScript TEXT,
		FeatureType TEXT NOT NULL,
		TerrainType TEXT,
		X INT default 0,
		Y INT default 0);
		
-- Start Positions
CREATE TABLE IF NOT EXISTS StartPosition
	(	MapName TEXT,
		MapScript TEXT, 	-- to override MapName reference for specific entries in relation to MapScript (like in region of the Largest Earth Map that were heavily modified and can't use the GiantEarth reference)
		Civilization TEXT,
		Leader TEXT,
		DisabledByCivilization TEXT,
		DisabledByLeader TEXT,
		AlternateStart INT default 0,		
		X INT default 0,
		Y INT default 0);
		
-- Replaced civilization (Civilization type still exist, but is used to represent another Civilization, for example CIVILIZATION_JAKARTA is now representing Bandar Brunei)
CREATE TABLE IF NOT EXISTS ReplacedCivilization
	(	Civilization TEXT NOT NULL,
		ReplacedBy TEXT NOT NULL,
		WhenNameTag TEXT NOT NULL);

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
	(	MapName TEXT,
		MapScript TEXT, 	-- to override MapName reference for specific entries in relation to MapScript (like in region of the Largest Earth Map that were heavily modified and can't use the GiantEarth reference)
		Civilization TEXT,
		CityLocaleName TEXT NOT NULL,
		X INT default 0,
		Y INT default 0,
		Area INT NOT NULL default 1);

-- Maritime CS
CREATE TABLE IF NOT EXISTS StartBiasCoast
    (   CivilizationType TEXT,
        Tier INT default 1);


-- Scenario Civilization Replacements
-- To code:
-- Replace scenario's <CivilizationType> by the (last) <PreferedType> available
-- Use (last available) <BackupType> when the scenario's <CivilizationType> is not available
-- If the scenario use a <PreferedType> and it's not available, try to use the first available <CivilizationType> referencing it.
CREATE TABLE IF NOT EXISTS ScenarioCivilizationsReplacement
	(	ScenarioName TEXT NOT NULL,
		CivilizationType TEXT NOT NULL,
		BackupType TEXT,
		PreferedType TEXT);
		
-- Scenario Civilizations
CREATE TABLE IF NOT EXISTS ScenarioCivilizations
	(	ScenarioName TEXT,
		MapName TEXT,
		MapScript TEXT,
		SpecificEra TEXT,
		CivilizationType TEXT, 		-- can be NULL to set default values for all Civilization, in that case ScenarioName must not be NULL
		ExploreAll BOOLEAN,
		MeetAll BOOLEAN,
		Priority INT default 0, 	-- higher means first selected for placement in loops
		CityPlacement TEXT,
		MaxDistanceFromCapital INT, -- if OnlySameLandMass is true, then this is the land path distance, else it's the air distance
		MinCitySeparation INT,
		SouthernLatitude INT,		-- from -90 to 90, 0 being equator
		NorthernLatitude INT,
		BorderPlacement TEXT,
		BorderMaxDistance INT,
		OnlySameLandMass BOOLEAN,
		NumberOfCity INT,
		NumberOfMinorCity INT, 		-- Default scenario setting only, it has no effect when CivilizationType exists
		CapitalSize INT,
		OtherCitySize INT,
		DecreaseOtherCitySize BOOLEAN,	-- Default scenario setting only, it has no effect when CivilizationType exists
		CitySizeDecrement INT,
		NumCityPerSizeDecrement INT,
		Infrastructure TEXT,
		RoadPlacement TEXT,
		RoadMaxDistance INT,
		MaxRoadPerCity INT,
		InternationalRoads BOOLEAN,
		InternationalRoadMaxDistance INT,
		NationalRailPlacement TEXT,
		InternationalRails TEXT,
		RailsMaxDistance INT,
		Improvements TEXT,
		MaxNumImprovements INT,
		ImprovementsPerSizeRatio INT,
		MaxImprovementsDistance INT,
		Districts TEXT,
		MaxNumDistricts INT,
		DistrictsPerSize TEXT,
		MaxDistrictsDistance INT,
		Buildings TEXT,
		BuildingsPerSize TEXT,
		MaxNumBuildings INT);
		
-- Scenario Cities
CREATE TABLE IF NOT EXISTS ScenarioCities
	(	ScenarioName TEXT,
		MapName TEXT,
		CivilizationType TEXT,			-- to code : if NULL it will search a possible CivilizationType using the GameInfo.CityNames table (CityName must be set in that case)
		CityName TEXT,					-- if not NULL it will override the civilization city list name
		CitySize INT default 1,
		OnlyAI BOOLEAN NOT NULL CHECK (OnlyAI IN (0,1)) DEFAULT 0,
		OnlyHuman BOOLEAN NOT NULL CHECK (OnlyHuman IN (0,1)) DEFAULT 0,
		X INT,
		Y INT);
		
-- Scenario Territory
CREATE TABLE IF NOT EXISTS ScenarioTerritory
	(	ScenarioName TEXT,
		MapName TEXT,
		CivilizationType TEXT NOT NULL,
		CityName TEXT,					-- if NULL the plot will be owned by the nearest city
		CityX INT,
		CityY INT,
		OnlyAI BOOLEAN NOT NULL CHECK (OnlyAI IN (0,1)) DEFAULT 0,
		OnlyHuman BOOLEAN NOT NULL CHECK (OnlyHuman IN (0,1)) DEFAULT 0,
		X INT NOT NULL,
		Y INT NOT NULL);
		
-- Scenario Districts (placed after Territory)
CREATE TABLE IF NOT EXISTS ScenarioDistricts
	(	ScenarioName TEXT,
		MapName TEXT,
		DistrictType TEXT NOT NULL,
		CityName TEXT,					-- if NULL the district will be owned by the nearest city in that case
		CityX INT,
		CityY INT,
		InnerHealth INT,
		OutterHealth INT,
		OnlyAI BOOLEAN NOT NULL CHECK (OnlyAI IN (0,1)) DEFAULT 0,
		OnlyHuman BOOLEAN NOT NULL CHECK (OnlyHuman IN (0,1)) DEFAULT 0,
		X INT NOT NULL,
		Y INT NOT NULL);
		
-- Scenario Buildings (placed after Districts)
CREATE TABLE IF NOT EXISTS ScenarioBuildings
	(	ScenarioName TEXT,
		MapName TEXT,
		BuildingType TEXT NOT NULL,
		OnlyAI BOOLEAN NOT NULL CHECK (OnlyAI IN (0,1)) DEFAULT 0,
		OnlyHuman BOOLEAN NOT NULL CHECK (OnlyHuman IN (0,1)) DEFAULT 0,
		X INT NOT NULL,
		Y INT NOT NULL);
		
-- Scenario Occupied Territory (placed last - can be used only if there is a Get/SetOriginalOwner method for plots)
CREATE TABLE IF NOT EXISTS ScenarioOccupiedTerritory
	(	ScenarioName TEXT,
		MapName TEXT,
		CivilizationType TEXT NOT NULL,
		CityName TEXT,					-- if NULL the plot will be owned by the nearest city in that case
		CityX INT,
		CityY INT,
		OnlyAI BOOLEAN NOT NULL CHECK (OnlyAI IN (0,1)) DEFAULT 0,
		OnlyHuman BOOLEAN NOT NULL CHECK (OnlyHuman IN (0,1)) DEFAULT 0,
		X INT NOT NULL,
		Y INT NOT NULL);
		
-- Scenario Improvements
CREATE TABLE IF NOT EXISTS ScenarioInfrastructure
	(	ScenarioName TEXT,
		MapName TEXT,
		ImprovementType TEXT,
		RouteType TEXT,
		OnlyAI BOOLEAN NOT NULL CHECK (OnlyAI IN (0,1)) DEFAULT 0,
		OnlyHuman BOOLEAN NOT NULL CHECK (OnlyHuman IN (0,1)) DEFAULT 0,
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
	(	ScenarioName TEXT,
		MapName TEXT,
		CivilizationType TEXT NOT NULL,
		UnitType TEXT NOT NULL,
		Name TEXT,
		Damage INT default 0,
		PromotionList TEXT,
		OnlyAI BOOLEAN NOT NULL CHECK (OnlyAI IN (0,1)) DEFAULT 0,
		OnlyHuman BOOLEAN NOT NULL CHECK (OnlyHuman IN (0,1)) DEFAULT 0,
		X INT NOT NULL,
		Y INT NOT NULL);

-- Scenario Technologies
CREATE TABLE IF NOT EXISTS ScenarioTechs
	(	ScenarioName TEXT NOT NULL,
		CivilizationType TEXT,			-- If NULL give the tech (or the era's techs depending on which is set) to all civilizations
		EraType TEXT,
		OnlyAI BOOLEAN NOT NULL CHECK (OnlyAI IN (0,1)) DEFAULT 0,
		OnlyHuman BOOLEAN NOT NULL CHECK (OnlyHuman IN (0,1)) DEFAULT 0,
		TechnologyType TEXT);

-- Scenario Diplomacy
CREATE TABLE IF NOT EXISTS ScenarioDiplomacy
	(	ScenarioName TEXT NOT NULL,
		CivilizationType TEXT NOT NULL,
		DiplomaticAction TEXT,
		OtherCivilization TEXT,
		ActionValue INT);
		
-----------------------------------------------
-- Temporary Tables for initialization
-----------------------------------------------

DROP TABLE IF EXISTS CityStatesConfiguration;
		
CREATE TABLE CityStatesConfiguration
	(	Name TEXT,
		Category TEXT,
		Ethnicity TEXT		
	);