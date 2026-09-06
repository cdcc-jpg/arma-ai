/*
    Author: Clement D. / Arma-AI Systems Engineering Team
    Mission: AAI Tactical Grounding & Affordance Sandbox (VR) - 300m x 30m Dual Enclosed Corridors
    File: init.sqf

    Description:
        Massive 300-meter long by 30-meter wide dual enclosed tactical corridors.
        - Corridor 1 (Left, centered at X = -20m, width 30m): Vanilla Arma 3 AI.
        - Central Walkway (X = -5m to +5m, width 10m): Spectator observation corridor.
        - Corridor 2 (Right, centered at X = +20m, width 30m): TICO Semantic Affordance AI.
        - Symmetrical tactical layout across 8 sectors:
            Sandbags, stone walls, vehicle wrecks, sheds, cargo containers, H-barriers, shops.
        - Two-stage hostile objectives:
            Stage 1: Mid-Way Checkpoint Sentry (Y = 150m).
            Stage 2: Northern Command Redoubt Commander (Y = 295m).
        - Both blue runners advance simultaneously from Y = 2m to Y = 300m.
        - Ghost Instructor: Player is 100% INVULNERABLE and INVISIBLE.
        - Full ZEUS RTS camera (Keys: Y / Z).
        - AI First-Person Helmet Cam (Key: F2).
        - 3D Affordance Visualizer (Key: F3).
        - Instant Scenario Reset (Key: F1).
*/

diag_log "[AAI VR Bootcamp] Initializing 300m x 30m Dual Enclosed Tactical Corridors...";

// ============================================================================
// 1. Ghost Instructor Setup (Player Invulnerability & Invisibility)
// ============================================================================
private _origin = [4000, 4000, 0];
if (!isNull player) then {
    _origin = [getPosATL player select 0, getPosATL player select 1, 0];
    player allowDamage false;
    player setCaptive true;
    player hideObjectGlobal true;
};

missionNamespace setVariable ["AAI_BootcampOrigin", _origin];
missionNamespace setVariable ["AAI_3DOverlayActive", true];
missionNamespace setVariable ["AAI_CameraModeIndex", 0];

enableSentences false;
enableRadio false;
showSubtitles false;

