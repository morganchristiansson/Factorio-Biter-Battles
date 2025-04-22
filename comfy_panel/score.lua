--scoreboard by mewmew

local LootRaffle = require('functions.loot_raffle')
local Event = require('utils.event')
local Functions = require('maps.biter_battles_v2.functions')
local Global = require('utils.global')
local Tabs = require('comfy_panel.main')

local Public = {}
local this = {
    score_table = {},
    sort_by = {},
}

Global.register(this, function(t)
    this = t
end)

local sorting_symbol = { ascending = '▲', descending = '▼' }
local building_and_mining_blacklist = {
    ['tile-ghost'] = true,
    ['entity-ghost'] = true,
    ['item-entity'] = true,
}

local math_random = math.random
local math_floor = math.floor
local math_round = function(x)
    return math_floor(x + 0.5)
end

function Public.get_table()
    return this
end

function Public.init_player_table(player)
    if not player then
        return
    end
    if not this.score_table[player.force.name] then
        this.score_table[player.force.name] = {}
    end
    if not this.score_table[player.force.name].players then
        this.score_table[player.force.name].players = {}
    end
    if not this.score_table[player.force.name].players[player.name] then
        this.score_table[player.force.name].players[player.name] = {
            built_entities = 0,
            deaths = 0,
            killscore = 0,
            mined_entities = 0,
        }
    end
end

local function get_score_list(force)
    local score_force = this.score_table[force]
    local score_list = {}
    for _, p in pairs(game.connected_players) do
        if score_force.players[p.name] then
            local score = score_force.players[p.name]
            table.insert(score_list, {
                name = p.name,
                killscore = score.killscore or 0,
                deaths = score.deaths or 0,
                built_entities = score.built_entities or 0,
                mined_entities = score.mined_entities or 0,
            })
        end
    end
    return score_list
end

local function get_sorted_list(method, column_name, score_list)
    local comparators = {
        ['ascending'] = function(a, b)
            return a[column_name] < b[column_name]
        end,
        ['descending'] = function(a, b)
            return a[column_name] > b[column_name]
        end,
    }
    table.sort(score_list, comparators[method])
    return score_list
end

local biters = {
    'small-spitter',
    'small-biter',
    'medium-spitter',
    'medium-biter',
    'big-spitter',
    'big-biter',
    'behemoth-spitter',
    'behemoth-biter',
    'titan-spitter',
    'titan-biter',
    'gargantuan-spitter',
    'gargantuan-biter',
    'small-worm-turret',
    'medium-worm-turret',
    'big-worm-turret',
    'behemoth-worm-turret',
    'small-wriggler-pentapod',
    'medium-wriggler-pentapod',
    'big-wriggler-pentapod',
    'behemoth-wriggler-pentapod',
    'titan-wriggler-pentapod',
    'gargantuan-wriggler-pentapod',
    'small-strafer-pentapod',
    'medium-strafer-pentapod',
    'big-strafer-pentapod',
    'behemoth-strafer-pentapod',
    'titan-strafer-pentapod',
    'small-stomper-pentapod',
    'medium-stomper-pentapod',
    'big-stomper-pentapod',
    'behemoth-stomper-pentapod',
    'titan-stomper-pentapod',
}
local function get_total_biter_killcount(force)
    local count = 0
    for _, biter in pairs(biters) do
        count = count + force.get_kill_count_statistics(storage.bb_surface_name).get_input_count(biter)
    end
    return count
end

local function add_global_stats(frame, player)
    local score = this.score_table[player.force.name]
    local t = frame.add({ type = 'table', column_count = 5 })

    local l = t.add({ type = 'label', caption = 'Rockets launched: ' })
    l.style.font = 'default-game'
    l.style.font_color = { r = 175, g = 75, b = 255 }
    l.style.minimal_width = 140

    local l = t.add({ type = 'label', caption = player.force.rockets_launched })
    l.style.font = 'default-listbox'
    l.style.font_color = { r = 0.9, g = 0.9, b = 0.9 }
    l.style.minimal_width = 123

    local l = t.add({ type = 'label', caption = 'Dead bugs: ' })
    l.style.font = 'default-game'
    l.style.font_color = { r = 0.90, g = 0.3, b = 0.3 }
    l.style.minimal_width = 100

    local l = t.add({ type = 'label', caption = tostring(get_total_biter_killcount(player.force)) })
    l.style.font = 'default-listbox'
    l.style.font_color = { r = 0.9, g = 0.9, b = 0.9 }
    l.style.minimal_width = 145

    local l = t.add({
        type = 'checkbox',
        caption = 'Show floating numbers',
        state = storage.show_floating_killscore[player.name],
        name = 'show_floating_killscore_texts',
    })
    l.style.font_color = { r = 0.8, g = 0.8, b = 0.8 }
