// The hologram's circulatory system (Qt Quick 3D custom material): tubes skinned like the body.
// UV0 is (metres from the heart, the tube's radius); a tube thinner than about a pixel is fattened to
// one (so the fingers' arteries don't shimmer away at a distance) and dimmed to match (vThin).
// Uniforms: pxScale (the world's size of a pixel one metre from the camera)
VARYING vec3 vPos;
VARYING vec3 vWorld;
VARYING vec3 vNormal;
VARYING vec2 vUv;
VARYING float vThin;
void MAIN()
{
    mat4 skin = BONE_TRANSFORMS[int(JOINTS.x)] * WEIGHTS.x + BONE_TRANSFORMS[int(JOINTS.y)] * WEIGHTS.y
              + BONE_TRANSFORMS[int(JOINTS.z)] * WEIGHTS.z + BONE_TRANSFORMS[int(JOINTS.w)] * WEIGHTS.w;
    vec4 p = skin * vec4(VERTEX, 1.0);
    vec3 n = normalize(mat3(skin) * NORMAL);
    float r = UV0.y;
    float least = distance(CAMERA_POSITION, (MODEL_MATRIX * p).xyz) * pxScale * 0.6;
    p.xyz += n * max(0.0, least - r);
    vThin = r / max(r, least);
    vPos = VERTEX;
    vWorld = (MODEL_MATRIX * p).xyz;
    vNormal = normalize(NORMAL_MATRIX * n);
    vUv = UV0;
    POSITION = MODELVIEWPROJECTION_MATRIX * p;
}