// ============================================================================
// 2. Build the Massive 300m x 30m Dual Enclosed Corridors Architecture
// ============================================================================
AAI_fnc_build300mCorridors = {
    params ["_origin"];

    // Clean up previous world props if any
    {
        if (!isNull _x) then { deleteVehicle _x; };
    } forEach (missionNamespace getVariable ["AAI_BootcampWorldObjects", []]);

    private _props = [];

    // Helper to spawn perimeter boundary walls (tagged to be ignored by tactical perception)
    private _fnc_spawnBoundaryWall = {
        params ["_pos", "_dir"];
        private _w = createVehicle ["Land_CncWall4_F", _pos, [], 0, "CAN_COLLIDE"];
        _w setPosATL _pos;
        _w setDir _dir;
        _w setVariable ["AAI_IgnoreObstacle", true, true]; // Never consider boundary walls as covers!
        _props pushBack _w;
        _w
    };

    // Helper to spawn tactical props symmetrically in both corridors
    // relX is offset from corridor centerline (-20 for Left, +20 for Right)
    private _fnc_spawnTacticalPair = {
        params ["_class", "_relX", "_relY", "_dir"];

        // Corridor 1 (Left: Center X = -20m)
        private _posL = _origin vectorAdd [-20 + _relX, _relY, 0];
        private _objL = createVehicle [_class, _posL, [], 0, "CAN_COLLIDE"];
        _objL setPosATL _posL;
        _objL setDir _dir;
        _props pushBack _objL;

        // Corridor 2 (Right: Center X = +20m) - Symmetrically placed
        private _posR = _origin vectorAdd [20 + _relX, _relY, 0];
        private _objR = createVehicle [_class, _posR, [], 0, "CAN_COLLIDE"];
        _objR setPosATL _posR;
        _objR setDir _dir;
        _props pushBack _objR;

        [_objL, _objR]
    };

    // =========================================================================
    // PERIMETER ISOLATION WALLS (310m Length: Y = -5m to Y = 305m)
    // Corridor 1: X in [-35m, -5m] (Width = 30m)
    // Central Walkway: X in [-5m, +5m] (Width = 10m)
    // Corridor 2: X in [+5m, +35m] (Width = 30m)
    // =========================================================================
    for "_y" from -4 to 300 step 8 do {
        [_origin vectorAdd [-35, _y, 0], 0] call _fnc_spawnBoundaryWall; // Far Left Outer Wall
        [_origin vectorAdd [-5,  _y, 0], 0] call _fnc_spawnBoundaryWall; // Corridor 1 Right / Central Left Wall
        [_origin vectorAdd [5,   _y, 0], 0] call _fnc_spawnBoundaryWall; // Central Right / Corridor 2 Left Wall
        [_origin vectorAdd [35,  _y, 0], 0] call _fnc_spawnBoundaryWall; // Far Right Outer Wall
    };

    // Start boundary walls (Y = -5m)
    for "_x" from -33 to -7 step 8 do { [_origin vectorAdd [_x, -5, 0], 90] call _fnc_spawnBoundaryWall; };
    for "_x" from 7 to 33 step 8 do   { [_origin vectorAdd [_x, -5, 0], 90] call _fnc_spawnBoundaryWall; };

    // End boundary walls (Y = 305m)
    for "_x" from -33 to -7 step 8 do { [_origin vectorAdd [_x, 305, 0], 90] call _fnc_spawnBoundaryWall; };
    for "_x" from 7 to 33 step 8 do   { [_origin vectorAdd [_x, 305, 0], 90] call _fnc_spawnBoundaryWall; };

    // =========================================================================
    // 8 SYMMETRICAL TACTICAL SECTORS (0m to 300m)
    // =========================================================================

    // --- SECTOR 1 (Y = 15m - 45m) : Low Outskirts & Sandbags ---
    ["Land_BagFence_Long_F", -6, 18, 0] call _fnc_spawnTacticalPair;
    ["Land_BagFence_Long_F", 7, 24, -15] call _fnc_spawnTacticalPair;
    ["Land_Wreck_Car_F", -2, 32, 25] call _fnc_spawnTacticalPair;
    ["Land_Stone_4m_F", 5, 42, 10] call _fnc_spawnTacticalPair;

    // --- SECTOR 2 (Y = 55m - 85m) : Residential Chicanes & Sheds ---
    ["Land_Shed_02_F", -8, 58, 90] call _fnc_spawnTacticalPair;
    ["Land_CncBarrier_stripes_F", 6, 64, 0] call _fnc_spawnTacticalPair;
    ["Land_Wreck_Car2_F", 0, 74, -20] call _fnc_spawnTacticalPair;
    ["Land_Stone_Gate_F", -5, 84, 0] call _fnc_spawnTacticalPair;

    // --- SECTOR 3 (Y = 95m - 125m) : Industrial Freight & Containers ---
    ["Land_Cargo20_military_green_F", 7, 102, 0] call _fnc_spawnTacticalPair;
    ["Land_BagFence_Long_F", -7, 110, 15] call _fnc_spawnTacticalPair;
    ["Land_Wreck_Truck_dropside_F", -1, 120, -10] call _fnc_spawnTacticalPair;

    // --- SECTOR 4 (Y = 135m - 160m) : Mid-Way Checkpoint & Sentry 1 ---
    ["Land_Stone_4m_F", -8, 140, 0] call _fnc_spawnTacticalPair;
    ["Land_Stone_4m_F", 8, 140, 0] call _fnc_spawnTacticalPair;
    ["Land_BagBunker_Small_F", 0, 152, 180] call _fnc_spawnTacticalPair;
    ["Land_BagFence_Round_F", 0, 150, 180] call _fnc_spawnTacticalPair;

    // --- SECTOR 5 (Y = 170m - 200m) : Heavy H-Barrier Trench Line ---
    ["Land_HBarrier_5_F", -7, 172, 15] call _fnc_spawnTacticalPair;
    ["Land_HBarrier_3_F", 6, 182, -10] call _fnc_spawnTacticalPair;
    ["Land_Wreck_Hunter_F", -2, 194, 30] call _fnc_spawnTacticalPair;

    // --- SECTOR 6 (Y = 210m - 240m) : Urban Village Stores & Rubble ---
    ["Land_i_Shop_01_V1_F", 9, 218, -90] call _fnc_spawnTacticalPair;
    ["Land_Stone_4m_F", -6, 226, 0] call _fnc_spawnTacticalPair;
    ["Land_CncBarrier_stripes_F", 2, 236, 15] call _fnc_spawnTacticalPair;

    // --- SECTOR 7 (Y = 250m - 275m) : CQB Breaching Alley ---
    ["Land_CncBarrier_stripes_F", -7, 255, 0] call _fnc_spawnTacticalPair;
    ["Land_CncBarrier_stripes_F", 6, 264, 0] call _fnc_spawnTacticalPair;
    ["Land_BagFence_Long_F", 0, 274, 0] call _fnc_spawnTacticalPair;

    // --- SECTOR 8 (Y = 285m - 305m) : Northern Command Redoubt ---
    ["Land_BagFence_Long_F", -6, 288, 0] call _fnc_spawnTacticalPair;
    ["Land_BagFence_Long_F", 6, 288, 0] call _fnc_spawnTacticalPair;
    ["Land_BagBunker_Small_F", 0, 298, 180] call _fnc_spawnTacticalPair;
    ["Land_BagFence_Round_F", 0, 296, 180] call _fnc_spawnTacticalPair;

    // --- SPECTATOR OVERHEAD CATWALK AT START LINE ---
    private _tower = createVehicle ["Land_Cargo_Patrol_V1_F", _origin vectorAdd [0, -10, 0], [], 0, "CAN_COLLIDE"];
    _tower setPosATL (_origin vectorAdd [0, -10, 0]);
    _tower setDir 0;
    _props pushBack _tower;

    if (!isNull player) then {
        player setPosATL (_origin vectorAdd [0, -10, 4.5]);
        player setDir 0;
    };

    missionNamespace setVariable ["AAI_BootcampWorldObjects", _props];
    diag_log "[AAI VR Bootcamp] Built 300m x 30m Dual Enclosed Infrastructure with 8 Symmetrical Sectors.";
};

