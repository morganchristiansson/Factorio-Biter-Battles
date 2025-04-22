local Public = {}
local BiterRaffle = require('maps.biter_battles_v2.biter_raffle')
local bb_config = require('maps.biter_battles_v2.config')
local Event = require('utils.event')
local Feeding = require('maps.biter_battles_v2.feeding')
local Functions = require('maps.biter_battles_v2.functions')
local Tables = require('maps.biter_battles_v2.tables')
local AiStrikes = require('maps.biter_battles_v2.ai_strikes')
local AiTargets = require('maps.biter_battles_v2.ai_targets')
local math_random = math.random
local math_abs = math.abs
local math_floor = math.floor
local table_insert = table.insert

local unit_type_raffle = { 'biter', 'mixed', 'mixed', 'spitter', 'gleba' }
local size_of_unit_type_raffle = #unit_type_raffle

local threat_values = {
    ['small-spitter'] = 1.5,
    ['small-biter'] = 1.5,
    ['medium-spitter'] = 4.5,
    ['medium-biter'] = 4.5,
    ['small-wriggler-pentapod'] = 5,
    ['medium-wriggler-pentapod'] = 9,
    ['big-spitter'] = 13,
    ['big-biter'] = 13,
    ['big-wriggler-pentapod'] = 13,
    ['behemoth-spitter'] = 38.5,
    ['behemoth-biter'] = 38.5,
    ['behemoth-wriggler-pentapod'] = 40,
    ['titan-spitter'] = 300,
    ['titan-biter'] = 300,
    ['titan-wriggler-pentapod'] = 320,
    ['gargantuan-spitter'] = 2500,
    ['gargantuan-biter'] = 2500,
    ['small-worm-turret'] = 8,
    ['medium-worm-turret'] = 16,
    ['big-worm-turret'] = 24,
    ['behemoth-worm-turret'] = 32,
    ['gargantuan-wriggler-pentapod'] = 2800,
    ['small-strafer-pentapod'] = 50,
    ['medium-strafer-pentapod'] = 80,
    ['big-strafer-pentapod'] = 110,
    ['behemoth-strafer-pentapod'] = 1000,
    ['titan-strafer-pentapod'] = 9000,
    ['small-stomper-pentapod'] = 90,
    ['medium-stomper-pentapod'] = 150,
    ['big-stomper-pentapod'] = 210,
    ['behemoth-stomper-pentapod'] = 1900,
    ['titan-stomper-pentapod'] = 17000,
}

local function get_threat_ratio(biter_force_name)
    if storage.bb_threat[biter_force_name] <= 0 then
        return 0
    end
    local t1 = storage.bb_threat['north_biters']
    local t2 = storage.bb_threat['south_biters']
    if t1 == 0 and t2 == 0 then
        return 0.5
    end
    if t1 < 0 then
        t1 = 0
    end
    if t2 < 0 then
        t2 = 0
    end
    local total_threat = t1 + t2
    local ratio = storage.bb_threat[biter_force_name] / total_threat
    return ratio
end

Public.send_near_biters_to_silo = function()
    if Functions.get_ticks_since_game_start() < 108000 then
        return
    end
    if not storage.rocket_silo['north'] then
        return
    end
    if not storage.rocket_silo['south'] then
        return
    end
    if storage.bb_game_won_by_team then
        return
    end

    game.surfaces[storage.bb_surface_name].set_multi_command({
        command = {
            type = defines.command.attack,
            target = storage.rocket_silo['north'],
            distraction = defines.distraction.none,
        },
        unit_count = 8,
        force = 'north_biters',
        unit_search_distance = 64,
    })

    game.surfaces[storage.bb_surface_name].set_multi_command({
        command = {
            type = defines.command.attack,
            target = storage.rocket_silo['south'],
            distraction = defines.distraction.none,
        },
        unit_count = 8,
        force = 'south_biters',
        unit_search_distance = 64,
    })
end

