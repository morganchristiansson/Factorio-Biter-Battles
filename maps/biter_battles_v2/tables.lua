local GUI_VARIANTS = require('utils.utils').GUI_VARIANTS

local Public = {}

-- List of forces that will be affected by ammo modifier
Public.ammo_modified_forces_list = { 'north', 'south', 'spectator' }

-- Ammo modifiers via set_ammo_damage_modifier
-- [ammo_category] = value
-- ammo_modifier_dmg = base_damage * base_ammo_modifiers
-- damage = base_damage + ammo_modifier_dmg
Public.base_ammo_modifiers = {
    ['shotgun-shell'] = 1,
}

-- turret attack modifier via set_turret_attack_modifier
Public.base_turret_attack_modifiers = {
    ['flamethrower-turret'] = -0.9,
}

Public.food_values = {
    ['automation-science-pack'] = { value = 0.001, name = 'automation science', color = '255, 50, 50' },
    ['logistic-science-pack'] = { value = 0.0025, name = 'logistic science', color = '50, 255, 50' },
    ['military-science-pack'] = { value = 0.0105, name = 'military science', color = '105, 105, 105' },
    ['chemical-science-pack'] = { value = 0.029, name = 'chemical science', color = '100, 200, 255' },
    ['space-science-pack'] = { value = 0.054, name = 'space science', color = '255, 255, 255' },
    ['production-science-pack'] = { value = 0.102, name = 'production science', color = '150, 25, 255' },
    ['utility-science-pack'] = { value = 0.167, name = 'utility science', color = '210, 210, 60' },
    ['metallurgic-science-pack'] = { value = 0.14, name = 'metallurgic science', color = '255, 165, 0' },
    ['electromagnetic-science-pack'] = { value = 0.151, name = 'electromagnetic science', color = '255, 192, 203' },
    ['agricultural-science-pack'] = { value = 0.012, name = 'agricultural science', color = '192, 255, 0' },
    ['cryogenic-science-pack'] = { value = 0.189, name = 'cryogenic science', color = '0, 0, 139' },
    ['promethium-science-pack'] = { value = 9.001, name = 'promethium science', color = '40, 20, 40' },
}

Public.gui_foods = {}
for k, v in pairs(Public.food_values) do
    Public.gui_foods[k] = math.floor(v.value * 1000) .. ' Mutagen strength'
end
Public.gui_foods['raw-fish'] =
    'Send a fish to spy for 45 seconds.\nLeft Mouse Button: Send one fish.\nRMB: Sends 5 fish.\nShift+LMB: Send all fish.\nShift+RMB: Send half of all fish.'

Public.force_translation = {
    ['south_biters'] = 'south',
    ['north_biters'] = 'north',
}

Public.enemy_team_of = {
    ['north'] = 'south',
    ['south'] = 'north',
}

Public.food_names = {
    ['automation-science-pack'] = true,
    ['logistic-science-pack'] = true,
    ['military-science-pack'] = true,
    ['chemical-science-pack'] = true,
    ['space-science-pack'] = true,
    ['production-science-pack'] = true,
    ['utility-science-pack'] = true,
    ['agricultural-science-pack'] = true,
    ['metallurgic-science-pack'] = true,
    ['electromagnetic-science-pack'] = true,
    ['cryogenic-science-pack'] = true,
    ['promethium-science-pack'] = true,
}

Public.food_long_and_short = {
    [1] = { short_name = 'automation', long_name = 'automation-science-pack' },
    [2] = { short_name = 'logistic', long_name = 'logistic-science-pack' },
    [3] = { short_name = 'military', long_name = 'military-science-pack' },
    [4] = { short_name = 'chemical', long_name = 'chemical-science-pack' },
    [5] = { short_name = 'space', long_name = 'space-science-pack' },
    [6] = { short_name = 'production', long_name = 'production-science-pack' },
    [7] = { short_name = 'utility', long_name = 'utility-science-pack' },
    [8] = { short_name = 'gleba', long_name = 'agricultural-science-pack' },
    [9] = { short_name = 'vulcanus', long_name = 'metallurgic-science-pack' },
    [10] = { short_name = 'fulgora', long_name = 'electromagnetic-science-pack' },
    [11] = { short_name = 'aquilo', long_name = 'cryogenic-science-pack' },
    [12] = { short_name = 'promethium', long_name = 'promethium-science-pack' },
}

Public.food_long_to_short = {
    ['automation-science-pack'] = { short_name = 'automation', indexScience = 1 },
    ['logistic-science-pack'] = { short_name = 'logistic', indexScience = 2 },
    ['military-science-pack'] = { short_name = 'military', indexScience = 3 },
    ['chemical-science-pack'] = { short_name = 'chemical', indexScience = 4 },
    ['space-science-pack'] = { short_name = 'space', indexScience = 5 },
    ['production-science-pack'] = { short_name = 'production', indexScience = 6 },
    ['utility-science-pack'] = { short_name = 'utility', indexScience = 7 },
    ['agricultural-science-pack'] = { short_name = 'gleba', indexScience = 8 },
    ['metallurgic-science-pack'] = { short_name = 'vulcanus', indexScience = 9 },
    ['electromagnetic-science-pack'] = { short_name = 'fulgora', indexScience = 10 },
    ['cryogenic-science-pack'] = { short_name = 'aquilo', indexScience = 11 },
    ['promethium-science-pack'] = { short_name = 'promethium', indexScience = 12 },
}