[_origin] call AAI_fnc_build300mCorridors;

// ============================================================================
// 3. Reset & Launch Dual 300m Corridor Trial (Simultaneous Progression)
// ============================================================================
AAI_fnc_resetBootcampTrial = {
    params [["_origin", missionNamespace getVariable ["AAI_BootcampOrigin", [4000, 4000, 0]]]];

    if (!isNil "AAI_FPCam" && {!isNull AAI_FPCam}) then {
        AAI_FPCam cameraEffect ["TERMINATE", "BACK"];
        camDestroy AAI_FPCam;
        AAI_FPCam = nil;
        missionNamespace setVariable ["AAI_CameraModeIndex", 0];
    };

    {
        if (!isNull _x) then { deleteVehicle _x; };
    } forEach (missionNamespace getVariable ["AAI_BootcampActiveUnits", []]);

    private _units = [];

    // Helper to spawn hostile OPFOR targets
    private _fnc_createHostile = {
        params ["_pos", "_dir"];
        private _grp = createGroup [east, true];
        _grp enableAttack false;
        private _unit = _grp createUnit ["O_Soldier_F", _pos, [], 0, "NONE"];
        _unit setPosATL _pos;
        _unit setDir _dir;
        _unit setUnitPos "MIDDLE";
        _unit disableAI "MOVE";
        _unit disableAI "PATH";
        _unit setBehaviour "COMBAT";
        _unit setCombatMode "RED";
        _unit setSkill 0.75;
        _unit setSkill ["aimingAccuracy", 0.10];
        _unit setSkill ["aimingSpeed", 0.40];
        _units pushBack _unit;
        _unit
    };

    // =========================================================================
    // HOSTILE DEFENDERS IN CORRIDOR 1 (LEFT, X = -20m)
    // =========================================================================
    private _sentry1 = [_origin vectorAdd [-20, 151.5, 0], 180] call _fnc_createHostile;
    private _commander1 = [_origin vectorAdd [-20, 297.5, 0], 180] call _fnc_createHostile;

    // =========================================================================
    // HOSTILE DEFENDERS IN CORRIDOR 2 (RIGHT, X = +20m)
    // =========================================================================
    private _sentry2 = [_origin vectorAdd [20, 151.5, 0], 180] call _fnc_createHostile;
    private _commander2 = [_origin vectorAdd [20, 297.5, 0], 180] call _fnc_createHostile;

    // =========================================================================
    // SPAWN BLUE RUNNER 1: VANILLA ARMA 3 AI (CORRIDOR 1, X = -20m, Y = 2m)
    // =========================================================================
    private _grpVanilla = createGroup [west, true];
    _grpVanilla enableAttack false;
    private _vanillaRunner = _grpVanilla createUnit ["B_Soldier_F", _origin vectorAdd [-20, 2, 0], [], 0, "NONE"];
    _vanillaRunner setPosATL (_origin vectorAdd [-20, 2, 0]);
    _vanillaRunner setDir 0;
    _vanillaRunner setSkill 0.95;
    _vanillaRunner setBehaviour "AWARE";
    _vanillaRunner setCombatMode "RED";
    _vanillaRunner setSpeedMode "FULL";
    _vanillaRunner disableAI "AUTOCOMBAT";
    _vanillaRunner setVariable ["AAI_Callsign", "VANILLA RUNNER (Couloir 1)"];

    _vanillaRunner addEventHandler ["HandleDamage", {
        params ["_unit", "_selection", "_damage"];
        private _cur = damage _unit;
        (_cur + 0.02) min 0.95
    }];
    _units pushBack _vanillaRunner;

    // =========================================================================
    // SPAWN BLUE RUNNER 2: TICO SEMANTIC AFFORDANCE AI (CORRIDOR 2, X = +20m, Y = 2m)
    // =========================================================================
    private _grpSemantic = createGroup [west, true];
    _grpSemantic enableAttack false;
    private _semanticRunner = _grpSemantic createUnit ["B_Soldier_F", _origin vectorAdd [20, 2, 0], [], 0, "NONE"];
    _semanticRunner setPosATL (_origin vectorAdd [20, 2, 0]);
    _semanticRunner setDir 0;
    _semanticRunner setSkill 0.95;
    _semanticRunner setBehaviour "AWARE";
    _semanticRunner setCombatMode "RED";
    _semanticRunner setSpeedMode "FULL";
    _semanticRunner disableAI "AUTOCOMBAT";
    _semanticRunner disableAI "COVER";
    _semanticRunner disableAI "SUPPRESSION";
    _semanticRunner disableConversation true;
    _semanticRunner setVariable ["AAI_Callsign", "TICO SEMANTIC RUNNER (Couloir 2)"];
    _semanticRunner setVariable ["AAI_TacticalRole", "Rifleman"];
    _semanticRunner setVariable ["AAI_TacticalObjective", getPosATL _sentry2];
    _semanticRunner setVariable ["AAI_TacticalCorridorCenter", _origin vectorAdd [20, 80, 0]];
    _semanticRunner setVariable ["AAI_TacticalCorridorWidth", 14.0]; // 30m width -> 14m half-width

    _semanticRunner addEventHandler ["HandleDamage", {
        params ["_unit", "_selection", "_damage"];
        private _cur = damage _unit;
        (_cur + 0.02) min 0.95
    }];
    _units pushBack _semanticRunner;

    missionNamespace setVariable ["AAI_VanillaRunner", _vanillaRunner];
    missionNamespace setVariable ["AAI_SemanticRunner", _semanticRunner];
    missionNamespace setVariable ["AAI_Sentry1", _sentry1];
    missionNamespace setVariable ["AAI_Commander1", _commander1];
    missionNamespace setVariable ["AAI_Sentry2", _sentry2];
    missionNamespace setVariable ["AAI_Commander2", _commander2];
    missionNamespace setVariable ["AAI_BootcampActiveUnits", _units];
    missionNamespace setVariable ["AAI_TrialStartTime", time];

    _vanillaRunner reveal [_sentry1, 4];
    _sentry1 reveal [_vanillaRunner, 4];

    _semanticRunner reveal [_sentry2, 4];
    _sentry2 reveal [_semanticRunner, 4];

    // =========================================================================
    // LAUNCH VANILLA RUNNER TWO-STAGE ADVANCE LOOP (CORRIDOR 1)
    // =========================================================================
    [_vanillaRunner, _sentry1, _commander1] spawn {
        params ["_u", "_target1", "_target2"];
        sleep 0.5;
        _u doMove (getPosATL _target1);

        // Stage 1: Advance to eliminate Sentry 1 at 150m
        while {alive _u && {alive _target1}} do {
            sleep 0.8;
            if (alive _u && {alive _target1} && {_u distance2D _target1 > 3.0} && {speed _u < 0.4}) then {
                _u doMove (getPosATL _target1);
            };
        };

        if (alive _u && {!alive _target1}) then {
            systemChat "[COULOIR 1 - VANILLA] Sentry 1 Neutralisee a 150m ! Avance vers le Commandant a 295m...";
            _u reveal [_target2, 4];
            _target2 reveal [_u, 4];
            _u doMove (getPosATL _target2);

            // Stage 2: Advance to eliminate Commander 2 at 295m
            while {alive _u && {alive _target2}} do {
                sleep 0.8;
                if (alive _u && {alive _target2} && {_u distance2D _target2 > 3.0} && {speed _u < 0.4}) then {
                    _u doMove (getPosATL _target2);
                };
            };

            if (!alive _target2) then {
                systemChat "[COULOIR 1 - VANILLA] OBJECTIF FINAL DETRUIT a 295m !";
            };
        };
    };

    // =========================================================================
    // LAUNCH TICO SEMANTIC AGENT CONTROLLER (CORRIDOR 2)
    // =========================================================================
    // Start autonomous TICO semantic decision loop
    [_semanticRunner, _sentry2, 0.30] spawn AAI_fnc_startAgentController;

    // Two-stage objective manager for Semantic AI
    [_semanticRunner, _sentry2, _commander2, _origin] spawn {
        params ["_u", "_sentry", "_commander", "_origin"];

        waitUntil {!alive _sentry || {!alive _u}};
        if (alive _u && {!alive _sentry}) then {
            systemChat "[COULOIR 2 - SEMANTIQUE] Sentry 1 Neutralisee a 150m ! Reorientation vers le Redoubt a 295m...";
            _u setVariable ["AAI_TacticalObjective", getPosATL _commander];
            _u setVariable ["AAI_TacticalCorridorCenter", _origin vectorAdd [20, 220, 0]];
            _u reveal [_commander, 4];
            _commander reveal [_u, 4];

            // Relaunch controller against Commander 2
            [_u, _commander, 0.35] spawn AAI_fnc_startAgentController;

            waitUntil {!alive _commander || {!alive _u}};
            if (!alive _commander) then {
                systemChat "[COULOIR 2 - SEMANTIQUE] VICTOIRE ! Redoubt de commandement neutralise a 295m avec preservation d'abris !";
            };
        };
    };

    // 3D Overlay setup
    if (missionNamespace getVariable ["AAI_3DOverlayActive", true]) then {
        [true, _semanticRunner] call AAI_fnc_drawTacticalOverlay;
    };

    systemChat "[BOOTCAMP 300M] Course d'assaut lancee ! Les deux IA progressent simultanement sur 300 metres.";
};

