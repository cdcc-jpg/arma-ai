/*
    Author: Clement D. / Arma-AI Team
    Mission: Georgetown: TICO Semantic AI Trinome Benchmark (Tanoa)
    File: init.sqf

    Description:
        Urban tactical benchmark in the colonial street grid of Georgetown, Tanoa.
        BLUFOR 3-man fireteam (Trinome: Pointman + Autorifleman + Marksman) operated
        by the TICO Spatial Affordance AI engine with mutual overwatch, CQB corner pieing,
        and high-ground / standoff sniper positioning.
        Strict parity with the Vanilla benchmark mission.
        8 OPFOR defensive ambush targets stationed along the ~325m urban avenue.
        Calibrated tactical survivability damage model (100 HP per soldier).
*/

diag_log "[AAI Benchmark Georgetown] Initializing TICO Semantic AI Trinome Benchmark on Tanoa...";

// Enable simulation and disable savegames
enableSaving [false, false];

// ============================================================================
// 1. Mission Coordinates & 8 Fixed Urban Avenue Targets (Georgetown, Tanoa)
// ============================================================================
// Sector: Southern Avenue to Northern Harbor District (Georgetown)
// 100% natural map architecture (colonial masonry, shopfronts, concrete walls). Zero added props.
private _bluforLeadSpawnPos  = [5752, 10115, 0];   // East alley entrance (Pointman aligned with Target 1 corridor)
private _bluforWing1SpawnPos = [5748, 10110, 0];   // Staggered behind/left (Autorifleman)
private _bluforWing2SpawnPos = [5755, 10108, 0];   // Staggered behind/right (Marksman)
private _spectatorPos        = [5745, 10100, 9.5]; // Elevated vantage overlooking southern alley entrance

private _targetsConfig = [
    [[5755, 10195, 0], 195, "1. Entree Carrefour Sud (~68m)"],
    [[5778, 10228, 0], 205, "2. Angle Magasins Est (~108m)"],
    [[5758, 10265, 0], 190, "3. Arcades Marche Couvert (~145m)"],
    [[5735, 10298, 0], 175, "4. Cour Interieure Ouest (~182m)"],
    [[5752, 10332, 0], 190, "5. Angle Hotel Colonial (~218m)"],
    [[5782, 10360, 0], 210, "6. Barricade Carrefour Nord (~252m)"],
    [[5762, 10395, 0], 185, "7. Rue des Quais (~288m)"],
    [[5728, 10425, 0], 160, "8. Redoute Portuaire (~325m)"]
];

missionNamespace setVariable ["AAI_BluforLeadSpawnPos", _bluforLeadSpawnPos];
missionNamespace setVariable ["AAI_BluforWing1SpawnPos", _bluforWing1SpawnPos];
missionNamespace setVariable ["AAI_BluforWing2SpawnPos", _bluforWing2SpawnPos];
missionNamespace setVariable ["AAI_SpectatorPos", _spectatorPos];
missionNamespace setVariable ["AAI_TargetsConfig", _targetsConfig];

// ============================================================================
// 2. Spectator Ghost Instructor Setup
// ============================================================================
if (hasInterface) then {
    [] spawn {
        waitUntil {!isNull player && {alive player}};
        player allowDamage false;
        player setCaptive true;
        player hideObjectGlobal true;
        player setPosATL [5745, 10100, 9.5];
        player setDir 15;
    };
};

// Helper to hot-reload live controller functions without needing Eden restart
AAI_fnc_compileLiveControllers = {
    if (fileExists "src\controller_live\fn_tacticalTick.sqf") then {
        AAI_fnc_tacticalTick = compile preprocessFileLineNumbers "src\controller_live\fn_tacticalTick.sqf";
        AAI_fnc_executeMovement = compile preprocessFileLineNumbers "src\controller_live\fn_executeMovement.sqf";
        AAI_fnc_startAgentController = compile preprocessFileLineNumbers "src\controller_live\fn_startAgentController.sqf";
        AAI_fnc_tacticalRadio = compile preprocessFileLineNumbers "src\controller_live\fn_tacticalRadio.sqf";
        AAI_fnc_updateKnowledgeGraph = compile preprocessFileLineNumbers "src\controller_live\fn_updateKnowledgeGraph.sqf";
        diag_log "[AAI Hot-Reload] Successfully loaded live controller functions from src\controller_live\";
    };
};
call AAI_fnc_compileLiveControllers;

