// FAST TRAVEL's ground: Night City's map. Each block is outlined and faintly tinted in its district's
// colour (c0..c7), streets run dark between with dashed centre lines, the ocean moves to the west with
// the coastline lit along it, and rings pulse out of the plaza where you stand.
// The geography (water(), the district seeds) must stay in step with FastTravel.qml.
// Uniforms: grid (block pitch), block (block size), c0..c7, plazaColor, sea, fogColor, fogNear, fogFar, time
VARYING vec3 vWorld;

bool water(vec2 p)
{
    float coast = -6.8 + 1.2 * sin(p.y * 0.42 + 0.8) + (p.y > 3.0 ? (p.y - 3.0) * 0.25 : 0.0);
    if (p.x < coast) return true;
    if (p.y < -7.4 + 0.9 * sin(p.x * 0.55 + 1.3)) return true;
    return length(p - vec2(-3.2, -7.9)) < 2.4;
}

int districtAt(vec2 c)
{
    if (c.x > 7.0 || c.y > 8.6 || length(c - vec2(0.5, 0.0)) > 9.6) return 7;
    vec2 s[7] = vec2[7](vec2(-3.6, -5.0), vec2(4.6, -4.2), vec2(0.4, -0.6), vec2(-2.6, 3.4),
                        vec2(4.6, 4.2), vec2(-5.0, 7.2), vec2(-1.2, 7.8));
    float w[7] = float[7](1.0, 1.0, 1.3, 1.0, 1.0, 1.1, 1.15);
    int best = 0;
    float bd = 1e9;
    for (int k = 0; k < 7; k++) {
        vec2 d = c - s[k];
        float v = dot(d, d) * w[k];
        if (v < bd) { bd = v; best = k; }
    }
    return best;
}

vec3 colourOf(int k)
{
    if (k == 0) return c0.rgb;
    if (k == 1) return c1.rgb;
    if (k == 2) return c2.rgb;
    if (k == 3) return c3.rgb;
    if (k == 4) return c4.rgb;
    if (k == 5) return c5.rgb;
    if (k == 6) return c6.rgb;
    return c7.rgb;
}

void MAIN()
{
    vec2 p = vWorld.xz / grid;                       // block units; block centres on whole numbers
    vec2 fw = max(fwidth(p), vec2(1e-5));
    vec2 cell = floor(p + 0.5);
    vec2 f = abs(p - cell);                          // 0 at a block's centre, 0.5 mid-street
    float hb = block / grid * 0.5;
    float r = length(vWorld.xz);
    vec3 col;

    bool wet = water(p);
    float e = 0.18;
    bool shore = wet != water(p + vec2(e, 0.0)) || wet != water(p - vec2(e, 0.0))
              || wet != water(p + vec2(0.0, e)) || wet != water(p - vec2(0.0, e));
    if (wet) {
        // the ocean: slow swell lines, darker further out
        float swell = sin(p.x * 3.1 + p.y * 1.3 + time * 0.6) * sin(p.y * 2.3 - time * 0.4);
        float lines = 1.0 - smoothstep(0.0, 0.08, abs(fract(p.x * 1.6 + p.y * 0.4 + time * 0.05) - 0.5) - 0.44);
        col = vec3(0.004, 0.012, 0.024) + sea.rgb * (0.025 + 0.02 * swell + lines * 0.025);
    } else {
        int k = districtAt(cell);
        vec3 dc = colourOf(k);
        bool desert = k == 7;
        float ox = (1.0 - smoothstep(0.0, 1.5, abs(f.x - hb) / fw.x)) * step(f.y, hb);
        float oy = (1.0 - smoothstep(0.0, 1.5, abs(f.y - hb) / fw.y)) * step(f.x, hb);
        float outline = max(ox, oy);
        float inside = step(f.x, hb) * step(f.y, hb);
        vec2 m = min(fract(p + 0.5), 1.0 - fract(p + 0.5));
        float cx = (1.0 - smoothstep(0.0, 1.2, m.x / fw.x)) * step(0.5, fract(p.y * 3.0));
        float cy = (1.0 - smoothstep(0.0, 1.2, m.y / fw.y)) * step(0.5, fract(p.x * 3.0));
        col = desert ? vec3(0.024, 0.018, 0.012) : vec3(0.010, 0.012, 0.016);
        col += dc * inside * (desert ? 0.015 : 0.035);
        col += dc * outline * (desert ? 0.10 : 0.34);
        col += vec3(0.5, 0.6, 0.7) * max(cx, cy) * (desert ? 0.0 : 0.05) * (1.0 - inside);
        // the plaza: rings pulsing out from where you stand
        float plaza = 1.0 - smoothstep(grid * 1.25, grid * 1.55, r);
        float ring = 1.0 - smoothstep(0.0, 0.06, abs(fract(r / 6.0 - time * 0.35) - 0.5));
        col = mix(col, vec3(0.012, 0.012, 0.016), plaza * 0.8);
        col += plazaColor.rgb * (ring * 0.32 + 0.05) * plaza;
    }
    if (shore) col += sea.rgb * 0.55;

    float d = length(vWorld - CAMERA_POSITION);
    col = mix(col, fogColor.rgb, smoothstep(fogNear, fogFar, d));
    FRAGCOLOR = vec4(col, 1.0);
}
