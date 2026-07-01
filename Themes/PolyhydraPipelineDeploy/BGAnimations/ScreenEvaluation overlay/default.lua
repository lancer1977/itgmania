--[[
  Polyhydra GameServerInterop: emit stage_result when evaluation is shown.
  Place in Themes/YourTheme/BGAnimations/ScreenEvaluation overlay/
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
      EventBus.Emit(types.Error, { message = tostring(err), context = "ScreenEvaluation overlay" })
    end
  end
  return ok
end

local function grade_to_tier(grade)
  if grade == nil then return "none" end
  local s = tostring(grade):lower()
  if s:match("tier01") or s:match("aaa") then return "tier01" end
  if s:match("tier02") or s:match("aa") then return "tier02" end
  if s:match("tier03") or s:match("a") then return "tier03" end
  if s:match("tier04") or s:match("b") then return "tier04" end
  if s:match("tier05") or s:match("c") then return "tier05" end
  if s:match("tier06") or s:match("d") then return "tier06" end
  if s:match("tier07") or s:match("e") or s:match("f") then return "tier07" end
  return "none"
end

local function get_stage_result_payload()
  local song = (GAMESTATE and GAMESTATE.GetCurrentSong and GAMESTATE:GetCurrentSong()) or nil
  local player = PLAYER_1
  local steps = (GAMESTATE and GAMESTATE.GetCurrentSteps and player and GAMESTATE:GetCurrentSteps(player)) or nil
  local stageStats = (STATSMAN and STATSMAN.GetCurStageStats and STATSMAN:GetCurStageStats()) or nil
  local pss = nil
  if stageStats and stageStats.GetPlayerStageStats then
    pss = player and stageStats:GetPlayerStageStats(player) or nil
  end

  local title, artist, group = "", "", ""
  if song then
    if song.GetDisplayMainTitle then title = song:GetDisplayMainTitle() or "" end
    if song.GetDisplayArtist then artist = song:GetDisplayArtist() or "" end
    if song.GetGroupName then group = song:GetGroupName() or "" end
  end

  local stepsType, difficulty, meter = "unknown", "unknown", 0
  if steps then
    if steps.GetStepsType then
      local st = steps:GetStepsType()
      if type(st) == "string" then
        stepsType = st:gsub("StepsType_", ""):gsub("_", "-"):lower()
      end
    end
    if steps.GetDifficulty then
      local d = steps:GetDifficulty()
      if type(d) == "string" then difficulty = d:gsub("Difficulty_", ""):lower() end
    end
    if steps.GetMeter then meter = steps:GetMeter() or 0 end
  end

  local gradeStr = "none"
  local scoreVal = 0
  local maxCombo = 0
  local judgments = { w1 = 0, w2 = 0, w3 = 0, w4 = 0, w5 = 0, miss = 0 }
  local failed = false

  if pss then
    if pss.GetGrade then gradeStr = grade_to_tier(pss:GetGrade()) end
    if pss.GetScore then scoreVal = pss:GetScore() or 0 end
    if pss.GetMaxCombo then maxCombo = pss:GetMaxCombo() or 0 end
    if pss.GetTapNoteScores then
      local tns = pss:GetTapNoteScores()
      if type(tns) == "table" then
        local map = { W1 = "w1", w1 = "w1", W2 = "w2", w2 = "w2", W3 = "w3", w3 = "w3", W4 = "w4", w4 = "w4", W5 = "w5", w5 = "w5", Miss = "miss", miss = "miss" }
        for k, v in pairs(tns) do
          local key = map[tostring(k):gsub("TNS_", "")] or tostring(k):lower():gsub("tns_", "")
          if judgments[key] ~= nil then judgments[key] = tonumber(v) or 0
          elseif key == "miss" then judgments.miss = tonumber(v) or 0 end
        end
      end
    end
    if pss.GetFailed then failed = pss:GetFailed() or false end
  end

  return {
    song = { title = title, artist = artist, group = group },
    chart = { stepsType = stepsType, difficulty = difficulty, meter = meter },
    result = {
      grade = gradeStr,
      score = scoreVal,
      maxCombo = maxCombo,
      judgments = judgments,
      failed = failed
    }
  }
end

local function emit_stage_result()
  if not EventBus or not EventBus.Emit then return end
  if not EventBus.Init() then return end
  local payload = get_stage_result_payload()
  local types = get_event_types()
  EventBus.Emit(types.StageResult, payload)
end

local emitted = false

local function run_stage_result()
  safe(function()
    ensure_sidecar_loaded()
    if not EventBus then EventBus = _G.Polyhydra_SM_EventBus or (require and require("Polyhydra_SM_EventBus")) end
    if not EventTypes then EventTypes = get_event_types() end
    if not emitted then
      emit_stage_result()
      emitted = true
    end
  end)
end

run_stage_result()

return Def.Actor{
  InitCommand = run_stage_result,
  OnCommand = run_stage_result
}