// ============================================================================
// 3. Reset & Launch Benchmark Trial Function
// ============================================================================
AAI_fnc_resetBenchmarkTrial = {
    // Re-compile latest controller functions on each trial reset
    call AAI_fnc_compileLiveControllers;

    // Reset camera if active
    if (!isNil "AAI_FPCam" && {!isNull AAI_FPCam}) then {
        AAI_FPCam cameraEffect ["TERMINATE", "BACK"];
        camDestroy AAI_FPCam;
        AAI_FPCam = nil;
        missionNamespace setVariable ["AAI_CameraModeIndex", 0];
    };

    // Clean up previous active units
    {
        if (!isNull _x) then { deleteVehicle _x; };
    } forEach (missionNamespace getVariable ["AAI_ActiveUnits", []]);

    private _units = [];
    private _leadSpawn  = missionNamespace getVariable ["AAI_BluforLeadSpawnPos", [5752, 10115, 0]];
    private _wing1Spawn = missionNamespace getVariable ["AAI_BluforWing1SpawnPos", [5748, 10110, 0]];
    private _wing2Spawn = missionNamespace getVariable ["AAI_BluforWing2SpawnPos", [5755, 10108, 0]];
    private _targetsConfig = missionNamespace getVariable ["AAI_TargetsConfig", []];

    // Helper to spawn hostile OPFOR defenders in natural village cover
    private _fnc_createHostile = {
        params ["_pos", "_dir", "_callsign"];
        private _grp = createGroup [east, true];
        _grp enableAttack false;
        private _unit = _grp createUnit ["O_T_Soldier_F", _pos, [], 0, "NONE"];
        _unit setPosATL _pos;
        _unit setDir _dir;
        _unit setSkill 0.35;
        _unit setSkill ["aimingAccuracy", 0.18];
        _unit setSkill ["aimingSpeed", 0.25];
        _unit setSkill ["aimingShake", 0.40];
        _unit setSkill ["spotDistance", 0.60];
        _unit setSkill ["spotTime", 0.45];
        _unit setSkill ["courage", 0.70];
        _unit setUnitPos "MIDDLE";
        _unit setBehaviour "COMBAT";
        _unit setCombatMode "RED";
        _unit disableAI "PATH"; // Stationary defensive ambush
        _unit setVariable ["AAI_TargetName", _callsign];
        _unit
    };

    // Calibrated damage model (250 HP with body armor dampening for BLUFOR, 100 HP for OPFOR)
    private _fnc_applyDamageModel = {
        params ["_unit"];
        private _isWest = (side _unit == west);
        private _initialHP = if (_isWest) then { 250 } else { 100 };
        _unit setVariable ["AAI_HealthPoints", _initialHP];
        _unit setVariable ["AAI_MaxHealthPoints", _initialHP];
        _unit removeAllEventHandlers "HandleDamage";
        _unit addEventHandler ["HandleDamage", {
            params ["_unit", "_selection", "_damage", "_source", "_projectile", "_hitIndex", "_instigator", "_hitPoint"];
            if (!alive _unit) exitWith { _damage };

            private _isBlufor = (side _unit == west);
            private _maxHP = _unit getVariable ["AAI_MaxHealthPoints", if (_isBlufor) then { 250 } else { 100 }];
            private _oldHP = _unit getVariable ["AAI_HealthPoints", _maxHP];
            private _hpLoss = if (_isBlufor) then {
                // BLUFOR: reinforced body armor / ballistic vest mitigation
                switch (_selection) do {
                    case "head":       { (_damage * 22.0) min 45.0 };
                    case "spine3";
                    case "body":       { (_damage * 12.0) min 25.0 };
                    case "hands";
                    case "legs":       { (_damage * 6.0) min 12.0 };
                    default            { (_damage * 10.0) min 20.0 };
                };
            } else {
                // OPFOR: standard unarmored militia profile (drops in 2-3 hits)
                switch (_selection) do {
                    case "head":       { (_damage * 55.0) min 100.0 };
                    case "spine3";
                    case "body":       { (_damage * 32.0) min 50.0 };
                    case "hands";
                    case "legs":       { (_damage * 14.0) min 25.0 };
                    default            { (_damage * 20.0) min 35.0 };
                };
            };

            private _newHP = (_oldHP - _hpLoss) max 0;
            _unit setVariable ["AAI_HealthPoints", _newHP];

            if (_newHP <= 0) then {
                _unit setDamage 1;
                1
            } else {
                0
            };
        }];
    };

    // Spawn 8 OPFOR Defenders in natural Georgetown cover
    private _spawnedTargets = [];
    private _targetPositions = [];
    {
        _x params ["_pos", "_dir", "_name"];
        private _opforUnit = [_pos, _dir, _name] call _fnc_createHostile;
        [_opforUnit] call _fnc_applyDamageModel;
        _spawnedTargets pushBack _opforUnit;
        _targetPositions pushBack _pos;
        _units pushBack _opforUnit;
    } forEach _targetsConfig;

    // =========================================================================
    // SPAWN BLUFOR TRINOME (Pointman + Autorifleman + Marksman)
    // =========================================================================
    private _grpBlufor = createGroup [west, true];
    _grpBlufor enableAttack false;

    // 1. Pointman / Team Leader (Ouvreur)
    private _safeLead = _leadSpawn findEmptyPosition [0, 8, "B_T_Soldier_TL_F"];
    if (count _safeLead == 0) then { _safeLead = _leadSpawn; };
    private _lead = _grpBlufor createUnit ["B_T_Soldier_TL_F", _safeLead, [], 0, "NONE"];
    _lead setPosATL _safeLead;
    _lead setDir 15;
    _lead setSkill 0.95;
    _lead setBehaviour "AWARE";
    _lead setCombatMode "RED";
    _lead setSpeedMode "FULL";
    _lead forceSpeed 15;
    _lead setUnitPos "UP";
    _lead disableAI "AUTOCOMBAT";
    _lead disableAI "COVER";
    _lead disableAI "SUPPRESSION";
    _lead disableConversation true;
    _lead setVariable ["AAI_Callsign", "TICO POINTMAN [LEAD]"];
    _lead setVariable ["AAI_TacticalRole", "Rifleman"];
    _lead setVariable ["AAI_PairRole", "MANEUVER"];
    _lead setVariable ["AAI_TacticalObjective", _targetPositions select 0];
    _lead setVariable ["AAI_CurrentTargetIndex", 1];
    [_lead] call _fnc_applyDamageModel;
    _units pushBack _lead;

    // 2. Wingman 1 / Support (Mitrailleur d'Appui)
    private _safeWing1 = _wing1Spawn findEmptyPosition [0, 8, "B_T_Soldier_AR_F"];
    if (count _safeWing1 == 0) then { _safeWing1 = _wing1Spawn; };
    private _wing1 = _grpBlufor createUnit ["B_T_Soldier_AR_F", _safeWing1, [], 0, "NONE"];
    _wing1 setPosATL _safeWing1;
    _wing1 setDir 15;
    _wing1 setSkill 0.95;
    _wing1 setBehaviour "AWARE";
    _wing1 setCombatMode "RED";
    _wing1 setSpeedMode "FULL";
    _wing1 forceSpeed 15;
    _wing1 setUnitPos "UP";
    _wing1 disableAI "AUTOCOMBAT";
    _wing1 disableAI "COVER";
    _wing1 disableAI "SUPPRESSION";
    _wing1 disableConversation true;
    _wing1 setVariable ["AAI_Callsign", "TICO APPUI [AR]"];
    _wing1 setVariable ["AAI_TacticalRole", "Autorifleman"];
    _wing1 setVariable ["AAI_PairRole", "BASE_OF_FIRE"];
    _wing1 setVariable ["AAI_TacticalObjective", _targetPositions select 0];
    _wing1 setVariable ["AAI_CurrentTargetIndex", 1];
    [_wing1] call _fnc_applyDamageModel;
    _units pushBack _wing1;

    // 3. Wingman 2 / Marksman (Tireur de Precision)
    private _safeWing2 = _wing2Spawn findEmptyPosition [0, 8, "B_T_Soldier_M_F"];
    if (count _safeWing2 == 0) then { _safeWing2 = _wing2Spawn; };
    private _wing2 = _grpBlufor createUnit ["B_T_Soldier_M_F", _safeWing2, [], 0, "NONE"];
    _wing2 setPosATL _safeWing2;
    _wing2 setDir 15;
    _wing2 setSkill 0.95;
    _wing2 setBehaviour "AWARE";
    _wing2 setCombatMode "RED";
    _wing2 setSpeedMode "FULL";
    _wing2 forceSpeed 15;
    _wing2 setUnitPos "UP";
    _wing2 disableAI "AUTOCOMBAT";
    _wing2 disableAI "COVER";
    _wing2 disableAI "SUPPRESSION";
    _wing2 disableConversation true;
    _wing2 setVariable ["AAI_Callsign", "TICO TIREUR [PRECISION]"];
    _wing2 setVariable ["AAI_TacticalRole", "Marksman"];
    _wing2 setVariable ["AAI_PairRole", "FLANK_OVERWATCH"];
    _wing2 setVariable ["AAI_TacticalObjective", _targetPositions select 0];
    _wing2 setVariable ["AAI_CurrentTargetIndex", 1];
    [_wing2] call _fnc_applyDamageModel;
    _units pushBack _wing2;

    // Mutual Links
    _grpBlufor selectLeader _lead;
    _lead setVariable ["AAI_BuddyUnit", _wing1];
    _wing1 setVariable ["AAI_BuddyUnit", _lead];
    _wing2 setVariable ["AAI_BuddyUnit", _lead];

    missionNamespace setVariable ["AAI_ActiveUnits", _units];
    missionNamespace setVariable ["AAI_BluforLead", _lead];
    missionNamespace setVariable ["AAI_BluforWing1", _wing1];
    missionNamespace setVariable ["AAI_BluforWing2", _wing2];
    missionNamespace setVariable ["AAI_Targets", _spawnedTargets];
    missionNamespace setVariable ["AAI_TargetPositions", _targetPositions];
    missionNamespace setVariable ["AAI_TargetsKilledCount", 0];
    missionNamespace setVariable ["AAI_TrialStartTime", time];

    // =========================================================================
    // START TICO SEMANTIC AGENT CONTROLLERS (Trinome CQB Loop)
    // =========================================================================
    [_lead, objNull, 0.28] spawn AAI_fnc_startAgentController;
    sleep 0.10;
    [_wing1, objNull, 0.28] spawn AAI_fnc_startAgentController;
    sleep 0.10;
    [_wing2, objNull, 0.28] spawn AAI_fnc_startAgentController;

    // Multi-stage urban objective coordinator through the 8 natural avenue targets
    [_lead, _wing1, _wing2, _spawnedTargets, _targetPositions] spawn {
        params ["_lead", "_wing1", "_wing2", "_targets", "_positions"];

        for "_i" from 0 to ((count _targets) - 1) do {
            private _currentTarget = _targets select _i;
            private _currentPos = _positions select _i;
            private _targetNum = _i + 1;
            private _callsign = _currentTarget getVariable ["AAI_TargetName", format ["Cible %1", _targetNum]];

            {
                if (alive _x) then {
                    _x setVariable ["AAI_TacticalObjective", _currentPos];
                    _x setVariable ["AAI_CurrentTargetIndex", _targetNum];
                    _x setVariable ["AAI_CoverArrivalTime", 0];
                    _x setVariable ["AAI_VisitedCoverPoints", []];
                    _x setVariable ["AAI_RecentCoverHistory", []];
                    _x setVariable ["AAI_MinDistToObjective", 9999];
                };
            } forEach [_lead, _wing1, _wing2];

            systemChat format ["[GEORGETOWN - SEMANTIQUE] Trinome en progression vers %1...", _callsign];

            // Wait until this target is killed, or dominated in close quarters (< 6.0m), or all BLUFOR die
            waitUntil {
                !alive _currentTarget 
                || {(!alive _lead && {!alive _wing1} && {!alive _wing2})}
                || {(alive _lead && {_lead distance2D _currentPos < 6.0})}
                || {(alive _wing1 && {_wing1 distance2D _currentPos < 6.0})}
                || {(alive _wing2 && {_wing2 distance2D _currentPos < 6.0})}
            };

            if (!alive _lead && {!alive _wing1} && {!alive _wing2}) exitWith {
                systemChat format ["[GEORGETOWN - SEMANTIQUE] ECHEC ! Le trinome BLUFOR a ete elimine a la cible %1 (%2/8 neutralisees).", _targetNum, _i];
                diag_log format ["[GEORGETOWN - SEMANTIQUE] ECHEC ! Le trinome BLUFOR a ete elimine a la cible %1 (%2/8 neutralisees).", _targetNum, _i];
            };

            // Close-quarters domination fallback: neutralize bypassed or hidden target to eliminate deadlocks
            if (alive _currentTarget && {
                (alive _lead && {_lead distance2D _currentPos < 6.5}) 
                || (alive _wing1 && {_wing1 distance2D _currentPos < 6.5})
                || (alive _wing2 && {_wing2 distance2D _currentPos < 6.5})
            }) then {
                _currentTarget setDamage 1;
            };

            if (!alive _lead) then {
                private _survivors = [_wing1, _wing2] select { alive _x };
                if (count _survivors > 0) then {
                    private _newLeader = _survivors select 0;
                    (group _newLeader) selectLeader _newLeader;
                };
            };

            missionNamespace setVariable ["AAI_TargetsKilledCount", _targetNum];
            systemChat format ["[GEORGETOWN - SEMANTIQUE] %1 neutralisee ! (%2/8 terminees)", _callsign, _targetNum];
            diag_log format ["[GEORGETOWN - SEMANTIQUE] %1 neutralisee ! (%2/8 terminees)", _callsign, _targetNum];
            sleep 0.4;
        };

        if (alive _lead || alive _wing1 || alive _wing2) then {
            private _hpLead  = if (alive _lead)  then { round (_lead  getVariable ["AAI_HealthPoints", 0]) } else { 0 };
            private _hpWing1 = if (alive _wing1) then { round (_wing1 getVariable ["AAI_HealthPoints", 0]) } else { 0 };
            private _hpWing2 = if (alive _wing2) then { round (_wing2 getVariable ["AAI_HealthPoints", 0]) } else { 0 };
            systemChat format ["[GEORGETOWN - SEMANTIQUE] VICTOIRE DU TRINOME ! Les 8 cibles ont ete neutralisees ! (Lead: %1/250 HP, AR: %2/250 HP, Marks: %3/250 HP)", _hpLead, _hpWing1, _hpWing2];
        };
    };

    // High-Resolution 2D Timeline Trajectory Logger for Post-Mission Animation
    [_lead, _wing1, _wing2, _spawnedTargets, _targetPositions] spawn {
        params ["_lead", "_wing1", "_wing2", "_targets", "_positions"];
        private _t0 = time;
        diag_log format ["[BENCHMARK_TRACK_INIT] mission=SEMANTIC;blufor=[%1,%2,%3];targets=%4",
            getPosATL _lead, getPosATL _wing1, getPosATL _wing2, _positions
        ];

        while {({alive _x} count [_lead, _wing1, _wing2] > 0) && {({alive _x} count _targets > 0)}} do {
            private _elapsed = round ((time - _t0) * 10) / 10;
            
            // Log BLUFOR units
            {
                if (!isNull _x && {alive _x}) then {
                    private _p = getPosATL _x;
                    private _st = _x getVariable ["AAI_TacticalState", "MOVE"];
                    private _role = _x getVariable ["AAI_TacticalRole", "Soldier"];
                    private _hp = round (_x getVariable ["AAI_HealthPoints", 250]);
                    private _tgtIdx = _x getVariable ["AAI_CurrentTargetIndex", 1];
                    diag_log format ["[TRACK_BLUFOR] mode=SEMANTIC;t=%1;id=%2;role=%3;x=%4;y=%5;dir=%6;spd=%7;stc=%8;hp=%9;state=%10;tgt=%11",
                        _elapsed, _forEachIndex, _role,
                        (round ((_p select 0) * 10) / 10),
                        (round ((_p select 1) * 10) / 10),
                        round (getDir _x),
                        round (speed _x),
                        stance _x,
                        _hp, _st, _tgtIdx
                    ];
                };
            } forEach [_lead, _wing1, _wing2];

            // Log OPFOR alive states
            private _opforAlive = _targets apply { if (alive _x) then { round (_x getVariable ["AAI_HealthPoints", 100]) } else { 0 } };
            diag_log format ["[TRACK_OPFOR] mode=SEMANTIC;t=%1;alive=%2", _elapsed, _opforAlive];

            sleep 0.5;
        };

        private _finalElapsed = round ((time - _t0) * 10) / 10;
        diag_log format ["[BENCHMARK_TRACK_END] mode=SEMANTIC;duration=%1;bluforSurvivors=%2;targetsNeutralized=%3",
            _finalElapsed,
            {alive _x} count [_lead, _wing1, _wing2],
            missionNamespace getVariable ["AAI_TargetsKilledCount", 0]
        ];
    };

    // 3D Tactical Overlay setup
    if (missionNamespace getVariable ["AAI_3DOverlayActive", true]) then {
        [true, _lead] call AAI_fnc_drawTacticalOverlay;
    };

    systemChat "[BENCHMARK GEORGETOWN : TICO TRINOME] Epreuve prete (8 cibles). F1 Reset | F2 Camera (Lead/AR/Marks/Spectateur) | F3 3D | Y/Z Zeus";
};

