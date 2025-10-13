// Applies a tail->tip alpha fade to any previously composited arrow (fill+outline).
// Only alpha is affected; RGB remain unchanged.
extern vec2 tailUV;   // tail point in texture UV (0..1)
extern vec2 tipUV;    // tip point in texture UV (0..1)
extern number gamma;  // fade curve power; 1.0 = linear

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 s = Texel(tex, uv) * color;
    vec2 d = tipUV - tailUV;
    float L2 = max(dot(d, d), 1e-8);
    float t = clamp(dot(uv - tailUV, d) / L2, 0.0, 1.0);
    float g = pow(t, gamma);
    s.a *= g; // fade alpha only: fully transparent at tail, opaque at tip
    return s;
}

