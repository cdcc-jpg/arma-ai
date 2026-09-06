/*
    Author: Clement D. / Arma-AI Team
    Mission: Agia Marina: Vanilla AI Benchmark (Stratis)
    File: init.sqf

    Description:
        1-to-1 urban tactical benchmark in Agia Marina with ZERO added objects.
        BLUFOR runner is commanded by native Vanilla Arma 3 AI.
        Exact millimeter-identical configuration with the TICO Semantic benchmark mission.
        7 OPFOR targets stationed along the natural winding artery of Agia Marina.
        Calibrated tactical survivability: BLUFOR is vulnerable but durable (100 HP).
*/

diag_log "[AAI Benchmark Agia Marina] Initializing Vanilla AI Benchmark on Stratis (7 Targets)...";

// Enable full debug and simulation
enableSaving [false, false];

// ============================================================================
// 1. Mission Coordinates & 7 Fixed Urban Landmarks (Agia Marina, Stratis)
// ============================================================================
// Zero added objects: millimeter-identical positions to Semantic mission
private _bluforSpawnPos = [2990, 6002, 0];   // South street entrance
private _spectatorPos   = [2982, 6010, 6.5]; // Flat roof overlooking street entrance

private _targetsConfig = [
    [[2998, 6025, 0], 205, "1. Muret Entree Sud (~25m)"],
    [[3010, 6046, 0], 210, "2. Terrasse du Marche (~50m)"],
    [[3024, 6068, 0], 215, "3. Couloir Maisons Blanches (~75m)"],
    [[3042, 6092, 0], 220, "4. Carrefour de l'Eglise (~105m)"],
    [[3065, 6122, 0], 215, "5. Escalier Rue Haute (~140m)"],
    [[3088, 6155, 0], 220, "6. Veranda du Cafe (~180m)"],
    [[3118, 6195, 0], 225, "7. Redoute Sortie Nord (~230m)"]
];

missionNamespace setVariable ["AAI_BluforSpawnPos", _bluforSpawnPos];
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
        player setPosATL [2982, 6010, 6.5];
        player setDir 25;
    };
};

