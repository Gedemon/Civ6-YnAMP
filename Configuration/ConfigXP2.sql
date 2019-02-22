/*
	YnAMP
	by Gedemon (2016-2019)
	
*/

-----------------------------------------------
-- Remove invalid choices for GS
-----------------------------------------------

--DELETE FROM DomainValues WHERE Domain='RiversPlacement' AND Value='PLACEMENT_IMPORT' AND EXISTS (SELECT * FROM GameCores WHERE GameCore = 'Expansion2');