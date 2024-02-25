--[[
    Author: flightwusel
]]

--[[ local ]]

-- sim/cockpit2/gauges/indicators/wind_heading_deg_mag
-- sim/cockpit2/gauges/indicators/wind_speed_kts

local windDir_degt_dataref = XPLMFindDataRef("sim/weather/aircraft/wind_now_direction_degt")
local windSpeed_mPerS_dataref = XPLMFindDataRef("sim/weather/aircraft/wind_now_speed_msc")
local windDir_degt
local windSpeed_mPerS

local windAlts_m_dataref = XPLMFindDataRef("sim/weather/aircraft/wind_altitude_msl_m")
local windDirs_degt_dataref = XPLMFindDataRef("sim/weather/aircraft/wind_direction_degt")
local windSpeeds_kt_dataref = XPLMFindDataRef("sim/weather/aircraft/wind_speed_kts")
local windAlts_m
local windDirs_degt
local windSpeeds_kt

local windAltsRegion_m_dataref = XPLMFindDataRef("sim/weather/region/wind_altitude_msl_m")
local windDirsRegion_degt_dataref = XPLMFindDataRef("sim/weather/region/wind_direction_degt")
local windSpeedsRegion_mPerS_dataref = XPLMFindDataRef("sim/weather/region/wind_speed_msc")
local windAltsRegion_m
local windDirsRegion_degt
local windSpeedsRegion_mPerS

local elevation_m_dataref = XPLMFindDataRef("sim/flightmodel/position/elevation")
local elevation_m

local function log(msg, level)
    -- @see https://stackoverflow.com/questions/9168058/how-to-dump-a-table-to-console
    local function dump(o)
        if type(o) == 'table' then
            local s = '{ '
            for k,v in pairs(o) do
                if type(k) ~= 'number' then k = '"'..k..'"' end
                s = s .. '['..k..'] = ' .. dump(v) .. ','
            end
            return s .. '} '
        else
            return tostring(o)
        end
    end

    local msg = msg or ""
    local level = level or ""
    local filePath = debug.getinfo(2, "S").source
    local fileName = filePath:match("[^/\\]*.lua$")
    local functionName = debug.getinfo(2, "n").name
    logMsg(
        string.format(
            "%s::%s() %s%s",
            fileName,
            functionName,
            level,
            dump(msg)
        )
    )
end

local function err(msg)
    return log(msg, "[ERROR] ")
end

local function addToggleMacroAndCommand(cmdRef, titlePrefix, activateCallbackName, globalStateVariableName)
    local macroActivated = loadstring("return " .. globalStateVariableName)() and 'activate' or 'deactivate'
    local cmdRefToggle = cmdRef .. "Toggle"
    local cmdRefActivate = cmdRef .. "Activate"
    local cmdRefDeactivate = cmdRef .. "Deactivate"
    local macroTitle = titlePrefix .. "Activate/De-Activate (Toggle)"
    log(
        string.format(
            "Adding commands %s, %s, %s and macro '%s' (activated: %s)",
            cmdRefToggle,
            cmdRefActivate,
            cmdRefDeactivate,
            macroTitle,
            macroActivated
        )
    )

    create_command(cmdRefToggle, titlePrefix .. "Toggle", activateCallbackName .. "(not " .. globalStateVariableName .. ")", "", "")
    create_command(cmdRefActivate, titlePrefix .. "Activate", activateCallbackName .. "(true)", "", "")
    create_command(cmdRefDeactivate, titlePrefix .. "De-Activate", activateCallbackName .. "(false)", "", "")
    add_macro(macroTitle, activateCallbackName .. "(true)", activateCallbackName .. "(false)", macroActivated)
end

local function m2ft(m)
    return m / 0.3048
end

local function mPerS2kt(mPerS)
    return mPerS / 0.514444
end

local function do_fetchWind()
    windDir_degt = XPLMGetDataf(windDir_degt_dataref)
    windSpeed_mPerS = XPLMGetDataf(windSpeed_mPerS_dataref)

    windAlts_m = XPLMGetDatavf(windAlts_m_dataref, 0, 13)
    windDirs_degt = XPLMGetDatavf(windDirs_degt_dataref, 0, 13)
    windSpeeds_kt = XPLMGetDatavf(windSpeeds_kt_dataref, 0, 13)

    windAltsRegion_m = XPLMGetDatavf(windAltsRegion_m_dataref, 0, 13)
    windDirsRegion_degt = XPLMGetDatavf(windDirsRegion_degt_dataref, 0, 13)
    windSpeedsRegion_mPerS = XPLMGetDatavf(windSpeedsRegion_mPerS_dataref, 0, 13)

    elevation_m = XPLMGetDatad(elevation_m_dataref)
end

local function activate(isEnabled)
    wind_isEnabled = isEnabled

    log(
        string.format(
            "enabled: %s",
            wind_isEnabled
        )
    )

    if wind_isEnabled then
        do_fetchWind()
    end
end

local function init()
    addToggleMacroAndCommand(
        "flightwusel/Wind/",
        "Wind: ",
        "wind_activate_callback",
        "wind_isEnabled"
    )
    do_every_draw("wind_draw_callback()")
    do_often("wind_often_callback()")
end

--[[ global ]]
wind_isEnabled = false

function wind_activate_callback(isEnabled)
    if isEnabled == wind_isEnabled then
        return
    end
    activate(isEnabled)
end

function wind_often_callback()
    if not wind_isEnabled then
        return
    end

    do_fetchWind()
end

function wind_draw_callback()
    if not wind_isEnabled then
        return
    end

    local _isCurrentLevel = false
    local _isCurrentLower = true
    local _a = 0
    local windLevelInfo = {}
    for _i = 0, 12 do
        if windSpeeds_kt[_i] > 0. then
            if _isCurrentLower and windAlts_m[_i] > elevation_m then
                _isCurrentLevel = true
                _isCurrentLower = false
                windLevelInfo[_i] = string.format(
                    '= /aircraft/ %03d deg @ %03d kt =',
                    windDir_degt,
                    mPerS2kt(windSpeed_mPerS)
                )
                _a = 1
            end
            windLevelInfo[_i + _a] = string.format(
                '%02.0fk ft: %03d deg @ %03d kt',
                m2ft(windAlts_m[_i]) / 1000.,
                windDirs_degt[_i],
                windSpeeds_kt[_i]
            )
        end
    end

    -- reverse list
--    table.sort(windLevelInfo, function(a, b) return a > b end)

    local _rightBubbleWidth = bubble(
        SCREEN_WIDTH - 160,
        -10,
        '',
        unpack(windLevelInfo)
    )

    -- region
--     local windLevelInfo = {}
--     for _i = 0, 12 do
--         if windSpeedsRegion_mPerS[_i] > 0. then
--             windLevelInfo[_i] = string.format(
--                 '%02.0fk ft: %03d deg @ %03d kt',
--                 m2ft(windAltsRegion_m[_i]) / 1000.,
--                 windDirsRegion_degt[_i],
--                 mPerS2kt(windSpeedsRegion_mPerS[_i])
--             )
--         end
--     end
--
--     -- reverse list
--     table.sort(windLevelInfo, function(a, b) return a > b end)
--
--     bubble(
--         SCREEN_WIDTH - _rightBubbleWidth * 2,
--         -10,
--         '/region/',
--         unpack(windLevelInfo)
--     )
end

init()