end

local show_score = function(player, frame)
    frame.clear()

    Public.init_player_table(player)

    -- Global stats : rockets, biters kills
    add_global_stats(frame, player)

    -- Separator
    local line = frame.add({ type = 'line' })
    line.style.top_margin = 8
    line.style.bottom_margin = 8

    -- Score per player
    local t = frame.add({ type = 'table', column_count = 5 })

    -- Score headers
    local headers = {
        { name = 'score_player', caption = 'Player' },
        { column = 'killscore', name = 'score_killscore', caption = 'Killscore' },
        { column = 'deaths', name = 'score_deaths', caption = 'Deaths' },
        { column = 'built_entities', name = 'score_built_entities', caption = 'Built structures' },
        { column = 'mined_entities', name = 'score_mined_entities', caption = 'Mined entities' },
    }

    local sorting_pref = this.sort_by[player.name]
    for _, header in ipairs(headers) do
        local cap = header.caption

        -- Add sorting symbol if any
        if header.column and sorting_pref.column == header.column then
            local symbol = sorting_symbol[sorting_pref.method]
            cap = symbol .. cap
        end

        -- Header
        local label = t.add({
            type = 'label',
            caption = cap,
            name = header.name,
        })
        label.style.font = 'default-listbox'
        label.style.font_color = { r = 0.98, g = 0.66, b = 0.22 } -- yellow
        label.style.minimal_width = 150
        label.style.horizontal_align = 'right'
    end

    -- Score list
    local score_list = get_score_list(player.force.name)

    if #game.connected_players > 1 then
        score_list = get_sorted_list(sorting_pref.method, sorting_pref.column, score_list)
    end

    -- New pane for scores (while keeping headers at same position)
    local scroll_pane = frame.add({
        type = 'scroll-pane',
        name = 'score_scroll_pane',
        direction = 'vertical',
        horizontal_scroll_policy = 'never',
        vertical_scroll_policy = 'auto',
    })
    scroll_pane.style.maximal_height = 400
    local t = scroll_pane.add({ type = 'table', column_count = 5 })

    -- Score entries
    for _, entry in pairs(score_list) do
        local p = game.get_player(entry.name)
        local special_color = {
            r = p.color.r * 0.6 + 0.4,
            g = p.color.g * 0.6 + 0.4,
            b = p.color.b * 0.6 + 0.4,
            a = 1,
        }
        local line = {
            { caption = entry.name, color = special_color },
            { caption = tostring(entry.killscore) },
            { caption = tostring(entry.deaths) },
            { caption = tostring(entry.built_entities) },
            { caption = tostring(entry.mined_entities) },
        }
        local default_color = { r = 0.9, g = 0.9, b = 0.9 }

        for _, column in ipairs(line) do
            local label = t.add({
                type = 'label',
                caption = column.caption,
                color = column.color or default_color,
            })
            label.style.font = 'default'
            label.style.minimal_width = 150
            label.style.maximal_width = 150
            label.style.horizontal_align = 'right'
        end -- foreach column
    end -- foreach entry
end

local function refresh_score_full()
    for _, player in pairs(game.connected_players) do
        local frame = Tabs.comfy_panel_get_active_frame(player)
        if frame then
            if frame.name == 'Scoreboard' then
                show_score(player, frame)
            end
        end
    end
end

local function on_player_joined_game(event)
    local player = game.get_player(event.player_index)
    Public.init_player_table(player)
    if not this.sort_by[player.name] then
        this.sort_by[player.name] = { method = 'descending', column = 'killscore' }
    end
    if not storage.show_floating_killscore then
        storage.show_floating_killscore = {}
    end
    if not storage.show_floating_killscore[player.name] then
        storage.show_floating_killscore[player.name] = false
    end
end

local function on_gui_click(event)
    if not event then
        return
    end
    if not event.element then
        return
    end
    if not event.element.valid then
        return
    end

    local player = game.get_player(event.element.player_index)
    local frame = Tabs.comfy_panel_get_active_frame(player)
    if not frame then
        return
    end
    if frame.name ~= 'Scoreboard' then
        return
    end

    local name = event.element.name

    -- Handles click on the checkbox, for floating score
    if name == 'show_floating_killscore_texts' then
        storage.show_floating_killscore[player.name] = event.element.state
        return
    end

    -- Handles click on a score header
    local element_to_column = {
        ['score_killscore'] = 'killscore',
        ['score_deaths'] = 'deaths',
        ['score_built_entities'] = 'built_entities',
        ['score_mined_entities'] = 'mined_entities',
    }
    local column = element_to_column[name]
    if column then
        local sorting_pref = this.sort_by[player.name]
        if sorting_pref.column == column and sorting_pref.method == 'descending' then
            sorting_pref.method = 'ascending'
        else
            sorting_pref.method = 'descending'
            sorting_pref.column = column
        end
        show_score(player, frame)
        return
    end

    -- No more to handle
