/*
    Author: Clement D. / Arma-AI Team
    Mission: Agia Marina: Vanilla AI Binome Benchmark (Stratis)
    File: init.sqf

    Description:
        Urban tactical benchmark in the eastern terraced alleys of Agia Marina.
        BLUFOR 2-man fireteam (Binome: Pointman + Wingman Support) operated
        by default Vanilla Arma 3 squad AI (un-augmented baseline).
        Millimeter-identical parity with the TICO Semantic benchmark mission.
        5 OPFOR defensive ambush targets stationed along the winding residential alleys.
        Calibrated tactical survivability damage model (100 HP per soldier).
*/

diag_log "[AAI Benchmark Agia Marina] Initializing Vanilla AI Binome Benchmark on Stratis...";

// Enable simulation and disable savegames
enableSaving [false, false];

// ============================================================================
// 1. Mission Coordinates & 5 Fixed Urban Alley Targets (Agia Marina, Stratis)
// ============================================================================
// Sector: Approach Road & Eastern Terraced Residential Alleys (Ruelles Hautes Est)
// 100% natural map architecture (stone walls, house corners, steps). Zero added props.
private _bluforLeadSpawnPos = [3038, 5940, 0];   // South approach road (Pointman ~80m from Target 1)
private _bluforWingSpawnPos = [3035, 5936, 0];   // Staggered 4m behind/left (Wingman)
private _spectatorPos       = [3028, 5942, 8.5]; // Elevated vantage overlooking approach road & town entrance

private _targetsConfig = [
    [[3052, 6018, 0], 205, "1. Muret du Verger Sud (~80m)"],
    [[3060, 6046, 0], 210, "2. Angle Maison Blanche (~110m)"],
    [[3068, 6074, 0], 205, "3. Carrefour des Escaliers (~138m)"],
    [[3078, 6104, 0], 215, "4. Cour des Oliviers (~168m)"],
    [[3092, 6138, 0], 220, "5. Redoute Sommet Est (~202m)"]
];

