/*
    Author: Clement D. / Arma-AI Team
    File: fn_perceiveObstacles.sqf
    Tag: AAI_fnc_perceiveObstacles

    Description:
        Scans the tactical environment around an origin point or unit, discovers physical obstacles
        (e.g., VR blocks, urban walls, fortifications, vehicles, static structures), extracts their
        exact 3D bounding geometry (boundingBoxReal), transforms corner vertices into world coordinates,
        and determines their physical tactical classification (SolidCover, Concealment, Opening).

    Parameters:
        0: _origin       - Position (ARRAY [X,Y,Z] or [X,Y]) or OBJECT from which to scan [Default: player]
        1: _radius       - Search radius in meters (NUMBER) [Default: 40.0]
        2: _filterTypes  - Optional array of specific classnames or superclasses (ARRAY of STRINGS) [Default: []]
        3: _excludeUnits - Optional array of units/objects to ignore (ARRAY of OBJECTS) [Default: []]

    Returns:
        ARRAY of HASHMAPs: Each HashMap contains structured obstacle data:
            - "object": OBJECT
            - "type": STRING (class name)
            - "pos": ARRAY [X,Y,Z] (ATL position)
            - "centerWorld": ARRAY [X,Y,Z] (Geometric 3D center in world space)
            - "bbox": ARRAY [_min, _max] (Model space bounding box)
            - "dimensions": ARRAY [_dx, _dy, _dz] (Width X, Length Y, Height Z in meters)
            - "height": NUMBER (Effective height dz)
            - "width": NUMBER (Max horizontal dimension)
            - "classification": STRING ("SolidCover" | "Concealment" | "Opening")
            - "cornersWorld": ARRAY of 8 ARRAYS [X,Y,Z] (World space vertices)
            - "baseCornersWorld": ARRAY of 4 ARRAYS [X,Y,Z] (Ground vertices)
            - "topCornersWorld": ARRAY of 4 ARRAYS [X,Y,Z] (Top crest vertices)

    Example:
        private _obstacles = [player, 35] call AAI_fnc_perceiveObstacles;
*/

params [
    ["_origin", player, [objNull, []]],
    ["_radius", 40.0, [0]],
    ["_filterTypes", [], [[]]],
    ["_excludeUnits", [], [[]]]
];

// Normalize origin to 3D position ATL
private _scanPos = if (_origin isEqualType objNull) then {
    if (isNull _origin) exitWith { [0,0,0] };
    getPosATL _origin
} else {
    if (count _origin == 2) then { [_origin select 0, _origin select 1, 0] } else { _origin }
};

if (_scanPos isEqualTo [0,0,0]) exitWith { [] };

// Build exclusion list (include origin object if it was passed as unit)
private _ignored = +_excludeUnits;
if (_origin isEqualType objNull && {!isNull _origin}) then {
    _ignored pushBackUnique _origin;
};

// Target object types for spatial perception
private _targetTypes = if (count _filterTypes > 0) then {
    _filterTypes
} else {
    [
        "Building",
        "House",
        "Wall",
        "Static",
        "ThingX",
        "Land_VR_Block_01_F",
        "Land_VR_Block_02_F",
        "Land_VR_Block_03_F",
        "Land_VR_Block_04_F",
        "Land_VR_Block_05_F",
        "Land_VR_CoverObject_01_stand_F",
        "Land_VR_CoverObject_01_crouch_F",
        "Land_VR_CoverObject_01_kneel_F",
        "AllVehicles",
        "Strategic",
        "NonStrategic"
    ]
};

// Spatial query: Mission/placed objects AND Map-baked terrain objects
private _rawObjects = nearestObjects [_scanPos, _targetTypes, _radius, true];

// Scan real map terrain objects (Crucial for Stratis, Altis, etc.)
private _terrainTypes = [
    "BUILDING", "HOUSE", "CHURCH", "CHAPEL", "CROSS", 
    "BUNKER", "FORTRESS", "FOUNTAIN", "VIEW-TOWER", 
    "WALL", "FENCE", "RUIN", "ROCKS"
];
private _mapTerrainObjects = nearestTerrainObjects [_scanPos, _terrainTypes, _radius, false, true];

