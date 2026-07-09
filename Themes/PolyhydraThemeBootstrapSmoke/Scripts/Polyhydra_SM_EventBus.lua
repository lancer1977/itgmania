--[[
  Polyhydra StepMania event bus: appends newline-delimited JSON to a
  daily JSONL file for GameServerInterop to tail.
  Requires: Polyhydra_SM_Config, Polyhydra_SM_Json (in Scripts/).
]]

local Config = nil
local Json = nil
local Capabilities = nil

-- Lazy load to avoid load order issues
local function get_config()
  if not Config then
    Config = _G.Polyhydra_SM_Config or (require and require("Polyhydra_SM_Config"))
  end
  return Config
end

local function get_json()
  if not Json then
    Json = _G.Polyhydra_SM_Json or (require and require("Polyhydra_SM_Json"))
  end
  return Json
end

local function get_capabilities()
  if not Capabilities then
    Capabilities = _G.Polyhydra_SM_Capabilities or (require and require("Polyhydra_SM_Capabilities"))
  end
  return Capabilities
end

local EventBus = {}
EventBus._initialized = false
EventBus._sessionId = nil
EventBus._outputDir = nil
EventBus._eventsFile = nil
EventBus._errorsFile = nil
EventBus.LastError = nil

local function set_error(operation, path, message, eventType)
  EventBus.LastError = {
    operation = operation,
    path = path,
    message = message,
    eventType = eventType
  }
end

local function clear_error()
  EventBus.LastError = nil
end

local function format_error(errorInfo)
  if not errorInfo then return nil end
  return string.format(
    "operation=%s path=%s eventType=%s message=%s",
    tostring(errorInfo.operation or ""),
    tostring(errorInfo.path or ""),
    tostring(errorInfo.eventType or ""),
    tostring(errorInfo.message or ""))
end

function EventBus.ToIsoUtc()
  local t = os.date("!*t")
  return string.format("%04d-%02d-%02dT%02d:%02d:%02d.000Z",
    t.year, t.month, t.day, t.hour, t.min, t.sec)
end

local function command_succeeded(...)
  local first, _, third = ...
  if first == true then return true end
  if first == 0 then return true end
  if third == 0 then return true end
  return false
end

local function quote_arg(value)
  return '"' .. tostring(value):gsub('"', '\\"') .. '"'
end

local function can_write_existing_dir(path)
  if not io or not io.open then return false end
  local testPath = path:gsub("\\", "/") .. "/.polyhydra-write-test"
  local f = io.open(testPath, "a")
  if not f then return false end
  f:write("")
  f:close()
  if os and os.remove then os.remove(testPath) end
  return true
end

function EventBus.EnsureDir(path)
  if not path or path == "" then
    set_error("ensure_dir", path, "empty path")
    return false
  end

  if can_write_existing_dir(path) then return true end

  local ok, created = pcall(function()
    if not os or not os.execute then return false, "os.execute unavailable" end

    local command
    if path:match("^%a:[/\\]") or path:find("\\", 1, true) then
      local normalized = path:gsub("/", "\\")
      command = "if not exist " .. quote_arg(normalized) .. " mkdir " .. quote_arg(normalized) .. " 2>nul"
    else
      command = "mkdir -p " .. quote_arg(path) .. " 2>/dev/null"
    end

    return command_succeeded(os.execute(command))
  end)

  if ok and created == true then return true end
  if can_write_existing_dir(path) then return true end

  local message = ok and "mkdir command failed" or tostring(created)
  set_error("ensure_dir", path, message)
  return false
end

function EventBus.AppendLine(filePath, text)
  if not filePath or not text then
    set_error("append_line", filePath, "missing file path or text")
    return false
  end
  local ok, wrote = pcall(function()
    local f, err = io.open(filePath, "a")
    if not f then return false, err end

    local writeOk = f:write(text)
    if writeOk and not text:match("\n$") then
      writeOk = f:write("\n")
    end

    local closeOk = f:close()
    return writeOk ~= nil and closeOk ~= nil
  end)

  if ok and wrote == true then return true end

  local message = ok and "write failed" or tostring(wrote)
  set_error("append_line", filePath, message)
  return false
end

function EventBus.WriteFile(filePath, text)
  if not filePath or not text then
    set_error("write_file", filePath, "missing file path or text")
    return false
  end

  local ok, wrote = pcall(function()
    local f, err = io.open(filePath, "w")
    if not f then return false, err end

    local writeOk = f:write(text)
    if writeOk and not text:match("\n$") then
      writeOk = f:write("\n")
    end

    local closeOk = f:close()
    return writeOk ~= nil and closeOk ~= nil
  end)

  if ok and wrote == true then return true end

  local message = ok and "write failed" or tostring(wrote)
  set_error("write_file", filePath, message)
  return false
end

