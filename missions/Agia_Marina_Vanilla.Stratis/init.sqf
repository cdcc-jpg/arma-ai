/*
    Author: Clement D. / Arma-AI Team
    Mission: Agia Marina: Vanilla AI Benchmark (Stratis)
    File: init.sqf

    Description:
        1-to-1 urban tactical benchmark in Agia Marina with ZERO added objects.
        BLUFOR runner is commanded solely by the native Arma 3 Vanilla AI engine.
        Exact millimeter-identical configuration with the Semantic benchmark mission.
*/

diag_log "[AAI Benchmark Agia Marina] Initializing Vanilla AI Benchmark on Stratis...";

// Enable full debug and simulation
enableSaving [false, false];

// ============================================================================
// 1. Mission Coordinates & Fixed Urban Landmarks (Agia Marina, Stratis)
// ============================================================================
// Zero added objects: uses natural Agia Marina buildings, stone walls, and streets
private _bluforSpawnPos = [2990, 6005, 0];   // South street entrance
private _sentry1Pos     = [3008, 6035, 0];   // Market square terrace (35m ahead)
private _sentry2Pos     = [3028, 6065, 0];   // Central crossroads / church corner (70m ahead)
private _commanderPos   = [3055, 6098, 0];   // Upper village redoubt (110m ahead)
private _spectatorPos   = [2982, 6010, 6.5]; // Flat roof overlooking street entrance