local function get_random_spawner(biter_force_name)
    local spawners = storage.unit_spawners[biter_force_name]
    local size_of_spawners = #spawners

    for _ = 1, 256, 1 do
        if size_of_spawners == 0 then
            return
        end
        local index = math_random(1, size_of_spawners)
        local spawner = spawners[index]
        if spawner and spawner.valid then
            return spawner
        else
            table.remove(spawners, index)
            size_of_spawners = size_of_spawners - 1
        end
    end
end

--Manual spawning of units
local function spawn_biters(
    biter_raffle_table,
    is_boss,
    max_unit_count,
    spawner,
    evolution_factor,
    biter_threat,
    biter_force_name,
    valid_biters,
    force_name
)
    local i = #valid_biters
    local difficulty_index = storage.difficulty_vote_index
    
    local biter_raffle_table_sum = 0
    for k, v in pairs(biter_raffle_table) do
        biter_raffle_table_sum = biter_raffle_table_sum + v
    end

    for _ = 1, max_unit_count, 1 do
        local unit_name = BiterRaffle.roll_table(biter_raffle_table, biter_raffle_table_sum)
        local position = spawner.surface.find_non_colliding_position(unit_name, spawner.position, 128, 2)
        if not position then
            break
        end
        local quality_roll = math_random(1, 10000)
        local biter_quality
        local push_higher_quality = storage.bb_quality[biter_force_name] * 100
        if is_boss then push_higher_quality = push_higher_quality * 10 + 700 end
        local quality_factor
        if quality_roll > (10000 - push_higher_quality) then
            biter_quality = 'epic'
            quality_factor = 1.9
        elseif quality_roll > (10000 - push_higher_quality * 10) then
            biter_quality = 'rare'
            quality_factor = 1.6
        elseif quality_roll > (10000 - push_higher_quality * 100) then
            biter_quality = 'uncommon'
            quality_factor = 1.3
        else
            biter_quality = 'normal'
            quality_factor = 1
        end

        local biter_threat_value = threat_values[unit_name] * quality_factor
        
        if biter_threat - biter_threat_value < 0 then
            break
        end

        biter_threat = biter_threat - biter_threat_value

        i = i + 1
        valid_biters[i] = spawner.surface.create_entity({ name = unit_name, force = biter_force_name, position = position, quality = biter_quality })

        --Announce New Spawn
        if not is_boss and storage.biter_spawn_unseen[force_name][unit_name] then
            game.print({
                '',
                'A ',
                unit_name:gsub('-', ' '),
                ' was spotted far away on ',
                Functions.team_name_with_color(force_name),
                '...',
            })
            storage.biter_spawn_unseen[force_name][unit_name] = false
        end
        if is_boss then
            local highquality_biter_force_name = force_name .. '_hq'
            if storage.biter_spawn_unseen[highquality_biter_force_name][unit_name] then
                game.print({
                    '',
                    'Due to high threat, a high quality ',
                    unit_name:gsub('-', ' '),
                    ' was spotted far away on ',
                    Functions.team_name_with_color(force_name),
                    '...',
                })
                storage.biter_spawn_unseen[highquality_biter_force_name][unit_name] = false
            end
        end
    end
    return biter_threat
end

local function roll_type_and_spawn_biters(spawner, force_name, biter_force_name, valid_biters, biter_threat)
    local roll_type = unit_type_raffle[math_random(1, size_of_unit_type_raffle)]
    local evolution_factor = storage.bb_evolution[biter_force_name]
    local biter_raffle_table = BiterRaffle.get_table(roll_type, evolution_factor)
    local boss_biter_raffle_table = BiterRaffle.get_boss_table(roll_type, evolution_factor)

    local max_unit_count = 300
    if evolution_factor > 0.5 then max_unit_count = 100 end
    if evolution_factor > 1.5 then max_unit_count = 50 end
    if roll_type == 'gleba' and evolution_factor > 0.7 then max_unit_count = 10 end
    local remaining_biter_threat = spawn_biters(
        biter_raffle_table,
        false,
        max_unit_count,
        spawner,
        evolution_factor,
        biter_threat,
        biter_force_name,
        valid_biters,
        force_name
    )

    if evolution_factor > 0.5 then
        max_unit_count = 50
        if roll_type == 'gleba' and evolution_factor > 0.7 then max_unit_count = 5 end
        remaining_biter_threat = spawn_biters(
            boss_biter_raffle_table,
            true,
            max_unit_count,
            spawner,
            evolution_factor,
            remaining_biter_threat,
            biter_force_name,
            valid_biters,
            force_name
        )
    end

    return remaining_biter_threat
