/*
    Author: Clement D. / Arma-AI Team
    File: fn_tacticalTick.sqf
    Tag: AAI_fnc_tacticalTick

    Description:
        Core tactical evaluation cycle for autonomous infantry agents.
        Evaluates current threat kinematics, line-of-sight exposure, invokes spatial grounding
        to extract environmental affordances (cover shadows, stance requirements),
        computes an optimal cover utility score across all candidates, selects the minimum-exposure
        tactical position, and dispatches the actuation commands via AAI_fnc_executeMovement.

    Parameters:
        0: _unit         - The tactical agent unit (OBJECT) [Default: player]
        1: _threat       - Active threat unit or position (OBJECT or ARRAY) [Default: objNull]
        2: _searchRadius - Radius in meters for obstacle perception (NUMBER) [Default: 45.0]
        3: _forceRecalc  - Force re-evaluation even if currently safe in cover (BOOLEAN) [Default: false]

    Returns:
        HASHMAP containing tick results:
            - "state": STRING ("IN_COVER" | "MOVING_TO_COVER" | "NO_COVER_FOUND" | "THREAT_LOST" | "DEAD")
            - "chosenCover": HASHMAP (Selected cover shadow data)
            - "allCoverCandidates": ARRAY of HASHMAPs
            - "affordance": HASHMAP (Stance affordance for selected cover)
            - "threat": OBJECT or ARRAY
            - "isExposed": BOOLEAN (Current line of sight status)

    Example:
        private _tickResult = [tactical_agent, opfor_threat, 40] call AAI_fnc_tacticalTick;
*/

params [
    ["_unit", player, [objNull]],
    ["_threat", objNull, [objNull, []]],
    ["_searchRadius", 45.0, [0]],
    ["_forceRecalc", false, [true]]
];

if (!alive _unit) exitWith {
    createHashMapFromArray [["state", "DEAD"], ["isExposed", false]]
};

// 1. Resolve Active Threat
private _activeThreat = objNull;
private _threatPos = [0,0,0];

if (_threat isEqualType objNull) then {
    if (!isNull _threat && {alive _threat}) then {
        _activeThreat = _threat;
        _threatPos = eyePos _threat;
    };
} else {
    if (count _threat >= 2) then {
        _threatPos = if (count _threat == 2) then { [_threat select 0, _threat select 1, 1.5] } else { _threat };
    };
};

// If no explicit threat passed, search for nearest known enemy
if (isNull _activeThreat && {_threatPos isEqualTo [0,0,0]}) then {
    private _nearestEnemy = _unit findNearestEnemy _unit;
    if (!isNull _nearestEnemy && {alive _nearestEnemy}) then {
        _activeThreat = _nearestEnemy;
        _threatPos = eyePos _nearestEnemy;
    } else {
        // Fallback: search for any living hostile unit in 300m
        private _hostiles = (allUnits select {side _x != side _unit && {side _x != civilian} && {alive _x} && {(_unit distance _x) < 300}});
        if (count _hostiles > 0) then {
            // Sort by distance
            _hostiles = [_hostiles, [], { _unit distance _x }, "ASCEND"] call BIS_fnc_sortBy;
            _activeThreat = _hostiles select 0;
            _threatPos = eyePos _activeThreat;
        };
    };
};

if (isNull _activeThreat && {_threatPos isEqualTo [0,0,0]}) exitWith {
    _unit setVariable ["AAI_TacticalState", "THREAT_LOST"];
    createHashMapFromArray [
        ["state", "THREAT_LOST"],
        ["chosenCover", createHashMap],
        ["allCoverCandidates", []],
        ["isExposed", false]
    ]
};

// 2. Assess Current Exposure to Threat
private _unitEyePos = eyePos _unit;
private _losIntersections = lineIntersectsSurfaces [
    _threatPos,
    _unitEyePos,
    if (!isNull _activeThreat) then { _activeThreat } else { objNull },
    _unit,
    true,
    1,
    "GEOM",
    "FIRE"
];

private _hasLOS = (count _losIntersections == 0);
if (_hasLOS && {!isNull _activeThreat}) then {
    // Double check terrain LOS
    if (terrainIntersectASL [_threatPos, _unitEyePos]) then {
        _hasLOS = false;
    };
};

private _currentCoverData = _unit getVariable ["AAI_TargetCover", createHashMap];
private _currentState = _unit getVariable ["AAI_TacticalState", "IDLE"];
private _currentCoverPoint = _currentCoverData getOrDefault ["coverPoint", []];

// Check if we are already sitting securely in assigned cover and not forced to move
if (!_forceRecalc && {!_hasLOS} && {count _currentCoverPoint > 0} && {(_unit distance2D _currentCoverPoint) < 1.35}) then {
    _unit setVariable ["AAI_TacticalState", "IN_COVER"];
    // Maintain watch on threat direction
    _unit doWatch _threatPos;
    
    // Return early preserving current safe state
    createHashMapFromArray [
        ["state", "IN_COVER"],
        ["chosenCover", _currentCoverData],
        ["allCoverCandidates", _unit getVariable ["AAI_CoverShadows", []]],
        ["affordance", _unit getVariable ["AAI_TargetAffordance", createHashMap]],
        ["threat", if (!isNull _activeThreat) then { _activeThreat } else { _threatPos }],
        ["isExposed", false]
    ]
};