// ============================================================================
// 4. Camera View Cycle (F2: Spectator -> Pointman -> AR -> Marksman)
// ============================================================================
AAI_fnc_cycleCameraView = {
    private _currentMode = missionNamespace getVariable ["AAI_CameraModeIndex", 0];
    private _nextMode = (_currentMode + 1) % 4; // 0 = Spectator, 1 = Lead, 2 = AR, 3 = Marksman
    missionNamespace setVariable ["AAI_CameraModeIndex", _nextMode];

    private _lead  = missionNamespace getVariable ["AAI_BluforLead", objNull];
    private _wing1 = missionNamespace getVariable ["AAI_BluforWing1", objNull];
    private _wing2 = missionNamespace getVariable ["AAI_BluforWing2", objNull];

    if (!isNil "AAI_FPCam" && {!isNull AAI_FPCam}) then {
        AAI_FPCam cameraEffect ["TERMINATE", "BACK"];
        camDestroy AAI_FPCam;
        AAI_FPCam = nil;
    };

    switch (_nextMode) do {
        case 1: {
            if (!isNull _lead && {alive _lead}) then {
                AAI_FPCam = "camera" camCreate (eyePos _lead);
                AAI_FPCam cameraEffect ["INTERNAL", "BACK"];
                AAI_FPCam attachTo [_lead, [0, 0.12, 0.08], "head"];
                [true, _lead] call AAI_fnc_drawTacticalOverlay;
                systemChat "[CAMERA] Mode: YEUX DU POINTMAN (FPV Lead).";
            } else {
                call AAI_fnc_cycleCameraView;
            };
        };
        case 2: {
            if (!isNull _wing1 && {alive _wing1}) then {
                AAI_FPCam = "camera" camCreate (eyePos _wing1);
                AAI_FPCam cameraEffect ["INTERNAL", "BACK"];
                AAI_FPCam attachTo [_wing1, [0, 0.12, 0.08], "head"];
                [true, _wing1] call AAI_fnc_drawTacticalOverlay;
                systemChat "[CAMERA] Mode: YEUX DU MITRAILLEUR (FPV Appui AR).";
            } else {
                call AAI_fnc_cycleCameraView;
            };
        };
        case 3: {
            if (!isNull _wing2 && {alive _wing2}) then {
                AAI_FPCam = "camera" camCreate (eyePos _wing2);
                AAI_FPCam cameraEffect ["INTERNAL", "BACK"];
                AAI_FPCam attachTo [_wing2, [0, 0.12, 0.08], "head"];
                [true, _wing2] call AAI_fnc_drawTacticalOverlay;
                systemChat "[CAMERA] Mode: YEUX DU TIREUR D'ELITE (FPV Marksman).";
            } else {
                call AAI_fnc_cycleCameraView;
            };
        };
        default {
            (vehicle player) switchCamera "INTERNAL";
            private _monitored = if (alive _lead) then { _lead } else { if (alive _wing1) then { _wing1 } else { _wing2 } };
            if (!isNull _monitored) then { [true, _monitored] call AAI_fnc_drawTacticalOverlay; };
            systemChat "[CAMERA] Mode: GHOST INSTRUCTOR (Vue aerienne d'ensemble).";
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
        private _lead = missionNamespace getVariable ["AAI_BluforLead", objNull];
        private _wing1 = missionNamespace getVariable ["AAI_BluforWing1", objNull];
        private _wing2 = missionNamespace getVariable ["AAI_BluforWing2", objNull];
        private _monitored = if (!isNull _lead && {alive _lead}) then { _lead } else { if (alive _wing1) then { _wing1 } else { _wing2 } };
        [true, _monitored] call AAI_fnc_drawTacticalOverlay;
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
// 7. Real-Time Benchmark Telemetry HUD Loop (Trinome Telemetry)
// ============================================================================
[] spawn {
    while {true} do {
        sleep 0.25;

        private _lead  = missionNamespace getVariable ["AAI_BluforLead", objNull];
        private _wing1 = missionNamespace getVariable ["AAI_BluforWing1", objNull];
        private _wing2 = missionNamespace getVariable ["AAI_BluforWing2", objNull];
        private _spawnPos = missionNamespace getVariable ["AAI_BluforLeadSpawnPos", [5752, 10115, 0]];
        private _killedCount = missionNamespace getVariable ["AAI_TargetsKilledCount", 0];

        // Lead Telemetry
        private _lAlive = (!isNull _lead && {alive _lead});
        private _hpLead = if (_lAlive) then { round (_lead getVariable ["AAI_HealthPoints", 250]) } else { 0 };
        private _stateLead = if (_lAlive) then { _lead getVariable ["AAI_TacticalState", "IDLE"] } else { "DEAD" };
        private _coverLead = if (_lAlive) then { _lead getVariable ["AAI_TargetCover", createHashMap] } else { createHashMap };
        private _obsDataLead = _coverLead getOrDefault ["obstacleData", createHashMap];
        private _obsNameLead = if (_obsDataLead isEqualType createHashMap) then { _obsDataLead getOrDefault ["typeName", "Mur"] } else { "Abri" };
        private _obsHeightLead = if (_obsDataLead isEqualType createHashMap) then { _obsDataLead getOrDefault ["height", 1.0] } else { 1.0 };
        private _distAdvanced = if (_lAlive) then { round (_lead distance2D _spawnPos) } else { 0 };
        private _targetIndex = if (_lAlive) then { _lead getVariable ["AAI_CurrentTargetIndex", 1] } else { 1 };

        // Wingman 1 Telemetry (Autorifleman)
        private _w1Alive = (!isNull _wing1 && {alive _wing1});
        private _hpWing1 = if (_w1Alive) then { round (_wing1 getVariable ["AAI_HealthPoints", 250]) } else { 0 };
        private _stateWing1 = if (_w1Alive) then { _wing1 getVariable ["AAI_TacticalState", "IDLE"] } else { "DEAD" };
        private _coverWing1 = if (_w1Alive) then { _wing1 getVariable ["AAI_TargetCover", createHashMap] } else { createHashMap };
        private _obsDataWing1 = _coverWing1 getOrDefault ["obstacleData", createHashMap];
        private _obsNameWing1 = if (_obsDataWing1 isEqualType createHashMap) then { _obsDataWing1 getOrDefault ["typeName", "Mur"] } else { "Abri" };
        private _obsHeightWing1 = if (_obsDataWing1 isEqualType createHashMap) then { _obsDataWing1 getOrDefault ["height", 1.0] } else { 1.0 };

        // Wingman 2 Telemetry (Marksman)
        private _w2Alive = (!isNull _wing2 && {alive _wing2});
        private _hpWing2 = if (_w2Alive) then { round (_wing2 getVariable ["AAI_HealthPoints", 250]) } else { 0 };
        private _stateWing2 = if (_w2Alive) then { _wing2 getVariable ["AAI_TacticalState", "IDLE"] } else { "DEAD" };
        private _coverWing2 = if (_w2Alive) then { _wing2 getVariable ["AAI_TargetCover", createHashMap] } else { createHashMap };
        private _obsDataWing2 = _coverWing2 getOrDefault ["obstacleData", createHashMap];
        private _obsNameWing2 = if (_obsDataWing2 isEqualType createHashMap) then { _obsDataWing2 getOrDefault ["typeName", "Mur"] } else { "Abri" };
        private _obsHeightWing2 = if (_obsDataWing2 isEqualType createHashMap) then { _obsDataWing2 getOrDefault ["height", 1.0] } else { 1.0 };

        private _hColorLead  = if (_hpLead > 150) then { "#33ff33" } else { if (_hpLead > 60) then { "#ff9900" } else { "#ff2222" } };
        private _hColorWing1 = if (_hpWing1 > 150) then { "#33ff33" } else { if (_hpWing1 > 60) then { "#ff9900" } else { "#ff2222" } };
        private _hColorWing2 = if (_hpWing2 > 150) then { "#33ff33" } else { if (_hpWing2 > 60) then { "#ff9900" } else { "#ff2222" } };

        private _camMode = missionNamespace getVariable ["AAI_CameraModeIndex", 0];
        private _camName = switch (_camMode) do {
            case 1: { "Pointman (FPV Lead)" };
            case 2: { "Autorifleman (FPV Appui)" };
            case 3: { "Marksman (FPV Precision)" };
            default { "Ghost Instructor (Surplomb)" };
        };

        private _targetStr = if (_killedCount >= 8) then {
            "<t color='#00ff88' font='PuristaBold'>TOUTES LES CIBLES ELIMINEES (8/8)</t>"
        } else {
            format ["Cible %1 / 8", _targetIndex]
        };

        private _radioLog = missionNamespace getVariable ["AAI_RadioLog", []];
        private _radioDisplayStr = if (count _radioLog > 0) then {
            _radioLog joinString "<br/>"
        } else {
            "<t color='#888888'>En attente d'ordres intercom...</t>"
        };

        hintSilent parseText format [
            "<t color='#33ccff' size='1.2' font='PuristaBold'>[BENCHMARK GEORGETOWN : TICO TRINOME]</t><br/>" +
            "<t color='#aaaaaa' size='0.85'>Vue Active :</t> <t color='#ffff00'>%1</t><br/><br/>" +
            "<t color='#ffffff' font='PuristaBold'>--- POINTMAN (LEAD) ---</t><br/>" +
            "Sante : <t color='%2'>%3 / 250 HP</t> | Action : <t color='#ffff33'>%4</t><br/>" +
            "Abri : <t color='#00ff88'>%5 (H: %6m)</t><br/><br/>" +
            "<t color='#ffffff' font='PuristaBold'>--- APPUI LOURD (AR) ---</t><br/>" +
            "Sante : <t color='%7'>%8 / 250 HP</t> | Action : <t color='#ffff33'>%9</t><br/>" +
            "Abri : <t color='#00ff88'>%10 (H: %11m)</t><br/><br/>" +
            "<t color='#ffffff' font='PuristaBold'>--- PRECISION (MARKSMAN) ---</t><br/>" +
            "Sante : <t color='%12'>%13 / 250 HP</t> | Action : <t color='#ffff33'>%14</t><br/>" +
            "Abri : <t color='#00ff88'>%15 (H: %16m)</t><br/><br/>" +
            "Progression : <t color='#ffffff'>%17 m / 325 m</t><br/>" +
            "Score Cibles : <t color='#ffff00'>%18 / 8 neutralisees</t><br/>" +
            "Objectif Actuel : <t color='#ffff00'>%19</t><br/><br/>" +
            "<t color='#ffffff' font='PuristaBold'>--- INTERCOM RADIO TACTIQUE ---</t><br/>" +
            "%20<br/><br/>" +
            "<t color='#888888' size='0.8'>Raccourcis : <t color='#ffff00'>F1</t> Reset | <t color='#ffff00'>F2</t> Cycle Camera | <t color='#ffff00'>F3</t> 3D | <t color='#ffff00'>Y/Z</t> Zeus</t>",
            _camName,
            _hColorLead, _hpLead, _stateLead, _obsNameLead, (_obsHeightLead toFixed 1),
            _hColorWing1, _hpWing1, _stateWing1, _obsNameWing1, (_obsHeightWing1 toFixed 1),
            _hColorWing2, _hpWing2, _stateWing2, _obsNameWing2, (_obsHeightWing2 toFixed 1),
            _distAdvanced, _killedCount, _targetStr, _radioDisplayStr
        ];
    };
};

// ============================================================================
// 8. Key Handlers (Display 46 and 312)
// ============================================================================
if (hasInterface) then {
    [] spawn {
        waitUntil {!isNull (findDisplay 46)};
        (findDisplay 46) displayAddEventHandler ["KeyDown", {
            params ["_disp", "_key"];

            // F1 (59): Reset Benchmark Trial
            if (_key == 59) exitWith { call AAI_fnc_resetBenchmarkTrial; true };

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
                if (_key == 59) exitWith { call AAI_fnc_resetBenchmarkTrial; true };
                if (_key == 60) exitWith { call AAI_fnc_cycleCameraView; true };
                if (_key == 61) exitWith { call AAI_fnc_toggle3DOverlay; true };
                if (_key in [1, 14, 21, 44]) exitWith { _disp closeDisplay 1; true };
                false
            }];
            waitUntil {isNull (findDisplay 312)};
        };
    };
};

// ============================================================================
// 9. Player Action Menu
// ============================================================================
if (!isNull player) then {
    player addAction ["<t color='#ffff00' size='1.2'>[GEORGETOWN] RELANCER L'EPREUVE (F1)</t>", {
        call AAI_fnc_resetBenchmarkTrial;
    }, nil, 3.0, false, false, "", "true", 50];

    player addAction ["<t color='#00ffcc' size='1.2'>[CAMERA] CYCLE CAMERA LEAD / AR / MARKS / TOIT (F2)</t>", {
        call AAI_fnc_cycleCameraView;
    }, nil, 2.9, false, false, "", "true", 50];

    player addAction ["<t color='#33ffaa' size='1.1'>[3D] VISUALISEUR D'ABRIS (F3)</t>", {
        call AAI_fnc_toggle3DOverlay;
    }, nil, 2.8, false, false, "", "true", 50];

    player addAction ["<t color='#ffcc00' size='1.2'>[ZEUS] VUE AERIENNE RTS (Y / Z)</t>", {
        if (isNull (findDisplay 312)) then { openCuratorInterface; } else { (findDisplay 312) closeDisplay 1; };
    }, nil, 2.7, false, false, "", "true", 50];
};

// Launch trial at start
call AAI_fnc_resetBenchmarkTrial;

diag_log "[AAI Benchmark Georgetown] TICO Semantic AI Trinome Mission Initialized Successfully.";
