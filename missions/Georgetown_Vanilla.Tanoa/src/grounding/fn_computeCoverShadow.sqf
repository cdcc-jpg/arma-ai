/*
    Author: Clement D. / Arma-AI Team
    File: fn_computeCoverShadow.sqf
    Tag: AAI_fnc_computeCoverShadow

    Description:
        Calculates the ballistic cover shadow (safe occluded zone) cast by an obstacle
        opposite to an incoming threat vector/position.
        Determines the geometric silhouette edges, computes the 3D ballistic shadow volume,
        derives the optimal primary cover point (standoff position minimizing direct line-of-sight),
        computes left/right peek/flank positions, and verifies physical line-of-sight obstruction
        via raycast testing.

    Parameters:
        0: _unit         - Friendly unit or unit position (OBJECT or ARRAY [X,Y,Z])
        1: _obstacleData - Obstacle HashMap (from AAI_fnc_perceiveObstacles) OR Obstacle OBJECT
        2: _threat       - Threat unit or threat position (OBJECT or ARRAY [X,Y,Z])
        3: _shadowDepth  - Optional depth of safe shadow cone in meters (NUMBER) [Default: 6.0]
        4: _standoffDist - Safe clearance distance behind the obstacle wall (NUMBER) [Default: 0.85]

    Returns:
        HASHMAP:
            - "obstacle": OBJECT
            - "coverPoint": ARRAY [X,Y,Z] (Optimal safe cover anchor point on terrain)
            - "shadowPolygon": ARRAY of 4 ARRAYS [X,Y,Z] (Ground shadow footprint vertices)
            - "shadowCrestPolygon": ARRAY of 4 ARRAYS [X,Y,Z] (Top crest shadow vertices)
            - "flankLeft": ARRAY [X,Y,Z] (Left peek/aim point around corner)
            - "flankRight": ARRAY [X,Y,Z] (Right peek/aim point around corner)
            - "silhouetteLeft": ARRAY [X,Y,Z] (Leftmost silhouette edge base)
            - "silhouetteRight": ARRAY [X,Y,Z] (Rightmost silhouette edge base)
            - "threatDir": ARRAY [X,Y,Z] (Normalized 2D direction from threat to obstacle)
            - "isOccluded": BOOLEAN (True if ray from threat eye to cover point is physically blocked)
            - "qualityScore": NUMBER (0.0 - 1.0 composite safety rating)

    Example:
        private _shadow = [player, _obstacleHash, _enemyUnit] call AAI_fnc_computeCoverShadow;
*/

params [
    ["_unit", player, [objNull, []]],
    ["_obstacleData", objNull, [objNull, createHashMap]],
    ["_threat", objNull, [objNull, []]],
    ["_shadowDepth", 6.0, [0]],
    ["_standoffDist", 0.85, [0]]
];

// Normalize threat position (prefer eyePos for living units, ATL for positions)
private _threatPos = if (_threat isEqualType objNull) then {
    if (isNull _threat) exitWith { [0,0,0] };
    if (alive _threat) then { eyePos _threat } else { getPosATL _threat }
} else {
    if (count _threat == 2) then { [_threat select 0, _threat select 1, 1.5] } else { _threat }
};

if (_threatPos isEqualTo [0,0,0]) exitWith { createHashMap };

// Normalize unit position
private _unitPos = if (_unit isEqualType objNull) then {
    if (isNull _unit) exitWith { [0,0,0] };
    getPosATL _unit
} else {
    if (count _unit == 2) then { [_unit select 0, _unit select 1, 0] } else { _unit }
};

// Resolve obstacle object & metadata
private _obsObj = objNull;
private _baseCorners = [];
private _topCorners = [];
private _obsCenter = [0,0,0];
private _obsHeight = 1.0;
private _obsWidth = 1.0;
private _classification = "SolidCover";

