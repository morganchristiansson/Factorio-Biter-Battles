local Public = {}
local math_random = math.random
local math_ceil = math.ceil
local math_max = math.max
local math_abs = math.abs

local function get_value(evo, middleofrange, final)
    if final and evo > middleofrange then
        return 100
    end
    return math_ceil(math_max(100 - math_abs(evo - middleofrange) * 200, 0))
end

local function add_to_table(biter_table, biter, evo, middleofrange, final, factor)
    local value = get_value(evo, middleofrange, final)
    if value > 0 then
        biter_table[biter] = value * factor
    end
end

function Public.get_table(entity_type, evolution_factor)
    local result_table = {}

    if entity_type == 'biter' or entity_type == 'mixed' then
        add_to_table(result_table, 'small-biter', evolution_factor, 0.05, false, 4)
        add_to_table(result_table, 'medium-biter', evolution_factor, 0.67, false, 4)
        add_to_table(result_table, 'big-biter', evolution_factor, 1, false, 4)
        add_to_table(result_table, 'behemoth-biter', evolution_factor, 1.4, false, 4)
        add_to_table(result_table, 'titan-biter', evolution_factor, 2.2, false, 4)
        add_to_table(result_table, 'gargantuan-biter', evolution_factor, 3, true, 4)

        add_to_table(result_table, 'small-wriggler-pentapod', evolution_factor, 0.7, false, 1)
        add_to_table(result_table, 'medium-wriggler-pentapod', evolution_factor, 0.9, false, 1)
        add_to_table(result_table, 'big-wriggler-pentapod', evolution_factor, 1.1, false, 1)
        add_to_table(result_table, 'behemoth-wriggler-pentapod', evolution_factor, 1.5, false, 1)
        add_to_table(result_table, 'titan-wriggler-pentapod', evolution_factor, 2.3, false, 1)
        add_to_table(result_table, 'gargantuan-wriggler-pentapod', evolution_factor, 3.1, true, 1)
    end
    if entity_type == 'spitter' or entity_type == 'mixed' then
        add_to_table(result_table, 'small-spitter', evolution_factor, 0.25, false, 2)
        add_to_table(result_table, 'medium-spitter', evolution_factor, 0.72, false, 2)
        add_to_table(result_table, 'big-spitter', evolution_factor, 1.1, false, 2)
        add_to_table(result_table, 'behemoth-spitter', evolution_factor, 1.4, false, 2)
        add_to_table(result_table, 'titan-spitter', evolution_factor, 2.1, false, 2)
        add_to_table(result_table, 'gargantuan-spitter', evolution_factor, 2.9, true, 2)
    end
    if entity_type == 'gleba' then
        if evolution_factor <= 0.2 then
            add_to_table(result_table, 'small-spitter', evolution_factor, 0.25, false, 2)
            add_to_table(result_table, 'medium-spitter', evolution_factor, 0.72, false, 2)
        elseif evolution_factor <= 0.7 then
            add_to_table(result_table, 'small-wriggler-pentapod', evolution_factor, 0.7, false, 1)
            add_to_table(result_table, 'medium-wriggler-pentapod', evolution_factor, 0.9, false, 1)
            add_to_table(result_table, 'big-wriggler-pentapod', evolution_factor, 1.1, false, 1)
        else
            add_to_table(result_table, 'small-strafer-pentapod', evolution_factor, 1.2, false, 2)
            add_to_table(result_table, 'medium-strafer-pentapod', evolution_factor, 1.6, false, 2)
            add_to_table(result_table, 'big-strafer-pentapod', evolution_factor, 2, false, 2)
            add_to_table(result_table, 'behemoth-strafer-pentapod', evolution_factor, 2.4, false, 2)
            add_to_table(result_table, 'titan-strafer-pentapod', evolution_factor, 2.8, true, 2)
            
            add_to_table(result_table, 'small-stomper-pentapod', evolution_factor, 1.45, false, 1)
            add_to_table(result_table, 'medium-stomper-pentapod', evolution_factor, 1.85, false, 1)
            add_to_table(result_table, 'big-stomper-pentapod', evolution_factor, 2.25, false, 1)
            add_to_table(result_table, 'behemoth-stomper-pentapod', evolution_factor, 2.65, false, 1)
            add_to_table(result_table, 'titan-stomper-pentapod', evolution_factor, 3.05, true, 1)
        end
    end
    if entity_type == 'worm' then
        add_to_table(result_table, 'small-worm-turret', evolution_factor, 0.05, false, 4)
        add_to_table(result_table, 'medium-worm-turret', evolution_factor, 0.5, false, 1)
        add_to_table(result_table, 'big-worm-turret', evolution_factor, 1, true, 2)
        add_to_table(result_table, 'behemoth-worm-turret', evolution_factor, 1.4, true, 3)
    end
    return result_table