local function default_output_dir()
  local env = os.getenv
  if not env then return nil end
  local base, sep
  if env("LOCALAPPDATA") then
    base = env("LOCALAPPDATA")
    sep = "\\"
  elseif env("XDG_DATA_HOME") then
    base = env("XDG_DATA_HOME")
    sep = "/"
  elseif env("HOME") then
    base = env("HOME") .. "/.local/share"
    sep = "/"
  else
    base = "."
    sep = "/"
  end
  return base .. sep .. "PolyhydraGames" .. sep .. "GameServerInterop" .. sep .. "StepMania" .. sep .. "events"
end

local function ensure_output_dir()
  local cfg = get_config()
  local dir = cfg.OutputDir or default_output_dir()
  if not dir then return nil end
  dir = dir:gsub("\\", "/")
  if not EventBus.EnsureDir(dir) then return nil end
  clear_error()
  EventBus._outputDir = dir
  return dir
end

local function session_id()
  if EventBus._sessionId then return EventBus._sessionId end
  math.randomseed(os.time())
  local hex = "0123456789abcdef"
  local s = {}
  for i = 1, 32 do
    local index = math.random(1, 16)
    s[i] = hex:sub(index, index)
  end
  EventBus._sessionId = table.concat(s)
  return EventBus._sessionId
end

local function events_file_path()
  if not EventBus._outputDir then return nil end
  local date = os.date("%Y%m%d")
  return EventBus._outputDir .. "/events-" .. date .. ".jsonl"
end

local function errors_file_path()
  if not EventBus._outputDir then return nil end
  local date = os.date("%Y%m%d")
  return EventBus._outputDir .. "/errors-" .. date .. ".log"
end

local function state_file_path()
  if not EventBus._outputDir then return nil end
  return EventBus._outputDir .. "/state.json"
end

local function build_state(envelope)
  local payload = envelope.payload or {}
  local state = {
    schemaVersion = envelope.schemaVersion,
    game = envelope.game,
    sessionId = envelope.sessionId,
    lastEventType = envelope.eventType,
    lastEventUtc = envelope.sentAtUtc,
    source = envelope.source
  }

  if payload.song then
    state.currentSong = payload.song
  end
  if payload.chart then
    state.currentChart = payload.chart
  end
  if payload.result then
    state.lastResult = payload.result
  end

  return state
end

function EventBus.Init()
  if EventBus._initialized then return true end
  local cfg = get_config()
  if not cfg or not cfg.Enabled then
    set_error("init", nil, "event bus disabled")
    return false
  end
  if not ensure_output_dir() then return false end
  EventBus._initialized = true
  return true
end

function EventBus.Emit(eventType, payload)
  local cfg = get_config()
  if not cfg or not cfg.Enabled then
    set_error("emit", nil, "event bus disabled", eventType)
    return false
  end
  if not EventBus._initialized then
    if not EventBus.Init() then return false end
  end

  local machine = (os.getenv and os.getenv("COMPUTERNAME")) or (os.getenv and os.getenv("HOSTNAME")) or "unknown"
  local theme = "unknown"
  if THEME then
    if type(THEME) == "table" and THEME.GetThemeName and THEME.GetThemeName() then
      theme = THEME.GetThemeName()
    elseif type(THEME) == "string" then theme = THEME end
  end

  local envelope = {
    schemaVersion = 1,
    eventType = eventType,
    sentAtUtc = EventBus.ToIsoUtc(),
    sessionId = session_id(),
    game = "stepmania",
    source = {
      machine = tostring(machine),
      install = cfg.InstallMode or "unknown",
      theme = theme,
      player = "P1",
      sidecarVersion = get_capabilities().SidecarVersion,
      stepmaniaVersion = cfg.StepManiaVersion or "unknown",
      capabilities = get_capabilities().Summary()
    },
    payload = payload or {}
  }

  local line = get_json().encode(envelope)
  local path = events_file_path()
  if not path then
    set_error("emit", nil, "events file path unavailable", eventType)
    return false
  end

  local ok = EventBus.AppendLine(path, line)
  if not ok then
    if EventBus.LastError then EventBus.LastError.eventType = eventType end
    local errPath = errors_file_path()
    if errPath then
      local writeError = EventBus.LastError
      EventBus.AppendLine(errPath, EventBus.ToIsoUtc() .. " [Polyhydra] " .. tostring(format_error(writeError)))
      EventBus.LastError = writeError
    end
  else
    clear_error()
    local statePath = state_file_path()
    if statePath then
      local stateOk = EventBus.WriteFile(statePath, get_json().encode(build_state(envelope)))
      if not stateOk and EventBus.LastError then
        EventBus.LastError.eventType = eventType
      end
    end
  end
  return ok
end

_G.Polyhydra_SM_EventBus = EventBus

return EventBus
