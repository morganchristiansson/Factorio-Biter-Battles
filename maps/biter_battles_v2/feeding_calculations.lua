local Tables = require('maps.biter_battles_v2.tables')
local bb_config = require('maps.biter_battles_v2.config')

local math_floor = math.floor
local math_min = math.min
local math_sqrt = math.sqrt

local Public = {}

---@param initial_evo number
---@param food_value number
---@param num_flasks integer
---@param current_player_count integer
---@return { evo_increase: number, threat_increase: number }
function Public.calc_feed_effects(initial_evo, food, current_player_count)
    local evo = initial_evo
    local player_count_modifier = 500 + 25 * math_min(current_player_count, 20)
    local threat = food * player_count_modifier
    while food > 0 do
        if evo < 1 then
            local modifier_start
            local modifier_per_evo
            local max_evo_this_iteration
            if evo < 0.2 then --at 0 to 20 evo: modifier x0.14 to x0.04
                modifier_start = 0.14
                modifier_per_evo = -0.5
                max_evo_this_iteration = 0.2
            elseif evo < 0.5 then --at 20 to 50 evo: modifier x0.02 to x0.002
                modifier_start = 0.032
                modifier_per_evo = -0.06
                max_evo_this_iteration = 0.5
            else --at 50 to 100 evo: modifier x0.0015 to x0.0005
                modifier_start = 0.0025
                modifier_per_evo = -0.002
                max_evo_this_iteration = 1
            end
            --compared to old formula
            --to  20 evo, food needed:   2.27 -> 2.22
            --to  50 evo, food needed:  27.17 -> 27.27
            --to 100 evo, food needed: 418.5  -> 500
            
            local current_evo_modifier = modifier_per_evo * evo + modifier_start
            local end_evo_modifier = modifier_per_evo * max_evo_this_iteration + modifier_start
            local max_evo_gain_this_iteration = max_evo_this_iteration - evo
            local max_food_this_iteration = 2 * max_evo_gain_this_iteration / (current_evo_modifier + end_evo_modifier)
            
            if food < max_food_this_iteration then
                -- rewrite max_food_this_iteration formula:
                -- food = (final_evo - evo) / (0.5 * modifier_per_evo * (evo + final_evo) + modifier_start)
                -- solve for final_evo:
                evo = (evo + (0.5 * evo * modifier_per_evo + modifier_start) * food) / (1 - 0.5 * modifier_per_evo * food)
                break
            else
                evo = max_evo_this_iteration
                food = food - max_food_this_iteration
            end
        else
            evo = evo + food * 0.0005
            break
        end
    end
    
    if evo > 2 then threat = threat * math_floor(evo * 10 - 18) end

    return {
        evo_increase = evo - initial_evo,
        threat_increase = threat,
    }
end

