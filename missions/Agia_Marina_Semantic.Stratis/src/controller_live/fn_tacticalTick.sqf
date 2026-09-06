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

// 1. Resolve Active Threat (Legitimate Perception - No Omniscience)
private _activeThreat = objNull;
private _threatPos = [0,0,0];
private _isAnticipatedThreat = false;

if (_threat isEqualType objNull) then {
    if (!isNull _threat && {alive _threat}) then {
        // Only accept threat if unit legitimately knows about it or has clear line of sight
        if (_unit knowsAbout _threat > 0.5 || {([_unit, "VIEW", _threat] checkVisibility [eyePos _unit, eyePos _threat]) > 0.2}) then {
            _activeThreat = _threat;
            _threatPos = eyePos _threat;
        };
    };
} else {
    if (count _threat >= 2) then {
        _threatPos = if (count _threat == 2) then { [_threat select 0, _threat select 1, 1.5] } else { _threat };
    };
};

// Check sensory perception (sight / sound)
if (isNull _activeThreat && {_threatPos isEqualTo [0,0,0]}) then {
    private _nearestEnemy = _unit findNearestEnemy _unit;
    if (!isNull _nearestEnemy && {alive _nearestEnemy} && {_unit knowsAbout _nearestEnemy > 0.5}) then {
        _activeThreat = _nearestEnemy;
        _threatPos = eyePos _nearestEnemy;
    } else {
        // Direct visual raycast sweep: check if any hostile within 120m is in direct line of sight
        private _hostiles = (allUnits select {
            side _x != side _unit && 
            {side _x != civilian} && 
            {alive _x} && 
            {(_unit distance _x) < 120} &&
            {([_unit, "VIEW", _x] checkVisibility [eyePos _unit, eyePos _x]) > 0.25}
        });
        if (count _hostiles > 0) then {
            _hostiles = [_hostiles, [], { _unit distance _x }, "ASCEND"] call BIS_fnc_sortBy;
            _activeThreat = _hostiles select 0;
            _threatPos = eyePos _activeThreat;
            _unit reveal [_activeThreat, 4];
            systemChat format ["[TICO ONTOLOGIE] CONTACT VISUEL ! Ennemi repere a %1m !", round (_unit distance _activeThreat)];
        };
    };
};

