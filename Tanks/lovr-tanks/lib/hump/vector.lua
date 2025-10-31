-- Minimal 2D vector (HUMP-like)
local vector = {}
vector.__index = vector

setmetatable(vector, {
  __call = function(_, x, y)
    return setmetatable({ x = x or 0, y = y or 0 }, vector)
  end
})

function vector:clone() return vector(self.x, self.y) end
function vector:unpack() return self.x, self.y end
function vector:len() return math.sqrt(self.x * self.x + self.y * self.y) end
function vector:normalize()
  local l = self:len()
  if l > 0 then self.x, self.y = self.x / l, self.y / l end
  return self
end
function vector:normalized() return self:clone():normalize() end
function vector:dot(v) return self.x * v.x + self.y * v.y end
function vector:angle() return math.atan2(self.y, self.x) end
function vector:rotated(a)
  local c, s = math.cos(a), math.sin(a)
  return vector(self.x * c - self.y * s, self.x * s + self.y * c)
end
function vector:add(vx, vy)
  if type(vx) == 'table' then self.x, self.y = self.x + vx.x, self.y + vx.y
  else self.x, self.y = self.x + vx, self.y + vy end
  return self
end
function vector:sub(vx, vy)
  if type(vx) == 'table' then self.x, self.y = self.x - vx.x, self.y - vx.y
  else self.x, self.y = self.x - vx, self.y - vy end
  return self
end
function vector:mul(s)
  self.x, self.y = self.x * s, self.y * s
  return self
end

vector.__add = function(a, b) return vector(a.x + b.x, a.y + b.y) end
vector.__sub = function(a, b) return vector(a.x - b.x, a.y - b.y) end
vector.__mul = function(a, b)
  if type(a) == 'number' then return vector(a * b.x, a * b.y) end
  if type(b) == 'number' then return vector(a.x * b, a.y * b) end
end
vector.__tostring = function(v) return string.format('(%0.3f,%0.3f)', v.x, v.y) end

return vector