local function starts_with(str, start)
   return str:sub(1, #start) == start
end

-- Player can be nil
---@param params string
---@param difficulty_vote_value number
---@param bb_evolution { string: number }
---@param max_reanim_thresh number
---@param training_mode boolean
---@param player_count integer
---@param player LuaPlayer|nil
---@return string
function Public.calc_send_command(
    params,
    difficulty_vote_value,
    bb_evolution,
    max_reanim_thresh,
    training_mode,
    player_count,
    player
)
    if params == nil then
        params = ''
    end
    local difficulty = difficulty_vote_value * 100
    local evo = nil
    local error_msg
    local flask_color
    local flask_count
    local force_to_send_to
    local help_text = '\nUsage: /calc-send evo=20.0 difficulty=30 players=4 color=green count=1000'
        .. '\nUsage: /calc-send force=north color=white count=1000'
    if player and training_mode then
        force_to_send_to = player.force.name
    elseif player and player.force.name == 'north' then
        force_to_send_to = 'south'
    elseif player and player.force.name == 'south' then
        force_to_send_to = 'north'
    end
    -- indexed by strings like "automation-science-pack"
    local foods = {}
    for param in string.gmatch(params, '([^%s]+)') do
        local k, v = string.match(param, '^(%w+)=([%w%p]+)$')
        if k and v then
            if k == 'force' then
                if v == 'n' or v == 'nth' or v == 'north' then
                    force_to_send_to = 'north'
                elseif v == 's' or v == 'sth' or v == 'south' then
                    force_to_send_to = 'south'
                else
                    error_msg = 'Invalid force'
                end
            elseif k == 'evo' then
                evo = tonumber(v)
                if evo == nil or evo < 0 or evo > 100000 then
                    error_msg = 'Invalid evo'
                end
            elseif k == 'difficulty' then
                difficulty = tonumber(v)
                if difficulty == nil or difficulty < 0 or difficulty > 10000 then
                    error_msg = 'Invalid difficulty'
                end
            elseif k == 'players' then
                player_count = tonumber(v)
                if
                    player_count == nil
                    or player_count < 0
                    or player_count > 10000
                    or player_count ~= math_floor(player_count)
                then
                    error_msg = 'Invalid player count'
                end
            elseif k == 'color' or k == 'colour' then
                if v == 'red' or v == 'automation' then
                    v = 'automation-science-pack'
                end
                if v == 'green' or v == 'logistic' then
                    v = 'logistic-science-pack'
                end
                if v == 'gray' or v == 'grey' or v == 'black' or v == 'military' then
                    v = 'military-science-pack'
                end
                if v == 'blue' or v == 'chemical' then
                    v = 'chemical-science-pack'
                end
                if v == 'purple' or v == 'production' then
                    v = 'production-science-pack'
                end
                if v == 'yellow' or v == 'utility' then
                    v = 'utility-science-pack'
                end
                if v == 'white' or v == 'space' then
                    v = 'space-science-pack'
                end
                if v == 'orange' or v == 'vulcanus' or v == 'metallurgic' then
                    v = 'metallurgic-science-pack'
                end
                if v == 'pink' or v == 'fulgora' or v == 'electromagnetic' then
                    v = 'electromagnetic-science-pack'
                end
                if v == 'lime' or v == 'gleba' or starts_with(v, 'ag') then
                    v = 'agricultural-science-pack'
                end
                if v == 'aquilo' or starts_with(v, 'cr') then
                    v = 'cryogenic-science-pack'
                end
                if starts_with(v, 'prom') or v == 'dark' then
                    v = 'promethium-science-pack'
                end
                local values = Tables.food_values[v]
                if values == nil then
                    error_msg = 'Invalid science pack color'
                else
                    flask_color = v
                end
            elseif k == 'count' then
                if flask_color == nil then
                    error_msg = 'Must specify flask color before count'
                else
                    flask_count = tonumber(v)
                    if flask_count == nil or flask_count <= 0 or flask_count > 1000000000 then
                        error_msg = 'Invalid flask count'
                    else
                        if foods[flask_color] == nil then
                            foods[flask_color] = 0
                        end
                        foods[flask_color] = foods[flask_color] + flask_count
                    end
                end
                flask_color = nil
            else
                error_msg = string.format('Invalid parameter: %q', k)
            end
        else
            error_msg = string.format('Invalid parameter: %q, must do things like "evo=120"', param)
        end
        if error_msg then
            break
        end
    end
    if flask_color ~= nil then
        error_msg = 'Must specify "count" after "color"'
    end
    if error_msg == nil and next(foods) == nil and player ~= nil then
        local i = player.character.get_main_inventory()
        if i then
            for food_type, _ in pairs(Tables.food_values) do
                local flask_amount = i.get_item_count(food_type)
                if flask_amount > 0 then
                    foods[food_type] = flask_amount
                end
            end
        end
    end
    if evo == nil and force_to_send_to then
        local biter_force_name = force_to_send_to .. '_biters'
        if bb_evolution[biter_force_name] then
            evo = bb_evolution[biter_force_name] * 100
        end
    end
    if error_msg == nil and evo == nil then
        error_msg = 'Must specify evo (or force)'
    end
    if error_msg then
        return error_msg .. help_text
    end
    local total_food = 0
    local debug_command_str =
        string.format('evo=%.1f difficulty=%d players=%d', evo, math.floor(difficulty), player_count)
    for k, v in pairs(foods) do
        total_food = total_food + v * Tables.food_values[k].value
        debug_command_str = debug_command_str .. string.format(' color=%s count=%d', k, v)
    end
    if total_food == 0 then
        error_msg = 'no "color"/"count" specified and nothing found in inventory'
    end
    if error_msg then
        return error_msg .. help_text
    end
    local effects =
        Public.calc_feed_effects(evo / 100, total_food * difficulty / 100, player_count, max_reanim_thresh)
    return string.format(
        '/calc-send %s\nevo_increase: %.1f new_evo: %.1f\nthreat_increase: %d',
        debug_command_str,
        effects.evo_increase * 100,
        evo + effects.evo_increase * 100,
        math.floor(effects.threat_increase)
    )
end

return Public