call AAI_fnc_resetBootcampTrial;

// ============================================================================
// 4. First-Person AI Eyes Camera (Key: F2)
// ============================================================================
AAI_fnc_cycleCameraView = {
    private _currentMode = missionNamespace getVariable ["AAI_CameraModeIndex", 0];
    private _nextMode = (_currentMode + 1) % 3;
    missionNamespace setVariable ["AAI_CameraModeIndex", _nextMode];

    private _semanticRunner = missionNamespace getVariable ["AAI_SemanticRunner", objNull];
    private _vanillaRunner = missionNamespace getVariable ["AAI_VanillaRunner", objNull];

    if (!isNil "AAI_FPCam" && {!isNull AAI_FPCam}) then {
        AAI_FPCam cameraEffect ["TERMINATE", "BACK"];
        camDestroy AAI_FPCam;
        AAI_FPCam = nil;
    };

    switch (_nextMode) do {
        case 0: {
            (vehicle player) switchCamera "INTERNAL";
            systemChat "[CAMERA] Mode: GHOST INSTRUCTOR (Libre / Vue d'ensemble).";
        };
        case 1: {
            if (!isNull _semanticRunner && {alive _semanticRunner}) then {
                AAI_FPCam = "camera" camCreate (eyePos _semanticRunner);
                AAI_FPCam cameraEffect ["INTERNAL", "BACK"];
                AAI_FPCam attachTo [_semanticRunner, [0, 0.12, 0.08], "head"];
                systemChat "[CAMERA] Mode: YEUX IA SEMANTIQUE (Couloir 2).";
            } else {
                systemChat "[CAMERA] IA Semantique indisponible.";
                missionNamespace setVariable ["AAI_CameraModeIndex", 0];
            };
        };
        case 2: {
            if (!isNull _vanillaRunner && {alive _vanillaRunner}) then {
                AAI_FPCam = "camera" camCreate (eyePos _vanillaRunner);
                AAI_FPCam cameraEffect ["INTERNAL", "BACK"];
                AAI_FPCam attachTo [_vanillaRunner, [0, 0.12, 0.08], "head"];
                systemChat "[CAMERA] Mode: YEUX IA VANILLA (Couloir 1).";
            } else {
                systemChat "[CAMERA] IA Vanilla indisponible.";
                missionNamespace setVariable ["AAI_CameraModeIndex", 0];
            };
        };
    };
};

