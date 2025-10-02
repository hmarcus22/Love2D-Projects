local Serialize = {}

local function is_array(t)
  if type(t) ~= 'table' then return false end
  local n = 0
  for k, _ in pairs(t) do
    if type(k) ~= 'number' then return false end
    n = n + 1
  end
  for i = 1, n do
    if t[i] == nil then return false end
  end
  return true
end

local function escape_str(s)
  s = s:gsub("\\", "\\\\")
  s = s:gsub("\"", "\\\"")
  s = s:gsub("\n", "\\n")
  s = s:gsub("\r", "\\r")
  s = s:gsub("\t", "\\t")
  return '"' .. s .. '"'
end

local function key_to_str(k)
  if type(k) == 'string' and k:match("^[A-Za-z_][A-Za-z0-9_]*$") then
    return k
  else
    return "[" .. Serialize.to_lua(k) .. "]"
  end
end

function Serialize.to_lua(v, indent)
  indent = indent or 0
  local t = type(v)
  if t == 'number' then
    if v ~= v then return "0/0" end -- NaN safe guard
    return tostring(v)
  elseif t == 'boolean' then
    return v and 'true' or 'false'
  elseif t == 'string' then
    return escape_str(v)
  elseif t == 'table' then
    local pad = string.rep("  ", indent)
    local pad2 = string.rep("  ", indent + 1)
    if next(v) == nil then return "{}" end
    local out = {}
    if is_array(v) then
      table.insert(out, "{")
      for i = 1, #v do
        table.insert(out, pad2 .. Serialize.to_lua(v[i], indent + 1) .. (i < #v and "," or ""))
      end
      table.insert(out, pad .. "}")
      return table.concat(out, "\n")
    else
      -- sort keys for stable output
      local keys = {}
      for k, _ in pairs(v) do table.insert(keys, k) end
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
      table.insert(out, "{")
      for i, k in ipairs(keys) do
        local vs = Serialize.to_lua(v[k], indent + 1)
        local line = pad2 .. key_to_str(k) .. " = " .. vs .. (i < #keys and "," or "")
        table.insert(out, line)
      end
      table.insert(out, pad .. "}")
      return table.concat(out, "\n")
    end
  else
    return 'nil'
  end
end

return Serialize