if (_obstacleData isEqualType createHashMap) then {
    _obsObj = _obstacleData getOrDefault ["object", objNull];
    _baseCorners = _obstacleData getOrDefault ["baseCornersWorld", []];
    _topCorners = _obstacleData getOrDefault ["topCornersWorld", []];
    _obsCenter = _obstacleData getOrDefault ["centerWorld", [0,0,0]];
    if (isNil "_obsCenter" || {_obsCenter isEqualTo [0,0,0]}) then {
        if (!isNull _obsObj) then { _obsCenter = getPosATL _obsObj; } else { _obsCenter = [0,0,0]; };
    };
    _obsHeight = _obstacleData getOrDefault ["height", 1.0];
    _obsWidth = _obstacleData getOrDefault ["width", 1.0];
    _classification = _obstacleData getOrDefault ["classification", "SolidCover"];
} else {
    _obsObj = _obstacleData;
    if (!isNull _obsObj) then {
        private _bbox = boundingBoxReal _obsObj;
        _bbox params ["_min", "_max"];
        _min params ["_x1", "_y1", "_z1"];
        _max params ["_x2", "_y2", "_z2"];
        
        _obsHeight = abs (_z2 - _z1);
        _obsWidth = abs (_x2 - _x1) max abs (_y2 - _y1);
        _obsCenter = _obsObj modelToWorldVisual [(_x1+_x2)*0.5, (_y1+_y2)*0.5, (_z1+_z2)*0.5];

        _baseCorners = [
            _obsObj modelToWorldVisual [_x1, _y1, _z1],
            _obsObj modelToWorldVisual [_x2, _y1, _z1],
            _obsObj modelToWorldVisual [_x2, _y2, _z1],
            _obsObj modelToWorldVisual [_x1, _y2, _z1]
        ];
        _topCorners = [
            _obsObj modelToWorldVisual [_x1, _y1, _z2],
            _obsObj modelToWorldVisual [_x2, _y1, _z2],
            _obsObj modelToWorldVisual [_x2, _y2, _z2],
            _obsObj modelToWorldVisual [_x1, _y2, _z2]
        ];
    };
};

if (isNull _obsObj || {count _baseCorners < 4}) exitWith { createHashMap };

// Calculate 2D Threat-to-Obstacle vector
private _threatToObs = _obsCenter vectorDiff _threatPos;
private _threatToObs2D = [_threatToObs select 0, _threatToObs select 1, 0];
private _threatDir2D = vectorNormalized _threatToObs2D;

// If threat is sitting directly at center (degenerate), fallback to arbitrary axis
if (vectorMagnitude _threatDir2D < 0.001) then {
    _threatDir2D = [0, 1, 0];
};

// 2D Perpendicular right vector to threat line: [dy, -dx, 0]
private _threatPerp2D = [-(_threatDir2D select 1), (_threatDir2D select 0), 0];

// Project all 4 base corners onto the perpendicular threat axis to find silhouette extrema
private _minProj = 1e9;
private _maxProj = -1e9;
private _leftCorner = _baseCorners select 0;
private _rightCorner = _baseCorners select 0;
private _leftTopCorner = _topCorners select 0;
private _rightTopCorner = _topCorners select 0;

{
    private _bc = _x;
    private _tc = _topCorners select _forEachIndex;
    private _rel = _bc vectorDiff _obsCenter;
    // Dot product with perpendicular vector defines lateral position (Left < 0 < Right)
    private _proj = (_rel select 0) * (_threatPerp2D select 0) + (_rel select 1) * (_threatPerp2D select 1);

    if (_proj < _minProj) then {
        _minProj = _proj;
        _leftCorner = _bc;
        _leftTopCorner = _tc;
    };
    if (_proj > _maxProj) then {
        _maxProj = _proj;
        _rightCorner = _bc;
        _rightTopCorner = _tc;
    };
} forEach _baseCorners;

// Ray projection directions from Threat through Left and Right silhouette corners
private _dirThreatToLeft = vectorNormalized (_leftCorner vectorDiff _threatPos);
private _dirThreatToRight = vectorNormalized (_rightCorner vectorDiff _threatPos);