// 3. Perceive Environmental Obstacles
private _obstacles = [_unit, _searchRadius, [], [_unit, _activeThreat]] call AAI_fnc_perceiveObstacles;

// Store perceived obstacles for debug rendering
_unit setVariable ["AAI_PerceivedObstacles", _obstacles];
_unit setVariable ["AAI_ActiveThreat", if (!isNull _activeThreat) then { _activeThreat } else { _threatPos }];

if (count _obstacles == 0) exitWith {
    _unit setVariable ["AAI_TacticalState", "NO_COVER_FOUND"];
    // Fallback: If under fire without cover, go prone and face threat
    if (_hasLOS) then {
        _unit setUnitPos "DOWN";
        _unit setSpeedMode "FULL";
    };
    createHashMapFromArray [
        ["state", "NO_COVER_FOUND"],
        ["chosenCover", createHashMap],
        ["allCoverCandidates", []],
        ["isExposed", _hasLOS]
    ]
};

// 4. Compute Cover Shadows & Stance Affordances for each candidate
private _candidates = [];
{
    private _shadow = [_unit, _x, if (!isNull _activeThreat) then { _activeThreat } else { _threatPos }] call AAI_fnc_computeCoverShadow;
    if (count keys _shadow > 0) then {
        private _coverPt = _shadow get "coverPoint";
        private _affordance = [_x get "height", _threatPos, _coverPt] call AAI_fnc_evaluateStanceAffordance;
        _shadow set ["affordance", _affordance];
        _shadow set ["obstacleData", _x];
        _candidates pushBack _shadow;
    };
} forEach _obstacles;

_unit setVariable ["AAI_CoverShadows", _candidates];

if (count _candidates == 0) exitWith {
    _unit setVariable ["AAI_TacticalState", "NO_COVER_FOUND"];
    createHashMapFromArray [
        ["state", "NO_COVER_FOUND"],
        ["chosenCover", createHashMap],
        ["allCoverCandidates", []],
        ["isExposed", _hasLOS]
    ]
};

// 5. Utility & Cost Optimization Function
// Minimize: J = w_dist * d(Unit, Cover) + w_threatDistPenalty - w_quality * Quality - w_height * Height + w_exposure * Exposure
private _bestScore = 1e9;
private _bestCandidate = _candidates select 0;

{
    private _c = _x;
    private _cPoint = _c get "coverPoint";
    private _affordance = _c get "affordance";
    private _quality = _c getOrDefault ["qualityScore", 0.5];
    private _isOccluded = _c getOrDefault ["isOccluded", true];
    private _height = _c getOrDefault ["height", 1.0];
    private _exposureIndex = _affordance getOrDefault ["exposureIndex", 0.2];

    private _distFromUnit = _unit distance2D _cPoint;
    private _distThreatToCover = _threatPos distance2D _cPoint;

    // Weight parameters
    private _wDist = 1.0;            // Movement cost (prefer close cover)
    private _wQuality = 6.0;         // Bonus for solid, verified occluded cover
    private _wExposure = 8.0;        // Penalty for exposure
    private _wHeight = 2.5;          // Bonus for tall cover (allows standing & speed)
    private _wThreatProximity = 0.0; // Penalty if cover is dangerously close to threat (< 6m)

    if (_distThreatToCover < 6.0) then {
        _wThreatProximity = (6.0 - _distThreatToCover) * 3.0;
    };

    // Huge penalty if the computed point fails LOS raycast occlusion
    private _occlusionPenalty = if (_isOccluded) then { 0.0 } else { 20.0 };

    // Cost formula
    private _cost = (_distFromUnit * _wDist) 
                  + (_exposureIndex * _wExposure) 
                  + _occlusionPenalty 
                  + _wThreatProximity 
                  - (_quality * _wQuality) 
                  - ((_height min 2.0) * _wHeight);

    _c set ["costScore", _cost];

    if (_cost < _bestScore) then {
        _bestScore = _cost;
        _bestCandidate = _c;
    };
} forEach _candidates;

// 6. State Transition & Actuation Dispatch
private _chosenPoint = _bestCandidate get "coverPoint";
private _chosenAffordance = _bestCandidate get "affordance";
private _chosenStance = _chosenAffordance getOrDefault ["stance", "MIDDLE"];

_unit setVariable ["AAI_TargetCover", _bestCandidate];
_unit setVariable ["AAI_TargetAffordance", _chosenAffordance];

// Check if unit is already at the destination
private _distToGoal = _unit distance2D _chosenPoint;
private _newState = "MOVING_TO_COVER";

if (_distToGoal <= 1.25) then {
    _newState = "IN_COVER";
};

_unit setVariable ["AAI_TacticalState", _newState];

// Execute actuation
[
    _unit,
    _chosenPoint,
    _chosenStance,
    if (!isNull _activeThreat) then { _activeThreat } else { _threatPos },
    "FULL"
] call AAI_fnc_executeMovement;

createHashMapFromArray [
    ["state", _newState],
    ["chosenCover", _bestCandidate],
    ["allCoverCandidates", _candidates],
    ["affordance", _chosenAffordance],
    ["threat", if (!isNull _activeThreat) then { _activeThreat } else { _threatPos }],
    ["isExposed", _hasLOS],
    ["bestCost", _bestScore]
]