// ============================================================================
// 5. 3D Tactical Overlay Toggle (Key: F3)
// ============================================================================
AAI_fnc_toggle3DOverlay = {
    private _isActive = missionNamespace getVariable ["AAI_3DOverlayActive", true];
    _isActive = !_isActive;
    missionNamespace setVariable ["AAI_3DOverlayActive", _isActive];

    if (_isActive) then {
        private _semanticRunner = missionNamespace getVariable ["AAI_SemanticRunner", objNull];
        [true, _semanticRunner] call AAI_fnc_drawTacticalOverlay;
        systemChat "[3D OVERLAY] Active.";
    } else {
        [false] call AAI_fnc_drawTacticalOverlay;
        systemChat "[3D OVERLAY] Desactive.";
    };
};

// ============================================================================
// 6. Zeus (Curator) Logic & Interactive RTS Controls
// ============================================================================
if (hasInterface) then {
    [] spawn {
        waitUntil {!isNull player && {alive player}};
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

        while {true} do {
            sleep 2.5;
            if (!isNull _curator) then {
                _curator addCuratorEditableObjects [allUnits + vehicles + (allMissionObjects "All"), true];
            };
        };
    };
};

// ============================================================================
// 7. Real-Time Benchmark Telemetry HUD Loop (300m Scale)
// ============================================================================
[] spawn {
    while {true} do {
        sleep 0.25;

        private _origin = missionNamespace getVariable ["AAI_BootcampOrigin", [4000, 4000, 0]];
        private _vanilla = missionNamespace getVariable ["AAI_VanillaRunner", objNull];
        private _semantic = missionNamespace getVariable ["AAI_SemanticRunner", objNull];
        private _sentry1 = missionNamespace getVariable ["AAI_Sentry1", objNull];
        private _sentry2 = missionNamespace getVariable ["AAI_Sentry2", objNull];
        private _comm1 = missionNamespace getVariable ["AAI_Commander1", objNull];
        private _comm2 = missionNamespace getVariable ["AAI_Commander2", objNull];

        private _vAlive = (!isNull _vanilla && {alive _vanilla});
        private _sAlive = (!isNull _semantic && {alive _semantic});

        private _vHealth = if (_vAlive) then { round ((1 - damage _vanilla) * 100) } else { 0 };
        private _sHealth = if (_sAlive) then { round ((1 - damage _semantic) * 100) } else { 0 };

        private _vY = if (_vAlive) then { round ((getPosATL _vanilla select 1) - (_origin select 1)) } else { 0 };
        private _sY = if (_sAlive) then { round ((getPosATL _semantic select 1) - (_origin select 1)) } else { 0 };

        private _s1Alive = (!isNull _sentry1 && {alive _sentry1});
        private _s2Alive = (!isNull _sentry2 && {alive _sentry2});
        private _c1Alive = (!isNull _comm1 && {alive _comm1});
        private _c2Alive = (!isNull _comm2 && {alive _comm2});

        private _vTargetStr = if (_s1Alive) then { format ["Sentry 1 (150m) | Y=%1m", _vY] } else { if (_c1Alive) then { format ["Final Redoubt (295m) | Y=%1m", _vY] } else { "<t color='#00ff88'>COMPLETE !</t>" } };
        private _sTargetStr = if (_s2Alive) then { format ["Sentry 1 (150m) | Y=%1m", _sY] } else { if (_c2Alive) then { format ["Final Redoubt (295m) | Y=%1m", _sY] } else { "<t color='#00ff88'>COMPLETE !</t>" } };

        private _sState = if (_sAlive) then { _semantic getVariable ["AAI_TacticalState", "IDLE"] } else { "DEAD" };
        private _sAffordance = if (_sAlive) then { _semantic getVariable ["AAI_TargetAffordance", createHashMap] } else { createHashMap };
        private _sAffName = _sAffordance getOrDefault ["stanceName", "N/A"];
        private _sCost = if (_sAlive) then { (_semantic getVariable ["AAI_TargetCover", createHashMap]) getOrDefault ["costScore", 0] } else { 0 };

        private _camMode = missionNamespace getVariable ["AAI_CameraModeIndex", 0];
        private _camName = switch (_camMode) do {
            case 0: { "Ghost Instructor (Libre)" };
            case 1: { "Yeux Semantique (Couloir 2)" };
            case 2: { "Yeux Vanilla (Couloir 1)" };
            default { "Ghost" };
        };

        private _vColor = if (_vHealth > 50) then { "#33ff33" } else { if (_vHealth > 0) then { "#ff9900" } else { "#ff2222" } };
        private _sColor = if (_sHealth > 50) then { "#33ff33" } else { if (_sHealth > 0) then { "#ff9900" } else { "#ff2222" } };

        hintSilent parseText format [
            "<t color='#00ffcc' size='1.15' font='PuristaBold'>[BENCHMARK 300M DUAL COULOIRS]</t><br/>" +
            "<t color='#aaaaaa' size='0.85'>Vue :</t> <t color='#ffff00'>%9</t><br/><br/>" +

            "<t color='#ff6666' size='1.05' font='PuristaBold'>COULOIR 1 : IA VANILLA (30m Large)</t><br/>" +
            "Sante : <t color='%1'>%2%10</t> | Cible : <t color='#ffffff'>%11</t><br/>" +
            "Comportement : <t color='#ff4444'>Course decouverte</t><br/><br/>" +

            "<t color='#33ccff' size='1.05' font='PuristaBold'>COULOIR 2 : IA SEMANTIQUE (30m Large)</t><br/>" +
            "Sante : <t color='%4'>%5%10</t> | Cible : <t color='#ffffff'>%12</t><br/>" +
            "Abri : <t color='#00ff88'>%7</t> (J: %8) | %13<br/><br/>" +

            "<t color='#888888' size='0.8'>Raccourcis : <t color='#ffff00'>F1</t> Reset | <t color='#ffff00'>F2</t> Yeux IA | <t color='#ffff00'>F3</t> 3D | <t color='#ffff00'>Y/Z</t> Zeus</t>",
            _vColor, _vHealth, "",
            _sColor, _sHealth, "",
            _sAffName, (if (_sCost isEqualType 0 && {finite _sCost}) then { _sCost toFixed 1 } else { "N/A" }),
            _camName, "%", _vTargetStr, _sTargetStr, _sState
        ];
    };
};

