local Global = require('utils.global')
local Game = require('utils.game')
local Token = require('utils.token')
local Task = require('utils.task')
local Event = require('utils.event')
local table = require('utils.table')

local session = {}
local trusted = {}
--local nth_tick = 54000 --15min

Global.register({
  session = session,
  trusted = trusted,
}, function(tbl)
  session = tbl.session
  trusted = tbl.trusted
end)

local Public = {}

local function update_time_played(player)
  if not storage.already_logged_current_session_time_online_players[player.name] then
    storage.already_logged_current_session_time_online_players[player.name] = 0
  end
  if not storage.total_time_online_players[player.name] then
    storage.total_time_online_players[player.name] = 0
  end
  local time_to_add = player.online_time - storage.already_logged_current_session_time_online_players[player.name]

  storage.already_logged_current_session_time_online_players[player.name] = storage.already_logged_current_session_time_online_players[player.name]
      + time_to_add
  storage.total_time_online_players[player.name] = storage.total_time_online_players[player.name] + time_to_add
end

-- Trust player automatically after a certain amount of times
local function autotrust_player(player)
  local playerName = player.name
  local playtimeRequiredForAutoTrust = 5184000 -- 24h
  if
    not trusted[playerName]
    and storage.total_time_online_players[playerName] ~= nil
    and storage.total_time_online_players[playerName] >= playtimeRequiredForAutoTrust
  then
    trusted[playerName] = true
  end
end

local function persist_playtime()
  local key = 'total_time_online_players'
  if game.is_multiplayer() then
    helpers.write_file('storage.' .. key, serpent.line(storage[key]), false, 0)
  else
    -- single player testing
    helpers.write_file('storage.' .. key, serpent.line(storage[key]), false)
  end
end

--- Returns the table of session
-- @return <table>
function Public.get_session_table()
  return session
end

--- Returns the table of trusted
-- @return <table>
function Public.get_trusted_table()
  return trusted
end

Event.add(defines.events.on_player_joined_game, function(event)
  local player = game.get_player(event.player_index)
  if not player or not player.valid then
    return
  end
  autotrust_player(player)
end)

Event.add(defines.events.on_player_left_game, function(event)
  local player = game.get_player(event.player_index)
  if not player or not player.valid then
    return
  end
  update_time_played(player)
  persist_playtime()
end)

local nth_tick = 3600 --1min
local function nth_tick_function()
  local players = game.connected_players
  for i = 1, #players do
    local player = players[i]
    if player and player.valid then
      update_time_played(player)
      autotrust_player(player)
    end
  end
  persist_playtime()
end
Event.on_nth_tick(nth_tick, nth_tick_function)

return Public