end

local function select_units_around_spawner(spawner, force_name)
    local biter_force_name = spawner.force.name
    local valid_biters = {}
    local biter_threat = storage.bb_threat[biter_force_name] / 10

    roll_type_and_spawn_biters(spawner, force_name, biter_force_name, valid_biters, biter_threat)
    
    return valid_biters
end

local function get_unit_group_position(spawner)
    local p
    if spawner.force.name == 'north_biters' then
        p = { x = spawner.position.x, y = spawner.position.y + 4 }
    else
        p = { x = spawner.position.x, y = spawner.position.y - 4 }
    end
    p = spawner.surface.find_non_colliding_position('electric-furnace', p, 256, 1)
    if not p then
        if storage.bb_debug then
            game.print('No unit_group_position found for force ' .. spawner.force.name)
        end
        return
    end
    return p
end

local function get_nearby_biter_nest(center, biter_force_name)
    local spawner = get_random_spawner(biter_force_name)
    if not spawner then
        return
    end
    local best_distance = (center.x - spawner.position.x) ^ 2 + (center.y - spawner.position.y) ^ 2

    for _ = 1, 16, 1 do
        local new_spawner = get_random_spawner(biter_force_name)
        local new_distance = (center.x - new_spawner.position.x) ^ 2 + (center.y - new_spawner.position.y) ^ 2
        if new_distance < best_distance then
            spawner = new_spawner
            best_distance = new_distance
        end
    end

    if not spawner then
        return
    end
    --print("Nearby biter nest found at x=" .. spawner.position.x .. " y=" .. spawner.position.y .. ".")
    return spawner
end

local function create_attack_group(surface, force_name, biter_force_name)
    local threat = storage.bb_threat[biter_force_name]
    if threat <= 0 then
        return false
    end

    local target_position = AiTargets.get_random_target(force_name)
    if not target_position then
        print('No side target found for ' .. force_name .. '.')
        return
    end

    local spawner = get_nearby_biter_nest(target_position, biter_force_name)
    if not spawner then
        print('No spawner found for ' .. force_name .. '.')
        return
    end

    local unit_group_position = get_unit_group_position(spawner)
    if not unit_group_position then
        return
    end
    local units = select_units_around_spawner(spawner, force_name)
    if not units then
        return
    end
    local unit_group = surface.create_unit_group({ position = unit_group_position, force = biter_force_name })
    for _, unit in pairs(units) do
        unit.ai_settings.path_resolution_modifier = -1
        unit_group.add_member(unit)
    end
    local strike_position = AiStrikes.calculate_strike_position(unit_group, target_position)
    AiStrikes.initiate(unit_group, force_name, strike_position, target_position)
end

