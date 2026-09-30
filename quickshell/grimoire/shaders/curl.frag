#version 440
// Turning a leaf of the codex: the right-hand page (the source) curls up from its bottom corner round
// a cylinder whose fold sweeps to the spine and lies down on the left. Its back is plain paper
// (versoSource) that becomes the left-hand page (backSource) as the last leaf settles. Drawn over the whole spread
// (the spine is at pageW). The page underneath gets the curl's shadow. Premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // the spread, px
    float pageW;        // one page, px
    float fold;         // where the fold is, px from the spine (pageW: flat .. 0: over)
    float radius;       // the curl's radius, px
    float tilt;         // how far the bottom leads the top (px of fold per px of height)
    float backMix;      // 0: the leaf's back is its own verso, 1: it is the left page (as it lands)
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D backSource;
layout(binding = 3) uniform sampler2D versoSource;

const float PI = 3.14159265;

vec4 front(float u, float y) { return texture(source, vec2(u / pageW, y / size.y)); }
vec4 back(float u, float y, float shade) {
    // the leaf's other side: plain paper with its front's ink faintly showing through, becoming the
    // left page itself as the last leaf settles there (so it lands without a jump)
    vec2 at = vec2((pageW - u) / pageW, y / size.y);
    vec4 f = texture(source, vec2(u / pageW, y / size.y));
    float ink = 1.0 - dot(f.rgb / max(f.a, 0.001), vec3(0.3, 0.59, 0.11));
    vec4 v = texture(versoSource, at);
    v.rgb *= 1.0 - smoothstep(0.35, 0.8, ink) * 0.08;
    vec4 t = mix(v, texture(backSource, at), backMix);
    return vec4(t.rgb * shade, t.a);
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    float x = px.x - pageW;
    float y = px.y;
    float f = fold + tilt * (size.y - y);
    float R = max(radius, 0.5);

    vec4 col = vec4(0.0);
    if (x < f) {
        float u = f + PI * R + (f - x);            // lying back over, flat, on top
        if (u <= pageW && u >= 0.0) col = back(u, y, 1.0 - 0.1 * exp(-(f - x) / 40.0) * smoothstep(0.0, 40.0, f));
        else if (x >= 0.0) {
            col = front(x, y);
            col.rgb *= 1.0 - 0.18 * exp(-(f - x) / 18.0);   // the curl's shadow on the leaf itself
        }
    } else if (x <= f + R) {
        float t1 = asin(clamp((x - f) / R, -1.0, 1.0));
        float t2 = PI - t1;
        float u2 = f + R * t2;
        float u1 = f + R * t1;
        if (u2 <= pageW) col = back(u2, y, 0.78 + 0.22 * sin(t2));
        else if (u1 <= pageW) {
            col = front(u1, y);
            col.rgb *= 1.0 - 0.35 * (1.0 - cos(t1));
        }
    }
    // the curl's shadow on the page underneath
    if (col.a < 0.99 && x > f && x >= 0.0) {
        float d = x - (f + R * 0.6);
        float s = 0.3 * exp(-max(d, 0.0) / 28.0) * smoothstep(0.0, 40.0, f);
        col = col + vec4(0.0, 0.0, 0.0, s) * (1.0 - col.a);
    }
    fragColor = col * qt_Opacity;
}