// Extended shadow boundary points on ground
private _shadowLeftBase = _leftCorner vectorAdd (_dirThreatToLeft vectorMultiply _shadowDepth);
_shadowLeftBase set [2, (_leftCorner select 2)]; // Ground level

private _shadowRightBase = _rightCorner vectorAdd (_dirThreatToRight vectorMultiply _shadowDepth);
_shadowRightBase set [2, (_rightCorner select 2)]; // Ground level

// Extended shadow boundary points at top crest
private _shadowLeftTop = _leftTopCorner vectorAdd (_dirThreatToLeft vectorMultiply _shadowDepth);
private _shadowRightTop = _rightTopCorner vectorAdd (_dirThreatToRight vectorMultiply _shadowDepth);

// Footprint 2D/3D Polygon of the safe ballistic cone (Base)
private _shadowPolygon = [
    _leftCorner,
    _rightCorner,
    _shadowRightBase,
    _shadowLeftBase
];

// Top crest Polygon of the safe ballistic cone
private _shadowCrestPolygon = [
    _leftTopCorner,
    _rightTopCorner,
    _shadowRightTop,
    _shadowLeftTop
];

// Compute the rear centroid of the obstacle (opposite to threat)
// Find corners that lie on the far side (positive dot product along threatDir2D)
private _backCorners = [];
{
    private _rel = _x vectorDiff _obsCenter;
    private _dot = (_rel select 0) * (_threatDir2D select 0) + (_rel select 1) * (_threatDir2D select 1);
    if (_dot >= -0.05) then {
        _backCorners pushBack _x;
    };
} forEach _baseCorners;

if (count _backCorners == 0) then { _backCorners = [_obsCenter]; };

private _backCenter = [0,0,0];
{
    _backCenter = _backCenter vectorAdd _x;
} forEach _backCorners;
_backCenter = _backCenter vectorMultiply (1.0 / (count _backCorners));

// Optimal Primary Cover Point: Offset from rear face along threat direction
// Ensure cover point is in open courtyard/street and never trapped under interior roofs
private _effStandoff = if (_obsWidth > 5.0) then { 2.2 } else { 1.1 };
private _coverPoint = _backCenter vectorAdd (_threatDir2D vectorMultiply _effStandoff);
_coverPoint set [2, 0];

if (lineIntersects [ATLToASL (_coverPoint vectorAdd [0,0,0.5]), ATLToASL (_coverPoint vectorAdd [0,0,8])]) then {
    _coverPoint = _coverPoint vectorAdd (_threatDir2D vectorMultiply 2.5);
    _coverPoint set [2, 0];
};

// Flank / Peek Points (Left & Right offsets around corners for shooting/peeking)
private _peekLateralOffset = 0.55;
private _peekBackOffset = 0.35;

private _flankLeft = _leftCorner vectorAdd (_threatPerp2D vectorMultiply (-_peekLateralOffset)) vectorAdd (_threatDir2D vectorMultiply _peekBackOffset);
_flankLeft set [2, 0];

private _flankRight = _rightCorner vectorAdd (_threatPerp2D vectorMultiply _peekLateralOffset) vectorAdd (_threatDir2D vectorMultiply _peekBackOffset);
_flankRight set [2, 0];

// Physical Occlusion Raycast Check for Center Defilade:
// Test ray from threat eye position to test height at cover point (crouch test height ~1.1m)
private _testCoverEyePos = [
    _coverPoint select 0,
    _coverPoint select 1,
    (_coverPoint select 2) + ((_obsHeight * 0.6) min 1.2)
];

// Use lineIntersectsSurfaces with ignore list
private _intersections = lineIntersectsSurfaces [
    _threatPos,
    ATLToASL _testCoverEyePos,
    if (_threat isEqualType objNull) then { _threat } else { objNull },
    if (_unit isEqualType objNull) then { _unit } else { objNull },
    true,
    1,
    "GEOM",
    "FIRE"
];

