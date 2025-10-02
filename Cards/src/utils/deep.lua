local Deep = {}

local function is_array(t)
  if type(t) ~= 'table' then return false end
  local count = 0
  for k, _ in pairs(t) do
    if type(k) ~= 'number' then return false end
    count = count + 1
  end
  for i = 1, count do
    if t[i] == nil then return false end
  end
  return true
end

function Deep.clone(v)
  if type(v) ~= 'table' then return v end
  local out = {}
  for k, tv in pairs(v) do
    out[k] = Deep.clone(tv)
  end
  return out
end

function Deep.merge(dst, src)
  if type(src) ~= 'table' then return dst end
  for k, v in pairs(src) do
    if type(v) == 'table' and type(dst[k]) == 'table' then
      Deep.merge(dst[k], v)
    else
      dst[k] = Deep.clone(v)
    end
  end
  return dst
end

local function split_path(path)
  local parts = {}
  for token in string.gmatch(path or '', "[^%.]+") do
    table.insert(parts, token)
  end
  return parts
end

function Deep.get_by_path(tbl, path)
  if type(tbl) ~= 'table' or type(path) ~= 'string' then return nil end
  local node = tbl
  for _, key in ipairs(split_path(path)) do
    if type(node) ~= 'table' then return nil end
    node = node[key]
  end
  return node
end

function Deep.set_by_path(tbl, path, value)
  if type(tbl) ~= 'table' or type(path) ~= 'string' then return false end
  local node = tbl
  local parts = split_path(path)
  for i = 1, #parts - 1 do
    local key = parts[i]
    if type(node[key]) ~= 'table' then node[key] = {} end
    node = node[key]
  end
  node[parts[#parts]] = value
  return true
end

local function shallow_copy_keys(t)
  local r = {}
  for k, _ in pairs(t or {}) do r[k] = true end
  return r
end

local function tables_equal(a, b)
  if a == b then return true end
  if type(a) ~= 'table' or type(b) ~= 'table' then return false end
  local seen = {}
  for k, v in pairs(a) do
    if not tables_equal(v, b[k]) then return false end
    seen[k] = true
  end
  for k, v in pairs(b) do
    if not seen[k] and not tables_equal(v, a[k]) then return false end
  end
  return true
end

-- Build a minimal diff: values in 'current' that differ from 'defaults'.
-- If 'allowedTop' is provided (set of top-level keys), skip others.
function Deep.diff(current, defaults, allowedTop)
  local function diff_rec(c, d, depth)
    if type(c) ~= 'table' or type(d) ~= 'table' then
      if not tables_equal(c, d) then return Deep.clone(c) end
      return nil
    end
    if is_array(c) or is_array(d) then
      if not tables_equal(c, d) then return Deep.clone(c) end
      return nil
    end
    local out = {}
    local keys = shallow_copy_keys(c)
    for k, _ in pairs(d) do keys[k] = true end
    for k, _ in pairs(keys) do
      if depth == 0 and allowedTop and not allowedTop[k] then
        -- skip non-persisted top-level keys
      else
        local sub = diff_rec(c[k], d[k], depth + 1)
        if sub ~= nil then out[k] = sub end
      end
    end
    if next(out) == nil then return nil end
    return out
  end
  return diff_rec(current, defaults, 0) or {}
end

return Deep

