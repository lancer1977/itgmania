--[[
  Versioned Stepmania-Sidecar capability profile.

  Keep this small and explicit: downstream consumers should branch on declared
  capabilities, not infer behavior from event payload accidents.
]]

local Capabilities = {}

Capabilities.SidecarVersion = "0.1.0"

local profiles = {
  ["stepmania-5.x-theme-lua"] = {
    profile = "stepmania-5.x-theme-lua",
    events = { "song_start", "stage_result", "error" },
    features = {
      jsonlEventBus = true,
      latestStateSnapshot = true,
      writeErrorLog = true,
      gameplayOverlayHook = true,
      evaluationOverlayHook = true,
      themeBootstrapLaunch = false,
      baseGamePipelineLaunch = false
    }
  },
  ["itgmania-theme-lua"] = {
    profile = "itgmania-theme-lua",
    events = { "session_start", "song_start", "stage_result", "error" },
    features = {
      jsonlEventBus = true,
      latestStateSnapshot = true,
      writeErrorLog = true,
      gameplayOverlayHook = true,
      evaluationOverlayHook = true,
      themeBootstrapLaunch = true,
      baseGamePipelineLaunch = false
    }
  },
  ["itgmania-pipeline"] = {
    profile = "itgmania-pipeline",
    events = { "session_start", "song_start", "stage_result", "error" },
    features = {
      jsonlEventBus = true,
      latestStateSnapshot = true,
      writeErrorLog = true,
      gameplayOverlayHook = true,
      evaluationOverlayHook = true,
      themeBootstrapLaunch = true,
      baseGamePipelineLaunch = true
    }
  },
  ["stepmania-5.1-pipeline"] = {
    profile = "stepmania-5.1-pipeline",
    events = { "song_start", "stage_result", "error" },
    features = {
      jsonlEventBus = true,
      latestStateSnapshot = true,
      writeErrorLog = true,
      gameplayOverlayHook = true,
      evaluationOverlayHook = true,
      themeBootstrapLaunch = false,
      baseGamePipelineLaunch = true
    }
  }
}

local function normalize_version(version)
  if type(version) ~= "string" then return "" end
  return version:lower()
end

local function get_config()
  if _G.Polyhydra_SM_Config then return _G.Polyhydra_SM_Config end
  if require then return require("Polyhydra_SM_Config") end
  return {}
end

function Capabilities.ResolveProfile()
  local Config = get_config()
  if Config.CapabilityProfile and profiles[Config.CapabilityProfile] then
    return profiles[Config.CapabilityProfile]
  end

  local version = normalize_version(Config.StepManiaVersion)
  if version:match("itgmania") then
    return profiles["itgmania-theme-lua"]
  end
  if version:match("5%.1") then
    return profiles["stepmania-5.1-pipeline"]
  end

  return profiles["stepmania-5.x-theme-lua"]
end

function Capabilities.Summary()
  local Config = get_config()
  local profile = Capabilities.ResolveProfile()
  return {
    sidecarVersion = Capabilities.SidecarVersion,
    stepmaniaVersion = Config.StepManiaVersion or "unknown",
    profile = profile.profile,
    events = profile.events,
    features = profile.features
  }
end

_G.Polyhydra_SM_Capabilities = Capabilities

return Capabilities
