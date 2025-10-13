// Expands the alpha mask outward and subtracts the original mask
// to produce an outside-only outline of configurable thickness.
// Expected usage: draw this with the mask texture into a composite canvas.
extern number outlineSize;      // thickness in pixels
extern vec4 outlineColor;
extern vec2 texelSize;          // 1/width, 1/height of the mask texture

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float a = Texel(tex, uv).a;

    // Dilate alpha by sampling neighbors at a radius of outlineSize.
    float r = outlineSize;
    vec2 o[8] = vec2[8](
        vec2( 1.0,  0.0), vec2(-1.0,  0.0),
        vec2( 0.0,  1.0), vec2( 0.0, -1.0),
        vec2( 1.0,  1.0), vec2(-1.0,  1.0),
        vec2( 1.0, -1.0), vec2(-1.0, -1.0)
    );
    float aDilated = a;
    for (int i = 0; i < 8; i++) {
        aDilated = max(aDilated, Texel(tex, uv + o[i] * texelSize * r).a);
    }

    // Outside-only ring: dilated minus original
    float edge = clamp(aDilated - a, 0.0, 1.0);
    return outlineColor * edge;
}

