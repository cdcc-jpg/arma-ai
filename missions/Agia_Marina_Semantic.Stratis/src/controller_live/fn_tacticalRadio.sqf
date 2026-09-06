/*
    Author: Clement D. / Arma-AI Team
    File: fn_tacticalRadio.sqf
    Tag: AAI_fnc_tacticalRadio

    Description:
        Broadcasts tactical intercom radio messages between BLUFOR fireteam buddies.
        Includes callsigns, distinct role-based color coding, throttled repetition,
        and authentic military radio click audio feedback.

    Parameters:
        0: _unit    - Soldier broadcasting (OBJECT)
        1: _message - Voice callout message (STRING)
        2: _type    - Category: "TACTICAL" | "DANGER" | "CONTACT" | "ORDER" [Default: "TACTICAL"]

    Example:
        [_lead, "Zone de danger à l'angle ! Découpage en cours !", "DANGER"] call AAI_fnc_tacticalRadio;
*/

params [
    ["_unit", player, [objNull]],
    ["_message", "", [""]],
    ["_type", "TACTICAL", [""]]
];

if (isNull _unit || {!alive _unit} || {_message == ""}) exitWith {};

// Per-message throttling: prevent repeating the identical message within 4 seconds
private _varKey = format ["AAI_RadioLastTime_%1", _message];
private _lastTime = _unit getVariable [_varKey, 0];
if (time - _lastTime < 3.5) exitWith {};
_unit setVariable [_varKey, time];

// Global radio throttle: at least 1.8s between routine transmissions from this unit (emergency CONTACT bypasses)
private _lastAnyRadio = _unit getVariable ["AAI_LastAnyRadioTime", 0];
if (_type != "CONTACT" && {time - _lastAnyRadio < 1.8}) exitWith {};
_unit setVariable ["AAI_LastAnyRadioTime", time];

private _isLead = (_unit == leader (group _unit));
private _roleTitle = if (_isLead) then { "POINTMAN (LEAD)" } else { "WINGMAN (APPUI)" };
private _tagColor  = if (_isLead) then { "#ffcc00" } else { "#33ddff" };

private _typePrefix = switch (_type) do {
    case "DANGER":  { "<t color='#ff9900'>[ALERTE ANGLE]</t>" };
    case "CONTACT": { "<t color='#ff2222'>[CONTACT FEU !]</t>" };
    case "ORDER":   { "<t color='#00ff88'>[ORDRE MOUVEMENT]</t>" };
    default         { "<t color='#cccccc'>[INTERCOM]</t>" };
};

// Distinct radio PTT key click audible across UI and 3D
playSoundUI ["readoutClick", 1.0, 1.0];
playSound "Click";

// Format radio message
private _radioText = format [
    "%1 <t color='%2' font='PuristaBold'>[%3]:</t> <t color='#ffffff'>""%4""</t>",
    _typePrefix, _tagColor, _roleTitle, _message
];

// Display via systemChat (plain text) and store for HUD telemetry
private _plainChat = format ["[%1] ""%2""", _roleTitle, _message];
systemChat _plainChat;

// Broadcast single callout and rolling history of last 3 transmissions
missionNamespace setVariable ["AAI_LastRadioCallout", _radioText];
missionNamespace setVariable ["AAI_LastRadioCalloutTime", time];

private _radioLog = missionNamespace getVariable ["AAI_RadioLog", []];
_radioLog pushBack _radioText;
if (count _radioLog > 3) then {
    _radioLog deleteAt 0;
};
missionNamespace setVariable ["AAI_RadioLog", _radioLog];

diag_log format ["[TACTICAL COMMS] %1: %2", _roleTitle, _message];
