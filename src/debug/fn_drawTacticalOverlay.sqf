/*
    Author: Clement D. / Arma-AI Team
    File: fn_drawTacticalOverlay.sqf
    Tag: AAI_fnc_drawTacticalOverlay

    Description:
        Real-time 3D tactical debug visualizer rendering in the Arma 3 viewport via
        the "Draw3D" mission event handler.
        Visualizes:
            1. 3D Obstacle bounding boxes with color-coded classification
               (Green = SolidCover, Yellow = Concealment, Cyan = Active Selected Cover).
            2. Threat sightlines and ballistic danger vectors (Red 3D lines and icons).
            3. Ballistic shadow polygons (Safe occlusion cones extruded behind cover).
            4. Affordance target points (Cover anchor, Left/Right peek points).
            5. Agent tactical state HUD floating in 3D space above the unit.

    Parameters:
        0: _enable - Enable or disable overlay rendering (BOOLEAN) [Default: true]
        1: _agent  - Tactical agent unit to monitor (OBJECT) [Default: player]

    Returns:
        NUMBER - Event Handler ID (or -1 if removed)

    Example:
        [true, tactical_agent] call AAI_fnc_drawTacticalOverlay;
        [false] call AAI_fnc_drawTacticalOverlay; // Disables overlay
*/

params [
    ["_enable", true, [true]],
    ["_agent", player, [objNull]]
];

// Helper: Ensure position is in ASL for Draw3D line primitives
private _fnc_toASL = {
    params ["_pos"];
    if (count _pos < 3) exitWith { [0,0,0] };
    if (_pos select 2 < 0) then { _pos set [2, 0]; };
    ATLToASL _pos
};

// Remove existing event handler if already active
if (!isNil "AAI_Draw3D_Handler") then {
    removeMissionEventHandler ["Draw3D", AAI_Draw3D_Handler];
    AAI_Draw3D_Handler = nil;
};

if (!_enable) exitWith { -1 };

// Persist the agent reference globally for the draw thread
AAI_Debug_MonitoredAgent = _agent;

