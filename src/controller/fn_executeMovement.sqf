/*
    Author: Clement D. / Arma-AI Team
    File: fn_executeMovement.sqf
    Tag: AAI_fnc_executeMovement

    Description:
        Actuation module executing smooth, responsive tactical movement commands.
        Manages unit stance transitions (dynamic sprint stance vs destination cover stance),
        movement commands (doMove / moveTo), combat mode overrides, speed modulation,
        and orientation/targeting towards active threats without vanilla AI hesitation loops.

    Parameters:
        0: _unit          - Unit to command (OBJECT)
        1: _targetPos     - Destination 3D position [X,Y,Z] (ARRAY)
        2: _desiredStance - Target stance when in cover ("UP" | "MIDDLE" | "DOWN" | "AUTO") [Default: "MIDDLE"]
        3: _threat        - Threat unit or threat position (OBJECT or ARRAY) [Default: objNull]
        4: _speedMode     - Desired speed ("FULL" | "NORMAL" | "LIMITED") [Default: "FULL"]

    Returns:
        BOOLEAN - True if movement command was successfully dispatched

    Example:
        [_unit, _coverPos, "MIDDLE", _threatUnit, "FULL"] call AAI_fnc_executeMovement;
*/

params [
    ["_unit", player, [objNull]],
    ["_targetPos", [0,0,0], [[]]],
    ["_desiredStance", "MIDDLE", [""]],
    ["_threat", objNull, [objNull, []]],
    ["_speedMode", "FULL", [""]]
];

if (!alive _unit || {_targetPos isEqualTo [0,0,0]}) exitWith { false };

// Normalize threat position
private _threatPos = [0,0,0];
if (_threat isEqualType objNull) then {
    if (!isNull _threat && {alive _threat}) then {
        _threatPos = eyePos _threat;
    };
} else {
    if (count _threat >= 2) then {
        _threatPos = if (count _threat == 2) then { [_threat select 0, _threat select 1, 1.5] } else { _threat };
    };
};

// 1. Ensure Agent Responsiveness: Override vanilla AUTOCOMBAT lockup
// AUTOCOMBAT often causes vanilla AI to drop prone and freeze in place instead of moving to cover
if (_unit checkAIFeature "AUTOCOMBAT") then {
    _unit disableAI "AUTOCOMBAT";
};
_unit enableAI "MOVE";
_unit enableAI "PATH";
_unit enableAI "ANIM";

// Set tactical posture
if (behaviour _unit != "COMBAT") then {
    _unit setBehaviour "COMBAT";
};

if (speedMode _unit != _speedMode) then {
    _unit setSpeedMode _speedMode;
};

// 2. Distance-based Stance & Movement Actuation
private _distToTarget = _unit distance2D _targetPos;

if (_distToTarget > 2.5) then {
    // Transit Phase (Sprinting to Cover)
    // When sprinting to cover, maintain mobility stance (UP or MIDDLE)
    private _transitStance = if (_desiredStance == "DOWN") then { "MIDDLE" } else { "UP" };
    if (unitPos _unit != _transitStance) then {
        _unit setUnitPos _transitStance;
    };

    // Free unit gaze to prevent slow strafing/moonwalking
    _unit doWatch objNull;

    // Issue pathfinding order
    _unit doMove _targetPos;
    _unit moveTo _targetPos;

} else {
    // Arrival / In-Cover Phase
    if (_distToTarget <= 1.35) then {
        // Enforce the strictly grounded cover stance
        if (unitPos _unit != _desiredStance) then {
            _unit setUnitPos _desiredStance;
        };

        // Halt micro-jitters
        _unit doMove (getPosATL _unit);

        // Turn to track and engage threat if present
        if (!(_threatPos isEqualTo [0,0,0])) then {
            if (_threat isEqualType objNull && {!isNull _threat}) then {
                _unit doTarget _threat;
                _unit doWatch _threat;
            } else {
                _unit doWatch _threatPos;
            };
        };
    } else {
        // Final approach (1.35m - 2.5m): Start lowering into stance while completing step
        if (unitPos _unit != _desiredStance) then {
            _unit setUnitPos _desiredStance;
        };
        _unit doMove _targetPos;
    };
};

true
