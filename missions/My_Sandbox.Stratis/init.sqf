/*
    Author: Clement D. / Arma-AI Team
    Mission: AAI Tactical Urban Grounding Sandbox (Stratis) - Agia Marina Seek & Destroy Campaign
    File: init.sqf
*/

diag_log "[AAI Stratis Campaign] Initializing Agia Marina Urban Seek & Destroy Campaign on Stratis...";

// ============================================================================
// 1. Agia Marina Multi-Sector Objectives (Close Urban Engagement ~100m)
// ============================================================================
// Focused on the Market Square, Church Plaza, and Main Street of Agia Marina
private _secAlphaPos   = [3005, 6030, 0];    // Sector Alpha: Market Square & Comms
private _secBravoPos   = [3025, 6060, 0];    // Sector Bravo: Church Plaza & Town Crossroads
private _secCharliePos = [3045, 6085, 0];    // Sector Charlie: North Village Fork
private _secDeltaPos   = [3080, 6135, 0];    // Sector Delta: Upper Hillside Redoubt

missionNamespace setVariable ["AAI_ObjectiveSectors", [
    ["SECTOR ALPHA",   _secAlphaPos,   "Market Square & Comms"],
    ["SECTOR BRAVO",   _secBravoPos,   "Church Plaza & Town Center"],
    ["SECTOR CHARLIE", _secCharliePos, "North Village Fork"],
    ["SECTOR DELTA",   _secDeltaPos,   "Upper Hillside Redoubt"]
]];
missionNamespace setVariable ["AAI_ActiveSectorIndex", 0];
missionNamespace setVariable ["AAI_ContestedObjectivePos", _secAlphaPos];

// Base positions (Close-quarters urban contact: 100m apart in central Agia Marina)
private _bBase = [2990, 6000, 0]; // South entrance of Market Square
private _oBase = [3050, 6100, 0]; // North entrance past Church Plaza

missionNamespace setVariable ["AAI_BluforBasePos", _bBase];
missionNamespace setVariable ["AAI_OpforBasePos", _oBase];

missionNamespace setVariable ["AAI_Mode_Active", true];
missionNamespace setVariable ["AAI_OPFOR_Affordance", true];

// ============================================================================
// 2. Tactical Fortifications & Sector Beacons (Complements Existing Town Buildings)
// ============================================================================
if (isNil "aai_stratis_world_spawned") then {
    missionNamespace setVariable ["aai_stratis_world_spawned", true];

    // --- SOUTH STAGING DEFENSES (BLUFOR Beach Road Spawn) ---
    {
        private _w = createVehicle ["Land_CncWall4_F", _bBase vectorAdd [_x, 8, 0], [], 0, "CAN_COLLIDE"];
        _w setPosATL (_bBase vectorAdd [_x, 8, 0]);
        _w setDir 15;
    } forEach [-12, -8, -4, 0, 4, 8, 12];

    // --- SECTOR ALPHA (Market Square: Comms Mast & Intel Laptop) ---
    private _tower = createVehicle ["Land_TTowerSmall_1_F", _secAlphaPos vectorAdd [-3, 2, 0], [], 0, "CAN_COLLIDE"];
    _tower setPosATL (_secAlphaPos vectorAdd [-3, 2, 0]);

    private _table1 = createVehicle ["Land_CampingTable_F", _secAlphaPos, [], 0, "CAN_COLLIDE"];
    _table1 setPosATL _secAlphaPos;
    private _lap1 = createVehicle ["Land_Laptop_device_F", _secAlphaPos vectorAdd [0, 0, 0.82], [], 0, "CAN_COLLIDE"];
    _lap1 setPosATL (_secAlphaPos vectorAdd [0, 0, 0.82]);

    private _wreck1 = createVehicle ["Land_Wreck_Car_F", _secAlphaPos vectorAdd [4, -5, 0], [], 0, "CAN_COLLIDE"];
    _wreck1 setPosATL (_secAlphaPos vectorAdd [4, -5, 0]); _wreck1 setDir 35;

    private _sandA1 = createVehicle ["Land_BagFence_Round_F", _secAlphaPos vectorAdd [5, 4, 0], [], 0, "CAN_COLLIDE"];
    _sandA1 setPosATL (_secAlphaPos vectorAdd [5, 4, 0]); _sandA1 setDir 180;

    // --- SECTOR BRAVO (Church Plaza: Command HQ Compound) ---
    private _hqBuilding = createVehicle ["Land_Cargo_HQ_V1_F", _secBravoPos vectorAdd [-8, 0, 0], [], 0, "CAN_COLLIDE"];
    _hqBuilding setPosATL (_secBravoPos vectorAdd [-8, 0, 0]); _hqBuilding setDir 105;

    private _wreck2 = createVehicle ["Land_Wreck_Truck_F", _secBravoPos vectorAdd [2, -6, 0], [], 0, "CAN_COLLIDE"];
    _wreck2 setPosATL (_secBravoPos vectorAdd [2, -6, 0]); _wreck2 setDir -20;

    private _sandB1 = createVehicle ["Land_BagFence_Round_F", _secBravoPos vectorAdd [6, 4, 0], [], 0, "CAN_COLLIDE"];
    _sandB1 setPosATL (_secBravoPos vectorAdd [6, 4, 0]); _sandB1 setDir 190;

    private _barB1 = createVehicle ["Land_CncBarrier_F", _secBravoPos vectorAdd [-2, 8, 0], [], 0, "CAN_COLLIDE"];
    _barB1 setPosATL (_secBravoPos vectorAdd [-2, 8, 0]); _barB1 setDir 15;

    // --- SECTOR CHARLIE (Upper Agia Marina Terraces: Ammo Cache) ---
    private _ammoCont = createVehicle ["Land_Cargo20_military_green_F", _secCharliePos, [], 0, "CAN_COLLIDE"];
    _ammoCont setPosATL _secCharliePos; _ammoCont setDir 20;

    private _crate1 = createVehicle ["Box_NATO_AmmoVeh_F", _secCharliePos vectorAdd [-3, 2, 0], [], 0, "CAN_COLLIDE"];
    _crate1 setPosATL (_secCharliePos vectorAdd [-3, 2, 0]);

    private _crate2 = createVehicle ["Box_East_Wps_F", _secCharliePos vectorAdd [3, -2, 0], [], 0, "CAN_COLLIDE"];
    _crate2 setPosATL (_secCharliePos vectorAdd [3, -2, 0]);

    private _sandC1 = createVehicle ["Land_BagFence_Round_F", _secCharliePos vectorAdd [-6, 6, 0], [], 0, "CAN_COLLIDE"];
    _sandC1 setPosATL (_secCharliePos vectorAdd [-6, 6, 0]); _sandC1 setDir 195;

    // --- SECTOR DELTA (North Road Exit Redoubt) ---
    private _bunkerW = createVehicle ["Land_BagFence_Round_F", _secDeltaPos vectorAdd [-6, 0, 0], [], 0, "CAN_COLLIDE"];
    _bunkerW setPosATL (_secDeltaPos vectorAdd [-6, 0, 0]); _bunkerW setDir 190;

    private _bunkerE = createVehicle ["Land_BagFence_Round_F", _secDeltaPos vectorAdd [6, 0, 0], [], 0, "CAN_COLLIDE"];
    _bunkerE setPosATL (_secDeltaPos vectorAdd [6, 0, 0]); _bunkerE setDir 190;

    // --- NORTH STAGING DEFENSES (OPFOR Mountain Road Spawn) ---
    {
        private _w = createVehicle ["Land_CncWall4_F", _oBase vectorAdd [_x, -8, 0], [], 0, "CAN_COLLIDE"];
        _w setPosATL (_oBase vectorAdd [_x, -8, 0]);
        _w setDir 195;
    } forEach [-12, -8, -4, 0, 4, 8, 12];
};