// If NO enemy is currently perceived: Construct an ANTICIPATED THREAT VECTOR (tac:ThreatVector)
if (isNull _activeThreat && {_threatPos isEqualTo [0,0,0]}) then {
    _isAnticipatedThreat = true;
    private _objectivePos = _unit getVariable ["AAI_TacticalObjective", []];
    private _unitPosATL = getPosATL _unit;
    private _advanceDir = if (count _objectivePos >= 2) then {
        private _diff = [(_objectivePos select 0) - (_unitPosATL select 0), (_objectivePos select 1) - (_unitPosATL select 1), 0];
        if (vectorMagnitude _diff > 0.1) then { vectorNormalized _diff } else { [sin (getDir _unit), cos (getDir _unit), 0] };
    } else {
        [sin (getDir _unit), cos (getDir _unit), 0]
    };

    // Anticipate potential hostile fire 45m ahead along the street/advance avenue
    private _anticipatedATL = _unitPosATL vectorAdd (_advanceDir vectorMultiply 45.0);
    _anticipatedATL set [2, (_unitPosATL select 2) + 1.5];
    _threatPos = ATLToASL _anticipatedATL;
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
// Arrival & In-Cover Assessment:
// Within 2.5m of cover anchor, OR within 3.8m after 2.5s of transit, OR stopped/ready within 3.2m
private _lastMoveTime = _unit getVariable ["AAI_LastMoveOrderTime", time];
private _moveStartTime = _unit getVariable ["AAI_MoveStartTime", time];
private _transitDuration = time - _moveStartTime;

private _isArrived = (count _currentCoverPoint >= 2 && {
    _distToCurrentCover <= 2.8 
    || (_distToCurrentCover <= 4.5 && {_transitDuration > 2.0} && {speed _unit < 0.7}) 
    || (_distToCurrentCover <= 4.0 && {_transitDuration > 2.5}) 
    || (_distToCurrentCover <= 3.5 && {unitReady _unit} && {time - _lastMoveTime > 0.3})
});

// SPRINT COMMITMENT: If currently bounding to a chosen cover and hasn't reached arrival yet
if (!_forceRecalc && {_currentState == "MOVING_TO_COVER"} && {count _currentCoverPoint >= 2} && {!_isArrived}) exitWith {
    // Keep sprint momentum and upright posture while bounding to cover!
    if (unitPos _unit != "UP") then { _unit setUnitPos "UP"; };
    _unit forceSpeed 15;
    _unit doWatch objNull;

    // Robust Un-stick & Transit Timeout Safety:
    // Allow long sprints (up to 32m across bridges/riverbeds taking 6-7s).
    // Only abort if sprint exceeds 8.0s and still far, or physically stationary for > 2.2s.
    if ((_transitDuration > 8.0 && {_distToCurrentCover > 4.5}) || {time - _lastMoveTime > 2.2 && {speed _unit < 0.20}}) then {
        _unit setVariable ["AAI_LastMoveOrderTime", time];
        _unit setVariable ["AAI_MoveStartTime", time];
        _unit setVariable ["AAI_TacticalState", "RECALCULATING"];
        // Temporarily penalize this unreachable candidate
        private _visList = _unit getVariable ["AAI_VisitedCoverPoints", []];
        _visList pushBack [_currentCoverPoint, time];
        _unit setVariable ["AAI_VisitedCoverPoints", _visList];
    } else {
        if (time - _lastMoveTime > 1.0 && {speed _unit < 0.8}) then {
            _unit setVariable ["AAI_LastMoveOrderTime", time];
            _unit doMove _currentCoverPoint;
        };
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

private _isInCover = _isArrived;

if (_isInCover) then {
    if (_unit getVariable ["AAI_CoverArrivalTime", 0] == 0) then {
        _unit setVariable ["AAI_CoverArrivalTime", time];
    };
    _unit setVariable ["AAI_CrossingAnnounced", false];
} else {
    _unit setVariable ["AAI_CoverArrivalTime", 0];
};

private _dwellTime = if (_isInCover) then { time - (_unit getVariable ["AAI_CoverArrivalTime", time]) } else { 0 };

// -------------------------------------------------------------------------
// TACTICAL DWELL: Sector Clearance & Pieing the Corner ("Faire la tarte")
// -------------------------------------------------------------------------
// Initiates early from wide standoff (3.8m - 5.0m) to clear danger zones
// before ever exposing body silhouette to pre-aimed defenders.
private _targetDwell = if ((_unit getVariable ["AAI_TacticalRole", "Rifleman"]) == "Marksman") then { 
    6.0 
} else { 
    if (_isAnticipatedThreat) then { 2.4 } else { 1.4 } 
};

private _activeObs = _currentCoverData getOrDefault ["obstacle", objNull];
private _clearedObstacles = _unit getVariable ["AAI_ClearedObstacles", []];
private _isObstacleCleared = (!isNull _activeObs && {_activeObs in _clearedObstacles});

if (!_forceRecalc && {_isInCover} && {!_isObstacleCleared} && {_dwellTime < _targetDwell}) exitWith {
    private _bestPeekPoint = _currentCoverData getOrDefault ["bestPeekPoint", []];
    private _cornerSlices = _unit getVariable ["AAI_CurrentCornerSlices", []];
    private _cachedCover = _unit getVariable ["AAI_SlicesCoverPoint", []];
    private _isDifferentObstacle = (_cachedCover isEqualTo [] || {(_cachedCover distance2D _currentCoverPoint) > 3.0});

    // Compute 5 progressive CQB quadrant slices along a wide standoff arc (3.8m back from corner)
    if (_cornerSlices isEqualTo [] || {_isDifferentObstacle}) then {
        private _dangerTarget = if (!isNull _activeThreat) then { eyePos _activeThreat } else {
            private _obj = _unit getVariable ["AAI_TacticalObjective", []];
            if (count _obj >= 2) then { _obj } else { _threatPos }
        };

        if (count _bestPeekPoint >= 2) then {
            _cornerSlices = [
                _unit,
                _bestPeekPoint,
                _currentCoverPoint,
                _dangerTarget,
                5,
                3.80
            ] call AAI_fnc_computeCornerSlices;
            _unit setVariable ["AAI_CurrentCornerSlices", _cornerSlices];
            _unit setVariable ["AAI_SlicesCoverPoint", _currentCoverPoint];
            _unit setVariable ["AAI_CurrentSliceIndex", 1];
            _unit setVariable ["AAI_SliceStepTime", time];
            _unit setVariable ["AAI_CornerCleared", false];
            _unit setVariable ["AAI_LeadWaitingForWingman", false];
            _unit setVariable ["AAI_LeadWaitStartTime", time];
            [_unit, "Zone de danger à l'angle ! Découpage en cours...", "DANGER"] call AAI_fnc_tacticalRadio;
        };
    };

    private _sliceIndex = _unit getVariable ["AAI_CurrentSliceIndex", 1];
    private _sliceStepTime = _unit getVariable ["AAI_SliceStepTime", time];
    private _totalSlices = count _cornerSlices;

    // Resolve active slice waypoint and tangent watch vector
    private _chosenPoint = _currentCoverPoint;
    private _watchPos = _currentCoverData getOrDefault ["watchPos", _threatPos];
    private _sliceAngle = 0;

    if (_totalSlices > 0) then {
        private _safeIdx = (_sliceIndex min _totalSlices) - 1;
        private _activeSlice = _cornerSlices select _safeIdx;
        _chosenPoint = _activeSlice getOrDefault ["pos", _currentCoverPoint];
        _watchPos = _activeSlice getOrDefault ["watchPos", _threatPos];
        _sliceAngle = _activeSlice getOrDefault ["angleDeg", 0];
    };

    // Active visual sweep: Check if any hostile in sector is revealed by this slice
    private _eyePosASL = eyePos _unit;
    private _spottedEnemy = objNull;
    {
        if (side _x != side _unit && {side _x != civilian} && {alive _x} && {(_unit distance _x) < 130}) then {
            private _targetEye = eyePos _x;
            private _vis = [_unit, "VIEW", _x] checkVisibility [_eyePosASL, _targetEye];
            if (_vis > 0.12) exitWith {
                _spottedEnemy = _x;
            };
        };
    } forEach allUnits;

    private _hasActiveContact = false;
    if (!isNull _spottedEnemy) then {
        _hasActiveContact = true;
        _unit reveal [_spottedEnemy, 4];
        (group _unit) reveal [_spottedEnemy, 4];
        _activeThreat = _spottedEnemy;
        _threatPos = eyePos _spottedEnemy;
        _watchPos = eyePos _spottedEnemy;
        _unit setVariable ["AAI_ActiveThreat", _spottedEnemy];
        {
            if (_x != _unit && {alive _x}) then {
                _x setVariable ["AAI_ActiveThreat", _spottedEnemy];
            };
        } forEach (units group _unit);
        // Lock onto enemy from this slice: do not advance to next slice while engaging!
        _unit setVariable ["AAI_SliceStepTime", time];

        // RADIO CALLOUT: CONTACT!
        [_unit, format ["CONTACT ENNEMI %1m ! FEU !", round (_unit distance _spottedEnemy)], "CONTACT"] call AAI_fnc_tacticalRadio;

        // INSTANT LETHAL PRE-EMPTIVE BURST (ZERO DELAY!)
        _unit doTarget _spottedEnemy;
        _unit doWatch _spottedEnemy;
        _unit forceWeaponFire [currentMuzzle _unit, "Single"];
        _unit forceWeaponFire [currentMuzzle _unit, "Single"];
        _unit forceWeaponFire [currentMuzzle _unit, "Single"];

        // Alert teammate to lay down crossfire
        private _buddyUnit = _unit getVariable ["AAI_BuddyUnit", objNull];
        if (!isNull _buddyUnit && {alive _buddyUnit}) then {
            _buddyUnit setVariable ["AAI_ActiveThreat", _spottedEnemy];
            _buddyUnit doTarget _spottedEnemy;
            _buddyUnit doWatch _spottedEnemy;
            _buddyUnit forceWeaponFire [currentMuzzle _buddyUnit, "Single"];
            _buddyUnit forceWeaponFire [currentMuzzle _buddyUnit, "Single"];
            [_buddyUnit, "Ennemi pris pour cible ! Tir d'appui croisé !", "CONTACT"] call AAI_fnc_tacticalRadio;
        };

        systemChat format ["[TICO ONTOLOGIE] ENNEMI ACQUIS DANS LA TRANCHE %1/5 (%2m, Angle: %3 deg) ! TIR IMMEDIAT !", _sliceIndex min _totalSlices, round (_unit distance _spottedEnemy), _sliceAngle];
    } else {
        // No enemy spotted in current slice: advance to next quadrant with fluid CQB cadence (0.22s)
        if (time - _sliceStepTime > 0.22) then {
            if (_sliceIndex < _totalSlices) then {
                _sliceIndex = _sliceIndex + 1;
                _unit setVariable ["AAI_CurrentSliceIndex", _sliceIndex];
                _unit setVariable ["AAI_SliceStepTime", time];
            } else {
                _unit setVariable ["AAI_IsProvidingCover", true];
                if (!(_unit getVariable ["AAI_CornerCleared", false])) then {
                    _unit setVariable ["AAI_CornerCleared", true];
                    if (!isNull _activeObs) then {
                        _clearedObstacles pushBackUnique _activeObs;
                        _unit setVariable ["AAI_ClearedObstacles", _clearedObstacles];
                    };
                    if (_unit == leader (group _unit)) then {
                        _unit setVariable ["AAI_LeadWaitingForWingman", true];
                        _unit setVariable ["AAI_LeadWaitStartTime", time];
                    };
                    [_unit, "Secteur clair ! À toi de bondir, je te couvre !", "ORDER"] call AAI_fnc_tacticalRadio;
                };
            };
        };
    };

    // Sub-state telemetry
    private _subState = if (_hasActiveContact) then {
        format ["PIE_FIRING [%1/%2] (%3 deg)", _sliceIndex min _totalSlices, _totalSlices, _sliceAngle]
    } else {
        format ["PIE_SLICING [%1/%2] (%3 deg)", _sliceIndex min _totalSlices, _totalSlices, _sliceAngle]
    };
    _unit setVariable ["AAI_TacticalState", _subState];

    [
        _unit,
        _chosenPoint,
        "MIDDLE",
        if (!isNull _activeThreat) then { _activeThreat } else { _threatPos },
        "LIMITED",
        _watchPos
    ] call AAI_fnc_executeMovement;

    createHashMapFromArray [
        ["state", _subState],
        ["chosenCover", _currentCoverData],
        ["allCoverCandidates", _unit getVariable ["AAI_CoverShadows", []]],
        ["affordance", _unit getVariable ["AAI_TargetAffordance", createHashMap]],
        ["threat", if (!isNull _activeThreat) then { _activeThreat } else { _threatPos }],
        ["isExposed", _hasLOS],
        ["dwellTime", _dwellTime],
        ["sliceIndex", _sliceIndex],
        ["sliceAngle", _sliceAngle]
    ]
};

// 2.1 Track recently departed covers to prevent oscillation / ping-pong loops
private _visitedCovers = _unit getVariable ["AAI_VisitedCoverPoints", []];
_visitedCovers = _visitedCovers select { (time - (_x select 1)) < 45.0 };

// A cover is only recorded as visited once the unit has vacated and moved past it (> 2.5m away)
private _lastSettledCover = _unit getVariable ["AAI_LastSettledCoverPoint", []];
if (_isInCover && {count _currentCoverPoint >= 2}) then {
    _unit setVariable ["AAI_LastSettledCoverPoint", _currentCoverPoint];
    private _coverHist = _unit getVariable ["AAI_RecentCoverHistory", []];
    if ({_x distance2D _currentCoverPoint < 3.0} count _coverHist == 0) then {
        _coverHist pushBack _currentCoverPoint;
        if (count _coverHist > 4) then { _coverHist deleteAt 0; };
        _unit setVariable ["AAI_RecentCoverHistory", _coverHist];
    };
} else {
    if (count _lastSettledCover >= 2 && {_unit distance2D _lastSettledCover > 2.5}) then {
        if ({(_x select 0) distance2D _lastSettledCover < 3.0} count _visitedCovers == 0) then {
            _visitedCovers pushBack [_lastSettledCover, time];
        };
        _unit setVariable ["AAI_LastSettledCoverPoint", []];
    };
};
_unit setVariable ["AAI_VisitedCoverPoints", _visitedCovers];

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
    private _fallbackSpeed = if (_hasLOS && {!isNull _activeThreat}) then { "FULL" } else { "NORMAL" };
    [
        _unit,
        _advanceTarget,
        _fallbackStance,
        if (!isNull _activeThreat) then { _activeThreat } else { _threatPos },
        _fallbackSpeed,
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
    private _fallbackSpeed = if (_hasLOS && {!isNull _activeThreat}) then { "FULL" } else { "NORMAL" };
    [
        _unit,
        _advanceTarget,
        _fallbackStance,
        if (!isNull _activeThreat) then { _activeThreat } else { _threatPos },
        _fallbackSpeed,
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

    // Objective attraction & forward advance
    private _objectivePos = _unit getVariable ["AAI_TacticalObjective", []];
    private _objectiveCost = 0.0;
    private _retreatPenalty = 0.0;
    private _boundPenalty = 0.0;

    if (count _objectivePos >= 2) then {
        private _unitDistToObj = _unit distance2D _objectivePos;
        private _distCoverToObj = _cPoint distance2D _objectivePos;
        _objectiveCost = _distCoverToObj * 2.0;

        // High-water mark ratchet: track closest distance reached to current objective
        private _minDistToObj = _unit getVariable ["AAI_MinDistToObjective", 9999];
        if (_unitDistToObj < _minDistToObj) then {
            _minDistToObj = _unitDistToObj;
            _unit setVariable ["AAI_MinDistToObjective", _minDistToObj];
        };

        // Strict penalty for candidate covers further from objective than unit's current position (+1.0m tolerance)
        if (_distCoverToObj > _unitDistToObj + 1.0) then {
            _retreatPenalty = 500.0 + ((_distCoverToObj - _unitDistToObj) * 40.0);
        };

        // Strict ratchet barrier: never regress further than the closest point achieved towards this objective
        if (_distCoverToObj > _minDistToObj + 2.5) then {
            _retreatPenalty = _retreatPenalty + 800.0;
        };
    };

    // Tactical CQB & Bridge Crossing Bounding Range: Allow athletic sprints up to 32m!
    // Crucial for crossing open danger areas (dry riverbeds, culverts, road bridges, town plazas)
    // Only progressively penalize beyond 32m to avoid map-wide leaps
    if (_distFromUnit > 32.0) then {
        _boundPenalty = (_distFromUnit - 32.0) * 12.0;
    };

    // Dynamic Maneuver & Leapfrogging Incentive under fire:
    // Assault elements bound after ~1.2s; marksmen hold overwatch for up to 6.0s
    private _maxDwell = if (_role == "Marksman") then { 
        6.0 
    } else { 
        if (_isAnticipatedThreat) then { 2.4 } else { 1.4 } 
    };
    private _currentCoverPoint = (_unit getVariable ["AAI_TargetCover", createHashMap]) getOrDefault ["coverPoint", []];
    private _maneuverModifier = 0.0;
    if (count _currentCoverPoint > 0 && {count _objectivePos >= 2}) then {
        private _distToCurrent = _cPoint distance2D _currentCoverPoint;
        private _currDistToObj = _currentCoverPoint distance2D _objectivePos;
        private _candDistToObj = _cPoint distance2D _objectivePos;

        if (_dwellTime < _maxDwell) then {
            if (_distToCurrent < 2.0) then { _maneuverModifier = -25.0; }; // Hold current spot during active dwell
        } else {
            // Dwell expired: ONLY LEAPFROG FORWARD TOWARDS OBJECTIVE!
            if (_distToCurrent < 2.0) then {
                // If dwell is expired, do NOT penalize current position by 600!
                // Cost is neutral (0.0): if a valid forward position exists, its forward bonus (-65 to -150) will win naturally.
                // If NO forward cover exists, holding position is safe and prevents ping-ponging across the riverbed!
                _maneuverModifier = 0.0;
            } else {
                if (_candDistToObj >= _currDistToObj - 1.5) then {
                    // Lateral (e.g. crossing riverbed without advancing) or backward: STRICTLY FORBIDDEN (+700.0)
                    _maneuverModifier = 700.0 + ((_candDistToObj - _currDistToObj) max 0) * 35.0;
                } else {
                    // Genuine forward progress: strong rewarding bonus!
                    private _advGained = (_currDistToObj - _candDistToObj) min 30.0;
                    _maneuverModifier = -65.0 - (_advGained * 4.0);
                };
            };
        };
    };

    // Fireteam Sector Alignment & Street Advance Corridor Confinement
    private _corridorCenter = _unit getVariable ["AAI_TacticalCorridorCenter", []];
    private _corridorHalfWidth = _unit getVariable ["AAI_TacticalCorridorWidth", 2.2];
    private _corridorPenalty = 0.0;
    if (count _corridorCenter >= 2) then {
        // Only penalize LATERAL deviation (X-axis), NEVER longitudinal advance (Y-axis)!
        private _lateralDev = abs ((_cPoint select 0) - (_corridorCenter select 0));
        if (_lateralDev > _corridorHalfWidth) then {
            _corridorPenalty = (_lateralDev - _corridorHalfWidth) * 50.0;
        };
    } else {
        // Street Advance Corridor Alignment (Allow up to 18.0m width for bridge crossings and winding alleys)
        if (count _objectivePos >= 2) then {
            private _unitPos2D = [getPosATL _unit select 0, getPosATL _unit select 1];
            private _objPos2D = [_objectivePos select 0, _objectivePos select 1];
            private _axisVec = [(_objPos2D select 0) - (_unitPos2D select 0), (_objPos2D select 1) - (_unitPos2D select 1), 0];
            private _axisLen = vectorMagnitude _axisVec;
            if (_axisLen > 2.0) then {
                private _axisDir = vectorNormalized _axisVec;
                private _toPoint = [(_cPoint select 0) - (_unitPos2D select 0), (_cPoint select 1) - (_unitPos2D select 1), 0];
                private _projDist = (_toPoint select 0) * (_axisDir select 0) + (_toPoint select 1) * (_axisDir select 1);
                private _perpVec = _toPoint vectorDiff (_axisDir vectorMultiply _projDist);
                private _lateralDist = vectorMagnitude _perpVec;
                // Allow up to 18.0m lateral width for road curvature and bridge approaches
                if (_lateralDist > 18.0) then {
                    _corridorPenalty = (_lateralDist - 18.0) * 15.0;
                };
            };
        };
    };

    // Tactical Dispersion: Do NOT crowd teammate covers!
    private _crowdingPenalty = 0.0;
    {
        if (_x != _unit && {alive _x}) then {
            private _claimed = (_x getVariable ["AAI_TargetCover", createHashMap]) getOrDefault ["coverPoint", []];
            if (count _claimed > 0 && {_cPoint distance2D _claimed < 4.2}) then {
                _crowdingPenalty = _crowdingPenalty + 60.0;
            };
        };
    } forEach (units group _unit);

    // Anti-Oscillation / Visited Cover Memory: Strictly prohibit returning to recently departed covers!
    private _visitedPenalty = 0.0;
    // Current target cover or currently occupied cover is NEVER penalized!
    if (count _currentCoverPoint == 0 || {_cPoint distance2D _currentCoverPoint >= 2.2}) then {
        // ONLY penalize departed covers if the candidate does NOT advance closer to the objective!
        // If moving to this cover makes genuine forward progress towards the objective, it is an advance, not an oscillation!
        private _currDistToObj = if (count _currentCoverPoint >= 2 && {count _objectivePos >= 2}) then { _currentCoverPoint distance2D _objectivePos } else { 9999 };
        private _candDistToObj = if (count _objectivePos >= 2) then { _cPoint distance2D _objectivePos } else { 0 };
        private _isAdvancingTowardsObj = (_candDistToObj < (_currDistToObj - 1.5));

        if (!_isAdvancingTowardsObj) then {
            {
                _x params ["_vPos"];
                if (_cPoint distance2D _vPos < 3.8) exitWith {
                    _visitedPenalty = 1500.0; // Absolute barrier: never return laterally or backwards!
                };
            } forEach _visitedCovers;

            // Loop Breaker: check recent cover history
            private _coverHist = _unit getVariable ["AAI_RecentCoverHistory", []];
            {
                if (_cPoint distance2D _x < 3.8) exitWith {
                    _visitedPenalty = 2000.0; // Absolute barrier: never cycle back into recent covers!
                };
            } forEach _coverHist;
        };
    };

    // Target Commitment / Stickiness: Strongly incentivize sticking with the currently assigned cover
    // to eradicate flitting ("papillonnage") between left and right walls on minor score noise!
    private _commitmentBonus = 0.0;
    if (count _currentCoverPoint >= 2 && {_cPoint distance2D _currentCoverPoint < 2.5}) then {
        _commitmentBonus = 35.0;
    };

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

    // Mutual Bounding Overwatch: If a fireteam buddy is in cover or slicing, advance with bounding confidence
    private _buddies = (units group _unit) select { _x != _unit && {alive _x} };
    private _overwatchActive = false;
    {
        private _bState = _x getVariable ["AAI_TacticalState", "IDLE"];
        if (_bState in ["IN_COVER", "HOLDING_COVER"] || {("PIE_" in _bState)}) exitWith {
            _overwatchActive = true;
        };
    } forEach _buddies;
    private _overwatchBonus = if (_overwatchActive) then { 5.0 } else { 0.0 };

    // Binôme Cohesion: Pointman leads the advance, Wingman provides tight staggered overwatch (4m-7m)
    private _leadUnit = leader (group _unit);
    private _cohesionPenalty = 0.0;
    if (_unit != _leadUnit && {alive _leadUnit} && {count _objectivePos >= 2}) then {
        private _leadDistToObj = _leadUnit distance2D _objectivePos;
        private _candDistToObj = _cPoint distance2D _objectivePos;
        // Wingman must not overtake pointman (> 1.0m ahead towards objective)
        if (_candDistToObj < _leadDistToObj - 1.0) then {
            _cohesionPenalty = _cohesionPenalty + 200.0;
        };
        // Wingman tight leash: ideal distance to lead is 3.5m to 6.5m in urban CQB
        private _distToLead = _cPoint distance2D (getPosATL _leadUnit);
        if (_distToLead < 3.0) then {
            _cohesionPenalty = _cohesionPenalty + ((3.0 - _distToLead) * 15.0); // Don't crowd
        };
        if (_distToLead > 6.5) then {
            _cohesionPenalty = _cohesionPenalty + ((_distToLead - 6.5) * 22.0); // Don't lag
        };
        if (_distToLead > 10.0) then {
            _cohesionPenalty = _cohesionPenalty + 250.0; // Critical separation
        };
    } else {
        // POINTMAN (Lead): In leapfrog bounds across gaps (bridges/riverbeds), Pointman is the lead scout!
        private _buddyUnit = _unit getVariable ["AAI_BuddyUnit", objNull];
        if (_unit == _leadUnit && {!isNull _buddyUnit} && {alive _buddyUnit}) then {
            private _distToWing = _cPoint distance2D (getPosATL _buddyUnit);
            // Allow bounds up to 20m across open danger areas without cohesion penalty for the scout
            if (_distToWing > 20.0) then {
                _cohesionPenalty = _cohesionPenalty + (((_distToWing - 20.0) * 3.0) min 25.0);
            };
        };
    };

    // Field of Fire / Sector Engagement Utility
    // Reward covers that offer clear corner peeking into the street; penalize dead-ends
    private _canShootL = _c getOrDefault ["canShootLeft", false];
    private _canShootR = _c getOrDefault ["canShootRight", false];
    private _fieldOfFireBonus = if (_canShootL || _canShootR) then { 8.0 } else { -30.0 };

    // Urban CQB Stance & Height Utility:
    // Low stone walls (0.85m to 2.0m) afford perfect crouch cover with overwatch & corner peeking!
    // Giant 12m buildings offer zero visibility down the street and trap the unit in blind defilade.
    private _heightBonus = if (_height >= 0.85 && _height <= 2.0) then {
        6.0
    } else {
        if (_height > 2.0 && _height <= 3.5) then { 3.5 } else { 1.0 }
    };

    // Cost formula
    private _cost = (_distFromUnit * _wDist) 
                  + (_exposureIndex * _wExposure) 
                  + _occlusionPenalty 
                  + _wThreatProximity 
                  + _objectiveCost 
                  + _boundPenalty
                  + _retreatPenalty
                  + _corridorPenalty
                  + _crowdingPenalty
                  + _visitedPenalty
                  + _kgModifier 
                  + _maneuverModifier
                  + _cohesionPenalty
                  - _commitmentBonus
                  - (_quality * _wQuality) 
                  - _heightBonus
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
private _chosenStance = "UP";

// Peek-Defilade Cycle: ONLY activates once the unit has safely arrived at cover!
if (_isAtCover && {count _bestPeekPoint >= 3}) then {
    private _peekCycleTime = _unit getVariable ["AAI_PeekCycleTime", 0];
    private _isPeeking = _unit getVariable ["AAI_IsPeeking", false];

    if (time - _peekCycleTime > (if (_isPeeking) then { 1.2 } else { 1.5 })) then {
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
    // Dynamic CQB Stance: Run upright ("UP") for full athletic sprint & movement in transit!
    // Drop to "MIDDLE" when reaching cover (< 2.2m) or under immediate suppression!
    private _threatDist = if (!isNull _activeThreat) then {
        _unit distance2D _activeThreat
    } else {
        if (count _threatPos >= 2) then { _unit distance2D _threatPos } else { 999 }
    };

    _chosenStance = if (_distToCover < 2.2 || {_isAtCover}) then {
        _chosenAffordance getOrDefault ["stance", "MIDDLE"]
    } else {
        if (!isNull _activeThreat && {_hasLOS} && {_threatDist < 25.0}) then {
            "MIDDLE"
        } else {
            "UP"
        }
    };
    _unit setVariable ["AAI_IsPeeking", false];
};

// Check proximity to chosen destination
private _distToGoal = _unit distance2D _chosenPoint;

// Fireteam Pair Bounding Synchronization (Appui vs Assaut)
private _buddy = _unit getVariable ["AAI_BuddyUnit", objNull];
private _isLead = (_unit == leader (group _unit));

if (!isNull _buddy && {alive _buddy}) then {
    private _buddyCovering = _buddy getVariable ["AAI_IsProvidingCover", false];
    private _distToBuddy = _unit distance2D _buddy;

    if (_isLead) then {
        // POINTMAN (LEAD):
        private _waitingForWing = _unit getVariable ["AAI_LeadWaitingForWingman", false];
        if (_waitingForWing) then {
            private _wingArrived = (_buddyCovering && {_distToBuddy <= 7.5});
            private _waitStartTime = _unit getVariable ["AAI_LeadWaitStartTime", time];
            if (_wingArrived || {time - _waitStartTime > 6.0}) then {
                _unit setVariable ["AAI_LeadWaitingForWingman", false];
                _unit setVariable ["AAI_IsProvidingCover", false];
                [_unit, "Je progresse vers l'angle suivant ! Couvre l'axe !", "ORDER"] call AAI_fnc_tacticalRadio;
            } else {
                // Lead stays anchored in overwatch covering the street while Wingman bounds!
                _unit setVariable ["AAI_IsProvidingCover", true];
                _chosenPoint = _currentCoverPoint;
            };
        } else {
            if (_distToGoal <= 2.2 || {_isInCover}) then {
                _unit setVariable ["AAI_IsProvidingCover", true];
            } else {
                _unit setVariable ["AAI_IsProvidingCover", false];
            };
        };
    } else {
        // WINGMAN (APPUI):
        // If Lead is providing overwatch, waiting, or lagging (> 6.5m): Wingman bounds!
        if (_buddyCovering || {_distToBuddy > 6.5}) then {
            _unit setVariable ["AAI_IsProvidingCover", false];
            if (_distToGoal <= 2.5 || {_isInCover}) then {
                _unit setVariable ["AAI_IsProvidingCover", true];
                if (!(_unit getVariable ["AAI_EnBatterieAnnounced", false])) then {
                    _unit setVariable ["AAI_EnBatterieAnnounced", true];
                    [_unit, "En batterie ! Appui prêt !", "TACTICAL"] call AAI_fnc_tacticalRadio;
                };
            } else {
                _unit setVariable ["AAI_EnBatterieAnnounced", false];
            };
        } else {
            // Lead is currently maneuvering forward and Wingman is in position: Wingman holds overwatch!
            if (_distToGoal <= 2.8 && {count _currentCoverPoint >= 2}) then {
                _unit setVariable ["AAI_IsProvidingCover", true];
                _chosenPoint = _currentCoverPoint;
            };
        };
    };
};

_unit setVariable ["AAI_TargetCover", _bestCandidate];
_unit setVariable ["AAI_TargetAffordance", _chosenAffordance];
_unit setVariable ["AAI_TargetWatchPos", _watchPos];

private _newState = if (_distToGoal <= 2.6 || {_isArrived}) then {
    _unit setVariable ["AAI_CoverDwellTime", _dwellTime + 1.0];
    if (_isAnticipatedThreat) then {
        if (_unit getVariable ["AAI_IsPeeking", false]) then { "PIEING_CORNER" } else { "HOLDING_COVER" }
    } else {
        if (_unit getVariable ["AAI_IsPeeking", false]) then { "PEEK_FIRING" } else { "IN_DEFILADE" }
    }
} else {
    _unit setVariable ["AAI_CoverDwellTime", 0.0];
    "MOVING_TO_COVER"
};

// State change detection: record transit start time and issue order once
if (_newState == "MOVING_TO_COVER" && {_currentState != "MOVING_TO_COVER"}) then {
    _unit setVariable ["AAI_MoveStartTime", time];
    if (_isLead) then {
        [_unit, "Je progresse vers l'angle suivant ! Couvre l'axe !", "ORDER"] call AAI_fnc_tacticalRadio;
    };
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

// Contextual Semantic Speed Modulation:
// - OPEN STREET CROSSING: If bounding across open street/road or exposed -> "FULL" SPRINT!
// - CATCHING UP: If wingman is lagging behind (> 7.5m from lead) -> "FULL" SPRINT!
// - WALL BOUND: Moving along continuous stone walls / covered alleyways -> "NORMAL" (combat jog)
// - PRECISION SETTLING: Only drop to "LIMITED" when within 1.8m of final cover anchor!
private _isOpenCrossing = false;
if (_distToGoal > 3.0) then {
    private _midPoint = [
        ((getPosATL _unit select 0) + (_chosenPoint select 0)) * 0.5,
        ((getPosATL _unit select 1) + (_chosenPoint select 1)) * 0.5,
        0
    ];
    private _nearWalls = nearestObjects [_midPoint, ["Building", "House", "Wall", "Land_Stone_8m_F", "Land_Stone_4m_F"], 2.2];
    if (count _nearWalls == 0 || {_hasLOS && {!isNull _activeThreat}}) then {
        _isOpenCrossing = true;
    };
};

private _isCatchingUp = (!_isLead && {!isNull _buddy} && {alive _buddy} && {_unit distance2D _buddy > 6.0});

private _dispatchSpeed = if (_distToGoal >= 2.5 || {_isOpenCrossing} || {_isCatchingUp} || {(!isNull _activeThreat && {_hasLOS})}) then {
    if (_isOpenCrossing && {_distToGoal > 4.0} && {!(_unit getVariable ["AAI_CrossingAnnounced", false])}) then {
        _unit setVariable ["AAI_CrossingAnnounced", true];
        [_unit, "Traversée de la ruelle en sprint !", "ORDER"] call AAI_fnc_tacticalRadio;
    };
    "FULL"
} else {
    if (_distToGoal < 1.4 || {_isAtCover}) then {
        "LIMITED"
    } else {
        "NORMAL"
    }
};

// Execute actuation with dedicated sector watch position
[
    _unit,
    _chosenPoint,
    _chosenStance,
    if (!isNull _activeThreat) then { _activeThreat } else { _threatPos },
    _dispatchSpeed,
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