-- This array contains parameters for spawn area ore patches.
-- These are non-standard units and they do not map to values used in factorio
-- map generation. They are only used internally by scenario logic.
Public.spawn_ore = {
    -- Value "size" is a parameter used as coefficient for simplex noise
    -- function that is applied to shape of an ore patch. You can think of it
    -- as size of a patch on average. Recomended range is from 1 up to 50.

    -- Value "density" controls the amount of resource in a single tile.
    -- The center of an ore patch contains specified amount and is decreased
    -- proportionally to distance from center of the patch.

    -- Value "big_patches" and "small_patches" represents a number of an ore
    -- patches of given type. The "density" is applied with the same rule
    -- regardless of the patch size.
    ['iron-ore'] = {
        size = 23,
        density = 3500,
        big_patches = 2,
        small_patches = 1,
    },
    ['copper-ore'] = {
        size = 21,
        density = 3000,
        big_patches = 1,
        small_patches = 2,
    },
    ['coal'] = {
        size = 22,
        density = 2500,
        big_patches = 1,
        small_patches = 1,
    },
    ['stone'] = {
        size = 20,
        density = 2000,
        big_patches = 1,
        small_patches = 0,
    },
}

Public.difficulties = {
    [1] = {
        name = "I'm Too Young to Die",
        short_name = 'ITYTD',
        str = '25%',
        value = 0.25,
        color = {
            [GUI_VARIANTS.Dark] = { r = 0.00, g = 1.00, b = 0.00 },
            [GUI_VARIANTS.Light] = { r = 0.00, g = 0.50, b = 0.00 },
        },
    },
    [2] = {
        name = 'Have a Nice Day',
        short_name = 'HaND',
        str = '38%',
        value = 0.38,
        color = {
            [GUI_VARIANTS.Dark] = { r = 0.33, g = 1.00, b = 0.00 },
            [GUI_VARIANTS.Light] = { r = 0.13, g = 0.40, b = 0.00 },
        },
    },
    [3] = {
        name = 'Piece of Cake',
        short_name = 'PoC',
        str = '50%',
        value = 0.5,
        color = {
            [GUI_VARIANTS.Dark] = { r = 0.67, g = 1.00, b = 0.00 },
            [GUI_VARIANTS.Light] = { r = 0.17, g = 0.30, b = 0.00 },
        },
    },
    [4] = {
        name = 'Easy',
        short_name = 'Easy',
        str = '75%',
        value = 0.75,
        color = {
            [GUI_VARIANTS.Dark] = { r = 1.00, g = 1.00, b = 0.00 },
            [GUI_VARIANTS.Light] = { r = 0.30, g = 0.30, b = 0.00 },
        },
    },
    [5] = {
        name = 'Normal',
        short_name = 'Normal',
        str = '100%',
        value = 1,
        color = {
            [GUI_VARIANTS.Dark] = { r = 1.00, g = 0.67, b = 0.00 },
            [GUI_VARIANTS.Light] = { r = 0.30, g = 0.17, b = 0.00 },
        },
    },
    [6] = {
        name = 'Hard',
        short_name = 'Hard',
        str = '200%',
        value = 2,
        color = {
            [GUI_VARIANTS.Dark] = { r = 1.00, g = 0.33, b = 0.00 },
            [GUI_VARIANTS.Light] = { r = 0.40, g = 0.13, b = 0.00 },
        },
    },
    [7] = {
        name = 'Fun and Fast',
        short_name = 'FnF',
        str = '500%',
        value = 5,
        color = {
            [GUI_VARIANTS.Dark] = { r = 1.00, g = 0.00, b = 0.00 },
            [GUI_VARIANTS.Light] = { r = 0.40, g = 0.00, b = 0.00 },
        },
    },
}

Public.difficulty_lowered_names_to_index = {
    ["i'm too young to die"] = 1,
    ['itytd'] = 1,
    ['have a nice day'] = 2,
    ['hand'] = 2,
    ['piece of cake'] = 3,
    ['poc'] = 3,
    ['easy'] = 4,
    ['normal'] = 5,
    ['hard'] = 6,
    ['fun and fast'] = 7,
    ['fnf'] = 7,
}

Public.forces_list = { 'all teams', 'north', 'south' }
Public.science_list = {
    'all science',
    'very high tier (promethium, aquilo, fulgora)',
    'high tier (promethium, aquilo, fulgora, vulcanus, utility)',
    'mid+ tier (promethium, aquilo, fulgora, vulcanus, utility, production, gleba, chemical, military)',
    'promethium',
    'aquilo',
    'fulgora',
    'vulcanus',
    'gleba',
    'space',
    'utility',
    'production',
    'chemical',
    'military',
    'logistic',
    'automation',
}
Public.evofilter_list =
    { 'all evo jump', 'no 0 evo jump', '10+ only', '5+ only', '4+ only', '3+ only', '2+ only', '1+ only' }
Public.food_value_table_version = {
    Public.food_values['automation-science-pack'].value,
    Public.food_values['logistic-science-pack'].value,
    Public.food_values['military-science-pack'].value,
    Public.food_values['chemical-science-pack'].value,
    Public.food_values['production-science-pack'].value,
    Public.food_values['utility-science-pack'].value,
    Public.food_values['space-science-pack'].value,
    Public.food_values['metallurgic-science-pack'].value,
    Public.food_values['electromagnetic-science-pack'].value,
    Public.food_values['agricultural-science-pack'].value,
    Public.food_values['cryogenic-science-pack'].value,
    Public.food_values['promethium-science-pack'].value,
}

return Public