{
    if (!(_x in _rawObjects)) then {
        _rawObjects pushBack _x;
    };
} forEach _mapTerrainObjects;

private _perceivedObstacles = [];

// Helper classification function
private _fnc_classifyObstacle = {
    params ["_obj", "_typeName", "_dz", "_dx", "_dy"];

    // 1. VR Tactical blocks and predefined cover objects
    if (_typeName find "VR_Block" != -1 || {_typeName find "VR_CoverObject" != -1} || {_typeName find "VR_Shape" != -1}) exitWith {
        "SolidCover"
    };

    // 2. Concrete, stone, metal walls, sandbags, fortifications, containers, trenches
    if (_typeName find "Wall" != -1 || 
        {_typeName find "wall" != -1} ||
        {_typeName find "Barrier" != -1} || 
        {_typeName find "barrier" != -1} ||
        {_typeName find "Sandbag" != -1} || 
        {_typeName find "HBarrier" != -1} || 
        {_typeName find "Fort" != -1} || 
        {_typeName find "Container" != -1} || 
        {_typeName find "Bunker" != -1} || 
        {_typeName find "bunker" != -1} ||
        {_typeName find "Stone" != -1} || 
        {_typeName find "stone" != -1} ||
        {_typeName find "Concrete" != -1} ||
        {_typeName find "canal" != -1} ||
        {_typeName find "ditch" != -1}) exitWith {
        "SolidCover"
    };

    // 3. Vehicles (Wrecks, Armored, Cars)
    if (_obj isKindOf "AllVehicles") exitWith {
        if (!alive _obj || {_obj isKindOf "Tank"} || {_obj isKindOf "Car"}) then {
            "SolidCover"
        } else {
            "Concealment"
        };
    };

    // 4. Buildings & houses & churches
    if (_obj isKindOf "House" || 
        {_obj isKindOf "Building"} || 
        {_typeName find "House" != -1} || 
        {_typeName find "house" != -1} || 
        {_typeName find "Shop" != -1} || 
        {_typeName find "shop" != -1} || 
        {_typeName find "Church" != -1} || 
        {_typeName find "church" != -1} || 
        {_typeName find "Shed" != -1} || 
        {_typeName find "shed" != -1} || 
        {_typeName find "Barn" != -1}) exitWith {
        "SolidCover"
    };

    // 5. Foliage, bushes, trees, wood fences -> Concealment
    if (_typeName find "Tree" != -1 || 
        {_typeName find "Bush" != -1} || 
        {_typeName find "Wood" != -1} || 
        {_typeName find "Fence" != -1} || 
        {_typeName find "Plant" != -1}) exitWith {
        "Concealment"
    };

    // 6. Default fallback based on armor/density heuristics
    private _armor = getNumber (configFile >> "CfgVehicles" >> _typeName >> "armor");
    if (_armor >= 50 || _dz >= 0.8) then {
        "SolidCover"
    } else {
        "Concealment"
    };
};

