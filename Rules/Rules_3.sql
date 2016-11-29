/*
	YnAMP
	RuleSet 3
	by Gedemon (2016)
	
*/

-----------------------------------------------
-- Defines
-----------------------------------------------

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('YNAMP_RULESET', '3');

-----------------------------------------------
-- More moves on roads
-----------------------------------------------
UPDATE Routes SET MovementCost = 0.75 WHERE RouteType="ROUTE_ANCIENT_ROAD"; 
UPDATE Routes SET MovementCost = 0.50 WHERE RouteType="ROUTE_MEDIEVAL_ROAD"; 
UPDATE Routes SET MovementCost = 0.33 WHERE RouteType="ROUTE_INDUSTRIAL_ROAD"; 
UPDATE Routes SET MovementCost = 0.25 WHERE RouteType="ROUTE_MODERN_ROAD"; 

-----------------------------------------------
-- Double movement on Ocean
-----------------------------------------------
UPDATE Terrains SET MovementCost = 2 WHERE TerrainType="TERRAIN_COAST"; 
UPDATE GlobalParameters SET Value = Value * 2 WHERE Name ='MOVEMENT_WHILE_EMBARKED_BASE';
UPDATE Units SET BaseMoves = BaseMoves * 2 WHERE Domain = 'DOMAIN_SEA';

-----------------------------------------------
-- Border Growth
-----------------------------------------------
/*
UPDATE ModifierArguments SET Value = 30 WHERE ModifierId="RELIGIOUS_SETTLEMENTS_CULTUREBORDER";
INSERT INTO Modifiers (ModifierId, ModifierType) VALUES ('ADJUST_BORDER_EXPANSION', 'MODIFIER_ALL_CITIES_CULTURE_BORDER_EXPANSION');
INSERT INTO ModifierArguments (ModifierId, Name, Value) VALUES ('ADJUST_BORDER_EXPANSION', 'Amount', '25');
INSERT INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_POLITICAL_PHILOSOPHY', 'ADJUST_BORDER_EXPANSION');
INSERT INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_DIVINE_RIGHT', 'ADJUST_BORDER_EXPANSION');
INSERT INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_REFORMED_CHURCH', 'ADJUST_BORDER_EXPANSION');
INSERT INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_EXPLORATION', 'ADJUST_BORDER_EXPANSION');
INSERT INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_TOTALITARIANISM', 'ADJUST_BORDER_EXPANSION');
INSERT INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_CLASS_STRUGGLE', 'ADJUST_BORDER_EXPANSION');
INSERT INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_SUFFRAGE', 'ADJUST_BORDER_EXPANSION');
--*/

