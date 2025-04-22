local Public = {}
local LootRaffle = require('functions.loot_raffle')
local BiterRaffle = require('maps.biter_battles_v2.biter_raffle')
local bb_config = require('maps.biter_battles_v2.config')
local multi_octave_noise = require('utils.multi_octave_noise')
local noise = require('maps.biter_battles_v2.predefined_noise')
local AiTargets = require('maps.biter_battles_v2.ai_targets')
local tables = require('maps.biter_battles_v2.tables')
local session = require('utils.datastore.session_data')

local ai_targets_start_tracking = AiTargets.start_tracking
local bb_config_bitera_area_distance = bb_config.bitera_area_distance
local bb_config_biter_area_slope = bb_config.biter_area_slope
local spawn_ore = tables.spawn_ore
local table_insert = table.insert
local table_remove = table.remove
local math_abs = math.abs
local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_random = math.random
local math_sqrt = math.sqrt

local get_noise = multi_octave_noise.get
local get_lower_bounded_noise = multi_octave_noise.get_lower_bounded
local get_upper_bounded_noise = multi_octave_noise.get_upper_bounded
local get_noise_between_bounds = multi_octave_noise.get_between_bounds

function amp_sum(octaves)
    local result = 0
    for _, octave in pairs(octaves) do
        result = result + octave.amp
    end
    return result
end

local spawn_wall_noise = noise.spawn_wall
local spawn_wall_noise_amp_sum = amp_sum(spawn_wall_noise)

local spawn_wall_2_noise = noise.spawn_wall_2
local spawn_wall_2_noise_amp_sum = amp_sum(spawn_wall_2_noise)

local spawn_ore_noise = noise.spawn_ore
local spawn_ore_noise_amp_sum = amp_sum(spawn_ore_noise)

-- avoid allocations to improve performance and maybe reduce gc lag
local preallocated_out_of_map_tiles = {}
local preallocated_tiles = {}
for i = 1, 32 * 32 do
    preallocated_out_of_map_tiles[i] = { name = 'out-of-map', position = { 0, 0 } }
    preallocated_tiles[i] = { name = '', position = { 0, 0 } }
end
local next_preallocated_tile = 1

-- max value 64
local river_circle_size = 39

local river_width_half = math_floor(bb_config.border_river_width * 0.5)

-- max value 32
local spawn_island_size = 9

local rocks = { 'huge-rock', 'big-rock', 'big-rock', 'big-rock', 'big-sand-rock' }

-- 32 * 32 buffers
local chunk_buffer = {}
local chunk_buffer2 = {}

