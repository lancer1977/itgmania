--[[
  Minimal JSON encoder for StepMania Lua (no external deps).
  Handles strings, numbers, booleans, nil, and tables of same.
  Used to build event envelope and payload for GameServerInterop.
]]

local Polyhydra_SM_Json = {}

local function escape(s)
  if type(s) ~= "string" then return tostring(s) end
  return (s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t"))
end

local function encode_value(v)
  local t = type(v)
  if t == "nil" then return "null" end
  if t == "boolean" then return v and "true" or "false" end
  if t == "number" then return tostring(v) end
  if t == "string" then return '"' .. escape(v) .. '"' end
  if t == "table" then
    local is_array = false
    local i = 0
    for k, _ in pairs(v) do
      if type(k) ~= "number" or k ~= i + 1 then break end
      i = i + 1
    end
    is_array = (i > 0 and i == #v)

    if is_array then
      local parts = {}
      for _, val in ipairs(v) do parts[#parts + 1] = encode_value(val) end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      for key, val in pairs(v) do
        if type(key) == "string" then
          parts[#parts + 1] = '"' .. escape(key) .. '":' .. encode_value(val)
        end
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  return "null"
end

function Polyhydra_SM_Json.encode(t)
  if type(t) ~= "table" then return encode_value(t) end
  return encode_value(t)
end

_G.Polyhydra_SM_Json = Polyhydra_SM_Json

return Polyhydra_SM_Json
