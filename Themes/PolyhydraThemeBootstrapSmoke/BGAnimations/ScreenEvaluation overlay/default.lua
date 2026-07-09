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
  local tier = s:match("tier(%d+)")
  if tier then return "tier" .. tier end
  if s:match("tier01") or s:match("aaa") then return "tier01" end
  if s:match("tier02") or s:match("aa") then return "tier02" end
  if s:match("tier03") or s:match("a") then return "tier03" end
  if s:match("tier04") or s:match("b") then return "tier04" end
  if s:match("tier05") or s:match("c") then return "tier05" end
  if s:match("tier06") or s:match("d") then return "tier06" end
  if s:match("tier07") or s:match("e") or s:match("f") then return "tier07" end
  return "none"
end

local function call_number(target, method, ...)
  if not target or not target[method] then return nil end
  local ok, value = pcall(target[method], target, ...)
  if not ok then return nil end
  return tonumber(value)
end

local function call_value(target, method, ...)
  if not target or not target[method] then return nil end
  local ok, value = pcall(target[method], target, ...)
  if not ok then return nil end
  return value
end

local function call_bool(target, method)
  if not target or not target[method] then return nil end
  local ok, value = pcall(target[method], target)
  if not ok then return nil end
  return value == true
end

local function call_grade(target, method)
  if not target or not target[method] then return nil end
  local ok, value = pcall(target[method], target)
  if not ok then return nil end
  return value
end

local function call_string(target, method, ...)
  if not target or not target[method] then return nil end
  local ok, value = pcall(target[method], target, ...)
  if not ok or value == nil then return nil end
  return tostring(value)
end

local function get_player_payload(player)
  local slot = tostring(player or "PLAYER_1")
  local name = nil
  local guid = nil

  if PROFILEMAN then
    name = call_string(PROFILEMAN, "GetPlayerName", player)
    local profile = nil
    if PROFILEMAN.GetProfile then
      local ok, value = pcall(PROFILEMAN.GetProfile, PROFILEMAN, player)
      if ok then profile = value end
    end
    guid = call_string(profile, "GetPlayerGuid")
  end

  return {
    slot = slot,
    name = name or slot,
    guid = guid or slot
  }
end

local function build_judgments(pss, highScore)
  local scoreSource = highScore or pss
  local scoreTable = call_value(pss, "GetTapNoteScores")
  local function score_from_table(...)
    if type(scoreTable) ~= "table" then return nil end
    for _, key in ipairs({...}) do
      local value = tonumber(scoreTable[key])
      if value then return value end
    end
    return nil
  end

  return {
    w1 = call_number(scoreSource, "GetTapNoteScore", "TapNoteScore_W1") or call_number(pss, "GetTapNoteScores", "TapNoteScore_W1") or score_from_table("TapNoteScore_W1", "TNS_W1", "W1", "w1") or 0,
    w2 = call_number(scoreSource, "GetTapNoteScore", "TapNoteScore_W2") or call_number(pss, "GetTapNoteScores", "TapNoteScore_W2") or score_from_table("TapNoteScore_W2", "TNS_W2", "W2", "w2") or 0,
    w3 = call_number(scoreSource, "GetTapNoteScore", "TapNoteScore_W3") or call_number(pss, "GetTapNoteScores", "TapNoteScore_W3") or score_from_table("TapNoteScore_W3", "TNS_W3", "W3", "w3") or 0,
    w4 = call_number(scoreSource, "GetTapNoteScore", "TapNoteScore_W4") or call_number(pss, "GetTapNoteScores", "TapNoteScore_W4") or score_from_table("TapNoteScore_W4", "TNS_W4", "W4", "w4") or 0,
    w5 = call_number(scoreSource, "GetTapNoteScore", "TapNoteScore_W5") or call_number(pss, "GetTapNoteScores", "TapNoteScore_W5") or score_from_table("TapNoteScore_W5", "TNS_W5", "W5", "w5") or 0,
    miss = call_number(scoreSource, "GetTapNoteScore", "TapNoteScore_Miss") or call_number(pss, "GetTapNoteScores", "TapNoteScore_Miss") or score_from_table("TapNoteScore_Miss", "TNS_Miss", "Miss", "miss") or 0
  }
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

  local title, artist, group, songHash = "", "", "", ""
  if song then
    if song.GetDisplayMainTitle then title = song:GetDisplayMainTitle() or "" end
    if song.GetDisplayArtist then artist = song:GetDisplayArtist() or "" end
    if song.GetGroupName then group = song:GetGroupName() or "" end
    if song.GetSongDir then songHash = song:GetSongDir() or "" end
  end

  local stepsType, difficulty, meter, chartHash = "unknown", "unknown", 0, ""
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
    if steps.GetHash then chartHash = tostring(steps:GetHash() or "") end
  end

  local gradeStr = "none"
  local scoreVal = 0
  local maxCombo = 0
  local judgments = { w1 = 0, w2 = 0, w3 = 0, w4 = 0, w5 = 0, miss = 0 }
  local failed = false

  if pss then
    local highScore = nil
    if pss.GetHighScore then
      local ok, value = pcall(pss.GetHighScore, pss)
      if ok then highScore = value end
    end

    gradeStr = grade_to_tier(call_grade(highScore, "GetGrade") or call_grade(pss, "GetGrade"))
    scoreVal = call_number(highScore, "GetScore") or call_number(pss, "GetScore") or 0
    maxCombo = call_number(highScore, "GetMaxCombo") or call_number(pss, "GetMaxCombo") or call_number(pss, "MaxCombo") or 0
    judgments = build_judgments(pss, highScore)
    failed = call_bool(pss, "GetFailed") or false
  end

  return {
    player = get_player_payload(player),
    song = { title = title, artist = artist, group = group, hash = songHash },
    chart = { stepsType = stepsType, difficulty = difficulty, meter = meter, hash = chartHash },
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
