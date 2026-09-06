/*
    Author: Clement D. / Arma-AI Team
    File: fn_startAgentController.sqf
    Tag: AAI_fnc_startAgentController

    Description:
        Spawns and manages the autonomous tactical decision loop for a given agent.
        Continuously evaluates spatial grounding affordances and executes tactical
        actions at a controlled tick rate (default: 0.35s). Stores the loop script handle
        on the unit to prevent duplicate execution and allow clean termination.

    Parameters:
        0: _agent    - The agent unit (OBJECT) [Default: player]
        1: _threat   - The threat unit or position (OBJECT or ARRAY) [Default: objNull]
        2: _tickRate - Update interval in seconds (NUMBER) [Default: 0.35]

    Returns:
        SCRIPT - The spawned background loop script handle

    Example:
        [tactical_agent, threat_opfor, 0.3] spawn AAI_fnc_startAgentController;
*/

params [
    ["_agent", player, [objNull]],
    ["_threat", objNull, [objNull, []]],
    ["_tickRate", 0.35, [0]]
];

if (isNull _agent || {!alive _agent}) exitWith { scriptNull };

// Stop existing controller loop on this unit if running
private _existingHandle = _agent getVariable ["AAI_ControllerHandle", scriptNull];
if (!isNull _existingHandle) then {
    terminate _existingHandle;
};

private _handle = [_agent, _threat, _tickRate] spawn {
    params ["_agent", "_threat", "_tickRate"];

    // Initialize unit attributes
    _agent setVariable ["AAI_TacticalState", "INITIALIZING"];
    _agent disableAI "AUTOCOMBAT";
    _agent disableAI "COVER";
    _agent disableAI "SUPPRESSION";
    _agent enableAI "MOVE";
    _agent enableAI "PATH";
    _agent enableAI "ANIM";
    _agent enableAI "TARGET";
    _agent enableAI "AUTOTARGET";
    _agent enableAI "AIMINGERROR";
    _agent setUnitPos "MIDDLE";
    _agent setSpeedMode "LIMITED";
    _agent setBehaviour "AWARE";
    _agent setCombatMode "RED";

    diag_log format ["[AAI Grounding Engine] Started tactical agent controller for %1 against threat %2 (Rate: %3s)", _agent, _threat, _tickRate];

    while {alive _agent} do {
        // Execute one tactical grounding & decision cycle
        [_agent, _threat, 50.0, false] call AAI_fnc_tacticalTick;

        // Responsive loop pacing for fluid, reactive tactical movement
        sleep (_tickRate max 0.25);
    };

    diag_log format ["[AAI Grounding Engine] Tactical agent controller terminated for %1 (Unit deceased or mission ended).", _agent];
    _agent setVariable ["AAI_TacticalState", "DEAD"];
};

_agent setVariable ["AAI_ControllerHandle", _handle];
_handle
