/*
    Author: Clement D. / Arma-AI Team
    File: fn_evaluateStanceAffordance.sqf
    Tag: AAI_fnc_evaluateStanceAffordance

    Description:
        Evaluates the stance affordance (STAND, CROUCH, PRONE, or EXPOSED) offered by an obstacle
        based on its physical height, geometric dimensions, and optional relative threat angle.
        Maps the physical affordance directly to Arma 3 unitPos tokens ("UP", "MIDDLE", "DOWN").

    Rules / Thresholds:
        - Height >= 1.8m: STAND affordance ("UP") - Full standing cover, maximum movement speed.
        - 0.9m <= Height < 1.8m: CROUCH affordance ("MIDDLE") - Half-height cover, standard crouch.
        - 0.4m <= Height < 0.9m: PRONE affordance ("DOWN") - Low barrier, prone crawl required.
        - Height < 0.4m: EXPOSED ("AUTO" / "UP") - Insufficient vertical protection.

    Parameters:
        0: _height    - Effective obstacle height in meters (NUMBER) OR Obstacle HashMap
        1: _threatPos - Optional threat position [X,Y,Z] (ARRAY) [Default: []]
        2: _coverPos  - Optional cover position [X,Y,Z] (ARRAY) [Default: []]

    Returns:
        HASHMAP:
            - "stance": STRING ("UP" | "MIDDLE" | "DOWN" | "AUTO") -> for setUnitPos
            - "stanceName": STRING ("STAND" | "CROUCH" | "PRONE" | "EXPOSED")
            - "effectiveHeight": NUMBER (Height in meters)
            - "canPeekOver": BOOLEAN (Whether agent can peek over the crest)
            - "canPeekFlank": BOOLEAN (Whether agent can peek around sides)
            - "exposureIndex": NUMBER (0.0 = completely protected, 1.0 = fully exposed)
            - "mobilityScore": NUMBER (Mobility factor in this stance: 1.0 for stand, 0.7 for crouch, 0.25 for prone)

    Example:
        private _affordance = [1.2, _threatEyePos, _coverPos] call AAI_fnc_evaluateStanceAffordance;
*/

params [
    ["_heightInput", 1.8, [0, createHashMap, objNull]],
    ["_threatPos", [], [[]]],
    ["_coverPos", [], [[]]]
];

// Extract scalar height
private _effectiveHeight = 1.0;
if (_heightInput isEqualType createHashMap) then {
    _effectiveHeight = _heightInput getOrDefault ["height", 1.0];
} else {
    if (_heightInput isEqualType objNull) then {
        if (!isNull _heightInput) then {
            private _bbox = boundingBoxReal _heightInput;
            _bbox params ["_min", "_max"];
            _effectiveHeight = abs ((_max select 2) - (_min select 2));
        };
    } else {
        _effectiveHeight = _heightInput;
    };
};

// Threat vertical angle adjustment (Plunging fire / Elevated threat)
private _elevationAngleDeg = 0.0;
if (count _threatPos >= 3 && {count _coverPos >= 3}) then {
    private _deltaZ = (_threatPos select 2) - (_coverPos select 2);
    private _dist2D = [_threatPos select 0, _threatPos select 1] distance2D [_coverPos select 0, _coverPos select 1];
    if (_dist2D > 1.0) then {
        _elevationAngleDeg = atan (_deltaZ / _dist2D);
        // If threat is elevated by more than 15 degrees, apparent cover height drops
        if (_elevationAngleDeg > 15.0) then {
            private _penalty = ((_elevationAngleDeg - 15.0) / 45.0) * 0.4;
            _effectiveHeight = (_effectiveHeight - _penalty) max 0.1;
        };
    };
};

// Core Stance Affordance Decision Logic
private _stance = "UP";
private _stanceName = "STAND";
private _canPeekOver = false;
private _canPeekFlank = true;
private _exposureIndex = 0.0;
private _mobilityScore = 1.0;

switch (true) do {
    // Tall Cover (Height >= 1.80m)
    // Physical affordance can afford standing, but tactical combat posture in cover defaults to crouch (MIDDLE) for low profile
    case (_effectiveHeight >= 1.80): {
        _stance = "MIDDLE";
        _stanceName = "STAND";
        _canPeekOver = false;
        _canPeekFlank = true;
        _exposureIndex = 0.05;
        _mobilityScore = 0.90;
    };

    // Medium / Crouch Cover (0.90m <= Height < 1.80m)
    case (_effectiveHeight >= 0.90): {
        _stance = "MIDDLE";
        _stanceName = "CROUCH";
        // Can peek over if height is within head peek window (0.9m to 1.35m)
        _canPeekOver = (_effectiveHeight <= 1.40);
        _canPeekFlank = true;
        _exposureIndex = 0.15;
        _mobilityScore = 0.70;
    };

    // Low / Prone Barrier (0.40m <= Height < 0.90m)
    case (_effectiveHeight >= 0.40): {
        _stance = "DOWN";
        _stanceName = "PRONE";
        _canPeekOver = (_effectiveHeight <= 0.60);
        _canPeekFlank = false;
        _exposureIndex = 0.35;
        _mobilityScore = 0.25;
    };

    // Insufficient Cover / Exposed (< 0.40m)
    default {
        _stance = "MIDDLE";
        _stanceName = "EXPOSED";
        _canPeekOver = false;
        _canPeekFlank = false;
        _exposureIndex = 0.90;
        _mobilityScore = 0.85;
    };
};

createHashMapFromArray [
    ["stance", _stance],
    ["stanceName", _stanceName],
    ["effectiveHeight", _effectiveHeight],
    ["canPeekOver", _canPeekOver],
    ["canPeekFlank", _canPeekFlank],
    ["exposureIndex", _exposureIndex],
    ["mobilityScore", _mobilityScore],
    ["threatAngle", _elevationAngleDeg]
]
