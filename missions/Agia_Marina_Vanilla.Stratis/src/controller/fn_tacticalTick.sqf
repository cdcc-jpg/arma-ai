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
private _distToCurrentCover = if (count _currentCoverPoint >= 2) then { _unit distance2D _currentCoverPoint } else { 999 };

// -------------------------------------------------------------------------
// SPRINT COMMITMENT: If currently bounding to a chosen cover, do NOT recalculate!
// Let the soldier sprint at full speed without stopping, stuttering, or flip-flopping!
// -------------------------------------------------------------------------
if (!_forceRecalc && {_currentState == "MOVING_TO_COVER"} && {count _currentCoverPoint >= 2} && {_distToCurrentCover > 2.0}) exitWith {
    private _lastMoveTime = _unit getVariable ["AAI_LastMoveOrderTime", time];
    // Un-stick safety: only re-issue doMove if unit has been physically stuck for > 2.5s
    if (time - _lastMoveTime > 2.5 && {speed _unit < 0.3}) then {
        _unit setVariable ["AAI_LastMoveOrderTime", time];
        _unit doMove _currentCoverPoint;
    };
    createHashMapFromArray [
        ["state", "MOVING_TO_COVER"],
        ["chosenCover", _currentCoverData],
        ["allCoverCandidates", []],
        ["affordance", _unit getVariable ["AAI_TargetAffordance", createHashMap]],
        ["threat", if (!isNull _activeThreat) then { _activeThreat } else { _threatPos }],
        ["isExposed", _hasLOS]
    ]
};

// Arrival & In-Cover Assessment
private _isInCover = (count _currentCoverPoint >= 2 && {_distToCurrentCover <= 2.0});

if (_isInCover) then {
    if (_unit getVariable ["AAI_CoverArrivalTime", 0] == 0) then {
        _unit setVariable ["AAI_CoverArrivalTime", time];
    };
} else {
    _unit setVariable ["AAI_CoverArrivalTime", 0];
};

private _dwellTime = if (_isInCover) then { time - (_unit getVariable ["AAI_CoverArrivalTime", time]) } else { 0 };

// -------------------------------------------------------------------------
// TACTICAL DWELL: In cover delivering fire from defilade/peek for ~1.2s
// -------------------------------------------------------------------------
private _targetDwell = if ((_unit getVariable ["AAI_TacticalRole", "Rifleman"]) == "Marksman") then { 6.0 } else { 1.2 };
if (!_forceRecalc && {_isInCover} && {_dwellTime < _targetDwell}) exitWith {
    _unit setVariable ["AAI_TacticalState", "IN_COVER"];
    
    // Peek-defilade corner slicing
    private _bestPeekPoint = _currentCoverData getOrDefault ["bestPeekPoint", []];
    private _chosenPoint = _currentCoverPoint;
    
    if (count _bestPeekPoint >= 3 && {!isNull _activeThreat}) then {
        private _peekCycleTime = _unit getVariable ["AAI_PeekCycleTime", 0];
        private _isPeeking = _unit getVariable ["AAI_IsPeeking", false];
        if (time - _peekCycleTime > 0.8) then {
            _isPeeking = !_isPeeking;
            _unit setVariable ["AAI_IsPeeking", _isPeeking];
            _unit setVariable ["AAI_PeekCycleTime", time];
        };
        _chosenPoint = if (_isPeeking) then { _bestPeekPoint } else { _currentCoverPoint };
    };

    [
        _unit,
        _chosenPoint,
        "MIDDLE",
        if (!isNull _activeThreat) then { _activeThreat } else { _threatPos },
        "NORMAL",
        _currentCoverData getOrDefault ["watchPos", _threatPos]
    ] call AAI_fnc_executeMovement;

    createHashMapFromArray [
        ["state", "IN_COVER"],
        ["chosenCover", _currentCoverData],
        ["allCoverCandidates", _unit getVariable ["AAI_CoverShadows", []]],
        ["affordance", _unit getVariable ["AAI_TargetAffordance", createHashMap]],
        ["threat", if (!isNull _activeThreat) then { _activeThreat } else { _threatPos }],
        ["isExposed", _hasLOS],
        ["dwellTime", _dwellTime]
    ]
};

