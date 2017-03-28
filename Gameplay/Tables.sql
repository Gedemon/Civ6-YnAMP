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
		
-- Start Positions
-- See EOF for added columns
CREATE TABLE IF NOT EXISTS StartPosition
	(	MapName TEXT,
		Civilization TEXT,
		Leader TEXT,
		X INT default 0,
		Y INT default 0);

-- Regions positions
CREATE TABLE IF NOT EXISTS RegionPosition
	(	MapName TEXT,
		Region TEXT,
		X INT default 0,
		Y INT default 0,
		Width INT default 0,
		Height INT default 0);			

-- City Map		
CREATE TABLE IF NOT EXISTS CityMap
	(	MapName TEXT,
		Civilization TEXT,
		CityLocaleName TEXT,
		X INT default 0,
		Y INT default 0,
		Area INT);		
		
-----------------------------------------------
-- Temporary Tables for initialization
-----------------------------------------------

DROP TABLE IF EXISTS CityStatesConfiguration;
		
CREATE TABLE CityStatesConfiguration
	(	Name TEXT,
		Category TEXT,
		Ethnicity TEXT		
	);
	
	
-- Altering the StartPosition table for compatibility with mods that used to add the table instead of setting loading priority
-- This is done at the end of the file in case of errors (IE if the columns are already set in another mod)
ALTER TABLE StartPosition ADD COLUMN DisabledByCivilization TEXT;
ALTER TABLE StartPosition ADD COLUMN DisabledByLeader TEXT;
ALTER TABLE StartPosition ADD COLUMN AlternateStart INT default 0;