{
    private _obj = _x;

    // Filter out invalid/ignored objects, living units, dead bodies, projectiles, perimeter walls
    if (!isNull _obj && 
        {!(_obj in _ignored)} && 
        {!(_obj getVariable ["AAI_IgnoreObstacle", false])} &&
        {!(_obj isKindOf "Man")} && 
        {!(_obj isKindOf "BulletCore")} && 
        {!(_obj isKindOf "LaserCore")} && 
        {!(_obj isKindOf "SmokeShell")}) then {

        // Extract real bounding box in model space
        private _bbox = boundingBoxReal _obj;
        _bbox params ["_min", "_max"];
        _min params ["_x1", "_y1", "_z1"];
        _max params ["_x2", "_y2", "_z2"];

        // Compute dimensions in meters
        private _dx = abs (_x2 - _x1);
        private _dy = abs (_y2 - _y1);
        private _dz = abs (_z2 - _z1);

        // Filter out microscopic clutter, tiny debris, and flat ground decals (dz >= 0.35m, footprint >= 0.3m)
        if (_dz >= 0.35 && {(_dx max _dy) >= 0.30}) then {

            private _typeName = typeOf _obj;
            if (_typeName == "") then {
                private _modelInfo = getModelInfo _obj;
                if (count _modelInfo > 0) then {
                    _typeName = _modelInfo select 0;
                } else {
                    _typeName = "TerrainObject";
                };
            };
            private _classification = [_obj, _typeName, _dz, _dx, _dy] call _fnc_classifyObstacle;

            // 8 Bounding Box Vertices in Model Space (Z-up, X-right, Y-forward)
            // Bottom 4 vertices (Ground plane)
            private _v0 = [_x1, _y1, _z1]; // Back-Left-Bottom
            private _v1 = [_x2, _y1, _z1]; // Back-Right-Bottom
            private _v2 = [_x2, _y2, _z1]; // Front-Right-Bottom
            private _v3 = [_x1, _y2, _z1]; // Front-Left-Bottom

            // Top 4 vertices (Crest plane)
            private _v4 = [_x1, _y1, _z2]; // Back-Left-Top
            private _v5 = [_x2, _y1, _z2]; // Back-Right-Top
            private _v6 = [_x2, _y2, _z2]; // Front-Right-Top
            private _v7 = [_x1, _y2, _z2]; // Front-Left-Top

            // Transform all 8 vertices to World Space (ATL) using modelToWorldVisual
            private _cornersWorld = [
                _obj modelToWorldVisual _v0,
                _obj modelToWorldVisual _v1,
                _obj modelToWorldVisual _v2,
                _obj modelToWorldVisual _v3,
                _obj modelToWorldVisual _v4,
                _obj modelToWorldVisual _v5,
                _obj modelToWorldVisual _v6,
                _obj modelToWorldVisual _v7
            ];

            private _baseCornersWorld = [
                _cornersWorld select 0,
                _cornersWorld select 1,
                _cornersWorld select 2,
                _cornersWorld select 3
            ];

            private _topCornersWorld = [
                _cornersWorld select 4,
                _cornersWorld select 5,
                _cornersWorld select 6,
                _cornersWorld select 7
            ];

            // Compute geometric center in World Space
            private _centerModel = [(_x1 + _x2) * 0.5, (_y1 + _y2) * 0.5, (_z1 + _z2) * 0.5];
            private _centerWorld = _obj modelToWorldVisual _centerModel;

            // Material classification & ballistic penetration resistance
            private _matClass = "MasonryStone";
            private _penRes = 0.85;

            if (_typeName find "Wall" != -1 || {_typeName find "Concrete" != -1} || {_typeName find "Bunker" != -1}) then {
                _matClass = "ReinforcedConcrete";
                _penRes = 1.0;
            } else {
                if (_typeName find "Sandbag" != -1 || {_typeName find "HBarrier" != -1} || {_typeName find "BagFence" != -1}) then {
                    _matClass = "SandbagComposite";
                    _penRes = 0.92;
                } else {
                    if (_typeName find "Wreck" != -1 || {_typeName find "Container" != -1} || {_typeName find "Cargo" != -1}) then {
                        _matClass = "BallisticSteel";
                        _penRes = 0.85;
                    } else {
                        if (_typeName find "Wood" != -1 || {_typeName find "Fence" != -1} || {_typeName find "Shed" != -1}) then {
                            _matClass = "TimberWood";
                            _penRes = 0.35;
                        } else {
                            if (_classification == "Concealment") then {
                                _matClass = "Foliage";
                                _penRes = 0.10;
                            };
                        };
                    };
                };
            };

            // Construct obstacle descriptor HashMap
            private _obsData = createHashMapFromArray [
                ["object", _obj],
                ["type", _typeName],
                ["pos", getPosATL _obj],
                ["centerWorld", _centerWorld],
                ["bbox", _bbox],
                ["dimensions", [_dx, _dy, _dz]],
                ["height", _dz],
                ["width", _dx max _dy],
                ["classification", _classification],
                ["materialClass", _matClass],
                ["penetrationResistance", _penRes],
                ["cornersWorld", _cornersWorld],
                ["baseCornersWorld", _baseCornersWorld],
                ["topCornersWorld", _topCornersWorld]
            ];

            _perceivedObstacles pushBack _obsData;
        };
    };
} forEach _rawObjects;

_perceivedObstacles
