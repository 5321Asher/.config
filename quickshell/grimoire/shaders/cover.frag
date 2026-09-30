#version 440
// A book's cover (or a strap, or a brass plate), lit: pebbled leather over boards whose edges round
// off, worn paler where hands have rubbed them; gilt tooling (the mask's red) pressed into it and
// catching the light; blind tooling (the mask's green) pressed in without gold. A point light (the
// candle) and a little ambient; the leather has a soft sheen, the gold a sharp one. With metal = 1
// the whole surface is brass. Premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;           // px
    vec4 base;           // the leather's dye (or the metal)
    vec4 gold;
    vec4 goldBright;
    vec4 goldDeep;
    vec4 lightColor;
    vec3 lightPos;       // px, in the item's coordinates; z = height above the cover
    float lightPower;    // 0 .. ~2
    float ambient;       // 0 .. 1
    float radius;        // corner radius, px
    float bevel;         // how wide the rounded edge is, px
    float seed;
    float wear;          // 0 .. 1
    float metal;         // 0: leather, 1: brass
};
layout(binding = 1) uniform sampler2D mask;

#include "noise.glsl"

vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}
float cells(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    float d1 = 8.0, d2 = 8.0;
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++) {
            vec2 o = vec2(float(x), float(y));
            vec2 c = o + 0.15 + 0.7 * hash2(i + o);
            float d = length(c - f);
            if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) d2 = d;
        }
    return smoothstep(0.0, 0.14, d2 - d1) * (1.0 - smoothstep(0.0, 0.8, d1) * 0.4);
}
float roundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
// the surface's height at px: the board's rounded edge, the grain, the tooling pressed in
vec2 tool(vec2 px) { return texture(mask, px / size).rg; }
float height(vec2 px, vec2 s) {
    float sd = roundBox(px - size * 0.5, size * 0.5, radius);
    float edge = sqrt(clamp(-sd / max(bevel, 0.5), 0.0, 1.0));
    float grain = metal > 0.5 ? noise(px * 0.35 + s) * 0.05 : cells(px / 4.2 + s) * 0.35;
    vec2 t = tool(px);
    return edge * 6.0 + grain - (t.r + t.g) * 1.6;
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec2 s = vec2(seed * 13.0, seed * 7.0);

    float sd = roundBox(px - size * 0.5, size * 0.5, radius);
    float alpha = 1.0 - smoothstep(-0.8, 0.4, sd);
    if (alpha <= 0.0) { fragColor = vec4(0.0); return; }

    // the normal, from the height field
    float e = 1.2;
    float hx = height(px + vec2(e, 0.0), s) - height(px - vec2(e, 0.0), s);
    float hy = height(px + vec2(0.0, e), s) - height(px - vec2(0.0, e), s);
    vec3 n = normalize(vec3(-hx, -hy, 2.0 * e));

    vec2 t = tool(px);
    float gilt = t.r;

    // colour: dyed leather, mottled, rubbed paler at the edges and corners
    vec3 leather = base.rgb * (1.0 + (fbm(px / 180.0 + s) - 0.5) * 0.18);
    float rub = (1.0 - smoothstep(0.0, 14.0, -sd)) * (0.5 + fbm(px / 9.0 + s * 2.0));
    leather = mix(leather, leather * 1.35 + 0.02, clamp(rub * wear * 0.5, 0.0, 1.0));
    leather *= 1.0 - (fbm(px / 40.0 + s * 4.0) - 0.5) * 0.12 * wear;          // scuffs
    vec3 metalCol = mix(goldDeep.rgb, gold.rgb, 0.62 + (fbm(px / 30.0 + s) - 0.5) * 0.3 + (noise(px * vec2(1.3, 0.25) + s) - 0.5) * 0.06);
    // gilt worn thin in places, the leather showing through
    float giltWear = smoothstep(0.35, 0.75, fbm(px / 14.0 + s * 5.0)) * wear * 0.45;
    vec3 albedo = metal > 0.5 ? metalCol : mix(leather, metalCol, gilt * (1.0 - giltWear));
    float shiny = max(metal, gilt * (1.0 - giltWear));

    // the light
    vec3 P = vec3(px, 0.0);
    vec3 L = lightPos - P;
    float dist = length(L);
    L /= dist;
    float fall = lightPower / (1.0 + pow(dist / max(size.x, size.y), 2.0) * 1.5);
    float diff = max(dot(n, L), 0.0);
    vec3 V = vec3(0.0, 0.0, 1.0);
    vec3 H = normalize(L + V);
    float specL = pow(max(dot(n, H), 0.0), 18.0) * 0.12;            // leather's soft sheen
    float specG = pow(max(dot(n, H), 0.0), 60.0) * 1.6;             // gold's sharp one
    // a broad sky/room light from above too, so gold reads even away from the candle
    float top = max(dot(n, normalize(vec3(0.0, -0.6, 1.0))), 0.0);

    vec3 lit = albedo * (ambient * (0.6 + 0.4 * top) + diff * fall * lightColor.rgb);
    lit += mix(specL, specG, shiny) * fall * mix(lightColor.rgb, goldBright.rgb, shiny);
    lit += shiny * goldBright.rgb * pow(top, 30.0) * 0.12 * ambient;
    // tooling's walls in shadow
    lit *= 1.0 - (t.g * 0.4);

    fragColor = vec4(lit * alpha, alpha) * qt_Opacity;
}