// ============================================================================
// 8. Key Handlers (Display 46 and 312)
// ============================================================================
[] spawn {
    waitUntil {!isNull (findDisplay 46)};
    (findDisplay 46) displayAddEventHandler ["KeyDown", {
        params ["_disp", "_key"];

        // F1 (59): Reset Benchmark Trial
        if (_key == 59) exitWith { call AAI_fnc_resetBootcampTrial; true };

        // F2 (60): Cycle Camera Mode
        if (_key == 60) exitWith { call AAI_fnc_cycleCameraView; true };

        // F3 (61): Toggle 3D Affordance Visualizer
        if (_key == 61) exitWith { call AAI_fnc_toggle3DOverlay; true };

        // Y (21) / Z (44): Toggle Zeus Interface
        if (_key in [21, 44]) exitWith {
            if (isNull (findDisplay 312)) then { openCuratorInterface; } else { (findDisplay 312) closeDisplay 1; };
            true
        };

        false
    }];

    while {true} do {
        waitUntil {!isNull (findDisplay 312)};
        private _zDisp = findDisplay 312;
        _zDisp displayAddEventHandler ["KeyDown", {
            params ["_disp", "_key"];
            if (_key == 59) exitWith { call AAI_fnc_resetBootcampTrial; true };
            if (_key == 60) exitWith { call AAI_fnc_cycleCameraView; true };
            if (_key == 61) exitWith { call AAI_fnc_toggle3DOverlay; true };
            if (_key in [1, 14, 21, 44]) exitWith { _disp closeDisplay 1; true };
            false
        }];
        waitUntil {isNull (findDisplay 312)};
    };
};

