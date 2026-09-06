/*
    Author: Clement D. / Arma-AI Team
    File: fn_executeMovement.sqf
    Tag: AAI_fnc_executeMovement

    Description:
        Actuation module executing smooth, responsive tactical movement commands.
        Manages unit stance transitions (dynamic sprint stance vs destination cover stance),
        movement hysteresis to prevent animation jitter, combat mode engagement,
        speed modulation, and orientation/firing from cover against active threats.

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
    ["_speedMode", "FULL", [""]],
    ["_watchPos", [0,0,0], [[]]]
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

// Fallback watch position if not provided
if (_watchPos isEqualTo [0,0,0]) then {
    _watchPos = if (!(_threatPos isEqualTo [0,0,0])) then { _threatPos } else { _targetPos };
};

// Elevate watch position to chest height (1.4m) so the rifle is aimed down the avenue rather than at the dirt
if (count _watchPos >= 3 && {(_watchPos select 2) < 1.0}) then {
    _watchPos set [2, ((getPosATL _unit) select 2) + 1.4];
};

// 1. Ensure all essential combat & movement AI capabilities are properly configured
if (_unit checkAIFeature "AUTOCOMBAT") then { _unit disableAI "AUTOCOMBAT"; };
if (_unit checkAIFeature "COVER") then { _unit disableAI "COVER"; };
if (_unit checkAIFeature "SUPPRESSION") then { _unit disableAI "SUPPRESSION"; };
_unit enableAI "MOVE";
_unit enableAI "PATH";
_unit enableAI "ANIM";
_unit enableAI "TARGET";
_unit enableAI "AUTOTARGET";
_unit enableAI "AIMINGERROR";

if (behaviour _unit != "AWARE") then {
    _unit setBehaviour "AWARE";
};
if (combatMode _unit != "RED") then {
    _unit setCombatMode "RED";
};
if (speedMode _unit != _speedMode) then {
    _unit setSpeedMode _speedMode;
};

// 2. Distance-based Movement & Stance Control with Hysteresis
private _distToTarget = _unit distance2D _targetPos;
private _lastTarget = _unit getVariable ["AAI_CurrentMoveTarget", [0,0,0]];
private _lastMoveTime = _unit getVariable ["AAI_LastMoveOrderTime", 0];
private _targetDelta = _lastTarget distance2D _targetPos;

if (_distToTarget > 1.8) then {
    // -------------------------------------------------------------------------
    // TRANSIT PHASE (Low-Profile CQB Tactical Ingress)
    // -------------------------------------------------------------------------
    // NEVER stand upright like a civilian in an urban combat zone!
    // Move in low-profile crouched posture ("MIDDLE") with weapon ready!
    private _tacticalStance = if (_desiredStance == "DOWN") then { "DOWN" } else { "MIDDLE" };
    if (unitPos _unit != _tacticalStance) then {
        _unit setUnitPos _tacticalStance;
    };

    // Speed modulation: Use requested speed ("LIMITED", "NORMAL", "FULL")
    private _transitSpeed = if (_speedMode in ["LIMITED", "NORMAL", "FULL"]) then { _speedMode } else { "NORMAL" };
    if (speedMode _unit != _transitSpeed) then {
        _unit setSpeedMode _transitSpeed;
    };

    // Always keep weapon raised and scanning down the corridor towards watchPos!
    if (!(_watchPos isEqualTo [0,0,0])) then {
        _unit doWatch _watchPos;
    };

    // Issue doMove if target changed significantly, or if idle with minimum cooldown
    if (_targetDelta > 0.8 || {unitReady _unit && {time - _lastMoveTime > 0.4}} || {time - _lastMoveTime > 2.0 && {speed _unit < 0.2}}) then {
        _unit setVariable ["AAI_CurrentMoveTarget", _targetPos];
        _unit setVariable ["AAI_LastMoveOrderTime", time];
        _unit doMove _targetPos;
    };

    // Reveal threat to agent if active
    if (_threat isEqualType objNull && {!isNull _threat} && {alive _threat}) then {
        _unit reveal [_threat, 4];
    };

} else {
    // -------------------------------------------------------------------------
    // ARRIVAL / IN-COVER PHASE (Immediately drop to safe low-profile stance)
    // -------------------------------------------------------------------------
    // Enforce low-profile combat posture: MIDDLE for walls/houses, DOWN for low barriers
    private _safeCoverStance = if (_desiredStance == "DOWN") then { "DOWN" } else { "MIDDLE" };
    if (unitPos _unit != _safeCoverStance) then {
        _unit setUnitPos _safeCoverStance;
    };
    if (speedMode _unit != "LIMITED") then {
        _unit setSpeedMode "LIMITED";
    };

    // Micro-positioning to the corner peek point or defilade anchor (Slicing the pie)
    if (_targetDelta > 0.4 && {time - _lastMoveTime > 0.5}) then {
        _unit setVariable ["AAI_CurrentMoveTarget", _targetPos];
        _unit setVariable ["AAI_LastMoveOrderTime", time];
        _unit doMove _targetPos;
    };

    // Active Sector Surveillance & Weapon Engagement from behind cover
    private _canSeeThreat = false;
    if (_threat isEqualType objNull && {!isNull _threat} && {alive _threat}) then {
        _unit reveal [_threat, 4];
        private _vis = [objNull, "VIEW", _unit] checkVisibility [eyePos _unit, eyePos _threat];
        _canSeeThreat = (_vis > 0.15);

        if (_canSeeThreat) then {
            // DIRECT ENGAGEMENT: Target is visible in clear line of sight
            _unit doTarget _threat;
            _unit doWatch _threat;

            // Rapid, lethal engagement bursts
            private _lastFire = _unit getVariable ["AAI_LastFireBurstTime", 0];
            if (time - _lastFire > 0.65) then {
                _unit setVariable ["AAI_LastFireBurstTime", time];
                _unit forceWeaponFire [currentMuzzle _unit, "Single"];
                _unit forceWeaponFire [currentMuzzle _unit, "Single"];
            };
        } else {
            // OCCLUDED THREAT: Clear target so engine does not stare into solid concrete!
            _unit doTarget objNull;

            // Naturally orient and watch towards the threat avenue / corner
            if (count _watchPos >= 2) then {
                _unit doWatch _watchPos;
            };
        };
    } else {
        // No explicit threat: scan forward naturally towards watchPos without snapping
        _unit doTarget objNull;
        if (count _watchPos >= 2) then {
            _unit doWatch _watchPos;
        };
    };
};

true