private _isOccluded = (count _intersections > 0);

// If no intersection was found with GEOM/FIRE, also check terrain line of sight
if (!_isOccluded) then {
    if (terrainIntersectASL [_threatPos, ATLToASL _testCoverEyePos]) then {
        _isOccluded = true;
    };
};

// Line of fire checks from corner peek positions
private _testEyeLeft = [_flankLeft select 0, _flankLeft select 1, (_flankLeft select 2) + 1.2];
private _losLeftInter = lineIntersectsSurfaces [_threatPos, ATLToASL _testEyeLeft, if (_threat isEqualType objNull) then { _threat } else { objNull }, if (_unit isEqualType objNull) then { _unit } else { objNull }, true, 1, "GEOM", "FIRE"];
private _canShootLeft = (count _losLeftInter == 0);

private _testEyeRight = [_flankRight select 0, _flankRight select 1, (_flankRight select 2) + 1.2];
private _losRightInter = lineIntersectsSurfaces [_threatPos, ATLToASL _testEyeRight, if (_threat isEqualType objNull) then { _threat } else { objNull }, if (_unit isEqualType objNull) then { _unit } else { objNull }, true, 1, "GEOM", "FIRE"];
private _canShootRight = (count _losRightInter == 0);

// Pick best corner peek point (closer to unit approach or with valid firing angle)
private _bestPeek = if (_unit distance2D _flankLeft <= _unit distance2D _flankRight) then { _flankLeft } else { _flankRight };
if (_canShootLeft && !_canShootRight) then { _bestPeek = _flankLeft; };
if (_canShootRight && !_canShootLeft) then { _bestPeek = _flankRight; };

// Material & Ballistic penetration factors
private _materialClass = if (_obstacleData isEqualType createHashMap) then { _obstacleData getOrDefault ["materialClass", "MasonryStone"] } else { "MasonryStone" };
private _penetrationResistance = if (_obstacleData isEqualType createHashMap) then { _obstacleData getOrDefault ["penetrationResistance", 0.85] } else { 0.85 };

// Higher score for solid penetration-resistant cover, obstacle height, width, and verified occlusion
private _heightFactor = (_obsHeight / 2.0) min 1.0;
private _widthFactor = (_obsWidth / 3.0) min 1.0;
private _occlusionFactor = if (_isOccluded) then { 1.0 } else { 0.1 };
private _qualityScore = (_heightFactor * 0.25) + (_widthFactor * 0.20) + (_penetrationResistance * 0.35) + (_occlusionFactor * 0.20);

// Sector Watch Position (Aiming down the open street corridor towards threat line)
private _threatAimDir = (_threatDir2D vectorMultiply -1);
// Always project watch position 35m down the open street from the peek corner, aimed at chest height (1.4m)
private _watchPos = _bestPeek vectorAdd (_threatAimDir vectorMultiply 35.0);
_watchPos set [2, 1.4];

createHashMapFromArray [
    ["obstacle", _obsObj],
    ["coverPoint", _coverPoint],
    ["bestPeekPoint", _bestPeek],
    ["watchPos", _watchPos],
    ["flankLeft", _flankLeft],
    ["flankRight", _flankRight],
    ["canShootLeft", _canShootLeft],
    ["canShootRight", _canShootRight],
    ["materialClass", _materialClass],
    ["penetrationResistance", _penetrationResistance],
    ["shadowPolygon", _shadowPolygon],
    ["shadowCrestPolygon", _shadowCrestPolygon],
    ["silhouetteLeft", _leftCorner],
    ["silhouetteRight", _rightCorner],
    ["threatDir", _threatDir2D],
    ["isOccluded", _isOccluded],
    ["shadowDepth", _shadowDepth],
    ["qualityScore", _qualityScore],
    ["height", _obsHeight],
    ["width", _obsWidth]
]
