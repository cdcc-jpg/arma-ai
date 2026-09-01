/*
    Author: Clement D. / Arma-AI Team
    Mission: AAI Tactical Grounding & Affordance Sandbox (VR)
    File: init.sqf
*/

diag_log "[AAI Grounding Sandbox] Initializing scenario...";

// Brief initialization delay for world and entities
if (isNil "tactical_agent" || {isNull tactical_agent}) then {
    // Dynamic spawn fallback if not placed in 3DEN editor
    private _grpWest = createGroup [west, true];
    tactical_agent = _grpWest createUnit ["B_Soldier_F", [7010, 7000, 0], [], 0, "NONE"];
    tactical_agent setVehicleVarName "tactical_agent";
    tactical_agent setDir 0;
};

if (isNil "threat_opfor" || {isNull threat_opfor}) then {
    // Dynamic spawn fallback for OPFOR threat
    private _grpEast = createGroup [east, true];
    threat_opfor = _grpEast createUnit ["O_Soldier_F", [7010, 7045, 0], [], 0, "NONE"];
    threat_opfor setVehicleVarName "threat_opfor";
    threat_opfor setDir 180;
};

// Configure tactical agent properties
tactical_agent setUnitPos "UP";
tactical_agent setSkill 1.0;
tactical_agent allowDamage false; // Keep immortal for uninterrupted sandbox testing
threat_opfor allowDamage false;
threat_opfor disableAI "AUTOTARGET";
threat_opfor disableAI "AUTOCOMBAT";

// Launch 3D Tactical Debug Visualizer
if (hasInterface) then {
    [true, tactical_agent] call AAI_fnc_drawTacticalOverlay;

    // Add Player Interactive Sandbox Controls
    player addAction ["<t color='#00ffcc'>[AAI] Toggle 3D Debug Visualizer</t>", {
        if (isNil "AAI_Draw3D_Handler") then {
            [true, tactical_agent] call AAI_fnc_drawTacticalOverlay;
            systemChat "[AAI] 3D Tactical Overlay ENABLED.";
        } else {
            [false] call AAI_fnc_drawTacticalOverlay;
            systemChat "[AAI] 3D Tactical Overlay DISABLED.";
        };
    }, nil, 1.5, false, false, "", "true", 50];

    player addAction ["<t color='#ff5555'>[AAI] Move Threat: Flank Left (+15m)</t>", {
        private _curPos = getPosATL threat_opfor;
        threat_opfor setPosATL [(_curPos select 0) - 15, _curPos select 1, _curPos select 2];
        systemChat "[AAI] Threat repositioned to West flank.";
        [tactical_agent, threat_opfor, 45.0, true] call AAI_fnc_tacticalTick;
    }, nil, 1.4, false, false, "", "true", 50];

    player addAction ["<t color='#ff5555'>[AAI] Move Threat: Flank Right (+15m)</t>", {
        private _curPos = getPosATL threat_opfor;
        threat_opfor setPosATL [(_curPos select 0) + 15, _curPos select 1, _curPos select 2];
        systemChat "[AAI] Threat repositioned to East flank.";
        [tactical_agent, threat_opfor, 45.0, true] call AAI_fnc_tacticalTick;
    }, nil, 1.4, false, false, "", "true", 50];

    player addAction ["<t color='#ffaa00'>[AAI] Move Threat: Elevate (+8m Plunging Fire)</t>", {
        private _curPos = getPosATL threat_opfor;
        threat_opfor setPosATL [_curPos select 0, _curPos select 1, (_curPos select 2) + 8];
        systemChat "[AAI] Threat elevated to +8m (Testing plunging fire & roof exposure).";
        [tactical_agent, threat_opfor, 45.0, true] call AAI_fnc_tacticalTick;
    }, nil, 1.3, false, false, "", "true", 50];

    player addAction ["<t color='#ffff00'>[AAI] Reset Threat Position</t>", {
        threat_opfor setPosATL [7010, 7045, 0];
        systemChat "[AAI] Threat reset to original position [7010, 7045, 0].";
        [tactical_agent, threat_opfor, 45.0, true] call AAI_fnc_tacticalTick;
    }, nil, 1.2, false, false, "", "true", 50];

    player addAction ["<t color='#33ff33'>[AAI] Spawn Dynamic VR Block</t>", {
        private _spawnPos = (getPosATL player) vectorAdd [0, 5, 0];
        private _block = createVehicle ["Land_VR_Block_03_F", _spawnPos, [], 0, "CAN_COLLIDE"];
        _block setPosATL _spawnPos;
        systemChat format ["[AAI] Spawned dynamic VR block at %1", _spawnPos];
        [tactical_agent, threat_opfor, 45.0, true] call AAI_fnc_tacticalTick;
    }, nil, 1.1, false, false, "", "true", 50];

    hintSilent parseText "<t size='1.2' color='#00ffcc'>AAI Grounding Sandbox Loaded</t><br/><br/>The autonomous tactical agent is running spatial grounding ticks.<br/>Use action menu (scroll wheel) to reposition the threat or toggle visual overlays.";
};

// Launch Autonomous Agent Tactical Loop
[tactical_agent, threat_opfor, 0.35] spawn AAI_fnc_startAgentController;

diag_log "[AAI Grounding Sandbox] Initialization completed successfully.";