// 3. Perceive Environmental Obstacles
private _obstacles = [_unit, _searchRadius, [], [_unit, _activeThreat]] call AAI_fnc_perceiveObstacles;

// Store perceived obstacles for debug rendering
_unit setVariable ["AAI_PerceivedObstacles", _obstacles];
_unit setVariable ["AAI_ActiveThreat", if (!isNull _activeThreat) then { _activeThreat } else { _threatPos }];

if (count _obstacles == 0) then {
    // Dynamic perception expansion up to 75m
    _obstacles = [_unit, 75.0, [], [_unit, _activeThreat]] call AAI_fnc_perceiveObstacles;
    _unit setVariable ["AAI_PerceivedObstacles", _obstacles];
};

if (count _obstacles == 0) exitWith {
    private _objectivePos = _unit getVariable ["AAI_TacticalObjective", []];
    private _advanceTarget = if (count _objectivePos >= 2) then { _objectivePos } else { _threatPos };
    private _fallbackStance = if (_hasLOS) then { "DOWN" } else { "MIDDLE" };

    _unit setVariable ["AAI_TacticalState", "BOUNDING_ADVANCE"];
    [
        _unit,
        _advanceTarget,
        _fallbackStance,
        if (!isNull _activeThreat) then { _activeThreat } else { _threatPos },
        "FULL",
        _advanceTarget
    ] call AAI_fnc_executeMovement;

    createHashMapFromArray [
        ["state", "BOUNDING_ADVANCE"],
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
    private _objectivePos = _unit getVariable ["AAI_TacticalObjective", []];
    private _advanceTarget = if (count _objectivePos >= 2) then { _objectivePos } else { _threatPos };
    private _fallbackStance = if (_hasLOS) then { "DOWN" } else { "MIDDLE" };

    _unit setVariable ["AAI_TacticalState", "BOUNDING_ADVANCE"];
    [
        _unit,
        _advanceTarget,
        _fallbackStance,
        if (!isNull _activeThreat) then { _activeThreat } else { _threatPos },
        "FULL",
        _advanceTarget
    ] call AAI_fnc_executeMovement;

    createHashMapFromArray [
        ["state", "BOUNDING_ADVANCE"],
        ["chosenCover", createHashMap],
        ["allCoverCandidates", []],
        ["isExposed", _hasLOS]
    ]
};

// 5. Utility & Cost Optimization Function
// Minimize: J = w_dist * d(Unit, Cover) + w_threatDistPenalty - w_quality * Quality - w_height * Height + w_exposure * Exposure
private _bestScore = 1e9;
private _bestCandidate = _candidates select 0;
private _role = _unit getVariable ["AAI_TacticalRole", "Rifleman"];

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

    // Objective attraction: If agent has an active tactical waypoint, favor covers advancing towards it
    private _objectivePos = _unit getVariable ["AAI_TacticalObjective", []];
    private _objectiveCost = 0.0;
    if (count _objectivePos >= 2) then {
        private _distCoverToObj = _cPoint distance2D _objectivePos;
        _objectiveCost = _distCoverToObj * 0.8;
    };

    // Dynamic Maneuver & Leapfrogging Incentive under fire:
    // Assault elements bound after ~1.2s; marksmen hold overwatch for up to 6.0s
    private _maxDwell = if (_role == "Marksman") then { 6.0 } else { 1.2 };
    private _currentCoverPoint = (_unit getVariable ["AAI_TargetCover", createHashMap]) getOrDefault ["coverPoint", []];
    private _maneuverModifier = 0.0;
    if (count _currentCoverPoint > 0) then {
        private _distToCurrent = _cPoint distance2D _currentCoverPoint;
        if (_dwellTime < _maxDwell) then {
            if (_distToCurrent < 1.5) then { _maneuverModifier = -10.0; }; // Hold current spot during active dwell
        } else {
            // Dwell expired: MUST LEAPFROG TO AVOID BEING PINNED!
            if (_distToCurrent < 2.5) then {
                _maneuverModifier = 500.0; // Prohibitive stagnation penalty: NEVER stay at the same cover!
            } else {
                // Must be CLOSER to objective than current cover to be rewarded as a forward assault!
                private _currDistToObj = _currentCoverPoint distance2D _objectivePos;
                private _candDistToObj = _cPoint distance2D _objectivePos;
                if (_candDistToObj < _currDistToObj - 1.5) then {
                    // Forward progress bonus proportional to advance (bounded)
                    _maneuverModifier = -25.0 - ((_currDistToObj - _candDistToObj) min 20.0);
                } else {
                    if (_candDistToObj > _currDistToObj + 2.0) then {
                        _maneuverModifier = 300.0; // Strict penalty: NEVER retreat backwards!
                    };
                };
            };
        };
    };

    // Fireteam Sector Alignment (Strict lateral lane confinement!)
    private _corridorCenter = _unit getVariable ["AAI_TacticalCorridorCenter", []];
    private _corridorHalfWidth = _unit getVariable ["AAI_TacticalCorridorWidth", 2.2];
    private _corridorPenalty = 0.0;
    if (count _corridorCenter >= 2) then {
        // Only penalize LATERAL deviation (X-axis), NEVER longitudinal advance (Y-axis)!
        private _lateralDev = abs ((_cPoint select 0) - (_corridorCenter select 0));
        if (_lateralDev > _corridorHalfWidth) then {
            _corridorPenalty = (_lateralDev - _corridorHalfWidth) * 50.0;
        };
    };

    // Tactical Dispersion: Do NOT crowd teammate covers!
    private _crowdingPenalty = 0.0;
    {
        if (_x != _unit && {alive _x}) then {
            private _claimed = (_x getVariable ["AAI_TargetCover", createHashMap]) getOrDefault ["coverPoint", []];
            if (count _claimed > 0 && {_cPoint distance2D _claimed < 3.8}) then {
                _crowdingPenalty = _crowdingPenalty + 30.0;
            };
        };
    } forEach (units group _unit);

    // Dynamic Semantic Learning Modifier: Query learned penalties/bonuses from Knowledge Graph
    private _kgModifier = ["GET_PENALTY", [_cPoint]] call AAI_fnc_updateKnowledgeGraph;

    // Tactical Role-Based Affordance Modifier
    private _roleBonus = 0.0;
    switch (_role) do {
        case "Marksman": {
            // Distance Standoff Preference: Avoid CQB (< 30m), reward ideal sniping range (40m - 140m)
            if (_distThreatToCover < 30.0) then {
                _roleBonus = -((30.0 - _distThreatToCover) * 2.5); // Penalty for entering close quarters
            } else {
                if (_distThreatToCover >= 40.0 && _distThreatToCover <= 140.0) then {
                    _roleBonus = 12.0; // Optimal sniper kill pocket
                };
            };

            // High Ground Advantage: Commanding terrain elevation or elevated architecture
            if (_height >= 2.2) then { _roleBonus = _roleBonus + 6.0; };
            private _coverElev = getTerrainHeightASL [_cPoint select 0, _cPoint select 1];
            private _threatElev = getTerrainHeightASL [_threatPos select 0, _threatPos select 1];
            if (_coverElev > _threatElev + 1.5) then {
                _roleBonus = _roleBonus + 16.0; // Commanding high-ground vantage bonus
            };
        };
        case "Autorifleman": {
            if (_height >= 0.7 && _height <= 1.4 && _isOccluded) then { _roleBonus = 5.5; };
        };
        case "Medic": {
            if (_isOccluded && _exposureIndex < 0.15) then { _roleBonus = 7.0; } else { _roleBonus = -4.0; };
        };
        case "Breacher": {
            if (_distThreatToCover < 20.0) then { _roleBonus = 5.0; };
        };
        default {};
    };

    // Mutual Bounding Overwatch: If a fireteam buddy is IN_COVER, advance with bounding confidence
    private _buddies = (units group _unit) select { _x != _unit && {alive _x} };
    private _overwatchActive = false;
    {
        if ((_x getVariable ["AAI_TacticalState", "IDLE"]) == "IN_COVER") exitWith {
            _overwatchActive = true;
        };
    } forEach _buddies;
    private _overwatchBonus = if (_overwatchActive) then { 3.5 } else { 0.0 };

    // Field of Fire / Sector Engagement Utility
    // Reward covers that offer clear corner peeking into the street; penalize dead-ends
    private _canShootL = _c getOrDefault ["canShootLeft", false];
    private _canShootR = _c getOrDefault ["canShootRight", false];
    private _fieldOfFireBonus = if (_canShootL || _canShootR) then { 5.0 } else { -3.5 };

    // Cost formula
    private _cost = (_distFromUnit * _wDist) 
                  + (_exposureIndex * _wExposure) 
                  + _occlusionPenalty 
                  + _wThreatProximity 
                  + _objectiveCost 
                  + _corridorPenalty
                  + _crowdingPenalty
                  + _kgModifier 
                  + _maneuverModifier
                  - (_quality * _wQuality) 
                  - ((_height min 2.0) * _wHeight)
                  - _roleBonus
                  - _overwatchBonus
                  - _fieldOfFireBonus;

    _c set ["costScore", _cost];
    _c set ["kgModifier", _kgModifier];
    _c set ["roleBonus", _roleBonus];

    if (_cost < _bestScore) then {
        _bestScore = _cost;
        _bestCandidate = _c;
    };
} forEach _candidates;