missionNamespace setVariable ["AAI_BluforLeadSpawnPos", _bluforLeadSpawnPos];
missionNamespace setVariable ["AAI_BluforWingSpawnPos", _bluforWingSpawnPos];
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
        player setPosATL [3028, 5942, 8.5];
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
    private _leadSpawn = missionNamespace getVariable ["AAI_BluforLeadSpawnPos", [3038, 5940, 0]];
    private _wingSpawn = missionNamespace getVariable ["AAI_BluforWingSpawnPos", [3035, 5936, 0]];
    private _targetsConfig = missionNamespace getVariable ["AAI_TargetsConfig", []];

    // Helper to spawn hostile OPFOR defenders in natural village cover
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

    // Spawn the 5 OPFOR defenders along the alley
    private _spawnedTargets = [];
    private _targetPositions = [];
    {
        _x params ["_pos", "_dir", "_callsign"];
        private _hostile = [_pos, _dir, _callsign] call _fnc_createHostile;
        _spawnedTargets pushBack _hostile;
        _targetPositions pushBack _pos;
    } forEach _targetsConfig;

    // Helper: Apply calibrated tactical survivability damage model (100 HP)
    private _fnc_applyDamageModel = {
        params ["_unit"];
        _unit setVariable ["AAI_HealthPoints", 100];
        _unit addEventHandler ["HandleDamage", {
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
    };

    // =========================================================================
    // SPAWN BLUFOR BINOME (Vanilla Arma 3 Engine AI)
    // =========================================================================
    private _grpBlufor = createGroup [west, true];
    _grpBlufor enableAttack false;

    // 1. Pointman / Team Leader (Vanilla)
    private _lead = _grpBlufor createUnit ["B_Soldier_TL_F", _leadSpawn, [], 0, "NONE"];
    _lead setPosATL _leadSpawn;
    _lead setDir 25;
    _lead setSkill 0.95;
    _lead setBehaviour "AWARE";
    _lead setCombatMode "RED";
    _lead setSpeedMode "FULL";
    _lead forceSpeed 15;
    _lead setUnitPos "UP";
    _lead setVariable ["AAI_Callsign", "VANILLA POINTMAN [LEAD]"];
    _lead setVariable ["AAI_TacticalObjective", _targetPositions select 0];
    _lead setVariable ["AAI_CurrentTargetIndex", 1];
    [_lead] call _fnc_applyDamageModel;
    _units pushBack _lead;

    // 2. Wingman / Support (Vanilla)
    private _wing = _grpBlufor createUnit ["B_Soldier_AR_F", _wingSpawn, [], 0, "NONE"];
    _wing setPosATL _wingSpawn;
    _wing setDir 25;
    _wing setSkill 0.95;
    _wing setBehaviour "AWARE";
    _wing setCombatMode "RED";
    _wing setSpeedMode "FULL";
    _wing forceSpeed 15;
    _wing setUnitPos "UP";
    _wing setVariable ["AAI_Callsign", "VANILLA WINGMAN [APPUI]"];
    _wing setVariable ["AAI_TacticalObjective", _targetPositions select 0];
    _wing setVariable ["AAI_CurrentTargetIndex", 1];
    [_wing] call _fnc_applyDamageModel;
    _units pushBack _wing;

    _grpBlufor selectLeader _lead;

    missionNamespace setVariable ["AAI_ActiveUnits", _units];
    missionNamespace setVariable ["AAI_BluforLead", _lead];
    missionNamespace setVariable ["AAI_BluforWingman", _wing];
    missionNamespace setVariable ["AAI_Targets", _spawnedTargets];
    missionNamespace setVariable ["AAI_TargetPositions", _targetPositions];
    missionNamespace setVariable ["AAI_TargetsKilledCount", 0];
    missionNamespace setVariable ["AAI_TrialStartTime", time];

    // Multi-stage urban objective coordinator through the 5 natural alley targets
    [_lead, _wing, _spawnedTargets, _targetPositions] spawn {
        params ["_lead", "_wing", "_targets", "_positions"];

        for "_i" from 0 to ((count _targets) - 1) do {
            private _currentTarget = _targets select _i;
            private _currentPos = _positions select _i;
            private _targetNum = _i + 1;
            private _callsign = _currentTarget getVariable ["AAI_TargetName", format ["Cible %1", _targetNum]];

            if (alive _lead) then {
                _lead setVariable ["AAI_TacticalObjective", _currentPos];
                _lead setVariable ["AAI_CurrentTargetIndex", _targetNum];
                _lead doMove _currentPos;
            };

            if (alive _wing) then {
                _wing setVariable ["AAI_TacticalObjective", _currentPos];
                _wing setVariable ["AAI_CurrentTargetIndex", _targetNum];
                if (alive _lead) then {
                    _wing doFollow _lead;
                } else {
                    _wing doMove _currentPos;
                };
            };

            systemChat format ["[AGIA MARINA - VANILLA] Binome en sprint vers %1...", _callsign];

            // Wait until this target is killed, or dominated in close quarters (< 6.0m), or both soldiers die
            waitUntil {
                !alive _currentTarget 
                || {(!alive _lead && {!alive _wing})}
                || {(alive _lead && {_lead distance2D _currentPos < 6.0})}
                || {(alive _wing && {_wing distance2D _currentPos < 6.0})}
            };

            if (!alive _lead && {!alive _wing}) exitWith {
                systemChat format ["[AGIA MARINA - VANILLA] ECHEC ! Le binome Vanilla a ete elimine a la cible %1 (%2/5 neutralisees).", _targetNum, _i];
                diag_log format ["[AGIA MARINA - VANILLA] ECHEC ! Le binome Vanilla a ete elimine a la cible %1 (%2/5 neutralisees).", _targetNum, _i];
            };

            // If target was bypassed or dominated at point-blank range, ensure clean elimination
            if (alive _currentTarget && {(alive _lead && {_lead distance2D _currentPos < 6.5}) || (alive _wing && {_wing distance2D _currentPos < 6.5})}) then {
                _currentTarget setDamage 1;
            };

            if (!alive _lead && {alive _wing}) then {
                systemChat "[AGIA MARINA - VANILLA] Le Chef de binome est tombe ! L'equipier prend le commandement !";
                (group _wing) selectLeader _wing;
            };

            missionNamespace setVariable ["AAI_TargetsKilledCount", _targetNum];
            systemChat format ["[AGIA MARINA - VANILLA] %1 neutralisee ! (%2/5 terminees)", _callsign, _targetNum];
            diag_log format ["[AGIA MARINA - VANILLA] %1 neutralisee ! (%2/5 terminees)", _callsign, _targetNum];
            sleep 0.4;
        };

        if (alive _lead || alive _wing) then {
            private _hpLead = if (alive _lead) then { round (_lead getVariable ["AAI_HealthPoints", 0]) } else { 0 };
            private _hpWing = if (alive _wing) then { round (_wing getVariable ["AAI_HealthPoints", 0]) } else { 0 };
            systemChat format ["[AGIA MARINA - VANILLA] VICTOIRE DU BINOME VANILLA ! (Lead: %1 HP, Wing: %2 HP)", _hpLead, _hpWing];
        };
    };

    systemChat "[BENCHMARK AGIA MARINA : VANILLA BINOME] Epreuve prete (5 cibles). F1 Reset | F2 Camera (Lead/Wing/Spectateur) | Y/Z Zeus";
};

// ============================================================================
// 4. Camera View Cycle (F2: Spectator -> Pointman FPV -> Wingman FPV)
// ============================================================================
AAI_fnc_cycleCameraView = {
    private _currentMode = missionNamespace getVariable ["AAI_CameraModeIndex", 0];
    private _nextMode = (_currentMode + 1) % 3; // 0 = Spectator, 1 = Lead, 2 = Wingman
    missionNamespace setVariable ["AAI_CameraModeIndex", _nextMode];

    private _lead = missionNamespace getVariable ["AAI_BluforLead", objNull];
    private _wing = missionNamespace getVariable ["AAI_BluforWingman", objNull];

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
                systemChat "[CAMERA] Mode: YEUX DE L'OUVREUR / POINTMAN (FPV Lead).";
            } else {
                call AAI_fnc_cycleCameraView;
            };
        };
        case 2: {
            if (!isNull _wing && {alive _wing}) then {
                AAI_FPCam = "camera" camCreate (eyePos _wing);
                AAI_FPCam cameraEffect ["INTERNAL", "BACK"];
                AAI_FPCam attachTo [_wing, [0, 0.12, 0.08], "head"];
                systemChat "[CAMERA] Mode: YEUX DE L'EQUIPIER / APPUI (FPV Wingman).";
            } else {
                call AAI_fnc_cycleCameraView;
            };
        };
        default {
            (vehicle player) switchCamera "INTERNAL";
            systemChat "[CAMERA] Mode: GHOST INSTRUCTOR (Vue d'ensemble sur le toit).";
        };
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
// 6. Real-Time Benchmark Telemetry HUD Loop (Vanilla Binome Telemetry)
// ============================================================================
[] spawn {
    while {true} do {
        sleep 0.25;

        private _lead = missionNamespace getVariable ["AAI_BluforLead", objNull];
        private _wing = missionNamespace getVariable ["AAI_BluforWingman", objNull];
        private _spawnPos = missionNamespace getVariable ["AAI_BluforLeadSpawnPos", [3048, 5992, 0]];
        private _killedCount = missionNamespace getVariable ["AAI_TargetsKilledCount", 0];

        // Lead Telemetry
        private _lAlive = (!isNull _lead && {alive _lead});
        private _hpLead = if (_lAlive) then { round (_lead getVariable ["AAI_HealthPoints", 100]) } else { 0 };
        private _distAdvanced = if (_lAlive) then { round (_lead distance2D _spawnPos) } else { if (!isNull _wing && {alive _wing}) then { round (_wing distance2D _spawnPos) } else { 0 } };
        private _targetIndex = if (_lAlive) then { _lead getVariable ["AAI_CurrentTargetIndex", 1] } else { if (!isNull _wing && {alive _wing}) then { _wing getVariable ["AAI_CurrentTargetIndex", 1] } else { 1 } };

        // Wingman Telemetry
        private _wAlive = (!isNull _wing && {alive _wing});
        private _hpWing = if (_wAlive) then { round (_wing getVariable ["AAI_HealthPoints", 100]) } else { 0 };

        private _hColorLead = if (_hpLead > 60) then { "#33ff33" } else { if (_hpLead > 25) then { "#ff9900" } else { "#ff2222" } };
        private _hColorWing = if (_hpWing > 60) then { "#33ff33" } else { if (_hpWing > 25) then { "#ff9900" } else { "#ff2222" } };

        private _camMode = missionNamespace getVariable ["AAI_CameraModeIndex", 0];
        private _camName = switch (_camMode) do {
            case 1: { "Pointman (FPV Lead)" };
            case 2: { "Wingman (FPV Appui)" };
            default { "Ghost Instructor (Toit)" };
        };

        private _targetStr = if (_killedCount >= 5) then {
            "<t color='#00ff88' font='PuristaBold'>TOUTES LES CIBLES ELIMINEES (5/5)</t>"
        } else {
            format ["Cible %1 / 5", _targetIndex]
        };

        hintSilent parseText format [
            "<t color='#ff9933' size='1.2' font='PuristaBold'>[BENCHMARK AGIA MARINA : BASELINE VANILLA]</t><br/>" +
            "<t color='#aaaaaa' size='0.85'>Vue Active :</t> <t color='#ffff00'>%1</t><br/><br/>" +
            "<t color='#ffffff' font='PuristaBold'>--- CHEF DE BINOME (POINTMAN) ---</t><br/>" +
            "Sante : <t color='%2'>%3 HP</t> | Action : <t color='#ff6666'>%4</t><br/><br/>" +
            "<t color='#ffffff' font='PuristaBold'>--- EQUIPIER D'APPUI (WINGMAN) ---</t><br/>" +
            "Sante : <t color='%5'>%6 HP</t> | Action : <t color='#ff6666'>%7</t><br/><br/>" +
            "Progression : <t color='#ffffff'>%8 m / 202 m</t><br/>" +
            "Score Cibles : <t color='#ffff00'>%9 / 5 neutralisees</t><br/>" +
            "Objectif Actuel : <t color='#ffff00'>%10</t><br/><br/>" +
            "<t color='#888888' size='0.8'>Raccourcis : <t color='#ffff00'>F1</t> Reset | <t color='#ffff00'>F2</t> Cycle Camera | <t color='#ffff00'>Y/Z</t> Zeus</t>",
            _camName,
            _hColorLead, _hpLead, (if (_lAlive) then { "SPRINT PLEIN DECOUVERT" } else { "MORT AU COMBAT" }),
            _hColorWing, _hpWing, (if (_wAlive) then { "FORMATION VULNERABLE" } else { "MORT AU COMBAT" }),
            _distAdvanced, _killedCount, _targetStr
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

    player addAction ["<t color='#00ffcc' size='1.2'>[CAMERA] CYCLE CAMERA LEAD / WING / ROOF (F2)</t>", {
        call AAI_fnc_cycleCameraView;
    }, nil, 2.9, false, false, "", "true", 50];

    player addAction ["<t color='#ffcc00' size='1.2'>[ZEUS] VUE AERIENNE RTS (Y / Z)</t>", {
        if (isNull (findDisplay 312)) then { openCuratorInterface; } else { (findDisplay 312) closeDisplay 1; };
    }, nil, 2.7, false, false, "", "true", 50];
};

// Launch trial at start
call AAI_fnc_resetBenchmarkTrial;

diag_log "[AAI Benchmark Agia Marina] Vanilla AI Binome Mission Initialized Successfully.";