local chunk_tile_vectors = {}
for x = 0, 31, 1 do
    for y = 0, 31, 1 do
        chunk_tile_vectors[#chunk_tile_vectors + 1] = { x, y }
    end
end
local size_of_chunk_tile_vectors = #chunk_tile_vectors

local loading_chunk_vectors = {}
for _, v in pairs(chunk_tile_vectors) do
    if v[1] == 0 or v[1] == 31 or v[2] == 0 or v[2] == 31 then
        table_insert(loading_chunk_vectors, v)
    end
end

local wrecks = {
    'crash-site-spaceship-wreck-big-1',
    'crash-site-spaceship-wreck-big-2',
    'crash-site-spaceship-wreck-medium-1',
    'crash-site-spaceship-wreck-medium-2',
    'crash-site-spaceship-wreck-medium-3',
}
local size_of_wrecks = #wrecks
local valid_wrecks = {}
for _, wreck in pairs(wrecks) do
    valid_wrecks[wreck] = true
end
local loot_blacklist = {
    ['automation-science-pack'] = true,
    ['logistic-science-pack'] = true,
    ['military-science-pack'] = true,
    ['chemical-science-pack'] = true,
    ['production-science-pack'] = true,
    ['utility-science-pack'] = true,
    ['space-science-pack'] = true,
    ['loader'] = true,
    ['fast-loader'] = true,
    ['express-loader'] = true,
}

function Public.adjust_map_gen_settings(map_gen_settings)
--     map_gen_settings.default_enable_all_autoplace_controls = false
    map_gen_settings.starting_area = 2.5
    local pen = map_gen_settings.property_expression_names
    pen['control:gleba_water:size'] = "1"

    map_gen_settings.cliff_settings = { cliff_elevation_interval = 0, cliff_elevation_0 = 0 }

    local ac = map_gen_settings.autoplace_controls
    ac['coal'] = { frequency = 6.5, size = 0.34, richness = 0.24 }
    ac['stone'] = { frequency = 6, size = 0.385, richness = 0.25 }
    ac['copper-ore'] = { frequency = 8.05, size = 0.352, richness = 0.35 }
    ac['iron-ore'] = { frequency = 8.5, size = 0.8, richness = 0.23 }
    ac['uranium-ore'] = { frequency = 2.2, size = 1, richness = 1 }
    ac['crude-oil'] = { frequency = 8, size = 1.4, richness = 0.45 }
    ac['water'] = { frequency = 10, size = 0.3 }
    ac['trees'] = { frequency = 0.65, size = 0.04 }
end

---@enum area_intersection
area_intersection = {
    none = 1,
    partial = 2,
    full = 3,
}

---Analyzes partiality of intersection of a north chunk and the biter area
---@param chunk_pos {x: int, y: int} north chunk position (not tile position)
---@return area_intersection
local function chunk_biter_area_intersection(chunk_pos)
    local left_top_x = chunk_pos.x * 32
    local right_top_x = left_top_x + 32 - 1

    local bitera_area_distance = bb_config.bitera_area_distance * -1
    local min_slope = bitera_area_distance - (math_abs(left_top_x) * bb_config.biter_area_slope)
    local max_slope = bitera_area_distance - (math_abs(right_top_x) * bb_config.biter_area_slope)
    if min_slope > max_slope then
        min_slope, max_slope = max_slope, min_slope
    end
    local top = chunk_pos.y * 32
    local bottom = top + 32 - 1
    if top - 70 > max_slope then
        return area_intersection.none
    elseif bottom + 70 < min_slope then
        return area_intersection.full
    else
        return area_intersection.partial
    end
end

---@enum chunk_type
chunk_type = {
    river = 1,
    ordinary = 2,
    biter_area_border = 3,
    biter_area = 4,
}

---@param chunk_pos {x: int, y: int} north chunk position (not tile position)
---@return chunk_type
function chunk_type_at(chunk_pos)
    if chunk_pos.y == -1 or (chunk_pos.y == -2 and (chunk_pos.x == -1 or chunk_pos.x == 0)) then
        return chunk_type.river
    end

    local biterland_intersection = chunk_biter_area_intersection(chunk_pos)
    if biterland_intersection == area_intersection.none then
        return chunk_type.ordinary
    elseif biterland_intersection == area_intersection.partial then
        return chunk_type.biter_area_border
    else
        return chunk_type.biter_area
    end
end

local function draw_noise_ore_patch(x, y, name, surface, radius, richness)
    local ore_template = { name = 'iron-ore', position = { 0, 0 }, amount = 1 }
    local remove_structures_template = { position = { 0, 0 }, name = { 'wooden-chest', 'stone-wall', 'gun-turret' } }

    local seed = surface.map_gen_settings.seed
    local can_place_entity = surface.can_place_entity
    local create_entity = surface.create_entity
    local find_entities_filtered = surface.find_entities_filtered

    local richness_part = richness / radius
    for dy = radius * -3, radius * 3, 1 do
        for dx = radius * -3, radius * 3, 1 do
            local distance_to_center = math_sqrt(dx ^ 2 + dy ^ 2)
            local amount = richness - richness_part * distance_to_center
            if amount > 1 then
                local ore_x, ore_y = x + dx, y + dy

                -- old equation
                -- distance_to_center < radius - math_abs(noise * radius * 0.85)
                local bound = (radius - distance_to_center) / (radius * 0.85)
                local noise = get_noise_between_bounds(
                    spawn_ore_noise,
                    spawn_ore_noise_amp_sum,
                    ore_x,
                    ore_y,
                    seed,
                    25000,
                    -bound,
                    bound
                )

                if noise then
                    local pos = { ore_x, ore_y }
                    local pos_inv = { ore_x, -ore_y }
                    ore_template.position = pos
                    ore_template.name = name
                    ore_template.amount = amount
                    if can_place_entity(ore_template) then
                        create_entity(ore_template)
                        ore_template.position = pos_inv
                        create_entity(ore_template)
                        remove_structures_template.position = pos
                        for _, e in pairs(find_entities_filtered(remove_structures_template)) do
                            e.destroy()
                        end
                    end
                end
            end
        end
    end
end

-- distance to the center of the map from the center of the tile
local function tile_distance_to_center(x, y)
    return math_sqrt((x + 0.5) ^ 2 + (y + 0.5) ^ 2)
end

local function is_within_spawn_island(x, y)
    if math_abs(x) > spawn_island_size then
        return false
    end
    if math_abs(y) > spawn_island_size then
        return false
    end
    if tile_distance_to_center(x, y) > spawn_island_size then
        return false
    end
    return true
end

local function is_horizontal_border_river(x, y, seed)
    if tile_distance_to_center(x, y) < river_circle_size then
        return true
    end

    y = -y
    return (y <= river_width_half)
end

--- Calculates tile y coordinate which has top border closest to the intersection point of the middle
---  of a vertical column and the top (negative) part of a circle at the origin, ties prefer tile below (towards positive)
---@param column_x number tile column x coordinate
---@param circle_radius number
---@return number? tile_y # intersection point, if any
local function tile_near_column_with_origin_circle_intersection(column_x, circle_radius)
    local tile_center = 0.5
    local circle_y_intersection_sq = circle_radius ^ 2 - (column_x + tile_center) ^ 2
    if circle_y_intersection_sq < 0 then
        return nil
    end
    local circle_y_intersection = -math_sqrt(circle_y_intersection_sq)
    -- round, tie breaker ceil
    circle_y_intersection = math_floor(circle_y_intersection + 0.5)
    return circle_y_intersection
end

---@param chunk_pos {x: number, y: number}
---@return boolean
local function in_spawn_river_circle_bbox(chunk_pos)
    return chunk_pos.y >= -2 and chunk_pos.x >= -2 and chunk_pos.x < 2
end

---@param seed any
---@param x number
---@param include_spawn_circle boolean
---@return number y
local function river_start(seed, x, include_spawn_circle)
    return -river_width_half
        end

---@param chunk_pos {x: number, y: number}
local function is_outside_spawn(chunk_pos)
    return chunk_pos.x < -5 or chunk_pos.x >= 5 or chunk_pos.y < -5
end

local DEFAULT_HIDDEN_TILE = 'dirt-3'

local spawn_wall_radius = 116
local spawn_wall_noise_multiplier = 15
local spawn_wall_noise_deviation = spawn_wall_noise_multiplier * spawn_wall_noise_amp_sum

local concrete_circle_radius = spawn_wall_radius - (10 + spawn_wall_noise_deviation)
local spawn_wall_noise_radius = spawn_wall_radius + (4.5 + spawn_wall_noise_deviation)

---@param surface LuaSurface
---@param chunk_pos {x: number, y: number}
---@param rng LuaRandomGenerator
local function generate_starting_area(surface, chunk_pos, rng)
    local wooden_chest_template = { name = 'wooden-chest', position = { 0, 0 }, force = 'north' }
    local coal_template = { name = 'coal', position = { 0, 0 } }
    local fire_magazine_template = { name = 'firearm-magazine', count = 0 }

    local seed = surface.map_gen_settings.seed
    local left_top_x = chunk_pos.x * 32
    local left_top_y = chunk_pos.y * 32
    local is_river_chunk = chunk_type_at(chunk_pos) == chunk_type.river
    local in_spawn_river_circle_bb = in_spawn_river_circle_bbox(chunk_pos)
    local can_place_entity = surface.can_place_entity
    local create_entity = surface.create_entity
    local get_tile = surface.get_tile
    local concrete_foundation = {}
    local concrete = {}

    -- distance_from_spawn_wall is the difference between the distance_to_center (with added noise)
    -- and our spawn_wall radius (spawn_wall_radius=116), i.e. how far are we from the ring with radius spawn_wall_radius.
    -- The following shows what happens depending on distance_from_spawn_wall:
    --      min     max
    --      N/A     -10     => replace water
    -- if noise_2 > -0.4:
    --      -1.75    0      => wall
    -- else:
    --      -6      -3      => 1/16 chance of turret or turret-remnants
    --      -1.95    0      => wall
    --       0       4.5    => chest-remnants with 1/3, chest with 1/(distance_from_spawn_wall+2)
    --
    -- => We never do anything for (distance_to_center + min_noise - spawn_wall_radius) > 4.5
    for x = left_top_x, left_top_x + 32 - 1 do
        local noise_start = tile_near_column_with_origin_circle_intersection(x, spawn_wall_noise_radius)
        noise_start = noise_start and math_max(noise_start, left_top_y) or (left_top_y + 32)
        noise_end = left_top_y + 32 - 1

        local concrete_start = tile_near_column_with_origin_circle_intersection(x, concrete_circle_radius)
        if concrete_start then
            noise_end = math_min(noise_end, concrete_start - 1)
        else
            concrete_start = left_top_y + 32
        end

        local concrete_end = left_top_y + 32 - 1
        if is_river_chunk then
            local river_start = river_start(seed, x, in_spawn_river_circle_bb)
            concrete_end = math_min(concrete_end, river_start - 1)
            noise_end = math_min(noise_end, river_start - 1)
        end

        for y = concrete_start, concrete_end do
            if get_tile(x, y).collides_with('resource') then
                concrete_foundation[#concrete_foundation + 1] = { name = DEFAULT_HIDDEN_TILE, position = { x, y } }
                concrete_foundation[#concrete_foundation + 1] = { name = DEFAULT_HIDDEN_TILE, position = { x, -y } }
            end
            concrete[#concrete + 1] = { name = 'refined-concrete', position = { x, y } }
            concrete[#concrete + 1] = { name = 'refined-concrete', position = { x, -y } }
        end

        for y = noise_start, noise_end do
            local distance_to_center = tile_distance_to_center(x, y)
            local noise = get_noise(spawn_wall_noise, x, y, seed, 25000) * spawn_wall_noise_multiplier
            local distance_from_spawn_wall = distance_to_center + noise - spawn_wall_radius

            local pos = { x, y }
            local pos_inv = { x, -y }
            if distance_from_spawn_wall < -10 then
                if get_tile(x, y).collides_with('resource') then
                    concrete_foundation[#concrete_foundation + 1] = { name = DEFAULT_HIDDEN_TILE, position = pos }
                end
                concrete[#concrete + 1] = { name = 'refined-concrete', position = pos }
                concrete[#concrete + 1] = { name = 'refined-concrete', position = pos_inv }
                goto continue
            end

            wooden_chest_template.name = 'wooden-chest'
            wooden_chest_template.position = pos
            coal_template.position = pos
            if
                not can_place_entity(wooden_chest_template)
                or not can_place_entity(coal_template)
            then
                goto continue
            end

            local noise_2 = get_upper_bounded_noise(spawn_wall_2_noise, spawn_wall_2_noise_amp_sum, x, y, seed, 0, 0.4)
            if not noise_2 then
                goto continue
            end

            if noise_2 > -0.40 then
                if distance_from_spawn_wall > -1.75 and distance_from_spawn_wall < 0 then
                    create_entity({ name = 'stone-wall', position = pos, force = 'north' })
                    create_entity({ name = 'stone-wall', position = pos_inv, force = 'south' })
                end
                goto continue
            end

            if distance_from_spawn_wall > -1.95 and distance_from_spawn_wall < 0 then
                create_entity({ name = 'stone-wall', position = pos, force = 'north' })
                create_entity({ name = 'stone-wall', position = pos_inv, force = 'south' })
            elseif distance_from_spawn_wall > 0 and distance_from_spawn_wall < 4.5 then
                local r_max = math_floor(math_abs(distance_from_spawn_wall)) + 2
                local name = rng(1, 3) == 1 and 'wooden-chest-remnants' or 'wooden-chest'
                if rng(1, r_max) == 1 then
                    create_entity({ name = name, position = pos, force = 'north' })
                    create_entity({ name = name, position = pos_inv, force = 'south' })
                end
            elseif distance_from_spawn_wall > -6 and distance_from_spawn_wall < -3 then
                if rng(1, 16) == 1 then
                    local entity = { name = 'gun-turret', position = pos, force = 'north' }
                    if can_place_entity(entity) then
                        local turret = surface.create_entity(entity)
                        fire_magazine_template.count = rng(2, 16)
                        turret.insert(fire_magazine_template)
                        ai_targets_start_tracking(turret)

                        entity.force = 'south'
                        entity.position[2] = pos_inv[2]+1
                        local turret = surface.create_entity(entity)
                        turret.insert(fire_magazine_template)
                    end
                else
                    if rng(1, 24) == 1 then
                        local entity = { name = 'gun-turret-remnants', position = pos, force = 'north' }
                        if can_place_entity(entity) then
                            surface.create_entity(entity)
                            entity.position[2] = pos_inv[2]+1
                            surface.create_entity(entity)
                        end
                    end
                end
            end

            ::continue::
        end
    end

    surface.set_tiles(concrete_foundation, false)
    surface.set_tiles(concrete, true)
end

local scrap_vectors = {}
for x = -8, 8, 1 do
    for y = -8, 8, 1 do
        if math_sqrt(x ^ 2 + y ^ 2) <= 8 then
            scrap_vectors[#scrap_vectors + 1] = { x, y }
        end
    end
end
local size_of_scrap_vectors = #scrap_vectors

---@param x number
---@param y number
---@param seed number
---@param a number biter area slope start
---@return boolean
local function biter_area_noise_test(x, y, seed, a)
    -- original test
    -- return y + (get_noise(biter_area_border_noise, x, y, seed, 0) * 64) <= a
    local noise =
        get_lower_bounded_noise(biter_area_border_noise, biter_area_border_noise_amp_sum, x, y, seed, 0, (a - y) / 64)
    return noise == nil
end

---@param seed uint
---@param x number
---@param y number
---@return boolean
local function is_biter_area(seed, x, y)
    local bitera_area_distance = bb_config_bitera_area_distance * -1
    local a = bitera_area_distance - (math_abs(x) * bb_config_biter_area_slope)
    if y - 70 > a then
        return false
    end
    if y + 70 < a then
        return true
    end
    return biter_area_noise_test(x, y, seed, a)
end

-- this will enable collection of chunk generation profiling statistics, chart huge area around the map origin
-- and enable `chunk-profiling-stats` command to retrieve the statistics
local ENABLE_CHUNK_GEN_PROFILING = false

local chunk_profiling = nil
if ENABLE_CHUNK_GEN_PROFILING then
    local profile_stats = require('utils.profiler_stats')
    local event = require('utils.event')
    local token = require('utils.token')

    chunk_profiling = {
        per_chunk_type = {},
        all = profile_stats.new(),
    }

    for _, i in pairs(chunk_type) do
        chunk_profiling.per_chunk_type[i] = profile_stats.new()
    end

    local function chart_profiling_area(surface)
        game.forces['spectator'].chart(surface, { { x = -1024, y = -1024 }, { x = 1023, y = 1023 } })
    end

    local on_after_init -- pass self reference to the callback below
    on_after_init = token.register(function()
        local bb_surface = game.get_surface(storage.bb_surface_name)
        chart_profiling_area(bb_surface)
        event.remove_removable(defines.events.on_tick, on_after_init)
    end)
    event.add_removable(defines.events.on_tick, on_after_init)

    -- this won't be called if you create a surface during `on_init`
    event.add(defines.events.on_surface_created, function(event)
        local bb_surface = game.get_surface(storage.bb_surface_name)
        if not bb_surface or event.surface_index ~= bb_surface.index then
            return
        end
        chart_profiling_area(bb_surface)
    end)

    -- server and client output won't match
    commands.add_command('chunk-profiling-stats', 'Display and log statistics of chunk generation time', function(cmd)
        local caller = cmd.player_index and game.get_player(cmd.player_index)

        if caller and not caller.admin then
            caller.print('Only admin may run this command')
            return
        end

        local stats = 'Chunk profiling statistics\nall: ' .. chunk_profiling.all.summarize_records()
        for chunk_name, i in pairs(chunk_type) do
            stats = stats .. '\n' .. chunk_name .. ': ' .. chunk_profiling.per_chunk_type[i].summarize_records()
        end
        log(stats)
        if caller then
            caller.print(stats)
        end
    end)
end

---@param chunk_pos {x: number, y: number}
---@param seed uint
---@return LuaRandomGenerator
local function create_rng_for_chunk(chunk_pos, seed)
    -- seeding from mixed ores special map generation
    return game.create_random_generator((chunk_pos.x * 374761393 + chunk_pos.y * 668265263 + seed) % 4294967296)
end

local function draw_spawn_island(surface)
    local tiles = {}
    for x = -math_floor(spawn_island_size), -1, 1 do
        for y = -math_floor(spawn_island_size), -1, 1 do
            if is_within_spawn_island(x, y) then
                local distance_to_center = tile_distance_to_center(x, y)
                local tile_name = 'refined-concrete'
                if distance_to_center < 6.3 then
                    tile_name = 'sand-1'
                end

                if storage.bb_settings['new_year_island'] then
                    tile_name = 'blue-refined-concrete'
                    if distance_to_center < 6.3 then
                        tile_name = 'sand-1'
                    end
                    if distance_to_center < 4.9 then
                        tile_name = 'lab-white'
                    end
                end

                table_insert(tiles, { name = tile_name, position = { x = x, y = y } })
                table_insert(tiles, { name = tile_name, position = { x = x, y = -y - 1} })
            end
        end
    end

    for i = 1, #tiles, 1 do
        table_insert(tiles, { name = tiles[i].name, position = { tiles[i].position.x * -1 - 1, tiles[i].position.y } })
    end

    surface.set_tiles(tiles, true)

    local island_area = { { -spawn_island_size, -spawn_island_size }, { spawn_island_size, spawn_island_size } }
    surface.destroy_decoratives({ area = island_area })
    for _, entity in pairs(surface.find_entities_filtered({area = island_area, name = 'character', invert = true})) do
        entity.destroy()
    end
end

local chunk_r = 4

--- Create initial chunks to be populated with spawn objects
---@param surface LuaSurface
---@param mirror boolean force south spawn chunks generation
local function force_spawn_chunks_generation(surface, mirror)
    local start_row = mirror and 0 or -chunk_r
    local end_row = start_row + chunk_r - 1
    local request_to_generate_chunks = surface.request_to_generate_chunks
    for x = -chunk_r, chunk_r - 1 do
        for y = start_row, end_row do
            request_to_generate_chunks({ x * 32, y * 32 }, 0)
        end
    end
    surface.force_generate_chunk_requests()
end

--- Generate some biter nests so attack groups could be spawned
---@param surface LuaSurface
local function request_biters_area_generation(surface)
    -- skip biter area border at x=0 chunk and include solid biter area chunk which guaranteed to contain some nests
    local solid_biter_area_start = bb_config_bitera_area_distance + 70 + (32 - 1) * bb_config_biter_area_slope
    local start_row = -1 - math_ceil(solid_biter_area_start / 32)
    local end_row = -chunk_r - 1
    local request_to_generate_chunks = surface.request_to_generate_chunks
    for x = -chunk_r, chunk_r - 1 do
        for y = start_row, end_row do
            request_to_generate_chunks({ x * 32, y * 32 }, 0)
        end
    end
end

local function draw_spawn_area(surface, rng)
    local spawn_wall_area_radius = spawn_wall_radius + spawn_wall_noise_deviation
    local trees = surface.find_entities_filtered({
        type = 'tree',
        position = { 0, 0 },
        radius = spawn_wall_area_radius,
    })
    for _, tree in pairs(trees) do
        -- old code checked for each tile with 2x2 box with chance of skipping 23%
        -- 4 times same tree 23% gives chance < 1%
        -- if rng(1, 100) > 1 then
        tree.destroy()
        -- end
    end
    for x = -chunk_r, chunk_r - 1 do
        for y = -chunk_r, -1 do
            generate_starting_area(surface, { x = x, y = y }, rng)
        end
    end
end

local function draw_grid_ore_patch(count, grid, name, surface, size, density, rng)
    -- Takes a random left_top coordinate from grid, removes it and draws
    -- ore patch on top of it. Grid is held by reference, so this function
    -- is reentrant.
    for i = 1, count, 1 do
        local idx = rng(1, #grid)
        local pos = grid[idx]
        table_remove(grid, idx)

        draw_noise_ore_patch(pos[1], pos[2], name, surface, size, density)
    end
end

local function _clear_resources(surface, area)
    local resources = surface.find_entities_filtered({
        area = area,
        type = 'resource',
    })

    local i = 0
    for _, res in pairs(resources) do
        res.destroy()
        i = i + 1
    end

    return i
end

local function clear_ore_in_main(surface)
    local area = {
        left_top = { -150, -150 },
        right_bottom = { 150, 150 },
    }
    local limit = 20
    local cnt = 0
    repeat
        -- Keep clearing resources until there is none.
        -- Each cycle increases search area.
        cnt = _clear_resources(surface, area)
        limit = limit - 1
        area.left_top[1] = area.left_top[1] - 5
        area.left_top[2] = area.left_top[2] - 5
        area.right_bottom[1] = area.right_bottom[1] + 5
    until cnt == 0 or limit == 0

    if limit == 0 then
        log('Limit reached, some ores might be truncated in spawn area')
        log('If this is a custom build, remove a call to clear_ore_in_main')
        log('If this in a standard value, limit could be tweaked')
    end
end

local function generate_spawn_ore(surface, rng)
    -- This array holds indices of chunks onto which we desire to
    -- generate ore patches. It is visually representing north spawn
    -- area. One element was removed on purpose - we don't want to
    -- draw ore in the lake which overlaps with chunk [0,-1]. All ores
    -- will be mirrored to south.
    local grid = {
        { -2, -3 },
        { -1, -3 },
        { 0, -3 },
        { 1, -3 },
        { 2, -3 },
        { -2, -2 },
        { -1, -2 },
        { 0, -2 },
        { 1, -2 },
        { 2, -2 },
        { -2, -1 },
        { -1, -1 },
        { 1, -1 },
        { 2, -1 },
    }

    -- Calculate left_top position of a chunk. It will be used as origin
    -- for ore drawing. Reassigns new coordinates to the grid.
    for i, _ in ipairs(grid) do
        grid[i][1] = grid[i][1] * 32 + rng(-12, 12)
        grid[i][2] = grid[i][2] * 32 + rng(-24, -1)
    end

    for name, props in pairs(spawn_ore) do
        draw_grid_ore_patch(props.big_patches, grid, name, surface, props.size, props.density, rng)
        draw_grid_ore_patch(props.small_patches, grid, name, surface, props.size / 2, props.density, rng)
    end
end

local function generate_additional_rocks(surface, rng)
    local r = 130
    if surface.count_entities_filtered({ type = 'simple-entity', area = { { r * -1, r * -1 }, { r, 0 } } }) >= 12 then
        return
    end
    local position = { x = -96 + rng(0, 192), y = -40 - rng(0, 96) }
    for _ = 1, rng(6, 10) do
        local name = rocks[rng(1, 5)]
        local p = surface.find_non_colliding_position(name, {
            position.x + (-10 + rng(0, 20)),
            position.y + (-10 + rng(0, 20)),
        }, 16, 1)
        if p and p.y < -16 then
            surface.create_entity({ name = name, position = p })
        end
    end
end

local function generate_silo(surface, rng)
    local pos = { x = -32 + rng(0, 64), y = -72 }
    local mirror_position = { x = pos.x, y = -pos.y }

    for _, t in
        pairs(surface.find_tiles_filtered({
            area = { { pos.x - 6, pos.y - 6 }, { pos.x + 6, pos.y + 6 } },
            name = { 'water', 'deepwater' },
        }))
    do
        surface.set_tiles({ { name = DEFAULT_HIDDEN_TILE, position = t.position } })
    end
    for _, t in
        pairs(surface.find_tiles_filtered({
            area = {
                { mirror_position.x - 6, mirror_position.y - 6 },
                {
                    mirror_position.x + 6,
                    mirror_position.y + 6,
                },
            },
            name = { 'water', 'deepwater' },
        }))
    do
        surface.set_tiles({ { name = DEFAULT_HIDDEN_TILE, position = t.position } })
    end

    local silo = surface.create_entity({
        name = 'rocket-silo',
        position = pos,
        force = 'north',
    })
    silo.minable_flag = false
    storage.rocket_silo[silo.force.name] = silo
    AiTargets.start_tracking(silo)
    local silo = surface.create_entity({
        name = 'rocket-silo',
        position = mirror_position,
        force = 'south',
    })
    silo.minable_flag = false
    storage.rocket_silo[silo.force.name] = silo
    AiTargets.start_tracking(silo)


    for _, entity in pairs(surface.find_entities({ { pos.x - 4, pos.y - 6 }, { pos.x + 5, pos.y + 5 } })) do
        if entity.type == 'simple-entity' or entity.type == 'tree' then
            entity.destroy()
        end
    end
    local turret1 =
        surface.create_entity({ name = 'gun-turret', position = { x = pos.x, y = pos.y - 5 }, force = 'north' })
    turret1.insert({ name = 'firearm-magazine', count = 10 })
    AiTargets.start_tracking(turret1)
    local turret2 =
        surface.create_entity({ name = 'gun-turret', position = { x = pos.x + 2, y = pos.y - 5 }, force = 'north' })
    turret2.insert({ name = 'firearm-magazine', count = 10 })
    AiTargets.start_tracking(turret2)

    local turret1 =
        surface.create_entity({ name = 'gun-turret', position = { x = mirror_position.x, y = mirror_position.y + 6 }, force = 'south' })
    turret1.insert({ name = 'firearm-magazine', count = 10 })
    AiTargets.start_tracking(turret1)
    local turret2 =
        surface.create_entity({ name = 'gun-turret', position = { x = mirror_position.x + 2, y = mirror_position.y + 6 }, force = 'south' })
    turret2.insert({ name = 'firearm-magazine', count = 10 })
    AiTargets.start_tracking(turret2)
end

function Public.generate_initial_structures(surface)
    force_spawn_chunks_generation(surface, false)
    force_spawn_chunks_generation(surface, true)
    local rng = create_rng_for_chunk({ x = 1, y = 1 }, surface.map_gen_settings.seed)
    draw_spawn_area(surface, rng)
        clear_ore_in_main(surface)
        generate_spawn_ore(surface, rng)
    generate_additional_rocks(surface, rng)
    generate_silo(surface, rng)
    draw_spawn_island(surface)
    request_biters_area_generation(surface)
end

---@param entity LuaEntity
---@param player LuaPlayer
function Public.minable_wrecks(entity, player)
    if not valid_wrecks[entity.name] then
        return
    end

    local surface = entity.surface

    local loot_worth = math_floor(math_abs(entity.position.x * 0.02)) + math_random(16, 32)
    local blacklist = LootRaffle.get_tech_blacklist(math_abs(entity.position.x * 0.0001) + 0.10)
    for k, _ in pairs(loot_blacklist) do
        blacklist[k] = true
    end
    local item_stacks = LootRaffle.roll(loot_worth, math_random(1, 3), blacklist)

    for k, stack in pairs(item_stacks) do
        local amount = stack.count
        local name = stack.name

        local inserted_count = player.insert({ name = name, count = amount })
        if inserted_count ~= amount then
            local amount_to_spill = amount - inserted_count
            surface.spill_item_stack({
                position = entity.position,
                stack = { name = name, count = amount_to_spill },
                enable_looted = true,
            })
        end

        player.create_local_flying_text({
            position = { entity.position.x, entity.position.y - 0.5 * k },
            text = '+' .. amount .. ' [img=item/' .. name .. ']',
            color = { r = 0.98, g = 0.66, b = 0.22 },
        })
    end
end

--Landfill Restriction
function Public.restrict_landfill(surface, user, tiles, item)
    local seed = game.surfaces[storage.bb_surface_name].map_gen_settings.seed
    for _, t in pairs(tiles) do
        local check_position = t.position
        if check_position.y > 0 then
            check_position = { x = check_position.x, y = (check_position.y * -1) - 1 }
        end
        local trusted = session.get_trusted_table()
        if is_horizontal_border_river(check_position.x, check_position.y, seed) then
            surface.set_tiles({ { name = t.old_tile.name, position = t.position } }, true)
            if user ~= nil then
                user.insert({ name = item.name, count = 1 })
                user.print('You can not landfill the river', { color = { r = 0.22, g = 0.99, b = 0.99 } })
            end
        elseif user ~= nil and not trusted[user.name] and (t.old_tile.name == 'deepwater' or t.old_tile.name == 'water') then
            surface.set_tiles({ { name = t.old_tile.name, position = t.position } }, true)
            user.insert({ name = item.name, count = 1 })
            user.print(
                'You have not grown accustomed to this technology yet.',
                { color = { r = 0.22, g = 0.99, b = 0.99 } }
            )
        end
    end
end

function Public.deny_bot_landfill(event)
    if event.item ~= nil and (event.item.name == 'landfill' or event.item.name == 'foundation') then
        Public.restrict_landfill(event.robot.surface, nil, event.tiles, event.item)
    end
end

--Construction Robot Restriction
local robot_build_restriction = {
    ['north'] = function(y)
        if y >= -bb_config.border_river_width / 2 then
            return true
        end
    end,
    ['south'] = function(y)
        if y <= bb_config.border_river_width / 2 then
            return true
        end
    end,
}

function Public.deny_construction_bots(event)
    if not event.entity.valid then
        return
    end
    if not robot_build_restriction[event.robot.force.name] then
        return
    end
    if not robot_build_restriction[event.robot.force.name](event.entity.position.y) then
        return
    end
    local inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
    inventory.insert({ name = event.entity.name, count = 1 })
    event.robot.surface.create_entity({ name = 'explosion', position = event.entity.position })
    game.print(
        'Team ' .. event.robot.force.name .. "'s construction drone had an accident.",
        { color = { r = 200, g = 50, b = 100 } }
    )
    event.entity.destroy()
end

function Public.deny_enemy_side_ghosts(event)
    local e = event.entity
    if not e.valid then
        return
    end
    if e.surface.name ~= storage.bb_surface_name then
        return
    end
    if e.type == 'entity-ghost' or e.type == 'tile-ghost' then
        local player = game.get_player(event.player_index)
        local force = player.force.name
        if not robot_build_restriction[force] then
            return
        end
        if not robot_build_restriction[force](event.entity.position.y) then
            return
        end

        -- If cursor is not cleared before removing ghost of dragged pipe it
        -- will cause segfault from infinite recursion.
        player.clear_cursor()
        local ghosts = player.surface.find_entities_filtered({
            position = e.position,
            -- Undeground pipe creates two ghost tiles, but only one entity
            -- gets corresponding event
            radius = 2,
            name = 'tile-ghost',
        })
        e.order_deconstruction(force)
        for _, g in ipairs(ghosts) do
            if g.valid then
                g.order_deconstruction(force)
            end
        end
    end
end

local function add_gifts(surface)
    -- exclude dangerous goods
    local blacklist = LootRaffle.get_tech_blacklist(0.95)
    for k, _ in pairs(loot_blacklist) do
        blacklist[k] = true
    end

    for i = 1, math_random(8, 12) do
        local loot_worth = math_random(1, 35000)
        local item_stacks = LootRaffle.roll(loot_worth, 3, blacklist)
        for k, stack in pairs(item_stacks) do
            surface.spill_item_stack({
                position = { x = math_random(-10, 10) * 0.1, y = math_random(-5, 15) * 0.1 },
                stack = { name = stack.name, count = 1 },
                enable_looted = false,
                force = nil,
                allow_belts = true,
            })
        end
    end
end

function Public.add_new_year_island_decorations(surface)
    -- To fix lab-white tiles transition, draw border snow with sprites
    local function draw_sprite_snow(params)
        rendering.draw_sprite({
            surface = surface,
            sprite = params.sprite,
            target = params.target,
            render_layer = '3',
            x_scale = params.x_scale,
            y_scale = params.y_scale,
            orientation = params.orientation or 0,
        })
    end

    -- top and bottom
    draw_sprite_snow({ sprite = 'virtual-signal/shape-horizontal', target = { 0, 5.22 }, x_scale = 4.6, y_scale = 5 })
    draw_sprite_snow({ sprite = 'virtual-signal/shape-horizontal', target = { 0, -5.22 }, x_scale = 4.6, y_scale = 5 })

    -- sides
    draw_sprite_snow({ sprite = 'virtual-signal/shape-vertical', target = { -5.25, 0 }, x_scale = 5, y_scale = 4.5 })
    draw_sprite_snow({ sprite = 'virtual-signal/shape-vertical', target = { 5.25, 0 }, x_scale = 5, y_scale = 4.5 })

    local sprite = 'virtual-signal/shape-diagonal'
    local scale = 5.75
    -- bottom-right
    draw_sprite_snow({ sprite = sprite, target = { 3.48, 3.48 }, x_scale = scale, y_scale = scale })
    draw_sprite_snow({ sprite = sprite, target = { 3, 3 }, x_scale = scale, y_scale = scale })

    -- bottom-left
    draw_sprite_snow({ sprite = sprite, target = { -3.48, 3.48 }, x_scale = scale, y_scale = scale, orientation = 0.25 })
    draw_sprite_snow({ sprite = sprite, target = { -3, 3 }, x_scale = scale, y_scale = scale, orientation = 0.25 })

    -- top-right
    draw_sprite_snow({ sprite = sprite, target = { 3.48, -3.48 }, x_scale = scale, y_scale = scale, orientation = 0.25 })
    draw_sprite_snow({ sprite = sprite, target = { 3, -3 }, x_scale = scale, y_scale = scale, orientation = 0.25 })

    -- top-left
    draw_sprite_snow({ sprite = sprite, target = { -3.48, -3.48 }, x_scale = scale, y_scale = scale })
    draw_sprite_snow({ sprite = sprite, target = { -3, -3 }, x_scale = scale, y_scale = scale })

    for _ = 1, math_random(0, 4) do
        local stump = surface.create_entity({
            name = 'tree-05-stump',
            position = { x = math_random(-40, 40) * 0.1, y = math_random(-40, 40) * 0.1 },
        })
        stump.corpse_expires = false
    end

    local scorchmark = surface.create_entity({
        name = 'medium-scorchmark-tintable',
        position = { x = 0, y = 0 },
    })
    scorchmark.corpse_expires = false

    local tree = surface.create_entity({
        name = 'tree-01',
        position = { x = 0, y = 0.05 },
    })
    tree.minable_flag = false
    tree.destructible = false

    add_gifts(surface)

    local signals = {
        { name = 'rail-signal', position = { -0.5, -5.5 }, direction = defines.direction.west },
        { name = 'rail-signal', position = { 0.5, -5.5 }, direction = defines.direction.west },
        { name = 'rail-signal', position = { 2.5, -4.5 }, direction = defines.direction.northwest },
        { name = 'rail-signal', position = { 4.5, -2.5 }, direction = defines.direction.northwest },
        { name = 'rail-signal', position = { 5.5, -0.5 }, direction = defines.direction.north },
        { name = 'rail-signal', position = { 5.5, 0.5 }, direction = defines.direction.north },
        { name = 'rail-signal', position = { 4.5, 2.5 }, direction = defines.direction.northeast },
        { name = 'rail-signal', position = { 2.5, 4.5 }, direction = defines.direction.northeast },
        { name = 'rail-signal', position = { 0.5, 5.5 }, direction = defines.direction.east },
        { name = 'rail-signal', position = { -0.5, 5.5 }, direction = defines.direction.east },
        { name = 'rail-signal', position = { -2.5, 4.5 }, direction = defines.direction.southeast },
        { name = 'rail-signal', position = { -4.5, 2.5 }, direction = defines.direction.southeast },
        { name = 'rail-signal', position = { -5.5, 0.5 }, direction = defines.direction.south },
        { name = 'rail-signal', position = { -5.5, -0.5 }, direction = defines.direction.south },
        { name = 'rail-signal', position = { -4.5, -2.5 }, direction = defines.direction.southwest },
        { name = 'rail-signal', position = { -2.5, -4.5 }, direction = defines.direction.southwest },
    }
    for _, v in pairs(signals) do
        local signal = surface.create_entity(v)
        signal.minable_flag = false
        signal.destructible = false
    end

    for _ = 1, math_random(0, 6) do
        surface.create_decoratives({
            check_collision = false,
            decoratives = {
                {
                    name = 'green-asterisk-mini',
                    position = {
                        x = math_random(-40, 40) * 0.1,
                        y = math_random(-40, 40) * 0.1,
                    },
                    amount = 1,
                },
            },
        })
    end
    for _ = 1, math_random(0, 6) do
        surface.create_decoratives({
            check_collision = false,
            decoratives = {
                {
                    name = 'tiny-rock',
                    position = {
                        x = math_random(-40, 40) * 0.1,
                        y = math_random(-40, 40) * 0.1,
                    },
                    amount = 1,
                },
            },
        })
    end
end

return Public
