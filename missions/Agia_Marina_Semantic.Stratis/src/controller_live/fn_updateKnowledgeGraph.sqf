/*
    Author: Clement D. / Arma-AI Team
    File: fn_updateKnowledgeGraph.sqf
    Tag: AAI_fnc_updateKnowledgeGraph

    Description:
        Real-time Tactical Knowledge Graph (TKG) episodic memory manager.
        Stores, queries, and updates dynamic RDF/OWL ABox triples generated during combat.
        Supports:
            - "RECORD_DAMAGE": Cover compromised by incoming fire (adds penalty).
            - "RECORD_KILL": Cover proved superior by eliminating hostile (adds bonus).
            - "GET_PENALTY": Computes accumulated semantic cost modifier for a given cover position.
            - "GET_TRIPLES": Returns all active ABox triples formatted in Turtle-like syntax.
            - "RESET": Clears episodic memory for a new engagement.

    Parameters:
        0: _action - Action string ("RECORD_DAMAGE" | "RECORD_KILL" | "GET_PENALTY" | "GET_TRIPLES" | "RESET")
        1: _params - Array of parameters specific to the action

    Returns:
        ANY - Depending on action: NUMBER for "GET_PENALTY", ARRAY for "GET_TRIPLES", BOOLEAN for updates.

    Example:
        ["RECORD_DAMAGE", [_unit, _damage, _source]] call AAI_fnc_updateKnowledgeGraph;
        private _penalty = ["GET_PENALTY", [_coverPos]] call AAI_fnc_updateKnowledgeGraph;
*/

params [
    ["_action", "GET_TRIPLES", [""]],
    ["_args", [], [[]]]
];

// Initialize global knowledge graph in missionNamespace if not present
if (isNil "AAI_KnowledgeGraph") then {
    AAI_KnowledgeGraph = createHashMapFromArray [
        ["triples", []],             // Array of [subject, predicate, object, timestamp]
        ["compromisedCovers", []],   // Array of [pos3D, penalty, sourceName, timestamp]
        ["superiorCovers", []]       // Array of [pos3D, bonus, targetName, timestamp]
    ];
};

private _kg = AAI_KnowledgeGraph;

switch (_action) do {

    // =========================================================================
    // RECORD_DAMAGE: Agent took damage while occupying a cover point
    // =========================================================================
    case "RECORD_DAMAGE": {
        _args params [
            ["_victim", objNull, [objNull]],
            ["_damage", 0, [0]],
            ["_source", objNull, [objNull]]
        ];

        if (isNull _victim) exitWith { false };

        private _coverData = _victim getVariable ["AAI_TargetCover", createHashMap];
        private _coverPos = _coverData getOrDefault ["coverPoint", []];
        if (count _coverPos < 3) then { _coverPos = getPosATL _victim; };
        private _obsObj = _coverData getOrDefault ["obstacle", objNull];
        private _obsType = if (!isNull _obsObj) then { typeOf _obsObj } else { "TerrainObstacle" };

        private _sourceName = if (!isNull _source) then { typeOf _source } else { "HostileFire" };
        private _victimName = if (name _victim != "Error: No unit" && name _victim != "") then { name _victim } else { typeOf _victim };

        // 1. Add compromised record
        private _compList = _kg get "compromisedCovers";
        _compList pushBack [_coverPos, 12.0, _sourceName, time];

        // 2. Generate formal ABox triples
        private _subj = format ["tac:Cover_%1_%2", round (_coverPos select 0), round (_coverPos select 1)];
        private _triples = _kg get "triples";

        _triples pushBack [_subj, "rdf:type", "tac:CompromisedCover", time];
        _triples pushBack [_subj, "tac:isPositionOf", _obsType, time];
        _triples pushBack [_subj, "tac:isCompromisedBy", _sourceName, time];
        _triples pushBack [_subj, "tac:hasVulnerabilityPenalty", "12.0", time];
        _triples pushBack [_subj, "tac:damageRecordedOn", _victimName, time];

        // Keep last 40 triples to prevent unbounded memory growth
        if (count _triples > 40) then {
            _triples deleteRange [0, (count _triples) - 40];
        };

        diag_log format ["[TICO KG LEARNING] %1 is COMPROMISED by %2! Generated ABox triples.", _subj, _sourceName];
        true
    };

    // =========================================================================
    // RECORD_KILL: Agent eliminated hostile from a cover point
    // =========================================================================
    case "RECORD_KILL": {
        _args params [
            ["_shooter", objNull, [objNull]],
            ["_victim", objNull, [objNull]]
        ];

        if (isNull _shooter) exitWith { false };

        private _coverData = _shooter getVariable ["AAI_TargetCover", createHashMap];
        private _coverPos = _coverData getOrDefault ["coverPoint", getPosATL _shooter];
        private _obsObj = _coverData getOrDefault ["obstacle", objNull];
        private _obsType = if (!isNull _obsObj) then { typeOf _obsObj } else { "TerrainObstacle" };

        private _victimName = if (!isNull _victim) then { typeOf _victim } else { "TargetHostile" };

        // 1. Add superior cover record
        private _supList = _kg get "superiorCovers";
        _supList pushBack [_coverPos, -6.0, _victimName, time];

        // 2. Generate formal ABox triples
        private _subj = format ["tac:Cover_%1_%2", round (_coverPos select 0), round (_coverPos select 1)];
        private _triples = _kg get "triples";

        _triples pushBack [_subj, "rdf:type", "tac:SuperiorFiringPosition", time];
        _triples pushBack [_subj, "tac:affordsTacticalSuperiority", "true", time];
        _triples pushBack [_subj, "tac:eliminatedTarget", _victimName, time];
        _triples pushBack [_subj, "tac:tacticalAdvantageBonus", "-6.0", time];

        diag_log format ["[TICO KG LEARNING] %1 marked as SUPERIOR FIRING POSITION! (Killed %2)", _subj, _victimName];
        true
    };

    // =========================================================================
    // GET_PENALTY: Query accumulated semantic cost modifier for a candidate position
    // =========================================================================
    case "GET_PENALTY": {
        _args params [
            ["_candidatePos", [0,0,0], [[]]]
        ];

        private _modifier = 0.0;

        // Check proximity to any compromised cover (within 4 meters radius)
        private _compList = _kg get "compromisedCovers";
        {
            _x params ["_pos", "_pen", "_src", "_t"];
            private _d = _candidatePos distance2D _pos;
            if (_d < 4.0) then {
                // Closer to compromised point = higher penalty
                private _weight = (1.0 - (_d / 4.0)) * _pen;
                _modifier = _modifier + _weight;
            };
        } forEach _compList;

        // Check proximity to any superior cover (within 4 meters radius)
        private _supList = _kg get "superiorCovers";
        {
            _x params ["_pos", "_bonus", "_target", "_t"];
            private _d = _candidatePos distance2D _pos;
            if (_d < 4.0) then {
                private _weight = (1.0 - (_d / 4.0)) * _bonus; // Negative value (bonus)
                _modifier = _modifier + _weight;
            };
        } forEach _supList;

        _modifier
    };

    // =========================================================================
    // GET_TRIPLES: Return all active triples formatted as strings
    // =========================================================================
    case "GET_TRIPLES": {
        _kg getOrDefault ["triples", []]
    };

    // =========================================================================
    // RESET: Clear knowledge graph for a new round
    // =========================================================================
    case "RESET": {
        _kg set ["triples", []];
        _kg set ["compromisedCovers", []];
        _kg set ["superiorCovers", []];
        diag_log "[TICO KG LEARNING] Knowledge graph reset for new round.";
        true
    };

    default { nil };
};