Public.pre_main_attack = function()
    local force_name = storage.next_attack

    -- In headless benchmarking, there are no connected_players so we need a global to override this
    if
        not storage.training_mode
        or (storage.training_mode and (storage.benchmark_mode or #game.forces[force_name].connected_players > 0))
    then
        local biter_force_name = force_name .. '_biters'
        storage.main_attack_wave_amount = math.ceil(get_threat_ratio(biter_force_name) * 7)

        if storage.bb_debug then
            game.print(storage.main_attack_wave_amount .. ' unit groups designated for ' .. force_name .. ' biters.')
        end
    else
        storage.main_attack_wave_amount = 0
    end
end

Public.perform_main_attack = function()
    if storage.main_attack_wave_amount > 0 then
        local surface = game.surfaces[storage.bb_surface_name]
        local force_name = storage.next_attack
        local biter_force_name = force_name .. '_biters'

        create_attack_group(surface, force_name, biter_force_name)
        storage.main_attack_wave_amount = storage.main_attack_wave_amount - 1
    end
end

Public.post_main_attack = function()
    storage.main_attack_wave_amount = 0
    if storage.next_attack == 'north' then
        storage.next_attack = 'south'
    else
        storage.next_attack = 'north'
    end
end

Public.raise_evo = function()
    if storage.freeze_players then
        return
    end
    local seconds_since_game_start = Functions.get_ticks_since_game_start() / 60
    if seconds_since_game_start < 120 then
        return
    end

    local biter_teams = { ['north_biters'] = 'north', ['south_biters'] = 'south' }
    for bf, pf in pairs(biter_teams) do
        if #game.forces[pf].connected_players > 0 then
            storage.passive_feed_redpotion[pf] = storage.passive_feed_redpotion[pf] + 0.3 --used to be 0.75 times 0.5 (=0.375), lowered to 0.3
            local amount = math.ceil(storage.passive_feed_redpotion[pf])
            storage.total_passive_feed_redpotion[pf] = storage.total_passive_feed_redpotion[pf] + amount
            Feeding.do_raw_feed(amount, 'automation-science-pack', bf)
        end
    end
end

Public.reset_evo = function()
    local biter_teams = { ['north_biters'] = 'north', ['south_biters'] = 'south' }
    for bf, _ in pairs(biter_teams) do
        Feeding.do_raw_feed(0, 'automation-science-pack', bf)
    end
    
    -- Shouldn't reset evo if any of the teams fed. Feeding is blocked when voting is in progress.
    -- However, if /difficulty-revote is done late in a game, we don't want to reset evo.
    if storage.science_logs_text then
        return
    end

    local amount = storage.total_passive_feed_redpotion
    if amount < 1 then
        return
    end
    storage.total_passive_feed_redpotion = 0

    for bf, _ in pairs(biter_teams) do
        storage.bb_evolution[bf] = 0
        Feeding.do_raw_feed(amount, 'automation-science-pack', bf)
    end
end

--Biter Threat Value Subtraction
function Public.subtract_threat(entity)
    if not threat_values[entity.name] then
        return
    end
    local biter_force = entity.force.name
    local factor = 1
    if biter_force ~= 'north_biters' and biter_force ~= 'south_biters' then
        return
    end

    if storage.active_special_games['threat_farm_threshold'] then
        local threat_value = threat_values[entity.name] * factor
        local special_variables = storage.special_games_variables['threat_farm_threshold']
        local threat_below_threshold = special_variables.threat_threshold
            - (storage.bb_threat[biter_force] - threat_value)
        local enemy_force
        if threat_below_threshold > 0 then
            storage.bb_threat[biter_force] = special_variables.threat_threshold
            if biter_force == 'south_biters' then
                enemy_force = 'north_biters'
            else
                enemy_force = 'south_biters'
            end
            storage.bb_threat[enemy_force] = storage.bb_threat[enemy_force]
                + threat_below_threshold * special_variables.excess_threat_send_fraction
        else
            storage.bb_threat[biter_force] = storage.bb_threat[biter_force] - threat_value
        end
        return true
    end

    local quality_factor = 1
    if entity.quality.name == 'uncommon' then quality_factor = 1.3 end
    if entity.quality.name == 'rare' then quality_factor = 1.6 end
    if entity.quality.name == 'epic' then quality_factor = 1.9 end
    if entity.quality.name == 'legendary' then quality_factor = 25 end

    storage.bb_threat[biter_force] = storage.bb_threat[biter_force]
        - threat_values[entity.name] * factor * quality_factor
    return true
end

Public.flood = function()
    if storage.bb_game_won_by_team then
        return
    end
    --send biters according to flood amount for both teams
    for _, force_name in pairs({'north', 'south'}) do
        local biter_force_name = force_name .. '_biters'
        local remaining_flood_amount = storage.bb_flood[biter_force_name] + storage.bb_flood_income[biter_force_name]
        --find silo for team
        local silo = storage.rocket_silo[force_name]
        if silo and silo.valid then
            local spawner = get_nearby_biter_nest(silo.position, biter_force_name)
            if spawner and spawner.valid then
                --spawn
                local biters = {}
                remaining_flood_amount = roll_type_and_spawn_biters(spawner, force_name, biter_force_name, biters, remaining_flood_amount)
                if biters and #biters > 0 then
                    local command_move_toward_mid = {
                        type = defines.command.go_to_location,
                        destination = {x=math_random(-5, 5), y=spawner.position.y},
                        distraction = defines.distraction.by_damage,
                    }
                    local command_move_to_silo = {
                        type = defines.command.go_to_location,
                        destination = silo.position,
                        radius = 64,
                        distraction = defines.distraction.by_anything,
                    }
                    local command_attack_silo = {
                        type = defines.command.attack,
                        target = silo,
                        distraction = defines.distraction.by_enemy,
                    }
                    for _, biter in pairs(biters) do
                        biter.commandable.set_command({
                            type = defines.command.compound,
                            structure_type = defines.compound_command.return_last,
                            commands = {command_move_toward_mid, command_move_to_silo, command_attack_silo},
                        })
                    end
                end
            end
        end
        storage.bb_flood[biter_force_name] = remaining_flood_amount
    end
end

local function on_chunk_generated(chunk)
    local enemies = chunk.surface.find_entities_filtered{area=chunk.area,force="enemy"}
    local biter_force_name
    if chunk.position.y < 0 then biter_force_name = "north_biters" else biter_force_name = "south_biters" end
    local biter_force = game.forces[biter_force_name]
    local unit_spawners = storage.unit_spawners
    for _,enemy in pairs(enemies) do
        enemy.force = biter_force
        if enemy.name == 'biter-spawner' then
            table_insert(unit_spawners[biter_force_name], enemy)
        elseif enemy.name == 'spitter-spawner' then
            if math_random(1,3) == 1 then --destroy 66% of the spitter spawners to get a 3 : 1 ratio
                table_insert(unit_spawners[biter_force_name], enemy)
            else
                enemy.destroy()
            end
        end
    end

    if chunk.surface.count_tiles_filtered{name={"red-desert-0","red-desert-1"}, area=chunk.area} > 600 then
        --add quality worms for that juicy loot
        local y_pos = chunk.position.y
        if chunk.position.y > 0 then y_pos = y_pos + 1 end
        local chunk_biter_area_depth = math_abs(y_pos) - 16
        if chunk_biter_area_depth > -8 then
            local worm_table = BiterRaffle.get_table('worm', 0.05 * chunk_biter_area_depth)
            local worm_table_sum = 0
            for k, v in pairs(worm_table) do
                worm_table_sum = worm_table_sum + v
            end
            local chunk_x_left = chunk.area.left_top.x
            local chunk_x_right = chunk.area.right_bottom.x
            local chunk_y_top = chunk.area.left_top.y
            local chunk_y_bottom = chunk.area.right_bottom.y
            local min_worms = 3
            local max_worms = 7
            if chunk_biter_area_depth < 0 then
                min_worms = 0
                max_worms = 1
            end
            for _ = 1, math_random(min_worms, max_worms), 1 do
                local worm_name = BiterRaffle.roll_table(worm_table, worm_table_sum)
                if not worm_name then
                    break
                end
                local random_pos = { x = math_random(chunk_x_left, chunk_x_right), y = math_random(chunk_y_top, chunk_y_bottom) }
                local worm_pos = chunk.surface.find_non_colliding_position(worm_name, random_pos, 3, 1)
                if not worm_pos then
                    break
                end

                local quality_roll = math_random(1,1000)
                local worm_quality
                if quality_roll > 850 then worm_quality = 'epic' -- 15%
                elseif quality_roll > 400 then worm_quality = 'rare' -- 45%
                else worm_quality = 'uncommon' --  40%
                end
                
                chunk.surface.create_entity({ name = worm_name, force = biter_force_name, position = worm_pos, quality = worm_quality })
            end
        end
    end
end

Event.add(defines.events.on_chunk_generated, on_chunk_generated)

return Public
