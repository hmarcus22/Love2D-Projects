-- Minimal HUMP-style class utility (init-based)
local function includeHelper(to, from)
  if type(from) == 'function' then
    from(to)
  else
    for k, v in pairs(from) do to[k] = v end
  end
end

local Object = {}
Object.__index = Object

function Object:init() end

function Object:extend()
  local cls = {}
  for k, v in pairs(self) do
    if k:match('^__') then cls[k] = v end
  end
  cls.__index = cls
  setmetatable(cls, self)
  return cls
end

function Object:implement(...)
  for _, other in ipairs({...}) do includeHelper(self, other) end
end

function Object:is(klass)
  local mt = getmetatable(self)
  while mt do
    if mt == klass then return true end
    mt = getmetatable(mt)
  end
  return false
end

function Object:__call(...)
  local obj = setmetatable({}, self)
  if obj.init then obj:init(...) end
  return obj
end

setmetatable(Object, { __call = Object.__call })

return Object

