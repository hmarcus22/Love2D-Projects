local M = {}

local code = [[
extern vec2 direction;   // (1,0) for horizontal, (0,1) for vertical
extern float radius;     // blur spread in pixels

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
{
    float r = max(0.0, radius);
    // convert pixel offsets to UV using current render target size
    vec2 texel = direction / love_ScreenSize.xy;
    vec2 off1 = texel * r;
    vec2 off2 = texel * (r * 2.0);
    vec2 off3 = texel * (r * 3.0);

    // 7-tap gaussian-ish kernel (normalized)
    vec4 c = Texel(tex, tc) * 0.40;
    c += Texel(tex, tc + off1) * 0.24;
    c += Texel(tex, tc - off1) * 0.24;
    c += Texel(tex, tc + off2) * 0.06;
    c += Texel(tex, tc - off2) * 0.06;
    c += Texel(tex, tc + off3) * 0.02;
    c += Texel(tex, tc - off3) * 0.02;
    return c * color;
}
]]

local shader
function M.get()
    if not shader then
        shader = love.graphics.newShader(code)
    end
    return shader
end

return M