// 6. State Transition & Actuation Dispatch
private _chosenAffordance = _bestCandidate getOrDefault ["affordance", createHashMap];
private _coverPoint = _bestCandidate getOrDefault ["coverPoint", getPosATL _unit];
private _bestPeekPoint = _bestCandidate getOrDefault ["bestPeekPoint", []];
private _watchPos = _bestCandidate getOrDefault ["watchPos", _threatPos];

// Check proximity to chosen cover anchor
private _distToCover = _unit distance2D _coverPoint;
private _isAtCover = (_distToCover <= 2.5);

private _chosenPoint = _coverPoint;
private _chosenStance = "MIDDLE";

// Peek-Defilade Cycle: ONLY activates once the unit has safely arrived at cover!
if (_isAtCover && {count _bestPeekPoint >= 3} && {!isNull _activeThreat}) then {
    private _peekCycleTime = _unit getVariable ["AAI_PeekCycleTime", 0];
    private _isPeeking = _unit getVariable ["AAI_IsPeeking", false];

    if (time - _peekCycleTime > (if (_isPeeking) then { 1.5 } else { 2.2 })) then {
        _isPeeking = !_isPeeking;
        _unit setVariable ["AAI_IsPeeking", _isPeeking];
        _unit setVariable ["AAI_PeekCycleTime", time];
    };

    if (_isPeeking) then {
        // PEEK PHASE: Step to corner to fire down the street
        _chosenPoint = _bestPeekPoint;
        _chosenStance = _chosenAffordance getOrDefault ["stance", "MIDDLE"];
    } else {
        // DEFILADE PHASE: Step back behind the solid wall in safety
        _chosenPoint = _coverPoint;
        _chosenStance = "MIDDLE";
    };
} else {
    // IN TRANSIT: Run directly to the solid cover anchor without oscillating!
    _chosenPoint = _coverPoint;
    _chosenStance = "MIDDLE";
    _unit setVariable ["AAI_IsPeeking", false];
};