end

function Public.get_boss_table(entity_type, evolution_factor)
    local result_table = {}
    
        if entity_type == 'biter' or entity_type == 'mixed' then
        add_to_table(result_table, 'medium-biter', evolution_factor, 0.05, false, 2)
        add_to_table(result_table, 'big-biter', evolution_factor, 0.67, false, 2)
        add_to_table(result_table, 'behemoth-biter', evolution_factor, 1, false, 2)
        add_to_table(result_table, 'titan-biter', evolution_factor, 1.4, false, 2)
        add_to_table(result_table, 'gargantuan-biter', evolution_factor, 2.2, true, 2)
        
        add_to_table(result_table, 'medium-wriggler-pentapod', evolution_factor, 0.10, false, 1)
        add_to_table(result_table, 'big-wriggler-pentapod', evolution_factor, 0.77, false, 1)
        add_to_table(result_table, 'behemoth-wriggler-pentapod', evolution_factor, 1.1, false, 1)
        add_to_table(result_table, 'titan-wriggler-pentapod', evolution_factor, 1.5, false, 1)
        add_to_table(result_table, 'gargantuan-wriggler-pentapod', evolution_factor, 2.3, true, 1)
    end
    if entity_type == 'spitter' or entity_type == 'mixed' then
        add_to_table(result_table, 'medium-spitter', evolution_factor, 0.25, false, 1)
        add_to_table(result_table, 'big-spitter', evolution_factor, 0.72, false, 1)
        add_to_table(result_table, 'behemoth-spitter', evolution_factor, 1.1, false, 1)
        add_to_table(result_table, 'titan-spitter', evolution_factor, 1.4, false, 1)
        add_to_table(result_table, 'gargantuan-spitter', evolution_factor, 2.1, true, 1)
    end
    if entity_type == 'gleba' then
        if evolution_factor < 0.7 then
            add_to_table(result_table, 'medium-wriggler-pentapod', evolution_factor, 0.10, false, 1)
            add_to_table(result_table, 'big-wriggler-pentapod', evolution_factor, 0.77, false, 1)
            add_to_table(result_table, 'behemoth-wriggler-pentapod', evolution_factor, 1.1, false, 1)
            add_to_table(result_table, 'titan-wriggler-pentapod', evolution_factor, 1.5, false, 1)
            add_to_table(result_table, 'gargantuan-wriggler-pentapod', evolution_factor, 2.3, true, 1)
        else
            add_to_table(result_table, 'medium-strafer-pentapod', evolution_factor, 1.2, false, 2)
            add_to_table(result_table, 'big-strafer-pentapod', evolution_factor, 1.6, false, 2)
            add_to_table(result_table, 'behemoth-strafer-pentapod', evolution_factor, 2, false, 2)
            add_to_table(result_table, 'titan-strafer-pentapod', evolution_factor, 2.4, true, 2)
            
            add_to_table(result_table, 'medium-stomper-pentapod', evolution_factor, 1.45, false, 1)
            add_to_table(result_table, 'big-stomper-pentapod', evolution_factor, 1.85, false, 1)
            add_to_table(result_table, 'behemoth-stomper-pentapod', evolution_factor, 2.25, false, 1)
            add_to_table(result_table, 'titan-stomper-pentapod', evolution_factor, 2.65, true, 1)
        end
    end

    return result_table
end

function Public.roll_table(biter_table, biter_table_sum)
    local r = math_random(0, biter_table_sum)
    for k, v in pairs(biter_table) do
        if r <= v then
            return k
        end
        r = r - v
    end
end

return Public
