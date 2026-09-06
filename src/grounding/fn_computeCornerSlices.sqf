/*
    Author: Clement D. / Arma-AI Team
    File: fn_computeCornerSlices.sqf
    Tag: AAI_fnc_computeCornerSlices

    Description:
        Generates tactical CQB pie-slicing waypoints (tac:CornerSliceAffordance)
        around an obstacle corner. The agent remains tight to the wall (wall-hugging standoff)
        and steps along an arc centered at the corner, slicing the unknown sector
        in progressive quadrants (default: 4 slices, ~18-22 deg each).
        For each slice, computes the exact tangent watch vector grazing the corner vertex,
        ensuring weapon and eyes sweep into the blind zone prior to foot placement.

    Parameters:
        0: _unit         - Unit performing the slice (OBJECT)
        1: _cornerPos    - 3D world position of the corner vertex (ARRAY [X,Y,Z])
        2: _defiladePos  - Safe cover anchor behind the wall (ARRAY [X,Y,Z])
        3: _dangerPos    - Threat position or avenue of approach down the street (ARRAY [X,Y,Z])
        4: _numSlices    - Number of angular quadrants to slice (NUMBER) [Default: 4]
        5: _standoffDist - Radial distance from the corner pivot in meters (NUMBER) [Default: 1.25]

    Returns:
        ARRAY of HASHMAPs:
            Each HashMap contains:
                - "index": NUMBER (1-based slice index, 1 to _numSlices)
                - "pos": ARRAY [X,Y,0] (Foot position ATL on the arc)
                - "watchPos": ARRAY [X,Y,1.4] (Tangent line-of-sight watch point 35m into sector)
                - "tangentDir": ARRAY [X,Y,0] (Normalized 2D ray from foot through corner)
                - "angleDeg": NUMBER (Cumulative angle revealed relative to wall line)
                - "cornerPivot": ARRAY [X,Y,Z] (Corner vertex)

    Example:
        private _slices = [_unit, _cornerVertex, _coverPos, _objectivePos, 4, 1.25] call AAI_fnc_computeCornerSlices;
*/

params [
    ["_unit", player, [objNull]],
    ["_cornerPos", [0,0,0], [[]]],
    ["_defiladePos", [0,0,0], [[]]],
    ["_dangerPos", [0,0,0], [[]]],
    ["_numSlices", 5, [0]],
    ["_standoffDist", 3.8, [0]]
];

if (_cornerPos isEqualTo [0,0,0]) exitWith { [] };

// Normalize fallback coordinates if defilade or danger not provided
if (_defiladePos isEqualTo [0,0,0]) then { _defiladePos = getPosATL _unit; };
if (_dangerPos isEqualTo [0,0,0]) then {
    private _dir = getDir _unit;
    _dangerPos = [(_cornerPos select 0) + (sin _dir * 30), (_cornerPos select 1) + (cos _dir * 30), 0];
};

// 1. Vector from Corner to Defilade (Wall axis behind cover)
private _vCornerToDef = [
    (_defiladePos select 0) - (_cornerPos select 0),
    (_defiladePos select 1) - (_cornerPos select 1),
    0
];
private _curDist = vectorMagnitude _vCornerToDef;
if (_curDist < 0.3) then {
    _vCornerToDef = [0, -3.8, 0];
    _curDist = 3.8;
};

// Standoff radius: Deep standoff (2.5m - 5.5m) to slice early and wide ("Feuilleter plus tôt et plus large")
// Never crowd the corner tip (< 2.0m) which exposes body silhouette to holding defenders!
private _radius = _standoffDist max 2.5 min 5.5;

// Base azimuth (Corner -> Defilade)
private _baseDir = vectorNormalized _vCornerToDef;
private _baseAngle = (_baseDir select 0) atan2 (_baseDir select 1);

// 2. Vector from Corner towards Danger Avenue / Street
private _vCornerToDanger = [
    (_dangerPos select 0) - (_cornerPos select 0),
    (_dangerPos select 1) - (_cornerPos select 1),
    0
];
private _dangerDir = vectorNormalized _vCornerToDanger;
private _dangerAngle = (_dangerDir select 0) atan2 (_dangerDir select 1);

// 3. Angular difference & turn direction (Clockwise vs Counter-Clockwise)
private _angleDiff = (_dangerAngle - _baseAngle);
while {_angleDiff > 180} do { _angleDiff = _angleDiff - 360; };
while {_angleDiff < -180} do { _angleDiff = _angleDiff + 360; };

// Clamp total pie sweep between 45 deg and 85 deg
private _sign = if (_angleDiff >= 0) then { 1.0 } else { -1.0 };
private _totalSweep = (abs _angleDiff) max 45.0 min 85.0;
private _stepAngle = (_sign * _totalSweep) / (_numSlices max 1);

private _unitEyeZ = ((getPosATL _unit) select 2) + 1.35;
private _slices = [];

// 4. Generate the N progressive quadrants along the arc
for "_i" from 1 to _numSlices do {
    private _sliceAngle = _baseAngle + (_i * _stepAngle);
    
    // Foot position on the arc around the corner
    private _footX = (_cornerPos select 0) + (_radius * sin _sliceAngle);
    private _footY = (_cornerPos select 1) + (_radius * cos _sliceAngle);
    private _footPos = [_footX, _footY, 0];

    // Tangent ray from Foot position through Corner vertex out into the street
    private _tangentVec = [
        (_cornerPos select 0) - _footX,
        (_cornerPos select 1) - _footY,
        0
    ];
    private _tangentDir = vectorNormalized _tangentVec;

    // Projected watch point 35m along the tangent ray at chest height
    private _watchX = (_cornerPos select 0) + ((_tangentDir select 0) * 35.0);
    private _watchY = (_cornerPos select 1) + ((_tangentDir select 1) * 35.0);
    private _watchPos = [_watchX, _watchY, _unitEyeZ];

    private _sliceHash = createHashMapFromArray [
        ["index", _i],
        ["pos", _footPos],
        ["watchPos", _watchPos],
        ["tangentDir", _tangentDir],
        ["angleDeg", round (abs (_i * _stepAngle))],
        ["cornerPivot", _cornerPos]
    ];
    _slices pushBack _sliceHash;
};

_slices
