// FAST TRAVEL's buildings (Qt Quick 3D custom material): pass world position, normal and UV on.
VARYING vec3 vWorld;
VARYING vec3 vNormal;
VARYING vec2 vUv;
void MAIN()
{
    vWorld = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vNormal = normalize(NORMAL_MATRIX * NORMAL);
    vUv = UV0;
    POSITION = MODELVIEWPROJECTION_MATRIX * vec4(VERTEX, 1.0);
}
