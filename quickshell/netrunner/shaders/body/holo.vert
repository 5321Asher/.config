// The ripperdoc's hologram body (Qt Quick 3D custom material), skinned to its skeleton (Ripperdoc's
// Skin): vPos is the rest pose's position (what the veins, the focus and the build are drawn
// against, so they stay put on the body whatever pose it strikes), vWorld and vNormal the posed ones.
VARYING vec3 vPos;
VARYING vec3 vWorld;
VARYING vec3 vNormal;
void MAIN()
{
    mat4 skin = BONE_TRANSFORMS[int(JOINTS.x)] * WEIGHTS.x + BONE_TRANSFORMS[int(JOINTS.y)] * WEIGHTS.y
              + BONE_TRANSFORMS[int(JOINTS.z)] * WEIGHTS.z + BONE_TRANSFORMS[int(JOINTS.w)] * WEIGHTS.w;
    vec4 p = skin * vec4(VERTEX, 1.0);
    vPos = VERTEX;
    vWorld = (MODEL_MATRIX * p).xyz;
    vNormal = normalize(NORMAL_MATRIX * (mat3(skin) * NORMAL));   // the bones only turn: no inverse-transpose needed
    POSITION = MODELVIEWPROJECTION_MATRIX * p;
}
