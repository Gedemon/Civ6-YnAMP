/*
	YnAMP
	by Gedemon (2021)
	
*/

-----------------------------------------------
-- Create Tables
-----------------------------------------------

-- Reserved Slots		
CREATE TABLE IF NOT EXISTS ReservedPlayerSlots
	(	LeaderType TEXT NOT NULL,
		NoDuplicate BOOLEAN NOT NULL CHECK (NoDuplicate IN (0,1)) DEFAULT 0,
		ForceReplace BOOLEAN NOT NULL CHECK (ForceReplace IN (0,1)) DEFAULT 0,
		IsMajor BOOLEAN NOT NULL CHECK (IsMajor IN (0,1)) DEFAULT 0);