// Check proximity to chosen destination
private _distToGoal = _unit distance2D _chosenPoint;

// Fireteam Pair Bounding Synchronization (Appui vs Assaut)
private _buddy = _unit getVariable ["AAI_BuddyUnit", objNull];
private _pairRole = _unit getVariable ["AAI_PairRole", "BASE_OF_FIRE"];

if (!isNull _buddy && {alive _buddy}) then {
    private _buddyIsCovering = _buddy getVariable ["AAI_IsProvidingCover", false];
    
    if (_pairRole == "BASE_OF_FIRE") then {
        if (_distToGoal <= 2.0) then {
            _unit setVariable ["AAI_IsProvidingCover", true];
            if (_dwellTime > 3.5 && {(_buddy distance2D ((_buddy getVariable ["AAI_TargetCover", createHashMap]) getOrDefault ["coverPoint", [0,0,0]])) < 2.5}) then {
                _unit setVariable ["AAI_PairRole", "MANEUVER"];
                _unit setVariable ["AAI_IsProvidingCover", false];
                _unit setVariable ["AAI_CoverDwellTime", 0.0];
            };
        };
    } else {
        if (!_buddyIsCovering && {_distToGoal <= 2.0 && count _currentCoverPoint > 0}) then {
            _chosenPoint = _currentCoverPoint;
        } else {
            if (_distToGoal <= 1.8) then {
                _unit setVariable ["AAI_PairRole", "BASE_OF_FIRE"];
                _unit setVariable ["AAI_IsProvidingCover", true];
                _buddy setVariable ["AAI_PairRole", "MANEUVER"];
                _buddy setVariable ["AAI_IsProvidingCover", false];
            };
        };
    };
};

