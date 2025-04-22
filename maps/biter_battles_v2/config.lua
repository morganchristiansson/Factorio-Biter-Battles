--BITER BATTLES CONFIG--

local bb_config = {
    --Optional custom team names, can also be modified via "Team Manager"
    ['north_side_team_name'] = 'Team North',
    ['south_side_team_name'] = 'Team South',

    --TERRAIN OPTIONS--
    ['border_river_width'] = 64, --Approximate width of the horizontal impassable river separating the teams. (values up to 64)

    --BITER SETTINGS--
    ['bitera_area_distance'] = 512, --Distance to the biter area.
    ['biter_area_slope'] = 0.45, -- Slope of the biter area. For example, 0 - an area parallel to the river, 1 - at an angle of 45° to the river
}

return bb_config