// ============================================================================
// 3. Squad Spawner (12 BLUFOR vs 12 OPFOR in Agia Marina)
// ============================================================================
AAI_fnc_spawnCampaignSquads = {
    private _bBase = missionNamespace getVariable ["AAI_BluforBasePos", [2990, 6000, 0]];
    private _oBase = missionNamespace getVariable ["AAI_OpforBasePos", [3050, 6100, 0]];
    private _targetSectorPos = missionNamespace getVariable ["AAI_ContestedObjectivePos", [3005, 6030, 0]];

    // Clean up existing units
    {
        if (!isNull _x) then { deleteVehicle _x; };
    } forEach (missionNamespace getVariable ["AAI_BluforUnits", []]);

    {
        if (!isNull _x) then { deleteVehicle _x; };
    } forEach (missionNamespace getVariable ["AAI_OpforUnits", []]);

    // Corridor Base Coordinates (Exact Lateral Alignment)
    private _bBaseAlpha   = [2990, 5995, 0];
    private _bBaseBravo   = [3020, 5995, 0];
    private _bBaseCharlie = [3045, 5990, 0];

    private _oBaseAlpha   = [2990, 6095, 0];
    private _oBaseBravo   = [3020, 6095, 0];
    private _oBaseCharlie = [3045, 6110, 0];

    // Separate Independent Specialized Fireteam Groups
    private _grpBluAlpha  = createGroup [west, true];  // Alpha Assault (West Alleys)
    private _grpBluBravo  = createGroup [west, true];  // Bravo Direct Fire Support (Center Street)
    private _grpBluSniper = createGroup [west, true];  // Charlie Autonomous Sniper / Overwatch (East Ridge)

    private _grpOpfAlpha  = createGroup [east, true];  // Alpha Assault (West Alleys)
    private _grpOpfBravo  = createGroup [east, true];  // Bravo Direct Fire Support (Center Street)
    private _grpOpfSniper = createGroup [east, true];  // Charlie Autonomous Sniper / Overwatch (East Ridge)

    // --- 12 BLUFOR OPERATORS (Spawning Directly in Designated Corridors) ---
    private _bConfigs = [
        // Fireteam Alpha (West Alleys: X = 2990)
        ["B_Soldier_SL_F", [0, 0, 0],   "BLU Alpha-1 [Lead]",     "Rifleman",     _grpBluAlpha,  _bBaseAlpha],
        ["B_Soldier_AR_F", [-2, -2, 0], "BLU Alpha-2 [Gunner]",   "Autorifleman", _grpBluAlpha,  _bBaseAlpha],
        ["B_Medic_F",      [2, -2, 0],  "BLU Alpha-3 [Medic]",    "Medic",        _grpBluAlpha,  _bBaseAlpha],
        ["B_Soldier_GL_F", [0, -4, 0],  "BLU Alpha-4 [Breacher]", "Breacher",     _grpBluAlpha,  _bBaseAlpha],

        // Fireteam Bravo (Central Street: X = 3020)
        ["B_Soldier_TL_F", [0, 0, 0],   "BLU Bravo-1 [TL]",       "Rifleman",     _grpBluBravo,  _bBaseBravo],
        ["B_Soldier_AR_F", [-2, -2, 0], "BLU Bravo-2 [Gunner]",   "Autorifleman", _grpBluBravo,  _bBaseBravo],
        ["B_Soldier_AR_F", [2, -2, 0],  "BLU Bravo-3 [Gunner]",   "Autorifleman", _grpBluBravo,  _bBaseBravo],
        ["B_Soldier_F",    [0, -4, 0],  "BLU Bravo-4 [Rifleman]", "Rifleman",     _grpBluBravo,  _bBaseBravo],

        // Fireteam Charlie (Autonomous Snipers / Overwatch Ridge: X = 3045)
        ["B_soldier_M_F",  [0, 0, 0],   "BLU Charlie-1 [Sniper]", "Marksman",     _grpBluSniper, _bBaseCharlie],
        ["B_Soldier_TL_F", [-2, -2, 0], "BLU Charlie-2 [Spotter]", "Rifleman",    _grpBluSniper, _bBaseCharlie],
        ["B_soldier_M_F",  [2, -2, 0],  "BLU Charlie-3 [Sniper]", "Marksman",     _grpBluSniper, _bBaseCharlie],
        ["B_Medic_F",      [0, -4, 0],  "BLU Charlie-4 [Support]","Medic",        _grpBluSniper, _bBaseCharlie]
    ];

    private _bluUnits = [];
    {
        _x params ["_type", "_offset", "_callsign", "_role", "_targetGrp", "_laneOrigin"];
        private _pos = _laneOrigin vectorAdd _offset;
        private _unit = _targetGrp createUnit [_type, _pos, [], 0, "NONE"];
        _unit setPosATL _pos;
        _unit setDir 15;
        _unit setSkill 0.95;
        _unit allowDamage true;
        _unit setVariable ["AAI_Callsign", _callsign];
        _unit setVariable ["AAI_TacticalRole", _role];
        _unit setVariable ["AAI_TacticalObjective", _targetSectorPos];

        _unit addEventHandler ["Hit", {
            params ["_unit", "_source", "_damage", "_instigator"];
            if (alive _unit && {_damage > 0.05}) then {
                ["RECORD_DAMAGE", [_unit, _damage, _source]] call AAI_fnc_updateKnowledgeGraph;
            };
        }];

        _unit addEventHandler ["Killed", {
            params ["_unit", "_killer", "_instigator", "_useEffects"];
            if (!isNull _killer && {alive _killer}) then {
                ["RECORD_KILL", [_killer, _unit]] call AAI_fnc_updateKnowledgeGraph;
            };
        }];

        _bluUnits pushBack _unit;
    } forEach _bConfigs;

    // Link Buddy Pairs and Tactical Sector Corridors
    private _uA0 = _bluUnits select 0;
    private _uA1 = _bluUnits select 1;
    private _uA2 = _bluUnits select 2;
    private _uA3 = _bluUnits select 3;
    _uA0 setVariable ["AAI_BuddyUnit", _uA2]; _uA0 setVariable ["AAI_PairRole", "BASE_OF_FIRE"];
    _uA1 setVariable ["AAI_BuddyUnit", _uA3]; _uA1 setVariable ["AAI_PairRole", "BASE_OF_FIRE"];
    _uA2 setVariable ["AAI_BuddyUnit", _uA0]; _uA2 setVariable ["AAI_PairRole", "MANEUVER"];
    _uA3 setVariable ["AAI_BuddyUnit", _uA1]; _uA3 setVariable ["AAI_PairRole", "MANEUVER"];
    { _x setVariable ["AAI_TacticalCorridorCenter", [2990, 6045, 0]]; } forEach [_uA0, _uA1, _uA2, _uA3];

    private _uB4 = _bluUnits select 4;
    private _uB5 = _bluUnits select 5;
    private _uB6 = _bluUnits select 6;
    private _uB7 = _bluUnits select 7;
    _uB4 setVariable ["AAI_BuddyUnit", _uB6]; _uB4 setVariable ["AAI_PairRole", "BASE_OF_FIRE"];
    _uB5 setVariable ["AAI_BuddyUnit", _uB7]; _uB5 setVariable ["AAI_PairRole", "BASE_OF_FIRE"];
    _uB6 setVariable ["AAI_BuddyUnit", _uB4]; _uB6 setVariable ["AAI_PairRole", "MANEUVER"];
    _uB7 setVariable ["AAI_BuddyUnit", _uB5]; _uB7 setVariable ["AAI_PairRole", "MANEUVER"];
    { _x setVariable ["AAI_TacticalCorridorCenter", [3020, 6045, 0]]; } forEach [_uB4, _uB5, _uB6, _uB7];

    private _uC8  = _bluUnits select 8;
    private _uC9  = _bluUnits select 9;
    private _uC10 = _bluUnits select 10;
    private _uC11 = _bluUnits select 11;
    _uC8  setVariable ["AAI_BuddyUnit", _uC10]; _uC8  setVariable ["AAI_PairRole", "BASE_OF_FIRE"];
    _uC9  setVariable ["AAI_BuddyUnit", _uC11]; _uC9  setVariable ["AAI_PairRole", "BASE_OF_FIRE"];
    _uC10 setVariable ["AAI_BuddyUnit", _uC8];  _uC10 setVariable ["AAI_PairRole", "MANEUVER"];
    _uC11 setVariable ["AAI_BuddyUnit", _uC9];  _uC11 setVariable ["AAI_PairRole", "MANEUVER"];
    { _x setVariable ["AAI_TacticalCorridorCenter", [3045, 6045, 0]]; } forEach [_uC8, _uC9, _uC10, _uC11];

    // --- 12 OPFOR OPERATORS (Spawning Directly in Designated Corridors) ---
    private _oConfigs = [
        // Fireteam Alpha (West Alleys: X = 2990)
        ["O_Soldier_SL_F", [0, 0, 0],   "OPF Alpha-1 [Lead]",     "Rifleman",     _grpOpfAlpha,  _oBaseAlpha],
        ["O_Soldier_AR_F", [-2, 2, 0],  "OPF Alpha-2 [Gunner]",   "Autorifleman", _grpOpfAlpha,  _oBaseAlpha],
        ["O_Medic_F",      [2, 2, 0],   "OPF Alpha-3 [Medic]",    "Medic",        _grpOpfAlpha,  _oBaseAlpha],
        ["O_Soldier_GL_F", [0, 4, 0],   "OPF Alpha-4 [Breacher]", "Breacher",     _grpOpfAlpha,  _oBaseAlpha],

        // Fireteam Bravo (Central Street: X = 3020)
        ["O_Soldier_TL_F", [0, 0, 0],   "OPF Bravo-1 [TL]",       "Rifleman",     _grpOpfBravo,  _oBaseBravo],
        ["O_Soldier_AR_F", [-2, 2, 0],  "OPF Bravo-2 [Gunner]",   "Autorifleman", _grpOpfBravo,  _oBaseBravo],
        ["O_Soldier_AR_F", [2, 2, 0],   "OPF Bravo-3 [Gunner]",   "Autorifleman", _grpOpfBravo,  _oBaseBravo],
        ["O_Soldier_F",    [0, 4, 0],   "OPF Bravo-4 [Rifleman]", "Rifleman",     _grpOpfBravo,  _oBaseBravo],

        // Fireteam Charlie (Autonomous Snipers / Ridge Overwatch: X = 3045)
        ["O_soldier_M_F",  [0, 0, 0],   "OPF Charlie-1 [Sniper]", "Marksman",     _grpOpfSniper, _oBaseCharlie],
        ["O_Soldier_TL_F", [-2, 2, 0],  "OPF Charlie-2 [Spotter]","Rifleman",     _grpOpfSniper, _oBaseCharlie],
        ["O_soldier_M_F",  [2, 2, 0],   "OPF Charlie-3 [Sniper]", "Marksman",     _grpOpfSniper, _oBaseCharlie],
        ["O_Medic_F",      [0, 4, 0],   "OPF Charlie-4 [Support]","Medic",        _grpOpfSniper, _oBaseCharlie]
    ];

    private _opfUnits = [];
    {
        _x params ["_type", "_offset", "_callsign", "_role", "_targetGrp", "_laneOrigin"];
        private _pos = _laneOrigin vectorAdd _offset;
        private _unit = _targetGrp createUnit [_type, _pos, [], 0, "NONE"];
        _unit setPosATL _pos;
        _unit setDir 195;
        _unit setSkill 0.95;
        _unit allowDamage true;
        _unit setVariable ["AAI_Callsign", _callsign];
        _unit setVariable ["AAI_TacticalRole", _role];

        _opfUnits pushBack _unit;
    } forEach _oConfigs;

    // Link OPFOR Buddy Pairs and Tactical Sector Corridors
    private _oA0 = _opfUnits select 0;
    private _oA1 = _opfUnits select 1;
    private _oA2 = _opfUnits select 2;
    private _oA3 = _opfUnits select 3;
    _oA0 setVariable ["AAI_BuddyUnit", _oA2]; _oA0 setVariable ["AAI_PairRole", "BASE_OF_FIRE"];
    _oA1 setVariable ["AAI_BuddyUnit", _oA3]; _oA1 setVariable ["AAI_PairRole", "BASE_OF_FIRE"];
    _oA2 setVariable ["AAI_BuddyUnit", _oA0]; _oA2 setVariable ["AAI_PairRole", "MANEUVER"];
    _oA3 setVariable ["AAI_BuddyUnit", _oA1]; _oA3 setVariable ["AAI_PairRole", "MANEUVER"];
    { _x setVariable ["AAI_TacticalCorridorCenter", [2990, 6045, 0]]; } forEach [_oA0, _oA1, _oA2, _oA3];

    private _oB4 = _opfUnits select 4;
    private _oB5 = _opfUnits select 5;
    private _oB6 = _opfUnits select 6;
    private _oB7 = _opfUnits select 7;
    _oB4 setVariable ["AAI_BuddyUnit", _oB6]; _oB4 setVariable ["AAI_PairRole", "BASE_OF_FIRE"];
    _oB5 setVariable ["AAI_BuddyUnit", _oB7]; _oB5 setVariable ["AAI_PairRole", "BASE_OF_FIRE"];
    _oB6 setVariable ["AAI_BuddyUnit", _oB4]; _oB6 setVariable ["AAI_PairRole", "MANEUVER"];
    _oB7 setVariable ["AAI_BuddyUnit", _oB5]; _oB7 setVariable ["AAI_PairRole", "MANEUVER"];
    { _x setVariable ["AAI_TacticalCorridorCenter", [3020, 6045, 0]]; } forEach [_oB4, _oB5, _oB6, _oB7];

    private _oC8  = _opfUnits select 8;
    private _oC9  = _opfUnits select 9;
    private _oC10 = _opfUnits select 10;
    private _oC11 = _opfUnits select 11;
    _oC8  setVariable ["AAI_BuddyUnit", _oC10]; _oC8  setVariable ["AAI_PairRole", "BASE_OF_FIRE"];
    _oC9  setVariable ["AAI_BuddyUnit", _oC11]; _oC9  setVariable ["AAI_PairRole", "BASE_OF_FIRE"];
    _oC10 setVariable ["AAI_BuddyUnit", _oC8];  _oC10 setVariable ["AAI_PairRole", "MANEUVER"];
    _oC11 setVariable ["AAI_BuddyUnit", _oC9];  _oC11 setVariable ["AAI_PairRole", "MANEUVER"];
    { _x setVariable ["AAI_TacticalCorridorCenter", [3045, 6045, 0]]; } forEach [_oC8, _oC9, _oC10, _oC11];

    missionNamespace setVariable ["AAI_BluforUnits", _bluUnits];
    missionNamespace setVariable ["AAI_OpforUnits", _opfUnits];

    // Silence vanilla radio chatter & prevent engine FSM conflicts
    enableSentences false;
    enableRadio false;
    showSubtitles false;

    {
        private _grp = _x;
        _grp enableAttack false;
        _grp setBehaviour "COMBAT";
        _grp setCombatMode "RED";
        _grp setSpeedMode "FULL";

        {
            _x disableAI "AUTOCOMBAT";
            _x disableAI "RADIO";
            _x setSpeedMode "FULL";
        } forEach (units _grp);
    } forEach [
        _grpBluAlpha, _grpBluBravo, _grpBluSniper,
        _grpOpfAlpha, _grpOpfBravo, _grpOpfSniper
    ];

    // Mutual awareness
    {
        private _b = _x;
        {
            _b reveal [_x, 4];
            _x reveal [_b, 4];
        } forEach _opfUnits;
    } forEach _bluUnits;

    // Launch Semantic Controllers for BLUFOR
    {
        private _targetThreat = if (_forEachIndex < count _opfUnits) then { _opfUnits select _forEachIndex } else { _opfUnits select 0 };
        [_x, _targetThreat, 0.35] spawn AAI_fnc_startAgentController;
    } forEach _bluUnits;

    // Launch Semantic Controllers for OPFOR
    {
        private _targetThreat = if (_forEachIndex < count _bluUnits) then { _bluUnits select _forEachIndex } else { _bluUnits select 0 };
        [_x, _targetThreat, 0.35] spawn AAI_fnc_startAgentController;
    } forEach _opfUnits;

    diag_log format ["[AAI Stratis Campaign] Spawned 12v12 Platoon in Agia Marina (BLU: %1, OPF: %2).", count _bluUnits, count _opfUnits];
};

