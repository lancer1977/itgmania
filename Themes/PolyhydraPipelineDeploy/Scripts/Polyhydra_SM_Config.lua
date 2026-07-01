--[[
  Polyhydra StepMania ↔ GameServerInterop config.
  Copy into your theme's Scripts/ folder.
]]

local Polyhydra_SM_Config = {}

-- Master toggle: set to false to disable all event emission.
Polyhydra_SM_Config.Enabled = true

-- Emit per-note judgment events (can be spammy). Default off.
Polyhydra_SM_Config.EmitJudgments = false

-- Throttle judgment events to at most N per second when EmitJudgments is true.
Polyhydra_SM_Config.JudgmentThrottlePerSecond = 30

-- Output directory for JSONL events. Prefer LOCALAPPDATA on Windows.
-- Leave nil to use default: %LOCALAPPDATA%\PolyhydraGames\GameServerInterop\StepMania\events
Polyhydra_SM_Config.OutputDir = "/tmp/itgmania-sidecar-deploy-events"

-- Install hint for source.install in envelope: "portable", "flatpak", "unknown"
Polyhydra_SM_Config.InstallMode = "pipeline"

-- Installed StepMania version hint. Installers and launch pipelines can stamp
-- this when they know the target runtime.
Polyhydra_SM_Config.StepManiaVersion = "ITGmania1.3.0-BETA-git-edb45aec40"

-- Optional capability profile override. Leave nil to infer from StepManiaVersion.
Polyhydra_SM_Config.CapabilityProfile = "itgmania-pipeline"

-- Optional pipeline launch hints for theme-driven launch adapters.
-- PipelineSong should use StepMania's FindSong shape: "Group/Song" or "Song".
Polyhydra_SM_Config.PipelineSong = nil
Polyhydra_SM_Config.PipelineSongDir = "StepMania 5/Goin' Under"
Polyhydra_SM_Config.PipelineDifficulty = "challenge"
Polyhydra_SM_Config.PipelineScreen = "gameplay"
Polyhydra_SM_Config.PipelineAutoplay = true

_G.Polyhydra_SM_Config = Polyhydra_SM_Config

return Polyhydra_SM_Config