AAI_Draw3D_Handler = addMissionEventHandler ["Draw3D", {
    private _unit = missionNamespace getVariable ["AAI_Debug_MonitoredAgent", player];
    if (isNull _unit || {!alive _unit}) exitWith {};

    private _toASL = {
        params ["_p"];
        ATLToASL [_p select 0, _p select 1, (_p select 2) max 0]
    };

    // Retrieve tactical telemetry from agent variables
    private _state = _unit getVariable ["AAI_TacticalState", "IDLE"];
    private _threat = _unit getVariable ["AAI_ActiveThreat", objNull];
    private _chosenCover = _unit getVariable ["AAI_TargetCover", createHashMap];
    private _obstacles = _unit getVariable ["AAI_PerceivedObstacles", []];
    private _shadows = _unit getVariable ["AAI_CoverShadows", []];
    private _affordance = _unit getVariable ["AAI_TargetAffordance", createHashMap];

    private _chosenObstacleObj = _chosenCover getOrDefault ["obstacle", objNull];
    private _chosenCoverPoint = _chosenCover getOrDefault ["coverPoint", []];

    // -------------------------------------------------------------------------
    // 1. Threat Visualization (Red Sightline & Threat Header)
    // -------------------------------------------------------------------------
    private _threatPosASL = [0,0,0];
    if (!isNull _threat && {_threat isEqualType objNull} && {alive _threat}) then {
        _threatPosASL = eyePos _threat;
        private _threatHeadPos = getPosATL _threat;
        _threatHeadPos set [2, (_threatHeadPos select 2) + 2.1];

        // Threat Icon & Tag
        drawIcon3D [
            "\a3\ui_f\data\map\markers\military\destroy_CA.paa",
            [1.0, 0.2, 0.2, 0.9],
            ATLToASL _threatHeadPos,
            0.8, 0.8, 0,
            format ["THREAT: %1 (%2m)", typeOf _threat, round (_unit distance _threat)],
            2, 0.035, "PuristaMedium", "center", true
        ];

        // Red Threat Sightline to Agent
        private _unitEyeASL = eyePos _unit;
        drawLine3D [_threatPosASL, _unitEyeASL, [1.0, 0.1, 0.1, 0.85]];

    } else {
        if (_threat isEqualType [] && {count _threat >= 3}) then {
            _threatPosASL = [_threat] call _toASL;
            drawIcon3D [
                "\a3\ui_f\data\map\markers\military\warning_CA.paa",
                [1.0, 0.3, 0.1, 0.9],
                _threatPosASL,
                0.7, 0.7, 0,
                "THREAT VECTOR",
                2, 0.035, "PuristaMedium", "center", true
            ];
        };
    };

    // -------------------------------------------------------------------------
    // 2. Obstacle 3D Bounding Boxes
    // -------------------------------------------------------------------------
    {
        private _obs = _x;
        private _obj = _obs get "object";
        private _corners = _obs get "cornersWorld";
        private _classification = _obs get "classification";
        private _height = _obs get "height";
        private _type = _obs get "type";

        // Determine Wireframe Color
        private _boxColor = if (_obj == _chosenObstacleObj) then {
            [0.1, 0.9, 1.0, 0.95] // Cyan for Active Selected Target Obstacle
        } else {
            if (_classification == "SolidCover") then {
                [0.2, 0.9, 0.3, 0.65] // Green for Solid Cover
            } else {
                [0.9, 0.8, 0.1, 0.65] // Yellow for Concealment
            };
        };

        if (count _corners == 8) then {
            private _aslCorners = _corners apply { [_x] call _toASL };

            // Bottom Ring (0-1-2-3-0)
            drawLine3D [_aslCorners select 0, _aslCorners select 1, _boxColor];
            drawLine3D [_aslCorners select 1, _aslCorners select 2, _boxColor];
            drawLine3D [_aslCorners select 2, _aslCorners select 3, _boxColor];
            drawLine3D [_aslCorners select 3, _aslCorners select 0, _boxColor];

            // Top Ring (4-5-6-7-4)
            drawLine3D [_aslCorners select 4, _aslCorners select 5, _boxColor];
            drawLine3D [_aslCorners select 5, _aslCorners select 6, _boxColor];
            drawLine3D [_aslCorners select 6, _aslCorners select 7, _boxColor];
            drawLine3D [_aslCorners select 7, _aslCorners select 4, _boxColor];

            // Vertical Pillars
            drawLine3D [_aslCorners select 0, _aslCorners select 4, _boxColor];
            drawLine3D [_aslCorners select 1, _aslCorners select 5, _boxColor];
            drawLine3D [_aslCorners select 2, _aslCorners select 6, _boxColor];
            drawLine3D [_aslCorners select 3, _aslCorners select 7, _boxColor];

            // Obstacle Classification Label
            private _centerPos = _obs get "centerWorld";
            private _labelPosASL = [_centerPos select 0, _centerPos select 1, (_centerPos select 2) + (_height * 0.5) + 0.3];
            
            drawIcon3D [
                "",
                _boxColor,
                ATLToASL _labelPosASL,
                0, 0, 0,
                format ["%1 (H: %2m)", _classification, (_height toFixed 1)],
                0, 0.028, "PuristaLight", "center", true
            ];
        };
    } forEach _obstacles;

    // -------------------------------------------------------------------------
    // 3. Ballistic Cover Shadows (Safe Zone Cones)
    // -------------------------------------------------------------------------
    {
        private _sh = _x;
        private _poly = _sh get "shadowPolygon";
        private _crest = _sh get "shadowCrestPolygon";
        private _isTarget = ((_sh get "obstacle") == _chosenObstacleObj);

        private _shadowColor = if (_isTarget) then {
            [0.1, 0.9, 0.4, 0.85] // Bright Green for Chosen Shadow
        } else {
            [0.2, 0.6, 0.9, 0.45] // Translucent Blue for Other Shadows
        };

        if (count _poly == 4) then {
            private _pASL = _poly apply { [_x] call _toASL };

            // Ground Polygon (Left -> Right -> ShadowRight -> ShadowLeft -> Left)
            drawLine3D [_pASL select 0, _pASL select 1, _shadowColor];
            drawLine3D [_pASL select 1, _pASL select 2, _shadowColor];
            drawLine3D [_pASL select 2, _pASL select 3, _shadowColor];
            drawLine3D [_pASL select 3, _pASL select 0, _shadowColor];

            // Crest Polygon (Top of shadow cone)
            if (count _crest == 4) then {
                private _cASL = _crest apply { [_x] call _toASL };
                drawLine3D [_cASL select 0, _cASL select 1, _shadowColor];
                drawLine3D [_cASL select 1, _cASL select 2, _shadowColor];
                drawLine3D [_cASL select 2, _cASL select 3, _shadowColor];
                drawLine3D [_cASL select 3, _cASL select 0, _shadowColor];

                // Side connector lines
                drawLine3D [_pASL select 2, _cASL select 2, _shadowColor];
                drawLine3D [_pASL select 3, _cASL select 3, _shadowColor];
            };
        };
    } forEach _shadows;

    // -------------------------------------------------------------------------
    // 4. Affordance Target Points & Flanks
    // -------------------------------------------------------------------------
    if (count _chosenCoverPoint >= 3) then {
        private _coverPosASL = [_chosenCoverPoint] call _toASL;
        private _stanceName = _affordance getOrDefault ["stanceName", "STAND"];
        private _stanceToken = _affordance getOrDefault ["stance", "UP"];
        private _cost = _chosenCover getOrDefault ["costScore", 0.0];

        // Draw Cover Anchor Marker
        drawIcon3D [
            "\a3\ui_f\data\map\markers\military\dot_CA.paa",
            [0.1, 1.0, 0.3, 0.95],
            _coverPosASL,
            0.6, 0.6, 0,
            format ["AFFORDANCE: %1 [%2] (Cost: %3)", _stanceName, _stanceToken, (_cost toFixed 1)],
            2, 0.035, "PuristaBold", "center", true
        ];

        // Draw Trajectory line from Agent to Cover
        drawLine3D [ATLToASL (getPosATL _unit), _coverPosASL, [0.1, 0.9, 1.0, 0.8]];

        // Draw Peek / Flank Points
        private _flankL = _chosenCover getOrDefault ["flankLeft", []];
        private _flankR = _chosenCover getOrDefault ["flankRight", []];

        if (count _flankL >= 3) then {
            drawIcon3D [
                "\a3\ui_f\data\map\markers\military\join_CA.paa",
                [1.0, 0.8, 0.2, 0.85],
                [_flankL] call _toASL,
                0.4, 0.4, 0,
                "PEEK [L]",
                1, 0.025, "PuristaMedium", "center", true
            ];
        };

        if (count _flankR >= 3) then {
            drawIcon3D [
                "\a3\ui_f\data\map\markers\military\join_CA.paa",
                [1.0, 0.8, 0.2, 0.85],
                [_flankR] call _toASL,
                0.4, 0.4, 0,
                "PEEK [R]",
                1, 0.025, "PuristaMedium", "center", true
            ];
        };
    };

    // -------------------------------------------------------------------------
    // 5. Agent Status HUD (3D Overhead Banner)
    // -------------------------------------------------------------------------
    private _agentHeadPos = getPosATL _unit;
    _agentHeadPos set [2, (_agentHeadPos select 2) + 2.2];

    private _stateColor = switch (_state) do {
        case "IN_COVER": { [0.2, 0.9, 0.3, 0.95] };
        case "MOVING_TO_COVER": { [0.1, 0.8, 1.0, 0.95] };
        case "NO_COVER_FOUND": { [1.0, 0.3, 0.1, 0.95] };
        default { [0.8, 0.8, 0.8, 0.9] };
    };

    drawIcon3D [
        "\a3\ui_f\data\map\markers\military\triangle_CA.paa",
        _stateColor,
        ATLToASL _agentHeadPos,
        0.5, 0.5, 180,
        format ["AAI AGENT: %1 | POS: %2", _state, unitPos _unit],
        2, 0.038, "PuristaBold", "center", true
    ];
}];

AAI_Draw3D_Handler
