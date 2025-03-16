local Token = require('utils.token')
local Task = require('utils.task')
local Global = require('utils.global')
local Event = require('utils.event')
local Print = require('utils.print_override')

local concat = table.concat
local remove = table.remove
local raw_print = Print.raw_print

local Public = {}

local discord_bold_tag = '[DISCORD-BOLD]'
local discord_embed_tag = '[DISCORD-EMBED]'
local player_join_tag = '[PLAYER-JOIN]'
local player_leave_tag = '[PLAYER-LEAVE]'

Public.raw_print = raw_print

function Public.to_discord_player_chat(message)
    raw_print(player_chat_tag .. message)
end

--- Sends a message to the linked discord channel. The message is sanitized of markdown server side, then made bold.
-- @param  message<string> message to send.
function Public.to_discord_bold(message)
    raw_print(discord_bold_tag .. message)
end

--- Sends a embed message to the linked discord channel. The message is sanitized of markdown server side.
-- @param  message<string> the content of the embed.
function Public.to_discord_embed(message)
    raw_print(discord_embed_tag .. message)
end

--- Sends a embed message to the linked banned discord channel. The message is sanitized of markdown server side.
-- @param  message<string> the content of the embed.
function Public.to_banned_embed(message)
    raw_print(discord_banned_embed_tag .. message)
end


--- The [JOIN] and [LEAVE] messages Factorio sends to stdout aren't sent in all cases of
--  players joining or leaving. So we send our own [PLAYER-JOIN] and [PLAYER-LEAVE] tags.
Event.add(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end

    raw_print(player_join_tag .. player.name)
end)

Event.add(defines.events.on_player_left_game, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end

    raw_print(player_leave_tag .. player.name)
end)

Event.add(defines.events.on_console_command, function(event)
    local cmd = event.command
    if not event.player_index then
        return
    end
    local player = game.get_player(event.player_index)
    local reason = event.parameters
    if not reason then
        return
    end
    if not player.admin then
        return
    end
    if cmd == 'ban' then
        if player then
            Public.to_banned_embed(table.concat({ player.name .. ' banned ' .. reason }))
            return
        else
            Public.to_banned_embed(table.concat({ 'Server banned ' .. reason }))
            return
        end
    elseif cmd == 'unban' then
        if player then
            Public.to_banned_embed(table.concat({ player.name .. ' unbanned ' .. reason }))
            return
        else
            Public.to_banned_embed(table.concat({ 'Server unbanned ' .. reason }))
            return
        end
    end
end)

Event.add(defines.events.on_player_died, function(event)
    local player = game.get_player(event.player_index)

    if not player or not player.valid then
        return
    end

    local cause = event.cause

    local message = { discord_bold_tag, player.name }
    if cause and cause.valid then
        message[#message + 1] = ' was killed by '

        local name = cause.name
        if name == 'character' and cause.player then
            name = cause.player.name
        end

        message[#message + 1] = name
        message[#message + 1] = '.'
    else
        message[#message + 1] = ' has died.'
    end

    message = concat(message)
    raw_print(message)
end)

return Public