// Initial Squad Deployment
call AAI_fnc_spawnCampaignSquads;

// ============================================================================
// 4. Dynamic Multi-Sector Seek & Destroy Progression Loop
// ============================================================================
[] spawn {
    while {true} do {
        private _bluUnits = (missionNamespace getVariable ["AAI_BluforUnits", []]) select {alive _x};
        private _opfUnits = (missionNamespace getVariable ["AAI_OpforUnits", []]) select {alive _x};

        private _sectors = missionNamespace getVariable ["AAI_ObjectiveSectors", []];
        private _activeIdx = missionNamespace getVariable ["AAI_ActiveSectorIndex", 0];
        private _curSector = _sectors select _activeIdx;
        _curSector params ["_secName", "_secPos", "_secDesc"];

        private _bluNear = {(_x distance2D _secPos) < 30} count _bluUnits;
        private _opfNear = {(_x distance2D _secPos) < 30} count _opfUnits;

        if (_bluNear > 0 && {_opfNear == 0} && {_activeIdx < (count _sectors - 1)}) then {
            _activeIdx = _activeIdx + 1;
            missionNamespace setVariable ["AAI_ActiveSectorIndex", _activeIdx];
            private _nextSec = _sectors select _activeIdx;
            _nextSec params ["_nName", "_nPos", "_nDesc"];
            missionNamespace setVariable ["AAI_ContestedObjectivePos", _nPos];

            {
                _x setVariable ["AAI_TacticalObjective", _nPos];
            } forEach _bluUnits;

            systemChat format ["[AGIA MARINA] %1 SECURED! Pushing to %2 (%3)!", _secName, _nName, _nDesc];
            hintSilent parseText format [
                "<t color='#00ff88' size='1.3'>SECTOR SECURED!</t><br/><br/><t color='#ffffff'>BLUFOR cleared</t> <t color='#00ffcc'>%1</t>.<br/><br/><t color='#ffff00'>Next Objective:</t> <t color='#ffffff'>%2 (%3)</t><br/>Advancing uphill through Agia Marina!",
                _secName, _nName, _nDesc
            ];
        };

        // Maintain Coordinated BLUFOR Squad Progression (Assault & Heavy Support in Streets, Snipers on High Ground)
        if (count _bluUnits > 0 && {missionNamespace getVariable ["AAI_Mode_Active", true]}) then {
            {
                private _bUnit = _x;
                private _laneCenter = _bUnit getVariable ["AAI_TacticalCorridorCenter", _secPos];
                private _role = _bUnit getVariable ["AAI_TacticalRole", "Rifleman"];
                if (_role == "Marksman") then {
                    // Snipers take commanding elevated overwatch 45m behind the assault line
                    _bUnit setVariable ["AAI_TacticalObjective", [_laneCenter select 0, (_secPos select 1) - 45, 0]];
                } else {
                    _bUnit setVariable ["AAI_TacticalObjective", [_laneCenter select 0, _secPos select 1, 0]];
                };
            } forEach _bluUnits;
        };

        // Maintain Coordinated OPFOR Squad Progression (Assault in Streets, Snipers on Northern Ridge)
        if (count _opfUnits > 0 && {missionNamespace getVariable ["AAI_OPFOR_Affordance", true]}) then {
            {
                private _oUnit = _x;
                private _laneCenter = _oUnit getVariable ["AAI_TacticalCorridorCenter", _secPos];
                private _role = _oUnit getVariable ["AAI_TacticalRole", "Rifleman"];
                if (_role == "Marksman") then {
                    // OPFOR Snipers take commanding elevated ridge overwatch 45m north of the contested point
                    _oUnit setVariable ["AAI_TacticalObjective", [_laneCenter select 0, (_secPos select 1) + 45, 0]];
                } else {
                    _oUnit setVariable ["AAI_TacticalObjective", [_laneCenter select 0, _secPos select 1, 0]];
                };
            } forEach _opfUnits;
        };

        // OPFOR Hunter Movement (Vanilla Fallback if affordance disabled)
        if (count _opfUnits > 0 && {! (missionNamespace getVariable ["AAI_OPFOR_Affordance", false])}) then {
            {
                if (alive _x) then {
                    _x enableAI "MOVE";
                    _x enableAI "PATH";
                    _x enableAI "AUTOCOMBAT";
                    _x enableAI "AUTOTARGET";
                    _x enableAI "TARGET";
                    _x setBehaviour "COMBAT";
                    _x setCombatMode "RED";

                    // Check if unit has a visible BLUFOR threat
                    private _enemy = _x findNearestEnemy _x;
                    private _canEngage = false;

                    if (!isNull _enemy && {alive _enemy} && {_x distance _enemy < 120}) then {
                        private _vis = [objNull, "VIEW", _x] checkVisibility [eyePos _x, eyePos _enemy];
                        if (_vis > 0.15) then {
                            _canEngage = true;
                            _x doTarget _enemy;
                            _x doFire _enemy;
                        };
                    };

                    // Only call movement if NOT currently aiming/firing at a visible target
                    if (!_canEngage && {unitReady _x}) then {
                        _x setSpeedMode "NORMAL";
                        if (count _bluUnits > 0) then {
                            private _leadBlu = _bluUnits select 0;
                            _x reveal [_leadBlu, 4];
                            _x doMove (getPosATL _leadBlu);
                        } else {
                            _x doMove _secPos;
                        };
                    };
                };
            } forEach _opfUnits;
        };

        sleep 2.0;
    };
};