// ============================================================================
// 3. Reset & Launch Benchmark Trial Function
// ============================================================================
AAI_fnc_resetBenchmarkTrial = {
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
    private _bluforSpawnPos = missionNamespace getVariable ["AAI_BluforSpawnPos", [2990, 6002, 0]];
    private _targetsConfig  = missionNamespace getVariable ["AAI_TargetsConfig", []];

    // Helper to spawn hostile OPFOR targets in natural village cover
    private _fnc_createHostile = {
        params ["_pos", "_dir", "_callsign"];
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
        _unit setSkill 0.70;
        _unit setSkill ["aimingAccuracy", 0.18];
        _unit setSkill ["aimingSpeed", 0.50];
        _unit setSkill ["spotDistance", 0.85];
        _unit setSkill ["spotTime", 0.85];
        _unit setVariable ["AAI_TargetName", _callsign];
        _units pushBack _unit;
        _unit
    };

    // Spawn the 7 OPFOR defenders in millimeter-identical positions
    private _spawnedTargets = [];
    private _targetPositions = [];
    {
        _x params ["_pos", "_dir", "_callsign"];
        private _hostile = [_pos, _dir, _callsign] call _fnc_createHostile;
        _spawnedTargets pushBack _hostile;
        _targetPositions pushBack _pos;
    } forEach _targetsConfig;

    // Spawn BLUFOR Vanilla Runner at south street entrance
    private _grpBlufor = createGroup [west, true];
    _grpBlufor enableAttack false;
    private _runner = _grpBlufor createUnit ["B_Soldier_F", _bluforSpawnPos, [], 0, "NONE"];
    _runner setPosATL _bluforSpawnPos;
    _runner setDir 15;
    _runner setSkill 0.95;
    _runner setBehaviour "AWARE";
    _runner setCombatMode "RED";
    _runner setSpeedMode "FULL";
    _runner setVariable ["AAI_Callsign", "VANILLA RUNNER"];
    _runner setVariable ["AAI_HealthPoints", 100];
    _runner setVariable ["AAI_CurrentTargetIndex", 1];

    // =========================================================================
    // CALIBRATED TACTICAL SURVIVABILITY DAMAGE MODEL (100 HP - Identical Parity)
    // =========================================================================
    _runner addEventHandler ["HandleDamage", {
        params ["_unit", "_selection", "_damage", "_source", "_projectile", "_hitIndex", "_instigator", "_hitPoint"];

        if (_selection in ["", "body", "spine1", "spine2", "spine3", "pelvis", "chest"]) then {
            private _curHP = _unit getVariable ["AAI_HealthPoints", 100];
            if (_curHP > 0) then {
                private _loss = 8.0 + (random 4.0);
                private _newHP = (_curHP - _loss) max 0;
                _unit setVariable ["AAI_HealthPoints", _newHP];

                if (_newHP <= 0) then {
                    _unit setDamage 1;
                } else {
                    _unit setDamage ((1 - (_newHP / 100)) min 0.89);
                };
            };
        } else {
            if (_selection in ["legs", "arms", "hands", "feet", "leftleg", "rightleg", "leftarm", "rightarm"]) then {
                private _curHP = _unit getVariable ["AAI_HealthPoints", 100];
                if (_curHP > 0) then {
                    private _loss = 4.0 + (random 2.0);
                    private _newHP = (_curHP - _loss) max 0;
                    _unit setVariable ["AAI_HealthPoints", _newHP];

                    if (_newHP <= 0) then {
                        _unit setDamage 1;
                    } else {
                        _unit setDamage ((1 - (_newHP / 100)) min 0.89);
                    };
                };
            };
        };

        damage _unit
    }];
    _units pushBack _runner;

    missionNamespace setVariable ["AAI_ActiveUnits", _units];
    missionNamespace setVariable ["AAI_BluforRunner", _runner];
    missionNamespace setVariable ["AAI_Targets", _spawnedTargets];
    missionNamespace setVariable ["AAI_TargetPositions", _targetPositions];
    missionNamespace setVariable ["AAI_TargetsKilledCount", 0];
    missionNamespace setVariable ["AAI_TrialStartTime", time];

    // =========================================================================
    // VANILLA ARMA 3 AI PATROL ROUTE & ENGAGEMENT LOOP (No Omniscience)
    // =========================================================================
    [_runner, _spawnedTargets, _targetPositions] spawn {
        params ["_u", "_targets", "_positions"];
        sleep 0.5;

        for "_i" from 0 to ((count _targets) - 1) do {
            private _currentTarget = _targets select _i;
            private _currentPos = _positions select _i;
            private _targetNum = _i + 1;
            private _callsign = _currentTarget getVariable ["AAI_TargetName", format ["Cible %1", _targetNum]];

            _u setVariable ["AAI_CurrentTargetIndex", _targetNum];
            systemChat format ["[AGIA MARINA - VANILLA] Patrouille a decouvert vers %1...", _callsign];
            _u doMove _currentPos;

            while {alive _u && {alive _currentTarget}} do {
                sleep 0.8;
                if (alive _u && {alive _currentTarget} && {_u distance2D _currentPos > 4.0} && {speed _u < 0.4}) then {
                    _u doMove _currentPos;
                };
            };

            if (!alive _u) exitWith {
                systemChat format ["[AGIA MARINA - VANILLA] ECHEC ! Soldat BLUFOR elimine a la cible %1 (%2/7 neutralisees).", _targetNum, _i];
            };

            missionNamespace setVariable ["AAI_TargetsKilledCount", _targetNum];
            systemChat format ["[AGIA MARINA - VANILLA] %1 eliminee ! (%2/7 terminees)", _callsign, _targetNum];
            sleep 0.4;
        };

        if (alive _u) then {
            private _finalHP = round (_u getVariable ["AAI_HealthPoints", 0]);
            systemChat format ["[AGIA MARINA - VANILLA] VICTOIRE ! Toutes les 7 cibles neutralisees. Sante restante : %1 HP", _finalHP];
        };
    };

    systemChat "[BENCHMARK AGIA MARINA : VANILLA] Epreuve prete (7 cibles). F1 Reset | F2 FPV | Y/Z Zeus";
};

// ============================================================================
// 4. First-Person AI Eyes Camera (Key: F2)
// ============================================================================
AAI_fnc_cycleCameraView = {
    private _currentMode = missionNamespace getVariable ["AAI_CameraModeIndex", 0];
    private _nextMode = if (_currentMode == 0) then { 1 } else { 0 };
    missionNamespace setVariable ["AAI_CameraModeIndex", _nextMode];

    private _runner = missionNamespace getVariable ["AAI_BluforRunner", objNull];

    if (!isNil "AAI_FPCam" && {!isNull AAI_FPCam}) then {
        AAI_FPCam cameraEffect ["TERMINATE", "BACK"];
        camDestroy AAI_FPCam;
        AAI_FPCam = nil;
    };

    if (_nextMode == 1 && {!isNull _runner} && {alive _runner}) then {
        AAI_FPCam = "camera" camCreate (eyePos _runner);
        AAI_FPCam cameraEffect ["INTERNAL", "BACK"];
        AAI_FPCam attachTo [_runner, [0, 0.12, 0.08], "head"];
        systemChat "[CAMERA] Mode: YEUX DE L'IA (Vue subjective FPV).";
    } else {
        (vehicle player) switchCamera "INTERNAL";
        systemChat "[CAMERA] Mode: GHOST INSTRUCTOR (Vue d'ensemble sur le toit).";
    };
};

