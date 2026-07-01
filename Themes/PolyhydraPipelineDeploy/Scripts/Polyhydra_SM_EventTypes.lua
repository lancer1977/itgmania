--[[
  StepMania event type names emitted by the Lua sidecar.
  Keep these string values aligned with GameServerInterop StepManiaEventTypeNames.
]]

local Polyhydra_SM_EventTypes = {
  SessionStart = "session_start",
  SongStart = "song_start",
  Judgment = "judgment",
  ComboMilestone = "combo_milestone",
  SongEnd = "song_end",
  StageResult = "stage_result",
  Error = "error"
}

_G.Polyhydra_SM_EventTypes = Polyhydra_SM_EventTypes

return Polyhydra_SM_EventTypes