_unit setVariable ["AAI_TargetCover", _bestCandidate];
_unit setVariable ["AAI_TargetAffordance", _chosenAffordance];
_unit setVariable ["AAI_TargetWatchPos", _watchPos];

private _newState = if (_distToGoal <= 1.8) then {
    _unit setVariable ["AAI_CoverDwellTime", _dwellTime + 1.0];
    "IN_COVER"
} else {
    _unit setVariable ["AAI_CoverDwellTime", 0.0];
    "MOVING_TO_COVER"
};

_unit setVariable ["AAI_TacticalState", _newState];

// Format TICO ABox episodic decision log
private _obsObj = _bestCandidate get "obstacle";
private _obsData = _bestCandidate getOrDefault ["obstacleData", createHashMap];
private _obsType = if (_obsData isEqualType createHashMap) then { _obsData getOrDefault ["typeName", "Cover"] } else { typeOf _obsObj };
private _obsHeight = if (_obsData isEqualType createHashMap) then { _obsData getOrDefault ["height", 1.0] } else { 1.0 };
private _quality = _bestCandidate getOrDefault ["qualityScore", 0];
private _affordanceName = _chosenAffordance getOrDefault ["name", "tac:SolidCover"];

private _unitTag = if (name _unit == "Error: No unit" || name _unit == "") then { typeOf _unit } else { name _unit };
private _callsign = _unit getVariable ["AAI_Callsign", _unitTag];
private _matClass = _bestCandidate getOrDefault ["materialClass", "ReinforcedConcrete"];
private _penRes = _bestCandidate getOrDefault ["penetrationResistance", 1.0];

private _logMsg = format [
    "[%1 | %2] Grounded %3 (%4, h=%5m, PR=%6) -> Affords %7 (Stance: %8, Q: %9, J: %10)",
    _callsign,
    _role,
    _obsType,
    _matClass,
    (round (_obsHeight * 10)) / 10,
    round (_penRes * 100) / 100,
    _affordanceName,
    _chosenStance,
    (round (_quality * 100)) / 100,
    (round (_bestScore * 100)) / 100
];

_unit setVariable ["AAI_LastSemanticLog", _logMsg];
_unit setVariable ["AAI_BestCostScore", _bestScore];
_unit setVariable ["AAI_CandidateCount", count _candidates];
_unit setVariable ["AAI_ChosenObstacleType", _obsType];
_unit setVariable ["AAI_AffordanceType", _affordanceName];

diag_log format ["[TICO ONTOLOGY ENGINE] %1", _logMsg];

// Execute actuation with dedicated sector watch position
[
    _unit,
    _chosenPoint,
    _chosenStance,
    if (!isNull _activeThreat) then { _activeThreat } else { _threatPos },
    "FULL",
    _watchPos
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
