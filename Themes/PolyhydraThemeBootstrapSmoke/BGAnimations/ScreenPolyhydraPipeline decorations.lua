--[[
  Polyhydra GameServerInterop: theme-driven pipeline bootstrap.

  Install into a theme and launch with metrics like:
    --metric=Common::InitialScreen="ScreenPolyhydraPipeline"
    --metric=ScreenPolyhydraPipeline::Class="ScreenWithMenuElements"
    --metric=ScreenPolyhydraPipeline::Fallback="ScreenWithMenuElementsBlank"
]]

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

ensure_sidecar_loaded()

local Config = _G.Polyhydra_SM_Config or (require and require("Polyhydra_SM_Config"))
local EventBus = _G.Polyhydra_SM_EventBus or (require and require("Polyhydra_SM_EventBus"))
local EventTypes = _G.Polyhydra_SM_EventTypes or (require and require("Polyhydra_SM_EventTypes"))

local function emit_event(event_type, payload)
  if EventBus and EventBus.Init and EventBus.Init() and EventBus.Emit then
    EventBus.Emit(event_type, payload)
  end
end

local function emit_error(message, context)
  emit_event(EventTypes.Error, { message = tostring(message), context = context or "ScreenPolyhydraPipeline" })
end

local function normalize(value)
  if type(value) ~= "string" then return "" end
  return value:gsub("^Difficulty_", ""):gsub("^StepsType_", ""):gsub("_", "-"):lower()
end

local function find_song()
  if not SONGMAN or not SONGMAN.FindSong then return nil end

  if Config.PipelineSong and Config.PipelineSong ~= "" then
    return SONGMAN:FindSong(Config.PipelineSong)
  end

  local songDir = Config.PipelineSongDir
  if type(songDir) ~= "string" or songDir == "" then return nil end

  local normalized = songDir:gsub("\\", "/"):gsub("/$", "")
  local group, song = normalized:match("([^/]+)/([^/]+)$")
  if group and song then
    return SONGMAN:FindSong(group .. "/" .. song)
  end

  return SONGMAN:FindSong(normalized)
end

local function choose_steps(song)
  if not song or not SongUtil or not SongUtil.GetPlayableSteps then return nil end

  local steps = SongUtil.GetPlayableSteps(song)
  if type(steps) ~= "table" then return nil end

  local requested = normalize(Config.PipelineDifficulty)
  local first = nil
  for _, candidate in pairs(steps) do
    if not first then first = candidate end
    if requested ~= "" and candidate and candidate.GetDifficulty and normalize(candidate:GetDifficulty()) == requested then
      return candidate
    end
  end

  return first
end

local function prepare_gameplay()
  local song = find_song()
  if not song then
    emit_error("pipeline song not found", "ScreenPolyhydraPipeline.find_song")
    return false
  end

  local steps = choose_steps(song)
  if not steps then
    emit_error("pipeline steps not found", "ScreenPolyhydraPipeline.choose_steps")
    return false
  end

  local player = PLAYER_1
  if GAMESTATE.JoinPlayer and player then GAMESTATE:JoinPlayer(player) end
  if GAMESTATE.SetCurrentStyle then
    local ok, err = pcall(function() GAMESTATE:SetCurrentStyle("single") end)
    if not ok then emit_error(err, "ScreenPolyhydraPipeline.set_style") end
  end
  if GAMESTATE.SetCurrentSong then GAMESTATE:SetCurrentSong(song) end
  if GAMESTATE.SetCurrentSteps and player then GAMESTATE:SetCurrentSteps(player, steps) end

  if GAMESTATE.prepare_song_for_gameplay then
    local result = GAMESTATE:prepare_song_for_gameplay()
    if result and result ~= 0 and result ~= "success" then
      emit_error("prepare_song_for_gameplay failed: " .. tostring(result), "ScreenPolyhydraPipeline.prepare")
      return false
    end
  end

  emit_event(EventTypes.SessionStart, {
    launch = {
      adapter = "theme-bootstrap",
      song = Config.PipelineSong,
      songDir = Config.PipelineSongDir,
      difficulty = Config.PipelineDifficulty,
      screen = Config.PipelineScreen,
      autoplay = Config.PipelineAutoplay
    }
  })

  return true
end

local function next_screen()
  if normalize(Config.PipelineScreen) == "gameplay" then return "ScreenGameplay" end
  return "ScreenSelectMusic"
end

local ran = false
local function run_bootstrap(self)
  if ran then return end
  ran = true

    local ok, prepared = pcall(prepare_gameplay)
    if not ok then
      emit_error(prepared, "ScreenPolyhydraPipeline.OnCommand")
      prepared = false
    end

    if SCREENMAN and SCREENMAN.SetNewScreen and prepared then
      SCREENMAN:SetNewScreen(next_screen())
    end
end

run_bootstrap()

return Def.Actor{
  InitCommand = run_bootstrap,
  OnCommand = run_bootstrap
}
