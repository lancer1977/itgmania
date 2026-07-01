--[[
  Polyhydra GameServerInterop: emit song_start when gameplay begins.
  Place in Themes/YourTheme/BGAnimations/ScreenGameplay overlay/
  Requires theme Scripts: Polyhydra_SM_Config, Polyhydra_SM_Json, Polyhydra_SM_EventBus, Polyhydra_SM_EventTypes.
]]

local EventBus = nil
local EventTypes = nil

local function load_sidecar_script(name)
  if not THEME or not THEME.GetCurrentThemeDirectory or not dofile then return nil end
  return dofile(THEME:GetCurrentThemeDirectory() .. "Scripts/" .. name .. ".lua")
end

local function ensure_sidecar_loaded()
  _G.Polyhydra_SM_Config = _G.Polyhydra_SM_Config or load_sidecar_script("Polyhydra_SM_Config")
  _G.Polyhydra_SM_Capabilities = _G.Polyhydra_SM_Capabilities or load_sidecar_script("Polyhydra_SM_Capabilities")
  _G.Polyhydra_SM_EventTypes = _G.Polyhydra_SM_EventTypes or load_sidecar_script("Polyhydra_SM_EventTypes")
  _G.Polyhydra_SM_Json = _G.Polyhydra_SM_Json or load_sidecar_script("Polyhydra_SM_Json")
  _G.Polyhydra_SM_EventBus = _G.Polyhydra_SM_EventBus or load_sidecar_script("Polyhydra_SM_EventBus")
end

local function get_event_types()
  ensure_sidecar_loaded()
  EventTypes = EventTypes or _G.Polyhydra_SM_EventTypes or (require and require("Polyhydra_SM_EventTypes"))
  return EventTypes
end

local function safe(fn)
  local ok, err = pcall(fn)
  if not ok and err then
    if EventBus and EventBus.Emit then
      local types = get_event_types()
      EventBus.Emit(types.Error, { message = tostring(err), context = "ScreenGameplay overlay" })
    end
  end
  return ok
 end

local function get_song_payload()
  local song = (GAMESTATE and GAMESTATE.GetCurrentSong and GAMESTATE:GetCurrentSong()) or nil
  local player = PLAYER_1
  local steps = (GAMESTATE and GAMESTATE.GetCurrentSteps and player and GAMESTATE:GetCurrentSteps(player)) or nil

  local title = ""
  local artist = ""
  local group = ""
  local hash = ""

  if song then
    if song.GetDisplayMainTitle then title = song:GetDisplayMainTitle() or "" end
    if song.GetDisplayArtist then artist = song:GetDisplayArtist() or "" end
    if song.GetGroupName then group = song:GetGroupName() or "" end
    if song.GetSongDir then hash = song:GetSongDir() or "" end
  end

  local stepsType = "unknown"
  local difficulty = "unknown"
  local meter = 0

  if steps then
    if steps.GetStepsType then
      local st = steps:GetStepsType()
      if type(st) == "string" then
        stepsType = st:gsub("StepsType_", ""):gsub("_", "-"):lower()
      end
    end
    if steps.GetDifficulty then
      local d = steps:GetDifficulty()
      if type(d) == "string" then
        difficulty = d:gsub("Difficulty_", ""):lower()
      end
    end
    if steps.GetMeter then meter = steps:GetMeter() or 0 end
  end

  return {
    song = { title = title, artist = artist, group = group, hash = hash },
    chart = { stepsType = stepsType, difficulty = difficulty, meter = meter },
    mods = {}
  }
end

local function emit_song_start()
  if not EventBus or not EventBus.Emit then return end
  if not EventBus.Init() then return end
  local payload = get_song_payload()
  local types = get_event_types()
  EventBus.Emit(types.SongStart, payload)
end

local emitted = false

local function run_song_start()
  safe(function()
    ensure_sidecar_loaded()
    if not EventBus then EventBus = _G.Polyhydra_SM_EventBus or (require and require("Polyhydra_SM_EventBus")) end
    if not EventTypes then EventTypes = get_event_types() end
    if not emitted then
      emit_song_start()
      emitted = true
    end
  end)
end

run_song_start()

return Def.Actor{
  InitCommand = run_song_start,
  OnCommand = run_song_start
}