// ============================================================================
// 5. Zeus (Curator) Logic & Interactive RTS Controls
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
// 6. Real-Time Benchmark Telemetry HUD Loop
// ============================================================================
[] spawn {
    while {true} do {
        sleep 0.25;

        private _runner = missionNamespace getVariable ["AAI_BluforRunner", objNull];
        private _spawnPos = missionNamespace getVariable ["AAI_BluforSpawnPos", [2990, 6002, 0]];
        private _killedCount = missionNamespace getVariable ["AAI_TargetsKilledCount", 0];

        private _rAlive = (!isNull _runner && {alive _runner});
        private _hp = if (_rAlive) then { round (_runner getVariable ["AAI_HealthPoints", 100]) } else { 0 };
        private _distAdvanced = if (_rAlive) then { round (_runner distance2D _spawnPos) } else { 0 };
        private _targetIndex = if (_rAlive) then { _runner getVariable ["AAI_CurrentTargetIndex", 1] } else { 1 };

        private _camMode = missionNamespace getVariable ["AAI_CameraModeIndex", 0];
        private _camName = if (_camMode == 1) then { "Yeux IA (FPV)" } else { "Ghost Instructor (Toit)" };
        private _hColor = if (_hp > 60) then { "#33ff33" } else { if (_hp > 25) then { "#ff9900" } else { "#ff2222" } };

        private _targetStr = if (_killedCount >= 7) then {
            "<t color='#00ff88' font='PuristaBold'>TOUTES LES CIBLES ELIMINEES (7/7)</t>"
        } else {
            format ["Cible %1 / 7", _targetIndex]
        };

        private _statusStr = if (_rAlive) then {
            "<t color='#ff8888'>Progression ouverte (Moteur Vanilla)</t>"
        } else {
            "<t color='#ff2222' font='PuristaBold'>MORT AU COMBAT (ELIMINE)</t>"
        };

        hintSilent parseText format [
            "<t color='#ff6666' size='1.2' font='PuristaBold'>[BENCHMARK AGIA MARINA : VANILLA]</t><br/>" +
            "<t color='#aaaaaa' size='0.85'>Vue :</t> <t color='#ffff00'>%4</t><br/><br/>" +
            "<t color='#ffffff' size='0.95'>Moteur IA :</t> <t color='#ff4444'>Vanilla Arma 3 (Native)</t><br/>" +
            "<t color='#ffffff' size='0.95'>Environnement :</t> <t color='#00ccff'>Agia Marina (100%% Natif)</t><br/>" +
            "<t color='#ffffff' size='0.95'>Objets ajoutes :</t> <t color='#33ff33'>0 (Natif)</t><br/><br/>" +
            "Sante Soldat : <t color='%1'>%2 HP / 100 HP</t><br/>" +
            "Progression : <t color='#ffffff'>%3 m / 232 m</t><br/>" +
            "Score Cibles : <t color='#ffff00'>%5 / 7 neutralisees</t><br/>" +
            "Objectif Actuel : <t color='#ffff00'>%6</t><br/>" +
            "Statut : %7<br/><br/>" +
            "<t color='#888888' size='0.8'>Raccourcis : <t color='#ffff00'>F1</t> Reset | <t color='#ffff00'>F2</t> Yeux IA | <t color='#ffff00'>Y/Z</t> Zeus</t>",
            _hColor, _hp, _distAdvanced, _camName, _killedCount, _targetStr, _statusStr
        ];
    };
};

// ============================================================================
// 7. Key Handlers (Display 46 and 312)
// ============================================================================
[] spawn {
    waitUntil {!isNull (findDisplay 46)};
    (findDisplay 46) displayAddEventHandler ["KeyDown", {
        params ["_disp", "_key"];

        // F1 (59): Reset Benchmark Trial
        if (_key == 59) exitWith { call AAI_fnc_resetBenchmarkTrial; true };

        // F2 (60): Cycle Camera Mode
        if (_key == 60) exitWith { call AAI_fnc_cycleCameraView; true };

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
            if (_key in [1, 14, 21, 44]) exitWith { _disp closeDisplay 1; true };
            false
        }];
        waitUntil {isNull (findDisplay 312)};
    };
};

// ============================================================================
// 8. Player Action Menu
// ============================================================================
if (!isNull player) then {
    player addAction ["<t color='#ffff00' size='1.2'>[AGIA MARINA] RELANCER L'EPREUVE (F1)</t>", {
        call AAI_fnc_resetBenchmarkTrial;
    }, nil, 3.0, false, false, "", "true", 50];

    player addAction ["<t color='#00ffcc' size='1.2'>[CAMERA] YEUX DE L'IA (F2)</t>", {
        call AAI_fnc_cycleCameraView;
    }, nil, 2.9, false, false, "", "true", 50];

    player addAction ["<t color='#ffcc00' size='1.2'>[ZEUS] VUE AERIENNE RTS (Y / Z)</t>", {
        if (isNull (findDisplay 312)) then { openCuratorInterface; } else { (findDisplay 312) closeDisplay 1; };
    }, nil, 2.7, false, false, "", "true", 50];
};

// Launch trial at start
call AAI_fnc_resetBenchmarkTrial;

diag_log "[AAI Benchmark Agia Marina] Vanilla AI Mission Initialized Successfully.";