// ============================================================================
// 9. Player Action Menu
// ============================================================================
if (!isNull player) then {
    player addAction ["<t color='#ffff00' size='1.2'>[BOOTCAMP 300M] RELANCER L'EPREUVE (F1)</t>", {
        call AAI_fnc_resetBootcampTrial;
    }, nil, 3.0, false, false, "", "true", 50];

    player addAction ["<t color='#00ffcc' size='1.2'>[CAMERA] YEUX DE L'IA (F2)</t>", {
        call AAI_fnc_cycleCameraView;
    }, nil, 2.9, false, false, "", "true", 50];

    player addAction ["<t color='#33ffaa' size='1.1'>[3D] VISUALISEUR D'ABRIS (F3)</t>", {
        call AAI_fnc_toggle3DOverlay;
    }, nil, 2.8, false, false, "", "true", 50];

    player addAction ["<t color='#ffcc00' size='1.2'>[ZEUS] VUE AERIENNE RTS (Y / Z)</t>", {
        if (isNull (findDisplay 312)) then { openCuratorInterface; } else { (findDisplay 312) closeDisplay 1; };
    }, nil, 2.7, false, false, "", "true", 50];
};

diag_log "[AAI VR Bootcamp] 300m x 30m Dual Corridors Initialized Successfully.";