// ============================================================================
// 5. Zeus & Interactive Campaign Controls
// ============================================================================
if (hasInterface) then {
    [] spawn {
        waitUntil {!isNull player && {alive player}};
        player setPosATL [2990, 5990, 0];
        player setDir 25;
        sleep 0.5;

        private _curator = getAssignedCuratorLogic player;
        if (isNull _curator) then {
            private _grp = createGroup [sideLogic, true];
            _curator = _grp createUnit ["ModuleCurator_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
            _curator setVariable ["Addons", 3, true];
            _curator setVariable ["BIS_fnc_initModules_activate", true];
            player assignCurator _curator;
        };

        _curator addCuratorEditableObjects [allUnits + vehicles + (allMissionObjects "All"), true];
        removeAllCuratorCameraAreas _curator;

        // Dynamic Keyhandler for Zeus Toggle on Display 46 (Main Game)
        waitUntil {!isNull (findDisplay 46)};
        (findDisplay 46) displayAddEventHandler ["KeyDown", {
            params ["_disp", "_key"];
            // Y (21), Z (44)
            if (_key in [21, 44]) then {
                if (isNull (findDisplay 312)) then {
                    openCuratorInterface;
                } else {
                    (findDisplay 312) closeDisplay 1;
                };
                true
            } else {
                if (_key == 59) then {
                    call AAI_fnc_spawnCampaignSquads;
                    systemChat "[AAI TELEMETRY] Instant Match Reset (F1) triggered!";
                    true
                } else {
                    false
                };
            };
        }];

        // Dynamic Keyhandler on Display 312 (Zeus Interface) to cleanly exit with Esc, Backspace, Y, Z, or F1 reset
        [] spawn {
            while {true} do {
                waitUntil {!isNull (findDisplay 312)};
                private _zDisp = findDisplay 312;
                _zDisp displayAddEventHandler ["KeyDown", {
                    params ["_disp", "_key"];
                    // F1 (59) Instant Reset
                    if (_key == 59) exitWith {
                        call AAI_fnc_spawnCampaignSquads;
                        systemChat "[AAI TELEMETRY] Instant Match Reset (F1) triggered!";
                        true
                    };
                    // Esc (1), Backspace (14), Y (21), Z (44)
                    if (_key in [1, 14, 21, 44]) then {
                        _disp closeDisplay 1;
                        true
                    } else {
                        false
                    };
                }];
                waitUntil {isNull (findDisplay 312)};
            };
        };

        while {true} do {
            sleep 2;
            if (!isNull _curator) then {
                _curator addCuratorEditableObjects [allUnits + vehicles + (allMissionObjects "All"), true];
            };
        };
    };

    // Launch 3D Tactical Overlay
    private _leadBlu = (missionNamespace getVariable ["AAI_BluforUnits", [player]]) select 0;
    [true, _leadBlu] call AAI_fnc_drawTacticalOverlay;

    // --- Action 1: DIRECT ZEUS OVERHEAD CAMERA ---
    player addAction ["<t color='#ffff00' size='1.3'>[ZEUS] TOGGLE RTS CAMERA (Keys: Y, Z, Esc, Backspace)</t>", {
        if (isNull (findDisplay 312)) then {
            openCuratorInterface;
        } else {
            (findDisplay 312) closeDisplay 1;
        };
    }, nil, 3.0, false, false, "", "true", 50];

    // --- Action 2: Start / Restart Full Campaign ---
    player addAction ["<t color='#00ff88' size='1.1'>[CAMPAIGN] START AGIA MARINA BATTLE</t>", {
        ["RESET"] call AAI_fnc_updateKnowledgeGraph;
        missionNamespace setVariable ["AAI_ActiveSectorIndex", 0];
        private _secPos = ((missionNamespace getVariable ["AAI_ObjectiveSectors", []]) select 0) select 1;
        missionNamespace setVariable ["AAI_ContestedObjectivePos", _secPos];

        call AAI_fnc_spawnCampaignSquads;

        systemChat "[AGIA MARINA] 12v12 Battle initiated across 4 Town Sectors!";
        hintSilent parseText "<t color='#00ff88' size='1.3'>AGIA MARINA CAMPAIGN</t><br/><br/>12 BLUFOR Operators vs 12 OPFOR Soldiers.<br/>Advancing through <t color='#ffff00'>Market</t> $\to$ <t color='#ffff00'>Church Plaza</t> $\to$ <t color='#ffff00'>Terraces</t> $\to$ <t color='#ffff00'>North Redoubt</t>.<br/>Press <t color='#ffff00'>Y</t> or use mouse wheel to open Zeus!";
    }, nil, 2.5, false, false, "", "true", 50];

    // --- Action 3: Reinforcements Wave ---
    player addAction ["<t color='#33ffaa'>[REINFORCE] Deploy Fresh Squads (Keep Knowledge Graph)</t>", {
        call AAI_fnc_spawnCampaignSquads;
        systemChat "[REINFORCEMENTS] 24 fresh soldiers deployed! Learned Knowledge Graph preserved.";
    }, nil, 2.48, false, false, "", "true", 50];

    // --- Action 4: Advance Sector Manually ---
    player addAction ["<t color='#ffff00'>[SECTOR] Force Advance to Next Objective</t>", {
        private _sectors = missionNamespace getVariable ["AAI_ObjectiveSectors", []];
        private _activeIdx = (missionNamespace getVariable ["AAI_ActiveSectorIndex", 0]) + 1;
        if (_activeIdx >= count _sectors) then { _activeIdx = 0; };
        missionNamespace setVariable ["AAI_ActiveSectorIndex", _activeIdx];
        private _nextSec = _sectors select _activeIdx;
        _nextSec params ["_nName", "_nPos", "_nDesc"];
        missionNamespace setVariable ["AAI_ContestedObjectivePos", _nPos];

        systemChat format ["[MANUAL ADVANCE] Switched active objective to %1 (%2)", _nName, _nDesc];
    }, nil, 2.45, false, false, "", "true", 50];

    // --- Action 5: Live Semantic Telemetry Inspection ---
    player addAction ["<t color='#00ccff'>[TELEMETRY] Print Live Semantic Triples and Cost</t>", {
        private _bluUnits = (missionNamespace getVariable ["AAI_BluforUnits", []]) select {alive _x};
        private _triples = ["GET_TRIPLES"] call AAI_fnc_updateKnowledgeGraph;
        if (isNil "_triples") then { _triples = []; };

        systemChat "================ TICO AGIA MARINA TELEMETRY ================";
        systemChat format ["[PLATOON STRENGTH] BLUFOR: %1/12 Alive | OPFOR: %2/12 Alive", count _bluUnits, {alive _x} count (missionNamespace getVariable ["AAI_OpforUnits", []])];
        systemChat format ["[KNOWLEDGE GRAPH] %1 dynamic episodic triples recorded in memory.", count _triples];

        {
            private _callsign = _x getVariable ["AAI_Callsign", "BLU"];
            private _role = _x getVariable ["AAI_TacticalRole", "Rifleman"];
            private _state = _x getVariable ["AAI_TacticalState", "IDLE"];
            private _cost = _x getVariable ["AAI_BestCostScore", 0];
            private _cands = _x getVariable ["AAI_CandidateCount", 0];
            systemChat format ["  [%1 - %2] State: %3 | Cost J: %4 | Evaluated: %5 cands", _callsign, _role, _state, round (_cost * 10) / 10, _cands];
        } forEach (_bluUnits select [0, 6]);

        private _recentTriples = if (count _triples > 3) then { _triples select [count _triples - 3, 3] } else { _triples };
        {
            _x params ["_s", "_p", "_o", "_t"];
            systemChat format ["  -> %1 %2 %3 .", _s, _p, _o];
        } forEach _recentTriples;

        systemChat "============================================================";
    }, nil, 2.4, false, false, "", "true", 50];

    // --- Action 6: Toggle OPFOR Brain ---
    player addAction ["<t color='#ff9933'>[OPFOR BRAIN] Toggle: Vanilla FSM vs Affordance AI</t>", {
        private _isAff = missionNamespace getVariable ["AAI_OPFOR_Affordance", false];
        if (_isAff) then {
            missionNamespace setVariable ["AAI_OPFOR_Affordance", false];
            {
                private _h = _x getVariable ["AAI_ControllerHandle", scriptNull];
                if (!isNull _h) then { terminate _h; };
                _x enableAI "AUTOCOMBAT";
                _x enableAI "AUTOTARGET";
                _x enableAI "TARGET";
                _x setUnitPos "AUTO";
            } forEach (missionNamespace getVariable ["AAI_OpforUnits", []]);
            systemChat "[OPFOR BRAIN] Switched to VANILLA FSM mode.";
        } else {
            missionNamespace setVariable ["AAI_OPFOR_Affordance", true];
            private _bluUnits = missionNamespace getVariable ["AAI_BluforUnits", []];
            {
                private _target = if (_forEachIndex < count _bluUnits) then { _bluUnits select _forEachIndex } else { _bluUnits select 0 };
                [_x, _target, 0.35] spawn AAI_fnc_startAgentController;
            } forEach (missionNamespace getVariable ["AAI_OpforUnits", []]);
            systemChat "[OPFOR BRAIN] Switched to AFFORDANCE AI mode (Full 12v12 Platoon Mirror Match).";
        };
    }, nil, 2.3, false, false, "", "true", 50];

    // --- Action 7: Toggle 3D Tactical Overlay ---
    player addAction ["<t color='#00ffcc'>[DEBUG] Toggle 3D Tactical Overlay</t>", {
        if (isNil "AAI_Draw3D_Handler") then {
            private _leadBlu = (missionNamespace getVariable ["AAI_BluforUnits", [player]]) select 0;
            [true, _leadBlu] call AAI_fnc_drawTacticalOverlay;
            systemChat "[DEBUG] 3D Tactical Overlay ENABLED.";
        } else {
            [false] call AAI_fnc_drawTacticalOverlay;
            systemChat "[DEBUG] 3D Tactical Overlay DISABLED.";
        };
    }, nil, 2.1, false, false, "", "true", 50];

    // Live Combat Telemetry HUD Loop
    [] spawn {
        while {true} do {
            sleep 0.75;
            private _blu = (missionNamespace getVariable ["AAI_BluforUnits", []]) select {alive _x};
            private _opf = (missionNamespace getVariable ["AAI_OpforUnits", []]) select {alive _x};

            private _bluCover = { (_x getVariable ["AAI_TacticalState", ""]) == "IN_COVER" } count _blu;
            private _bluBound = (count _blu) - _bluCover;

            private _opfCover = { (_x getVariable ["AAI_TacticalState", ""]) == "IN_COVER" } count _opf;
            private _opfBound = (count _opf) - _opfCover;

            private _activeIdx = missionNamespace getVariable ["AAI_ActiveSectorIndex", 0];
            private _sectors = missionNamespace getVariable ["AAI_ObjectiveSectors", []];
            private _secName = if (_activeIdx < count _sectors) then { (_sectors select _activeIdx) select 0 } else { "FINAL" };

            hintSilent parseText format [
                "<t color='#00ffcc' size='1.1' font='PuristaBold'>[AAI AGIA MARINA BATTLE TELEMETRY]</t><br/>" +
                "<t color='#ffcc00'>Contested Sector:</t> <t color='#ffffff'>%5</t><br/><br/>" +
                "<t color='#3399ff' size='1.05'>BLUFOR:</t> %1/12 Alive <t color='#888888'>(%2 In Cover | %3 Moving)</t><br/>" +
                "<t color='#ff3333' size='1.05'>OPFOR:</t>  %4/12 Alive <t color='#888888'>(%6 In Cover | %7 Moving)</t><br/><br/>" +
                "<t color='#aaaaaa' size='0.85'>Key <t color='#ffff00'>Y/Z</t>: Zeus RTS | Key <t color='#ffff00'>F1</t>: Instant Reset</t>",
                count _blu, _bluCover, _bluBound,
                count _opf, _secName, _opfCover, _opfBound
            ];
        };
    };

    hintSilent parseText "<t size='1.3' color='#00ffcc'>Agia Marina (Stratis) Ready</t><br/><br/><t color='#ffffff'>• Real Greek coastal town with 40+ houses, church &amp; stone walls.</t><br/><t color='#ffffff'>• Press <t color='#ffff00'>Y</t> or use mouse wheel: <t color='#ffff00'>[ZEUS] OPEN CAMERA</t>.</t>";
};

diag_log "[AAI Stratis Campaign] Initialization completed successfully.";
