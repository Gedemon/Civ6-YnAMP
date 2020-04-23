/*
	YnAMP
	by Gedemon (2016-2020)
	
*/

-- Create the base of YnampCityMap based on YnampGenerated
--INSERT OR REPLACE INTO ScenarioCivilizations (ScenarioName,MapName,MapScript,SpecificEra,CivilizationType,Priority,CityPlacement,MaxDistanceFromCapital,MinCitySeparation,SouthernLatitude,NorthernLatitude,BorderMaxDistance,OnlySameLandMass,NumberOfCity,CapitalSize,OtherCitySize,CitySizeDecrement,NumCityPerSizeDecrement,RoadPlacement,RoadMaxDistance,MaxRoadPerCity,InternationalRoads,InternationalRoadMaxDistance,NationalRailPlacement,InternationalRails,RailsMaxDistance,Improvements,MaxNumImprovements,ImprovementsPerSizeRatio,MaxImprovementsDistance,Districts,MaxNumDistricts,DistrictsPerSize,MaxDistrictsDistance,Buildings,BuildingsPerSize,MaxNumBuildings)
--	SELECT	'YnampCityMap',SC.MapName,SC.MapScript,SC.SpecificEra,SC.CivilizationType,SC.Priority,'PLACEMENT_CITY_MAP_ONLY',SC.MaxDistanceFromCapital,SC.MinCitySeparation,SC.SouthernLatitude,SC.NorthernLatitude,SC.BorderMaxDistance,SC.OnlySameLandMass,SC.NumberOfCity,SC.CapitalSize,SC.OtherCitySize,SC.CitySizeDecrement,SC.NumCityPerSizeDecrement,SC.RoadPlacement,SC.RoadMaxDistance,SC.MaxRoadPerCity,SC.InternationalRoads,SC.InternationalRoadMaxDistance,SC.NationalRailPlacement,SC.InternationalRails,SC.RailsMaxDistance,SC.Improvements,SC.MaxNumImprovements,SC.ImprovementsPerSizeRatio,SC.MaxImprovementsDistance,SC.Districts,SC.MaxNumDistricts,SC.DistrictsPerSize,SC.MaxDistrictsDistance,SC.Buildings,SC.BuildingsPerSize,SC.MaxNumBuildings
--	FROM ScenarioCivilizations AS SC WHERE ScenarioName='YnampGenerated' AND NOT EXISTS (SELECT 1 FROM ScenarioCivilizations WHERE ScenarioName='YnampCityMap');
	
-- Update specific rows in ScenariosPostUpdate.xml