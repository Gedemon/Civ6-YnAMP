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
	(	Civilization TEXT,
		Resource TEXT,
		Quantity INT default 1);
		
-- Optional Extra Placement
CREATE TABLE IF NOT EXISTS ExtraPlacement
	(	MapName TEXT,
		X INT default 0,
		Y INT default 0,
		ConfigurationId TEXT,
		ConfigurationValue TEXT,
		TerrainType TEXT,
		FeatureType TEXT,
		ResourceType TEXT,
		Quantity INT default 0);
		
-- GiantEarth
CREATE TABLE IF NOT EXISTS GiantEarth_StartPosition
	(	Civilization TEXT,
		Leader TEXT,
		X INT default 0,
		Y INT default 0);	
CREATE TABLE IF NOT EXISTS GiantEarth_RegionPosition
	(	Region TEXT,
		X INT default 0,
		Y INT default 0,
		Width INT default 0,
		Height INT default 0);			
CREATE TABLE IF NOT EXISTS GiantEarth_CityMap
	(	Civilization TEXT,
		CityLocaleName TEXT,
		X INT default 0,
		Y INT default 0);		

-- GreatestEarthMap
CREATE TABLE IF NOT EXISTS GreatestEarthMap_StartPosition
	(	Civilization TEXT,
		Leader TEXT,
		X INT default 0,
		Y INT default 0);
CREATE TABLE IF NOT EXISTS GreatestEarthMap_RegionPosition
	(	Region TEXT,
		X INT default 0,
		Y INT default 0,
		Width INT default 0,
		Height INT default 0);			
CREATE TABLE IF NOT EXISTS GreatestEarthMap_CityMap
	(	Civilization TEXT,
		CityLocaleName TEXT,
		X INT default 0,
		Y INT default 0);	

-- PlayEuropeAgain
CREATE TABLE IF NOT EXISTS PlayEuropeAgain_StartPosition
	(	Civilization TEXT,
		Leader TEXT,
		X INT default 0,
		Y INT default 0);
CREATE TABLE IF NOT EXISTS PlayEuropeAgain_RegionPosition
	(	Region TEXT,
		X INT default 0,
		Y INT default 0,
		Width INT default 0,
		Height INT default 0);			
CREATE TABLE IF NOT EXISTS PlayEuropeAgain_CityMap
	(	Civilization TEXT,
		CityLocaleName TEXT,
		X INT default 0,
		Y INT default 0);
		
-- LargestEarth
CREATE TABLE IF NOT EXISTS LargestEarth_StartPosition
	(	Civilization TEXT,
		Leader TEXT,
		X INT default 0,
		Y INT default 0);	
CREATE TABLE IF NOT EXISTS LargestEarth_RegionPosition
	(	Region TEXT,
		X INT default 0,
		Y INT default 0,
		Width INT default 0,
		Height INT default 0);			
CREATE TABLE IF NOT EXISTS LargestEarth_CityMap
	(	Civilization TEXT,
		CityLocaleName TEXT,
		X INT default 0,
		Y INT default 0);
		
-----------------------------------------------
-- Temporary Tables for initialization
-----------------------------------------------

DROP TABLE IF EXISTS CityStatesConfiguration;
		
CREATE TABLE CityStatesConfiguration
	(	Name TEXT,
		Category TEXT,
		Ethnicity TEXT		
	);