missionNamespace setVariable ["AAI_BluforSpawnPos", _bluforSpawnPos];
missionNamespace setVariable ["AAI_Sentry1Pos", _sentry1Pos];
missionNamespace setVariable ["AAI_Sentry2Pos", _sentry2Pos];
missionNamespace setVariable ["AAI_CommanderPos", _commanderPos];
missionNamespace setVariable ["AAI_SpectatorPos", _spectatorPos];

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
    private _bluforSpawnPos = missionNamespace getVariable ["AAI_BluforSpawnPos", [2990, 6005, 0]];
    private _sentry1Pos     = missionNamespace getVariable ["AAI_Sentry1Pos", [3008, 6035, 0]];
    private _sentry2Pos     = missionNamespace getVariable ["AAI_Sentry2Pos", [3028, 6065, 0]];
    private _commanderPos   = missionNamespace getVariable ["AAI_CommanderPos", [3055, 6098, 0]];

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
        _unit setSkill 0.75;
        _unit setSkill ["aimingAccuracy", 0.12];
        _unit setSkill ["aimingSpeed", 0.45];
        _unit setVariable ["AAI_TargetName", _callsign];
        _units pushBack _unit;
        _unit
    };

    // Spawn 3 OPFOR defenders in natural Agia Marina positions
    private _sentry1 = [_sentry1Pos, 205, "Sentry 1 (Place du Marché)"] call _fnc_createHostile;
    private _sentry2 = [_sentry2Pos, 215, "Sentry 2 (Carrefour Central)"] call _fnc_createHostile;
    private _commander = [_commanderPos, 220, "Commandant (Sortie Nord)"] call _fnc_createHostile;

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
    _runner disableAI "AUTOCOMBAT";
    _runner disableAI "RADIO";
    _runner setVariable ["AAI_Callsign", "VANILLA RUNNER"];

    // Normalized damage handler (scaled so unit survives to demonstrate tactics)
    _runner addEventHandler ["HandleDamage", {
        params ["_unit", "_selection", "_damage"];
        private _cur = damage _unit;
        (_cur + 0.02) min 0.95
    }];
    _units pushBack _runner;

    missionNamespace setVariable ["AAI_ActiveUnits", _units];
    missionNamespace setVariable ["AAI_BluforRunner", _runner];
    missionNamespace setVariable ["AAI_Sentry1", _sentry1];
    missionNamespace setVariable ["AAI_Sentry2", _sentry2];
    missionNamespace setVariable ["AAI_Commander", _commander];
    missionNamespace setVariable ["AAI_TrialStartTime", time];

    // Reveal targets mutually
    _runner reveal [_sentry1, 4];
    _sentry1 reveal [_runner, 4];

    // =========================================================================
    // VANILLA ARMA 3 AI LOCOMOTION & OBJECTIVE LOOP
    // =========================================================================
    [_runner, _sentry1, _sentry2, _commander] spawn {
        params ["_u", "_t1", "_t2", "_t3"];
        sleep 0.5;

        // Stage 1: Advance towards Sentry 1 (Market Square)
        systemChat "[AGIA MARINA - VANILLA] Epreuve lancee ! Avance vers Sentry 1 (Place du Marche)...";
        _u doMove (getPosATL _t1);

        while {alive _u && {alive _t1}} do {
            sleep 0.8;
            if (alive _u && {alive _t1} && {_u distance2D _t1 > 3.0} && {speed _u < 0.4}) then {
                _u doMove (getPosATL _t1);
            };
        };

        if (alive _u && {!alive _t1}) then {
            systemChat "[AGIA MARINA - VANILLA] Sentry 1 neutralisee ! Avance vers Sentry 2 (Carrefour Central)...";
            _u reveal [_t2, 4];
            _t2 reveal [_u, 4];
            _u doMove (getPosATL _t2);

            // Stage 2: Advance towards Sentry 2 (Central Crossroads)
            while {alive _u && {alive _t2}} do {
                sleep 0.8;
                if (alive _u && {alive _t2} && {_u distance2D _t2 > 3.0} && {speed _u < 0.4}) then {
                    _u doMove (getPosATL _t2);
                };
            };

            if (alive _u && {!alive _t2}) then {
                systemChat "[AGIA MARINA - VANILLA] Sentry 2 neutralisee ! Assaut final vers le Commandant (Sortie Nord)...";
                _u reveal [_t3, 4];
                _t3 reveal [_u, 4];
                _u doMove (getPosATL _t3);

                // Stage 3: Advance towards Commander (North Exit)
                while {alive _u && {alive _t3}} do {
                    sleep 0.8;
                    if (alive _u && {alive _t3} && {_u distance2D _t3 > 3.0} && {speed _u < 0.4}) then {
                        _u doMove (getPosATL _t3);
                    };
                };

                if (!alive _t3) then {
                    systemChat "[AGIA MARINA - VANILLA] VICTOIRE ! Tous les defenseurs d'Agia Marina ont ete neutralises.";
                };
            };
        };
    };

    systemChat "[BENCHMARK AGIA MARINA] Mission Vanilla prete. Appuyez sur F2 pour la camera FPV ou Y/Z pour Zeus.";
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
        private _sentry1 = missionNamespace getVariable ["AAI_Sentry1", objNull];
        private _sentry2 = missionNamespace getVariable ["AAI_Sentry2", objNull];
        private _commander = missionNamespace getVariable ["AAI_Commander", objNull];
        private _spawnPos = missionNamespace getVariable ["AAI_BluforSpawnPos", [2990, 6005, 0]];

        private _rAlive = (!isNull _runner && {alive _runner});
        private _health = if (_rAlive) then { round ((1 - damage _runner) * 100) } else { 0 };
        private _distAdvanced = if (_rAlive) then { round (_runner distance2D _spawnPos) } else { 0 };

        private _s1Alive = (!isNull _sentry1 && {alive _sentry1});
        private _s2Alive = (!isNull _sentry2 && {alive _sentry2});
        private _cAlive = (!isNull _commander && {alive _commander});

        private _targetStr = if (_s1Alive) then { "Sentry 1 (Marche ~35m)" } else { if (_s2Alive) then { "Sentry 2 (Carrefour ~70m)" } else { if (_cAlive) then { "Commandant (Sortie ~110m)" } else { "<t color='#00ff88'>COMPLETE !</t>" } } };

        private _camMode = missionNamespace getVariable ["AAI_CameraModeIndex", 0];
        private _camName = if (_camMode == 1) then { "Yeux IA (FPV)" } else { "Ghost Instructor (Toit)" };
        private _hColor = if (_health > 50) then { "#33ff33" } else { if (_health > 0) then { "#ff9900" } else { "#ff2222" } };

        hintSilent parseText format [
            "<t color='#ff6666' size='1.2' font='PuristaBold'>[BENCHMARK AGIA MARINA : VANILLA]</t><br/>" +
            "<t color='#aaaaaa' size='0.85'>Vue :</t> <t color='#ffff00'>%4</t><br/><br/>" +
            "<t color='#ffffff' size='0.95'>Moteur IA :</t> <t color='#ff4444'>Vanilla Arma 3 (Native)</t><br/>" +
            "<t color='#ffffff' size='0.95'>Environnement :</t> <t color='#00ccff'>Agia Marina (100%% Natif)</t><br/>" +
            "<t color='#ffffff' size='0.95'>Objets ajoutes :</t> <t color='#33ff33'>0 (Aucun)</t><br/><br/>" +
            "Sante Soldat : <t color='%1'>%2%5</t><br/>" +
            "Progression : <t color='#ffffff'>%3 m</t><br/>" +
            "Objectif Actuel : <t color='#ffff00'>%6</t><br/><br/>" +
            "<t color='#888888' size='0.8'>Raccourcis : <t color='#ffff00'>F1</t> Reset | <t color='#ffff00'>F2</t> Yeux IA | <t color='#ffff00'>Y/Z</t> Zeus</t>",
            _hColor, _health, _distAdvanced, _camName, "%", _targetStr
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
    }, nil, 2.8, false, false, "", "true", 50];
};

// Launch trial at start
call AAI_fnc_resetBenchmarkTrial;

diag_log "[AAI Benchmark Agia Marina] Vanilla AI Mission Initialized Successfully.";
