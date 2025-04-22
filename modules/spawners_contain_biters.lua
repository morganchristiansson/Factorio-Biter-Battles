-- spawners release biters on death -- by mewmew
local Functions = require('maps.biter_battles_v2.functions')
local BiterRaffle = require('maps.biter_battles_v2.biter_raffle')

local event = require('utils.event')
local math_random = math.random
local math_ceil = math.ceil

local biter_building_inhabitants = {
    [1] = { { 'small-biter', 8, 16 }, { 'small-wriggler-pentapod', 1, 3 } },
    [2] = { { 'small-biter', 12, 24 }, { 'small-wriggler-pentapod', 2, 4 } },
    [3] = { { 'small-biter', 8, 16 }, { 'medium-biter', 1, 2 }, { 'small-wriggler-pentapod', 3, 5 } },
    [4] = { { 'small-biter', 4, 8 }, { 'medium-biter', 4, 8 }, { 'medium-wriggler-pentapod', 1, 3 } },
    [5] = { { 'small-biter', 3, 5 }, { 'medium-biter', 8, 12 }, { 'medium-wriggler-pentapod', 2, 4 } },
    [6] = { { 'small-biter', 3, 5 }, { 'medium-biter', 5, 7 }, { 'big-biter', 1, 2 }, { 'medium-wriggler-pentapod', 3, 5 } },
    [7] = { { 'medium-biter', 6, 8 }, { 'big-biter', 3, 5 }, { 'big-wriggler-pentapod', 1, 3 } },
    [8] = { { 'medium-biter', 2, 4 }, { 'big-biter', 6, 8 }, { 'big-wriggler-pentapod', 2, 4 } },
    [9] = { { 'medium-biter', 2, 3 }, { 'big-biter', 7, 9 }, { 'big-wriggler-pentapod', 3, 5 } },
    [10] = { { 'big-biter', 4, 8 }, { 'behemoth-biter', 3, 4 }, { 'behemoth-wriggler-pentapod', 2, 3 } },
}

local boss_names =
{
    --tier1
    'big-biter',
    'big-wriggler-pentapod',

    --tier2
    'behemoth-spitter',
    'behemoth-wriggler-pentapod',

    --tier3
    'behemoth-biter',
    'medium-strafer-pentapod',

    --tier4
    'titan-wriggler-pentapod',
    'titan-biter',
    'big-stomper-pentapod',
}

local boss_floating_names = {
    ['big-biter'] = {
        'Stefan',
        'Jimmy',
        'Henry',
    },
    ['big-wriggler-pentapod'] = {
        'Emily',
        'Sophia',
        'Anya',
    },

    ['behemoth-spitter'] = {
        'Prince Beauty',
        'Prince Pain',
        'Prince Acidburn',
    },
    ['behemoth-wriggler-pentapod'] = {
        'Princess Night Terror',
        'Princess Crazyarms',
        'Princess Viona',
    },

    ['behemoth-biter'] = {
        'King Scarface',
        'King Brightsmile',
        'King Daystalker',
    },
    ['medium-strafer-pentapod'] = {
        'King Longlegs',
        'Queen Laserchaser',
    },

    ['titan-wriggler-pentapod'] = {
        'Empress Poisonlash',
        'Empress Toxictentacle',
        'Empress Thruthseeker',
    },
    ['titan-biter'] = {
        'Empress Razorteeth',
        'Emperor Dreadfang',
        'Emperor Doombite',
    },
    ['big-stomper-pentapod'] = {
        'Emperor Myth',
        'Emperor Reign',
        'Emperor Promise',
    },
}

local function on_entity_died(event)
    if not event.entity.valid then
        return
    end
    if event.entity.type ~= 'unit-spawner' then
        return
    end
    if event.entity.name == 'gleba-spawner-small' then
        local p = event.entity.surface.find_non_colliding_position('small-stomper-pentapod', event.entity.position, 6, 1)
        if p then
            event.entity.surface.create_entity({ name = 'small-stomper-pentapod', position = p, force = event.entity.force.name })
        end
        return
    end

    local e = math.ceil(event.entity.force.get_evolution_factor(storage.bb_surface_name) * 10)
    if e < 1 then
        e = 1
    end
    for _, t in pairs(biter_building_inhabitants[e]) do
        for x = 1, math_random(t[2], t[3]), 1 do
            local p = event.entity.surface.find_non_colliding_position(t[1], event.entity.position, 6, 1)
            if p then
                local quality_roll = math_random(1, 1000)
                local biter_quality
                if quality_roll >= 980 then biter_quality = 'epic' -- 2%
                elseif quality_roll >= 800 then biter_quality = 'rare' -- 18%
                else biter_quality = 'uncommon' -- 80%
                end

                event.entity.surface.create_entity({ name = t[1], position = p, force = event.entity.force.name, quality = biter_quality })
            end
        end
    end

    if math_random(1,1000) <= 400 then --40% chance on spawner kill
        -- spawn legendary named boss biter
        local force_name
        local biter_force = event.entity.force.name
        if biter_force == 'north_biters' then force_name = 'north'
        elseif biter_force == 'south_biters' then force_name = 'south'
        else return
        end

        if game.ticks_played - storage.last_boss_spawn[biter_force] >= 1200 then -- boss cooldown in frames, 3600 frames is 1 minute
            local announce = false
            local boss_name
            local bb_threat = storage.bb_threat[event.entity.force.name]
            local flood_income = storage.bb_flood_income[biter_force]
            local boss_tier
            local random_roll = math_random(1,100)

            if flood_income < 0.25 then
                if random_roll > flood_income * 400 then boss_tier = 1 else boss_tier = 2 end
            elseif flood_income < 6 then
                if random_roll > flood_income * 17 - 4 then boss_tier = 2 else boss_tier = 3 end
            elseif flood_income < 18.5 then
                if random_roll > flood_income * 4 - 24 then boss_tier = 3 else boss_tier = 4 end
            else
                if random_roll > 50 then boss_tier = 3 else boss_tier = 4 end
            end

            local val
            if boss_tier == 1 then
                val = math_random(1,2)
            elseif boss_tier == 2 then
                val = math_random(3,4)
            elseif boss_tier == 3 then
                val = math_random(5,6)
            else
                val = math_random(7,9)
            end
            boss_name = boss_names[val]
            if val >= 7 then
                announce = true
            end

            local pos = event.entity.surface.find_non_colliding_position(boss_name, event.entity.position, 8, 1)
            if pos then
                local boss = event.entity.surface.create_entity({ name = boss_name, position = pos, force = biter_force, quality = 'legendary' })
                storage.last_boss_spawn[biter_force] = game.ticks_played
                local floating_names = boss_floating_names[boss_name]
                local floating_name = floating_names[math_random(1, #floating_names)]
                if announce then
                    game.print('Legendary boss ' .. floating_name .. ' has been spotted on ' .. Functions.team_name_with_color(force_name) .. ' at ' .. string.format("[gps=%s,%s,%s]", boss.position.x, boss.position.y, boss.surface.name))
                end
                rendering.draw_text({
                    text = floating_name,
                    surface = boss.surface,
                    target = { entity = boss, offset = { x = 0, y = -5 } },
                    color = { r = 1, g = 0.6, b = 0.6, a = 0.8, },
                    scale = 2.3,
                    font = 'default-game',
                    alignment = 'center',
                    scale_with_zoom = false,
                })
            end
        end
    end
end

event.add(defines.events.on_entity_died, on_entity_died)