/*

-- try lua scripting instead (when script available) :
-- define regions (new table) for faster expansion, for each plot acquired give 1,2,3 or more free plots around (adjacent to the acquired plot and one other of that civilization)
-- could change with eras.
-- could be different per regions. 

--*/
--/*

INSERT INTO TraitModifiers
(	TraitType,					ModifierId							)	VALUES
(	'TRAIT_LEADER_MAJOR_CIV',	'ERA_CLASSICAL_INCREASED_BORDER_EXPANSION'		),
(	'TRAIT_LEADER_MAJOR_CIV',	'ERA_MEDIEVAL_INCREASED_BORDER_EXPANSION'		),
(	'TRAIT_LEADER_MAJOR_CIV',	'ERA_RENAISSANCE_INCREASED_BORDER_EXPANSION'	),
(	'TRAIT_LEADER_MAJOR_CIV',	'ERA_INDUSTRIAL_INCREASED_BORDER_EXPANSION'		),
(	'TRAIT_LEADER_MAJOR_CIV',	'ERA_MODERN_INCREASED_BORDER_EXPANSION'			),
(	'TRAIT_LEADER_MAJOR_CIV',	'ERA_ATOMIC_INCREASED_BORDER_EXPANSION'			),
(	'TRAIT_LEADER_MAJOR_CIV',	'ERA_INFORMATION_INCREASED_BORDER_EXPANSION'	);

INSERT INTO Modifiers
(	ModifierId,										ModifierType,											RunOnce,	Permanent,	SubjectRequirementSetId		)	VALUES
(	'ERA_CLASSICAL_INCREASED_BORDER_EXPANSION'	,	'MODIFIER_ALL_CITIES_CULTURE_BORDER_EXPANSION',			'0',		'0',		NULL						),
(	'ERA_MEDIEVAL_INCREASED_BORDER_EXPANSION'	,	'MODIFIER_ALL_CITIES_CULTURE_BORDER_EXPANSION',			'0',		'0',		NULL						),
(	'ERA_RENAISSANCE_INCREASED_BORDER_EXPANSION',	'MODIFIER_ALL_CITIES_CULTURE_BORDER_EXPANSION',			'0',		'0',		NULL						),
(	'ERA_INDUSTRIAL_INCREASED_BORDER_EXPANSION'	,	'MODIFIER_ALL_CITIES_CULTURE_BORDER_EXPANSION',			'0',		'0',		NULL						),
(	'ERA_MODERN_INCREASED_BORDER_EXPANSION'		,	'MODIFIER_ALL_CITIES_CULTURE_BORDER_EXPANSION',			'0',		'0',		NULL						),
(	'ERA_ATOMIC_INCREASED_BORDER_EXPANSION'		,	'MODIFIER_ALL_CITIES_CULTURE_BORDER_EXPANSION',			'0',		'0',		NULL						),
(	'ERA_INFORMATION_INCREASED_BORDER_EXPANSION',	'MODIFIER_ALL_CITIES_CULTURE_BORDER_EXPANSION',			'0',		'0',		NULL						);

INSERT INTO ModifierArguments
(	ModifierId,										Name,			Value,				Extra	)	VALUES
(	'ERA_CLASSICAL_INCREASED_BORDER_EXPANSION',		'Amount',		'10',				NULL	),
(	'ERA_CLASSICAL_INCREASED_BORDER_EXPANSION',		'StartEraType',	'ERA_CLASSICAL',	NULL	),
(	'ERA_MEDIEVAL_INCREASED_BORDER_EXPANSION',		'Amount',		'25',				NULL	),
(	'ERA_MEDIEVAL_INCREASED_BORDER_EXPANSION',		'StartEraType',	'ERA_MEDIEVAL',		NULL	),
(	'ERA_RENAISSANCE_INCREASED_BORDER_EXPANSION',	'Amount',		'25',				NULL	),
(	'ERA_RENAISSANCE_INCREASED_BORDER_EXPANSION',	'StartEraType',	'ERA_RENAISSANCE',	NULL	),
(	'ERA_INDUSTRIAL_INCREASED_BORDER_EXPANSION'	,	'Amount',		'50',				NULL	),
(	'ERA_INDUSTRIAL_INCREASED_BORDER_EXPANSION'	,	'StartEraType',	'ERA_INDUSTRIAL',	NULL	),
(	'ERA_MODERN_INCREASED_BORDER_EXPANSION'	,		'Amount',		'50',				NULL	),
(	'ERA_MODERN_INCREASED_BORDER_EXPANSION'	,		'StartEraType',	'ERA_MODERN',		NULL	),
(	'ERA_ATOMIC_INCREASED_BORDER_EXPANSION'	,		'Amount',		'100',				NULL	),
(	'ERA_ATOMIC_INCREASED_BORDER_EXPANSION'	,		'StartEraType',	'ERA_ATOMIC',		NULL	),
(	'ERA_INFORMATION_INCREASED_BORDER_EXPANSION',	'Amount',		'100',				NULL	),
(	'ERA_INFORMATION_INCREASED_BORDER_EXPANSION',	'StartEraType',	'ERA_INFORMATION',	NULL	);

-- Need requirements
--*/

/* Balance */
UPDATE ModifierArguments SET Value = 30 WHERE ModifierId="RELIGIOUS_SETTLEMENTS_CULTUREBORDER";