end

local function on_rocket_launched(event)
    refresh_score_full()
end

local entity_score_values = {
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

local boss_tier_map = {
    ['big-biter'] = 1,
    ['big-wriggler-pentapod'] = 1,

    ['behemoth-spitter'] = 2,
    ['behemoth-wriggler-pentapod'] = 2,

    ['behemoth-biter'] = 3,
    ['medium-strafer-pentapod'] = 3,

    ['titan-wriggler-pentapod'] = 4,
    ['titan-biter'] = 4,
    ['big-stomper-pentapod'] = 4,
}

local function train_type_cause(event)
    local players = {}
    if event.cause.train.passengers then
        for _, player in pairs(event.cause.train.passengers) do
            players[#players + 1] = player
        end
    end
    return players
end

local kill_causes = {
    ['character'] = function(event)
        if not event.cause.player then
            return
        end
        return { event.cause.player }
    end,
    ['combat-robot'] = function(event)
        if not event.cause.last_user then
            return
        end
        if not game.get_player(event.cause.last_user.index) then
            return
        end
        return { game.get_player(event.cause.last_user.index) }
    end,
    ['car'] = function(event)
        local players = {}
        local driver = event.cause.get_driver()
        if driver then
            if driver.player then
                players[#players + 1] = driver.player
            end
        end
        local passenger = event.cause.get_passenger()
        if passenger then
            if passenger.player then
                players[#players + 1] = passenger.player
            end
        end
        return players
    end,
    ['locomotive'] = train_type_cause,
    ['cargo-wagon'] = train_type_cause,
    ['artillery-wagon'] = train_type_cause,
    ['fluid-wagon'] = train_type_cause,
}

local function give_loot(name, quality, surface, entity, player)
    local inserted_count = player.insert({ name = name, count = 1, quality = quality })
    if inserted_count < 1 then
        surface.spill_item_stack({
            position = entity.position,
            stack = { name = name, count = 1, quality = quality},
            enable_looted = true,
        })
    end

    player.create_local_flying_text({
        position = { entity.position.x, entity.position.y + 0.5},
        text = '+1 [img=item/' .. name .. ']',
        color = { r = 0.98, g = 0.66, b = 0.22 },
    })
end

local function on_entity_died(event)
    local entity = event.entity
    if not (entity and entity.valid) then
        return
    end
    if not event.cause then
        return
    end
    if not event.cause.valid then
        return
    end
    if entity.force.index == event.cause.force.index then
        return
    end
    if not entity_score_values[entity.name] then
        return
    end
    if not kill_causes[event.cause.type] then
        return
    end
    local players_to_reward = kill_causes[event.cause.type](event)
    if not players_to_reward then
        return
    end
    if #players_to_reward == 0 then
        return
    end
    local quality_factor = 1
    local do_loot = false

    if entity.quality.name == 'uncommon' then quality_factor = 1.3 end

    if entity.quality.name == 'rare' then
        quality_factor = 1.6
        if math_random(1, 100) >= 83 then do_loot = true end
    end

    if entity.quality.name == 'epic' then
        quality_factor = 1.9
        if math_random(1, 100) >= 65 then do_loot = true end
    end

    if entity.quality.name == 'legendary' then
        quality_factor = 25
        do_loot = true
    end

    local value = math_round(entity_score_values[entity.name] * quality_factor)

    local firstplayer = true
    for _, player in pairs(players_to_reward) do
        Public.init_player_table(player)
        local score = this.score_table[player.force.name].players[player.name]
        score.killscore = score.killscore + value
        if storage.show_floating_killscore[player.name] then
            Functions.create_local_flying_text({
                surface = entity.surface,
                position = entity.position,
                text = tostring(value),
                color = player.chat_color,
            })
        end
        
        if firstplayer and do_loot then
            firstplayer = false

            local lootname
            local loot_quality = 'normal'
            local surface = entity.surface
            if entity.quality.name == 'legendary' then
                local tier = boss_tier_map[entity.name]
                if not tier then tier = 1 end

                local flood_income_increase
                if tier == 4 then
                    flood_income_increase = 2.5
                elseif tier == 3 then
                    flood_income_increase = 0.5
                elseif tier == 2 then
                    flood_income_increase = 0.1
                else
                    flood_income_increase = 0.02
                end
                local biter_force_name = entity.force.name
                storage.bb_flood_income[biter_force_name] = storage.bb_flood_income[biter_force_name] + flood_income_increase
                
                if tier == 1 then
                    --check if player already owns an armor, if not, give one
                    local main = player.character.get_main_inventory().get_contents()
                    local armor = player.character.get_inventory(defines.inventory.character_armor).get_contents()
                    local trash = player.character.get_inventory(defines.inventory.character_trash).get_contents()
                    local armor_found = false
                    for _,item in pairs(armor) do
                        if item.name == 'modular-armor' or item.name == 'power-armor' or item.name == 'power-armor-mk2' or item.name == 'mech-armor' or armor_found then
                            armor_found = true
                            break;
                        end
                    end
                    for _,item in pairs(main) do
                        if item.name == 'modular-armor' or armor_found then
                            armor_found = true
                            break;
                        end
                    end
                    for _,item in pairs(trash) do
                        if item.name == 'modular-armor' or armor_found then
                            armor_found = true
                            break;
                        end
                    end

                    if not armor_found then
                        give_loot('modular-armor', 'normal', surface, entity, player)
                    end
                else
                    --check if player already owns a railgun, if not, give one
                    local main = player.character.get_main_inventory().get_contents()
                    local guns = player.character.get_inventory(defines.inventory.character_guns).get_contents()
                    local trash = player.character.get_inventory(defines.inventory.character_trash).get_contents()
                    local teslagun_found = false
                    local railgun_found = false
                    for _,item in pairs(guns) do
                        if item.name == 'railgun' then
                            railgun_found = true
                        end
                        if item.name == 'teslagun' then
                            teslagun_found = true
                        end
                        if teslagun_found and railgun_found then
                            break
                        end
                    end
                    for _,item in pairs(main) do
                        if item.name == 'railgun' then
                            railgun_found = true
                        end
                        if item.name == 'teslagun' then
                            teslagun_found = true
                        end
                        if teslagun_found and railgun_found then
                            break
                        end
                    end
                    for _,item in pairs(trash) do
                        if item.name == 'railgun' then
                            railgun_found = true
                        end
                        if item.name == 'teslagun' then
                            teslagun_found = true
                        end
                        if teslagun_found and railgun_found then
                            break
                        end
                    end

                    if not teslagun_found then
                        give_loot('teslagun', 'normal', surface, entity, player)
                    elseif not railgun_found then
                        give_loot('railgun', 'normal', surface, entity, player)
                    end

                    if math_random(1,10) == 1 then
                        loot_quality = 'rare'
                    else
                        loot_quality = 'uncommon'
                    end
                end

                if tier > 2 then
                    if tier > 3 or math_random(1,5) == 1 then
                        if math_random(1,5) == 1 then
                            loot_quality = 'legendary'
                        else
                            loot_quality = 'epic'
                        end
                    else
                        loot_quality = 'rare'
                    end
                end

                lootname = LootRaffle.roll_tier_loot(tier)
            else
                if entity.quality.name == 'epic' then
                    if math_random(1,5) == 1 then
                        if math_random(1,5) == 1 then
                            if math_random(1,5) == 1 then
                                loot_quality = 'epic'
                            else
                                loot_quality = 'rare'
                            end
                        else
                            loot_quality = 'uncommon'
                        end
                    end
                end
                lootname = LootRaffle.roll_loot(entity.quality.name)
            end

            give_loot(lootname, loot_quality, surface, entity, player)
        end
    end
end

local function on_player_died(event)
    local player = game.get_player(event.player_index)
    Public.init_player_table(player)
    local score = this.score_table[player.force.name].players[player.name]
    score.deaths = 1 + (score.deaths or 0)
end

---@param entity LuaEntity
---@param player LuaPlayer
function Public.on_player_mined_entity(entity, player)
    if building_and_mining_blacklist[entity.type] then
        return
    end

    Public.init_player_table(player)
    local score = this.score_table[player.force.name].players[player.name]
    score.mined_entities = 1 + (score.mined_entities or 0)
end

local function on_built_entity(event)
    if not event.entity.valid then
        return
    end
    if building_and_mining_blacklist[event.entity.type] then
        return
    end
    local player = game.get_player(event.player_index)
    Public.init_player_table(player)
    local score = this.score_table[player.force.name].players[player.name]
    score.built_entities = 1 + (score.built_entities or 0)
end

comfy_panel_tabs['Scoreboard'] = { gui = show_score, admin = false }

Event.add(defines.events.on_player_died, on_player_died)
Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_entity_died, on_entity_died)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_rocket_launched, on_rocket_launched)

return Public
